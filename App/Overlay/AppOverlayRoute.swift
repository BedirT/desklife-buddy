import BreakFlow
import Domain
import StatusMenu

enum AppOverlayRoute: Equatable {
    case visualReset
    case movement
    case merged
    case snooze(BreakScope)

    static func resolve(
        action: StatusMenuAction,
        liveHeadsUp: OpportunityPresentation?,
    ) -> AppOverlayRoute? {
        switch action {
        case .startVisualReset:
            .visualReset
        case .startMovement:
            .movement
        case .startHeadsUpNow:
            breakRoute(for: liveHeadsUp)
        case .openSnoozeOptions:
            snoozeRoute(for: liveHeadsUp)
        case .snooze, .pause, .resume, .toggleWorkingHours,
             .openWeeklyRhythm, .openSettings, .quit:
            nil
        }
    }

    private static func breakRoute(for presentation: OpportunityPresentation?) -> AppOverlayRoute? {
        switch presentation {
        case .visual: .visualReset
        case .movement: .movement
        case .merged: .merged
        case .recovery, nil: nil
        }
    }

    private static func snoozeRoute(for presentation: OpportunityPresentation?) -> AppOverlayRoute? {
        switch presentation {
        case .visual: .snooze(.visual)
        case .movement: .snooze(.movement)
        case .merged: .snooze(.merged)
        case .recovery, nil: nil
        }
    }

    var family: AppOverlayFamily {
        switch self {
        case .visualReset: .visualReset
        case .movement: .movement
        case .merged: .merged
        case .snooze: .snooze
        }
    }
}

enum AppOverlayFamily: Hashable {
    case visualReset
    case movement
    case merged
    case snooze
}

enum AppOverlayPresentationDecision: Equatable {
    case presented
    case reused
    case blocked
}

enum AppOverlayArbitration {
    @discardableResult
    static func performPresentation(
        requested: AppOverlayFamily,
        active: Set<AppOverlayFamily>,
        operation: () -> Void,
    ) -> AppOverlayPresentationDecision {
        if active.isEmpty {
            operation()
            return .presented
        }
        if active == [requested] {
            operation()
            return .reused
        }
        return .blocked
    }
}
