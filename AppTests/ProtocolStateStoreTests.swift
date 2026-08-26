import Domain
import Foundation
import Testing
@testable import App

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

    @Test("Events and counters can be committed atomically through one App store")
    func atomicCommit() async throws {
        let store = try SwiftDataProtocolStore(inMemory: true)
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
