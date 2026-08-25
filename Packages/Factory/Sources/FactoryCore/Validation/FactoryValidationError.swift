import Foundation

/// Stable machine-readable validation failure returned at every trust boundary.
public struct FactoryValidationError: Error, Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

extension FactoryValidationError: CustomStringConvertible {
    public var description: String {
        "\(code): \(message)"
    }
}

extension FactoryValidationError: LocalizedError {
    public var errorDescription: String? {
        description
    }
}
