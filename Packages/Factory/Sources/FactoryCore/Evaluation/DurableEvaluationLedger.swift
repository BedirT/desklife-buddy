import CryptoKit
import Darwin
import Foundation

/// Durable partition-scoped query budget. A reservation is committed before private execution begins.
public final class EvaluationQueryLedger {
    static let maximumEntries = 100_000
    let partition: EvaluationPartition
    let policy: EvolutionAcceptancePolicy
    let root: URL

    package static func initialize(
        at root: URL,
        partition: EvaluationPartition,
        policy: EvolutionAcceptancePolicy,
    ) throws -> EvaluationQueryLedger {
        let ledger = EvaluationQueryLedger(root: root, partition: partition, policy: policy)
        let state = QueryState(
            completions: [],
            epochSHA256: ledger.epochSHA256,
            evaluatorSHA256: policy.evaluatorSHA256,
            maximumSelectionQueries: policy.maximumSelectionQueries,
            partition: partition,
            policySHA256: policy.digest,
            reservations: [],
            schemaVersion: FactoryCore.schemaVersion,
            trustedBaseSHA: policy.trustedRootSHA,
        )
        let document = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
        try EvaluationLedgerFileStore.initialize(at: root, kind: .query, document: document) {
            try ledger.validate($0)
        }
        return ledger
    }

    package convenience init(
        opening root: URL,
        partition: EvaluationPartition,
        policy: EvolutionAcceptancePolicy,
    ) throws {
        self.init(root: root, partition: partition, policy: policy)
        _ = try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) {
            try self.validate($0 as QueryDocument)
        }
    }

    private init(root: URL, partition: EvaluationPartition, policy: EvolutionAcceptancePolicy) {
        self.root = root
        self.partition = partition
        self.policy = policy
    }

    func reserve(_ request: EvaluationRequest) throws -> SHA256Digest {
        try policy.validate(request)
        return try EvaluationLedgerFileStore.update(at: root, kind: .query) { document in
            try self.reserving(request, in: document as QueryDocument)
        }
    }

    @discardableResult
    func requirePending(_ request: EvaluationRequest) throws -> SHA256Digest {
        try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try self.validate(document)
            return try self.pendingReservation(for: request, in: document).digest
        }
    }

    func reservationSHA256(for request: EvaluationRequest) throws -> SHA256Digest {
        try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try self.validate(document)
            guard request.partition == self.partition,
                  request.epochSHA256 == self.epochSHA256,
                  let reservation = document.state.reservations.first(where: {
                      $0.requestSHA256 == request.digest
                  }),
                  reservation.targetSHA256 == QueryTarget(request: request).digest
            else {
                throw FactoryValidationError(
                    code: "evaluation_reservation_missing",
                    message: "Private execution requires one durable query reservation.",
                )
            }
            return reservation.digest
        }
    }

    func pendingAuthorization(for request: EvaluationRequest) throws -> EvaluationPendingAuthorization {
        try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try self.validate(document)
            let reservation = try self.pendingReservation(for: request, in: document)
            return EvaluationPendingAuthorization(
                authorization: reservation.authorization,
                reservationSHA256: reservation.digest,
            )
        }
    }

    func attachAuthorization(
        _ authorization: EvaluationExecutionAuthorization,
        to request: EvaluationRequest,
    ) throws {
        _ = try EvaluationLedgerFileStore.update(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try validate(document)
            let reservation = try pendingReservation(for: request, in: document)
            guard authorization.requestSHA256 == request.digest,
                  authorization.reservationSHA256 == reservation.digest,
                  authorization.partition == partition,
                  authorization.epochSHA256 == epochSHA256,
                  authorization.queryOrdinal == request.queryOrdinal,
                  reservation.authorization == nil || reservation.authorization == authorization,
                  let index = document.state.reservations.firstIndex(where: {
                      $0.digest == reservation.digest
                  })
            else {
                throw FactoryValidationError(
                    code: "execution_authorization_mismatch",
                    message: "The execution capability differs from its durable reservation.",
                )
            }
            var reservations = document.state.reservations
            reservations[index] = reservation.replacing(authorization: authorization)
            let state = document.state.replacing(reservations: reservations)
            let updated = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
            try validate(updated)
            return (updated, ())
        }
    }

    func complete(
        _ request: EvaluationRequest,
        aggregate: EvaluationAggregate,
        executionReceiptSHA256: SHA256Digest,
    ) throws -> SHA256Digest {
        try EvaluationLedgerFileStore.update(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try validate(document)
            let reservation = try pendingReservation(for: request, in: document)
            let completion = QueryCompletionRecord(
                aggregate: aggregate,
                attestation: nil,
                executionReceiptSHA256: executionReceiptSHA256,
                failureCode: nil,
                reservationSHA256: reservation.digest,
                status: .completed,
            )
            let state = document.state.replacing(
                completions: (document.state.completions + [completion])
                    .sorted { $0.reservationSHA256.rawValue < $1.reservationSHA256.rawValue },
            )
            let updated = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
            try validate(updated)
            return (updated, completion.queryLedgerSHA256)
        }
    }

    func completedOutput(_ request: EvaluationRequest) throws -> EvaluationCompletedOutput? {
        try EvaluationLedgerFileStore.snapshot(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try self.validate(document)
            guard let reservation = document.state.reservations.first(where: {
                $0.requestSHA256 == request.digest
            }),
                let completion = document.state.completions.first(where: {
                    $0.reservationSHA256 == reservation.digest
                }),
                completion.status == .completed,
                let aggregate = completion.aggregate,
                let executionReceiptSHA256 = completion.executionReceiptSHA256
            else {
                return nil
            }
            return EvaluationCompletedOutput(
                attestation: completion.attestation,
                result: EvaluationResult(
                    aggregate: aggregate,
                    executionReceiptSHA256: executionReceiptSHA256,
                    queryLedgerSHA256: completion.queryLedgerSHA256,
                ),
            )
        }
    }

    func attach(_ attestation: AggregateAttestation, to request: EvaluationRequest) throws {
        _ = try EvaluationLedgerFileStore.update(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try validate(document)
            guard let reservation = document.state.reservations.first(where: {
                $0.requestSHA256 == request.digest
            }),
                let index = document.state.completions.firstIndex(where: {
                    $0.reservationSHA256 == reservation.digest
                })
            else {
                throw FactoryValidationError(
                    code: "evaluation_completion_missing",
                    message: "A signed aggregate requires its durable completed query.",
                )
            }
            let completion = document.state.completions[index]
            guard completion.status == .completed,
                  completion.attestation == nil
                  || completion.attestation == attestation
                  || completion.attestation?.canRenew(with: attestation) == true,
                  attestation.requestSHA256 == request.digest,
                  attestation.partition == partition,
                  attestation.epochSHA256 == epochSHA256,
                  attestation.queryLedgerSHA256 == completion.queryLedgerSHA256,
                  attestation.executionReceiptSHA256 == completion.executionReceiptSHA256,
                  attestation.decision == completion.aggregate?.decision,
                  attestation.failureClass == completion.aggregate?.failureClass
            else {
                throw FactoryValidationError(
                    code: "evaluation_attestation_mismatch",
                    message: "The signed aggregate differs from its durable completion.",
                )
            }
            var completions = document.state.completions
            completions[index] = completion.replacing(attestation: attestation)
            let state = document.state.replacing(completions: completions)
            let updated = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
            try validate(updated)
            return (updated, ())
        }
    }

    func abandon(_ request: EvaluationRequest, failureCode: String) throws {
        _ = try EvaluationLedgerFileStore.update(at: root, kind: .query) { document in
            let document = document as QueryDocument
            try validate(document)
            let reservation = try pendingReservation(for: request, in: document)
            let completion = QueryCompletionRecord(
                aggregate: nil,
                attestation: nil,
                executionReceiptSHA256: nil,
                failureCode: failureCode,
                reservationSHA256: reservation.digest,
                status: .abandoned,
            )
            let state = document.state.replacing(
                completions: (document.state.completions + [completion])
                    .sorted { $0.reservationSHA256.rawValue < $1.reservationSHA256.rawValue },
            )
            let updated = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
            try validate(updated)
            return (updated, ())
        }
    }
}
