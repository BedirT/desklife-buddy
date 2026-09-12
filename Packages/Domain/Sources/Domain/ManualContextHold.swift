import Foundation

/// Permission-free manual context modes: pure user declarations that hold
/// presentation without inspecting anything. Each mode maps to one
/// `SuppressionReason`, always resolves with `.continue` accumulation (need
/// clocks keep accruing), and is only ever active inside an explicit
/// `ManualContextHold` expiry window.
public enum ManualContextMode: String, CaseIterable, Hashable, Sendable {
    /// "You marked a meeting or call."
    case meetingOrCall
    /// "You marked presenting or sharing."
    case presentingOrSharing
    /// "You marked timed focus."
    case timedFocus

    /// The Held reason this mode resolves to. Never `manualPause`: explicit
    /// user pause keeps outranking every manual context hold.
    public var suppressionReason: SuppressionReason {
        switch self {
        case .meetingOrCall: .userDeclaredMeetingOrCall
        case .presentingOrSharing: .userDeclaredScreenSharingOrPresentation
        case .timedFocus: .userSelectedTimedTask
        }
    }

    /// Default hold length when the user declares the mode without a
    /// duration. The hold always carries an explicit expiry; this is only
    /// the fallback length.
    public var defaultDurationSeconds: TimeInterval {
        switch self {
        case .meetingOrCall: 3600
        case .presentingOrSharing: 3600
        case .timedFocus: 1500
        }
    }
}

/// One active explicit manual hold: a user-declared mode with an explicit
/// expiry. Holds never freeze need clocks; expiry is structural (there is
/// no indefinite manual context hold).
public struct ManualContextHold: Equatable, Sendable {
    public let mode: ManualContextMode
    public let startedAt: Date
    public let expiresAt: Date

    public init(mode: ManualContextMode, startedAt: Date, expiresAt: Date) {
        self.mode = mode
        self.startedAt = startedAt
        self.expiresAt = expiresAt
    }

    public var suppressionReason: SuppressionReason {
        mode.suppressionReason
    }

    public func isExpired(at date: Date) -> Bool {
        date >= expiresAt
    }

    public func isActive(at date: Date) -> Bool {
        date >= startedAt && !isExpired(at: date)
    }
}
