import Domain
import Foundation
import SwiftData
import Testing
@testable import App

private final class LegacyProtocolStoreFixture {}

@Suite("Restart-safe protocol state")
struct ProtocolStateStoreTests {
    @Test("Both independent counters round-trip into a safe restart grace")
    func roundTrip() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let state = ProtocolState(
            profileID: .frequentMovement,
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 1234,
                phase: .suppressed(.calendarBusy),
            ),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 4321,
                phase: .running,
            ),
        )

        try await store.saveState(state)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.profileID == .frequentMovement)
        #expect(loaded.visualClock.accumulatedActiveUseSeconds == 1234)
        #expect(loaded.movementClock.accumulatedActiveUseSeconds == 4321)
        #expect(loaded.visualClock.phase == .gracedAfterSuppression)
        #expect(loaded.movementClock.phase == .gracedAfterSuppression)
    }
}

@Suite("Restart-safe heads-up delivery state")
struct HeadsUpDeliveryStateStoreTests {
    @Test("Clock cycles and a presented heads-up delivery round-trip exactly")
    func headsUpDeliveryRoundTrip() async throws {
        let directory = try makeTemporaryStoreDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "protocol.store")
        let deliveryID = HeadsUpDeliveryID(
            rawValue: UUID(uuidString: "A1B2C3D4-E5F6-47A8-9012-3456789ABCDE")!,
        )
        let movementCycleID = UInt64.max
        let visualSnooze = Date(timeIntervalSince1970: 1_750_000_000)
        let state = ProtocolState(
            visualClock: OpportunityClockState(
                cycleID: 41,
                accumulatedActiveUseSeconds: 1234,
            ),
            movementClock: OpportunityClockState(
                cycleID: movementCycleID,
                accumulatedActiveUseSeconds: 4321,
            ),
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(
                    cycleID: 41,
                    presentationCount: 2,
                    snoozeDeadline: visualSnooze,
                ),
                movementClock: HeadsUpClockLedger(
                    cycleID: movementCycleID,
                    presentationCount: 1,
                ),
                activeDelivery: HeadsUpActiveDelivery(
                    id: deliveryID,
                    opportunity: .movement(cycleID: movementCycleID),
                    phase: .presented,
                    channel: .capsule,
                    promptFactStatus: .acknowledged,
                    countdownMark: .seconds5,
                    didLand: true,
                    targetAt: Date(timeIntervalSince1970: 1_750_000_030),
                ),
            ),
        )

        do {
            let container = try AppModelContainer.make(url: storeURL)
            let store = try SwiftDataProtocolStateStore(container: container)
            try await store.saveState(state)
        }

        let reopenedContainer = try AppModelContainer.make(url: storeURL)
        let reopenedStore = try SwiftDataProtocolStateStore(container: reopenedContainer)
        let loaded = try #require(try await reopenedStore.loadState())
        #expect(loaded.visualClock.cycleID == 41)
        #expect(loaded.movementClock.cycleID == movementCycleID)
        #expect(loaded.headsUpDeliveryState == state.headsUpDeliveryState)
    }

    @Test("A reserved heads-up delivery retains its stable identity and phase")
    func reservedHeadsUpDeliveryRoundTrip() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let delivery = HeadsUpActiveDelivery(
            id: HeadsUpDeliveryID(
                rawValue: UUID(uuidString: "12345678-90AB-4CDE-8F01-23456789ABCD")!,
            ),
            opportunity: .merged(visualCycleID: 8, movementCycleID: 9),
            countdownMark: .seconds45,
        )
        let state = ProtocolState(
            visualClock: OpportunityClockState(cycleID: 8),
            movementClock: OpportunityClockState(cycleID: 9),
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(cycleID: 8),
                movementClock: HeadsUpClockLedger(cycleID: 9),
                activeDelivery: delivery,
            ),
        )

        try await store.saveState(state)

        #expect(try await store.loadState()?.headsUpDeliveryState.activeDelivery == delivery)
    }

    @Test("Pending App action and exact reservation timing round-trip without a new identity")
    func pendingActionAndTimingRoundTrip() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let action = HeadsUpPendingAction(
            id: HeadsUpDeliveryID(
                rawValue: UUID(uuidString: "22345678-90AB-4CDE-8F01-23456789ABCD")!,
            ),
            kind: .openBreak,
            opportunity: .merged(visualCycleID: 8, movementCycleID: 9),
            source: .localTimer,
        )
        let state = ProtocolState(
            visualClock: OpportunityClockState(cycleID: 8),
            movementClock: OpportunityClockState(cycleID: 9),
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(cycleID: 8),
                movementClock: HeadsUpClockLedger(cycleID: 9),
                pendingAction: action,
            ),
        )

        try await store.saveState(state)

        #expect(try await store.loadState()?.headsUpDeliveryState.pendingAction == action)
    }

    @Test("Legacy delivery payloads decode with no pending action or exact target")
    func legacyDeliveryPayloadDefaultsNewFieldsToNil() throws {
        let state = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(cycleID: 2),
            activeDelivery: HeadsUpActiveDelivery(
                id: HeadsUpDeliveryID(rawValue: UUID()),
                opportunity: .visual(cycleID: 2),
                countdownMark: .seconds30,
                targetAt: Date(timeIntervalSince1970: 200),
            ),
        )
        let encoded = try HeadsUpDeliveryStateCodec.encode(state)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any],
        )
        var encodedState = try #require(object["state"] as? [String: Any])
        var active = try #require(encodedState["activeDelivery"] as? [String: Any])
        active.removeValue(forKey: "targetAt")
        encodedState["activeDelivery"] = active
        encodedState.removeValue(forKey: "pendingAction")
        object["state"] = encodedState
        let legacy = try JSONSerialization.data(withJSONObject: object)

        let decoded = try HeadsUpDeliveryStateCodec.decode(legacy)

        #expect(decoded.activeDelivery?.targetAt == nil)
        #expect(decoded.pendingAction == nil)
    }

    @Test("Codec rejects simultaneous delivery and action or mismatched pending cycles")
    func invalidPendingActionsAreRejected() {
        let id = HeadsUpDeliveryID(rawValue: UUID())
        let pending = HeadsUpPendingAction(
            id: id,
            kind: .openMoreOptions,
            opportunity: .visual(cycleID: 3),
            source: .user,
        )
        let simultaneous = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(cycleID: 3),
            activeDelivery: HeadsUpActiveDelivery(
                id: id,
                opportunity: .visual(cycleID: 3),
                countdownMark: .seconds30,
            ),
            pendingAction: pending,
        )
        let mismatched = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(cycleID: 4),
            pendingAction: pending,
        )
        let snoozed = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(
                cycleID: 3,
                presentationCount: 1,
                snoozeDeadline: Date(timeIntervalSince1970: 500),
            ),
            pendingAction: HeadsUpPendingAction(
                id: id,
                kind: .openBreak,
                opportunity: .visual(cycleID: 3),
                source: .localTimer,
            ),
        )
        let userActionWithoutPresentation = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(cycleID: 3),
            pendingAction: HeadsUpPendingAction(
                id: id,
                kind: .openBreak,
                opportunity: .visual(cycleID: 3),
                source: .user,
            ),
        )
        let snoozeWithoutPresentation = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(
                cycleID: 3,
                snoozeDeadline: Date(timeIntervalSince1970: 500),
            ),
        )

        for invalid in [
            simultaneous,
            mismatched,
            snoozed,
            userActionWithoutPresentation,
            snoozeWithoutPresentation,
        ] {
            #expect(throws: ProtocolPersistenceError.invalidHeadsUpDeliveryState) {
                _ = try HeadsUpDeliveryStateCodec.encode(invalid)
            }
        }
    }

    @Test("Saving a replacement state clears a stale active heads-up delivery")
    func replacementClearsActiveHeadsUpDelivery() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let activeState = ProtocolState(
            visualClock: OpportunityClockState(cycleID: 3),
            headsUpDeliveryState: HeadsUpDeliveryState(
                visualClock: HeadsUpClockLedger(cycleID: 3),
                activeDelivery: HeadsUpActiveDelivery(
                    id: HeadsUpDeliveryID(rawValue: UUID()),
                    opportunity: .visual(cycleID: 3),
                    countdownMark: .seconds30,
                ),
            ),
        )
        try await store.saveState(activeState)

        let replacement = ProtocolState(
            visualClock: OpportunityClockState(cycleID: 4),
            movementClock: OpportunityClockState(cycleID: 5),
        )
        try await store.saveState(replacement)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.visualClock.cycleID == 4)
        #expect(loaded.movementClock.cycleID == 5)
        #expect(loaded.headsUpDeliveryState == HeadsUpDeliveryState())
    }

    @Test("Malformed and semantically corrupt delivery payloads are rejected explicitly")
    func invalidHeadsUpDeliveryPayloads() async throws {
        let validPayload = try HeadsUpDeliveryStateCodec.encode(HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(cycleID: 1, presentationCount: 1),
        ))
        var corruptObject = try #require(
            JSONSerialization.jsonObject(with: validPayload) as? [String: Any],
        )
        var corruptState = try #require(corruptObject["state"] as? [String: Any])
        var corruptLedger = try #require(
            corruptState["visualClock"] as? [String: Any],
        )
        corruptLedger["presentationCount"] = -1
        corruptState["visualClock"] = corruptLedger
        corruptObject["state"] = corruptState
        let semanticallyCorruptPayload = try JSONSerialization.data(withJSONObject: corruptObject)

        for payload in [Data([0xFF]), semanticallyCorruptPayload] {
            let container = try AppModelContainer.make(inMemory: true)
            let context = ModelContext(container)
            context.insert(storedProtocolState(headsUpDeliveryStatePayload: payload))
            try context.save()
            let store = try SwiftDataProtocolStateStore(container: container)

            await #expect(throws: ProtocolPersistenceError.invalidHeadsUpDeliveryState) {
                _ = try await store.loadState()
            }
        }
    }

    @Test("A persisted presentation count cannot overflow on the next acknowledgement")
    func presentationCountOverflowIsRejected() async throws {
        let state = HeadsUpDeliveryState(
            visualClock: HeadsUpClockLedger(
                cycleID: 1,
                presentationCount: .max,
            ),
            activeDelivery: HeadsUpActiveDelivery(
                id: HeadsUpDeliveryID(rawValue: UUID()),
                opportunity: .visual(cycleID: 1),
                countdownMark: .seconds30,
            ),
        )

        #expect(throws: ProtocolPersistenceError.invalidHeadsUpDeliveryState) {
            _ = try HeadsUpDeliveryStateCodec.encode(
                state,
                visualCycleID: 1,
                movementCycleID: 0,
            )
        }
    }

    @Test("Unsupported delivery payload versions are rejected explicitly")
    func unsupportedHeadsUpDeliveryPayloadVersion() async throws {
        let validPayload = try HeadsUpDeliveryStateCodec.encode(HeadsUpDeliveryState())
        var object = try #require(
            JSONSerialization.jsonObject(with: validPayload) as? [String: Any],
        )
        object["schemaVersion"] = 2
        let payload = try JSONSerialization.data(withJSONObject: object)
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(storedProtocolState(headsUpDeliveryStatePayload: payload))
        try context.save()
        let store = try SwiftDataProtocolStateStore(container: container)

        await #expect(
            throws: ProtocolPersistenceError.unsupportedHeadsUpDeliverySchemaVersion(2),
        ) {
            _ = try await store.loadState()
        }
    }

    @Test("An unknown delivery schema is identified before its state is decoded")
    func incompatibleFutureHeadsUpDeliveryPayloadVersion() throws {
        let payload = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 2,
            "state": ["futureShape": true],
        ])

        #expect(
            throws: ProtocolPersistenceError.unsupportedHeadsUpDeliverySchemaVersion(2),
        ) {
            _ = try HeadsUpDeliveryStateCodec.decode(payload)
        }
    }

    @Test(
        "Saving rejects heads-up cycles that disagree with the outer clocks",
        arguments: HeadsUpCycleMismatch.allCases,
    )
    func saveRejectsHeadsUpCycleMismatch(_ mismatch: HeadsUpCycleMismatch) async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)

        await #expect(throws: ProtocolPersistenceError.invalidHeadsUpDeliveryState) {
            try await store.saveState(mismatch.protocolState)
        }
        #expect(try await store.loadState() == nil)
    }

    @Test(
        "Loading rejects heads-up cycles that disagree with the stored outer clocks",
        arguments: HeadsUpCycleMismatch.allCases,
    )
    func loadRejectsHeadsUpCycleMismatch(_ mismatch: HeadsUpCycleMismatch) async throws {
        let state = mismatch.protocolState
        let payload = try HeadsUpDeliveryStateCodec.encode(state.headsUpDeliveryState)
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(storedProtocolState(
            headsUpDeliveryStatePayload: payload,
            visualCycleID: state.visualClock.cycleID,
            movementCycleID: state.movementClock.cycleID,
        ))
        try context.save()
        let store = try SwiftDataProtocolStateStore(container: container)

        await #expect(throws: ProtocolPersistenceError.invalidHeadsUpDeliveryState) {
            _ = try await store.loadState()
        }
    }

    private func storedProtocolState(
        headsUpDeliveryStatePayload: Data,
        visualCycleID: UInt64? = nil,
        movementCycleID: UInt64? = nil,
    ) -> StoredProtocolState {
        StoredProtocolState(
            key: "current",
            schemaVersion: 1,
            profileID: ProtocolProfileID.balanced.rawValue,
            visualAccumulatedActiveUseSeconds: 0,
            movementAccumulatedActiveUseSeconds: 0,
            visualSnoozeDeadline: nil,
            movementSnoozeDeadline: nil,
            recoveryActiveUseSeconds: 0,
            recoveryMovementDeferralCount: 0,
            recoveryWasOfferedThisSession: false,
            recoveryLastObservedAt: nil,
            visualCycleIDStorage: visualCycleID.map(Int64.init(bitPattern:)),
            movementCycleIDStorage: movementCycleID.map(Int64.init(bitPattern:)),
            headsUpDeliveryStatePayload: headsUpDeliveryStatePayload,
        )
    }

    private func makeTemporaryStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "protocol-state-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

extension ProtocolStateStoreTests {
    @Test("A restored engine establishes a new baseline instead of adding offline time")
    func noOfflineCatchUp() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let saved = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 100),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 200),
        )
        try await store.saveState(saved)

        let restored = try #require(try await store.loadState())
        var engine = try ProtocolEngine(configuration: testConfiguration(), state: restored)
        _ = engine.observe(.active(uptimeSeconds: 50000, secondsSinceInput: 0))

        #expect(engine.state.visualClock.accumulatedActiveUseSeconds == 100)
        #expect(engine.state.movementClock.accumulatedActiveUseSeconds == 200)

        _ = engine.observe(.active(uptimeSeconds: 50010, secondsSinceInput: 0))
        #expect(engine.state.visualClock.accumulatedActiveUseSeconds == 110)
        #expect(engine.state.movementClock.accumulatedActiveUseSeconds == 210)
    }

    @Test("Snooze deadlines and recovery debt round-trip without becoming elapsed use")
    func lifecycleStateRoundTrip() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let deadline = Date(timeIntervalSince1970: 1300)
        let recoveryAnchor = Date(timeIntervalSince1970: 900)
        let state = ProtocolState(
            profileID: .balanced,
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 1500),
            movementClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 3600,
                phase: .snoozed,
            ),
            movementSnoozeDeadline: deadline,
            recoveryState: RecoveryState(
                accumulatedEligibleActiveUseSeconds: 5400,
                movementDeferralCount: 2,
                wasOfferedThisSession: true,
            ),
            recoveryLastObservedAt: recoveryAnchor,
        )

        try await store.saveState(state)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.movementClock.phase == .snoozed)
        #expect(loaded.movementSnoozeDeadline == deadline)
        #expect(loaded.recoveryState == state.recoveryState)
        #expect(loaded.recoveryLastObservedAt == recoveryAnchor)
    }

    @Test("Session-scoped not-appropriate choices round-trip independently")
    func notAppropriateOpportunitiesRoundTrip() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        let state = ProtocolState(
            notAppropriateOpportunities: [.visual, .movement],
        )

        try await store.saveState(state)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.notAppropriateOpportunities == [.visual, .movement])

        try await store.saveState(ProtocolState(
            notAppropriateOpportunities: [.movement],
        ))
        #expect(try await store.loadState()?.notAppropriateOpportunities == [.movement])
    }

    @Test("Rows without additive suppression flags restore as no session suppression")
    func absentNotAppropriateFlagsDefaultToEmpty() async throws {
        let container = try AppModelContainer.make(inMemory: true)
        let context = ModelContext(container)
        context.insert(StoredProtocolState(
            key: "current",
            schemaVersion: 1,
            profileID: ProtocolProfileID.balanced.rawValue,
            visualAccumulatedActiveUseSeconds: 0,
            movementAccumulatedActiveUseSeconds: 0,
            visualSnoozeDeadline: nil,
            movementSnoozeDeadline: nil,
            recoveryActiveUseSeconds: 0,
            recoveryMovementDeferralCount: 0,
            recoveryWasOfferedThisSession: false,
            recoveryLastObservedAt: nil,
        ))
        try context.save()

        let store = try SwiftDataProtocolStateStore(container: container)
        let loaded = try #require(try await store.loadState())
        #expect(loaded.notAppropriateOpportunities.isEmpty)
        #expect(loaded.visualClock.cycleID == 0)
        #expect(loaded.movementClock.cycleID == 0)
        #expect(loaded.headsUpDeliveryState == HeadsUpDeliveryState())
    }

    @Test("The exact additive schema opens and preserves a pre-heads-up SQLite store")
    func additiveHeadsUpFieldsMigrateLegacySQLiteStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "protocol-legacy-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "protocol.store")
        let visualSnooze = Date(timeIntervalSince1970: 1_750_000_000)
        let recoveryAnchor = Date(timeIntervalSince1970: 1_750_000_100)

        try seedLegacyProtocolStore(at: storeURL)

        let migratedContainer = try AppModelContainer.make(url: storeURL)
        let store = try SwiftDataProtocolStateStore(container: migratedContainer)
        let loaded = try #require(try await store.loadState())
        #expect(loaded.profileID == .frequentMovement)
        #expect(loaded.visualClock.cycleID == 0)
        #expect(loaded.visualClock.accumulatedActiveUseSeconds == 111)
        #expect(loaded.movementClock.cycleID == 0)
        #expect(loaded.movementClock.accumulatedActiveUseSeconds == 222)
        #expect(loaded.visualSnoozeDeadline == visualSnooze)
        #expect(loaded.recoveryState == RecoveryState(
            accumulatedEligibleActiveUseSeconds: 333,
            movementDeferralCount: 2,
            wasOfferedThisSession: true,
        ))
        #expect(loaded.recoveryLastObservedAt == recoveryAnchor)
        #expect(loaded.notAppropriateOpportunities == [.visual])
        #expect(loaded.headsUpDeliveryState == HeadsUpDeliveryState())
    }

    func seedLegacyProtocolStore(at storeURL: URL) throws {
        let fixtureURL = try #require(Bundle(for: LegacyProtocolStoreFixture.self).url(
            forResource: "LegacyProtocolStore",
            withExtension: "store",
        ))
        try FileManager.default.copyItem(at: fixtureURL, to: storeURL)
    }

    @Test("Completing a snoozed visual opportunity cannot resurrect snooze after restart")
    func completedVisualClearsSnoozeDeadline() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        var engine = try ProtocolEngine(
            configuration: testConfiguration(),
            visualClock: OpportunityClockState(
                accumulatedActiveUseSeconds: 2000,
                phase: .readyToPresent,
            ),
        )
        _ = engine.snooze(
            .visual,
            durationSeconds: 300,
            at: Date(timeIntervalSince1970: 1000),
        )
        _ = engine.record(.userDeclaredCompleted, opportunity: .visual)

        try await store.saveState(engine.state)

        let restored = try #require(try await store.loadState())
        #expect(restored.visualSnoozeDeadline == nil)
        #expect(restored.visualClock == OpportunityClockState(
            cycleID: 1,
            accumulatedActiveUseSeconds: 0,
            phase: .gracedAfterSuppression,
        ))
    }

    @Test("Events and counters can be committed atomically through one App store")
    func atomicCommit() async throws {
        let store = try SwiftDataProtocolStore(
            inMemory: true,
            now: { Date(timeIntervalSince1970: 300) },
        )
        let state = ProtocolState(
            visualClock: OpportunityClockState(accumulatedActiveUseSeconds: 10),
            movementClock: OpportunityClockState(accumulatedActiveUseSeconds: 20),
        )
        let event = OpportunityEvent(
            id: UUID(),
            kind: .timerFinished,
            recordedAt: Date(timeIntervalSince1970: 300),
            source: .localTimer,
            opportunity: .visual,
        )
        let secondEvent = OpportunityEvent(
            id: UUID(),
            kind: .positionChanged,
            recordedAt: Date(timeIntervalSince1970: 299),
            source: .user,
            opportunity: .positionChange,
        )

        try await store.commit(events: [event, secondEvent], state: state)

        #expect(try await store.loadEvents() == [event, secondEvent])
        let loaded = try #require(try await store.loadState())
        #expect(loaded.visualClock.accumulatedActiveUseSeconds == 10)
        #expect(loaded.movementClock.accumulatedActiveUseSeconds == 20)
    }

    @Test("Deleting state returns the store to an uninitialized session")
    func deleteState() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)
        try await store.saveState(ProtocolState())
        try await store.deleteState()

        #expect(try await store.loadState() == nil)
    }

    @Test("Unsupported custom configuration and invalid counters are rejected")
    func invalidState() async throws {
        let store = try SwiftDataProtocolStateStore(inMemory: true)

        do {
            try await store.saveState(ProtocolState(profileID: .custom))
            Issue.record("Expected custom state without durable configuration to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .invalidProfileID("custom"))
        }

        do {
            try await store.saveState(ProtocolState(
                movementClock: OpportunityClockState(accumulatedActiveUseSeconds: .infinity),
            ))
            Issue.record("Expected an infinite counter to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .invalidCounter)
        }
    }

    private func testConfiguration() throws -> ProtocolConfiguration {
        try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 1000,
                targetSeconds: 2000,
                latestPreferredSeconds: 3000,
                durationOptionsSeconds: [20],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 4000,
                targetSeconds: 5000,
                latestPreferredSeconds: 6000,
                durationOptionsSeconds: [300, 120],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: true,
                mergeWindowSeconds: 300,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 45,
                snoozeOptionsSeconds: [300, 600, 900],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
    }
}

enum HeadsUpCycleMismatch: CaseIterable, Sendable {
    case visual
    case movement
    case merged

    var protocolState: ProtocolState {
        let outerVisualCycleID: UInt64 = 10
        let outerMovementCycleID: UInt64 = 20
        return switch self {
        case .visual:
            ProtocolState(
                visualClock: OpportunityClockState(cycleID: outerVisualCycleID),
                movementClock: OpportunityClockState(cycleID: outerMovementCycleID),
                headsUpDeliveryState: HeadsUpDeliveryState(
                    visualClock: HeadsUpClockLedger(cycleID: outerVisualCycleID + 1),
                    activeDelivery: HeadsUpActiveDelivery(
                        id: HeadsUpDeliveryID(rawValue: UUID()),
                        opportunity: .visual(cycleID: outerVisualCycleID + 1),
                        countdownMark: .seconds30,
                    ),
                ),
            )
        case .movement:
            ProtocolState(
                visualClock: OpportunityClockState(cycleID: outerVisualCycleID),
                movementClock: OpportunityClockState(cycleID: outerMovementCycleID),
                headsUpDeliveryState: HeadsUpDeliveryState(
                    movementClock: HeadsUpClockLedger(cycleID: outerMovementCycleID + 1),
                    activeDelivery: HeadsUpActiveDelivery(
                        id: HeadsUpDeliveryID(rawValue: UUID()),
                        opportunity: .movement(cycleID: outerMovementCycleID + 1),
                        countdownMark: .seconds30,
                    ),
                ),
            )
        case .merged:
            ProtocolState(
                visualClock: OpportunityClockState(cycleID: outerVisualCycleID),
                movementClock: OpportunityClockState(cycleID: outerMovementCycleID),
                headsUpDeliveryState: HeadsUpDeliveryState(
                    visualClock: HeadsUpClockLedger(cycleID: outerVisualCycleID + 1),
                    movementClock: HeadsUpClockLedger(cycleID: outerMovementCycleID + 1),
                    activeDelivery: HeadsUpActiveDelivery(
                        id: HeadsUpDeliveryID(rawValue: UUID()),
                        opportunity: .merged(
                            visualCycleID: outerVisualCycleID + 1,
                            movementCycleID: outerMovementCycleID + 1,
                        ),
                        countdownMark: .seconds30,
                    ),
                ),
            )
        }
    }
}
