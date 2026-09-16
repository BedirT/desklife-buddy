import CompanionPhone
import Foundation

/// App Group persistence for the one unsent terminal intent.
///
/// Suite `group.com.imeralabs.desklife` (the approved group, attached via
/// automatic signing) so a later widget can read the same pending state.
/// Carries NO secrets: only IDs, counters, and the codec-encoded intent
/// envelope. The pairing key itself stays device-only in the Keychain.
///
/// Fail-loud: every entry point resolves the suite through
/// `PhonePendingStoreError.requireSuite`, so a missing group or a missing
/// entitlement throws `suiteUnavailable` instead of silently running
/// non-durable. A nil suite must NEVER look like an empty outbox.
public struct PhoneDefaultsPendingStore: PhonePendingStore {
    /// Approved App Group suite. QUOTE IN PLAN: `"group.com.imeralabs.desklife"`.
    public static let suiteName = "group.com.imeralabs.desklife"
    private static let key = "desklife.companion.pending"

    private let suiteName: String
    private let resolve: (@Sendable (String) -> UserDefaults?)?

    public init(
        suiteName: String = Self.suiteName,
        resolve: (@Sendable (String) -> UserDefaults?)? = nil,
    ) {
        self.suiteName = suiteName
        self.resolve = resolve
    }

    private var defaults: UserDefaults? {
        if let resolve {
            resolve(suiteName)
        } else {
            UserDefaults(suiteName: suiteName)
        }
    }

    public func load() throws -> PhonePendingSnapshot? {
        let defaults = try PhonePendingStoreError.requireSuite(defaults)
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try JSONDecoder().decode(PhonePendingSnapshot.self, from: data)
    }

    public func save(_ snapshot: PhonePendingSnapshot) throws {
        let defaults = try PhonePendingStoreError.requireSuite(defaults)
        try defaults.set(JSONEncoder().encode(snapshot), forKey: Self.key)
    }

    public func clear() throws {
        let defaults = try PhonePendingStoreError.requireSuite(defaults)
        defaults.removeObject(forKey: Self.key)
    }
}
