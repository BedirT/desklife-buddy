import CompanionPhone
import Foundation

/// App Group persistence for the one unsent terminal intent.
///
/// Suite `group.com.imeralabs.desklife` (the approved group, attached via
/// automatic signing) so a later widget can read the same pending state.
/// Carries NO secrets: only IDs, counters, and the codec-encoded intent
/// envelope. The pairing key itself stays device-only in the Keychain.
public struct PhoneDefaultsPendingStore: PhonePendingStore {
    /// Approved App Group suite. QUOTE IN PLAN: `"group.com.imeralabs.desklife"`.
    public static let suiteName = "group.com.imeralabs.desklife"
    private static let key = "desklife.companion.pending"

    public init() {}

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.suiteName)
    }

    public func load() throws -> PhonePendingSnapshot? {
        guard let data = defaults?.data(forKey: Self.key) else { return nil }
        return try JSONDecoder().decode(PhonePendingSnapshot.self, from: data)
    }

    public func save(_ snapshot: PhonePendingSnapshot) throws {
        try defaults?.set(JSONEncoder().encode(snapshot), forKey: Self.key)
    }

    public func clear() throws {
        defaults?.removeObject(forKey: Self.key)
    }
}
