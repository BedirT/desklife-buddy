import CryptoKit
import Darwin
import Foundation

/// Read-only durable broker state summary without replay nonce disclosure.
public struct BrokerCASSnapshot: Equatable, Sendable {
    public let activationReceiptSHA256: SHA256Digest?
    public let auditEntries: [BrokerAuditEntry]
    public let consumedNonceCount: Int
    public let isActivated: Bool
    public let state: BrokerState

    public init(
        activationReceiptSHA256: SHA256Digest?,
        auditEntries: [BrokerAuditEntry],
        consumedNonceCount: Int,
        isActivated: Bool,
        state: BrokerState,
    ) {
        self.activationReceiptSHA256 = activationReceiptSHA256
        self.auditEntries = auditEntries
        self.consumedNonceCount = consumedNonceCount
        self.isActivated = isActivated
        self.state = state
    }
}

/// Descriptor-backed, locked compare-and-swap document for broker state, replay, and audit facts.
package enum BrokerCASStore {
    private static let lockName = "broker.lock"
    private static let stateName = "broker-state.json"
    private static let temporaryName = ".broker-state.tmp"
    private static let maximumDocumentBytes = 16 * 1024 * 1024

    /// Creates a new empty audit/replay root. Existing state is never overwritten.
    package static func initialize(at root: URL, state: BrokerState, policy: BrokerPolicy) throws {
        try BrokerRequestValidator.validatePolicy(policy)
        guard state.policyDigest == policy.digest,
              state.priorAuditSequence == 0,
              state.priorAuditDigest == SHA256Digest.hashing(Data())
        else {
            throw FactoryValidationError(
                code: "invalid_broker_genesis",
                message: "A new durable broker root must begin at the zero audit predecessor.",
            )
        }
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        try withLock(rootFD: rootFD, exclusive: true) {
            guard try entryStatus(rootFD: rootFD, name: stateName) == .missing else {
                throw FactoryValidationError(
                    code: "broker_state_exists",
                    message: "Durable broker state already exists.",
                )
            }
            let document = BrokerCASDocument(
                activationReceipt: nil,
                auditEntries: [],
                consumedNonceSHA256: [],
                policy: policy,
                schemaVersion: FactoryCore.schemaVersion,
                state: state,
            )
            try validate(document, publicKey: nil)
            try write(document, rootFD: rootFD, createOnly: true)
        }
    }

    /// Loads and verifies the complete durable chain under a shared lock.
    package static func snapshot(
        at root: URL,
        publicKey: Curve25519.Signing.PublicKey,
        afterLockAcquisition: () throws -> Void = {},
    ) throws -> BrokerCASSnapshot {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try withLock(rootFD: rootFD, exclusive: false) {
            try afterLockAcquisition()
            let document = try read(rootFD: rootFD)
            try validate(document, publicKey: publicKey)
            return BrokerCASSnapshot(
                activationReceiptSHA256: document.activationReceipt?.digest,
                auditEntries: document.auditEntries,
                consumedNonceCount: document.consumedNonceSHA256.count,
                isActivated: document.activationReceipt != nil,
                state: document.state,
            )
        }
    }

    /// Installs one owner-signed trusted root activation capability under the same durable lock.
    static func activate(
        at root: URL,
        anchor: BrokerTrustAnchor,
        receipt: BrokerActivationReceipt,
        now: String,
    ) throws -> BrokerCASSnapshot {
        try anchor.validateStateRoot(root)
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try withLock(rootFD: rootFD, exclusive: true) {
            let current = try read(rootFD: rootFD)
            guard current.activationReceipt == nil,
                  let auditPublicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: receipt.auditPublicKey),
                  try BrokerActivationAuthority.verifyForActivation(
                      receipt,
                      anchor: anchor,
                      policy: current.policy,
                      state: current.state,
                      now: now,
                  )
            else {
                throw FactoryValidationError(
                    code: "invalid_broker_activation",
                    message: "Broker activation is missing, repeated, stale, or bound to another root.",
                )
            }
            try validate(current, publicKey: auditPublicKey)
            let (generation, overflow) = current.state.generation.addingReportingOverflow(1)
            guard !overflow else {
                throw FactoryValidationError(
                    code: "broker_generation_overflow",
                    message: "Broker generation is exhausted.",
                )
            }
            let activatedState = BrokerState(
                runID: current.state.runID,
                issueNumber: current.state.issueNumber,
                pullRequestNumber: current.state.pullRequestNumber,
                contractDigest: current.state.contractDigest,
                head: current.state.head,
                tree: current.state.tree,
                generation: generation,
                leaseID: current.state.leaseID,
                policyDigest: current.state.policyDigest,
                priorAuditSequence: current.state.priorAuditSequence,
                priorAuditDigest: current.state.priorAuditDigest,
            )
            let updated = BrokerCASDocument(
                activationReceipt: receipt,
                auditEntries: current.auditEntries,
                consumedNonceSHA256: current.consumedNonceSHA256,
                policy: current.policy,
                schemaVersion: FactoryCore.schemaVersion,
                state: activatedState,
            )
            try validate(updated, publicKey: auditPublicKey)
            try write(updated, rootFD: rootFD, createOnly: false)
            return BrokerCASSnapshot(
                activationReceiptSHA256: receipt.digest,
                auditEntries: updated.auditEntries,
                consumedNonceCount: updated.consumedNonceSHA256.count,
                isActivated: true,
                state: updated.state,
            )
        }
    }

    /// Atomically consumes one nonce and advances the CAS/audit predecessor together.
    package static func compareAndSwap(
        at root: URL,
        request: BrokerRequest,
        policy: BrokerPolicy,
        nextState: BrokerState,
        auditEntry: BrokerAuditEntry,
        auditPublicKey: Curve25519.Signing.PublicKey,
        now: String,
    ) throws -> BrokerResponse {
        let rootFD = try openRoot(root)
        defer { Darwin.close(rootFD) }
        return try withLock(rootFD: rootFD, exclusive: true) {
            let current = try read(rootFD: rootFD)
            try validate(current, publicKey: auditPublicKey)
            guard policy == current.policy else {
                throw FactoryValidationError(
                    code: "wrong_broker_policy",
                    message: "Broker policy differs from genesis.",
                )
            }
            let authority: BrokerAuthorityMode = current
                .activationReceipt == nil ? .buildCandidateFixtureOnly : .activated
            try BrokerRequestValidator.validateSemantics(
                request,
                policy: current.policy,
                state: current.state,
                authority: authority,
                now: now,
            )
            let nonceSHA256 = SHA256Digest.hashing(Data(request.nonce.utf8))
            guard !current.consumedNonceSHA256.contains(nonceSHA256) else {
                throw FactoryValidationError(
                    code: "broker_replay",
                    message: "The broker nonce was already consumed by durable state.",
                )
            }
            guard current.consumedNonceSHA256.count < policy.maximumReplayEntries else {
                throw FactoryValidationError(
                    code: "broker_replay_budget",
                    message: "The durable replay ledger reached its trusted ceiling.",
                )
            }
            guard auditEntry.decision == .accepted,
                  auditEntry.brokerIdentitySHA256 == current.policy.brokerIdentitySHA256,
                  current.activationReceipt.map({ $0.auditPublicKey == auditPublicKey.rawRepresentation }) ?? true,
                  try BrokerAuditChain.verify(auditEntry, request: request, publicKey: auditPublicKey),
                  auditEntry.nextStateSHA256 == CanonicalJSON.digest(nextState)
            else {
                throw FactoryValidationError(
                    code: "invalid_broker_audit",
                    message: "The audit entry is not the signed successor for this request.",
                )
            }
            try validateTransition(
                from: current.state,
                to: nextState,
                operation: request.operation,
                policy: current.policy,
                auditEntry: auditEntry,
            )

            let updated = BrokerCASDocument(
                activationReceipt: current.activationReceipt,
                auditEntries: current.auditEntries + [auditEntry],
                consumedNonceSHA256: (current.consumedNonceSHA256 + [nonceSHA256]).sorted { $0.rawValue < $1.rawValue },
                policy: current.policy,
                schemaVersion: FactoryCore.schemaVersion,
                state: nextState,
            )
            try validate(updated, publicKey: auditPublicKey)
            try write(updated, rootFD: rootFD, createOnly: false)
            return BrokerResponse(
                requestID: request.requestID,
                decision: .accepted,
                reasonCode: auditEntry.reasonCode,
                receiptSHA256: auditEntry.resultSHA256,
                auditSequence: auditEntry.sequence,
                auditSHA256: auditEntry.entrySHA256,
            )
        }
    }
}

private extension BrokerCASStore {
    private static func validate(
        _ document: BrokerCASDocument,
        publicKey: Curve25519.Signing.PublicKey?,
    ) throws {
        try BrokerRequestValidator.validatePolicy(document.policy)
        let signedNonceSHA256 = document.auditEntries
            .map(\.nonceSHA256)
            .sorted { $0.rawValue < $1.rawValue }
        guard document.schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(document.state.runID),
              document.state.issueNumber > 0,
              document.state.pullRequestNumber.map({
                  $0 > 0 && $0 <= document.policy.maximumPullRequestNumber
              }) ?? true,
              document.state.generation > 0,
              FactoryTextRules.isStableID(document.state.leaseID),
              document.state.policyDigest == document.policy.digest,
              document.consumedNonceSHA256 == document.consumedNonceSHA256.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(document.consumedNonceSHA256).count == document.consumedNonceSHA256.count,
              document.consumedNonceSHA256 == signedNonceSHA256,
              document.auditEntries.count == document.state.priorAuditSequence
        else {
            throw FactoryValidationError(
                code: "invalid_broker_state",
                message: "Durable broker state is malformed or noncanonical.",
            )
        }
        var expectedAuditTerminalSHA256 = CanonicalJSON.digest(document.state)
        if let receipt = document.activationReceipt {
            guard let installedAuditKey = try? Curve25519.Signing.PublicKey(
                rawRepresentation: receipt.auditPublicKey,
            ),
                publicKey?.rawRepresentation == installedAuditKey.rawRepresentation,
                try BrokerActivationAuthority.verifyInstalled(
                    receipt,
                    policy: document.policy,
                    state: document.state,
                )
            else {
                throw FactoryValidationError(
                    code: "invalid_broker_activation",
                    message: "Durable broker activation is corrupt or uses another audit identity.",
                )
            }

            let (activationGeneration, overflow) = receipt.priorGeneration.addingReportingOverflow(1)
            let preactivationState = BrokerState(
                runID: document.state.runID,
                issueNumber: document.state.issueNumber,
                pullRequestNumber: document.state.pullRequestNumber,
                contractDigest: document.state.contractDigest,
                head: document.state.head,
                tree: document.state.tree,
                generation: receipt.priorGeneration,
                leaseID: document.state.leaseID,
                policyDigest: document.state.policyDigest,
                priorAuditSequence: document.state.priorAuditSequence,
                priorAuditDigest: document.state.priorAuditDigest,
            )
            let isExactActivationState = !overflow
                && document.state.generation == activationGeneration
                && CanonicalJSON.digest(preactivationState) == receipt.stateSHA256
            if isExactActivationState {
                expectedAuditTerminalSHA256 = CanonicalJSON.digest(preactivationState)
            } else {
                guard !document.auditEntries.isEmpty else {
                    throw FactoryValidationError(
                        code: "invalid_broker_state",
                        message: "The current broker state is not the signed terminal transition.",
                    )
                }
            }
        }
        if document.auditEntries.isEmpty {
            guard document.state.priorAuditSequence == 0,
                  document.state.priorAuditDigest == SHA256Digest.hashing(Data())
            else {
                throw FactoryValidationError(
                    code: "invalid_broker_state",
                    message: "Empty audit state must use the zero predecessor.",
                )
            }
        } else {
            guard let publicKey,
                  document.auditEntries.last?.nextStateSHA256 == expectedAuditTerminalSHA256,
                  try BrokerAuditChain.verify(
                      document.auditEntries,
                      expectedCount: document.auditEntries.count,
                      expectedHeadSHA256: document.state.priorAuditDigest,
                      publicKey: publicKey,
                  )
            else {
                throw FactoryValidationError(
                    code: "invalid_broker_state",
                    message: "The durable audit chain is incomplete or has an invalid signature.",
                )
            }
        }
    }

    private static func openRoot(_ root: URL) throws -> Int32 {
        guard root.isFileURL,
              root.path.hasPrefix("/"),
              root.path != "/",
              !root.path.hasSuffix("/"),
              !root.path.contains("//"),
              root.path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              URL(fileURLWithPath: root.path).path == root.path
        else {
            throw FactoryValidationError(
                code: "unsafe_broker_state_root",
                message: "Durable broker state requires a canonical absolute directory.",
            )
        }
        var endpoint = stat()
        guard Darwin.lstat(root.path, &endpoint) == 0,
              endpoint.st_mode & S_IFMT == S_IFDIR
        else {
            throw FactoryValidationError(
                code: "unsafe_broker_state_root",
                message: "Durable broker state requires a real directory.",
            )
        }
        let components = root.pathComponents.filter { $0 != "/" }
        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0,
              BrokerFilesystemSecurity.isSecureDirectory(
                  fileDescriptor: directoryFD,
                  allowedOwnerUIDs: [0, geteuid()],
              )
        else {
            throw FactoryValidationError(
                code: "unsafe_broker_state_root",
                message: "Broker state ancestry must reject ambient write authority.",
            )
        }
        var keepDirectory = false
        defer {
            if !keepDirectory { Darwin.close(directoryFD) }
        }
        let brokerUserID = geteuid()
        for (index, component) in components.enumerated() {
            let nextFD = Darwin.openat(
                directoryFD,
                component,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            )
            guard nextFD >= 0 else { throw posixError("open_broker_root") }
            var metadata = stat()
            let isLeaf = index == components.index(before: components.endIndex)
            let valid = Darwin.fstat(nextFD, &metadata) == 0
                && metadata.st_mode & S_IFMT == S_IFDIR
                && (isLeaf ? metadata.st_uid == brokerUserID : [uid_t(0), brokerUserID].contains(metadata.st_uid))
                && metadata.st_mode & 0o022 == 0
                && (!isLeaf || metadata.st_mode & 0o777 == 0o700)
                && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
            guard valid else {
                Darwin.close(nextFD)
                throw FactoryValidationError(
                    code: "unsafe_broker_state_root",
                    message: "Broker state ancestry must be root- or broker-owned and non-writable by other users.",
                )
            }
            Darwin.close(directoryFD)
            directoryFD = nextFD
        }
        keepDirectory = true
        return directoryFD
    }

    private static func withLock<T>(
        rootFD: Int32,
        exclusive: Bool,
        operation: () throws -> T,
    ) throws -> T {
        let lockFD = try lock(rootFD: rootFD, exclusive: exclusive)
        defer { unlockAndClose(lockFD) }
        do {
            let result = try operation()
            try validateInstalledEntry(fd: lockFD, rootFD: rootFD, name: lockName)
            return result
        } catch let operationError {
            try validateInstalledEntry(fd: lockFD, rootFD: rootFD, name: lockName)
            throw operationError
        }
    }

    private static func lock(rootFD: Int32, exclusive: Bool) throws -> Int32 {
        let fd = Darwin.openat(rootFD, lockName, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw posixError("open_broker_lock") }
        do {
            try validateRegularFile(fd: fd, expectedMode: 0o600)
            var lock = Darwin.flock()
            lock.l_type = Int16(exclusive ? F_WRLCK : F_RDLCK)
            lock.l_whence = Int16(SEEK_SET)
            guard Darwin.fcntl(fd, F_SETLKW, &lock) == 0 else { throw posixError("lock_broker_state") }
            try validateInstalledEntry(fd: fd, rootFD: rootFD, name: lockName)
            return fd
        } catch {
            Darwin.close(fd)
            throw error
        }
    }

    private static func unlockAndClose(_ fd: Int32) {
        var lock = Darwin.flock()
        lock.l_type = Int16(F_UNLCK)
        lock.l_whence = Int16(SEEK_SET)
        _ = Darwin.fcntl(fd, F_SETLK, &lock)
        Darwin.close(fd)
    }

    private static func read(rootFD: Int32) throws -> BrokerCASDocument {
        let fd = Darwin.openat(rootFD, stateName, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw posixError("open_broker_state") }
        defer { Darwin.close(fd) }
        try validateRegularFile(fd: fd, expectedMode: 0o600)
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_size >= 0,
              metadata.st_size <= maximumDocumentBytes
        else {
            throw FactoryValidationError(
                code: "broker_state_budget",
                message: "The durable broker state exceeds its fixed byte ceiling.",
            )
        }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        let expectedBytes = Int(metadata.st_size)
        var data = Data()
        data.reserveCapacity(expectedBytes)
        while data.count < expectedBytes {
            let count = min(64 * 1024, expectedBytes - data.count)
            guard let chunk = try handle.read(upToCount: count), !chunk.isEmpty else {
                throw FactoryValidationError(
                    code: "broker_state_changed",
                    message: "Durable broker state changed while it was read.",
                )
            }
            data.append(chunk)
        }
        let overflow = try handle.read(upToCount: 1) ?? Data()
        var observed = stat()
        var installed = stat()
        guard overflow.isEmpty,
              Darwin.fstat(fd, &observed) == 0,
              Darwin.fstatat(rootFD, stateName, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(metadata, observed),
              stableIdentity(metadata, installed)
        else {
            throw FactoryValidationError(
                code: "broker_state_changed",
                message: "Durable broker state changed while it was read.",
            )
        }
        return try CanonicalJSON.decode(BrokerCASDocument.self, from: data)
    }

    private static func write(
        _ document: BrokerCASDocument,
        rootFD: Int32,
        createOnly: Bool,
    ) throws {
        if try entryStatus(rootFD: rootFD, name: temporaryName) == .regular {
            guard Darwin.unlinkat(rootFD, temporaryName, 0) == 0 else {
                throw posixError("remove_broker_temporary")
            }
        }
        let data = try CanonicalJSON.encode(document)
        guard data.count <= maximumDocumentBytes else {
            throw FactoryValidationError(
                code: "broker_state_budget",
                message: "The durable broker state exceeds its fixed byte ceiling.",
            )
        }
        let temporaryFD = Darwin.openat(
            rootFD,
            temporaryName,
            O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
            0o600,
        )
        guard temporaryFD >= 0 else { throw posixError("create_broker_temporary") }
        var keepTemporary = true
        defer {
            Darwin.close(temporaryFD)
            if keepTemporary { Darwin.unlinkat(rootFD, temporaryName, 0) }
        }
        let handle = FileHandle(fileDescriptor: temporaryFD, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard Darwin.fchmod(temporaryFD, 0o600) == 0,
              Darwin.fsync(temporaryFD) == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: temporaryFD)
        else {
            throw posixError("sync_broker_temporary")
        }
        let status: Int32
        if createOnly {
            status = Darwin.renameatx_np(rootFD, temporaryName, rootFD, stateName, UInt32(RENAME_EXCL))
        } else {
            guard try entryStatus(rootFD: rootFD, name: stateName) == .regular else {
                throw FactoryValidationError(
                    code: "missing_broker_state",
                    message: "Durable broker state disappeared before replacement.",
                )
            }
            status = Darwin.renameat(rootFD, temporaryName, rootFD, stateName)
        }
        guard status == 0, Darwin.fsync(rootFD) == 0 else {
            throw posixError("commit_broker_state")
        }
        keepTemporary = false
        let observed = try read(rootFD: rootFD)
        guard observed == document else {
            throw FactoryValidationError(
                code: "broker_state_verification",
                message: "Durable broker bytes differ after atomic replacement.",
            )
        }
    }

    private enum EntryStatus {
        case missing
        case regular
    }

    private static func entryStatus(rootFD: Int32, name: String) throws -> EntryStatus {
        let fd = Darwin.openat(rootFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        if fd >= 0 {
            defer { Darwin.close(fd) }
            try validateRegularFile(fd: fd, expectedMode: 0o600)
            try validateInstalledEntry(fd: fd, rootFD: rootFD, name: name)
            return .regular
        }
        if errno == ENOENT { return .missing }
        throw posixError("inspect_broker_state")
    }

    private static func validateRegularFile(fd: Int32, expectedMode: mode_t) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == geteuid(),
              metadata.st_nlink == 1,
              metadata.st_mode & 0o777 == expectedMode,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_broker_state_file",
                message: "Broker state entries must be private one-link regular files.",
            )
        }
    }

    private static func validateInstalledEntry(fd: Int32, rootFD: Int32, name: String) throws {
        var descriptor = stat()
        var installed = stat()
        guard Darwin.fstat(fd, &descriptor) == 0,
              Darwin.fstatat(rootFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(descriptor, installed)
        else {
            throw FactoryValidationError(
                code: "broker_state_changed",
                message: "The installed broker state entry changed identity while in use.",
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
        FactoryValidationError(
            code: code,
            message: "The durable broker filesystem operation failed with errno \(errno).",
        )
    }

    private struct BrokerCASDocument: Codable, Equatable {
        @RequiredNullable var activationReceipt: BrokerActivationReceipt?
        let auditEntries: [BrokerAuditEntry]
        let consumedNonceSHA256: [SHA256Digest]
        let policy: BrokerPolicy
        let schemaVersion: Int
        let state: BrokerState
    }
}

private extension BrokerCASStore {
    static func validateTransition(
        from current: BrokerState,
        to next: BrokerState,
        operation: BrokerOperation,
        policy: BrokerPolicy,
        auditEntry: BrokerAuditEntry,
    ) throws {
        let (expectedGeneration, overflow) = current.generation.addingReportingOverflow(1)
        let isPullRequestBinding: Bool = if case let .githubTransaction(transaction) = operation {
            transaction.transaction == .createPR
        } else {
            false
        }
        let hasValidPullRequestBinding = if isPullRequestBinding {
            current.pullRequestNumber == nil
                && next.pullRequestNumber.map { $0 > 0 && $0 <= policy.maximumPullRequestNumber } == true
        } else {
            next.pullRequestNumber == current.pullRequestNumber
        }
        guard !overflow,
              next.runID == current.runID,
              next.issueNumber == current.issueNumber,
              hasValidPullRequestBinding,
              next.contractDigest == current.contractDigest,
              next.generation == expectedGeneration,
              next.leaseID == current.leaseID,
              next.policyDigest == current.policyDigest,
              next.priorAuditSequence == auditEntry.sequence,
              next.priorAuditDigest == auditEntry.entrySHA256,
              auditEntry.nextStateSHA256 == CanonicalJSON.digest(next)
        else {
            throw FactoryValidationError(
                code: "invalid_broker_transition",
                message: "The proposed durable state broadens or skips its CAS predecessor.",
            )
        }
        switch operation {
        case .importPatch:
            guard next.head == current.head, next.tree != current.tree else {
                throw FactoryValidationError(
                    code: "invalid_broker_transition",
                    message: "Patch import must change only the authoritative working tree.",
                )
            }
        case .commitCheckpoint:
            guard next.head != current.head, next.tree == current.tree else {
                throw FactoryValidationError(
                    code: "invalid_broker_transition",
                    message: "A checkpoint commit must advance the head without changing the imported tree.",
                )
            }
        default:
            guard next.head == current.head, next.tree == current.tree else {
                throw FactoryValidationError(
                    code: "invalid_broker_transition",
                    message: "This broker operation cannot mutate the authoritative Git identity.",
                )
            }
        }
    }
}
