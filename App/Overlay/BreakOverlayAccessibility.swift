import Domain
import Movement
import VisualReset

extension AccessibilityPreferences {
    var visualResetAccessibility: VisualResetAccessibility {
        VisualResetAccessibility(staticPresentation: presentation != .standard)
    }

    var movementAccessibility: MovementAccessibility {
        MovementAccessibility(staticPresentation: presentation != .standard)
    }

    func includes(_ announcement: VisualResetAnnouncement) -> Bool {
        guard timerAnnouncements == .none else { return true }
        return switch announcement {
        case .opened, .tenSecondsRemaining, .finished: false
        case .doneEarly, .skipped: true
        }
    }

    func includes(_ announcement: MovementAnnouncement) -> Bool {
        guard timerAnnouncements == .none else { return true }
        return switch announcement {
        case .opened, .oneMinuteRemaining, .finished: false
        case .selectionChanged, .doneEarly, .alreadyMoved, .positionChanged,
             .visualOnly, .skipped:
            true
        }
    }
}
