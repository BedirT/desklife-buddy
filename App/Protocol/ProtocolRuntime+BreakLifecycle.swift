import Domain
import Foundation

extension ProtocolRuntime {
    func withLifecycleGate<Result>(
        _ operation: () async throws -> Result,
    ) async throws -> Result {
        await lifecycleGate.acquire()
        do {
            try Task.checkCancellation()
            let result = try await operation()
            await lifecycleGate.release()
            return result
        } catch {
            await lifecycleGate.release()
            throw error
        }
    }

    func reduceMovement(
        _ event: MovementLifecycleEvent,
        openingSource: OpportunityEventSource,
    ) async throws {
        switch event {
        case .opened:
            try await openMovement(source: openingSource)
        case let .selectedDuration(duration):
            try await selectMovement(duration)
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .skipped:
            try await finishMovement(event)
        }
    }

    func reduceMerged(
        _ event: MergedLifecycleEvent,
        openingSource: OpportunityEventSource,
    ) async throws {
        switch event {
        case .opened:
            try await openMerged(source: openingSource)
        case .visualTimerFinished:
            try await finishMergedVisual(
                kind: .timerFinished,
                source: .localTimer,
            )
        case .doneEarly where lifecycleSession == .merged(segment: .visual, selectedDuration: nil):
            try await finishMergedVisual(
                kind: .userDeclaredCompleted,
                source: .user,
            )
        case .skipped:
            try await skipMergedActiveSegment()
        case .selectedDuration, .movementTimerFinished, .doneEarly,
             .alreadyMoved, .positionChanged, .visualOnly:
            try await reduceMergedMovement(event)
        }
    }

    private func openMovement(source: OpportunityEventSource) async throws {
        guard lifecycleSession == nil else { throw ProtocolLifecycleError.invalidTransition }
        try await commitLifecycle(nextSession: .movement(selectedDuration: nil)) {
            coordinator.dispatch(.record(
                kind: .breakStarted,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: source,
            )).events
        }
    }

    private func selectMovement(_ duration: TimeInterval) async throws {
        guard case .movement = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        guard engine.isAcceptedMovementDuration(duration) else {
            throw ProtocolLifecycleError.invalidMovementDuration
        }
        try await commitLifecycle(nextSession: .movement(selectedDuration: duration)) {
            coordinator.dispatch(.selectMovement(durationSeconds: duration)).events
        }
    }

    private func finishMovement(_ event: MovementLifecycleEvent) async throws {
        guard case .movement = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        try await commitLifecycle(nextSession: nil) {
            movementTerminalOutput(event).events
        }
    }

    private func openMerged(source: OpportunityEventSource) async throws {
        guard lifecycleSession == nil else { throw ProtocolLifecycleError.invalidTransition }
        try await commitLifecycle(nextSession: .merged(segment: .visual, selectedDuration: nil)) {
            coordinator.dispatch(.record(
                kind: .breakStarted,
                opportunity: .visual,
                selectedDurationSeconds: nil,
                source: source,
            )).events
        }
    }

    private func finishMergedVisual(
        kind: OpportunityEventKind,
        source: OpportunityEventSource,
    ) async throws {
        guard lifecycleSession == .merged(segment: .visual, selectedDuration: nil) else {
            throw ProtocolLifecycleError.noActiveSession
        }
        try await commitLifecycle(nextSession: .merged(segment: .movement, selectedDuration: nil)) {
            var drafts = coordinator.dispatch(.record(
                kind: kind,
                opportunity: .visual,
                selectedDurationSeconds: nil,
                source: source,
            )).events
            drafts += coordinator.dispatch(.record(
                kind: .breakStarted,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .localTimer,
            )).events
            return drafts
        }
    }

    private func reduceMergedMovement(_ event: MergedLifecycleEvent) async throws {
        guard case .merged(segment: .movement, selectedDuration: _) = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        let dispatching: () throws -> [OpportunityEventDraft]
        let nextSession: LifecycleSession?
        switch event {
        case let .selectedDuration(duration):
            guard engine.isAcceptedMovementDuration(duration) else {
                throw ProtocolLifecycleError.invalidMovementDuration
            }
            nextSession = .merged(segment: .movement, selectedDuration: duration)
            dispatching = { self.coordinator.dispatch(.selectMovement(durationSeconds: duration)).events }
        case .movementTimerFinished, .doneEarly, .alreadyMoved, .positionChanged:
            nextSession = nil
            dispatching = { self.mergedMovementTerminalOutput(event).events }
        case .visualOnly:
            nextSession = nil
            dispatching = { self.coordinator.dispatch(.skipMergedSegment(.movement)).events }
        case .opened, .visualTimerFinished, .skipped:
            throw ProtocolLifecycleError.invalidTransition
        }
        try await commitLifecycle(nextSession: nextSession, dispatching: dispatching)
    }

    private func skipMergedActiveSegment() async throws {
        // Escape-during-visual takes the canonical D-043
        // `merged.escape_during_visual` effect (fresh visual + fresh movement
        // + one deferral + one skip); the movement-segment path keeps the
        // legacy retaining route.
        let command: OpportunityCoordinatorCommand = switch lifecycleSession {
        case .merged(segment: .visual, selectedDuration: _): .mergedEscapeDuringVisual
        case .merged(segment: .movement, selectedDuration: _): .skipMergedSegment(.movement)
        case .movement, nil: throw ProtocolLifecycleError.noActiveSession
        }
        try await commitLifecycle(nextSession: nil) {
            coordinator.dispatch(command).events
        }
    }

    private func movementTerminalOutput(
        _ event: MovementLifecycleEvent,
    ) -> OpportunityCoordinatorOutput {
        switch event {
        case .timerFinished:
            coordinator.dispatch(.record(
                kind: .timerFinished,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .localTimer,
            ))
        case .doneEarly:
            coordinator.dispatch(.record(
                kind: .userDeclaredCompleted,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .alreadyMoved:
            coordinator.dispatch(.record(
                kind: .userDeclaredAlreadyMoved,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .positionChanged:
            coordinator.dispatch(.record(
                kind: .positionChanged,
                opportunity: .positionChange,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .skipped:
            coordinator.dispatch(.record(
                kind: .skipped,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .opened, .selectedDuration:
            preconditionFailure("Movement terminal reducer received a non-terminal event")
        }
    }

    private func mergedMovementTerminalOutput(
        _ event: MergedLifecycleEvent,
    ) -> OpportunityCoordinatorOutput {
        switch event {
        case .movementTimerFinished:
            coordinator.dispatch(.record(
                kind: .timerFinished,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .localTimer,
            ))
        case .doneEarly:
            coordinator.dispatch(.record(
                kind: .userDeclaredCompleted,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .alreadyMoved:
            coordinator.dispatch(.record(
                kind: .userDeclaredAlreadyMoved,
                opportunity: .movement,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .positionChanged:
            coordinator.dispatch(.record(
                kind: .positionChanged,
                opportunity: .positionChange,
                selectedDurationSeconds: nil,
                source: .user,
            ))
        case .opened, .visualTimerFinished, .selectedDuration, .visualOnly, .skipped:
            preconditionFailure("Merged terminal reducer received a non-terminal event")
        }
    }

    /// Single choke point for every BreakLifecycle mutation (Story 2.6 F1):
    /// snapshots the owned coordinator before the first dispatch and restores
    /// engine + fence on any throw, so a failed store write retries from
    /// identical state instead of double-applying.
    private func commitLifecycle(
        nextSession: LifecycleSession?,
        dispatching: () throws -> [OpportunityEventDraft],
    ) async throws {
        let checkpoint = checkpointCoordinator()
        do {
            let drafts = try dispatching()
            var candidate = coordinator.engine
            let synchronization = try await persistProtocolMutation(
                candidate: &candidate,
                drafts: drafts,
            )
            coordinator.engine = candidate
            lifecycleSession = nextSession
            publish(liveHeadsUp: nil)
            emitHeadsUpEffects(synchronization)
        } catch {
            restoreCoordinator(checkpoint)
            throw error
        }
    }
}

#if DEBUG
    extension ProtocolRuntime {
        var movementSessionDurationForVerification: TimeInterval? {
            switch lifecycleSession {
            case let .movement(selectedDuration): selectedDuration
            case .merged, nil: nil
            }
        }
    }
#endif
