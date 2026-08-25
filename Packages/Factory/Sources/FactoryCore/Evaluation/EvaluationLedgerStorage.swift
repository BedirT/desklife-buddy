import Darwin
import Foundation

enum EvaluationLedgerFileStore {
    private static let maximumDocumentBytes = 16 * 1024 * 1024

    static func initialize<Document: Codable & Equatable>(
        at root: URL,
        kind: EvaluationLedgerFileKind,
        document: Document,
        validate: (Document) throws -> Void,
    ) throws {
        try validate(document)
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        try withLock(rootFD: rootFD, name: kind.lockName, exclusive: true) {
            guard try entryStatus(rootFD: rootFD, name: kind.stateName) == .missing else {
                throw FactoryValidationError(
                    code: "evaluation_ledger_exists",
                    message: "Durable evaluation ledger state already exists.",
                )
            }
            try write(document, rootFD: rootFD, kind: kind, createOnly: true)
        }
    }

    static func snapshot<Document: Codable & Equatable, Result>(
        at root: URL,
        kind: EvaluationLedgerFileKind,
        body: (Document) throws -> Result,
    ) throws -> Result {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try withLock(rootFD: rootFD, name: kind.lockName, exclusive: false) {
            try body(read(rootFD: rootFD, name: kind.stateName))
        }
    }

    static func update<Document: Codable & Equatable, Result>(
        at root: URL,
        kind: EvaluationLedgerFileKind,
        body: (Document) throws -> (Document, Result),
    ) throws -> Result {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try withLock(rootFD: rootFD, name: kind.lockName, exclusive: true) {
            let (updated, result) = try body(read(rootFD: rootFD, name: kind.stateName))
            try write(updated, rootFD: rootFD, kind: kind, createOnly: false)
            return result
        }
    }
}

private extension EvaluationLedgerFileStore {
    private static func openRoot(_ root: URL) throws -> Int32 {
        guard root.isFileURL,
              root.path.hasPrefix("/"),
              root.path != "/",
              !root.path.hasSuffix("/"),
              !root.path.contains("//"),
              root.path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              URL(fileURLWithPath: root.path).path == root.path
        else {
            throw unsafeRoot()
        }
        let components = root.pathComponents.filter { $0 != "/" }
        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0,
              BrokerFilesystemSecurity.isSecureDirectory(
                  fileDescriptor: directoryFD,
                  allowedOwnerUIDs: [0, Darwin.geteuid()],
              )
        else {
            throw unsafeRoot()
        }
        var keepDirectory = false
        defer {
            if !keepDirectory { Darwin.close(directoryFD) }
        }
        let ownerUID = Darwin.geteuid()
        for (index, component) in components.enumerated() {
            let nextFD = Darwin.openat(
                directoryFD,
                component,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            )
            guard nextFD >= 0 else { throw unsafeRoot() }
            var metadata = stat()
            let isLeaf = index == components.index(before: components.endIndex)
            let valid = Darwin.fstat(nextFD, &metadata) == 0
                && metadata.st_mode & S_IFMT == S_IFDIR
                && (isLeaf ? metadata.st_uid == ownerUID : [uid_t(0), ownerUID].contains(metadata.st_uid))
                && metadata.st_mode & 0o022 == 0
                && (!isLeaf || metadata.st_mode & 0o777 == 0o700)
                && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
            guard valid else {
                Darwin.close(nextFD)
                throw unsafeRoot()
            }
            Darwin.close(directoryFD)
            directoryFD = nextFD
        }
        keepDirectory = true
        return directoryFD
    }

    private static func withLock<Result>(
        rootFD: Int32,
        name: String,
        exclusive: Bool,
        operation: () throws -> Result,
    ) throws -> Result {
        let lockFD = try lock(rootFD: rootFD, name: name, exclusive: exclusive)
        defer { unlockAndClose(lockFD) }
        do {
            let result = try operation()
            try validateInstalledEntry(fd: lockFD, rootFD: rootFD, name: name)
            return result
        } catch let operationError {
            try validateInstalledEntry(fd: lockFD, rootFD: rootFD, name: name)
            throw operationError
        }
    }

    private static func lock(rootFD: Int32, name: String, exclusive: Bool) throws -> Int32 {
        let fd = Darwin.openat(rootFD, name, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw posixError("open_evaluation_ledger_lock") }
        do {
            try validateRegularFile(fd: fd)
            var value = Darwin.flock()
            value.l_type = Int16(exclusive ? F_WRLCK : F_RDLCK)
            value.l_whence = Int16(SEEK_SET)
            guard Darwin.fcntl(fd, F_SETLKW, &value) == 0 else {
                throw posixError("lock_evaluation_ledger")
            }
            try validateInstalledEntry(fd: fd, rootFD: rootFD, name: name)
            return fd
        } catch {
            Darwin.close(fd)
            throw error
        }
    }

    private static func unlockAndClose(_ fd: Int32) {
        var value = Darwin.flock()
        value.l_type = Int16(F_UNLCK)
        value.l_whence = Int16(SEEK_SET)
        _ = Darwin.fcntl(fd, F_SETLK, &value)
        Darwin.close(fd)
    }

    private static func read<Document: Codable & Equatable>(rootFD: Int32, name: String) throws -> Document {
        let fd = Darwin.openat(rootFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw posixError("open_evaluation_ledger") }
        defer { Darwin.close(fd) }
        try validateRegularFile(fd: fd)
        var before = stat()
        guard Darwin.fstat(fd, &before) == 0,
              before.st_size > 0,
              before.st_size <= maximumDocumentBytes
        else {
            throw FactoryValidationError(
                code: "evaluation_ledger_budget",
                message: "Durable evaluation ledger bytes exceed the fixed ceiling.",
            )
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let expectedBytes = Int(before.st_size)
        var data = Data()
        data.reserveCapacity(expectedBytes)
        while data.count < expectedBytes {
            let count = min(64 * 1024, expectedBytes - data.count)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else {
                throw changed()
            }
            data.append(chunk)
        }
        let overflow = try handle.read(upToCount: 1) ?? Data()
        var after = stat()
        var installed = stat()
        guard overflow.isEmpty,
              Darwin.fstat(fd, &after) == 0,
              Darwin.fstatat(rootFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(before, after),
              stableIdentity(before, installed)
        else {
            throw changed()
        }
        return try CanonicalJSON.decode(Document.self, from: data)
    }
}

private extension EvaluationLedgerFileStore {
    private static func write<Document: Codable & Equatable>(
        _ document: Document,
        rootFD: Int32,
        kind: EvaluationLedgerFileKind,
        createOnly: Bool,
    ) throws {
        if try entryStatus(rootFD: rootFD, name: kind.temporaryName) == .regular {
            guard Darwin.unlinkat(rootFD, kind.temporaryName, 0) == 0 else {
                throw posixError("remove_evaluation_ledger_temporary")
            }
        }
        let data = try CanonicalJSON.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw FactoryValidationError(
                code: "evaluation_ledger_budget",
                message: "Durable evaluation ledger bytes exceed the fixed ceiling.",
            )
        }
        let temporaryFD = Darwin.openat(
            rootFD,
            kind.temporaryName,
            O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600,
        )
        guard temporaryFD >= 0 else { throw posixError("create_evaluation_ledger_temporary") }
        var keepTemporary = true
        defer {
            Darwin.close(temporaryFD)
            if keepTemporary { Darwin.unlinkat(rootFD, kind.temporaryName, 0) }
        }
        try validateRegularFile(fd: temporaryFD)
        let handle = FileHandle(fileDescriptor: temporaryFD, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard Darwin.fchmod(temporaryFD, 0o600) == 0,
              Darwin.fsync(temporaryFD) == 0
        else {
            throw posixError("sync_evaluation_ledger_temporary")
        }
        try commitTemporary(rootFD: rootFD, kind: kind, createOnly: createOnly)
        keepTemporary = false
        let observed: Document = try read(rootFD: rootFD, name: kind.stateName)
        guard observed == document else { throw changed() }
    }

    private static func commitTemporary(
        rootFD: Int32,
        kind: EvaluationLedgerFileKind,
        createOnly: Bool,
    ) throws {
        let status: Int32
        if createOnly {
            status = Darwin.renameatx_np(
                rootFD,
                kind.temporaryName,
                rootFD,
                kind.stateName,
                UInt32(RENAME_EXCL),
            )
        } else {
            guard try entryStatus(rootFD: rootFD, name: kind.stateName) == .regular else {
                throw changed()
            }
            status = Darwin.renameat(rootFD, kind.temporaryName, rootFD, kind.stateName)
        }
        guard status == 0, Darwin.fsync(rootFD) == 0 else {
            throw posixError("commit_evaluation_ledger")
        }
    }

    private enum EntryStatus {
        case missing
        case regular
    }

    private static func entryStatus(rootFD: Int32, name: String) throws -> EntryStatus {
        var metadata = stat()
        if Darwin.fstatat(rootFD, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 {
            guard metadata.st_mode & S_IFMT == S_IFREG,
                  metadata.st_uid == Darwin.geteuid(),
                  metadata.st_nlink == 1,
                  metadata.st_mode & 0o777 == 0o600
            else {
                throw unsafeFile()
            }
            let descriptor = Darwin.openat(rootFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
            guard descriptor >= 0 else { throw unsafeFile() }
            defer { Darwin.close(descriptor) }
            try validateRegularFile(fd: descriptor)
            return .regular
        }
        if errno == ENOENT { return .missing }
        throw posixError("inspect_evaluation_ledger")
    }

    private static func validateRegularFile(fd: Int32) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == Darwin.geteuid(),
              metadata.st_nlink == 1,
              metadata.st_mode & 0o777 == 0o600,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw unsafeFile()
        }
    }

    private static func validateInstalledEntry(fd: Int32, rootFD: Int32, name: String) throws {
        var descriptor = stat()
        var installed = stat()
        guard Darwin.fstat(fd, &descriptor) == 0,
              Darwin.fstatat(rootFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(descriptor, installed)
        else {
            throw changed()
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

    private static func unsafeRoot() -> FactoryValidationError {
        FactoryValidationError(
            code: "unsafe_evaluation_ledger_root",
            message: "Evaluation ledger ancestry must be private, canonical, and link-free.",
        )
    }

    private static func unsafeFile() -> FactoryValidationError {
        FactoryValidationError(
            code: "unsafe_evaluation_ledger_file",
            message: "Evaluation ledger entries must be private one-link regular files.",
        )
    }

    private static func changed() -> FactoryValidationError {
        FactoryValidationError(
            code: "evaluation_ledger_changed",
            message: "Durable evaluation ledger state changed during a locked operation.",
        )
    }

    private static func posixError(_ code: String) -> FactoryValidationError {
        FactoryValidationError(
            code: code,
            message: "The durable evaluation ledger operation failed with errno \(errno).",
        )
    }
}
