import CryptoKit
import Foundation

enum FactoryTextRules {
    static func isStableID(_ value: String) -> Bool {
        value.wholeMatch(of: /^[a-z0-9][a-z0-9._:-]{0,127}$/) != nil
    }

    static func isBoundedText(_ value: String, maximumScalars: Int) -> Bool {
        (1 ... maximumScalars).contains(value.unicodeScalars.count)
    }
}

/// Validated SHA-256 identity used for contracts, context, evidence, and policy.
public struct SHA256Digest: Hashable, Sendable {
    public let rawValue: String

    private init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(validating rawValue: String) throws {
        guard rawValue.count == 64,
              rawValue.unicodeScalars.allSatisfy({ scalar in
                  ("0" ... "9").contains(Character(scalar)) || ("a" ... "f").contains(Character(scalar))
              })
        else {
            throw FactoryValidationError(
                code: "invalid_sha256",
                message: "SHA-256 values must contain exactly 64 lowercase hexadecimal characters.",
            )
        }
        self.rawValue = rawValue
    }

    /// Computes a content identity without invoking an external hashing process.
    public static func hashing(_ data: Data) -> SHA256Digest {
        let rawValue = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return SHA256Digest(rawValue: rawValue)
    }
}

extension SHA256Digest: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            try self.init(validating: container.decode(String.self))
        } catch let error as FactoryValidationError {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// Validated Git object identity compatible with SHA-1 and SHA-256 repositories.
public struct GitObjectID: Hashable, Sendable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        guard rawValue.count == 40 || rawValue.count == 64,
              rawValue.unicodeScalars.allSatisfy({ scalar in
                  ("0" ... "9").contains(Character(scalar)) || ("a" ... "f").contains(Character(scalar))
              })
        else {
            throw FactoryValidationError(
                code: "invalid_git_oid",
                message: "Git object IDs must contain 40 or 64 lowercase hexadecimal characters.",
            )
        }
        self.rawValue = rawValue
    }
}

extension GitObjectID: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            try self.init(validating: container.decode(String.self))
        } catch let error as FactoryValidationError {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
