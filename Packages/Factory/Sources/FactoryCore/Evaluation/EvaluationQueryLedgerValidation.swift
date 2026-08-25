import Foundation

extension EvaluationQueryLedger {
    var epochSHA256: SHA256Digest {
        partition == .selection ? policy.selectionEpoch.sha256 : policy.sealedEpoch.sha256
    }

    func reserving(
        _ request: EvaluationRequest,
        in document: QueryDocument,
    ) throws -> (QueryDocument, SHA256Digest) {
        try validate(document)
        let admission = try reservationAdmission(for: request, in: document)
        try validateQueryOrdinal(request, targetReservations: admission.targetReservations)
        let reservation = try QueryReservationRecord(
            authorization: nil,
            nonceSHA256: admission.nonceSHA256,
            queryOrdinal: request.queryOrdinal,
            requestSHA256: request.digest,
            sequence: nextSequence(after: document.state.reservations.count),
            targetSHA256: admission.targetSHA256,
        )
        let state = document.state.replacing(
            reservations: document.state.reservations + [reservation],
        )
        let updated = QueryDocument(headSHA256: CanonicalJSON.digest(state), state: state)
        try validate(updated)
        return (updated, reservation.digest)
    }

    func pendingReservation(
        for request: EvaluationRequest,
        in document: QueryDocument,
    ) throws -> QueryReservationRecord {
        guard request.partition == partition,
              request.epochSHA256 == epochSHA256,
              let reservation = document.state.reservations.first(where: { $0.requestSHA256 == request.digest }),
              reservation.targetSHA256 == QueryTarget(request: request).digest,
              !document.state.completions.contains(where: { $0.reservationSHA256 == reservation.digest })
        else {
            throw FactoryValidationError(
                code: "evaluation_reservation_missing",
                message: "Private execution requires one pending durable query reservation.",
            )
        }
        return reservation
    }

    func validate(_ document: QueryDocument) throws {
        guard documentShapeIsValid(document) else { throw invalidState() }
        let reservationsByDigest = Dictionary(
            uniqueKeysWithValues: document.state.reservations.map { ($0.digest, $0) },
        )
        guard document.state.reservations.allSatisfy(reservationAuthorizationIsValid),
              document.state.completions.allSatisfy({ completion in
                  completionIsValid(completion, reservationsByDigest: reservationsByDigest)
              })
        else {
            throw invalidState()
        }
        try validateOrdinals(document.state.reservations)
    }

    private func reservationAdmission(
        for request: EvaluationRequest,
        in document: QueryDocument,
    ) throws -> ReservationAdmission {
        guard request.partition == partition,
              request.epochSHA256 == epochSHA256
        else {
            throw FactoryValidationError(
                code: "evaluation_ledger_partition",
                message: "Selection and sealed query ledgers cannot be shared.",
            )
        }
        let nonceSHA256 = SHA256Digest.hashing(Data(request.nonce.utf8))
        try validateNonce(nonceSHA256, reservations: document.state.reservations)
        let targetSHA256 = QueryTarget(request: request).digest
        let targetReservations = document.state.reservations.filter { $0.targetSHA256 == targetSHA256 }
        try validateTargetIsComplete(targetReservations, completions: document.state.completions)
        return ReservationAdmission(
            nonceSHA256: nonceSHA256,
            targetReservations: targetReservations,
            targetSHA256: targetSHA256,
        )
    }

    private func validateNonce(
        _ nonceSHA256: SHA256Digest,
        reservations: [QueryReservationRecord],
    ) throws {
        guard !reservations.contains(where: { $0.nonceSHA256 == nonceSHA256 }) else {
            throw FactoryValidationError(
                code: "evaluation_replay",
                message: "The evaluation nonce was already consumed.",
            )
        }
        guard reservations.count < Self.maximumEntries else {
            throw FactoryValidationError(
                code: "evaluation_ledger_overflow",
                message: "The evaluation query ledger is exhausted.",
            )
        }
    }

    private func validateTargetIsComplete(
        _ reservations: [QueryReservationRecord],
        completions: [QueryCompletionRecord],
    ) throws {
        let completionsByReservation = Dictionary(
            uniqueKeysWithValues: completions.map { ($0.reservationSHA256, $0) },
        )
        guard !reservations.contains(where: { reservation in
            guard let completion = completionsByReservation[reservation.digest] else { return true }
            return completion.status == .abandoned || completion.attestation == nil
        }) else {
            throw FactoryValidationError(
                code: "evaluation_query_incomplete",
                message: "An incomplete or abandoned private query blocks this target.",
            )
        }
    }

    private func validateQueryOrdinal(
        _ request: EvaluationRequest,
        targetReservations: [QueryReservationRecord],
    ) throws {
        switch partition {
        case .sealed:
            guard targetReservations.isEmpty, request.queryOrdinal == 1 else {
                throw FactoryValidationError(
                    code: "sealed_query_replay",
                    message: "A frozen candidate may query one sealed epoch once.",
                )
            }
        case .selection:
            let (expected, overflow) = targetReservations.count.addingReportingOverflow(1)
            guard !overflow, request.queryOrdinal == expected else {
                throw FactoryValidationError(
                    code: "selection_query_order",
                    message: "Selection revisions must be sequential.",
                )
            }
        }
    }

    private func nextSequence(after count: Int) throws -> Int {
        let (sequence, overflow) = count.addingReportingOverflow(1)
        guard !overflow else {
            throw FactoryValidationError(
                code: "evaluation_ledger_overflow",
                message: "The evaluation query ledger is exhausted.",
            )
        }
        return sequence
    }

    private func documentShapeIsValid(_ document: QueryDocument) -> Bool {
        let state = document.state
        return state.schemaVersion == FactoryCore.schemaVersion
            && state.partition == partition
            && state.epochSHA256 == epochSHA256
            && state.policySHA256 == policy.digest
            && state.evaluatorSHA256 == policy.evaluatorSHA256
            && state.trustedBaseSHA == policy.trustedRootSHA
            && state.maximumSelectionQueries == policy.maximumSelectionQueries
            && state.reservations.count <= Self.maximumEntries
            && state.completions.count <= state.reservations.count
            && document.headSHA256 == CanonicalJSON.digest(state)
            && state.reservations.enumerated().allSatisfy { $0.element.sequence == $0.offset + 1 }
            && Set(state.reservations.map(\.nonceSHA256)).count == state.reservations.count
            && Set(state.reservations.map(\.requestSHA256)).count == state.reservations.count
            && state.completions == state.completions.sorted(by: {
                $0.reservationSHA256.rawValue < $1.reservationSHA256.rawValue
            })
            && Set(state.completions.map(\.reservationSHA256)).count == state.completions.count
    }

    private func reservationAuthorizationIsValid(_ reservation: QueryReservationRecord) -> Bool {
        guard let authorization = reservation.authorization else { return true }
        return authorization.requestSHA256 == reservation.requestSHA256
            && authorization.reservationSHA256 == reservation.digest
            && authorization.partition == partition
            && authorization.epochSHA256 == epochSHA256
            && authorization.queryOrdinal == reservation.queryOrdinal
    }

    private func completionIsValid(
        _ completion: QueryCompletionRecord,
        reservationsByDigest: [SHA256Digest: QueryReservationRecord],
    ) -> Bool {
        guard let reservation = reservationsByDigest[completion.reservationSHA256],
              completion.isValid
        else {
            return false
        }
        guard let attestation = completion.attestation else { return true }
        return completion.status == .completed
            && attestation.requestSHA256 == reservation.requestSHA256
            && attestation.partition == partition
            && attestation.epochSHA256 == epochSHA256
            && attestation.queryLedgerSHA256 == completion.queryLedgerSHA256
            && attestation.executionReceiptSHA256 == completion.executionReceiptSHA256
            && attestation.decision == completion.aggregate?.decision
            && attestation.failureClass == completion.aggregate?.failureClass
    }

    private func validateOrdinals(_ reservations: [QueryReservationRecord]) throws {
        var ordinalsByTarget: [SHA256Digest: Int] = [:]
        for reservation in reservations {
            let expected = ordinalsByTarget[reservation.targetSHA256, default: 0] + 1
            guard reservation.queryOrdinal == expected,
                  partition == .selection || expected == 1
            else {
                throw invalidState()
            }
            ordinalsByTarget[reservation.targetSHA256] = expected
        }
    }

    private func invalidState() -> FactoryValidationError {
        FactoryValidationError(
            code: "invalid_evaluation_ledger",
            message: "The durable evaluation query ledger is malformed or bound to another ruler.",
        )
    }
}

private struct ReservationAdmission {
    let nonceSHA256: SHA256Digest
    let targetReservations: [QueryReservationRecord]
    let targetSHA256: SHA256Digest
}
