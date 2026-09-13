import Foundation
import Security

/// Keychain persistence for the QR-shared pairing key (Epic 4 wave 1, gates Q2/Q6).
///
/// Ceremony flow: Domain issues/rotates/revokes (`CompanionPairingCeremony`),
/// this store persists the live key, and the Mac renders the ceremony's
/// `qrText` for the phone to scan (QR rendering UI is a later story; no UI
/// here). Unpair deletes the Keychain item, completing revocation on this Mac.
///
/// Identity scoping (owner sign-off pending, quoted in the wave-1 PR body):
/// - Keychain service: `"desklife.companion.pairing"` (a Keychain service
///   string, NOT a bundle ID — product bundle identity stays deferred).
/// - Keychain access group: default (nil). No App Group exists yet because
///   App Group ID naming is product-identity-deferred; sharing the key with
///   future iOS/Watch targets needs an App Group the owner has not named.
///   Flagged in the PR — this build stores Mac-local only.
/// - Accessibility is device-only: a pairing-bound key must not roam to
///   devices the owner never scanned.
public enum CompanionKeychainStore {
    /// Keychain service string. QUOTE IN PR: `"desklife.companion.pairing"`.
    public static let service = "desklife.companion.pairing"

    /// Keychain errors the store surfaces instead of defaulting past.
    public enum StoreError: Error, Equatable {
        /// Randomness failed while minting a key.
        case randomGenerationFailed(OSStatus)
        /// A Keychain call failed.
        case keychainFailure(OSStatus)
        /// Expected a key that is not there.
        case notFound
        /// A stored item decoded to the wrong shape.
        case corruptItem
    }

    /// Mints 32 random key bytes for a new or rotated pairing.
    public static func makeKey() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw StoreError.randomGenerationFailed(status)
        }
        return Data(bytes)
    }

    /// Saves (or replaces) the live key for one pairing ID.
    public static func saveKey(_ key: Data, pairingID: UUID) throws {
        let account = pairingID.uuidString
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = key
            add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw StoreError.keychainFailure(status)
        }
    }

    /// Loads the live key for one pairing ID.
    public static func loadKey(pairingID: UUID) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pairingID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status != errSecItemNotFound else {
            throw StoreError.notFound
        }
        guard status == errSecSuccess, let data = item as? Data else {
            throw StoreError.keychainFailure(status)
        }
        return data
    }

    /// Deletes the key for one pairing ID. Missing keys delete silently:
    /// unpair revocation must be idempotent.
    public static func deleteKey(pairingID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: pairingID.uuidString,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StoreError.keychainFailure(status)
        }
    }
}
