import Foundation

/// Canonical opportunity-action vocabulary for Story 2.3 (D-043
/// `timing_runtime_v2.yaml` action_contract transitions + protocol §17.4).
///
/// Every case names one registered transition. Standalone and merged exits
/// share one engine effect through the reducer mapping, so their facts and
/// clock deltas stay identical by construction. Kinds without a v1 engine
/// path (pause/hold/system/sensor/restart, content changes, Take with me)
/// commit operationally: validated identity, lease, rank, and fence with an
/// auditable receipt, but no fact and no clock mutation. Their clock and
/// evidence effects land with the owning clock/persistence stories.
///
/// The v1 matrix is preserved exactly: movement timer finish keeps movement
/// accrual and freshens visual; movement Done-early/already-moved freshen
/// movement only; visual exits freshen visual. D-043 deltas that need
/// four-clock/evidence machinery are documented at each mapping.
public enum OpportunityActionKind: String, Codable, Hashable, Sendable, CaseIterable {
    // MARK: Nonterminal opportunity intents

    case nowAcceptVisual
    case nowOpenMovementOffer
    case nowAcceptMovement
    case movementChangeContent
    case laterSnooze
    case nowAcceptRecovery
    case mergedAccept
    case mergedMovementAccept
    case mergedMovementChangeContent
    case companionTakeWithMe

    // MARK: Nonterminal global/system/schedule intents

    case pauseStart
    case pauseResume
    case holdBegin
    case holdRelease
    case holdCorrectionRelease
    case workingHoursExit
    case workingHoursEnter
    case systemUnavailable
    case systemAvailable
    case systemAvailableAfterExtended
    case systemShortInputIdle
    case systemLongIdleBegan
    case systemReturnedFromLongIdle
    case systemSampleGap
    case sensorStrongMovementRestart
    case scheduleRestartUndo

    // MARK: Terminal candidates

    case visualTimerFinished
    case visualDoneEarly
    case visualSkip
    case visualEscape
    case movementTimerFinished
    case movementDoneEarly
    case movementAlreadyMoved
    case movementPositionChangedOffered
    case movementPositionChangedRunning
    case movementSkipOffered
    case movementSkipRunning
    case movementEscapeOffered
    case movementEscapeRunning
    case positionChanged
    case positionSkip
    case mergedVisualSegmentFinished
    case mergedVisualSegmentDoneEarly
    case mergedMovementTimerFinished
    case mergedMovementDoneEarly
    case mergedMovementAlreadyMoved
    case mergedMovementPositionChanged
    case mergedMovementSkip
    case mergedVisualOnly
    case mergedEscapeDuringVisual
    case mergedEscapeDuringMovement
}

extension OpportunityActionKind {
    /// Whether settling this action closes its opportunity through the
    /// terminal reconciliation path. Merged visual-segment components only
    /// advance the visual segment and create the movement segment: they are
    /// nonterminal on purpose, so they bind the projection epoch without
    /// fencing it and a same-epoch movement accept can still commit after
    /// them. Only the movement-segment exit (or a standalone exit) closes
    /// and fences.
    var isTerminal: Bool {
        switch self {
        case .nowAcceptVisual, .nowOpenMovementOffer, .nowAcceptMovement,
             .movementChangeContent, .laterSnooze, .nowAcceptRecovery,
             .mergedAccept, .mergedMovementAccept, .mergedMovementChangeContent,
             .mergedVisualSegmentFinished, .mergedVisualSegmentDoneEarly,
             .companionTakeWithMe, .pauseStart, .pauseResume, .holdBegin,
             .holdRelease, .holdCorrectionRelease, .workingHoursExit,
             .workingHoursEnter, .systemUnavailable, .systemAvailable,
             .systemAvailableAfterExtended, .systemShortInputIdle,
             .systemLongIdleBegan, .systemReturnedFromLongIdle,
             .systemSampleGap, .sensorStrongMovementRestart, .scheduleRestartUndo:
            false
        default:
            true
        }
    }

    /// Whether this intent addresses the global coordinator state rather
    /// than one opportunity revision.
    var isGlobalScope: Bool {
        switch self {
        case .pauseStart, .pauseResume, .holdBegin, .holdRelease,
             .holdCorrectionRelease, .workingHoursExit, .workingHoursEnter,
             .systemUnavailable, .systemAvailable, .systemAvailableAfterExtended,
             .systemShortInputIdle, .systemLongIdleBegan,
             .systemReturnedFromLongIdle, .systemSampleGap,
             .sensorStrongMovementRestart, .scheduleRestartUndo:
            true
        default:
            false
        }
    }

    /// Registered rank inside one conflict key: smallest wins. Mirrors the
    /// contract `transition_rank_within_conflict_key` for the covered set.
    var sameKeyRank: Int {
        switch self {
        case .pauseStart: 0
        case .systemUnavailable: 5
        case .workingHoursExit: 10
        case .systemLongIdleBegan: 15
        case .holdBegin: 20
        case .laterSnooze: 25
        case .companionTakeWithMe: 30
        case .sensorStrongMovementRestart: 35
        case .scheduleRestartUndo: 36
        case .pauseResume: 40
        case .systemAvailableAfterExtended: 41
        case .systemAvailable: 42
        case .workingHoursEnter: 43
        case .systemReturnedFromLongIdle: 44
        case .holdCorrectionRelease: 45
        case .holdRelease: 46
        case .systemSampleGap: 50
        case .systemShortInputIdle: 51
        case .nowAcceptVisual: 60
        case .nowOpenMovementOffer: 61
        case .nowAcceptMovement: 62
        case .mergedAccept: 63
        case .mergedMovementAccept: 64
        case .nowAcceptRecovery: 65
        case .movementChangeContent: 70
        case .mergedMovementChangeContent: 71
        default: 90
        }
    }

    /// Terminal fact-claim rank: smallest wins. Skipped outranks completion;
    /// completion outranks timer finish. Arrival order never ranks.
    var terminalClaimRank: Int {
        switch factKind {
        case .some(.skipped): 0
        case .some(.snoozed): 5
        case .some(.notAppropriate): 10
        case .some(.positionChanged): 20
        case .some(.userDeclaredAlreadyMoved): 30
        case .some(.userDeclaredCompleted): 40
        case .some(.timerFinished): 50
        default: 60
        }
    }

    /// The single product fact this action settles, if any. Content changes,
    /// Take with me, pause/hold/system/sensor/restart, and the movement
    /// offer opening are fact-free by contract.
    var factKind: OpportunityEventKind? {
        switch self {
        case .nowAcceptVisual, .nowAcceptMovement, .nowAcceptRecovery,
             .mergedAccept, .mergedMovementAccept:
            .breakStarted
        case .visualTimerFinished, .movementTimerFinished,
             .mergedVisualSegmentFinished, .mergedMovementTimerFinished:
            .timerFinished
        case .visualDoneEarly, .movementDoneEarly,
             .mergedVisualSegmentDoneEarly, .mergedMovementDoneEarly:
            .userDeclaredCompleted
        case .movementAlreadyMoved, .mergedMovementAlreadyMoved:
            .userDeclaredAlreadyMoved
        case .movementPositionChangedOffered, .movementPositionChangedRunning,
             .positionChanged, .mergedMovementPositionChanged:
            .positionChanged
        case .visualSkip, .visualEscape, .movementSkipOffered,
             .movementSkipRunning, .movementEscapeOffered,
             .movementEscapeRunning, .positionSkip, .mergedMovementSkip,
             .mergedVisualOnly, .mergedEscapeDuringVisual,
             .mergedEscapeDuringMovement:
            .skipped
        default:
            nil
        }
    }
}

/// Participant scope one action addresses. The affected nonparticipant clock
/// (movement/movement-phase position exits) is declared by the kind, never by
/// widening the participant set.
public enum OpportunityActionScope: Equatable, Hashable, Sendable {
    case visual(cycle: ClockCycleID)
    case movement(cycle: ClockCycleID)
    case merged(visualCycle: ClockCycleID, movementCycle: ClockCycleID)
    case position(cycle: ClockCycleID)
    case globalSystem
}

extension OpportunityActionScope: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case cycle
        case visualCycle
        case movementCycle
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .kind) {
        case "visual":
            self = try .visual(cycle: container.decode(ClockCycleID.self, forKey: .cycle))
        case "movement":
            self = try .movement(cycle: container.decode(ClockCycleID.self, forKey: .cycle))
        case "merged":
            self = try .merged(
                visualCycle: container.decode(ClockCycleID.self, forKey: .visualCycle),
                movementCycle: container.decode(ClockCycleID.self, forKey: .movementCycle),
            )
        case "position":
            self = try .position(cycle: container.decode(ClockCycleID.self, forKey: .cycle))
        case "globalSystem":
            self = .globalSystem
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .kind,
                in: container,
                debugDescription: "OpportunityActionScope kind is unknown",
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .visual(cycle):
            try container.encode("visual", forKey: .kind)
            try container.encode(cycle, forKey: .cycle)
        case let .movement(cycle):
            try container.encode("movement", forKey: .kind)
            try container.encode(cycle, forKey: .cycle)
        case let .merged(visualCycle, movementCycle):
            try container.encode("merged", forKey: .kind)
            try container.encode(visualCycle, forKey: .visualCycle)
            try container.encode(movementCycle, forKey: .movementCycle)
        case let .position(cycle):
            try container.encode("position", forKey: .kind)
            try container.encode(cycle, forKey: .cycle)
        case .globalSystem:
            try container.encode("globalSystem", forKey: .kind)
        }
    }
}

/// Coarse origin phase named by every opportunity-scoped action. The engine
/// keeps the full phase graph; the reducer names only what guards require.
public enum OpportunityActionPhase: String, Codable, Hashable, Sendable {
    case offered
    case running
}

/// Validated payload for one action. All time is injected: durations from the
/// configured options, snooze reference dates from the caller.
public struct OpportunityActionPayload: Equatable, Hashable, Sendable {
    public var selectedDurationSeconds: TimeInterval?
    public var selectedSnoozeSeconds: TimeInterval?
    public var reofferCount: Int?
    public var referenceDate: Date?
    public var pauseRecordID: UUID?
    public var holdDecisionID: DecisionID?
    public var affectedPositionCycle: ClockCycleID?
    public var contentIdentifier: String?

    public init(
        selectedDurationSeconds: TimeInterval? = nil,
        selectedSnoozeSeconds: TimeInterval? = nil,
        reofferCount: Int? = nil,
        referenceDate: Date? = nil,
        pauseRecordID: UUID? = nil,
        holdDecisionID: DecisionID? = nil,
        affectedPositionCycle: ClockCycleID? = nil,
        contentIdentifier: String? = nil,
    ) {
        self.selectedDurationSeconds = selectedDurationSeconds
        self.selectedSnoozeSeconds = selectedSnoozeSeconds
        self.reofferCount = reofferCount
        self.referenceDate = referenceDate
        self.pauseRecordID = pauseRecordID
        self.holdDecisionID = holdDecisionID
        self.affectedPositionCycle = affectedPositionCycle
        self.contentIdentifier = contentIdentifier
    }
}

extension OpportunityActionPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case selectedDurationSeconds
        case selectedSnoozeSeconds
        case reofferCount
        case referenceDate
        case pauseRecordID
        case holdDecisionID
        case affectedPositionCycle
        case contentIdentifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            selectedDurationSeconds: container.decodeIfPresent(TimeInterval.self, forKey: .selectedDurationSeconds),
            selectedSnoozeSeconds: container.decodeIfPresent(TimeInterval.self, forKey: .selectedSnoozeSeconds),
            reofferCount: container.decodeIfPresent(Int.self, forKey: .reofferCount),
            referenceDate: container.decodeIfPresent(Date.self, forKey: .referenceDate),
            pauseRecordID: container.decodeIfPresent(UUID.self, forKey: .pauseRecordID),
            holdDecisionID: container.decodeIfPresent(DecisionID.self, forKey: .holdDecisionID),
            affectedPositionCycle: container.decodeIfPresent(ClockCycleID.self, forKey: .affectedPositionCycle),
            contentIdentifier: container.decodeIfPresent(String.self, forKey: .contentIdentifier),
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(selectedDurationSeconds, forKey: .selectedDurationSeconds)
        try container.encodeIfPresent(selectedSnoozeSeconds, forKey: .selectedSnoozeSeconds)
        try container.encodeIfPresent(reofferCount, forKey: .reofferCount)
        try container.encodeIfPresent(referenceDate, forKey: .referenceDate)
        try container.encodeIfPresent(pauseRecordID, forKey: .pauseRecordID)
        try container.encodeIfPresent(holdDecisionID, forKey: .holdDecisionID)
        try container.encodeIfPresent(affectedPositionCycle, forKey: .affectedPositionCycle)
        try container.encodeIfPresent(contentIdentifier, forKey: .contentIdentifier)
    }
}

/// One versioned action submitted to the canonical reducer. Opportunity
/// actions name origin revision, generation, projection epoch, origin phase,
/// and segment; global actions name the global revision instead.
public struct OpportunityActionEnvelope: Equatable, Hashable, Sendable {
    public let action: ActionID
    public let kind: OpportunityActionKind
    public let scope: OpportunityActionScope
    public let originRevision: UInt64
    public let generation: CoordinatorGeneration
    public let projectionEpoch: ProjectionEpochID?
    public let originPhase: OpportunityActionPhase?
    public let segmentID: MergedSegmentID?
    public let causalParents: [ActionID]
    public let lease: OpportunityLease?
    public let payload: OpportunityActionPayload

    public init(
        action: ActionID,
        kind: OpportunityActionKind,
        scope: OpportunityActionScope,
        originRevision: UInt64,
        generation: CoordinatorGeneration,
        projectionEpoch: ProjectionEpochID?,
        originPhase: OpportunityActionPhase?,
        segmentID: MergedSegmentID?,
        causalParents: [ActionID],
        lease: OpportunityLease?,
        payload: OpportunityActionPayload,
    ) {
        self.action = action
        self.kind = kind
        self.scope = scope
        self.originRevision = originRevision
        self.generation = generation
        self.projectionEpoch = projectionEpoch
        self.originPhase = originPhase
        self.segmentID = segmentID
        self.causalParents = causalParents
        self.lease = lease
        self.payload = payload
    }
}

extension OpportunityActionEnvelope: Codable {
    private enum CodingKeys: String, CodingKey {
        case action
        case kind
        case scope
        case originRevision
        case generation
        case projectionEpoch
        case originPhase
        case segmentID
        case causalParents
        case lease
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            action: container.decode(ActionID.self, forKey: .action),
            kind: container.decode(OpportunityActionKind.self, forKey: .kind),
            scope: container.decode(OpportunityActionScope.self, forKey: .scope),
            originRevision: container.decode(UInt64.self, forKey: .originRevision),
            generation: container.decode(CoordinatorGeneration.self, forKey: .generation),
            projectionEpoch: container.decodeIfPresent(ProjectionEpochID.self, forKey: .projectionEpoch),
            originPhase: container.decodeIfPresent(OpportunityActionPhase.self, forKey: .originPhase),
            segmentID: container.decodeIfPresent(MergedSegmentID.self, forKey: .segmentID),
            causalParents: container.decodeIfPresent([ActionID].self, forKey: .causalParents) ?? [],
            lease: container.decodeIfPresent(OpportunityLease.self, forKey: .lease),
            payload: container.decode(OpportunityActionPayload.self, forKey: .payload),
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        try container.encode(kind, forKey: .kind)
        try container.encode(scope, forKey: .scope)
        try container.encode(originRevision, forKey: .originRevision)
        try container.encode(generation, forKey: .generation)
        try container.encodeIfPresent(projectionEpoch, forKey: .projectionEpoch)
        try container.encodeIfPresent(originPhase, forKey: .originPhase)
        try container.encodeIfPresent(segmentID, forKey: .segmentID)
        try container.encode(causalParents, forKey: .causalParents)
        try container.encodeIfPresent(lease, forKey: .lease)
        try container.encode(payload, forKey: .payload)
    }
}

/// Auditable outcome of one reduced action. Rejections are no-ops with an
/// explicit reason; they never mutate clocks, emit facts, or erase later
/// effects.
public enum OpportunityActionOutcome: String, Codable, Hashable, Sendable {
    /// The action committed its fact and clock effect exactly once.
    case committed
    /// A duplicate ActionID replayed the original receipt without reapplying.
    case duplicateReplay
    /// The action named a generation that is no longer current.
    case rejectedStaleGeneration
    /// The action originated from a revision the frontier already advanced past.
    case rejectedStaleRevision
    /// The action arrived after its projection epoch fenced.
    case rejectedFencedEpoch
    /// An opportunity action carried a global lease, or the reverse.
    case rejectedScopeMismatch
    /// The lease was missing or not live at the coordinator ticks.
    case rejectedLeaseNotLive
    /// Payload, segment, or participant validation failed.
    case rejectedInvalidPayload
}

/// The auditable receipt for one reduced action: its outcome, the exact facts
/// it settled (at most one product fact), and the revisions it left behind.
public struct OpportunityActionReceipt: Equatable, Sendable, Codable {
    public let actionID: ActionID
    public let outcome: OpportunityActionOutcome
    public let facts: [OpportunityEventDraft]
    public let reason: String
    public let globalRevision: UInt64
    public let opportunityRevision: UInt64?

    public init(
        actionID: ActionID,
        outcome: OpportunityActionOutcome,
        facts: [OpportunityEventDraft],
        reason: String,
        globalRevision: UInt64,
        opportunityRevision: UInt64?,
    ) {
        self.actionID = actionID
        self.outcome = outcome
        self.facts = facts
        self.reason = reason
        self.globalRevision = globalRevision
        self.opportunityRevision = opportunityRevision
    }

    private enum CodingKeys: String, CodingKey {
        case actionID
        case outcome
        case facts
        case reason
        case globalRevision
        case opportunityRevision
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            actionID: container.decode(ActionID.self, forKey: .actionID),
            outcome: container.decode(OpportunityActionOutcome.self, forKey: .outcome),
            facts: container.decode([OpportunityEventDraft].self, forKey: .facts),
            reason: container.decode(String.self, forKey: .reason),
            globalRevision: container.decode(UInt64.self, forKey: .globalRevision),
            opportunityRevision: container.decodeIfPresent(UInt64.self, forKey: .opportunityRevision),
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(actionID, forKey: .actionID)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(facts, forKey: .facts)
        try container.encode(reason, forKey: .reason)
        try container.encode(globalRevision, forKey: .globalRevision)
        try container.encodeIfPresent(opportunityRevision, forKey: .opportunityRevision)
    }
}

/// Observable result of one coordinator-routed action: the auditable receipt
/// plus the single presentation the arbitration selects next.
public struct OpportunityActionOutput: Equatable, Sendable {
    public let receipt: OpportunityActionReceipt
    public let presentation: OpportunityPresentation?

    public init(receipt: OpportunityActionReceipt, presentation: OpportunityPresentation?) {
        self.receipt = receipt
        self.presentation = presentation
    }
}
