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
}

final class SwiftDataProtocolStore: OpportunityEventStore, ProtocolStateStore {
    private static let schemaVersion = 1
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
        guard stored.schemaVersion == Self.schemaVersion else {
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
        if let stored = try fetchState() {
            update(stored, from: state, headsUpDeliveryStatePayload: headsUpDeliveryStatePayload)
        } else {
            insertState(state, headsUpDeliveryStatePayload: headsUpDeliveryStatePayload)
        }
    }

    private func update(
        _ stored: StoredProtocolState,
        from state: ProtocolState,
        headsUpDeliveryStatePayload: Data,
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
    }

    private func insertState(
        _ state: ProtocolState,
        headsUpDeliveryStatePayload: Data,
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
                phase: stored.visualSnoozeDeadline == nil ? .gracedAfterSuppression : .snoozed,
            ),
            movementClock: OpportunityClockState(
                cycleID: movementCycleID,
                accumulatedActiveUseSeconds: stored.movementAccumulatedActiveUseSeconds,
                phase: stored.movementSnoozeDeadline == nil ? .gracedAfterSuppression : .snoozed,
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
        )
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
        guard stored.schemaVersion == Self.schemaVersion else {
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
