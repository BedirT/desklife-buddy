import Darwin
import Foundation

struct LockedAuthoritativeRoot {
    let canonicalURL: URL
    let fileDescriptor: Int32

    private let device: dev_t
    private let inode: ino_t
    private let ownerUID: uid_t

    init(canonicalURL: URL, fileDescriptor: Int32, metadata: stat) {
        self.canonicalURL = canonicalURL
        self.fileDescriptor = fileDescriptor
        device = metadata.st_dev
        inode = metadata.st_ino
        ownerUID = metadata.st_uid
    }

    func validatePathIdentity() throws {
        let observedFD = Darwin.open(
            canonicalURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY,
        )
        guard observedFD >= 0 else { throw changed() }
        defer { Darwin.close(observedFD) }
        var observed = stat()
        guard Darwin.fstat(observedFD, &observed) == 0,
              observed.st_mode & S_IFMT == S_IFDIR,
              observed.st_dev == device,
              observed.st_ino == inode,
              observed.st_uid == ownerUID
        else {
            throw changed()
        }
    }

    private func changed() -> FactoryValidationError {
        FactoryValidationError(
            code: "authoritative_root_changed",
            message: "The authoritative root changed identity while its transaction lock was held.",
        )
    }
}

enum AuthoritativePatchLock {
    static func withExclusiveLock<T>(at authoritativeRoot: URL, _ body: () throws -> T) throws -> T {
        try withLockedRoot(at: authoritativeRoot) { _ in try body() }
    }

    static func withLockedRoot<T>(
        at authoritativeRoot: URL,
        _ body: (LockedAuthoritativeRoot) throws -> T,
    ) throws -> T {
        let canonicalRoot = try SecureRepositoryFileSystem.canonicalExistingURL(authoritativeRoot)
        let rootFD = try SecureRepositoryFileSystem.openDirectory(canonicalRoot)
        defer { Darwin.close(rootFD) }
        var rootMetadata = stat()
        guard Darwin.fstat(rootFD, &rootMetadata) == 0,
              rootMetadata.st_mode & S_IFMT == S_IFDIR,
              rootMetadata.st_uid == getuid()
        else {
            throw FactoryValidationError(
                code: "unsafe_authoritative_lock_root",
                message: "The authoritative patch root has an unsafe identity.",
            )
        }
        let lockedRoot = LockedAuthoritativeRoot(
            canonicalURL: canonicalRoot,
            fileDescriptor: rootFD,
            metadata: rootMetadata,
        )
        try lockedRoot.validatePathIdentity()

        let lockURL = lockURL(for: canonicalRoot, metadata: rootMetadata)
        let parent = lockURL.deletingLastPathComponent()
        let parentFD = try SecureRepositoryFileSystem.openDirectory(parent)
        defer { Darwin.close(parentFD) }
        let lockFD = Darwin.openat(
            parentFD,
            lockURL.lastPathComponent,
            O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW,
            0o600,
        )
        guard lockFD >= 0 else { throw posixError("open_authoritative_patch_lock") }
        defer { Darwin.close(lockFD) }

        var lockMetadata = stat()
        guard Darwin.fstat(lockFD, &lockMetadata) == 0,
              lockMetadata.st_mode & S_IFMT == S_IFREG,
              lockMetadata.st_uid == getuid(),
              lockMetadata.st_nlink == 1,
              lockMetadata.st_mode & 0o777 == 0o600,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: lockFD)
        else {
            throw FactoryValidationError(
                code: "unsafe_authoritative_patch_lock",
                message: "The authoritative patch lock must be a private one-link regular file.",
            )
        }

        var lock = Darwin.flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(lockFD, F_SETLKW, &lock) == 0 else {
            throw posixError("lock_authoritative_patch_root")
        }
        defer {
            lock.l_type = Int16(F_UNLCK)
            _ = Darwin.fcntl(lockFD, F_SETLK, &lock)
        }

        try validateInstalledLock(
            fd: lockFD,
            parentFD: parentFD,
            name: lockURL.lastPathComponent,
        )
        try lockedRoot.validatePathIdentity()
        do {
            let result = try body(lockedRoot)
            try lockedRoot.validatePathIdentity()
            try validateInstalledLock(
                fd: lockFD,
                parentFD: parentFD,
                name: lockURL.lastPathComponent,
            )
            return result
        } catch {
            let operationError = error
            try lockedRoot.validatePathIdentity()
            try validateInstalledLock(
                fd: lockFD,
                parentFD: parentFD,
                name: lockURL.lastPathComponent,
            )
            throw operationError
        }
    }

    static func lockURL(for authoritativeRoot: URL) throws -> URL {
        let root = try SecureRepositoryFileSystem.canonicalExistingURL(authoritativeRoot)
        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        var metadata = stat()
        guard Darwin.fstat(rootFD, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid()
        else {
            throw FactoryValidationError(
                code: "unsafe_authoritative_lock_root",
                message: "The authoritative patch root has an unsafe identity.",
            )
        }
        return lockURL(for: root, metadata: metadata)
    }

    private static func lockURL(for root: URL, metadata: stat) -> URL {
        let identity = Data("\(root.path)\0\(metadata.st_dev)\0\(metadata.st_ino)".utf8)
        let name = ".swiftmac-factory-patch-\(SHA256Digest.hashing(identity).rawValue).lock"
        return root.deletingLastPathComponent().appending(path: name)
    }

    private static func validateInstalledLock(fd: Int32, parentFD: Int32, name: String) throws {
        var descriptor = stat()
        var installed = stat()
        guard Darwin.fstat(fd, &descriptor) == 0,
              Darwin.fstatat(parentFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(descriptor, installed),
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "authoritative_lock_changed",
                message: "The installed authoritative patch lock changed while held.",
            )
        }
    }

    private static func stableIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_uid == rhs.st_uid
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
            && lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec
            && lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }

    private static func posixError(_ code: String) -> FactoryValidationError {
        FactoryValidationError(code: code, message: "The authoritative patch lock failed with errno \(errno).")
    }
}
