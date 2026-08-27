import Domain
import Foundation
import HeadsUp
import Testing
@testable import App

@Suite("Heads-Up lifecycle composition")
struct HeadsUpLifecycleCoordinatorTests {
    @Test("A persisted reservation reaches the fallback capsule with the exact UUID")
    func reservationBeforeCapsule() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let capsule = FakeHeadsUpCapsulePresenter()
        var reservationWasPersisted = false
        capsule.onPresent = {
            reservationWasPersisted = store.state?.headsUpDeliveryState.activeDelivery?.phase
                == .reserved
        }
        let harness = makeHarness(runtime: runtime, capsule: capsule)
        await harness.coordinator.start()

        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()

        let active = try #require(runtime.state.headsUpDeliveryState.activeDelivery)
        #expect(reservationWasPersisted)
        #expect(capsule.presented.map(\.deliveryID) == [active.id.rawValue])
        #expect(active.phase == .presented)
        #expect(active.channel == .capsule)
        #expect(active.promptFactStatus == .acknowledged)
    }

    @Test("Denied notifications use the capsule without replacing delivery identity")
    func deniedFallback() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .denied, alertsEnabled: false),
        ])
        let capsule = FakeHeadsUpCapsulePresenter()
        let harness = makeHarness(runtime: runtime, center: center, capsule: capsule)
        await harness.coordinator.start()

        harness.coordinator.observeHeadsUp(snapshot(.movement(cycleID: 0)))
        await harness.coordinator.drain()

        let active = try #require(runtime.state.headsUpDeliveryState.activeDelivery)
        #expect(center.addedRequests.isEmpty)
        #expect(capsule.presented.map(\.deliveryID) == [active.id.rawValue])
        #expect(active.channel == .capsule)
    }

    @Test("Authorized Notification Center presents the exact request without a capsule duplicate")
    func authorizedNotification() async throws {
        let id = deliveryID(1)
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: id.rawValue)
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let center = FakeHeadsUpNotificationCenter(
            settings: [.init(authorizationStatus: .authorized, alertsEnabled: true)],
            deliveredIdentifiers: [[requestID]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        let harness = makeHarness(
            runtime: runtime,
            center: center,
            capsule: capsule,
            usesInAppHeadsUp: false,
        )
        await harness.coordinator.start()

        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()

        #expect(center.addedRequests.map(\.deliveryID) == [id.rawValue])
        #expect(capsule.presented.isEmpty)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.channel == .notification)
    }

    @Test("Suppression cancels the exact notification reconciliation in flight")
    func suppressionCancelsInFlightDelivery() async throws {
        let id = deliveryID(1)
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let gate = HeadsUpNotificationTestGate()
        let center = FakeHeadsUpNotificationCenter(
            settings: [.init(authorizationStatus: .authorized, alertsEnabled: true)],
            deliveredIdentifiers: [[]],
        )
        center.onDeliveredRead = { await gate.wait() }
        let capsule = FakeHeadsUpCapsulePresenter()
        let harness = makeHarness(
            runtime: runtime,
            center: center,
            capsule: capsule,
            usesInAppHeadsUp: false,
        )
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        while center.addedRequests.isEmpty { await Task.yield() }

        try await runtime.handle(.pause(.untilResume))
        gate.open()
        await harness.coordinator.drain()

        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: id.rawValue)
        #expect(center.removedPendingIdentifiers.contains([requestID]))
        #expect(center.removedDeliveredIdentifiers.contains([requestID]))
        #expect(capsule.presented.isEmpty)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery == nil)
    }

    @Test("A launch response waits for restore and prompt acknowledgement before opening")
    func bufferedLaunchResponse() async throws {
        let id = deliveryID(8)
        let active = HeadsUpActiveDelivery(
            id: id,
            opportunity: .visual(cycleID: 0),
            phase: .presented,
            channel: .notification,
            promptFactStatus: .acknowledged,
            countdownMark: .seconds30,
        )
        let store = HeadsUpRuntimeStore(state: ProtocolState(
            headsUpDeliveryState: HeadsUpDeliveryState(activeDelivery: active),
        ))
        let runtime = try makeRuntime(store: store)
        var openings: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            presentBreak: { id, opportunity in
                openings.append((id, opportunity))
                return .presented
            },
        )

        harness.coordinator.receive(.startNow(id.rawValue))
        #expect(openings.isEmpty)
        await harness.coordinator.start()
        await harness.coordinator.drain()

        #expect(openings.map(\.0) == [id])
        #expect(runtime.state.headsUpDeliveryState.pendingAction?.id == id)

        var completion: Result<Void, any Error>?
        #expect(!harness.coordinator.completePendingBreakOpening(
            actionID: deliveryID(99),
            family: .visualReset,
            completion: { completion = $0 },
        ))
        #expect(completion == nil)
        #expect(runtime.state.headsUpDeliveryState.pendingAction?.id == id)
        #expect(harness.coordinator.completePendingBreakOpening(
            actionID: id,
            family: .visualReset,
            completion: { completion = $0 },
        ))
        await harness.coordinator.drain()

        #expect(completion?.isSuccess == true)
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)
        #expect(store.commits.last?.events.map(\.kind) == [.breakStarted])
        #expect(store.commits.last?.events.map(\.source) == [.user])
    }

    @Test("Merged delivery uses one UUID, one prompt fact, and one overlay opening")
    func mergedConvergesOnce() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let capsule = FakeHeadsUpCapsulePresenter()
        var openings: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            capsule: capsule,
            presentBreak: { id, opportunity in
                openings.append((id, opportunity))
                return .presented
            },
        )
        await harness.coordinator.start()
        let opportunity = HeadsUpOpportunityID.merged(
            visualCycleID: 0,
            movementCycleID: 0,
        )
        harness.coordinator.observeHeadsUp(snapshot(opportunity))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)

        #expect(capsule.presented.map(\.deliveryID) == [id.rawValue])
        #expect(store.commits.flatMap(\.events).filter { $0.kind == .promptPresented }.count == 1)

        harness.coordinator.receive(.startNow(id.rawValue))
        await harness.coordinator.drain()
        #expect(openings.map(\.0) == [id])
        #expect(openings.map(\.1) == [opportunity])

        var completion: Result<Void, any Error>?
        #expect(harness.coordinator.completePendingBreakOpening(
            actionID: id,
            family: .merged,
            completion: { completion = $0 },
        ))
        await harness.coordinator.drain()
        #expect(completion?.isSuccess == true)
        #expect(store.commits.flatMap(\.events).filter { $0.kind == .breakStarted }.count == 1)
    }

    @Test("Explicit Start records user only after the exact overlay confirms opening")
    func explicitOpeningSource() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var openings: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            presentBreak: { id, opportunity in
                openings.append((id, opportunity))
                return .presented
            },
        )
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)

        harness.coordinator.receive(.startNow(id.rawValue))
        await harness.coordinator.drain()
        #expect(openings.map(\.0) == [id])
        #expect(store.commits.flatMap(\.events).filter { $0.kind == .breakStarted }.isEmpty)

        var completion: Result<Void, any Error>?
        #expect(harness.coordinator.completePendingBreakOpening(
            actionID: id,
            family: .visualReset,
            completion: { completion = $0 },
        ))
        await harness.coordinator.drain()
        #expect(completion?.isSuccess == true)
        #expect(store.commits.last?.events.map(\.source) == [.user])
    }

    @Test("Restore orders reserved delivery, acknowledged delivery, and pending action distinctly")
    func restoredStateOrdering() async throws {
        let reservedID = deliveryID(4)
        let reservedStore = HeadsUpRuntimeStore(state: ProtocolState(
            headsUpDeliveryState: HeadsUpDeliveryState(activeDelivery: HeadsUpActiveDelivery(
                id: reservedID,
                opportunity: .visual(cycleID: 0),
                countdownMark: .seconds30,
            )),
        ))
        let reservedRuntime = try makeRuntime(store: reservedStore)
        let reservedCapsule = FakeHeadsUpCapsulePresenter()
        let reserved = makeHarness(runtime: reservedRuntime, capsule: reservedCapsule)
        await reserved.coordinator.start()
        await reserved.coordinator.drain()
        #expect(reservedCapsule.presented.map(\.deliveryID) == [reservedID.rawValue])

        let acknowledgedID = deliveryID(5)
        let acknowledgedStore = HeadsUpRuntimeStore(state: ProtocolState(
            headsUpDeliveryState: HeadsUpDeliveryState(activeDelivery: HeadsUpActiveDelivery(
                id: acknowledgedID,
                opportunity: .movement(cycleID: 0),
                phase: .presented,
                channel: .notification,
                promptFactStatus: .acknowledged,
                countdownMark: .seconds15,
            )),
        ))
        let acknowledgedRuntime = try makeRuntime(store: acknowledgedStore)
        let acknowledgedCapsule = FakeHeadsUpCapsulePresenter()
        let acknowledged = makeHarness(
            runtime: acknowledgedRuntime,
            capsule: acknowledgedCapsule,
        )
        await acknowledged.coordinator.start()
        await acknowledged.coordinator.drain()
        #expect(acknowledgedCapsule.presented.isEmpty)
        #expect(acknowledged.coordinator.statusProjection?.scope == .movement)

        let pendingID = deliveryID(6)
        let pendingAction = HeadsUpPendingAction(
            id: pendingID,
            kind: .openMoreOptions,
            opportunity: .merged(visualCycleID: 0, movementCycleID: 0),
            source: .user,
        )
        let pendingStore = HeadsUpRuntimeStore(state: ProtocolState(
            headsUpDeliveryState: HeadsUpDeliveryState(pendingAction: pendingAction),
        ))
        let pendingRuntime = try makeRuntime(store: pendingStore)
        var pendingPresentations: [HeadsUpDeliveryID] = []
        let pending = makeHarness(
            runtime: pendingRuntime,
            presentMoreOptions: { id, _ in
                pendingPresentations.append(id)
                return .blocked
            },
        )
        await pending.coordinator.start()
        await pending.coordinator.drain()
        #expect(pendingPresentations == [pendingID])
        #expect(pendingRuntime.state.headsUpDeliveryState.pendingAction == pendingAction)
    }

    @Test("More Options clears its outbox only after the exact scoped surface presents")
    func exactMoreOptionsPresentation() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var result = BreakFlowOverlayCoordinator.PresentationResult.blocked
        var presentations: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            presentMoreOptions: { id, opportunity in
                presentations.append((id, opportunity))
                return result
            },
        )
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.merged(
            visualCycleID: 0,
            movementCycleID: 0,
        )))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)

        harness.coordinator.receive(.moreOptions(id.rawValue))
        await harness.coordinator.drain()
        #expect(runtime.state.headsUpDeliveryState.pendingAction?.id == id)
        #expect(presentations.count == 1)

        result = .presented
        harness.coordinator.retryPendingPresentation()
        await harness.coordinator.drain()
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)
        #expect(presentations.map(\.0) == [id, id])
        #expect(presentations.map(\.1) == [
            .merged(visualCycleID: 0, movementCycleID: 0),
            .merged(visualCycleID: 0, movementCycleID: 0),
        ])
    }

    @Test("A restored More Options action reuses its exact UUID and scope")
    func restoredMoreOptions() async throws {
        let id = deliveryID(7)
        let action = HeadsUpPendingAction(
            id: id,
            kind: .openMoreOptions,
            opportunity: .movement(cycleID: 3),
            source: .user,
        )
        let store = HeadsUpRuntimeStore(state: ProtocolState(
            movementClock: OpportunityClockState(cycleID: 3),
            headsUpDeliveryState: HeadsUpDeliveryState(pendingAction: action),
        ))
        let runtime = try makeRuntime(store: store)
        var presentations: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            presentMoreOptions: { id, opportunity in
                presentations.append((id, opportunity))
                return .presented
            },
        )

        await harness.coordinator.start()
        await harness.coordinator.drain()

        #expect(presentations.map(\.0) == [id])
        #expect(presentations.map(\.1) == [.movement(cycleID: 3)])
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)
    }

    @Test("Automatic target opening records localTimer only after the overlay opens")
    func automaticOpeningSource() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var openings: [(HeadsUpDeliveryID, HeadsUpOpportunityID)] = []
        let harness = makeHarness(
            runtime: runtime,
            presentBreak: { id, opportunity in
                openings.append((id, opportunity))
                return .presented
            },
        )
        await harness.coordinator.start()

        harness.coordinator.observeHeadsUp(snapshot(.movement(cycleID: 0), target: 0))
        await harness.coordinator.drain()
        #expect(openings.map(\.0) == [deliveryID(1)])
        #expect(store.commits.flatMap(\.events).filter { $0.kind == .breakStarted }.isEmpty)

        var completion: Result<Void, any Error>?
        #expect(harness.coordinator.completePendingBreakOpening(
            actionID: deliveryID(1),
            family: .movement,
            completion: { completion = $0 },
        ))
        await harness.coordinator.drain()

        #expect(completion?.isSuccess == true)
        #expect(store.commits.last?.events.map(\.kind) == [.breakStarted])
        #expect(store.commits.last?.events.map(\.source) == [.localTimer])
    }

    @Test("A nil production policy constructs no Heads-Up adapter graph")
    func nilPolicyBuildsNoAdapters() {
        var factoryCalls = 0

        let composition: HeadsUpLifecycleCoordinator? = HeadsUpLifecycleComposition.makeIfConfigured(
            policy: nil,
            make: {
                factoryCalls += 1
                fatalError("The nil-policy factory must stay inert")
            },
        )

        #expect(composition == nil)
        #expect(factoryCalls == 0)
    }

    @Test("A response write failure rejects the model intent and stays retryable")
    func responsePersistenceRetry() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var errors = 0
        let harness = makeHarness(runtime: runtime, onError: { _ in errors += 1 })
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        store.failuresRemaining = 1

        harness.coordinator.send(.start(scope: .visual))
        await harness.coordinator.drain()
        #expect(errors == 1)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery != nil)
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)

        harness.coordinator.send(.start(scope: .visual))
        await harness.coordinator.drain()
        #expect(runtime.state.headsUpDeliveryState.pendingAction?.kind == .openBreak)
    }

    @Test("A prompt-fact write failure retries the same confirmed delivery without redelivery")
    func promptFactPersistenceRetry() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let capsule = FakeHeadsUpCapsulePresenter()
        var errors = 0
        let harness = makeHarness(
            runtime: runtime,
            capsule: capsule,
            onError: { _ in errors += 1 },
        )
        await harness.coordinator.start()
        store.failOnAttempt = store.commitAttempts + 2
        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        let id = try #require(runtime.state.headsUpDeliveryState.activeDelivery?.id)

        #expect(errors == 1)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.phase == .reserved)
        #expect(capsule.presented.map(\.deliveryID) == [id.rawValue])

        harness.coordinator.retryActiveDelivery()
        await harness.coordinator.drain()

        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.phase == .presented)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.promptFactStatus == .acknowledged)
        #expect(capsule.presented.map(\.deliveryID) == [id.rawValue])
    }

    @Test("Dismissal and unresolved body tap remain fact-free")
    func factFreeResponses() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let harness = makeHarness(runtime: runtime)
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.visual(cycleID: 0)))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)
        let commitCount = store.commits.count

        harness.coordinator.receive(.dismiss(id.rawValue))
        harness.coordinator.receive(.defaultBodyTapAwaitingOwnerDecision(id.rawValue))
        await harness.coordinator.drain()

        #expect(store.commits.count == commitCount)
        #expect(runtime.state.headsUpDeliveryState.activeDelivery?.id == id)
        #expect(runtime.state.headsUpDeliveryState.pendingAction == nil)
    }

    @Test("Concurrent exact responses settle only once")
    func concurrentResponsesSettleOnce() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        let harness = makeHarness(runtime: runtime)
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.movement(cycleID: 0)))
        await harness.coordinator.drain()
        let id = try #require(harness.coordinator.activeDeliveryID)

        harness.coordinator.receive(.startNow(id.rawValue))
        harness.coordinator.receive(.snoozeFiveMinutes(id.rawValue))
        await harness.coordinator.drain()

        #expect(runtime.state.headsUpDeliveryState.pendingAction?.kind == .openBreak)
        #expect(store.commits.flatMap(\.events).filter { $0.kind == .snoozed }.isEmpty)
    }

    @Test("The status menu projection comes from the exact live capsule model")
    func statusProjection() async throws {
        let store = HeadsUpRuntimeStore()
        let runtime = try makeRuntime(store: store)
        var projections: [HeadsUpStatusMenuProjection?] = []
        let harness = makeHarness(
            runtime: runtime,
            onStatusProjection: { projections.append($0) },
        )
        await harness.coordinator.start()
        harness.coordinator.observeHeadsUp(snapshot(.merged(
            visualCycleID: 0,
            movementCycleID: 0,
        )))
        await harness.coordinator.drain()

        let projection = try #require(harness.coordinator.statusProjection)
        #expect(projection.scope == .merged)
        #expect(projection.intents.first == .start(scope: .merged))
        #expect(projection.intents.last == .moreOptions(scope: .merged))
        #expect(projections.last! == projection)
    }
}

private extension HeadsUpLifecycleCoordinatorTests {
    struct Harness {
        let coordinator: HeadsUpLifecycleCoordinator
    }

    func makeHarness(
        runtime: ProtocolRuntime,
        center: FakeHeadsUpNotificationCenter? = nil,
        capsule: FakeHeadsUpCapsulePresenter = FakeHeadsUpCapsulePresenter(),
        presentBreak: @escaping HeadsUpLifecycleCoordinator.BreakPresenter = { _, _ in .presented },
        presentMoreOptions: @escaping HeadsUpLifecycleCoordinator.MoreOptionsPresenter = {
            _, _ in .presented
        },
        onStatusProjection: @escaping (HeadsUpStatusMenuProjection?) -> Void = { _ in },
        onError: @escaping (any Error) -> Void = { _ in },
        usesInAppHeadsUp: Bool = true,
    ) -> Harness {
        let center = center ?? FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .denied, alertsEnabled: false),
        ])
        let authorizationStore = FakeHeadsUpAuthorizationStore()
        authorizationStore.state.usesInAppHeadsUp = usesInAppHeadsUp
        let permission = HeadsUpPermissionPanelCoordinator { _, onAction, _ in
            AutoChoicePermissionPanel(onPresent: { onAction(.useInAppHeadsUp) })
        }
        return Harness(coordinator: HeadsUpLifecycleCoordinator(
            runtime: runtime,
            center: center,
            authorizationStore: authorizationStore,
            permissionPanelCoordinator: permission,
            capsule: capsule,
            reconciliationAttempts: 1,
            reconciliationWait: {},
            wallNow: { Date(timeIntervalSince1970: 100) },
            driverFactory: { model, lead in
                HeadsUpApproachDriver(
                    model: model,
                    leadSeconds: lead,
                    now: { 0 },
                    scheduleRefresh: { _ in OverlayCancellation {} },
                )
            },
            presentBreak: presentBreak,
            presentMoreOptions: presentMoreOptions,
            onStatusProjection: onStatusProjection,
            onError: onError,
        ))
    }

    func makeRuntime(store: HeadsUpRuntimeStore) throws -> ProtocolRuntime {
        ProtocolRuntime(
            configuration: try ProtocolProfiles.configuration(for: .balanced),
            store: store,
            headsUpRuntimePolicy: HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1),
            now: { Date(timeIntervalSince1970: 100) },
            makeID: { deliveryID(1).rawValue },
        )
    }

    func snapshot(
        _ opportunity: HeadsUpOpportunityID,
        target: TimeInterval = 45,
    ) -> HeadsUpDeliverySnapshot {
        HeadsUpDeliverySnapshot(
            opportunity: opportunity,
            currentVisualCycleID: 0,
            currentMovementCycleID: 0,
            observedAt: Date(timeIntervalSince1970: 100),
            secondsUntilTarget: target,
            secondsUntilLatest: target + 60,
            headsUpEnabled: true,
            headsUpLeadSeconds: 45,
            waitsForLowFrictionMoment: false,
            isLowFrictionMoment: true,
        )
    }

    func deliveryID(_ value: UInt8) -> HeadsUpDeliveryID {
        HeadsUpDeliveryID(rawValue: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value),
        ))
    }
}

private final class AutoChoicePermissionPanel: HeadsUpPermissionPanelPresenting {
    let onPresent: () -> Void

    init(onPresent: @escaping () -> Void) {
        self.onPresent = onPresent
    }

    func present() { onPresent() }
    func close() {}
}

private extension Result where Success == Void {
    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
