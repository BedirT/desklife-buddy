import Foundation

/// Stable sorted-key JSON encoding used for hashes and signatures.
public enum CanonicalJSON {
    public static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .custom { path in
            FactoryJSONKey(camelCase: path.last?.stringValue ?? "")
        }
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }

    /// Decodes only byte-for-byte canonical JSON, rejecting unknown keys and alternate encodings.
    public static func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        let value: T
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom { path in
                FactoryJSONKey(snakeCase: path.last?.stringValue ?? "")
            }
            value = try decoder.decode(type, from: data)
        } catch {
            throw FactoryValidationError(
                code: "invalid_json",
                message: "The payload does not decode as its declared schema.",
            )
        }
        guard try encode(value) == data else {
            throw FactoryValidationError(
                code: "noncanonical_json",
                message: "JSON must have exact keys, sorted encoding, and no duplicate or trailing bytes.",
            )
        }
        return value
    }

    /// Computes the canonical digest of a Factory-owned value whose encoding cannot contain runtime failures.
    public static func digest(_ value: some Encodable) -> SHA256Digest {
        do {
            return try SHA256Digest.hashing(encode(value))
        } catch {
            preconditionFailure("Factory canonical encoding invariant failed: \(error)")
        }
    }
}

struct FactoryJSONKey: CodingKey {
    let stringValue: String

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
    }

    var intValue: Int? {
        Int(stringValue)
    }

    init(snakeCase: String) {
        let components = snakeCase.split(separator: "_", omittingEmptySubsequences: false).map(String.init)
        stringValue = components.enumerated().map { index, component in
            if index == 0 {
                return component
            }
            switch component {
            case "id": return "ID"
            case "ids": return "IDs"
            case "url": return "URL"
            case "sha": return "SHA"
            case "sha256": return "SHA256"
            default: return component.prefix(1).uppercased() + component.dropFirst()
            }
        }.joined()
    }

    init(camelCase: String) {
        let suffixes = [
            ("SHA256", "sha256"),
            ("SHA", "sha"),
            ("IDs", "ids"),
            ("ID", "id"),
            ("URL", "url"),
        ]
        for (suffix, encoded) in suffixes where camelCase.hasSuffix(suffix) && camelCase != suffix {
            let prefix = String(camelCase.dropLast(suffix.count))
            stringValue = "\(FactoryJSONKey.snakeCase(prefix))_\(encoded)"
            return
        }
        stringValue = FactoryJSONKey.snakeCase(camelCase)
    }

    private static func snakeCase(_ value: String) -> String {
        let characters = Array(value)
        var result = ""
        for index in characters.indices {
            let character = characters[index]
            let isUppercase = character.isUppercase
            let previousIsLowercaseOrDigit = index > 0
                && (characters[characters.index(before: index)].isLowercase
                    || characters[characters.index(before: index)].isNumber)
            let nextIsLowercase = index < characters.index(before: characters.endIndex)
                && characters[characters.index(after: index)].isLowercase
            if isUppercase, index > 0, previousIsLowercaseOrDigit || nextIsLowercase {
                result.append("_")
            }
            result.append(contentsOf: String(character).lowercased())
        }
        return result
    }
}
