import BreakFlow
import Domain
import Foundation
import StatusMenu

extension AppDelegate {
    @discardableResult
    func present(
        _ overlayRoute: AppOverlayRoute,
        for action: StatusMenuAction,
    ) -> AppOverlayPresentationDecision {
        AppOverlayArbitration.performPresentation(
            requested: overlayRoute.family,
            active: activeOverlayFamilies,
        ) {
            switch overlayRoute {
            case .visualReset:
                completionCapsuleCoordinator?.dismiss()
                overlayCoordinator?.present()
            case .movement:
                completionCapsuleCoordinator?.dismiss()
                movementOverlayCoordinator?.present(
                    selectedDurationSeconds: selectedDuration(for: action),
                )
            case .merged:
                completionCapsuleCoordinator?.dismiss()
                mergedOverlayCoordinator?.present()
            case let .snooze(scope):
                breakFlowOverlayCoordinator?.presentSnooze(scope: scope)
            }
        }
    }

    func presentHeadsUpBreak(
        _ id: HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
    ) -> AppOverlayPresentationDecision {
        let family = HeadsUpLifecycleCoordinator.family(for: opportunity)
        let binding = HeadsUpOpeningBinding(id: id, family: family)
        let decision = AppOverlayArbitration.performExclusivePresentation(
            active: activeOverlayFamilies,
        ) { [self] in
            completionCapsuleCoordinator?.dismiss()
            headsUpOpeningBinding = binding
            switch opportunity {
            case .visual:
                overlayCoordinator?.present()
            case .movement:
                movementOverlayCoordinator?.present()
            case .merged:
                mergedOverlayCoordinator?.present()
            }
        }
        guard decision == .presented, isHeadsUpOverlayPresenting(opportunity) else {
            if headsUpOpeningBinding == binding { headsUpOpeningBinding = nil }
            return .blocked
        }
        return .presented
    }

    func presentHeadsUpMoreOptions(
        _ id: HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
    ) -> BreakFlowOverlayCoordinator.PresentationResult {
        let scope: BreakScope = switch opportunity {
        case .visual: .visual
        case .movement: .movement
        case .merged: .merged
        }
        return breakFlowOverlayCoordinator?.presentSnooze(
            actionID: id.rawValue,
            scope: scope,
        ) ?? .blocked
    }

    var activeOverlayFamilies: Set<AppOverlayFamily> {
        var active: Set<AppOverlayFamily> = []
        if overlayCoordinator?.isPresenting == true { active.insert(.visualReset) }
        if movementOverlayCoordinator?.isPresenting == true { active.insert(.movement) }
        if mergedOverlayCoordinator?.isPresenting == true { active.insert(.merged) }
        if breakFlowOverlayCoordinator?.isPresenting == true { active.insert(.snooze) }
        return active
    }

    private func isHeadsUpOverlayPresenting(_ opportunity: HeadsUpOpportunityID) -> Bool {
        switch opportunity {
        case .visual:
            overlayCoordinator?.isPresenting == true
        case .movement:
            movementOverlayCoordinator?.isPresenting == true
        case .merged:
            mergedOverlayCoordinator?.isPresenting == true
        }
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
