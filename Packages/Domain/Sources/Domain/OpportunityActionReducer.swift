import Foundation

/// The one canonical opportunity-action reducer (Story 2.3, D-043
/// action_contract + protocol §17.4-17.5).
///
/// Every action flows through this reducer: standalone and merged exits share
/// one engine-effect path, so their facts and clock deltas stay identical by
/// construction. Reductions are commutative, associative, and idempotent —
/// every permutation of one candidate set settles the same winner, one fact,
/// and one fenced successor.
///
/// Settlement order inside one transaction:
/// 1. Duplicate ActionIDs replay their original receipt without reapplying.
///    Fence and dedup state is session-scoped: it lives in this struct until
///    story 2.5 persists it, so cross-restart crash-replay dedup is a 2.5
///    entry requirement, not a 2.3 claim.
/// 2. Structural validation against the snapshot (generation, lease, scope,
///    epoch fence, revision, payload/segment guards).
/// 3. Terminal candidates settle to one winner by claim rank
///    (skipped < already-moved < completed < timer finish); losers
///    revalidate against the fenced successor.
/// 4. Nonterminal winners settle per conflict key by transition rank; losers
///    revalidate. Compatible disjoint keys all commit.
///
/// `reduce(_:on:atTicks:)` is the single-action transaction: the winner
/// settles immediately. Waiting windows for distributed settlement arrive
/// with companion scope; v1 documents the simplification here rather than
/// holding actions open.
///
/// The v1 engine owns clocks, phases, and facts. The reducer adds no policy
/// of its own: unsupported durations, unknown snoozes, and invalid records
/// fail closed through the same empty-output verdict the engine returns, and
/// phase guards stay with the engine (whose `record` path never gated on
/// phase). D-043 deltas that need four-clock/evidence machinery are mapped
/// to the closest v1 effect and marked at each site.
public struct OpportunityActionReducer: Sendable {
    public var generation: CoordinatorGeneration
    public var globalRevision: UInt64
    public var opportunityRevisions: [OpportunityID: UInt64]
    public var projectionEpochs: [OpportunityID: ProjectionEpochID]
    public var fencedEpochs: Set<ProjectionEpochID>
    public var committedActions: [ActionID: OpportunityActionReceipt]
    public var mergedSessions: [OpportunityID: OpportunityMergedSession]

    public init(
        generation: CoordinatorGeneration = CoordinatorGeneration(0),
        globalRevision: UInt64 = 0,
        opportunityRevisions: [OpportunityID: UInt64] = [:],
        projectionEpochs: [OpportunityID: ProjectionEpochID] = [:],
        fencedEpochs: Set<ProjectionEpochID> = [],
        committedActions: [ActionID: OpportunityActionReceipt] = [:],
        mergedSessions: [OpportunityID: OpportunityMergedSession] = [:],
    ) {
        self.generation = generation
        self.globalRevision = globalRevision
        self.opportunityRevisions = opportunityRevisions
        self.projectionEpochs = projectionEpochs
        self.fencedEpochs = fencedEpochs
        self.committedActions = committedActions
        self.mergedSessions = mergedSessions
    }

    /// Restores fence/dedup state previously captured as `fenceState` (Story
    /// 2.5 crash-replay continuity). No fact, clock, or revision is
    /// re-applied: the snapshot only re-arms dedup and fences so a
    /// resubmitted ActionID replays instead of recommitting.
    public init(fenceState: CoordinatorFenceState) {
        self.generation = fenceState.generation
        self.globalRevision = fenceState.globalRevision
        self.opportunityRevisions = fenceState.opportunityRevisions
        self.projectionEpochs = fenceState.projectionEpochs
        self.fencedEpochs = fenceState.fencedEpochs
        self.committedActions = fenceState.committedActions
        self.mergedSessions = fenceState.mergedSessions
    }

    /// Captures the restart-safe fence/dedup subset for persistence: the
    /// causal generation, global and opportunity revisions, bound projection
    /// epochs, fenced epochs, committed ActionIDs with their receipts, and
    /// merged sessions. Received/losing/duplicate/rejected candidate buffers
    /// are Class 0 memory-only by contract and are never part of this
    /// snapshot; the committed map is the replay authority, not a buffer.
    public var fenceState: CoordinatorFenceState {
        CoordinatorFenceState(
            generation: generation,
            globalRevision: globalRevision,
            opportunityRevisions: opportunityRevisions,
            projectionEpochs: projectionEpochs,
            fencedEpochs: fencedEpochs,
            committedActions: committedActions,
            mergedSessions: mergedSessions,
        )
    }

    /// One merged delivery session: the created visual segment, the movement
    /// segment once the visual exit commits, and the revision that created it.
    public struct OpportunityMergedSession: Equatable, Sendable, Codable {
        public let opportunityID: OpportunityID
        public var visualSegmentID: MergedSegmentID
        public var movementSegmentID: MergedSegmentID?
        public var revision: UInt64

        public init(
            opportunityID: OpportunityID,
            visualSegmentID: MergedSegmentID,
            movementSegmentID: MergedSegmentID?,
            revision: UInt64,
        ) {
            self.opportunityID = opportunityID
            self.visualSegmentID = visualSegmentID
            self.movementSegmentID = movementSegmentID
            self.revision = revision
        }
    }


    public func mergedSession(for opportunity: OpportunityID) -> OpportunityMergedSession? {
        mergedSessions[opportunity]
    }

    /// Reduces one action as a single-action transaction.
    public mutating func reduce(
        _ envelope: OpportunityActionEnvelope,
        on engine: inout ProtocolEngine,
        atTicks: TimeInterval,
    ) -> OpportunityActionReceipt {
        reduceAll([envelope], on: &engine, atTicks: atTicks)[0]
    }

    /// Reduces one transaction of actions to one receipt per action.
    public mutating func reduceAll(
        _ envelopes: [OpportunityActionEnvelope],
        on engine: inout ProtocolEngine,
        atTicks: TimeInterval,
    ) -> [OpportunityActionReceipt] {
        var receipts: [OpportunityActionReceipt] = []
        receipts.reserveCapacity(envelopes.count)

        var candidates: [OpportunityActionEnvelope] = []
        candidates.reserveCapacity(envelopes.count)
        for envelope in envelopes {
            if let original = committedActions[envelope.action] {
                receipts.append(OpportunityActionReceipt(
                    actionID: envelope.action,
                    outcome: .duplicateReplay,
                    facts: original.facts,
                    reason: "Duplicate ActionID replays the original receipt without reapplying.",
                    globalRevision: globalRevision,
                    opportunityRevision: opportunityRevision(for: envelope),
                ))
            } else {
                candidates.append(envelope)
            }
        }

        var valid: [OpportunityActionEnvelope] = []
        valid.reserveCapacity(candidates.count)
        for envelope in candidates {
            if let failure = validate(envelope, atTicks: atTicks) {
                receipts.append(reject(envelope, failure: failure))
            } else {
                valid.append(envelope)
            }
        }

        // Terminal settlement first: one winner by claim rank. Every loser
        // revalidates against the fenced successor, so simultaneous
        // candidates converge no matter the arrival order.
        var remaining = valid
        let terminals = valid.filter { $0.kind.isTerminal }.sorted(by: terminalOrder(_:_:))
        if let winner = terminals.first {
            receipts.append(commit(winner, on: &engine))
            for loser in valid where loser.action != winner.action && loser.kind.isTerminal {
                receipts.append(revalidate(loser, atTicks: atTicks))
            }
            remaining.removeAll { $0.kind.isTerminal }
        }

        // A terminal winner advances the revision and fences the epoch, so
        // remaining nonterminals revalidate before key settlement: same
        // revision losers reject against the successor instead of applying.
        // Compatible disjoint scopes (for example global plumbing) stay
        // valid and still commit.
        var survivors: [OpportunityActionEnvelope] = []
        survivors.reserveCapacity(remaining.count)
        for envelope in remaining where !envelope.kind.isTerminal {
            if let failure = validate(envelope, atTicks: atTicks) {
                receipts.append(reject(envelope, failure: failure))
            } else {
                survivors.append(envelope)
            }
        }
        // Nonterminal settlement per conflict key in canonical key order.
        // Survivors were valid against the post-terminal state and never
        // conflict, so winners commit while losers revalidate for a truthful
        // receipt. Compatible disjoint keys all commit.
        var byKey: [OpportunityConflictKey: [OpportunityActionEnvelope]] = [:]
        for envelope in survivors {
            byKey[conflictKey(for: envelope), default: []].append(envelope)
        }
        for key in byKey.keys.sorted() {
            let contenders = byKey[key]!.sorted(by: nonterminalOrder(_:_:))
            guard let winner = contenders.first else { continue }
            receipts.append(commit(winner, on: &engine))
            for loser in contenders.dropFirst() {
                receipts.append(revalidateWithSameKeyLoss(
                    loser,
                    winner: winner.action.uuid,
                    atTicks: atTicks,
                ))
            }
        }
        return receipts
    }

    // MARK: - Generation rotation

    /// Advances the action generation after session-rotation evidence (a
    /// committed likely-natural-interruption fact). Every pre-rotation offer
    /// fences from here on; leases granted under the retired generation stop
    /// authorizing. Rotation evidence flows through the coordinator seam,
    /// which advances automatically on dispatch and exposes this for
    /// restore paths.
    public mutating func noteSessionRotation() {
        generation = generation.advanced()
    }

}

/// Restart-safe fence/dedup snapshot for the coordinator (Story 2.5).
///
/// This is the exact crash-replay authority the contract requires to
/// survive restore: the generation (the causal clock; not elapsed time),
/// global and opportunity revisions, bound projection epochs, fenced epochs,
/// committed ActionIDs with their auditable receipts (authorship device +
/// gap-free counter ride along, never regenerated), and merged sessions. It
/// carries no clocks, no wall-time anchors, and no Class 0 candidate
/// buffers.
public struct CoordinatorFenceState: Equatable, Sendable {
    public var generation: CoordinatorGeneration
    public var globalRevision: UInt64
    public var opportunityRevisions: [OpportunityID: UInt64]
    public var projectionEpochs: [OpportunityID: ProjectionEpochID]
    public var fencedEpochs: Set<ProjectionEpochID>
    public var committedActions: [ActionID: OpportunityActionReceipt]
    public var mergedSessions: [OpportunityID: OpportunityActionReducer.OpportunityMergedSession]

    public init(
        generation: CoordinatorGeneration = CoordinatorGeneration(0),
        globalRevision: UInt64 = 0,
        opportunityRevisions: [OpportunityID: UInt64] = [:],
        projectionEpochs: [OpportunityID: ProjectionEpochID] = [:],
        fencedEpochs: Set<ProjectionEpochID> = [],
        committedActions: [ActionID: OpportunityActionReceipt] = [:],
        mergedSessions: [OpportunityID: OpportunityActionReducer.OpportunityMergedSession] = [:],
    ) {
        self.generation = generation
        self.globalRevision = globalRevision
        self.opportunityRevisions = opportunityRevisions
        self.projectionEpochs = projectionEpochs
        self.fencedEpochs = fencedEpochs
        self.committedActions = committedActions
        self.mergedSessions = mergedSessions
    }
}

extension CoordinatorFenceState: Codable {
    private enum CodingKeys: String, CodingKey {
        case generation
        case globalRevision
        case opportunityRevisions
        case projectionEpochs
        case fencedEpochs
        case committedActions
        case mergedSessions
    }

    private struct OpportunityRevisionRecord: Codable {
        var opportunity: OpportunityID
        var revision: UInt64
    }

    private struct ProjectionEpochRecord: Codable {
        var opportunity: OpportunityID
        var epoch: ProjectionEpochID
    }

    private struct CommittedActionRecord: Codable {
        var action: ActionID
        var receipt: OpportunityActionReceipt
    }

    private struct MergedSessionRecord: Codable {
        var opportunity: OpportunityID
        var session: OpportunityActionReducer.OpportunityMergedSession
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        generation = try container.decode(CoordinatorGeneration.self, forKey: .generation)
        globalRevision = try container.decode(UInt64.self, forKey: .globalRevision)
        let revisions = try container.decode([OpportunityRevisionRecord].self, forKey: .opportunityRevisions)
        opportunityRevisions = try Self.uniquelyKeyed(
            revisions,
            key: \.opportunity,
            value: \.revision,
            forKey: .opportunityRevisions,
            codingPath: container.codingPath,
        )
        let epochs = try container.decode([ProjectionEpochRecord].self, forKey: .projectionEpochs)
        projectionEpochs = try Self.uniquelyKeyed(
            epochs,
            key: \.opportunity,
            value: \.epoch,
            forKey: .projectionEpochs,
            codingPath: container.codingPath,
        )
        fencedEpochs = Set(try container.decode([ProjectionEpochID].self, forKey: .fencedEpochs))
        let actions = try container.decode([CommittedActionRecord].self, forKey: .committedActions)
        committedActions = try Self.uniquelyKeyed(
            actions,
            key: \.action,
            value: \.receipt,
            forKey: .committedActions,
            codingPath: container.codingPath,
        )
        let sessions = try container.decode([MergedSessionRecord].self, forKey: .mergedSessions)
        mergedSessions = try Self.uniquelyKeyed(
            sessions,
            key: \.opportunity,
            value: \.session,
            forKey: .mergedSessions,
            codingPath: container.codingPath,
        )
    }

    /// Builds a keyed map from decoded records, failing closed on duplicates.
    /// A tampered payload carrying two records for one key throws
    /// `DecodingError.dataCorrupted` (surfaced as invalidCoordinatorFenceState
    /// at the store boundary) instead of trapping in
    /// `Dictionary(uniqueKeysWithValues:)` on the launch path.
    private static func uniquelyKeyed<Record, Key: Hashable, Value>(
        _ records: [Record],
        key keyPath: KeyPath<Record, Key>,
        value valuePath: KeyPath<Record, Value>,
        forKey codingKey: CodingKeys,
        codingPath: [CodingKey],
    ) throws -> [Key: Value] {
        var map: [Key: Value] = [:]
        map.reserveCapacity(records.count)
        for record in records {
            let key = record[keyPath: keyPath]
            guard map[key] == nil else {
                throw DecodingError.dataCorrupted(DecodingError.Context(
                    codingPath: codingPath + [codingKey],
                    debugDescription: "Duplicate coordinator fence record for one key.",
                ))
            }
            map[key] = record[keyPath: valuePath]
        }
        return map
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generation, forKey: .generation)
        try container.encode(globalRevision, forKey: .globalRevision)
        try container.encode(
            opportunityRevisions
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { OpportunityRevisionRecord(opportunity: $0.key, revision: $0.value) },
            forKey: .opportunityRevisions,
        )
        try container.encode(
            projectionEpochs
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { ProjectionEpochRecord(opportunity: $0.key, epoch: $0.value) },
            forKey: .projectionEpochs,
        )
        try container.encode(
            fencedEpochs.sorted { $0.uuid.uuidString < $1.uuid.uuidString },
            forKey: .fencedEpochs,
        )
        try container.encode(
            committedActions
                .sorted {
                    if $0.key.deviceID.uuid.uuidString != $1.key.deviceID.uuid.uuidString {
                        return $0.key.deviceID.uuid.uuidString < $1.key.deviceID.uuid.uuidString
                    }
                    if $0.key.counter != $1.key.counter { return $0.key.counter < $1.key.counter }
                    return $0.key.uuid.uuidString < $1.key.uuid.uuidString
                }
                .map { CommittedActionRecord(action: $0.key, receipt: $0.value) },
            forKey: .committedActions,
        )
        try container.encode(
            mergedSessions
                .sorted { $0.key.uuid.uuidString < $1.key.uuid.uuidString }
                .map { MergedSessionRecord(opportunity: $0.key, session: $0.value) },
            forKey: .mergedSessions,
        )
    }
}

// MARK: - Validation

extension OpportunityActionReducer {

    private enum ValidationFailure: Equatable {
        case staleGeneration
        case staleRevision(String)
        case fencedEpoch
        case scopeMismatch
        case leaseNotLive(String)
        case invalidPayload(String)
    }

    private func opportunityRevision(for envelope: OpportunityActionEnvelope) -> UInt64? {
        guard let id = envelope.lease?.scope.opportunityID else { return nil }
        return opportunityRevisions[id, default: 0]
    }

    private func validate(
        _ envelope: OpportunityActionEnvelope,
        atTicks: TimeInterval,
    ) -> ValidationFailure? {
        guard envelope.generation == generation else { return .staleGeneration }
        guard let lease = envelope.lease else {
            return .leaseNotLive("The action carries no lease.")
        }
        let needsGlobalLease = envelope.kind.isGlobalScope
        guard lease.scope.isGlobal == needsGlobalLease else { return .scopeMismatch }
        guard lease.generation == generation else {
            return .leaseNotLive("The lease was granted under a retired generation.")
        }
        guard lease.isLive(atTicks: atTicks) else {
            return .leaseNotLive("The lease is not live at the coordinator ticks.")
        }
        // A lease is issued for one scope revision: advancing the revision
        // revokes predecessor leases, so the lease revision must match the
        // envelope's origin revision exactly.
        guard lease.scope.scopeRevision == envelope.originRevision else {
            return .leaseNotLive("The lease was issued for a spent revision; advancing the revision revoked it.")
        }
        if needsGlobalLease {
            guard envelope.originRevision == globalRevision else {
                return .staleRevision("The action originated from global revision \(envelope.originRevision) past \(globalRevision).")
            }
            return validateGlobalPayload(envelope)
        }
        guard let opportunityID = lease.scope.opportunityID else {
            return .scopeMismatch
        }
        guard let epoch = envelope.projectionEpoch else {
            return .invalidPayload("An opportunity action must name its projection epoch.")
        }
        // An opportunity lease is bound to one projection epoch: it
        // authorizes only actions naming that epoch, so fencing the epoch on
        // closure revokes every lease bound to it.
        guard lease.projectionEpoch == epoch else {
            return .leaseNotLive("The lease is not bound to this projection epoch.")
        }
        if fencedEpochs.contains(epoch) { return .fencedEpoch }
        if let bound = projectionEpochs[opportunityID], bound != epoch {
            return .staleRevision("The action names a projection epoch that is no longer bound.")
        }
        guard envelope.originRevision == opportunityRevisions[opportunityID, default: 0] else {
            return .staleRevision("The action originated from opportunity revision \(envelope.originRevision) past \(opportunityRevisions[opportunityID, default: 0]).")
        }
        return validateOpportunityPayload(envelope, opportunityID: opportunityID)
    }

    private func validateGlobalPayload(
        _ envelope: OpportunityActionEnvelope,
    ) -> ValidationFailure? {
        switch envelope.kind {
        case .pauseStart, .pauseResume:
            guard envelope.payload.pauseRecordID != nil else {
                return .invalidPayload("A pause action must name its pause record.")
            }
            return nil
        case .holdBegin, .holdRelease, .holdCorrectionRelease:
            guard envelope.payload.holdDecisionID != nil else {
                return .invalidPayload("A hold action must name its hold decision.")
            }
            return nil
        default:
            return nil
        }
    }

    private func validateOpportunityPayload(
        _ envelope: OpportunityActionEnvelope,
        opportunityID: OpportunityID,
    ) -> ValidationFailure? {
        switch envelope.kind {
        case .laterSnooze:
            switch envelope.scope {
            case .visual, .movement: break
            default:
                return .invalidPayload("Only single-clock scopes can snooze in v1; merged snooze needs per-clock deadlines.")
            }
            guard envelope.payload.selectedSnoozeSeconds != nil,
                  envelope.payload.referenceDate != nil
            else {
                return .invalidPayload("A snooze must name its duration and reference date.")
            }
            return nil
        case .mergedMovementAccept:
            // No exit action may consume a segment before its creation commit.
            guard let session = mergedSessions[opportunityID],
                  let movementSegment = session.movementSegmentID
            else {
                return .invalidPayload("The movement segment does not exist yet.")
            }
            if let named = envelope.segmentID, named != movementSegment {
                return .invalidPayload("The action names a segment that was never created.")
            }
            return nil
        case .mergedVisualSegmentFinished, .mergedVisualSegmentDoneEarly:
            if let session = mergedSessions[opportunityID],
               let named = envelope.segmentID, named != session.visualSegmentID
            {
                return .invalidPayload("The action names a segment that was never created.")
            }
            return nil
        default:
            return nil
        }
    }

    private func reject(
        _ envelope: OpportunityActionEnvelope,
        failure: ValidationFailure,
    ) -> OpportunityActionReceipt {
        let outcome: OpportunityActionOutcome
        let reason: String
        switch failure {
        case .staleGeneration:
            outcome = .rejectedStaleGeneration
            reason = "The action names a generation that is no longer current."
        case let .staleRevision(detail):
            outcome = .rejectedStaleRevision
            reason = detail
        case .fencedEpoch:
            outcome = .rejectedFencedEpoch
            reason = "The action arrived after its projection epoch fenced."
        case .scopeMismatch:
            outcome = .rejectedScopeMismatch
            reason = "An opportunity action requires an opportunity lease and a global action requires a global lease."
        case let .leaseNotLive(detail):
            outcome = .rejectedLeaseNotLive
            reason = detail
        case let .invalidPayload(detail):
            outcome = .rejectedInvalidPayload
            reason = detail
        }
        return OpportunityActionReceipt(
            actionID: envelope.action,
            outcome: outcome,
            facts: [],
            reason: reason,
            globalRevision: globalRevision,
            opportunityRevision: opportunityRevision(for: envelope),
        )
    }

    private func revalidate(
        _ envelope: OpportunityActionEnvelope,
        atTicks: TimeInterval,
    ) -> OpportunityActionReceipt {
        if committedActions[envelope.action] != nil {
            let original = committedActions[envelope.action]!
            return OpportunityActionReceipt(
                actionID: envelope.action,
                outcome: .duplicateReplay,
                facts: original.facts,
                reason: "Duplicate ActionID replays the original receipt without reapplying.",
                globalRevision: globalRevision,
                opportunityRevision: opportunityRevision(for: envelope),
            )
        }
        if let failure = validate(envelope, atTicks: atTicks) {
            return reject(envelope, failure: failure)
        }
        // Valid against the successor but no longer a winner: the successor
        // revision advanced past it.
        return OpportunityActionReceipt(
            actionID: envelope.action,
            outcome: .rejectedStaleRevision,
            facts: [],
            reason: "The frontier settled another winner for this revision first.",
            globalRevision: globalRevision,
            opportunityRevision: opportunityRevision(for: envelope),
        )
    }

    private func revalidateWithSameKeyLoss(
        _ envelope: OpportunityActionEnvelope,
        winner: UUID,
        atTicks: TimeInterval,
    ) -> OpportunityActionReceipt {
        if let failure = validate(envelope, atTicks: atTicks) {
            return reject(envelope, failure: failure)
        }
        return OpportunityActionReceipt(
            actionID: envelope.action,
            outcome: .rejectedStaleRevision,
            facts: [],
            reason: "Lost same-key rank to \(winner.uuidString.lowercased()).",
            globalRevision: globalRevision,
            opportunityRevision: opportunityRevision(for: envelope),
        )
    }

    // MARK: - Ordering

    private func terminalOrder(
        _ lhs: OpportunityActionEnvelope,
        _ rhs: OpportunityActionEnvelope,
    ) -> Bool {
        if lhs.kind.terminalClaimRank != rhs.kind.terminalClaimRank {
            return lhs.kind.terminalClaimRank < rhs.kind.terminalClaimRank
        }
        if lhs.kind.rawValue != rhs.kind.rawValue {
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
        if lhs.action.deviceID != rhs.action.deviceID {
            return lhs.action.deviceID.uuid.uuidString < rhs.action.deviceID.uuid.uuidString
        }
        if lhs.action.counter != rhs.action.counter {
            return lhs.action.counter < rhs.action.counter
        }
        return lhs.action.uuid.uuidString < rhs.action.uuid.uuidString
    }

    private func nonterminalOrder(
        _ lhs: OpportunityActionEnvelope,
        _ rhs: OpportunityActionEnvelope,
    ) -> Bool {
        if lhs.kind.sameKeyRank != rhs.kind.sameKeyRank {
            return lhs.kind.sameKeyRank < rhs.kind.sameKeyRank
        }
        return lhs.action.uuid.uuidString < rhs.action.uuid.uuidString
    }
}

// MARK: - Commit

extension OpportunityActionReducer {
    private mutating func commit(
        _ envelope: OpportunityActionEnvelope,
        on engine: inout ProtocolEngine,
    ) -> OpportunityActionReceipt {
        let effect = applyEffect(envelope, on: &engine)
        guard let facts = effect else {
            return reject(envelope, failure: .invalidPayload("The engine declined the effect without emitting a fact."))
        }
        if envelope.kind.isGlobalScope {
            globalRevision &+= 1
            let receipt = OpportunityActionReceipt(
                actionID: envelope.action,
                outcome: .committed,
                facts: facts,
                reason: "Committed.",
                globalRevision: globalRevision,
                opportunityRevision: opportunityRevision(for: envelope),
            )
            committedActions[envelope.action] = receipt
            return receipt
        }
        let opportunityID = envelope.lease!.scope.opportunityID!
        if projectionEpochs[opportunityID] == nil {
            projectionEpochs[opportunityID] = envelope.projectionEpoch
        }
        if envelope.kind.isTerminal, let epoch = envelope.projectionEpoch {
            fencedEpochs.insert(epoch)
        }
        opportunityRevisions[opportunityID, default: 0] &+= 1
        updateSession(for: envelope, opportunityID: opportunityID)
        let receipt = OpportunityActionReceipt(
            actionID: envelope.action,
            outcome: .committed,
            facts: facts,
            reason: "Committed.",
            globalRevision: globalRevision,
            opportunityRevision: opportunityRevisions[opportunityID],
        )
        committedActions[envelope.action] = receipt
        return receipt
    }

    private mutating func updateSession(
        for envelope: OpportunityActionEnvelope,
        opportunityID: OpportunityID,
    ) {
        switch envelope.kind {
        case .mergedAccept:
            mergedSessions[opportunityID] = OpportunityMergedSession(
                opportunityID: opportunityID,
                visualSegmentID: MergedSegmentID.visual(for: OpportunityID(opportunityID.uuid)),
                movementSegmentID: nil,
                revision: opportunityRevisions[opportunityID, default: 0],
            )
        case .mergedVisualSegmentFinished, .mergedVisualSegmentDoneEarly:
            if mergedSessions[opportunityID] != nil {
                mergedSessions[opportunityID]!.movementSegmentID =
                    MergedSegmentID.movement(for: OpportunityID(opportunityID.uuid))
                mergedSessions[opportunityID]!.revision = opportunityRevisions[opportunityID, default: 0]
            }
        default:
            if mergedSessions[opportunityID] != nil {
                mergedSessions[opportunityID]!.revision = opportunityRevisions[opportunityID, default: 0]
            }
        }
    }

    /// Applies the one shared engine effect for the kind. Returns nil when
    /// the engine declines without emitting a fact, which the commit turns
    /// into an auditable invalid-payload rejection.
    private mutating func applyEffect(
        _ envelope: OpportunityActionEnvelope,
        on engine: inout ProtocolEngine,
    ) -> [OpportunityEventDraft]? {
        if let spec = recordedEffectSpecs[envelope.kind] {
            let output = engine.record(
                spec.event,
                opportunity: spec.opportunity,
                selectedDurationSeconds: spec.usesDuration ? envelope.payload.selectedDurationSeconds : nil,
                source: spec.source,
            )
            return output.events.isEmpty ? nil : output.events
        }
        if factFreeKinds.contains(envelope.kind) {
            // The offer opening, content changes, and operational plumbing
            // commit identity, rank, and fence with no fact and no clock delta.
            return []
        }
        switch envelope.kind {
        case .nowAcceptMovement, .mergedMovementAccept:
            guard let duration = envelope.payload.selectedDurationSeconds else { return nil }
            let output = engine.selectMovement(durationSeconds: duration)
            return output.events.isEmpty ? nil : output.events
        case .laterSnooze:
            return applyLaterSnooze(envelope, on: &engine)
        case .mergedVisualOnly:
            // The visual component already settled; the movement side retains
            // accrual with one deferral and one skip.
            engine.noteMovementDeferral()
            return [OpportunityEventDraft(
                kind: .skipped,
                source: .user,
                opportunity: .movement,
                selectedDurationSeconds: nil,
            )]
        case .mergedEscapeDuringVisual:
            return [engine.applyMergedEscapeDuringVisual()]
        default:
            return nil
        }
    }

    private mutating func applyLaterSnooze(
        _ envelope: OpportunityActionEnvelope,
        on engine: inout ProtocolEngine,
    ) -> [OpportunityEventDraft]? {
        guard let snoozeSeconds = envelope.payload.selectedSnoozeSeconds,
              let referenceDate = envelope.payload.referenceDate
        else { return nil }
        let opportunity: OpportunityType
        switch envelope.scope {
        case .visual: opportunity = .visual
        case .movement: opportunity = .movement
        default: return nil
        }
        let output = engine.snooze(opportunity, durationSeconds: snoozeSeconds, at: referenceDate)
        return output.events.isEmpty ? nil : output.events
    }
}

/// One table-driven engine record: the event fact, its opportunity, source,
/// and whether the envelope's selected duration rides along.
private struct RecordedEffectSpec: Sendable {
    let event: OpportunityEventKind
    let opportunity: OpportunityType
    let source: OpportunityEventSource
    let usesDuration: Bool
}

/// The 26 kinds whose effect is exactly one engine record. Standalone and
/// merged exits share one row each, so their semantics stay identical by
/// sharing one code path.
private let recordedEffectSpecs: [OpportunityActionKind: RecordedEffectSpec] = [
    .nowAcceptVisual: RecordedEffectSpec(event: .breakStarted, opportunity: .visual, source: .user, usesDuration: true),
    .mergedAccept: RecordedEffectSpec(event: .breakStarted, opportunity: .visual, source: .user, usesDuration: true),
    .nowAcceptRecovery: RecordedEffectSpec(event: .breakStarted, opportunity: .recovery, source: .user, usesDuration: false),
    .visualTimerFinished: RecordedEffectSpec(event: .timerFinished, opportunity: .visual, source: .localTimer, usesDuration: false),
    .mergedVisualSegmentFinished: RecordedEffectSpec(event: .timerFinished, opportunity: .visual, source: .localTimer, usesDuration: false),
    .visualDoneEarly: RecordedEffectSpec(event: .userDeclaredCompleted, opportunity: .visual, source: .user, usesDuration: false),
    .mergedVisualSegmentDoneEarly: RecordedEffectSpec(event: .userDeclaredCompleted, opportunity: .visual, source: .user, usesDuration: false),
    .visualSkip: RecordedEffectSpec(event: .skipped, opportunity: .visual, source: .user, usesDuration: false),
    .visualEscape: RecordedEffectSpec(event: .skipped, opportunity: .visual, source: .user, usesDuration: false),
    .movementTimerFinished: RecordedEffectSpec(event: .timerFinished, opportunity: .movement, source: .localTimer, usesDuration: true),
    .mergedMovementTimerFinished: RecordedEffectSpec(event: .timerFinished, opportunity: .movement, source: .localTimer, usesDuration: true),
    .movementDoneEarly: RecordedEffectSpec(event: .userDeclaredCompleted, opportunity: .movement, source: .user, usesDuration: true),
    .mergedMovementDoneEarly: RecordedEffectSpec(event: .userDeclaredCompleted, opportunity: .movement, source: .user, usesDuration: true),
    .movementAlreadyMoved: RecordedEffectSpec(event: .userDeclaredAlreadyMoved, opportunity: .movement, source: .user, usesDuration: false),
    .mergedMovementAlreadyMoved: RecordedEffectSpec(event: .userDeclaredAlreadyMoved, opportunity: .movement, source: .user, usesDuration: false),
    .movementPositionChangedOffered: RecordedEffectSpec(event: .positionChanged, opportunity: .movement, source: .user, usesDuration: false),
    .movementPositionChangedRunning: RecordedEffectSpec(event: .positionChanged, opportunity: .movement, source: .user, usesDuration: false),
    .mergedMovementPositionChanged: RecordedEffectSpec(event: .positionChanged, opportunity: .movement, source: .user, usesDuration: false),
    .movementSkipOffered: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .movementSkipRunning: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .movementEscapeOffered: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .movementEscapeRunning: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .mergedMovementSkip: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .mergedEscapeDuringMovement: RecordedEffectSpec(event: .skipped, opportunity: .movement, source: .user, usesDuration: false),
    .positionChanged: RecordedEffectSpec(event: .positionChanged, opportunity: .positionChange, source: .user, usesDuration: false),
    .positionSkip: RecordedEffectSpec(event: .skipped, opportunity: .positionChange, source: .user, usesDuration: false),
]

/// The 20 kinds that commit identity, rank, and fence with no fact and no
/// clock delta: offer openings, content changes, and operational plumbing.
private let factFreeKinds: Set<OpportunityActionKind> = [
    .nowOpenMovementOffer,
    .movementChangeContent,
    .mergedMovementChangeContent,
    .companionTakeWithMe,
    .pauseStart,
    .pauseResume,
    .holdBegin,
    .holdRelease,
    .holdCorrectionRelease,
    .workingHoursExit,
    .workingHoursEnter,
    .systemUnavailable,
    .systemAvailable,
    .systemAvailableAfterExtended,
    .systemShortInputIdle,
    .systemLongIdleBegan,
    .systemReturnedFromLongIdle,
    .systemSampleGap,
    .sensorStrongMovementRestart,
    .scheduleRestartUndo,
]

/// One intent conflict: the losers of one key reject against the successor
/// the winner commits. Opportunity intents share one key per opportunity;
/// pause and hold name their record; singleton global plumbing names itself.
struct OpportunityConflictKey: Hashable, Comparable, Sendable {
    let raw: String

    static func < (lhs: OpportunityConflictKey, rhs: OpportunityConflictKey) -> Bool {
        lhs.raw < rhs.raw
    }
}

private func conflictKey(for envelope: OpportunityActionEnvelope) -> OpportunityConflictKey {
    switch envelope.kind {
    case .pauseStart, .pauseResume:
        let record = envelope.payload.pauseRecordID?.uuidString.lowercased() ?? "missing"
        return OpportunityConflictKey(raw: "manual_pause:\(record)")
    case .holdBegin, .holdRelease, .holdCorrectionRelease:
        let decision = envelope.payload.holdDecisionID?.uuid.uuidString.lowercased() ?? "missing"
        return OpportunityConflictKey(raw: "hold_decision:\(decision)")
    default:
        if envelope.kind.isGlobalScope {
            return OpportunityConflictKey(raw: "global:\(envelope.kind.rawValue)")
        }
        let opportunity = envelope.lease?.scope.opportunityID?.uuid.uuidString.lowercased() ?? "missing"
        return OpportunityConflictKey(raw: "opportunity:\(opportunity)")
    }
}

extension LeaseScope {
    var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    var opportunityID: OpportunityID? {
        if case let .opportunity(id, _) = self { return id }
        return nil
    }

    /// The scope revision the lease was issued for. Validation requires it
    /// to match the envelope's origin revision: advancing the revision
    /// revokes predecessor leases.
    var scopeRevision: UInt64 {
        switch self {
        case let .opportunity(_, revision): return revision
        case let .global(_, revision): return revision
        }
    }
}
