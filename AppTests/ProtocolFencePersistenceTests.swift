import Domain
import Foundation
import SwiftData
import Testing
@testable import App

/// Story 2.5 RED: versioned persistence fixtures + migration for the
/// coordinator fence/dedup state.
///
/// Fresh vs migrated vs legacy-tampered stores, state/restore round-trips,
/// fence/generation/lease/epoch/receipt-map persistence (R1: a committed
/// ActionID resubmitted post-restore yields `duplicateReplay`), crash-replay
/// skew, illegal-clock rollback refusal, owner-named App authorship
/// fixtures, no-presenter-reads-legacy-key isolation, and the R2
/// relaunch-starts-clean courtesy pin through the persistence boundary.
///
/// Every test fails until the v2 schema, `CoordinatorFenceStateCodec`, and
/// the `ProtocolStateStore` migration land. Schema evolution is
/// additive-only; the v1 preset registry is untouched.
@Suite("Coordinator fence persistence and migration")
struct ProtocolFencePersistenceTests {
    @Test("A fresh store restores no state")
    func freshStoreLoadsNil() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        #expect(try await store.loadState() == nil)
    }

    @Test("A migrated v1 store restores counters with an empty fence, then upgrades on save")
    func migratedV1StoreLoadsWithEmptyFence() async throws {
        let (directory, storeURL) = try ProtocolFenceStoreFixture.makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ProtocolFenceStoreFixture.makeMigrated(at: storeURL)

        let loaded = try #require(try await store.loadState())
        #expect(loaded.profileID == .frequentMovement)
        #expect(loaded.coordinatorFence == CoordinatorFenceState())

        var reducer = OpportunityActionReducer()
        var engine = try fenceFixtureEngine()
        let envelope = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000011",
            counter: 1,
        )
        #expect(reducer.reduce(envelope, on: &engine, atTicks: 1000).outcome == .committed)
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        let key = "current"
        let stored = try #require(try ModelContext(store.container).fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)
        #expect(stored.schemaVersion == 2)
        #expect(stored.coordinatorFencePayload != nil)

        let reloaded = try #require(try await store.loadState())
        #expect(reloaded.coordinatorFence == reducer.fenceState)
    }

    @Test("A legacy-tampered future row version is refused explicitly")
    func tamperedSchemaVersionRefused() async throws {
        let (directory, storeURL) = try ProtocolFenceStoreFixture.makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ProtocolFenceStoreFixture.makeTamperedVersion(at: storeURL, version: 999)

        do {
            _ = try await store.loadState()
            Issue.record("Expected an unsupported future schema version to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .unsupportedSchemaVersion(999))
        }
    }

    @Test("A v2 row with a corrupt or missing fence payload is refused, never defaulted")
    func corruptFencePayloadRefused() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        try await store.saveState(ProtocolState())
        let key = "current"
        let stored = try #require(try store.context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)

        stored.coordinatorFencePayload = Data("not-a-fence-payload".utf8)
        try store.context.save()
        do {
            _ = try await store.loadState()
            Issue.record("Expected a corrupt fence payload to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .invalidCoordinatorFenceState)
        }

        stored.coordinatorFencePayload = nil
        try store.context.save()
        do {
            _ = try await store.loadState()
            Issue.record("Expected a missing v2 fence payload to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .invalidCoordinatorFenceState)
        }
    }

    @Test("Fence state round-trips generation, revisions, epochs, receipts, and sessions")
    func fenceRoundTrip() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var reducer = OpportunityActionReducer()
        var engine = try fenceFixtureEngine()

        let first = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000021",
            counter: 1,
        )
        #expect(reducer.reduce(first, on: &engine, atTicks: 1000).outcome == .committed)
        let second = try fenceFixtureEnvelope(
            .mergedAccept,
            scope: .merged(
                visualCycle: ClockCycleID(scope: .visual, rawValue: 0),
                movementCycle: ClockCycleID(scope: .movement, rawValue: 0),
            ),
            actionUUID: "20000000-0000-0000-0000-000000000022",
            counter: 2,
            revision: 1,
        )
        #expect(reducer.reduce(second, on: &engine, atTicks: 1000).outcome == .committed)
        reducer.noteSessionRotation()

        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))
        let loaded = try #require(try await store.loadState())
        // The store persists cycle identity and accrual; the phase is
        // re-derived on load (accumulating without a snooze deadline), so
        // only the persisted subset round-trips exactly.
        #expect(loaded.visualClock.cycleID == engine.visualClock.cycleID)
        #expect(loaded.visualClock.accumulatedActiveUseSeconds == engine.visualClock.accumulatedActiveUseSeconds)
        #expect(loaded.visualClock.phase == .accumulating)
        #expect(loaded.movementClock.cycleID == engine.movementClock.cycleID)
        #expect(loaded.movementClock.accumulatedActiveUseSeconds == engine.movementClock.accumulatedActiveUseSeconds)
        #expect(loaded.coordinatorFence == reducer.fenceState)
        #expect(loaded.coordinatorFence.generation == CoordinatorGeneration(1))
        #expect(loaded.coordinatorFence.mergedSessions[fenceFixtureOpportunity]?.revision == 2)
        let restoredAction = try #require(loaded.coordinatorFence.committedActions.keys.first {
            $0.deviceID == fenceFixtureOwnerDevice
        })
        #expect(restoredAction.counter == 1 || restoredAction.counter == 2)
    }

    @Test("A committed ActionID resubmitted after a file-backed restart replays exactly once")
    func postRestoreDuplicateReplays() async throws {
        let (directory, storeURL) = try ProtocolFenceStoreFixture.makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let envelope = try fenceFixtureEnvelope(
            .nowAcceptMovement,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000031",
            counter: 7,
            payload: OpportunityActionPayload(selectedDurationSeconds: 300),
        )
        let committedFacts: [OpportunityEventDraft]
        do {
            let container = try AppModelContainer.make(url: storeURL)
            let store = try SwiftDataProtocolStore(container: container)
            var reducer = OpportunityActionReducer()
            var engine = try fenceFixtureEngine()
            let receipt = reducer.reduce(envelope, on: &engine, atTicks: 1000)
            #expect(receipt.outcome == .committed)
            committedFacts = receipt.facts
            #expect(committedFacts.map(\.kind) == [.breakStarted])
            try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))
        }

        let reopenedContainer = try AppModelContainer.make(url: storeURL)
        let reopened = try SwiftDataProtocolStore(container: reopenedContainer)
        let restored = try #require(try await reopened.loadState())
        var engine = try ProtocolEngine(
            configuration: fenceFixtureConfiguration(),
            state: restored,
        )
        var reducer = OpportunityActionReducer(fenceState: restored.coordinatorFence)
        let clocksBefore = engine.state

        // Fresh-boot ticks long past the pre-crash lease expiry: dedup still
        // precedes lease validation, so the resend replays without a second
        // commit on the new monotonic epoch.
        let replay = reducer.reduce(envelope, on: &engine, atTicks: 60000)
        #expect(replay.outcome == .duplicateReplay)
        #expect(replay.facts == committedFacts)
        #expect(reducer.opportunityRevisions[fenceFixtureOpportunity] == 1)
        #expect(engine.visualClock == clocksBefore.visualClock)
        #expect(engine.movementClock == clocksBefore.movementClock)
    }

    @Test("Restore keeps fenced epochs fenced while unfenced epochs stay committable")
    func fencedVersusUnfencedRestore() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var reducer = OpportunityActionReducer()
        var engine = try fenceFixtureEngine()
        let terminal = try fenceFixtureEnvelope(
            .visualSkip,
            scope: .visual(cycle: ClockCycleID(scope: .visual, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000041",
            counter: 11,
        )
        #expect(reducer.reduce(terminal, on: &engine, atTicks: 1000).outcome == .committed)
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        let restored = try #require(try await store.loadState())
        var restoredReducer = OpportunityActionReducer(fenceState: restored.coordinatorFence)
        var restoredEngine = try ProtocolEngine(
            configuration: fenceFixtureConfiguration(),
            state: restored,
        )
        let stale = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000042",
            counter: 12,
        )
        #expect(restoredReducer.reduce(stale, on: &restoredEngine, atTicks: 1000).outcome == .rejectedFencedEpoch)

        restoredReducer.projectionEpochs[fenceFixtureOpportunity] = fenceFixtureSuccessorEpoch
        let successor = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000043",
            counter: 13,
            projectionEpoch: fenceFixtureSuccessorEpoch,
            revision: 1,
        )
        #expect(restoredReducer.reduce(successor, on: &restoredEngine, atTicks: 1000).outcome == .committed)
    }

    @Test("Crash-replay skew in ticks and wall time never causes a second commit or catch-up")
    func crashReplaySkew() async throws {
        let savedAt = Date(timeIntervalSince1970: 1_750_000_000)
        let store = try ProtocolFenceStoreFixture.makeFresh(now: { savedAt })
        var reducer = OpportunityActionReducer()
        var engine = try fenceFixtureEngine()
        let envelope = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000051",
            counter: 4,
        )
        let original = reducer.reduce(envelope, on: &engine, atTicks: 1000)
        #expect(original.outcome == .committed)
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        // Wall clock skews a month forward, then a month back: counters do
        // not catch up and the fence decodes identically (the fence carries
        // no wall-time anchor by design).
        let skewedStore = try SwiftDataProtocolStore(
            container: store.container,
            now: { savedAt.addingTimeInterval(30 * 86400) },
        )
        let skewed = try #require(try await skewedStore.loadState())
        #expect(skewed.visualClock.accumulatedActiveUseSeconds == 1500)
        #expect(skewed.coordinatorFence == reducer.fenceState)

        let backdatedStore = try SwiftDataProtocolStore(
            container: store.container,
            now: { savedAt.addingTimeInterval(-30 * 86400) },
        )
        let backdated = try #require(try await backdatedStore.loadState())
        #expect(backdated.coordinatorFence == reducer.fenceState)

        // Ticks skew both directions on the restored reducer: duplicates
        // replay; the frontier never advances twice.
        var restored = OpportunityActionReducer(fenceState: skewed.coordinatorFence)
        #expect(restored.reduce(envelope, on: &engine, atTicks: 60000).outcome == .duplicateReplay)
        var restoredEarly = OpportunityActionReducer(fenceState: skewed.coordinatorFence)
        #expect(restoredEarly.reduce(envelope, on: &engine, atTicks: 0).outcome == .duplicateReplay)
        #expect(restored.opportunityRevisions[fenceFixtureOpportunity] == 1)
    }

    @Test("A regressed causal generation is refused and the stored fence is preserved")
    func illegalGenerationRollbackRefused() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var engine = try fenceFixtureEngine()
        var advanced = OpportunityActionReducer()
        advanced.noteSessionRotation()
        advanced.noteSessionRotation()
        try await store.saveState(fenceFixtureState(engine: engine, fence: advanced.fenceState))

        var regressed = OpportunityActionReducer()
        regressed.noteSessionRotation()
        do {
            try await store.saveState(fenceFixtureState(engine: engine, fence: regressed.fenceState))
            Issue.record("Expected a regressed generation save to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .illegalCoordinatorRollback)
        }
        #expect(try await store.loadState()?.coordinatorFence.generation == CoordinatorGeneration(2))
    }

    @Test("Distinct owner devices coexist in one receipt map with exact authorship")
    func ownerAuthorshipSurvivesRestore() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var reducer = OpportunityActionReducer()
        var engine = try fenceFixtureEngine()
        let first = try fenceFixtureEnvelope(
            .nowOpenMovementOffer,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000061",
            counter: 1,
            device: fenceFixtureOwnerDevice,
        )
        #expect(reducer.reduce(first, on: &engine, atTicks: 1000).outcome == .committed)
        let second = try fenceFixtureEnvelope(
            .movementChangeContent,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000062",
            counter: 1,
            device: fenceFixtureSecondDevice,
            revision: 1,
        )
        #expect(reducer.reduce(second, on: &engine, atTicks: 1000).outcome == .committed)

        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))
        let loaded = try #require(try await store.loadState())
        #expect(loaded.coordinatorFence.committedActions.count == 2)
        let owners = Set(loaded.coordinatorFence.committedActions.keys.map(\.deviceID))
        #expect(owners == [fenceFixtureOwnerDevice, fenceFixtureSecondDevice])
        #expect(loaded.coordinatorFence.committedActions[first.action]?.outcome == .committed)
        #expect(loaded.coordinatorFence.committedActions[second.action]?.outcome == .committed)
    }

    @Test("No presenter reads a legacy key: the row key is stable and the fence needs no preferences row")
    func noPresenterReadsLegacyKey() async throws {
        let (directory, storeURL) = try ProtocolFenceStoreFixture.makeTemporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try ProtocolFenceStoreFixture.makeMigrated(at: storeURL)
        var reducer = OpportunityActionReducer()
        let engine = try fenceFixtureEngine()
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        // Migration never rekeys or duplicates the row, so presenter
        // verification reads against the "current" row keep resolving.
        let key = "current"
        let rows = try ModelContext(store.container).fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        ))
        #expect(rows.count == 1)
        #expect(rows.first?.profileID == ProtocolProfileID.balanced.rawValue)

        // The fence path consults no legacy preferences key: a container
        // holding only the protocol row restores the full fence.
        let lonelyContainer = try AppModelContainer.make(inMemory: true)
        let lonelyContext = ModelContext(lonelyContainer)
        let lonelyStored = try #require(try ModelContext(store.container).fetch(
            FetchDescriptor<StoredProtocolState>(),
        ).first)
        lonelyContext.insert(StoredProtocolState(
            key: lonelyStored.key,
            schemaVersion: lonelyStored.schemaVersion,
            profileID: lonelyStored.profileID,
            visualAccumulatedActiveUseSeconds: lonelyStored.visualAccumulatedActiveUseSeconds,
            movementAccumulatedActiveUseSeconds: lonelyStored.movementAccumulatedActiveUseSeconds,
            visualSnoozeDeadline: lonelyStored.visualSnoozeDeadline,
            movementSnoozeDeadline: lonelyStored.movementSnoozeDeadline,
            recoveryActiveUseSeconds: lonelyStored.recoveryActiveUseSeconds,
            recoveryMovementDeferralCount: lonelyStored.recoveryMovementDeferralCount,
            recoveryWasOfferedThisSession: lonelyStored.recoveryWasOfferedThisSession,
            recoveryLastObservedAt: lonelyStored.recoveryLastObservedAt,
            visualNotAppropriateThisSession: nil,
            movementNotAppropriateThisSession: nil,
            visualCycleIDStorage: lonelyStored.visualCycleIDStorage,
            movementCycleIDStorage: lonelyStored.movementCycleIDStorage,
            headsUpDeliveryStatePayload: lonelyStored.headsUpDeliveryStatePayload,
            coordinatorFencePayload: lonelyStored.coordinatorFencePayload,
        ))
        try lonelyContext.save()
        let lonelyStore = try SwiftDataProtocolStore(container: lonelyContainer)
        let lonely = try #require(try await lonelyStore.loadState())
        #expect(lonely.coordinatorFence == reducer.fenceState)
    }

    @Test("Relaunch through the store starts clean: counters persist, courtesy does not")
    func relaunchStartsCleanThroughStore() async throws {
        // R2 decision record: the extended-away runway is monotonic-uptime
        // anchored in-process state (see the Domain relaunch pin and its
        // contract citation). The store carries counters and snooze
        // deadlines only, so relaunch re-anchors instead of catching up.
        let configuration = try ProtocolConfiguration(
            visual: OpportunitySchedule(
                softDueSeconds: 10,
                targetSeconds: 20,
                latestPreferredSeconds: 30,
                durationOptionsSeconds: [5],
            ),
            movement: OpportunitySchedule(
                softDueSeconds: 15,
                targetSeconds: 50,
                latestPreferredSeconds: 60,
                durationOptionsSeconds: [12, 6],
            ),
            activityEstimator: ActivityEstimatorConfiguration(
                recentInputWindowSeconds: 60,
                longIdleResetSeconds: 300,
                wakeUnlockGraceSeconds: 90,
            ),
            delivery: OpportunityDeliveryConfiguration(
                waitForLowFrictionMoment: false,
                mergeWindowSeconds: 5,
                headsUpDefault: true,
                headsUpSecondsBeforeTarget: 2,
                snoozeOptionsSeconds: [3, 6, 9],
                maximumRepeatedEscalations: 1,
                lockoutAllowed: false,
            ),
        )
        var engine = ProtocolEngine(configuration: configuration)
        _ = engine.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        _ = engine.observe(.active(uptimeSeconds: 10, secondsSinceInput: 0))
        let away = engine.observe(.active(uptimeSeconds: 310, secondsSinceInput: 300))
        #expect(away.events.map(\.kind) == [.likelyNaturalInterruption])

        let store = try ProtocolFenceStoreFixture.makeFresh()
        try await store.saveState(engine.state)
        let restored = try #require(try await store.loadState())
        var relaunched = ProtocolEngine(configuration: configuration, state: restored)
        #expect(relaunched.state.visualClock.cycleID == engine.visualClock.cycleID)
        #expect(relaunched.state.visualClock.accumulatedActiveUseSeconds == engine.visualClock
            .accumulatedActiveUseSeconds)
        #expect(relaunched.state.movementClock.accumulatedActiveUseSeconds == engine.movementClock
            .accumulatedActiveUseSeconds)

        _ = relaunched.observe(.active(uptimeSeconds: 0, secondsSinceInput: 0))
        var sawDue = false
        var uptime: TimeInterval = 10
        while uptime <= 150 {
            let output = relaunched.observe(.active(uptimeSeconds: uptime, secondsSinceInput: 0))
            if relaunched.visualClock.phase == .readyToPresent
                || output.presentation == .visual
                || output.presentation == .merged
            {
                sawDue = true
                break
            }
            uptime += 10
        }
        #expect(sawDue, "A persisted courtesy anchor would hold visual past its normal due")
    }

    @Test("A future fence payload version is identified before its fence is decoded")
    func futureFencePayloadVersionRefused() throws {
        struct FutureEnvelope: Encodable {
            var schemaVersion = 999
            var fence: [String] = []
        }
        let future = try JSONEncoder().encode(FutureEnvelope())
        do {
            _ = try CoordinatorFenceStateCodec.decode(future)
            Issue.record("Expected a future fence payload version to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .unsupportedCoordinatorFenceVersion(999))
        }
    }

    @Test("A stored fence payload with duplicate records is refused, never trapped")
    func duplicatedFenceRecordRefused() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var engine = try fenceFixtureEngine()
        var reducer = OpportunityActionReducer()
        let envelope = try fenceFixtureEnvelope(
            .nowAcceptMovement,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000041",
            counter: 1,
            payload: OpportunityActionPayload(selectedDurationSeconds: 300),
        )
        #expect(reducer.reduce(envelope, on: &engine, atTicks: 1000).outcome == .committed)
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        let key = "current"
        let stored = try #require(try store.context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)
        let valid = String(decoding: stored.coordinatorFencePayload ?? Data(), as: UTF8.self)
        stored.coordinatorFencePayload = try Data(#require(
            duplicateFenceRecord(in: valid, arrayKey: "committedActions"),
        ).utf8)
        try store.context.save()

        do {
            _ = try await store.loadState()
            Issue.record("Expected a duplicated fence record to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .invalidCoordinatorFenceState)
        }
    }

    @Test("A same-generation write that drops retained commits is refused and replay survives")
    func sameGenerationEmptyFenceWriteRefused() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        var engine = try fenceFixtureEngine()
        var reducer = OpportunityActionReducer()
        let envelope = try fenceFixtureEnvelope(
            .nowAcceptMovement,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000051",
            counter: 3,
            payload: OpportunityActionPayload(selectedDurationSeconds: 300),
        )
        #expect(reducer.reduce(envelope, on: &engine, atTicks: 1000).outcome == .committed)
        try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))

        // Pre-2.6 snapshots carry an empty fence at the same generation.
        // Persisting one must not wipe the commit above.
        do {
            try await store.saveState(ProtocolState())
            Issue.record("Expected a same-generation fence wipe to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .illegalCoordinatorRollback)
        }

        let restored = try #require(try await store.loadState())
        #expect(restored.coordinatorFence.committedActions[envelope.action]?.outcome == .committed)
        var replayEngine = try ProtocolEngine(
            configuration: fenceFixtureConfiguration(),
            state: restored,
        )
        var replayReducer = OpportunityActionReducer(fenceState: restored.coordinatorFence)
        let replay = replayReducer.reduce(envelope, on: &replayEngine, atTicks: 2000)
        #expect(replay.outcome == .duplicateReplay)
    }

    @Test("A retained future-version fence is never overwritten by a write")
    func futureVersionFenceWriteRefused() async throws {
        let store = try ProtocolFenceStoreFixture.makeFresh()
        try await store.saveState(ProtocolState())
        let key = "current"
        let stored = try #require(try store.context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)
        let valid = String(decoding: stored.coordinatorFencePayload ?? Data(), as: UTF8.self)
        let future = valid.replacingOccurrences(of: "\"schemaVersion\":2", with: "\"schemaVersion\":999")
        #expect(future != valid)
        stored.coordinatorFencePayload = Data(future.utf8)
        try store.context.save()

        var engine = try fenceFixtureEngine()
        var reducer = OpportunityActionReducer()
        let envelope = try fenceFixtureEnvelope(
            .nowAcceptMovement,
            scope: .movement(cycle: ClockCycleID(scope: .movement, rawValue: 0)),
            actionUUID: "20000000-0000-0000-0000-000000000061",
            counter: 5,
            payload: OpportunityActionPayload(selectedDurationSeconds: 300),
        )
        #expect(reducer.reduce(envelope, on: &engine, atTicks: 1000).outcome == .committed)
        do {
            try await store.saveState(fenceFixtureState(engine: engine, fence: reducer.fenceState))
            Issue.record("Expected a future-version fence write to fail")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .unsupportedCoordinatorFenceVersion(999))
        }

        // The throw precedes any mutation: the newer binary's authority is intact.
        let retained = try #require(try store.context.fetch(FetchDescriptor<StoredProtocolState>(
            predicate: #Predicate { $0.key == key },
        )).first)
        #expect(retained.coordinatorFencePayload == Data(future.utf8))
    }
}

/// Duplicates the first element of the JSON array under `arrayKey`, returning
/// the tampered document, or nil when the array is absent or empty. The scan
/// respects string literals and escapes, so the duplicate is byte-exact.
private func duplicateFenceRecord(in document: String, arrayKey: String) -> String? {
    let needle = "\"\(arrayKey)\":["
    guard let keyRange = document.range(of: needle) else { return nil }
    let start = keyRange.upperBound
    var depth = 1
    var inString = false
    var escaped = false
    var cursor = start
    var end = document.endIndex
    while cursor < document.endIndex {
        let char = document[cursor]
        if inString {
            if escaped {
                escaped = false
            } else if char == "\\" {
                escaped = true
            } else if char == "\"" {
                inString = false
            }
        } else if char == "\"" {
            inString = true
        } else if char == "[" || char == "{" {
            depth += 1
        } else if char == "]" || char == "}" {
            depth -= 1
            if depth == 0 {
                end = cursor
                break
            }
        }
        cursor = document.index(after: cursor)
    }
    guard depth == 0, start < end else { return nil }
    let inner = document[start ..< end]
    guard !inner.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
    var tampered = document
    tampered.replaceSubrange(start ..< end, with: "\(inner),\(inner)")
    return tampered
}
