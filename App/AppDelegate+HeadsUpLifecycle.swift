import BreakFlow
import Domain
import HeadsUp
import Movement
import VisualReset

extension AppDelegate {
    func installPrimaryOverlays(configuration: ProtocolConfiguration) {
        let accessibilityPreferences = runtime?.preferences?.accessibility ?? .defaults
        overlayCoordinator = VisualResetOverlayCoordinator(
            durationSeconds: configuration.visual.durationOptionsSeconds[0],
            accessibilityPreferences: accessibilityPreferences,
            onLifecycle: { [weak self] action, completion in
                guard let self else {
                    completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                    return
                }
                enqueueVisualReset(action, completion: completion)
            },
            onAnnouncement: VisualResetAccessibilityAnnouncer.post,
            onCompletion: { [weak self] in self?.presentCompletionAcknowledgement() },
        )
        movementOverlayCoordinator = MovementOverlayCoordinator(
            schedule: configuration.movement,
            accessibilityPreferences: accessibilityPreferences,
            onLifecycle: { [weak self] action, completion in
                guard let self else {
                    completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                    return
                }
                enqueueMovement(action, completion: completion)
            },
            onAnnouncement: MovementAccessibilityAnnouncer.post,
            onCompletion: { [weak self] in self?.presentCompletionAcknowledgement() },
        )
    }

    func installHeadsUpLifecycle(runtime: ProtocolRuntime, policy: HeadsUpRuntimePolicy?) {
        headsUpLifecycleCoordinator = HeadsUpLifecycleComposition.makeIfConfigured(
            policy: policy,
            make: { [weak self] in
                HeadsUpLifecycleComposition.makeLive(
                    runtime: runtime,
                    authorizationStore: {
                        #if DEBUG
                            self?.headsUpVerificationMode.map(
                                HeadsUpVerificationAuthorizationStore.init,
                            )
                        #else
                            nil
                        #endif
                    }(),
                    presentBreak: { [weak self] id, opportunity in
                        guard let result = self?.presentHeadsUpBreak(
                            id,
                            opportunity: opportunity,
                        ) else {
                            return .blocked
                        }
                        return result
                    },
                    presentMoreOptions: { [weak self] id, opportunity in
                        self?.presentHeadsUpMoreOptions(id, opportunity: opportunity) ?? .blocked
                    },
                    onStatusProjection: { [weak self] projection in
                        self?.updateHeadsUpStatusProjection(projection)
                    },
                    onError: { [weak self] error in self?.lastRuntimeError = error },
                )
            },
        )
    }

    func enqueueVisualReset(
        _ action: VisualResetAction,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        let completedHeadsUp = action == .opened
            && completeHeadsUpOpeningIfBound(family: .visualReset, completion: completion)
        guard !completedHeadsUp else { return }
        let event: VisualResetLifecycleEvent = switch action {
        case .opened: .opened
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .skipped: .skipped
        }
        visualResetLifecycleQueue.enqueue(
            event,
            operation: { [weak self] event in
                guard let self, let runtime else {
                    throw AppDelegateLifecycleError.coordinatorUnavailable
                }
                try await runtime.handleVisualReset(event)
            },
            onFailure: { [weak self] error in self?.lastRuntimeError = error },
            completion: completionWithHeadsUpRetry(completion),
        )
    }

    func enqueueMovement(
        _ action: MovementAction,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        let completedHeadsUp = action == .opened
            && completeHeadsUpOpeningIfBound(family: .movement, completion: completion)
        guard !completedHeadsUp else { return }
        let event: MovementLifecycleEvent
        switch action {
        case .opened: event = .opened
        case let .selectedDuration(duration): event = .selectedDuration(duration)
        case .timerFinished: event = .timerFinished
        case .doneEarly: event = .doneEarly
        case .alreadyMoved: event = .alreadyMoved
        case .positionChanged: event = .positionChanged
        case .skipped: event = .skipped
        case .visualOnly:
            completion(.failure(ProtocolLifecycleError.invalidTransition))
            return
        }
        movementLifecycleQueue.enqueue(
            event,
            operation: { [weak self] event in
                guard let self, let runtime else {
                    throw AppDelegateLifecycleError.coordinatorUnavailable
                }
                try await runtime.handleMovement(event)
            },
            onFailure: { [weak self] error in self?.lastRuntimeError = error },
            completion: completionWithHeadsUpRetry(completion),
        )
    }

    func enqueueMerged(
        _ event: MergedLifecycleEvent,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        let completedHeadsUp = event == .opened
            && completeHeadsUpOpeningIfBound(family: .merged, completion: completion)
        guard !completedHeadsUp else { return }
        mergedLifecycleQueue.enqueue(
            event,
            operation: { [weak self] event in
                guard let self, let runtime else {
                    throw AppDelegateLifecycleError.coordinatorUnavailable
                }
                try await runtime.handleMerged(event)
            },
            onFailure: { [weak self] error in self?.lastRuntimeError = error },
            completion: completionWithHeadsUpRetry(completion),
        )
    }

    func enqueueBreakFlow(
        _ action: BreakFlowAction,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        Task { [weak self] in
            guard let self, let runtime else {
                completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                return
            }
            do {
                try await runtime.handleBreakFlow(action)
                completion(.success(()))
                scheduleHeadsUpPendingPresentationRetry()
            } catch {
                lastRuntimeError = error
                completion(.failure(error))
            }
        }
    }

    func completionWithHeadsUpRetry(
        _ completion: @escaping (Result<Void, any Error>) -> Void,
    ) -> (Result<Void, any Error>) -> Void {
        { [weak self] result in
            completion(result)
            guard case .success = result else { return }
            self?.scheduleHeadsUpPendingPresentationRetry()
        }
    }

    func completeHeadsUpOpeningIfBound(
        family: OverlayOpeningFamily,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) -> Bool {
        guard let binding = headsUpOpeningBinding,
              binding.family == family,
              let headsUpLifecycleCoordinator
        else {
            return false
        }
        let handled = headsUpLifecycleCoordinator.completePendingBreakOpening(
            actionID: binding.id,
            family: family,
            completion: { [weak self] result in
                if case .success = result, self?.headsUpOpeningBinding == binding {
                    self?.headsUpOpeningBinding = nil
                }
                completion(result)
            },
        )
        if !handled, headsUpOpeningBinding == binding {
            headsUpOpeningBinding = nil
        }
        return handled
    }

    func scheduleHeadsUpPendingPresentationRetry() {
        Task { [weak self] in
            await Task.yield()
            self?.headsUpLifecycleCoordinator?.retryPendingPresentation()
        }
    }

    func enqueueBreakFlowForTesting(
        _ action: BreakFlowAction,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        enqueueBreakFlow(action, completion: completion)
    }
}

enum AppDelegateLifecycleError: Error, Equatable {
    case coordinatorUnavailable
}

struct HeadsUpOpeningBinding: Equatable {
    let id: HeadsUpDeliveryID
    let family: OverlayOpeningFamily
}
