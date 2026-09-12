/// A sanctioned reason that blocks presentation without implying hidden sensing.
///
/// Manual context cases (`userDeclaredMeetingOrCall`,
/// `userDeclaredScreenSharingOrPresentation`, `userSelectedTimedTask`) are
/// pure user declarations: they work permission-free, always carry an
/// explicit expiry via `ManualContextHold`, and never freeze need clocks.
public enum SuppressionReason: String, CaseIterable, Hashable, Sendable {
    case manualPause
    case systemInactiveOrLocked
    case explicitPresentationMode
    case focusFilter
    case calendarBusy
    case excludedApplication
    case outsideWorkingHours
    case userDeclaredMeetingOrCall
    case userDeclaredScreenSharingOrPresentation
    case userSelectedTimedTask
    case snooze
    case lowFrictionWait

    /// Normative highest-to-lowest precedence from the product protocol.
    /// Manual user state always wins over inference; `manualPause` still
    /// outranks every manual context hold.
    public static let precedence: [SuppressionReason] = [
        .manualPause,
        .systemInactiveOrLocked,
        .explicitPresentationMode,
        .focusFilter,
        .calendarBusy,
        .excludedApplication,
        .outsideWorkingHours,
        .userDeclaredMeetingOrCall,
        .userDeclaredScreenSharingOrPresentation,
        .userSelectedTimedTask,
        .snooze,
        .lowFrictionWait,
    ]

    var accumulationPolicy: AccumulationPolicy {
        switch self {
        case .manualPause, .systemInactiveOrLocked, .outsideWorkingHours:
            .pause
        case .explicitPresentationMode, .focusFilter, .calendarBusy,
             .excludedApplication, .userDeclaredMeetingOrCall,
             .userDeclaredScreenSharingOrPresentation, .userSelectedTimedTask,
             .snooze, .lowFrictionWait:
            .continue
        }
    }
}

/// Whether estimated active use continues while presentation is held.
public enum AccumulationPolicy: Equatable, Sendable {
    case pause
    case `continue`
}

/// Deterministic result of evaluating all currently active holds.
public struct SuppressionResolution: Equatable, Sendable {
    public let shouldPresent: Bool
    public let reason: SuppressionReason?
    public let accumulationPolicy: AccumulationPolicy
}

/// Applies the protocol's honest, single-reason suppression precedence.
public enum SuppressionResolver {
    /// Returns the highest-precedence active reason and its accumulation policy.
    public static func resolve(activeReasons: Set<SuppressionReason>) -> SuppressionResolution {
        guard let reason = SuppressionReason.precedence.first(where: activeReasons.contains) else {
            return SuppressionResolution(
                shouldPresent: true,
                reason: nil,
                accumulationPolicy: .continue,
            )
        }

        return SuppressionResolution(
            shouldPresent: false,
            reason: reason,
            accumulationPolicy: reason.accumulationPolicy,
        )
    }
}
