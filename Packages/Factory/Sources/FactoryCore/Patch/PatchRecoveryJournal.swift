import Darwin
import Foundation

/// Outcome of reconciling one durable patch-import journal.
public enum PatchRecoveryResult: String, Codable, Sendable {
    case nothingToRecover = "nothing_to_recover"
    case discardedUncommittedJournal = "discarded_uncommitted_journal"
    case restoredPreparedTransaction = "restored_prepared_transaction"
    case clearedCompletedTransaction = "cleared_completed_transaction"
}

enum PatchRecoveryState: String, Codable {
    case prepared
    case completed
}

struct PatchRecoveryFile: Codable, Equatable {
    let data: Data
    let executable: Bool

    var expectation: FileExpectation {
        FileExpectation(data: data, executable: executable)
    }
}

struct PatchRecoveryOperation: Codable, Equatable {
    let operationID: String
    let path: RepositoryPath
    let kind: PatchFileOperationKind
    let before: PatchRecoveryFile?
    let after: FileExpectation?
}

struct PatchRecoveryRecord: Codable, Equatable {
    let schemaVersion: Int
    let envelopeID: String
    let envelopeDigest: SHA256Digest
    let state: PatchRecoveryState
    let beforeTree: RepositoryTree
    let completedTree: RepositoryTree?
    let operations: [PatchRecoveryOperation]

    func markingCompleted(with tree: RepositoryTree) -> PatchRecoveryRecord {
        PatchRecoveryRecord(
            schemaVersion: schemaVersion,
            envelopeID: envelopeID,
            envelopeDigest: envelopeDigest,
            state: .completed,
            beforeTree: beforeTree,
            completedTree: tree,
            operations: operations,
        )
    }

    func expectedCompletedTree() throws -> RepositoryTree {
        var files = Dictionary(uniqueKeysWithValues: beforeTree.files.map { ($0.path, $0) })
        for operation in operations {
            switch operation.kind {
            case .create, .update:
                guard let after = operation.after else {
                    throw FactoryValidationError(
                        code: "invalid_patch_journal",
                        message: "A completed patch operation is missing its expected output.",
                    )
                }
                files[operation.path] = RepositoryTreeFile(
                    path: operation.path,
                    digest: after.sha256,
                    bytes: after.bytes,
                    executable: after.executable,
                )
            case .delete:
                files.removeValue(forKey: operation.path)
            }
        }
        let ordered = files.values.sorted { $0.path < $1.path }
        return RepositoryTree(files: ordered, digest: CanonicalJSON.digest(ordered))
    }

    func validate(maximumTotalBytes: Int? = nil) throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(envelopeID),
              isCanonicalTree(beforeTree),
              !operations.isEmpty,
              operations.count <= PatchImportPolicy.maximumKernelOperations,
              operations.map(\.path) == operations.map(\.path).sorted(),
              Set(operations.map(\.path.collisionKey)).count == operations.count,
              Set(operations.map(\.operationID)).count == operations.count,
              operations.allSatisfy({ operation in
                  FactoryTextRules.isStableID(operation.operationID)
                      && (operation.before?.data.count ?? 0) <= SecureRepositoryFileSystem.maximumRegularFileBytes
                      && (operation.after?.bytes ?? 0) >= 0
                      && (operation.after?.bytes ?? 0) <= SecureRepositoryFileSystem.maximumRegularFileBytes
              }),
              (state == .completed) == (completedTree != nil),
              completedTree.map(isCanonicalTree) ?? true
        else {
            throw FactoryValidationError(
                code: "invalid_patch_journal",
                message: "The recovery journal is incomplete or noncanonical.",
            )
        }

        var totalBytes = 0
        for operation in operations {
            for bytes in [operation.before?.data.count, operation.after?.bytes].compactMap(\.self) {
                let (nextTotal, overflow) = totalBytes.addingReportingOverflow(bytes)
                guard !overflow,
                      maximumTotalBytes.map({ nextTotal <= $0 }) ?? true
                else {
                    throw FactoryValidationError(
                        code: "patch_journal_budget",
                        message: "Recovery data exceeds its fixed byte ceiling.",
                    )
                }
                totalBytes = nextTotal
            }
        }

        let beforeByPath = Dictionary(uniqueKeysWithValues: beforeTree.files.map { ($0.path, $0) })
        for operation in operations {
            let prior = operation.before?.expectation
            let treePrior = beforeByPath[operation.path]
            switch operation.kind {
            case .create:
                guard operation.before == nil,
                      operation.after != nil,
                      treePrior == nil
                else {
                    throw FactoryValidationError(
                        code: "invalid_patch_journal",
                        message: "A journaled create has invalid before state.",
                    )
                }
            case .update:
                guard let prior,
                      let after = operation.after,
                      treePrior.map({ matches(prior, treeFile: $0) }) == true,
                      prior != after
                else {
                    throw FactoryValidationError(
                        code: "invalid_patch_journal",
                        message: "A journaled update has invalid state.",
                    )
                }
            case .delete:
                guard let prior,
                      operation.after == nil,
                      treePrior.map({ matches(prior, treeFile: $0) }) == true
                else {
                    throw FactoryValidationError(
                        code: "invalid_patch_journal",
                        message: "A journaled delete has invalid state.",
                    )
                }
            }
        }
        if let completedTree {
            let expectedTree = try expectedCompletedTree()
            guard completedTree == expectedTree else {
                throw FactoryValidationError(
                    code: "invalid_patch_journal",
                    message: "The completed patch tree does not match its declared operations.",
                )
            }
        }
    }

    func containsExpectedPrefix(_ tree: RepositoryTree) throws -> Bool {
        var files = Dictionary(uniqueKeysWithValues: beforeTree.files.map { ($0.path, $0) })
        if tree == beforeTree { return true }
        for operation in operations {
            switch operation.kind {
            case .create, .update:
                guard let after = operation.after else { return false }
                files[operation.path] = RepositoryTreeFile(
                    path: operation.path,
                    digest: after.sha256,
                    bytes: after.bytes,
                    executable: after.executable,
                )
            case .delete:
                files.removeValue(forKey: operation.path)
            }
            let ordered = files.values.sorted { $0.path < $1.path }
            let expected = RepositoryTree(files: ordered, digest: CanonicalJSON.digest(ordered))
            if tree == expected { return true }
        }
        return false
    }

    private func matches(_ expectation: FileExpectation, treeFile: RepositoryTreeFile) -> Bool {
        expectation.sha256 == treeFile.digest
            && expectation.bytes == treeFile.bytes
            && expectation.executable == treeFile.executable
    }

    private func isCanonicalTree(_ tree: RepositoryTree) -> Bool {
        tree.files.map(\.path) == tree.files.map(\.path).sorted()
            && Set(tree.files.map(\.path.collisionKey)).count == tree.files.count
            && tree.files.allSatisfy { $0.bytes >= 0 }
            && tree.digest == CanonicalJSON.digest(tree.files)
    }
}

enum PatchRecoveryJournal {
    private static let journalName = "prepared.json"
    private static let lockName = "transaction.lock"
    static let maximumRecoveryBytes = 256 * 1024 * 1024
    private static let maximumJournalBytes = maximumRecoveryBytes
    private static let temporaryName = ".prepared.json.tmp"

    static func withExclusiveLock<T>(at root: URL, _ body: () throws -> T) throws -> T {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        let lockFD = Darwin.openat(rootFD, lockName, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard lockFD >= 0 else { throw posixError("open_patch_lock") }
        defer { Darwin.close(lockFD) }
        var metadata = stat()
        guard Darwin.fstat(lockFD, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == getuid(),
              metadata.st_nlink == 1,
              metadata.st_mode & 0o777 == 0o600
        else {
            throw FactoryValidationError(
                code: "unsafe_patch_lock",
                message: "Patch transaction locks must be private one-link regular files.",
            )
        }
        var lock = Darwin.flock()
        lock.l_type = Int16(F_WRLCK)
        lock.l_whence = Int16(SEEK_SET)
        guard Darwin.fcntl(lockFD, F_SETLKW, &lock) == 0 else {
            throw posixError("lock_patch_transaction")
        }
        defer {
            lock.l_type = Int16(F_UNLCK)
            _ = Darwin.fcntl(lockFD, F_SETLK, &lock)
        }
        return try body()
    }

    static func hasPending(at root: URL) throws -> Bool {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try entryExists(rootFD: rootFD, name: journalName)
            || entryExists(rootFD: rootFD, name: temporaryName)
    }

    static func load(at root: URL) throws -> PatchRecoveryRecord? {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        guard try entryExists(rootFD: rootFD, name: journalName) else { return nil }
        let path = try RepositoryPath(validating: journalName)
        let file = try SecureRepositoryFileSystem.readRegularFile(
            rootFD: rootFD,
            path: path,
            allowedModes: [0o600],
            maximumBytes: maximumJournalBytes,
        )
        let record = try CanonicalJSON.decode(PatchRecoveryRecord.self, from: file.data)
        try record.validate(maximumTotalBytes: maximumRecoveryBytes)
        return record
    }

    static func writePrepared(
        _ record: PatchRecoveryRecord,
        at root: URL,
        maximumEncodedBytes: Int = maximumJournalBytes,
        encoder: (PatchRecoveryRecord) throws -> Data = { try CanonicalJSON.encode($0) },
    ) throws {
        let data = try encoded(
            record,
            maximumEncodedBytes: maximumEncodedBytes,
            encoder: encoder,
        )
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        guard try !entryExists(rootFD: rootFD, name: journalName) else {
            throw FactoryValidationError(
                code: "patch_recovery_required",
                message: "A prepared patch transaction must be reconciled first.",
            )
        }
        if try entryExists(rootFD: rootFD, name: temporaryName) {
            guard Darwin.unlinkat(rootFD, temporaryName, 0) == 0,
                  Darwin.fsync(rootFD) == 0
            else {
                throw posixError("remove_orphaned_patch_journal")
            }
        }
        try write(data, rootFD: rootFD, name: temporaryName, createOnly: true)
        guard Darwin.renameatx_np(rootFD, temporaryName, rootFD, journalName, UInt32(RENAME_EXCL)) == 0,
              Darwin.fsync(rootFD) == 0
        else {
            Darwin.unlinkat(rootFD, temporaryName, 0)
            throw posixError("prepare_patch_journal")
        }
    }

    static func replace(_ record: PatchRecoveryRecord, at root: URL) throws {
        let data = try encoded(
            record,
            maximumEncodedBytes: maximumJournalBytes,
            encoder: { try CanonicalJSON.encode($0) },
        )
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        if try entryExists(rootFD: rootFD, name: temporaryName) {
            guard Darwin.unlinkat(rootFD, temporaryName, 0) == 0 else {
                throw posixError("remove_patch_journal_temporary")
            }
        }
        try write(data, rootFD: rootFD, name: temporaryName, createOnly: true)
        guard Darwin.renameat(rootFD, temporaryName, rootFD, journalName) == 0,
              Darwin.fsync(rootFD) == 0
        else {
            Darwin.unlinkat(rootFD, temporaryName, 0)
            throw posixError("complete_patch_journal")
        }
    }

    static func remove(at root: URL) throws {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        for name in [temporaryName, journalName] where try entryExists(rootFD: rootFD, name: name) {
            guard Darwin.unlinkat(rootFD, name, 0) == 0 else {
                throw posixError("remove_patch_journal")
            }
        }
        guard Darwin.fsync(rootFD) == 0 else {
            throw posixError("sync_patch_journal_root")
        }
    }

    private static func openRoot(_ root: URL) throws -> Int32 {
        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        var metadata = stat()
        guard Darwin.fstat(rootFD, &metadata) == 0,
              metadata.st_mode & 0o777 == 0o700
        else {
            Darwin.close(rootFD)
            throw FactoryValidationError(
                code: "unsafe_patch_recovery_root",
                message: "Patch recovery state must live in a private broker-owned directory.",
            )
        }
        return rootFD
    }

    private static func entryExists(rootFD: Int32, name: String) throws -> Bool {
        var metadata = stat()
        if Darwin.fstatat(rootFD, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 {
            guard metadata.st_mode & S_IFMT == S_IFREG,
                  metadata.st_uid == getuid(),
                  metadata.st_nlink == 1,
                  metadata.st_mode & 0o777 == 0o600
            else {
                throw FactoryValidationError(
                    code: "unsafe_patch_journal",
                    message: "Patch journal entries must be private one-link regular files.",
                )
            }
            return true
        }
        if errno == ENOENT { return false }
        throw posixError("inspect_patch_journal")
    }

    private static func write(
        _ data: Data,
        rootFD: Int32,
        name: String,
        createOnly: Bool,
    ) throws {
        guard data.count <= maximumJournalBytes else {
            throw FactoryValidationError(
                code: "patch_journal_budget",
                message: "The encoded recovery journal exceeds its fixed byte ceiling.",
            )
        }
        let flags = O_WRONLY | O_CREAT | O_CLOEXEC | O_NOFOLLOW | (createOnly ? O_EXCL : O_TRUNC)
        let fd = Darwin.openat(rootFD, name, flags, 0o600)
        guard fd >= 0 else { throw posixError("create_patch_journal") }
        defer { Darwin.close(fd) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard Darwin.fchmod(fd, 0o600) == 0,
              Darwin.fsync(fd) == 0
        else {
            throw posixError("sync_patch_journal")
        }
    }

    private static func encoded(
        _ record: PatchRecoveryRecord,
        maximumEncodedBytes: Int,
        encoder: (PatchRecoveryRecord) throws -> Data,
    ) throws -> Data {
        guard (1 ... maximumJournalBytes).contains(maximumEncodedBytes) else {
            throw FactoryValidationError(
                code: "patch_journal_budget",
                message: "The recovery journal byte ceiling is invalid.",
            )
        }
        try record.validate(maximumTotalBytes: maximumRecoveryBytes)
        try preflightEncodedBytes(record, maximumEncodedBytes: maximumEncodedBytes)
        let data = try encoder(record)
        guard data.count <= maximumEncodedBytes else {
            throw FactoryValidationError(
                code: "patch_journal_budget",
                message: "The encoded recovery journal exceeds its fixed byte ceiling.",
            )
        }
        return data
    }

    private static func preflightEncodedBytes(
        _ record: PatchRecoveryRecord,
        maximumEncodedBytes: Int,
    ) throws {
        let skeleton = PatchRecoveryRecord(
            schemaVersion: record.schemaVersion,
            envelopeID: record.envelopeID,
            envelopeDigest: record.envelopeDigest,
            state: record.state,
            beforeTree: record.beforeTree,
            completedTree: record.completedTree,
            operations: record.operations.map { operation in
                PatchRecoveryOperation(
                    operationID: operation.operationID,
                    path: operation.path,
                    kind: operation.kind,
                    before: operation.before.map {
                        PatchRecoveryFile(data: Data(), executable: $0.executable)
                    },
                    after: operation.after,
                )
            },
        )
        var expectedBytes = try CanonicalJSON.encode(skeleton).count
        for data in record.operations.compactMap(\.before?.data) {
            let completeGroups = data.count / 3
            let partialGroups = data.count % 3 == 0 ? 0 : 1
            let (groups, groupOverflow) = completeGroups.addingReportingOverflow(partialGroups)
            let (base64Bytes, base64Overflow) = groups.multipliedReportingOverflow(by: 4)
            let (nextExpectedBytes, totalOverflow) = expectedBytes.addingReportingOverflow(base64Bytes)
            guard !groupOverflow,
                  !base64Overflow,
                  !totalOverflow,
                  nextExpectedBytes <= maximumEncodedBytes
            else {
                throw FactoryValidationError(
                    code: "patch_journal_budget",
                    message: "The encoded recovery journal exceeds its fixed byte ceiling.",
                )
            }
            expectedBytes = nextExpectedBytes
        }
        guard expectedBytes <= maximumEncodedBytes else {
            throw FactoryValidationError(
                code: "patch_journal_budget",
                message: "The encoded recovery journal exceeds its fixed byte ceiling.",
            )
        }
    }

    private static func posixError(_ code: String) -> FactoryValidationError {
        FactoryValidationError(
            code: code,
            message: "The patch recovery filesystem operation failed with errno \(errno).",
        )
    }
}
