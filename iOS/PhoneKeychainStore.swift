import CompanionPhone
import Foundation
import Security

/// Keychain persistence for the QR-shared pairing key on iPhone.
///
/// Device-only (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`): a
/// pairing-bound key must never roam to devices the owner never scanned.
/// Per-device store (default access group): sharing secrets through the App
/// Group keychain would need a `keychain-access-groups` entitlement, which is
/// out of scope — the group carries session files, never keys.
public struct PhoneKeychainStore: PhoneKeyStoring {
    /// Keychain service string. QUOTE IN PR: `"desklife.companion.pairing"`.
    public static let service = "desklife.companion.pairing"

    public init() {}

    public func save(_ key: Data, pairingID: UUID) throws {
        let account = pairingID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw PhoneKeychainError.keychainFailure(updateStatus)
            }
            return
        }
        guard status == errSecSuccess else {
            throw PhoneKeychainError.keychainFailure(status)
        }
    }

    public func load(pairingID: UUID) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: pairingID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw PhoneKeyStoreError.notFound
            }
            throw PhoneKeychainError.keychainFailure(status)
        }
        guard let data = item as? Data else {
            throw PhoneKeychainError.corruptItem
        }
        return data
    }

    public func delete(pairingID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: pairingID.uuidString,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PhoneKeychainError.keychainFailure(status)
        }
    }
}

/// Keychain errors the phone surfaces instead of defaulting past.
public enum PhoneKeychainError: Error, Equatable, Hashable, Sendable {
    /// A Keychain call failed.
    case keychainFailure(OSStatus)
    /// A stored item decoded to the wrong shape.
    case corruptItem
}
