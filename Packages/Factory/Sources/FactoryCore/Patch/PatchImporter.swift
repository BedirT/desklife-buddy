import Darwin
import Foundation

/// Transactional, descriptor-backed importer for validated scratch output.
package enum PatchImporter {
    /// Whether a prepared, completed, or not-yet-committed journal needs reconciliation.
    package static func hasPendingRecovery(at recoveryRoot: URL) throws -> Bool {
        try PatchRecoveryJournal.hasPending(at: recoveryRoot)
    }

    /// Reconciles a durable journal while excluding every concurrent importer.
    package static func recover(
        authoritativeRoot: URL,
        recoveryRoot: URL,
    ) throws -> PatchRecoveryResult {
        try AuthoritativePatchLock.withLockedRoot(at: authoritativeRoot) { lockedRoot in
            try PatchRecoveryJournal.withExclusiveLock(at: recoveryRoot) {
                try recoverLocked(authoritativeRoot: lockedRoot, recoveryRoot: recoveryRoot)
            }
        }
    }

    /// Imports one fully bound envelope while holding the recovery transaction lock.
    package static func apply(
        _ envelope: PatchEnvelope,
        authoritativeRoot: URL,
        contentRoot: URL,
        recoveryRoot: URL,
        repositoryIdentity: (_ excluding: [RepositoryPath]) throws -> (base: GitObjectID, tree: GitObjectID),
        policy: PatchImportPolicy,
        fault: PatchImportFault = PatchImportFault(),
    ) throws -> PatchImportReceipt {
        try AuthoritativePatchLock.withLockedRoot(at: authoritativeRoot) { lockedRoot in
            try PatchRecoveryJournal.withExclusiveLock(at: recoveryRoot) {
                try applyLocked(
                    envelope,
                    authoritativeRoot: lockedRoot,
                    contentRoot: contentRoot,
                    recoveryRoot: recoveryRoot,
                    repositoryIdentity: repositoryIdentity,
                    policy: policy,
                    fault: fault,
                )
            }
        }
    }
}

private extension PatchImporter {
    /// Reconciles a durable journal without trusting live process memory.
    static func recoverLocked(
        authoritativeRoot: LockedAuthoritativeRoot,
        recoveryRoot: URL,
    ) throws -> PatchRecoveryResult {
        try validateDistinctRoots(
            authoritativeRoot: authoritativeRoot.canonicalURL,
            contentRoot: nil,
            recoveryRoot: recoveryRoot,
        )
        guard let record = try PatchRecoveryJournal.load(at: recoveryRoot) else {
            guard try PatchRecoveryJournal.hasPending(at: recoveryRoot) else {
                return .nothingToRecover
            }
            try PatchRecoveryJournal.remove(at: recoveryRoot)
            return .discardedUncommittedJournal
        }
        let paths = record.operations.map(\.path)
        let current = try RepositoryTree.capture(rootFD: authoritativeRoot.fileDescriptor, paths: paths)
        switch record.state {
        case .completed:
            guard current == record.completedTree else {
                throw FactoryValidationError(
                    code: "patch_import_quarantined",
                    message: "A completed patch journal no longer matches the authoritative tree.",
                )
            }
            try PatchRecoveryJournal.remove(at: recoveryRoot)
            return .clearedCompletedTransaction
        case .prepared:
            guard try record.containsExpectedPrefix(current) else {
                throw FactoryValidationError(
                    code: "patch_import_quarantined",
                    message: "The authoritative tree is not a valid prefix of its prepared patch transaction.",
                )
            }
            let repositoryFD = authoritativeRoot.fileDescriptor
            do {
                for operation in record.operations.reversed() {
                    try restoreRecoveryOperation(operation, repositoryFD: repositoryFD)
                }
                guard try RepositoryTree.capture(rootFD: repositoryFD, paths: paths) == record.beforeTree else {
                    throw FactoryValidationError(
                        code: "rollback_tree_mismatch",
                        message: "Crash recovery did not restore the exact original tree.",
                    )
                }
                try PatchRecoveryJournal.remove(at: recoveryRoot)
                return .restoredPreparedTransaction
            } catch {
                throw FactoryValidationError(
                    code: "patch_import_quarantined",
                    message: "Crash recovery failed; the worktree remains quarantined.",
                )
            }
        }
    }

    static func applyLocked(
        _ envelope: PatchEnvelope,
        authoritativeRoot: LockedAuthoritativeRoot,
        contentRoot: URL,
        recoveryRoot: URL,
        repositoryIdentity: (_ excluding: [RepositoryPath]) throws -> (base: GitObjectID, tree: GitObjectID),
        policy: PatchImportPolicy,
        fault: PatchImportFault = PatchImportFault(),
    ) throws -> PatchImportReceipt {
        let transaction = try prepareTransaction(
            envelope,
            authoritativeRoot: authoritativeRoot,
            contentRoot: contentRoot,
            recoveryRoot: recoveryRoot,
            repositoryIdentity: repositoryIdentity,
            policy: policy,
        )
        let repositoryFD = authoritativeRoot.fileDescriptor
        try PatchRecoveryJournal.writePrepared(transaction.recoveryRecord, at: recoveryRoot)
        var attempted: [PreparedOperation] = []
        var completed = false
        do {
            for operation in transaction.prepared {
                try validateLiveBefore(operation, repositoryFD: repositoryFD)
                attempted.append(operation)
                switch operation.operation.kind {
                case .create:
                    try SecureRepositoryFileSystem.atomicWrite(
                        rootFD: repositoryFD,
                        path: operation.operation.path,
                        data: operation.after!.data,
                        executable: operation.after!.executable,
                        createOnly: true,
                        transactionID: operation.operation.operationID,
                    )
                case .update:
                    try SecureRepositoryFileSystem.atomicWrite(
                        rootFD: repositoryFD,
                        path: operation.operation.path,
                        data: operation.after!.data,
                        executable: operation.after!.executable,
                        createOnly: false,
                        transactionID: operation.operation.operationID,
                    )
                case .delete:
                    try SecureRepositoryFileSystem.delete(rootFD: repositoryFD, path: operation.operation.path)
                }
                if fault.failAfterAppliedOperation == attempted.count {
                    throw FactoryValidationError(
                        code: "injected_import_failure",
                        message: "The deterministic rollback fixture fired.",
                    )
                }
                if fault.simulateProcessDeathAfterAppliedOperation == attempted.count {
                    throw SimulatedProcessDeath()
                }
            }
            try validateStableRepositoryIdentity(
                repositoryIdentity(transaction.paths),
                expected: transaction.outsideIdentity,
            )
            let afterTree = try RepositoryTree.capture(rootFD: repositoryFD, paths: transaction.paths)
            guard afterTree == transaction.expectedAfterTree else {
                throw FactoryValidationError(
                    code: "patch_output_changed",
                    message: "An authoritative patch output changed before transaction completion.",
                )
            }
            try PatchRecoveryJournal.replace(
                transaction.recoveryRecord.markingCompleted(with: afterTree),
                at: recoveryRoot,
            )
            completed = true
            let committedTree = try validateCompletedTransaction(
                repositoryFD: repositoryFD,
                transaction: transaction,
                repositoryIdentity: repositoryIdentity,
            )
            try? PatchRecoveryJournal.remove(at: recoveryRoot)
            return makeReceipt(envelope: envelope, beforeTree: transaction.beforeTree, afterTree: committedTree)
        } catch is SimulatedProcessDeath {
            throw FactoryValidationError(
                code: "simulated_process_death",
                message: "The test process stopped after a durable prepared journal.",
            )
        } catch {
            if completed {
                throw FactoryValidationError(
                    code: "patch_import_quarantined",
                    message: "A completed patch transaction changed before success could be reported.",
                )
            }
            try rollback(
                attempted,
                repositoryFD: repositoryFD,
                expected: transaction.beforeTree,
                paths: transaction.paths,
            )
            try? PatchRecoveryJournal.remove(at: recoveryRoot)
            if let validation = error as? FactoryValidationError {
                throw validation
            }
            throw FactoryValidationError(
                code: "patch_import_failed",
                message: "Patch import failed and was rolled back.",
            )
        }
    }

    private static func validateCompletedTransaction(
        repositoryFD: Int32,
        transaction: PreparedTransaction,
        repositoryIdentity: (_ excluding: [RepositoryPath]) throws -> (base: GitObjectID, tree: GitObjectID),
    ) throws -> RepositoryTree {
        try validateStableRepositoryIdentity(
            repositoryIdentity(transaction.paths),
            expected: transaction.outsideIdentity,
        )
        let committedTree = try RepositoryTree.capture(rootFD: repositoryFD, paths: transaction.paths)
        guard committedTree == transaction.expectedAfterTree else {
            throw FactoryValidationError(
                code: "patch_output_changed",
                message: "An authoritative patch output changed after durable transaction completion.",
            )
        }
        return committedTree
    }

    private static func prepareTransaction(
        _ envelope: PatchEnvelope,
        authoritativeRoot: LockedAuthoritativeRoot,
        contentRoot: URL,
        recoveryRoot: URL,
        repositoryIdentity: (_ excluding: [RepositoryPath]) throws -> (base: GitObjectID, tree: GitObjectID),
        policy: PatchImportPolicy,
    ) throws -> PreparedTransaction {
        try validateDistinctRoots(
            authoritativeRoot: authoritativeRoot.canonicalURL,
            contentRoot: contentRoot,
            recoveryRoot: recoveryRoot,
        )
        guard try !PatchRecoveryJournal.hasPending(at: recoveryRoot) else {
            throw FactoryValidationError(
                code: "patch_recovery_required",
                message: "A prior patch transaction must be reconciled first.",
            )
        }
        try validateEnvelopeStructure(envelope, policy: policy)
        let paths = envelope.operations.map(\.path)
        let outsideIdentity = try repositoryIdentity(paths)
        let fullIdentity = try repositoryIdentity([])
        try validateStableRepositoryIdentity(repositoryIdentity(paths), expected: outsideIdentity)
        try validateEnvelopeBinding(envelope, actualIdentity: fullIdentity, policy: policy)
        let repositoryFD = authoritativeRoot.fileDescriptor
        let beforeTree = try RepositoryTree.capture(rootFD: repositoryFD, paths: paths)
        let contentFD = try SecureRepositoryFileSystem.openDirectory(contentRoot)
        defer { Darwin.close(contentFD) }
        let prepared = try envelope.operations.map {
            try prepare($0, repositoryFD: repositoryFD, contentFD: contentFD, policy: policy)
        }
        try validateStableRepositoryIdentity(repositoryIdentity(paths), expected: outsideIdentity)
        let recoveryRecord = makeRecoveryRecord(envelope: envelope, beforeTree: beforeTree, prepared: prepared)
        try recoveryRecord.validate(
            maximumTotalBytes: min(policy.maximumTotalBytes, PatchRecoveryJournal.maximumRecoveryBytes),
        )
        return try PreparedTransaction(
            paths: paths,
            outsideIdentity: outsideIdentity,
            beforeTree: beforeTree,
            prepared: prepared,
            recoveryRecord: recoveryRecord,
            expectedAfterTree: recoveryRecord.expectedCompletedTree(),
        )
    }

    private static func restoreRecoveryOperation(
        _ operation: PatchRecoveryOperation,
        repositoryFD: Int32,
    ) throws {
        let live = try currentFile(for: operation, repositoryFD: repositoryFD)
        switch operation.kind {
        case .create:
            if live == nil { return }
            guard let after = operation.after, let live, expectation(after, matches: live) else {
                throw FactoryValidationError(
                    code: "recovery_state_changed",
                    message: "Recovery refused to delete bytes from another transaction.",
                )
            }
            try SecureRepositoryFileSystem.delete(rootFD: repositoryFD, path: operation.path)
        case .update:
            guard let before = operation.before else {
                throw FactoryValidationError(code: "invalid_patch_journal", message: "Recovery bytes are missing.")
            }
            if let live, expectation(before.expectation, matches: live) { return }
            guard let after = operation.after, let live, expectation(after, matches: live) else {
                throw FactoryValidationError(
                    code: "recovery_state_changed",
                    message: "Recovery refused to overwrite bytes from another transaction.",
                )
            }
            try SecureRepositoryFileSystem.atomicWrite(
                rootFD: repositoryFD,
                path: operation.path,
                data: before.data,
                executable: before.executable,
                createOnly: false,
                transactionID: "recovery-\(operation.operationID)",
            )
        case .delete:
            guard let before = operation.before else {
                throw FactoryValidationError(code: "invalid_patch_journal", message: "Recovery bytes are missing.")
            }
            if let live, expectation(before.expectation, matches: live) { return }
            guard live == nil else {
                throw FactoryValidationError(
                    code: "recovery_state_changed",
                    message: "Recovery refused to overwrite bytes from another transaction.",
                )
            }
            try SecureRepositoryFileSystem.atomicWrite(
                rootFD: repositoryFD,
                path: operation.path,
                data: before.data,
                executable: before.executable,
                createOnly: true,
                transactionID: "recovery-\(operation.operationID)",
            )
        }
    }

    private static func currentFile(
        for operation: PatchRecoveryOperation,
        repositoryFD: Int32,
    ) throws -> SecureRegularFile? {
        guard try SecureRepositoryFileSystem.entryExists(rootFD: repositoryFD, path: operation.path) else {
            return nil
        }
        let maximumBytes = max(operation.before?.data.count ?? 0, operation.after?.bytes ?? 0)
        return try SecureRepositoryFileSystem.readRegularFile(
            rootFD: repositoryFD,
            path: operation.path,
            allowedModes: [0o644, 0o755],
            maximumBytes: maximumBytes,
        )
    }

    private static func makeRecoveryRecord(
        envelope: PatchEnvelope,
        beforeTree: RepositoryTree,
        prepared: [PreparedOperation],
    ) -> PatchRecoveryRecord {
        PatchRecoveryRecord(
            schemaVersion: FactoryCore.schemaVersion,
            envelopeID: envelope.envelopeID,
            envelopeDigest: CanonicalJSON.digest(envelope),
            state: .prepared,
            beforeTree: beforeTree,
            completedTree: nil,
            operations: prepared.map { operation in
                PatchRecoveryOperation(
                    operationID: operation.operation.operationID,
                    path: operation.operation.path,
                    kind: operation.operation.kind,
                    before: operation.before.map { PatchRecoveryFile(data: $0.data, executable: $0.executable) },
                    after: operation.after.map { FileExpectation(data: $0.data, executable: $0.executable) },
                )
            },
        )
    }

    private static func makeReceipt(
        envelope: PatchEnvelope,
        beforeTree: RepositoryTree,
        afterTree: RepositoryTree,
    ) -> PatchImportReceipt {
        let operationIDs = envelope.operations.map(\.operationID)
        let payload = ReceiptPayload(
            envelopeID: envelope.envelopeID,
            beforeTree: beforeTree.digest,
            afterTree: afterTree.digest,
            operationIDs: operationIDs,
        )
        return PatchImportReceipt(
            envelopeID: envelope.envelopeID,
            beforeTree: beforeTree.digest,
            afterTree: afterTree.digest,
            operationIDs: operationIDs,
            receiptDigest: CanonicalJSON.digest(payload),
        )
    }

    private static func validateEnvelopeStructure(
        _ envelope: PatchEnvelope,
        policy: PatchImportPolicy,
    ) throws {
        try envelope.validateStructure(
            maximumOperations: policy.maximumOperations,
            maximumTotalBytes: min(policy.maximumTotalBytes, PatchRecoveryJournal.maximumRecoveryBytes),
        )
        guard envelope.contractSHA256 == policy.contractSHA256,
              envelope.invocationID == policy.expectedInvocationID,
              envelope.runID == policy.expectedRunID,
              envelope.projectionSHA256 == policy.projectionSHA256,
              envelope.policySHA256 == policy.digest
        else {
            throw FactoryValidationError(
                code: "patch_envelope_mismatch",
                message: "Patch scope, base, tree, or policy changed.",
            )
        }
        try validateOperations(envelope.operations, policy: policy)
    }

    private static func validateEnvelopeBinding(
        _ envelope: PatchEnvelope,
        actualIdentity: (base: GitObjectID, tree: GitObjectID),
        policy: PatchImportPolicy,
    ) throws {
        guard envelope.expectedBaseSHA == actualIdentity.base,
              envelope.expectedTreeSHA == actualIdentity.tree,
              envelope.contractSHA256 == policy.contractSHA256,
              envelope.invocationID == policy.expectedInvocationID,
              envelope.runID == policy.expectedRunID,
              envelope.projectionSHA256 == policy.projectionSHA256,
              envelope.policySHA256 == policy.digest
        else {
            throw FactoryValidationError(
                code: "patch_envelope_mismatch",
                message: "Patch scope, base, tree, or policy changed.",
            )
        }
    }

    private static func validateStableRepositoryIdentity(
        _ actual: (base: GitObjectID, tree: GitObjectID),
        expected: (base: GitObjectID, tree: GitObjectID),
    ) throws {
        guard actual.base == expected.base, actual.tree == expected.tree else {
            throw FactoryValidationError(
                code: "patch_repository_changed",
                message: "An unrelated authoritative path changed during patch import.",
            )
        }
    }

    private static func validateOperations(
        _ operations: [PatchFileOperation],
        policy: PatchImportPolicy,
    ) throws {
        for operation in operations {
            guard policy.allowedRoots.contains(where: { operation.path.isWithin($0) }) else {
                throw FactoryValidationError(
                    code: "patch_path_excluded",
                    message: "A patch path is outside the accepted contract.",
                )
            }
            if policy.purpose == .product, operation.path.isControlPlane {
                throw FactoryValidationError(
                    code: "product_control_plane_mutation",
                    message: "Product work cannot mutate factory policy.",
                )
            }
            if policy.purpose == .product, isSnapshotBaseline(operation.path) {
                throw FactoryValidationError(
                    code: "product_snapshot_baseline_mutation",
                    message: "Product work cannot mutate snapshot baselines.",
                )
            }
        }
    }

    private static func isSnapshotBaseline(_ path: RepositoryPath) -> Bool {
        path.collisionKey.split(separator: "/").contains("__snapshots__")
    }

    private static func prepare(
        _ operation: PatchFileOperation,
        repositoryFD: Int32,
        contentFD: Int32,
        policy: PatchImportPolicy,
    ) throws -> PreparedOperation {
        let existing: SecureRegularFile?
        switch operation.kind {
        case .create:
            guard try !SecureRepositoryFileSystem.entryExists(rootFD: repositoryFD, path: operation.path) else {
                throw FactoryValidationError(
                    code: "patch_create_exists",
                    message: "A create destination already exists.",
                )
            }
            existing = nil
        case .update, .delete:
            guard let before = operation.before.expectation else {
                throw FactoryValidationError(
                    code: "patch_before_mismatch",
                    message: "Existing bytes or mode differ from the envelope.",
                )
            }
            existing = try SecureRepositoryFileSystem.readRegularFile(
                rootFD: repositoryFD,
                path: operation.path,
                allowedModes: [0o644, 0o755],
                maximumBytes: before.bytes,
            )
            guard let existing,
                  expectation(before, matches: existing)
            else {
                throw FactoryValidationError(
                    code: "patch_before_mismatch",
                    message: "Existing bytes or mode differ from the envelope.",
                )
            }
        }

        let after: SecureRegularFile?
        if let payload = operation.after.payload {
            guard try payload.contentRef.isWithin(RepositoryPath(validating: "output/files")) else {
                throw FactoryValidationError(
                    code: "unsafe_content_reference",
                    message: "Patch content must live beneath the output files root.",
                )
            }
            let content = try SecureRepositoryFileSystem.readRegularFile(
                rootFD: contentFD,
                path: payload.contentRef,
                allowedModes: [0o600, 0o644],
                maximumBytes: payload.expectation.bytes,
            )
            guard payload.expectation.sha256 == SHA256Digest.hashing(content.data),
                  payload.expectation.bytes == content.data.count
            else {
                throw FactoryValidationError(
                    code: "patch_after_mismatch",
                    message: "Output bytes do not match the envelope.",
                )
            }
            switch payload.contentKind {
            case .text:
                guard payload.assetProvenance == nil,
                      !content.data.contains(0),
                      String(data: content.data, encoding: .utf8) != nil
                else {
                    throw FactoryValidationError(
                        code: "invalid_text_patch",
                        message: "Text patches must be UTF-8 without NUL bytes or asset metadata.",
                    )
                }
            case .asset:
                let fileName = operation.path.components.last ?? ""
                let fileExtension = fileName.split(separator: ".").last.map(String.init)?.lowercased() ?? ""
                guard fileName.contains("."),
                      policy.approvedAssetExtensions.contains(fileExtension),
                      isAssetAuthorized(payload, path: operation.path, policy: policy)
                else {
                    throw FactoryValidationError(
                        code: "unapproved_binary_asset",
                        message: "Binary assets require an approved extension and complete provenance.",
                    )
                }
            }
            after = SecureRegularFile(data: content.data, executable: payload.expectation.executable)
        } else {
            after = nil
        }
        return PreparedOperation(operation: operation, before: existing, after: after)
    }

    private static func isAssetAuthorized(
        _ payload: PatchFilePayload,
        path: RepositoryPath,
        policy: PatchImportPolicy,
    ) -> Bool {
        guard let provenance = payload.assetProvenance, provenance.isComplete else { return false }
        switch provenance.ownerApproval {
        case .required:
            return false
        case .notRequired:
            return provenance.sourceClass == .placeholder || provenance.sourceClass == .repositoryDerived
        case .approved:
            let binding = PatchImportPolicy.assetApprovalBindingSHA256(
                path: path,
                contentSHA256: payload.expectation.sha256,
                bytes: payload.expectation.bytes,
                provenance: provenance,
            )
            return policy.approvedAssetBindingsSHA256.contains(binding)
        }
    }

    private static func expectation(_ expectation: FileExpectation, matches file: SecureRegularFile) -> Bool {
        expectation.sha256 == SHA256Digest.hashing(file.data)
            && expectation.bytes == file.data.count
            && expectation.executable == file.executable
    }

    private static func validateLiveBefore(_ operation: PreparedOperation, repositoryFD: Int32) throws {
        let live = try currentFile(for: operation, repositoryFD: repositoryFD)
        let valid: Bool = switch operation.operation.kind {
        case .create:
            live == nil
        case .update, .delete:
            matches(live, expected: operation.before)
        }
        guard valid else {
            throw FactoryValidationError(
                code: "patch_before_changed",
                message: "An authoritative patch path changed after preflight.",
            )
        }
    }

    private static func rollback(
        _ attempted: [PreparedOperation],
        repositoryFD: Int32,
        expected: RepositoryTree,
        paths: [RepositoryPath],
    ) throws {
        do {
            for operation in attempted.reversed() {
                let path = operation.operation.path
                let live = try currentFile(for: operation, repositoryFD: repositoryFD)
                switch operation.operation.kind {
                case .create:
                    if live == nil { continue }
                    guard matches(live, expected: operation.after) else {
                        throw FactoryValidationError(
                            code: "rollback_state_changed",
                            message: "Rollback refused to overwrite another transaction's bytes.",
                        )
                    }
                    if try SecureRepositoryFileSystem.entryExists(rootFD: repositoryFD, path: path) {
                        try SecureRepositoryFileSystem.delete(rootFD: repositoryFD, path: path)
                    }
                case .update:
                    if matches(live, expected: operation.before) { continue }
                    guard matches(live, expected: operation.after) else {
                        throw FactoryValidationError(
                            code: "rollback_state_changed",
                            message: "Rollback refused to overwrite another transaction's bytes.",
                        )
                    }
                    let exists = try SecureRepositoryFileSystem.entryExists(rootFD: repositoryFD, path: path)
                    try SecureRepositoryFileSystem.atomicWrite(
                        rootFD: repositoryFD,
                        path: path,
                        data: operation.before!.data,
                        executable: operation.before!.executable,
                        createOnly: !exists,
                        transactionID: "rollback-\(operation.operation.operationID)",
                    )
                case .delete:
                    if matches(live, expected: operation.before) { continue }
                    guard live == nil else {
                        throw FactoryValidationError(
                            code: "rollback_state_changed",
                            message: "Rollback refused to overwrite another transaction's bytes.",
                        )
                    }
                    try SecureRepositoryFileSystem.atomicWrite(
                        rootFD: repositoryFD,
                        path: path,
                        data: operation.before!.data,
                        executable: operation.before!.executable,
                        createOnly: true,
                        transactionID: "rollback-\(operation.operation.operationID)",
                    )
                }
            }
            guard try RepositoryTree.capture(rootFD: repositoryFD, paths: paths) == expected else {
                throw FactoryValidationError(
                    code: "rollback_tree_mismatch",
                    message: "Rollback did not restore the exact original tree.",
                )
            }
        } catch {
            throw FactoryValidationError(
                code: "patch_import_quarantined",
                message: "Patch rollback failed; the worktree must be quarantined.",
            )
        }
    }

    private static func currentFile(
        for operation: PreparedOperation,
        repositoryFD: Int32,
    ) throws -> SecureRegularFile? {
        guard try SecureRepositoryFileSystem.entryExists(
            rootFD: repositoryFD,
            path: operation.operation.path,
        ) else {
            return nil
        }
        let maximumBytes = max(operation.before?.data.count ?? 0, operation.after?.data.count ?? 0)
        return try SecureRepositoryFileSystem.readRegularFile(
            rootFD: repositoryFD,
            path: operation.operation.path,
            allowedModes: [0o644, 0o755],
            maximumBytes: maximumBytes,
        )
    }

    private static func matches(_ observed: SecureRegularFile?, expected: SecureRegularFile?) -> Bool {
        guard let observed, let expected else { return observed == nil && expected == nil }
        return observed.data == expected.data && observed.executable == expected.executable
    }

    private struct PreparedOperation {
        let operation: PatchFileOperation
        let before: SecureRegularFile?
        let after: SecureRegularFile?
    }

    private struct PreparedTransaction {
        let paths: [RepositoryPath]
        let outsideIdentity: (base: GitObjectID, tree: GitObjectID)
        let beforeTree: RepositoryTree
        let prepared: [PreparedOperation]
        let recoveryRecord: PatchRecoveryRecord
        let expectedAfterTree: RepositoryTree
    }

    private struct SimulatedProcessDeath: Error {}

    private struct ReceiptPayload: Codable {
        let envelopeID: String
        let beforeTree: SHA256Digest
        let afterTree: SHA256Digest
        let operationIDs: [String]
    }

    private static func validateDistinctRoots(
        authoritativeRoot: URL,
        contentRoot: URL?,
        recoveryRoot: URL,
    ) throws {
        let authoritative = try SecureRepositoryFileSystem.canonicalExistingURL(authoritativeRoot)
        let recovery = try SecureRepositoryFileSystem.canonicalExistingURL(recoveryRoot)
        var roots = [authoritative, recovery]
        if let contentRoot {
            try roots.append(SecureRepositoryFileSystem.canonicalExistingURL(contentRoot))
        }
        for leftIndex in roots.indices {
            for rightIndex in roots.indices where rightIndex > leftIndex {
                guard !isWithin(roots[leftIndex], root: roots[rightIndex]),
                      !isWithin(roots[rightIndex], root: roots[leftIndex])
                else {
                    throw FactoryValidationError(
                        code: "overlapping_patch_roots",
                        message: "Authoritative, content, and recovery roots must be disjoint.",
                    )
                }
            }
        }
    }

    private static func isWithin(_ candidate: URL, root: URL) -> Bool {
        let rootPath = root.path.hasSuffix("/") ? String(root.path.dropLast()) : root.path
        return candidate.path == rootPath || candidate.path.hasPrefix(rootPath + "/")
    }
}
