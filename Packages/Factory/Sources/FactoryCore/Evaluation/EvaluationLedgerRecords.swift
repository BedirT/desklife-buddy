import Foundation

enum QueryCompletionStatus: String, Codable {
    case abandoned
    case completed
}

struct EvaluationCompletedOutput {
    let attestation: AggregateAttestation?
    let result: EvaluationResult
}

struct EvaluationPendingAuthorization {
    let authorization: EvaluationExecutionAuthorization?
    let reservationSHA256: SHA256Digest
}

struct QueryCompletionRecord: Codable, Equatable {
    @RequiredNullable var aggregate: EvaluationAggregate?
    @RequiredNullable var attestation: AggregateAttestation?
    @RequiredNullable var executionReceiptSHA256: SHA256Digest?
    @RequiredNullable var failureCode: String?
    let reservationSHA256: SHA256Digest
    let status: QueryCompletionStatus

    var isValid: Bool {
        switch status {
        case .completed:
            aggregate != nil && executionReceiptSHA256 != nil && failureCode == nil
        case .abandoned:
            aggregate == nil
                && attestation == nil
                && executionReceiptSHA256 == nil
                && failureCode.map(FactoryTextRules.isStableID) == true
        }
    }

    var queryLedgerSHA256: SHA256Digest {
        CanonicalJSON.digest(QueryCompletionBinding(
            aggregateSHA256: aggregate?.digest,
            executionReceiptSHA256: executionReceiptSHA256,
            failureCode: failureCode,
            reservationSHA256: reservationSHA256,
            status: status,
        ))
    }

    func replacing(attestation: AggregateAttestation) -> QueryCompletionRecord {
        QueryCompletionRecord(
            aggregate: aggregate,
            attestation: attestation,
            executionReceiptSHA256: executionReceiptSHA256,
            failureCode: failureCode,
            reservationSHA256: reservationSHA256,
            status: status,
        )
    }
}

struct QueryCompletionBinding: Codable {
    @RequiredNullable var aggregateSHA256: SHA256Digest?
    @RequiredNullable var executionReceiptSHA256: SHA256Digest?
    @RequiredNullable var failureCode: String?
    let reservationSHA256: SHA256Digest
    let status: QueryCompletionStatus
}

struct QueryDocument: Codable, Equatable {
    let headSHA256: SHA256Digest
    let state: QueryState
}

struct QueryReservationRecord: Codable, Equatable {
    @RequiredNullable var authorization: EvaluationExecutionAuthorization?
    let nonceSHA256: SHA256Digest
    let queryOrdinal: Int
    let requestSHA256: SHA256Digest
    let sequence: Int
    let targetSHA256: SHA256Digest

    var digest: SHA256Digest {
        CanonicalJSON.digest(QueryReservationBinding(
            nonceSHA256: nonceSHA256,
            queryOrdinal: queryOrdinal,
            requestSHA256: requestSHA256,
            sequence: sequence,
            targetSHA256: targetSHA256,
        ))
    }

    func replacing(authorization: EvaluationExecutionAuthorization) -> QueryReservationRecord {
        QueryReservationRecord(
            authorization: authorization,
            nonceSHA256: nonceSHA256,
            queryOrdinal: queryOrdinal,
            requestSHA256: requestSHA256,
            sequence: sequence,
            targetSHA256: targetSHA256,
        )
    }
}

struct QueryReservationBinding: Codable {
    let nonceSHA256: SHA256Digest
    let queryOrdinal: Int
    let requestSHA256: SHA256Digest
    let sequence: Int
    let targetSHA256: SHA256Digest
}

struct QueryState: Codable, Equatable {
    let completions: [QueryCompletionRecord]
    let epochSHA256: SHA256Digest
    let evaluatorSHA256: SHA256Digest
    let maximumSelectionQueries: Int
    let partition: EvaluationPartition
    let policySHA256: SHA256Digest
    let reservations: [QueryReservationRecord]
    let schemaVersion: Int
    let trustedBaseSHA: GitObjectID

    func replacing(
        completions: [QueryCompletionRecord]? = nil,
        reservations: [QueryReservationRecord]? = nil,
    ) -> QueryState {
        QueryState(
            completions: completions ?? self.completions,
            epochSHA256: epochSHA256,
            evaluatorSHA256: evaluatorSHA256,
            maximumSelectionQueries: maximumSelectionQueries,
            partition: partition,
            policySHA256: policySHA256,
            reservations: reservations ?? self.reservations,
            schemaVersion: schemaVersion,
            trustedBaseSHA: trustedBaseSHA,
        )
    }
}

struct QueryTarget: Codable {
    let baseComponentSHA256: SHA256Digest
    let candidateComponentID: String
    let epochSHA256: SHA256Digest
    let partition: EvaluationPartition

    init(request: EvaluationRequest) {
        baseComponentSHA256 = request.baseComponentSHA256
        candidateComponentID = request.candidateComponentID
        epochSHA256 = request.epochSHA256
        partition = request.partition
    }

    var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }
}

struct ReplayDocument: Codable, Equatable {
    let headSHA256: SHA256Digest
    let state: ReplayState
}

struct AttestationReplayIdentity: Codable {
    let epochSHA256: SHA256Digest
    let nonceSHA256: SHA256Digest
    let partition: EvaluationPartition
    let queryOrdinal: Int
    let requestSHA256: SHA256Digest

    init(attestation: AggregateAttestation) {
        epochSHA256 = attestation.epochSHA256
        nonceSHA256 = attestation.nonceSHA256
        partition = attestation.partition
        queryOrdinal = attestation.queryOrdinal
        requestSHA256 = attestation.requestSHA256
    }
}

struct ReplayState: Codable, Equatable {
    let consumedAttestationSHA256: [SHA256Digest]
    let epochSHA256: SHA256Digest
    let partition: EvaluationPartition
    let schemaVersion: Int
}

struct AuthorizationReplayDocument: Codable, Equatable {
    let headSHA256: SHA256Digest
    let state: AuthorizationReplayState
}

struct AuthorizationReplayState: Codable, Equatable {
    let consumedAuthorizationSHA256: [SHA256Digest]
    let epochSHA256: SHA256Digest
    let partition: EvaluationPartition
    let schemaVersion: Int
}

extension AggregateAttestation {
    func canRenew(with renewed: AggregateAttestation) -> Bool {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let priorExpiry = formatter.date(from: expiresAt),
              let renewedIssue = formatter.date(from: renewed.issuedAt)
        else {
            return false
        }
        return renewedIssue >= priorExpiry
            && requestSHA256 == renewed.requestSHA256
            && queryLedgerSHA256 == renewed.queryLedgerSHA256
            && executionReceiptSHA256 == renewed.executionReceiptSHA256
            && decision == renewed.decision
            && failureClass == renewed.failureClass
            && signingKeyID == renewed.signingKeyID
            && signatureAlgorithm == renewed.signatureAlgorithm
            && evaluatorSHA256 == renewed.evaluatorSHA256
            && policySHA256 == renewed.policySHA256
            && trustedBaseSHA == renewed.trustedBaseSHA
            && partition == renewed.partition
            && epochSHA256 == renewed.epochSHA256
    }
}

enum EvaluationLedgerFileKind {
    case attestationReplay
    case executionAuthorizationReplay
    case query

    var lockName: String {
        switch self {
        case .attestationReplay: ".attestation-replay.lock"
        case .executionAuthorizationReplay: ".execution-authorization-replay.lock"
        case .query: ".evaluation-query.lock"
        }
    }

    var stateName: String {
        switch self {
        case .attestationReplay: "attestation-replay.json"
        case .executionAuthorizationReplay: "execution-authorization-replay.json"
        case .query: "evaluation-query.json"
        }
    }

    var temporaryName: String {
        ".\(stateName).tmp"
    }
}
