import Foundation

/// One coordinator-routed mutation of the protocol engine.
///
/// Each case names the exact `ProtocolEngine` reduction it dispatches to. The
/// coordinator adds no policy of its own, so dispatching a command behaves
/// identically to calling the engine reduction directly.
public enum OpportunityCoordinatorCommand: Equatable, Sendable {
    /// Reduces one coarse system observation (`ProtocolEngine.observe`).
    case observe(
        sample: ActivitySample,
        activeSuppressions: Set<SuppressionReason>,
        isLowFrictionMoment: Bool
    )

    /// Applies one canonical event (`ProtocolEngine.record`).
    case record(
        kind: OpportunityEventKind,
        opportunity: OpportunityType?,
        selectedDurationSeconds: TimeInterval?,
        source: OpportunityEventSource
    )

    /// Records a validated snooze (`ProtocolEngine.snooze`).
    case snooze(opportunity: OpportunityType, durationSeconds: TimeInterval, at: Date)

    /// Accepts an explicit movement duration (`ProtocolEngine.selectMovement`).
    case selectMovement(durationSeconds: TimeInterval)

    /// Applies merged Escape semantics (`ProtocolEngine.skipMergedSegment`).
    case skipMergedSegment(OpportunityType)

    /// Applies merged Escape-during-visual through the canonical D-043
    /// `merged.escape_during_visual` effect
    /// (`ProtocolEngine.applyMergedEscapeDuringVisual`: fresh visual cycle
    /// plus fresh movement cycle with one deferral and one skip). This is the
    /// only route production Escape-during-visual callers may use; the legacy
    /// retaining `skipMergedSegment` route stays for movement-segment paths.
    case mergedEscapeDuringVisual

    /// Expires retained snoozes (`ProtocolEngine.resumeExpiredSnoozes`).
    case resumeExpiredSnoozes(at: Date)

    /// Rotates recovery-session debt (`ProtocolEngine.observeRecoverySession`).
    case observeRecoverySession(at: Date, systemAvailable: Bool)

    /// Applies an offline boundary during restore (`ProtocolEngine.resumeRecoverySession`).
    case resumeRecoverySession(at: Date)

    /// Repairs a crash-interrupted break (`ProtocolEngine.resumeInterruptedBreak`).
    case resumeInterruptedBreak
}

/// Observable result of one coordinator-dispatched command: the emitted event
/// facts plus the single presentation the arbitration selected next.
public struct OpportunityCoordinatorOutput: Equatable, Sendable {
    public let events: [OpportunityEventDraft]
    public let presentation: OpportunityPresentation?

    /// Creates an output from its emitted facts and selected presentation.
    public init(events: [OpportunityEventDraft], presentation: OpportunityPresentation?) {
        self.events = events
        self.presentation = presentation
    }
}

extension OpportunityCoordinatorOutput {
    init(_ output: ProtocolEngineOutput) {
        self.init(events: output.events, presentation: output.presentation)
    }
}
