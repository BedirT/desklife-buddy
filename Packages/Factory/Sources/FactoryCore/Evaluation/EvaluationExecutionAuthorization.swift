import CryptoKit
import Foundation

/// Signed capability emitted only after the durable query reservation exists.
package struct EvaluationExecutionAuthorization: Codable, Equatable {
    package let epochSHA256: SHA256Digest
    package let expiresAt: String
    package let issuedAt: String
    package let partition: EvaluationPartition
    package let queryOrdinal: Int
    package let requestSHA256: SHA256Digest
    package let reservationSHA256: SHA256Digest
    package let signature: Data
    package let signingKeyID: String

    package var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    package static func sign(
        request: EvaluationRequest,
        reservationSHA256: SHA256Digest,
        issuedAt: String,
        expiresAt: String,
        signingKeyID: String,
        privateKey: Curve25519.Signing.PrivateKey,
    ) throws -> EvaluationExecutionAuthorization {
        let unsigned = try UnsignedExecutionAuthorization(
            epochSHA256: request.epochSHA256,
            expiresAt: expiresAt,
            issuedAt: issuedAt,
            partition: request.partition,
            queryOrdinal: request.queryOrdinal,
            requestSHA256: request.digest,
            reservationSHA256: reservationSHA256,
            signingKeyID: signingKeyID,
        )
        return try EvaluationExecutionAuthorization(
            unsigned: unsigned,
            signature: privateKey.signature(for: CanonicalJSON.encode(unsigned)),
        )
    }

    package func verify(
        request: EvaluationRequest,
        reservationSHA256 expectedReservationSHA256: SHA256Digest,
        now: String?,
        publicKey: Curve25519.Signing.PublicKey,
    ) throws {
        let expected = try UnsignedExecutionAuthorization(
            epochSHA256: request.epochSHA256,
            expiresAt: expiresAt,
            issuedAt: issuedAt,
            partition: request.partition,
            queryOrdinal: request.queryOrdinal,
            requestSHA256: request.digest,
            reservationSHA256: expectedReservationSHA256,
            signingKeyID: signingKeyID,
        )
        guard try unsigned() == expected,
              now.map({ isWithinAuthorizationLifetime(issuedAt: issuedAt, expiresAt: expiresAt, now: $0) }) ?? true,
              try publicKey.isValidSignature(signature, for: CanonicalJSON.encode(expected))
        else {
            throw FactoryValidationError(
                code: "invalid_execution_authorization",
                message: "Private execution requires the signed capability issued after durable reservation.",
            )
        }
    }

    package init(from decoder: Decoder) throws {
        let stored = try Stored(from: decoder)
        try self.init(unsigned: stored.unsigned, signature: stored.signature)
    }

    package func encode(to encoder: Encoder) throws {
        try Stored(unsigned: unsigned(), signature: signature).encode(to: encoder)
    }

    private init(unsigned: UnsignedExecutionAuthorization, signature: Data) throws {
        guard signature.count == 64 else {
            throw FactoryValidationError(
                code: "invalid_execution_authorization",
                message: "The private execution authorization is malformed.",
            )
        }
        epochSHA256 = unsigned.epochSHA256
        expiresAt = unsigned.expiresAt
        issuedAt = unsigned.issuedAt
        partition = unsigned.partition
        queryOrdinal = unsigned.queryOrdinal
        requestSHA256 = unsigned.requestSHA256
        reservationSHA256 = unsigned.reservationSHA256
        self.signature = signature
        signingKeyID = unsigned.signingKeyID
    }

    private func unsigned() throws -> UnsignedExecutionAuthorization {
        try UnsignedExecutionAuthorization(
            epochSHA256: epochSHA256,
            expiresAt: expiresAt,
            issuedAt: issuedAt,
            partition: partition,
            queryOrdinal: queryOrdinal,
            requestSHA256: requestSHA256,
            reservationSHA256: reservationSHA256,
            signingKeyID: signingKeyID,
        )
    }

    private struct Stored: Codable {
        let epochSHA256: SHA256Digest
        let expiresAt: String
        let issuedAt: String
        let partition: EvaluationPartition
        let queryOrdinal: Int
        let requestSHA256: SHA256Digest
        let reservationSHA256: SHA256Digest
        let signature: Data
        let signingKeyID: String

        init(unsigned: UnsignedExecutionAuthorization, signature: Data) {
            epochSHA256 = unsigned.epochSHA256
            expiresAt = unsigned.expiresAt
            issuedAt = unsigned.issuedAt
            partition = unsigned.partition
            queryOrdinal = unsigned.queryOrdinal
            requestSHA256 = unsigned.requestSHA256
            reservationSHA256 = unsigned.reservationSHA256
            self.signature = signature
            signingKeyID = unsigned.signingKeyID
        }

        var unsigned: UnsignedExecutionAuthorization {
            get throws {
                try UnsignedExecutionAuthorization(
                    epochSHA256: epochSHA256,
                    expiresAt: expiresAt,
                    issuedAt: issuedAt,
                    partition: partition,
                    queryOrdinal: queryOrdinal,
                    requestSHA256: requestSHA256,
                    reservationSHA256: reservationSHA256,
                    signingKeyID: signingKeyID,
                )
            }
        }
    }
}

/// Receipt bytes signed by the separately anchored private executor.
package struct AuthorizedCandidateExecutionReceipt: Codable, Equatable {
    package let authorizationSHA256: SHA256Digest
    package let completedAt: String
    package let receipt: CandidateExecutionReceipt
    package let startedAt: String

    package init(
        authorizationSHA256: SHA256Digest,
        completedAt: String,
        receipt: CandidateExecutionReceipt,
        startedAt: String,
    ) throws {
        guard let started = canonicalAuthorizationDate(startedAt),
              let completed = canonicalAuthorizationDate(completedAt),
              started <= completed
        else {
            throw FactoryValidationError(
                code: "invalid_execution_receipt_lifetime",
                message: "Private execution timestamps are malformed.",
            )
        }
        self.authorizationSHA256 = authorizationSHA256
        self.completedAt = completedAt
        self.receipt = receipt
        self.startedAt = startedAt
    }

    package init(from decoder: Decoder) throws {
        let stored = try Stored(from: decoder)
        try self.init(
            authorizationSHA256: stored.authorizationSHA256,
            completedAt: stored.completedAt,
            receipt: stored.receipt,
            startedAt: stored.startedAt,
        )
    }

    package func encode(to encoder: Encoder) throws {
        try Stored(
            authorizationSHA256: authorizationSHA256,
            completedAt: completedAt,
            receipt: receipt,
            startedAt: startedAt,
        ).encode(to: encoder)
    }

    package func validate(
        authorization: EvaluationExecutionAuthorization,
        budget: EvaluationExecutionBudget,
    ) throws {
        guard authorizationSHA256 == authorization.digest,
              let authorizationIssued = canonicalAuthorizationDate(authorization.issuedAt),
              let authorizationExpires = canonicalAuthorizationDate(authorization.expiresAt),
              let started = canonicalAuthorizationDate(startedAt),
              let completed = canonicalAuthorizationDate(completedAt),
              authorizationIssued <= started,
              started <= completed,
              completed < authorizationExpires,
              completed.timeIntervalSince(started) * 1000 <= Double(budget.maximumWallTimeMilliseconds)
        else {
            throw FactoryValidationError(
                code: "invalid_execution_receipt_lifetime",
                message: "Private execution must begin and finish within its one-shot authorization and budget.",
            )
        }
    }

    private struct Stored: Codable {
        let authorizationSHA256: SHA256Digest
        let completedAt: String
        let receipt: CandidateExecutionReceipt
        let startedAt: String
    }
}

private struct UnsignedExecutionAuthorization: Codable, Equatable {
    let epochSHA256: SHA256Digest
    let expiresAt: String
    let issuedAt: String
    let partition: EvaluationPartition
    let queryOrdinal: Int
    let requestSHA256: SHA256Digest
    let reservationSHA256: SHA256Digest
    let signingKeyID: String

    init(
        epochSHA256: SHA256Digest,
        expiresAt: String,
        issuedAt: String,
        partition: EvaluationPartition,
        queryOrdinal: Int,
        requestSHA256: SHA256Digest,
        reservationSHA256: SHA256Digest,
        signingKeyID: String,
    ) throws {
        guard validAuthorizationLifetime(issuedAt: issuedAt, expiresAt: expiresAt),
              queryOrdinal > 0,
              FactoryTextRules.isStableID(signingKeyID)
        else {
            throw FactoryValidationError(
                code: "invalid_execution_authorization",
                message: "The private execution authorization is malformed.",
            )
        }
        self.epochSHA256 = epochSHA256
        self.expiresAt = expiresAt
        self.issuedAt = issuedAt
        self.partition = partition
        self.queryOrdinal = queryOrdinal
        self.requestSHA256 = requestSHA256
        self.reservationSHA256 = reservationSHA256
        self.signingKeyID = signingKeyID
    }
}

private func validAuthorizationLifetime(issuedAt: String, expiresAt: String) -> Bool {
    guard let issued = canonicalAuthorizationDate(issuedAt),
          let expires = canonicalAuthorizationDate(expiresAt)
    else {
        return false
    }
    return issued < expires && expires.timeIntervalSince(issued) <= 15 * 60
}

private func isWithinAuthorizationLifetime(issuedAt: String, expiresAt: String, now: String) -> Bool {
    guard let issued = canonicalAuthorizationDate(issuedAt),
          let expires = canonicalAuthorizationDate(expiresAt),
          let current = canonicalAuthorizationDate(now)
    else {
        return false
    }
    return issued <= current && current < expires
}

private func canonicalAuthorizationDate(_ value: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
        return nil
    }
    return date
}
