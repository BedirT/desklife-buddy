import Foundation
import StatusMenu

extension AppDelegate {
    func present(_ overlayRoute: AppOverlayRoute, for action: StatusMenuAction) {
        AppOverlayArbitration.performPresentation(
            requested: overlayRoute.family,
            active: activeOverlayFamilies,
        ) {
            switch overlayRoute {
            case .visualReset:
                overlayCoordinator?.present()
            case .movement:
                movementOverlayCoordinator?.present(
                    selectedDurationSeconds: selectedDuration(for: action),
                )
            case .merged:
                mergedOverlayCoordinator?.present()
            case let .snooze(scope):
                breakFlowOverlayCoordinator?.presentSnooze(scope: scope)
            }
        }
    }

    var activeOverlayFamilies: Set<AppOverlayFamily> {
        var active: Set<AppOverlayFamily> = []
        if overlayCoordinator?.isPresenting == true { active.insert(.visualReset) }
        if movementOverlayCoordinator?.isPresenting == true { active.insert(.movement) }
        if mergedOverlayCoordinator?.isPresenting == true { active.insert(.merged) }
        if breakFlowOverlayCoordinator?.isPresenting == true { active.insert(.snooze) }
        return active
    }

    private func selectedDuration(for action: StatusMenuAction) -> TimeInterval? {
        switch action {
        case .startMovement(.recommended):
            configuration?.movement.durationOptionsSeconds.first
        case .startMovement(.quick):
            configuration?.movement.durationOptionsSeconds.dropFirst().first
        case .startMovement(.positionChange), .startHeadsUpNow,
             .startVisualReset, .snooze, .openSnoozeOptions, .pause, .resume,
             .toggleWorkingHours, .openWeeklyRhythm, .openSettings, .quit:
            nil
        }
    }
}
