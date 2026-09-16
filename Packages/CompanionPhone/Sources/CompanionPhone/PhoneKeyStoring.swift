import Foundation

/// Key storage seam for the QR-shared pairing key.
///
/// Production slots in the Keychain store; tests and previews use the
/// in-memory implementation, so no test ever touches the Keychain.
public protocol PhoneKeyStoring: Sendable {
    mutating func save(_ key: Data, pairingID: UUID) throws
    func load(pairingID: UUID) throws -> Data
    mutating func delete(pairingID: UUID) throws
}

/// Pairing-key errors the phone surfaces instead of defaulting past.
public enum PhoneKeyStoreError: Error, Equatable, Hashable, Sendable {
    /// Expected a key that is not there.
    case notFound
}

/// The in-memory key store: previews and tests, never production secrets.
public struct InMemoryPhoneKeyStore: PhoneKeyStoring {
    private var keys: [UUID: Data] = [:]

    public init() {}

    public mutating func save(_ key: Data, pairingID: UUID) throws {
        keys[pairingID] = key
    }

    public func load(pairingID: UUID) throws -> Data {
        guard let key = keys[pairingID] else {
            throw PhoneKeyStoreError.notFound
        }
        return key
    }

    public mutating func delete(pairingID: UUID) throws {
        keys.removeValue(forKey: pairingID)
    }
}
