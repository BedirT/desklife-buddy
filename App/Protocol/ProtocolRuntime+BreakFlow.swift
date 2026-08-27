import BreakFlow
import Domain
import Foundation

enum BreakFlowRuntimeError: Error, Equatable {
    case unsupportedExactDeadline
    case unsupportedAction
}

extension ProtocolRuntime {
    func handleBreakFlow(_ action: BreakFlowAction) async throws {
        try await withLifecycleGate {
            switch action {
            case let .snooze(scope, durationSeconds):
                try await reduceBreakFlowSnooze(scope: scope, durationSeconds: durationSeconds)
            case .snoozeUntil:
                throw BreakFlowRuntimeError.unsupportedExactDeadline
            case .pauseOneHour:
                applyPause(.oneHour)
                lifecycleSession = nil
                publish(liveHeadsUp: nil)
            case let .notAppropriate(scope):
                try await reduceBreakFlowNotAppropriate(scope: scope)
            case let .skip(scope):
                try await reduceBreakFlowSkip(scope: scope)
            case .acknowledgementFinished, .chooseRecovery, .dismissRecovery:
                throw BreakFlowRuntimeError.unsupportedAction
            }
        }
    }

    private func reduceBreakFlowSnooze(
        scope: BreakScope,
        durationSeconds: TimeInterval,
    ) async throws {
        let actionDate = now()
        var candidate = engine
        var drafts: [OpportunityEventDraft] = []
        for opportunity in opportunities(for: scope) {
            let output = candidate.snooze(
                opportunity,
                durationSeconds: durationSeconds,
                at: actionDate,
            )
            guard output.events.count == 1 else {
                throw ProtocolLifecycleError.invalidSnoozeDuration
            }
            drafts += output.events
        }
        try await commitBreakFlow(
            candidate: candidate,
            drafts: drafts,
            recordedAt: actionDate,
        )
    }

    private func reduceBreakFlowNotAppropriate(scope: BreakScope) async throws {
        let actionDate = now()
        var candidate = engine
        var drafts: [OpportunityEventDraft] = []
        for opportunity in opportunities(for: scope) {
            drafts += candidate.record(
                .notAppropriate,
                opportunity: opportunity,
                source: .user,
            ).events
        }
        try await commitBreakFlow(
            candidate: candidate,
            drafts: drafts,
            recordedAt: actionDate,
        )
    }

    private func reduceBreakFlowSkip(scope: BreakScope) async throws {
        var candidate = engine
        let output: ProtocolEngineOutput = switch scope {
        case .visual:
            candidate.record(.skipped, opportunity: .visual, source: .user)
        case .movement:
            candidate.record(.skipped, opportunity: .movement, source: .user)
        case .merged:
            switch lifecycleSession {
            case .merged(segment: .visual, selectedDuration: _):
                candidate.skipMergedSegment(.visual)
            case .merged(segment: .movement, selectedDuration: _):
                candidate.skipMergedSegment(.movement)
            case nil:
                candidate.skipMergedSegment(.visual)
            case .movement:
                throw ProtocolLifecycleError.noActiveSession
            }
        }
        try await commitBreakFlow(candidate: candidate, drafts: output.events)
    }

    private func commitBreakFlow(
        candidate: ProtocolEngine,
        drafts: [OpportunityEventDraft],
        recordedAt: Date? = nil,
    ) async throws {
        try await persist(drafts, state: candidate.state, recordedAt: recordedAt)
        engine = candidate
        lifecycleSession = nil
        publish(liveHeadsUp: nil)
    }

    private func opportunities(for scope: BreakScope) -> [OpportunityType] {
        switch scope {
        case .visual: [.visual]
        case .movement: [.movement]
        case .merged: [.visual, .movement]
        }
    }
}
