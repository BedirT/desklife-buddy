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
        var candidate = engine
        let output = candidate.record(.breakStarted, opportunity: .movement, source: source)
        try await commitLifecycle(
            candidate: candidate,
            drafts: output.events,
            nextSession: .movement(selectedDuration: nil),
        )
    }

    private func selectMovement(_ duration: TimeInterval) async throws {
        guard case .movement = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        guard engine.isAcceptedMovementDuration(duration) else {
            throw ProtocolLifecycleError.invalidMovementDuration
        }
        var candidate = engine
        let output = candidate.selectMovement(durationSeconds: duration)
        try await commitLifecycle(
            candidate: candidate,
            drafts: output.events,
            nextSession: .movement(selectedDuration: duration),
        )
    }

    private func finishMovement(_ event: MovementLifecycleEvent) async throws {
        guard case .movement = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        var candidate = engine
        let output = movementTerminalOutput(event, candidate: &candidate)
        try await commitLifecycle(candidate: candidate, drafts: output.events, nextSession: nil)
    }

    private func openMerged(source: OpportunityEventSource) async throws {
        guard lifecycleSession == nil else { throw ProtocolLifecycleError.invalidTransition }
        var candidate = engine
        let output = candidate.record(.breakStarted, opportunity: .visual, source: source)
        try await commitLifecycle(
            candidate: candidate,
            drafts: output.events,
            nextSession: .merged(segment: .visual, selectedDuration: nil),
        )
    }

    private func finishMergedVisual(
        kind: OpportunityEventKind,
        source: OpportunityEventSource,
    ) async throws {
        guard lifecycleSession == .merged(segment: .visual, selectedDuration: nil) else {
            throw ProtocolLifecycleError.noActiveSession
        }
        var candidate = engine
        var drafts = candidate.record(
            kind,
            opportunity: .visual,
            source: source,
        ).events
        drafts += candidate.record(
            .breakStarted,
            opportunity: .movement,
            source: .localTimer,
        ).events
        try await commitLifecycle(
            candidate: candidate,
            drafts: drafts,
            nextSession: .merged(segment: .movement, selectedDuration: nil),
        )
    }

    private func reduceMergedMovement(_ event: MergedLifecycleEvent) async throws {
        guard case .merged(segment: .movement, selectedDuration: _) = lifecycleSession else {
            throw ProtocolLifecycleError.noActiveSession
        }
        var candidate = engine
        let output: ProtocolEngineOutput
        let nextSession: LifecycleSession?
        switch event {
        case let .selectedDuration(duration):
            guard engine.isAcceptedMovementDuration(duration) else {
                throw ProtocolLifecycleError.invalidMovementDuration
            }
            output = candidate.selectMovement(durationSeconds: duration)
            nextSession = .merged(segment: .movement, selectedDuration: duration)
        case .movementTimerFinished, .doneEarly, .alreadyMoved, .positionChanged:
            output = mergedMovementTerminalOutput(event, candidate: &candidate)
            nextSession = nil
        case .visualOnly:
            output = candidate.skipMergedSegment(.movement)
            nextSession = nil
        case .opened, .visualTimerFinished, .skipped:
            throw ProtocolLifecycleError.invalidTransition
        }
        try await commitLifecycle(
            candidate: candidate,
            drafts: output.events,
            nextSession: nextSession,
        )
    }

    private func skipMergedActiveSegment() async throws {
        let opportunity: OpportunityType = switch lifecycleSession {
        case .merged(segment: .visual, selectedDuration: _): .visual
        case .merged(segment: .movement, selectedDuration: _): .movement
        case .movement, nil: throw ProtocolLifecycleError.noActiveSession
        }
        var candidate = engine
        let output = candidate.skipMergedSegment(opportunity)
        try await commitLifecycle(candidate: candidate, drafts: output.events, nextSession: nil)
    }

    private func movementTerminalOutput(
        _ event: MovementLifecycleEvent,
        candidate: inout ProtocolEngine,
    ) -> ProtocolEngineOutput {
        switch event {
        case .timerFinished:
            candidate.record(.timerFinished, opportunity: .movement, source: .localTimer)
        case .doneEarly:
            candidate.record(.userDeclaredCompleted, opportunity: .movement)
        case .alreadyMoved:
            candidate.record(.userDeclaredAlreadyMoved, opportunity: .movement)
        case .positionChanged:
            candidate.record(.positionChanged, opportunity: .positionChange)
        case .skipped:
            candidate.record(.skipped, opportunity: .movement)
        case .opened, .selectedDuration:
            preconditionFailure("Movement terminal reducer received a non-terminal event")
        }
    }

    private func mergedMovementTerminalOutput(
        _ event: MergedLifecycleEvent,
        candidate: inout ProtocolEngine,
    ) -> ProtocolEngineOutput {
        switch event {
        case .movementTimerFinished:
            candidate.record(.timerFinished, opportunity: .movement, source: .localTimer)
        case .doneEarly:
            candidate.record(.userDeclaredCompleted, opportunity: .movement)
        case .alreadyMoved:
            candidate.record(.userDeclaredAlreadyMoved, opportunity: .movement)
        case .positionChanged:
            candidate.record(.positionChanged, opportunity: .positionChange)
        case .opened, .visualTimerFinished, .selectedDuration, .visualOnly, .skipped:
            preconditionFailure("Merged terminal reducer received a non-terminal event")
        }
    }

    private func commitLifecycle(
        candidate: ProtocolEngine,
        drafts: [OpportunityEventDraft],
        nextSession: LifecycleSession?,
    ) async throws {
        var candidate = candidate
        let synchronization = try await persistProtocolMutation(
            candidate: &candidate,
            drafts: drafts,
        )
        engine = candidate
        lifecycleSession = nextSession
        publish(liveHeadsUp: nil)
        emitHeadsUpEffects(synchronization)
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
