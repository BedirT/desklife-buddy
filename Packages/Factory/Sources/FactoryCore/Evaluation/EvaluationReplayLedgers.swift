import CryptoKit
import Foundation

/// Durable controller-side one-shot ledger for verified aggregate attestations.
public final class EvaluationAttestationReplayLedger {
    private static let maximumEntries = 100_000
    private let epochSHA256: SHA256Digest
    private let partition: EvaluationPartition
    private let root: URL

    package static func initialize(
        at root: URL,
        partition: EvaluationPartition,
        epochSHA256: SHA256Digest,
    ) throws -> EvaluationAttestationReplayLedger {
        let ledger = EvaluationAttestationReplayLedger(
            root: root,
            partition: partition,
            epochSHA256: epochSHA256,
        )
        let state = ReplayState(
            consumedAttestationSHA256: [],
            epochSHA256: epochSHA256,
            partition: partition,
            schemaVersion: FactoryCore.schemaVersion,
        )
        let document = ReplayDocument(headSHA256: CanonicalJSON.digest(state), state: state)
        try EvaluationLedgerFileStore.initialize(at: root, kind: .attestationReplay, document: document) {
            try ledger.validate($0)
        }
        return ledger
    }

    package convenience init(
        opening root: URL,
        partition: EvaluationPartition,
        epochSHA256: SHA256Digest,
    ) throws {
        self.init(root: root, partition: partition, epochSHA256: epochSHA256)
        _ = try EvaluationLedgerFileStore.snapshot(at: root, kind: .attestationReplay) {
            try self.validate($0 as ReplayDocument)
        }
    }

    private init(root: URL, partition: EvaluationPartition, epochSHA256: SHA256Digest) {
        self.root = root
        self.partition = partition
        self.epochSHA256 = epochSHA256
    }

    func consume(_ attestation: AggregateAttestation) throws {
        _ = try EvaluationLedgerFileStore.update(at: root, kind: .attestationReplay) { document in
            let document = document as ReplayDocument
            try validate(document)
            let digest = CanonicalJSON.digest(AttestationReplayIdentity(attestation: attestation))
            guard attestation.partition == partition,
                  attestation.epochSHA256 == epochSHA256,
                  document.state.consumedAttestationSHA256.count < Self.maximumEntries,
                  !document.state.consumedAttestationSHA256.contains(digest)
            else {
                throw FactoryValidationError(
                    code: "attestation_replay",
                    message: "The attestation was already consumed or belongs to another result channel.",
                )
            }
            let state = ReplayState(
                consumedAttestationSHA256: (document.state.consumedAttestationSHA256 + [digest])
                    .sorted { $0.rawValue < $1.rawValue },
                epochSHA256: epochSHA256,
                partition: partition,
                schemaVersion: FactoryCore.schemaVersion,
            )
            let updated = ReplayDocument(headSHA256: CanonicalJSON.digest(state), state: state)
            try validate(updated)
            return (updated, ())
        }
    }

    private func validate(_ document: ReplayDocument) throws {
        let consumed = document.state.consumedAttestationSHA256
        guard document.state.schemaVersion == FactoryCore.schemaVersion,
              document.state.partition == partition,
              document.state.epochSHA256 == epochSHA256,
              consumed.count <= Self.maximumEntries,
              consumed == consumed.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(consumed).count == consumed.count,
              document.headSHA256 == CanonicalJSON.digest(document.state)
        else {
            throw FactoryValidationError(
                code: "invalid_attestation_replay_ledger",
                message: "The durable attestation replay ledger is malformed or cross-partition.",
            )
        }
    }
}

/// Durable private-executor one-shot consumption for signed reservation capabilities.
public final class EvaluationAuthorizationReplayLedger {
    private static let maximumEntries = 100_000
    private let epochSHA256: SHA256Digest
    private let partition: EvaluationPartition
    private let root: URL

    package static func initialize(
        at root: URL,
        partition: EvaluationPartition,
        epochSHA256: SHA256Digest,
    ) throws -> EvaluationAuthorizationReplayLedger {
        let ledger = EvaluationAuthorizationReplayLedger(
            root: root,
            partition: partition,
            epochSHA256: epochSHA256,
        )
        let state = AuthorizationReplayState(
            consumedAuthorizationSHA256: [],
            epochSHA256: epochSHA256,
            partition: partition,
            schemaVersion: FactoryCore.schemaVersion,
        )
        let document = AuthorizationReplayDocument(
            headSHA256: CanonicalJSON.digest(state),
            state: state,
        )
        try EvaluationLedgerFileStore.initialize(
            at: root,
            kind: .executionAuthorizationReplay,
            document: document,
        ) {
            try ledger.validate($0)
        }
        return ledger
    }

    package convenience init(
        opening root: URL,
        partition: EvaluationPartition,
        epochSHA256: SHA256Digest,
    ) throws {
        self.init(root: root, partition: partition, epochSHA256: epochSHA256)
        _ = try EvaluationLedgerFileStore.snapshot(at: root, kind: .executionAuthorizationReplay) {
            try self.validate($0 as AuthorizationReplayDocument)
        }
    }

    private init(root: URL, partition: EvaluationPartition, epochSHA256: SHA256Digest) {
        self.root = root
        self.partition = partition
        self.epochSHA256 = epochSHA256
    }

    package func consume(
        _ authorization: EvaluationExecutionAuthorization,
        request: EvaluationRequest,
        reservationSHA256: SHA256Digest,
        now: String,
        evaluatorPublicKey: Curve25519.Signing.PublicKey,
    ) throws -> SHA256Digest {
        try authorization.verify(
            request: request,
            reservationSHA256: reservationSHA256,
            now: now,
            publicKey: evaluatorPublicKey,
        )
        return try EvaluationLedgerFileStore.update(at: root, kind: .executionAuthorizationReplay) { document in
            let document = document as AuthorizationReplayDocument
            try validate(document)
            let digest = authorization.digest
            guard authorization.partition == partition,
                  authorization.epochSHA256 == epochSHA256,
                  document.state.consumedAuthorizationSHA256.count < Self.maximumEntries,
                  !document.state.consumedAuthorizationSHA256.contains(digest)
            else {
                throw FactoryValidationError(
                    code: "execution_authorization_replay",
                    message: "The private execution authorization was already consumed or is cross-partition.",
                )
            }
            let state = AuthorizationReplayState(
                consumedAuthorizationSHA256: (document.state.consumedAuthorizationSHA256 + [digest])
                    .sorted { $0.rawValue < $1.rawValue },
                epochSHA256: epochSHA256,
                partition: partition,
                schemaVersion: FactoryCore.schemaVersion,
            )
            let updated = AuthorizationReplayDocument(
                headSHA256: CanonicalJSON.digest(state),
                state: state,
            )
            try validate(updated)
            return (updated, updated.headSHA256)
        }
    }

    private func validate(_ document: AuthorizationReplayDocument) throws {
        let consumed = document.state.consumedAuthorizationSHA256
        guard document.state.schemaVersion == FactoryCore.schemaVersion,
              document.state.partition == partition,
              document.state.epochSHA256 == epochSHA256,
              consumed.count <= Self.maximumEntries,
              consumed == consumed.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(consumed).count == consumed.count,
              document.headSHA256 == CanonicalJSON.digest(document.state)
        else {
            throw FactoryValidationError(
                code: "invalid_execution_authorization_ledger",
                message: "The durable private-executor authorization ledger is malformed or cross-partition.",
            )
        }
    }
}
