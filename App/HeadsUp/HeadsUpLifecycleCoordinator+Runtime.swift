import Domain
import Foundation
import HeadsUp

extension HeadsUpLifecycleCoordinator {
    func drain() async {
        while true {
            let revision = workRevision
            await serialTaskTail?.value
            let tasks = deliveryTasks.values
            for task in tasks {
                await task.value
            }
            await serialTaskTail?.value
            await Task.yield()
            guard revision == workRevision else { continue }
            return
        }
    }

    #if DEBUG
        @discardableResult
        func captureCapsuleForVerification() -> Bool {
            verificationCapture?() ?? false
        }
    #endif

    func tearDown() {
        suppressionRetractionCancellation?.cancel()
        suppressionRetractionCancellation = nil
        deliveryTasks.values.forEach { $0.cancel() }
        deliveryTasks.removeAll()
        permissionPanelCoordinator.tearDown()
        if let id = activePresentation?.id {
            deliveryCoordinator.withdraw(.retractPresented(id.rawValue))
        }
        activePresentation?.driver.stop()
        activePresentation = nil
        pendingBreakOpening = nil
        pendingModelIntents.removeAll()
        readyDeliveryIDs.removeAll()
        publishStatusProjection()
    }

    func installRuntimeCallbacks() {
        runtime.onHeadsUpEffect = { [weak self] effect in self?.receive(effect) }
        runtime.onHeadsUpRestoredDelivery = { [weak self] active in self?.restore(active) }
        runtime.onHeadsUpPromptFactReady = { [weak self] id in self?.markPromptFactReady(id) }
        runtime.onHeadsUpSettled = { [weak self] id, response in
            self?.settle(id, response: response)
        }
    }

    func receive(_ effect: HeadsUpRuntimeEffect) {
        if case let .reserve(reservation) = effect {
            _ = responseRegistry.registerActive(deliveryID: reservation.id.rawValue)
        }
        enqueue { [weak self] in self?.handle(effect) }
    }

    func restore(_ active: HeadsUpActiveDelivery) {
        _ = responseRegistry.registerActive(deliveryID: active.id.rawValue)
        enqueue { [weak self] in self?.restorePresentation(active) }
    }

    func markPromptFactReady(_ id: HeadsUpDeliveryID) {
        readyDeliveryIDs.insert(id)
        responseBuffer.markPromptFactReady(deliveryID: id.rawValue)
        publishStatusProjection()
        if let intent = pendingModelIntents[id] {
            enqueueIntent(intent, deliveryID: id)
        }
    }

    func enqueue(_ operation: @escaping @MainActor @Sendable () async -> Void) {
        workRevision += 1
        let predecessor = serialTaskTail
        let task = Task {
            await predecessor?.value
            await operation()
        }
        serialTaskTail = task
    }

    func enqueueResponse(_ response: HeadsUpNotificationResponse) {
        enqueue { [weak self] in await self?.handle(response) }
    }

    func handle(_ effect: HeadsUpRuntimeEffect) {
        switch effect {
        case let .reserve(reservation):
            reserve(reservation)
        case let .updateCountdown(id, mark, targetAt):
            update(id, mark: mark, targetAt: targetAt)
        case let .updateTiming(id, targetAt):
            retarget(id, targetAt: targetAt)
        case let .land(id):
            land(id)
        case let .holdThenRetract(id, reason):
            holdThenRetract(id, reason: reason)
        case let .snooze(id, _, _), let .skip(id, _), let .cancel(id):
            retire(id)
        case let .openBreak(id, opportunity, _):
            openBreak(id, opportunity: opportunity)
        case let .openMoreOptions(id, opportunity):
            openMoreOptions(id, opportunity: opportunity)
        case let .cancelPendingAction(action):
            cancelPendingAction(action)
        }
    }

    func reserve(_ reservation: HeadsUpDeliveryReservation) {
        if activePresentation?.id != reservation.id {
            retireActivePresentation()
            activePresentation = makePresentation(
                id: reservation.id,
                opportunity: reservation.opportunity,
                mark: reservation.countdownMark,
                targetAt: reservation.targetAt,
            )
        }
        startDelivery(reservation)
    }

    func startDelivery(_ reservation: HeadsUpDeliveryReservation) {
        guard deliveryTasks[reservation.id] == nil,
              let activePresentation,
              activePresentation.id == reservation.id
        else {
            return
        }
        let content = activePresentation.model.notificationContent
        let id = reservation.id
        let task = Task { [weak self] in
            guard let self else { return }
            let preferred = authorizationCoordinator.automaticDeliveryChannel()
            guard !Task.isCancelled else { return }
            let channel = await deliveryCoordinator.deliver(
                deliveryID: id.rawValue,
                content: content,
                preferredChannel: preferred,
            )
            guard !Task.isCancelled, let channel else { return }
            enqueue { [weak self] in
                guard let self else { return }
                do {
                    try await runtime.acknowledgeHeadsUpPresented(
                        id,
                        channel: channel == .notification ? .notification : .capsule,
                    )
                    deliveryCoordinator.releasePersistedDelivery(deliveryID: id.rawValue)
                } catch {
                    onError(error)
                }
            }
        }
        deliveryTasks[id] = task
        Task { [weak self] in
            await task.value
            self?.deliveryTasks[id] = nil
        }
    }

    func restorePresentation(_ active: HeadsUpActiveDelivery) {
        activePresentation = makePresentation(
            id: active.id,
            opportunity: active.opportunity,
            mark: active.countdownMark,
            targetAt: active.targetAt,
        )
        if active.didLand { land(active.id) }
    }

    func makePresentation(
        id: HeadsUpDeliveryID,
        opportunity: HeadsUpOpportunityID,
        mark: HeadsUpCountdownMark,
        targetAt: Date?,
    ) -> ActivePresentation {
        let scope = Self.scope(for: opportunity)
        let phase = HeadsUpPhase.approaching(
            HeadsUpApproachMark(seconds: mark.rawValue) ?? .seconds45,
        )
        let remaining = targetAt.map { max(0, $0.timeIntervalSince(wallNow())) }
            ?? TimeInterval(mark.rawValue)
        let lead = TimeInterval(max(mark.rawValue, 1))
        let progress = min(max(1 - remaining / lead, 0), 1)
        let accessibility = Self.accessibility(
            for: runtime.preferences?.accessibility.presentation,
        )
        let model = modelFactory(scope, phase, progress, accessibility) { [weak self] intent in
            self?.send(intent)
        }
        let driver = driverFactory(model, lead)
        driver.start()
        driver.retarget(remainingSeconds: remaining)
        return ActivePresentation(
            id: id,
            opportunity: opportunity,
            model: model,
            driver: driver,
            targetAt: targetAt,
        )
    }

    func update(
        _ id: HeadsUpDeliveryID,
        mark: HeadsUpCountdownMark,
        targetAt: Date,
    ) {
        guard var activePresentation, activePresentation.id == id else { return }
        activePresentation.model.updatePhase(.approaching(
            HeadsUpApproachMark(seconds: mark.rawValue) ?? .seconds45,
        ))
        activePresentation.targetAt = targetAt
        self.activePresentation = activePresentation
        retarget(id, targetAt: targetAt)
    }

    func retarget(_ id: HeadsUpDeliveryID, targetAt: Date) {
        guard var activePresentation, activePresentation.id == id else { return }
        activePresentation.targetAt = targetAt
        activePresentation.driver.retarget(
            remainingSeconds: max(0, targetAt.timeIntervalSince(wallNow())),
        )
        self.activePresentation = activePresentation
    }

    func land(_ id: HeadsUpDeliveryID) {
        guard let activePresentation, activePresentation.id == id else { return }
        activePresentation.driver.stop()
        activePresentation.model.updatePhase(.landedWaiting)
        publishStatusProjection()
    }

    func holdThenRetract(_ id: HeadsUpDeliveryID, reason: SuppressionReason) {
        guard let activePresentation, activePresentation.id == id else { return }
        suppressionRetractionCancellation?.cancel()
        activePresentation.driver.stop()
        activePresentation.model.updatePhase(.hold(Self.hold(for: reason)))
        deliveryTasks[id]?.cancel()
        deliveryTasks[id] = nil
        publishStatusProjection()
        suppressionRetractionCancellation = scheduleSuppressionRetraction(
            suppressionHoldDurationSeconds,
        ) { [weak self] in
            guard let self, self.activePresentation?.id == id else { return }
            suppressionRetractionCancellation = nil
            deliveryCoordinator.withdraw(.retractPresented(id.rawValue))
            responseBuffer.clearDelivery(deliveryID: id.rawValue)
            retireActivePresentation()
        }
    }

    func retire(_ id: HeadsUpDeliveryID) {
        guard activePresentation?.id == id || pendingBreakOpening?.id == id else { return }
        if activePresentation?.id == id {
            suppressionRetractionCancellation?.cancel()
            suppressionRetractionCancellation = nil
        }
        deliveryTasks[id]?.cancel()
        deliveryTasks[id] = nil
        deliveryCoordinator.withdraw(.retractPresented(id.rawValue))
        responseBuffer.clearDelivery(deliveryID: id.rawValue)
        readyDeliveryIDs.remove(id)
        pendingModelIntents[id] = nil
        if activePresentation?.id == id { retireActivePresentation() }
    }

    func retireActivePresentation() {
        suppressionRetractionCancellation?.cancel()
        suppressionRetractionCancellation = nil
        activePresentation?.driver.stop()
        activePresentation = nil
        publishStatusProjection()
    }

    static func hold(for reason: SuppressionReason) -> HeadsUpHold {
        switch reason {
        case .manualPause: .manualPause(until: nil)
        case .systemInactiveOrLocked: .systemInactiveOrLocked
        case .explicitPresentationMode: .explicitPresentationMode
        case .focusFilter: .focusFilter
        case .calendarBusy: .calendarBusy(until: nil)
        case .userDeclaredMeetingOrCall: .userDeclaredMeetingOrCall(until: nil)
        case .userDeclaredScreenSharingOrPresentation:
            .userDeclaredScreenSharingOrPresentation(until: nil)
        case .userSelectedTimedTask: .userSelectedTimedTask(until: nil)
        case .excludedApplication: .excludedApplication
        case .outsideWorkingHours: .outsideWorkingHours
        case .snooze, .lowFrictionWait: .snooze
        }
    }

    static func accessibility(
        for presentation: AccessibleBreakPresentation?,
    ) -> HeadsUpAccessibility {
        switch presentation {
        case .staticPresentation:
            HeadsUpAccessibility(staticPresentation: true)
        case .textOnly:
            HeadsUpAccessibility(textOnly: true, staticPresentation: true)
        case .standard, nil:
            HeadsUpAccessibility()
        }
    }

    static func liveSuppressionRetractionScheduler(
        duration: TimeInterval,
        action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let timer = Timer(timeInterval: duration, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return OverlayCancellation { timer.invalidate() }
    }
}
