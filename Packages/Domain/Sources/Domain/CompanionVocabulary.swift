import Foundation

/// Closed companion-session vocabularies (Epic 4 wave 1).
///
/// The session carries countdown observations and companion intents between
/// the Mac and the phone. Every code on the wire comes from these closed
/// sets so unknown peers cannot smuggle new behavior through the transport.
/// The Watch has no target in v1: it is a forwarding-only relay reached
/// through the phone (owner gate Q4).
public enum CompanionMessageKind: String, Equatable, Hashable, CaseIterable, Sendable, Codable {
    /// A countdown observation (remaining ticks + phase hint payload).
    case countdown
    /// A phase change hint (break/arm/recover windows).
    case phase
    /// A companion intent (take-with-me / handoff / mirror request).
    case intent
    /// A settlement receipt for a previously sent intent.
    case receipt
}

/// Closed device roles admitted to a companion session.
public enum CompanionDeviceRole: String, Equatable, Hashable, CaseIterable, Sendable, Codable {
    /// The Mac: the only clock owner in the session.
    case mac
    /// The phone: observes and relays, never mutates Mac clocks.
    case phone
    /// The Watch: forwarding-only, relayed through the phone.
    /// No watchOS target exists in v1 (owner gate Q4).
    case watchRelay
}

/// The one forwarding-only relay hop the session admits.
public enum CompanionRelayHop: String, Equatable, Hashable, Sendable, Codable {
    /// Route a phone-bound envelope onward to the paired Watch.
    /// The Watch never joins the session directly.
    case watchViaPhone
}

/// Closed settlement outcomes for companion-routed work.
public enum CompanionSessionOutcome: String, Equatable, Hashable, CaseIterable, Sendable, Codable {
    case delivered
    case duplicateReplay
    case rejectedStaleSequence
    case rejectedUnknownKind
    case rejectedRevokedPairing
}
