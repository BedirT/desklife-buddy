import Foundation

// OWNER STOP (Story 8): this file is compile-only feasibility vocabulary
// for future helper/XPC traffic. Closed request/response cases only — no
// transport, no entitlements, no raw sensing content. New helper traffic
// extends these enums; real adoption, signing, and sandbox changes go to
// the owner. Unreferenced by production (proven by grep).

/// Closed request vocabulary the app could send a helper (Story 8).
///
/// Status and budget questions only. No case carries readings, pixels,
/// audio, coordinates, titles, or motion: the helper answers in counts,
/// digests, and ticks.
public enum HelperXPCRequest: Equatable, Hashable, Sendable, Codable {
    /// How many tokens one work class currently holds.
    case budgetStatus(workClassCode: String)
    /// How many units one work class has deferred.
    case deferredReport(workClassCode: String)
    /// Whether any revocation is still draining at the presented ticks.
    case revocationDrainStatus(atTicks: TimeInterval)
}

/// Closed response vocabulary a helper could return (Story 8).
public enum HelperXPCResponse: Equatable, Sendable {
    case budgetStatus(workClassCode: String, tokensHeld: Int, capacity: Int)
    case deferredReport(workClassCode: String, deferredCount: Int)
    case revocationDrainStatus(drainingCount: Int)
}

/// The wire envelope wrapping one closed request (Story 8).
public struct HelperXPCEnvelope: Equatable, Hashable, Sendable, Codable {
    public let messageID: UInt64
    public let request: HelperXPCRequest

    public init(messageID: UInt64, request: HelperXPCRequest) {
        self.messageID = messageID
        self.request = request
    }
}
