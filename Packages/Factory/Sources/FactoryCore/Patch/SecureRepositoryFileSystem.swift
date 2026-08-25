import Darwin
import Foundation

struct SecureRegularFile {
    let data: Data
    let executable: Bool
}

struct SecureRegularFileSnapshot {
    let file: SecureRegularFile
    let identity: SecureRegularFileIdentity
}

struct SecureRegularFileIdentity {
    let path: RepositoryPath
    fileprivate let directoryIdentities: [stat]
    fileprivate let fileIdentity: stat
}

enum SecureRepositoryFileSystem {
    static let maximumRegularFileBytes = 1024 * 1024 * 1024

    static func canonicalExistingURL(_ url: URL) throws -> URL {
        let standardized = url.standardizedFileURL
        var endpoint = stat()
        guard Darwin.lstat(standardized.path, &endpoint) == 0,
              endpoint.st_mode & S_IFMT == S_IFDIR
        else {
            throw FactoryValidationError(
                code: "unsafe_secure_root",
                message: "The filesystem root must be a real directory, not a link.",
            )
        }
        guard let resolved = Darwin.realpath(standardized.path, nil) else {
            throw posixError("resolve_secure_root")
        }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }

    static func openDirectory(_ url: URL) throws -> Int32 {
        let canonical = try canonicalExistingURL(url)
        let fd = Darwin.open(canonical.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard fd >= 0 else { throw posixError("open_secure_root") }
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid(),
              metadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            Darwin.close(fd)
            throw FactoryValidationError(
                code: "unsafe_secure_root",
                message: "The filesystem root has an unexpected owner or type.",
            )
        }
        return fd
    }

    static func readRegularFile(
        rootFD: Int32,
        path: RepositoryPath,
        allowedModes: Set<mode_t>,
        maximumBytes: Int,
    ) throws -> SecureRegularFile {
        try readRegularFileSnapshot(
            rootFD: rootFD,
            path: path,
            allowedModes: allowedModes,
            maximumBytes: maximumBytes,
        ).file
    }

    static func readRegularFile(
        rootFD: Int32,
        path: RepositoryPath,
        allowedModes: Set<mode_t>,
        maximumBytes: Int,
        beforeRootIdentityValidation: () throws -> Void,
    ) throws -> SecureRegularFile {
        try readRegularFileSnapshot(
            rootFD: rootFD,
            path: path,
            allowedModes: allowedModes,
            maximumBytes: maximumBytes,
            beforeRootIdentityValidation: beforeRootIdentityValidation,
        ).file
    }

    static func readRegularFileSnapshot(
        rootFD: Int32,
        path: RepositoryPath,
        allowedModes: Set<mode_t>,
        maximumBytes: Int,
        deadlineCheck: () -> Bool = { true },
        afterDirectoryIdentityCapture: () throws -> Void = {},
        beforeRootIdentityValidation: () throws -> Void = {},
    ) throws -> SecureRegularFileSnapshot {
        let directoryFDs = try openDirectoryChain(
            rootFD: rootFD,
            components: Array(path.components.dropLast()),
        )
        defer { directoryFDs.forEach { Darwin.close($0) } }
        let directoryIdentities = try directoryFDs.map(metadata)
        try afterDirectoryIdentityCapture()
        guard let parentFD = directoryFDs.last else { throw posixError("missing_secure_parent") }
        guard let name = path.components.last else {
            throw FactoryValidationError(code: "invalid_patch_path", message: "Patch paths need a filename.")
        }
        let fd = Darwin.openat(parentFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard fd >= 0 else { throw posixError("open_secure_file") }
        defer { Darwin.close(fd) }
        let (regular, fileIdentity) = try readRegularFileSnapshot(
            fd: fd,
            allowedModes: allowedModes,
            maximumBytes: maximumBytes,
            deadlineCheck: deadlineCheck,
        )
        try validateInstalledIdentity(
            fd: fd,
            directoryFD: parentFD,
            name: name,
            expected: fileIdentity,
        )
        let snapshot = SecureRegularFileSnapshot(
            file: regular,
            identity: SecureRegularFileIdentity(
                path: path,
                directoryIdentities: directoryIdentities,
                fileIdentity: fileIdentity,
            ),
        )
        try beforeRootIdentityValidation()
        try validateInstalled(snapshot, rootFD: rootFD)
        return snapshot
    }

    static func validateInstalled(_ snapshot: SecureRegularFileSnapshot, rootFD: Int32) throws {
        try validateInstalled(snapshot.identity, rootFD: rootFD)
    }

    static func validateInstalled(_ identity: SecureRegularFileIdentity, rootFD: Int32) throws {
        let directoryFDs = try openDirectoryChain(
            rootFD: rootFD,
            components: Array(identity.path.components.dropLast()),
        )
        defer { directoryFDs.forEach { Darwin.close($0) } }
        guard directoryFDs.count == identity.directoryIdentities.count else {
            throw FactoryValidationError(
                code: "repository_path_changed",
                message: "A repository directory chain changed while it was in use.",
            )
        }
        for (fd, expected) in zip(directoryFDs, identity.directoryIdentities) {
            guard try stableIdentity(metadata(fd), expected) else {
                throw FactoryValidationError(
                    code: "repository_path_changed",
                    message: "A repository directory chain changed while it was in use.",
                )
            }
        }
        guard let parentFD = directoryFDs.last,
              let name = identity.path.components.last
        else {
            throw FactoryValidationError(code: "invalid_patch_path", message: "Patch paths need a filename.")
        }
        let fd = Darwin.openat(parentFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard fd >= 0 else { throw posixError("reopen_secure_file") }
        defer { Darwin.close(fd) }
        try validateInstalledIdentity(
            fd: fd,
            directoryFD: parentFD,
            name: name,
            expected: identity.fileIdentity,
        )
    }

    static func entryExists(rootFD: Int32, path: RepositoryPath) throws -> Bool {
        let parentFD = try openDirectories(rootFD: rootFD, components: Array(path.components.dropLast()))
        defer { Darwin.close(parentFD) }
        guard let name = path.components.last else {
            throw FactoryValidationError(code: "invalid_patch_path", message: "Patch paths need a filename.")
        }
        let fd = Darwin.openat(parentFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW_ANY)
        if fd >= 0 {
            defer { Darwin.close(fd) }
            var metadata = stat()
            guard Darwin.fstat(fd, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFREG,
                  metadata.st_uid == getuid(),
                  metadata.st_nlink == 1,
                  BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
            else {
                throw FactoryValidationError(
                    code: "unsafe_repository_entry",
                    message: "A patch path resolves to a link or special file.",
                )
            }
            try validateInstalledIdentity(fd: fd, directoryFD: parentFD, name: name)
            return true
        }
        if errno == ENOENT {
            return false
        }
        throw posixError("inspect_repository_entry")
    }

    static func atomicWrite(
        rootFD: Int32,
        path: RepositoryPath,
        data: Data,
        executable: Bool,
        createOnly: Bool,
        transactionID: String,
    ) throws {
        let parent = Array(path.components.dropLast())
        let parentFD = try openDirectories(rootFD: rootFD, components: parent)
        defer { Darwin.close(parentFD) }
        guard let name = path.components.last else {
            throw FactoryValidationError(code: "invalid_patch_path", message: "Patch paths need a filename.")
        }
        let temporary = ".factory-import-\(transactionID)"
        let mode: mode_t = executable ? 0o755 : 0o644
        let temporaryFD = Darwin.openat(
            parentFD,
            temporary,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            mode,
        )
        guard temporaryFD >= 0 else { throw posixError("create_import_temporary") }
        var keepTemporary = true
        defer {
            Darwin.close(temporaryFD)
            if keepTemporary {
                Darwin.unlinkat(parentFD, temporary, 0)
            }
        }
        let handle = FileHandle(fileDescriptor: temporaryFD, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard Darwin.fchmod(temporaryFD, mode) == 0, Darwin.fsync(temporaryFD) == 0 else {
            throw posixError("finish_import_temporary")
        }
        var temporaryMetadata = stat()
        guard Darwin.fstat(temporaryFD, &temporaryMetadata) == 0,
              temporaryMetadata.st_mode & S_IFMT == S_IFREG,
              temporaryMetadata.st_uid == getuid(),
              temporaryMetadata.st_nlink == 1,
              temporaryMetadata.st_mode & 0o7777 == mode,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: temporaryFD)
        else {
            throw FactoryValidationError(
                code: "unsafe_import_temporary",
                message: "The patch temporary inherited unexpected write authority.",
            )
        }
        let renameStatus: Int32 = if createOnly {
            Darwin.renameatx_np(parentFD, temporary, parentFD, name, UInt32(RENAME_EXCL))
        } else {
            Darwin.renameat(parentFD, temporary, parentFD, name)
        }
        guard renameStatus == 0, Darwin.fsync(parentFD) == 0 else {
            throw posixError("commit_import_file")
        }
        keepTemporary = false
        let observed = try readRegularFile(
            rootFD: rootFD,
            path: path,
            allowedModes: [0o644, 0o755],
            maximumBytes: data.count,
        )
        guard observed.data == data, observed.executable == executable else {
            throw FactoryValidationError(
                code: "import_verification_failed",
                message: "Imported bytes do not match their envelope.",
            )
        }
    }

    static func delete(rootFD: Int32, path: RepositoryPath) throws {
        let parent = Array(path.components.dropLast())
        let parentFD = try openDirectories(rootFD: rootFD, components: parent)
        defer { Darwin.close(parentFD) }
        guard let name = path.components.last,
              Darwin.unlinkat(parentFD, name, 0) == 0,
              Darwin.fsync(parentFD) == 0
        else {
            throw posixError("delete_import_file")
        }
    }

    static func removeEmptyDirectories(rootFD: Int32, paths: [RepositoryPath]) {
        for path in paths.reversed() {
            let components = path.components
            guard let name = components.last,
                  let parentFD = try? openDirectories(rootFD: rootFD, components: Array(components.dropLast()))
            else { continue }
            Darwin.unlinkat(parentFD, name, AT_REMOVEDIR)
            Darwin.close(parentFD)
        }
    }

    static func listTree(rootFD: Int32) throws -> [RepositoryTreeFile] {
        var rootMetadata = stat()
        guard Darwin.fstat(rootFD, &rootMetadata) == 0,
              rootMetadata.st_mode & S_IFMT == S_IFDIR,
              rootMetadata.st_uid == getuid(),
              rootMetadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: rootFD)
        else {
            throw FactoryValidationError(
                code: "unsafe_tree_root",
                message: "The repository root has unsafe ownership, mode, or access control.",
            )
        }
        var files: [RepositoryTreeFile] = []
        try listTree(
            directoryFD: rootFD,
            prefix: [],
            rootDevice: rootMetadata.st_dev,
            files: &files,
        )
        return files.sorted { $0.path < $1.path }
    }
}

private extension SecureRepositoryFileSystem {
    private static func listTree(
        directoryFD: Int32,
        prefix: [String],
        rootDevice: dev_t,
        files: inout [RepositoryTreeFile],
    ) throws {
        let duplicate = Darwin.dup(directoryFD)
        guard duplicate >= 0, let directory = Darwin.fdopendir(duplicate) else {
            if duplicate >= 0 { Darwin.close(duplicate) }
            throw posixError("enumerate_tree")
        }
        var names: [String] = []
        while let entryPointer = Darwin.readdir(directory) {
            var entry = entryPointer.pointee
            let name = withUnsafePointer(to: &entry.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if name != ".", name != ".." {
                names.append(name)
            }
        }
        Darwin.closedir(directory)

        for name in names.sorted() {
            if prefix.isEmpty, name == ".git" {
                continue
            }
            let raw = (prefix + [name]).joined(separator: "/")
            let path: RepositoryPath
            do {
                path = try RepositoryPath(validating: raw)
            } catch {
                throw FactoryValidationError(
                    code: "unsafe_tree_path",
                    message: "The repository contains reserved or noncanonical paths.",
                )
            }
            var metadata = stat()
            guard Darwin.fstatat(directoryFD, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0,
                  metadata.st_dev == rootDevice,
                  metadata.st_uid == getuid()
            else {
                throw FactoryValidationError(
                    code: "unsafe_tree_entry",
                    message: "A repository entry changed owner or device.",
                )
            }
            switch metadata.st_mode & S_IFMT {
            case S_IFDIR:
                let child = Darwin.openat(directoryFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
                guard child >= 0 else { throw posixError("open_tree_directory") }
                do {
                    try validateOpenedIdentity(fd: child, expected: metadata)
                    try validateDirectory(fd: child)
                    try listTree(
                        directoryFD: child,
                        prefix: prefix + [name],
                        rootDevice: rootDevice,
                        files: &files,
                    )
                    Darwin.close(child)
                } catch {
                    Darwin.close(child)
                    throw error
                }
            case S_IFREG:
                guard metadata.st_nlink == 1 else {
                    throw FactoryValidationError(
                        code: "hard_link_in_tree",
                        message: "Repository files must have one link.",
                    )
                }
                let fd = Darwin.openat(directoryFD, name, O_RDONLY | O_NONBLOCK | O_CLOEXEC | O_NOFOLLOW_ANY)
                guard fd >= 0 else { throw posixError("open_tree_file") }
                let regular: SecureRegularFile
                do {
                    try validateOpenedIdentity(fd: fd, expected: metadata)
                    regular = try readRegularFile(
                        fd: fd,
                        allowedModes: [0o644, 0o755],
                        maximumBytes: maximumRegularFileBytes,
                    )
                    try validateInstalledIdentity(fd: fd, directoryFD: directoryFD, name: name)
                } catch {
                    Darwin.close(fd)
                    throw error
                }
                Darwin.close(fd)
                files.append(
                    RepositoryTreeFile(
                        path: path,
                        digest: SHA256Digest.hashing(regular.data),
                        bytes: regular.data.count,
                        executable: regular.executable,
                    ),
                )
            default:
                throw FactoryValidationError(
                    code: "special_file_in_tree",
                    message: "Repository trees may contain only directories and regular files.",
                )
            }
        }
    }

    private static func validateOpenedIdentity(fd: Int32, expected: stat) throws {
        var observed = stat()
        guard Darwin.fstat(fd, &observed) == 0,
              observed.st_dev == expected.st_dev,
              observed.st_ino == expected.st_ino,
              observed.st_mode == expected.st_mode,
              observed.st_uid == expected.st_uid,
              observed.st_nlink == expected.st_nlink,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "tree_entry_changed",
                message: "A repository entry changed while it was opened.",
            )
        }
    }

    private static func readRegularFile(
        fd: Int32,
        allowedModes: Set<mode_t>,
        maximumBytes: Int,
    ) throws -> SecureRegularFile {
        try readRegularFileSnapshot(
            fd: fd,
            allowedModes: allowedModes,
            maximumBytes: maximumBytes,
            deadlineCheck: { true },
        ).0
    }

    private static func readRegularFileSnapshot(
        fd: Int32,
        allowedModes: Set<mode_t>,
        maximumBytes: Int,
        deadlineCheck: () -> Bool,
    ) throws -> (SecureRegularFile, stat) {
        var before = stat()
        guard deadlineCheck(),
              maximumBytes >= 0,
              Darwin.fstat(fd, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(),
              before.st_nlink == 1,
              before.st_size >= 0,
              before.st_size <= maximumBytes,
              allowedModes.contains(before.st_mode & 0o7777),
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_regular_file",
                message: "A file has an unsafe type, link count, or mode.",
            )
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let expectedBytes = Int(before.st_size)
        var data = Data()
        data.reserveCapacity(expectedBytes)
        while data.count < expectedBytes {
            guard deadlineCheck() else {
                throw FactoryValidationError(
                    code: "secure_read_deadline",
                    message: "The secure file read exceeded its deadline.",
                )
            }
            let remaining = expectedBytes - data.count
            let chunk = try handle.read(upToCount: min(remaining, 64 * 1024)) ?? Data()
            guard !chunk.isEmpty else { break }
            data.append(chunk)
        }
        guard deadlineCheck() else {
            throw FactoryValidationError(
                code: "secure_read_deadline",
                message: "The secure file read exceeded its deadline.",
            )
        }
        let overflowProbe = try handle.read(upToCount: 1) ?? Data()
        var after = stat()
        guard Darwin.fstat(fd, &after) == 0,
              stableIdentity(before, after),
              data.count == before.st_size,
              overflowProbe.isEmpty
        else {
            throw FactoryValidationError(code: "regular_file_changed", message: "A file changed while it was read.")
        }
        return (SecureRegularFile(data: data, executable: before.st_mode & 0o111 != 0), after)
    }

    private static func openDirectoryChain(rootFD: Int32, components: [String]) throws -> [Int32] {
        let root = Darwin.dup(rootFD)
        guard root >= 0 else { throw posixError("duplicate_identity_root") }
        var directories = [root]
        do {
            try validateDirectory(fd: root)
            for component in components {
                guard let parentFD = directories.last else { throw posixError("missing_identity_parent") }
                let next = Darwin.openat(
                    parentFD,
                    component,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY,
                )
                guard next >= 0 else { throw posixError("open_identity_parent") }
                directories.append(next)
                try validateDirectory(fd: next)
            }
            return directories
        } catch {
            directories.forEach { Darwin.close($0) }
            throw error
        }
    }

    private static func metadata(_ fd: Int32) throws -> stat {
        var value = stat()
        guard Darwin.fstat(fd, &value) == 0 else { throw posixError("read_secure_identity") }
        return value
    }

    private static func openDirectories(rootFD: Int32, components: [String]) throws -> Int32 {
        var current = Darwin.dup(rootFD)
        guard current >= 0 else { throw posixError("duplicate_tree_root") }
        do {
            try validateDirectory(fd: current)
        } catch {
            Darwin.close(current)
            throw error
        }
        for component in components {
            let next = Darwin.openat(current, component, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
            Darwin.close(current)
            guard next >= 0 else { throw posixError("open_tree_parent") }
            do {
                try validateDirectory(fd: next)
            } catch {
                Darwin.close(next)
                throw error
            }
            current = next
        }
        return current
    }

    private static func validateDirectory(fd: Int32) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid(),
              metadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_repository_directory",
                message: "Repository directories must reject ambient write authority.",
            )
        }
    }

    private static func validateInstalledIdentity(
        fd: Int32,
        directoryFD: Int32,
        name: String,
        expected: stat? = nil,
    ) throws {
        var descriptor = stat()
        var installed = stat()
        guard Darwin.fstat(fd, &descriptor) == 0,
              Darwin.fstatat(directoryFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(descriptor, installed),
              expected.map({ stableIdentity(descriptor, $0) }) ?? true,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "repository_entry_changed",
                message: "A repository entry changed identity while it was in use.",
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
        FactoryValidationError(code: code, message: "The secure filesystem operation failed with errno \(errno).")
    }
}
