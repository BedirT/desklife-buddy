import Domain
import Foundation
import HeadsUp

extension HeadsUpLifecycleCoordinator {
    func openBreak(_ id: HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID) {
        pendingBreakOpening = PendingBreakOpening(id: id, opportunity: opportunity)
        _ = presentBreak(id, opportunity)
    }

    func openMoreOptions(_ id: HeadsUpDeliveryID, opportunity: HeadsUpOpportunityID) {
        let result = presentMoreOptions(id, opportunity)
        guard result == .presented || result == .reused else { return }
        enqueue { [weak self] in
            guard let self else { return }
            do {
                let completed = try await runtime.completeHeadsUpPendingAction(
                    id,
                    kind: .openMoreOptions,
                    opportunity: opportunity,
                )
                guard completed != nil else { return }
                retire(id)
            } catch {
                onError(error)
            }
        }
    }

    func cancelPendingAction(_ action: HeadsUpPendingAction) {
        if pendingBreakOpening?.id == action.id { pendingBreakOpening = nil }
    }

    func handlePendingAction(_ action: HeadsUpPendingAction) {
        switch action.kind {
        case .openBreak:
            openBreak(action.id, opportunity: action.opportunity)
        case .openMoreOptions:
            openMoreOptions(action.id, opportunity: action.opportunity)
        }
    }

    func handle(_ response: HeadsUpNotificationResponse) async {
        guard let route = HeadsUpNotificationResponseMapper.route(
            response,
            defaultBodyTapBehavior: .moreOptions,
        ) else {
            return
        }
        switch route {
        case let .startNow(id):
            await respond(HeadsUpDeliveryID(rawValue: id), .startNow)
        case let .snoozeFiveMinutes(id):
            await respond(
                HeadsUpDeliveryID(rawValue: id),
                .snooze(until: wallNow().addingTimeInterval(300)),
            )
        case let .moreOptions(id):
            await respond(HeadsUpDeliveryID(rawValue: id), .moreOptions)
        case .dismissedWithoutAction, .defaultBodyTapAwaitingOwnerDecision:
            break
        }
    }

    func enqueueIntent(_ intent: HeadsUpIntent, deliveryID: HeadsUpDeliveryID) {
        enqueue { [weak self] in
            guard let self else { return }
            switch intent {
            case .start:
                await respond(deliveryID, .startNow)
            case let .snooze(_, duration):
                await respond(
                    deliveryID,
                    .snooze(until: wallNow().addingTimeInterval(duration)),
                )
            case .moreOptions:
                await respond(deliveryID, .moreOptions)
            case .skip:
                await respond(deliveryID, .skip)
            case .snoozeUntil, .manualHold:
                rejectPendingIntent(deliveryID)
            }
        }
    }

    func respond(_ id: HeadsUpDeliveryID, _ response: HeadsUpDeliveryResponse) async {
        do {
            try await runtime.respondToHeadsUp(id, response: response)
        } catch {
            rejectPendingIntent(id)
            onError(error)
        }
    }

    func settle(_ id: HeadsUpDeliveryID, response: HeadsUpDeliveryResponse) {
        let activeModel = activePresentation?.id == id ? activePresentation?.model : nil
        if let intent = pendingModelIntents.removeValue(forKey: id), let activeModel {
            activeModel.confirmPersistence(intent)
        }
        if response != .dismissedWithoutAction {
            readyDeliveryIDs.remove(id)
            publishStatusProjection()
        }
    }

    func rejectPendingIntent(_ id: HeadsUpDeliveryID) {
        guard let intent = pendingModelIntents.removeValue(forKey: id),
              let activePresentation,
              activePresentation.id == id
        else {
            return
        }
        activePresentation.model.rejectPersistence(intent)
    }

    func publishStatusProjection() {
        onStatusProjection(statusProjection)
    }

    static func makeModel(
        scope: HeadsUpScope,
        phase: HeadsUpPhase,
        progress: Double,
        accessibility: HeadsUpAccessibility,
        onIntent: @escaping (HeadsUpIntent) -> Void,
    ) -> HeadsUpModel {
        HeadsUpModel(
            scope: scope,
            phase: phase,
            approachProgress: progress,
            snoozeDurationsSeconds: [300, 600, 900],
            accessibility: accessibility,
            onIntent: onIntent,
            onAnnouncement: HeadsUpAccessibilityAnnouncer.post,
        )
    }

    static func scope(for opportunity: HeadsUpOpportunityID) -> HeadsUpScope {
        switch opportunity {
        case .visual: .visual
        case .movement: .movement
        case .merged: .merged
        }
    }

    static func family(for opportunity: HeadsUpOpportunityID) -> OverlayOpeningFamily {
        switch opportunity {
        case .visual: .visualReset
        case .movement: .movement
        case .merged: .merged
        }
    }
}
