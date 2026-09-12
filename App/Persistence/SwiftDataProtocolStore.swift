import Domain
import Foundation
import SwiftData

enum ProtocolPersistenceError: Error, Equatable {
    case conflictingEventID(UUID)
    case invalidSelectedDuration(TimeInterval)
    case invalidEventKind(String)
    case invalidEventSource(String)
    case invalidOpportunityType(String)
    case invalidProfileID(String)
    case invalidCounter
    case invalidRecoveryState
    case invalidSnoozeDeadline
    case invalidHeadsUpDeliveryState
    case unsupportedHeadsUpDeliverySchemaVersion(Int)
    case unsupportedSchemaVersion(Int)
    case unsupportedCoordinatorFenceVersion(Int)
    case invalidCoordinatorFenceState
    case illegalCoordinatorRollback
}

final class SwiftDataProtocolStore: OpportunityEventStore, ProtocolStateStore {
    private static let schemaVersion = 2
    private static let stateKey = "current"

    let container: ModelContainer
    let context: ModelContext
    let now: () -> Date
    let saveContext: () throws -> Void

    convenience init(
        inMemory: Bool = false,
        now: @escaping () -> Date = Date.init,
        save: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        try self.init(
            container: AppModelContainer.make(inMemory: inMemory),
            now: now,
            save: save,
        )
    }

    init(
        container: ModelContainer,
        now: @escaping () -> Date = Date.init,
        save: ((ModelContext) throws -> Void)? = nil,
    ) throws {
        self.container = container
        self.now = now
        let context = ModelContext(container)
        self.context = context
        saveContext = {
            if let save {
                try save(context)
            } else {
                try context.save()
            }
        }
    }

    func append(_ event: OpportunityEvent) async throws {
        do {
            if try storedRetentionPolicy() == .keepNothing { return }
            try insert(event)
            try pruneStoredHistoryIfConfigured()
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadEvents() async throws -> [OpportunityEvent] {
        do {
            try pruneStoredHistoryIfConfigured()
            try saveContext()
            let descriptor = FetchDescriptor<StoredOpportunityEvent>(
                sortBy: [SortDescriptor(\.appendSequence)],
            )
            return try context.fetch(descriptor).map(event(from:))
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteAllEvents() async throws {
        do {
            for event in try context.fetch(FetchDescriptor<StoredOpportunityEvent>()) {
                context.delete(event)
            }
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func appendEstimatedActiveUseRun(_ run: EstimatedActiveUseRun) async throws {
        do {
            if try storedRetentionPolicy() == .keepNothing { return }
            try insertOrMerge(run)
            try pruneStoredHistoryIfConfigured()
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadEstimatedActiveUseRuns() async throws -> [EstimatedActiveUseRun] {
        do {
            try pruneStoredHistoryIfConfigured()
            try saveContext()
            let descriptor = FetchDescriptor<StoredEstimatedActiveUseRun>(
                sortBy: [SortDescriptor(\.startedAt)],
            )
            return try context.fetch(descriptor).map {
                try EstimatedActiveUseRun(startedAt: $0.startedAt, endedAt: $0.endedAt)
            }
        } catch {
            context.rollback()
            throw error
        }
    }

    func loadState() async throws -> ProtocolState? {
        guard let stored = try fetchState() else { return nil }
        guard stored.schemaVersion == 1 || stored.schemaVersion == Self.schemaVersion else {
            throw ProtocolPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        guard let profileID = ProtocolProfileID(rawValue: stored.profileID)
        else {
            throw ProtocolPersistenceError.invalidProfileID(stored.profileID)
        }
        guard try isSupportedPersistedProfile(profileID) else {
            throw ProtocolPersistenceError.invalidProfileID(stored.profileID)
        }
        guard isValidCounter(stored.visualAccumulatedActiveUseSeconds),
              isValidCounter(stored.movementAccumulatedActiveUseSeconds)
        else {
            throw ProtocolPersistenceError.invalidCounter
        }
        guard isValidCounter(stored.recoveryActiveUseSeconds),
              stored.recoveryMovementDeferralCount >= 0
        else {
            throw ProtocolPersistenceError.invalidRecoveryState
        }
        guard isValidDeadline(stored.visualSnoozeDeadline),
              isValidDeadline(stored.movementSnoozeDeadline),
              isValidDeadline(stored.recoveryLastObservedAt)
        else {
            throw ProtocolPersistenceError.invalidSnoozeDeadline
        }
        return try protocolState(from: stored, profileID: profileID)
    }

    func saveState(_ state: ProtocolState) async throws {
        do {
            try upsert(state)
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func deleteState() async throws {
        do {
            guard let stored = try fetchState() else { return }
            context.delete(stored)
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
        try await commit(events: events, state: state, estimatedActiveUseRun: nil)
    }

    func commit(
        events: [OpportunityEvent],
        state: ProtocolState,
        estimatedActiveUseRun: EstimatedActiveUseRun?,
    ) async throws {
        do {
            if try storedRetentionPolicy() != .keepNothing {
                for event in events {
                    try insert(event)
                }
                if let estimatedActiveUseRun {
                    try insertOrMerge(estimatedActiveUseRun)
                }
            }
            try upsert(state)
            try pruneStoredHistoryIfConfigured()
            try saveContext()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func insert(_ event: OpportunityEvent) throws {
        try validate(event)
        if let existing = try fetchEvent(id: event.id) {
            guard try self.event(from: existing) == event else {
                throw ProtocolPersistenceError.conflictingEventID(event.id)
            }
            return
        }
        let nextSequence = try fetchLatestSequence().map { $0 + 1 } ?? 0
        context.insert(StoredOpportunityEvent(
            id: event.id,
            schemaVersion: Self.schemaVersion,
            appendSequence: nextSequence,
            kind: event.kind.rawValue,
            recordedAt: event.recordedAt,
            source: event.source.rawValue,
            opportunity: event.opportunity?.rawValue,
            selectedDurationSeconds: event.selectedDurationSeconds,
        ))
    }

    private func insertOrMerge(_ run: EstimatedActiveUseRun) throws {
        let descriptor = FetchDescriptor<StoredEstimatedActiveUseRun>(
            sortBy: [SortDescriptor(\.endedAt, order: .reverse)],
        )
        if let latest = try context.fetch(descriptor).first,
           run.startedAt <= latest.endedAt.addingTimeInterval(0.001)
        {
            latest.startedAt = min(latest.startedAt, run.startedAt)
            latest.endedAt = max(latest.endedAt, run.endedAt)
        } else {
            context.insert(StoredEstimatedActiveUseRun(
                startedAt: run.startedAt,
                endedAt: run.endedAt,
            ))
        }
    }

    func upsert(_ state: ProtocolState) throws {
        try validateStateProfileMatchesPreferences(state.profileID)
        guard try isSupportedPersistedProfile(state.profileID) else {
            throw ProtocolPersistenceError.invalidProfileID(state.profileID.rawValue)
        }
        let visual = state.visualClock.accumulatedActiveUseSeconds
        let movement = state.movementClock.accumulatedActiveUseSeconds
        let recovery = state.recoveryState.accumulatedEligibleActiveUseSeconds
        guard isValidCounter(visual), isValidCounter(movement) else {
            throw ProtocolPersistenceError.invalidCounter
        }
        guard isValidCounter(recovery), state.recoveryState.movementDeferralCount >= 0 else {
            throw ProtocolPersistenceError.invalidRecoveryState
        }
        guard isValidDeadline(state.visualSnoozeDeadline),
              isValidDeadline(state.movementSnoozeDeadline),
              isValidDeadline(state.recoveryLastObservedAt)
        else {
            throw ProtocolPersistenceError.invalidSnoozeDeadline
        }
        let headsUpDeliveryStatePayload = try HeadsUpDeliveryStateCodec.encode(
            state.headsUpDeliveryState,
            visualCycleID: state.visualClock.cycleID,
            movementCycleID: state.movementClock.cycleID,
        )
        let coordinatorFencePayload = try CoordinatorFenceStateCodec.encode(state.coordinatorFence)
        if let stored = try fetchState() {
            try refuseGenerationRollback(stored: stored, incoming: state.coordinatorFence)
            stored.schemaVersion = Self.schemaVersion
            update(
                stored,
                from: state,
                headsUpDeliveryStatePayload: headsUpDeliveryStatePayload,
                coordinatorFencePayload: coordinatorFencePayload,
            )
        } else {
            insertState(
                state,
                headsUpDeliveryStatePayload: headsUpDeliveryStatePayload,
                coordinatorFencePayload: coordinatorFencePayload,
            )
        }
    }

    /// Refuses a regressed causal generation: the generation only advances
    /// (`noteSessionRotation`), so persisting an older one means a stale
    /// writer or a rolled-back file. A same-generation write that drops
    /// retained committed actions is the same hazard: pre-2.6 snapshots
    /// carry an empty fence, and persisting one over a commit would wipe
    /// replay authority and let the next resubmission recommit. v1 rows
    /// carry no generation (implicit zero, never newer). A retained payload
    /// from a newer binary is authority this binary cannot read, so its
    /// version error is rethrown rather than overwritten; only a genuinely
    /// corrupt payload cannot anchor a comparison, and overwriting it with
    /// a good snapshot is recovery, not rollback. The throw precedes any
    /// mutation, leaving the stored row intact.
    private func refuseGenerationRollback(
        stored: StoredProtocolState,
        incoming: CoordinatorFenceState,
    ) throws {
        guard stored.schemaVersion != 1,
              let payload = stored.coordinatorFencePayload
        else {
            return
        }
        let retained: CoordinatorFenceState
        do {
            retained = try CoordinatorFenceStateCodec.decode(payload)
        } catch let error as ProtocolPersistenceError {
            if case .unsupportedCoordinatorFenceVersion = error { throw error }
            return
        } catch {
            return
        }
        guard incoming.generation >= retained.generation else {
            throw ProtocolPersistenceError.illegalCoordinatorRollback
        }
        let dropsRetainedCommits = !retained.committedActions.keys.allSatisfy {
            incoming.committedActions.keys.contains($0)
        }
        guard incoming.generation != retained.generation || !dropsRetainedCommits else {
            throw ProtocolPersistenceError.illegalCoordinatorRollback
        }
    }

    private func update(
        _ stored: StoredProtocolState,
        from state: ProtocolState,
        headsUpDeliveryStatePayload: Data,
        coordinatorFencePayload: Data,
    ) {
        stored.updateClocks(
            profileID: state.profileID.rawValue,
            visualCycleIDStorage: Int64(bitPattern: state.visualClock.cycleID),
            visualAccumulatedActiveUseSeconds: state.visualClock.accumulatedActiveUseSeconds,
            movementCycleIDStorage: Int64(bitPattern: state.movementClock.cycleID),
            movementAccumulatedActiveUseSeconds: state.movementClock.accumulatedActiveUseSeconds,
        )
        stored.updateSnoozes(
            visual: state.visualSnoozeDeadline,
            movement: state.movementSnoozeDeadline,
        )
        stored.updateRecovery(
            activeUseSeconds: state.recoveryState.accumulatedEligibleActiveUseSeconds,
            movementDeferralCount: state.recoveryState.movementDeferralCount,
            wasOfferedThisSession: state.recoveryState.wasOfferedThisSession,
            lastObservedAt: state.recoveryLastObservedAt,
        )
        stored.updateNotAppropriateOpportunities(
            visual: state.notAppropriateOpportunities.contains(.visual),
            movement: state.notAppropriateOpportunities.contains(.movement),
        )
        stored.updateHeadsUpDeliveryStatePayload(headsUpDeliveryStatePayload)
        stored.updateCoordinatorFencePayload(coordinatorFencePayload)
    }

    private func insertState(
        _ state: ProtocolState,
        headsUpDeliveryStatePayload: Data,
        coordinatorFencePayload: Data,
    ) {
        context.insert(StoredProtocolState(
            key: Self.stateKey,
            schemaVersion: Self.schemaVersion,
            profileID: state.profileID.rawValue,
            visualAccumulatedActiveUseSeconds: state.visualClock.accumulatedActiveUseSeconds,
            movementAccumulatedActiveUseSeconds: state.movementClock.accumulatedActiveUseSeconds,
            visualSnoozeDeadline: state.visualSnoozeDeadline,
            movementSnoozeDeadline: state.movementSnoozeDeadline,
            recoveryActiveUseSeconds: state.recoveryState.accumulatedEligibleActiveUseSeconds,
            recoveryMovementDeferralCount: state.recoveryState.movementDeferralCount,
            recoveryWasOfferedThisSession: state.recoveryState.wasOfferedThisSession,
            recoveryLastObservedAt: state.recoveryLastObservedAt,
            visualNotAppropriateThisSession: state.notAppropriateOpportunities.contains(.visual),
            movementNotAppropriateThisSession: state.notAppropriateOpportunities.contains(.movement),
            visualCycleIDStorage: Int64(bitPattern: state.visualClock.cycleID),
            movementCycleIDStorage: Int64(bitPattern: state.movementClock.cycleID),
            headsUpDeliveryStatePayload: headsUpDeliveryStatePayload,
            coordinatorFencePayload: coordinatorFencePayload,
        ))
    }
}

private extension SwiftDataProtocolStore {
    private func protocolState(
        from stored: StoredProtocolState,
        profileID: ProtocolProfileID,
    ) throws -> ProtocolState {
        let visualCycleID = stored.visualCycleIDStorage.map(UInt64.init(bitPattern:)) ?? 0
        let movementCycleID = stored.movementCycleIDStorage.map(UInt64.init(bitPattern:)) ?? 0
        return try ProtocolState(
            profileID: profileID,
            visualClock: OpportunityClockState(
                cycleID: visualCycleID,
                accumulatedActiveUseSeconds: stored.visualAccumulatedActiveUseSeconds,
                phase: stored.visualSnoozeDeadline == nil ? .accumulating : .snoozed,
            ),
            movementClock: OpportunityClockState(
                cycleID: movementCycleID,
                accumulatedActiveUseSeconds: stored.movementAccumulatedActiveUseSeconds,
                phase: stored.movementSnoozeDeadline == nil ? .accumulating : .snoozed,
            ),
            visualSnoozeDeadline: stored.visualSnoozeDeadline,
            movementSnoozeDeadline: stored.movementSnoozeDeadline,
            recoveryState: RecoveryState(
                accumulatedEligibleActiveUseSeconds: stored.recoveryActiveUseSeconds,
                movementDeferralCount: stored.recoveryMovementDeferralCount,
                wasOfferedThisSession: stored.recoveryWasOfferedThisSession,
            ),
            recoveryLastObservedAt: stored.recoveryLastObservedAt,
            notAppropriateOpportunities: notAppropriateOpportunities(from: stored),
            headsUpDeliveryState: HeadsUpDeliveryStateCodec.decode(
                stored.headsUpDeliveryStatePayload,
                visualCycleID: visualCycleID,
                movementCycleID: movementCycleID,
            ),
            coordinatorFence: coordinatorFence(from: stored),
        )
    }

    private func coordinatorFence(from stored: StoredProtocolState) throws -> CoordinatorFenceState {
        // v1 rows predate the fence column: they restore with an empty
        // fence and upgrade on the next save. A v2 row without a decodable
        // payload is tampered, never silently defaulted.
        guard stored.schemaVersion != 1 else { return CoordinatorFenceState() }
        guard let payload = stored.coordinatorFencePayload else {
            throw ProtocolPersistenceError.invalidCoordinatorFenceState
        }
        return try CoordinatorFenceStateCodec.decode(payload)
    }

    private func notAppropriateOpportunities(
        from stored: StoredProtocolState,
    ) -> Set<OpportunityType> {
        var opportunities: Set<OpportunityType> = []
        if stored.visualNotAppropriateThisSession == true {
            opportunities.insert(.visual)
        }
        if stored.movementNotAppropriateThisSession == true {
            opportunities.insert(.movement)
        }
        return opportunities
    }

    private func event(from stored: StoredOpportunityEvent) throws -> OpportunityEvent {
        // The event schema is unchanged in v2 (additive-only: the fence
        // column lives on the state row), so v1 event rows decode as-is.
        guard stored.schemaVersion == 1 || stored.schemaVersion == Self.schemaVersion else {
            throw ProtocolPersistenceError.unsupportedSchemaVersion(stored.schemaVersion)
        }
        guard let kind = OpportunityEventKind(rawValue: stored.kind) else {
            throw ProtocolPersistenceError.invalidEventKind(stored.kind)
        }
        guard let source = OpportunityEventSource(rawValue: stored.source) else {
            throw ProtocolPersistenceError.invalidEventSource(stored.source)
        }
        let opportunity: OpportunityType?
        if let storedOpportunity = stored.opportunity {
            guard let decoded = OpportunityType(rawValue: storedOpportunity) else {
                throw ProtocolPersistenceError.invalidOpportunityType(storedOpportunity)
            }
            opportunity = decoded
        } else {
            opportunity = nil
        }

        return OpportunityEvent(
            id: stored.id,
            kind: kind,
            recordedAt: stored.recordedAt,
            source: source,
            opportunity: opportunity,
            selectedDurationSeconds: stored.selectedDurationSeconds,
        )
    }

    private func validate(_ event: OpportunityEvent) throws {
        guard let duration = event.selectedDurationSeconds else { return }
        guard duration.isFinite, duration >= 0 else {
            throw ProtocolPersistenceError.invalidSelectedDuration(duration)
        }
    }

    private func fetchEvent(id: UUID) throws -> StoredOpportunityEvent? {
        let descriptor = FetchDescriptor<StoredOpportunityEvent>(
            predicate: #Predicate { $0.id == id },
        )
        return try context.fetch(descriptor).first
    }

    private func fetchLatestSequence() throws -> Int64? {
        let descriptor = FetchDescriptor<StoredOpportunityEvent>(
            sortBy: [SortDescriptor(\.appendSequence, order: .reverse)],
        )
        return try context.fetch(descriptor).first?.appendSequence
    }

    private func fetchState() throws -> StoredProtocolState? {
        let key = Self.stateKey
        let descriptor = FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )
        return try context.fetch(descriptor).first
    }
}

private extension SwiftDataProtocolStore {
    private func isValidCounter(_ value: TimeInterval) -> Bool {
        value.isFinite && value >= 0
    }

    private func isValidDeadline(_ value: Date?) -> Bool {
        value?.timeIntervalSinceReferenceDate.isFinite ?? true
    }
}

typealias SwiftDataOpportunityEventStore = SwiftDataProtocolStore
typealias SwiftDataProtocolStateStore = SwiftDataProtocolStore
