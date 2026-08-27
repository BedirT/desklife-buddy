import Foundation
import HeadsUp
import Testing
@testable import App

@Suite("Heads-up notification delivery")
struct HeadsUpNotificationDeliveryTests {
    @Test("Crash relaunch registers the persisted UUID before reconciling its delivered notification")
    func crashRelaunchReconcilesDeliveredNotification() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000070")!
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        let registry = HeadsUpNotificationResponseRegistry()
        #expect(registry.registerActive(deliveryID: deliveryID))
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[requestID]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            responseRegistry: registry,
        )

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        ) == .notification)
        #expect(center.addedRequests.map(\.deliveryID) == [deliveryID])
        #expect(center.addedRequests.map(\.userInfo) == [[
            HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey:
                deliveryID.uuidString.lowercased(),
        ]])
        #expect(capsule.presented.isEmpty)
    }

    @Test("Delivered UUID confirms notification without presenting capsule")
    func notificationConfirmed() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000051")!
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [
                [],
                [HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)],
            ],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        var delays = 0
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            reconciliationAttempts: 3,
            wait: { delays += 1 },
        )

        let channel = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .notification,
        )

        #expect(channel == .notification)
        #expect(center.addedRequests.map(\.identifier) == [
            HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID),
        ])
        #expect(center.deliveredReadCount == 2)
        #expect(delays == 1)
        #expect(capsule.presented.isEmpty)
        #expect(center.removedPendingIdentifiers.isEmpty)
        #expect(center.removedDeliveredIdentifiers.isEmpty)
    }

    @Test("Absent delivery is cancelled then falls back to capsule using the same UUID")
    func absentFallsBack() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000052")!
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[], [], []],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        var delays = 0
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            reconciliationAttempts: 3,
            wait: { delays += 1 },
        )

        let channel = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )

        #expect(channel == .capsule)
        #expect(center.deliveredReadCount == 3)
        #expect(delays == 2)
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        #expect(center.removedPendingIdentifiers == [[requestID]])
        #expect(center.removedDeliveredIdentifiers == [[requestID]])
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
        #expect(capsule.presented.map(\.content.scope) == [.visual])
    }

    @Test("Add failure cleans both notification stores before capsule fallback")
    func addFailureFallsBack() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000053")!
        let center = FakeHeadsUpNotificationCenter(settings: [])
        center.addError = FakeHeadsUpNotificationCenter.Failure.requested
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        let channel = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .merged),
            preferredChannel: .notification,
        )

        #expect(channel == .capsule)
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        #expect(center.removedPendingIdentifiers == [[requestID]])
        #expect(center.removedDeliveredIdentifiers == [[requestID]])
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
        #expect(capsule.presented.map(\.content.scope) == [.merged])
    }

    @Test("Default reconciliation is bounded at five observations with four waits")
    func defaultReconciliationBound() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[], [], [], [], []],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        var delays = 0
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            wait: { delays += 1 },
        )

        let channel = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )

        #expect(channel == .capsule)
        #expect(center.deliveredReadCount == 5)
        #expect(delays == 4)
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
    }

    @Test("Concurrent calls for one delivery UUID share one add, poll, and fallback")
    func concurrentDeliveryCoalesces() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000056")!
        let gate = HeadsUpNotificationTestGate()
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[]],
        )
        center.onAdd = { await gate.wait() }
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            reconciliationAttempts: 1,
        )

        async let first = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        while center.addedRequests.isEmpty {
            await Task.yield()
        }
        async let second = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        await Task.yield()

        #expect(center.addedRequests.count == 1)
        coordinator.releasePersistedDelivery(deliveryID: deliveryID)
        #expect(coordinator.cachedDeliveryCount == 1)
        gate.open()
        let channels = await [first, second]

        #expect(channels == [.capsule, .capsule])
        #expect(center.addedRequests.count == 1)
        #expect(center.deliveredReadCount == 1)
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
        #expect(center.removedPendingIdentifiers.count == 1)
        #expect(center.removedDeliveredIdentifiers.count == 1)
        coordinator.releasePersistedDelivery(deliveryID: deliveryID)
        #expect(coordinator.cachedDeliveryCount == 0)
    }

    @Test("A completed retry for one delivery UUID reuses the confirmed channel")
    func completedDeliveryRetryCoalesces() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000057")!
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[requestID]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        let first = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        let retry = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        )

        #expect(first == .notification)
        #expect(retry == .notification)
        #expect(center.addedRequests.count == 1)
        #expect(center.deliveredReadCount == 1)
        #expect(capsule.presented.isEmpty)
        #expect(coordinator.cachedDeliveryCount == 1)
    }

    @Test("Persisted prompt fact releases a completed delivery cache entry")
    func persistedPromptFactReleasesDelivery() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000058")!
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[requestID]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        ) == .notification)
        #expect(coordinator.cachedDeliveryCount == 1)

        coordinator.releasePersistedDelivery(deliveryID: deliveryID)

        #expect(coordinator.cachedDeliveryCount == 0)
        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == .capsule)
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
    }

    @Test("Capsule preference does not submit a notification and reports only confirmed presentation")
    func capsuleOnly() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000054")!
        let center = FakeHeadsUpNotificationCenter(settings: [])
        let capsule = FakeHeadsUpCapsulePresenter()
        capsule.shouldConfirm = false
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        let channel = await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .capsule,
        )

        #expect(channel == nil)
        #expect(center.addedRequests.isEmpty)
        #expect(capsule.presented.map(\.deliveryID) == [deliveryID])
    }

    @Test("Cancellation during native add removes both stores and prevents stale fallback")
    func cancelDuringAdd() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-00000000005A")!
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        let gate = HeadsUpNotificationTestGate()
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[]],
        )
        center.onAdd = { await gate.wait() }
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            reconciliationAttempts: 1,
        )

        async let delivery = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        while center.addedRequests.isEmpty {
            await Task.yield()
        }

        coordinator.withdraw(.cancelBeforePresentation(deliveryID))

        #expect(center.removedPendingIdentifiers == [[requestID]])
        #expect(center.removedDeliveredIdentifiers == [[requestID]])
        #expect(capsule.dismissedDeliveryIDs == [deliveryID])
        gate.open()
        #expect(await delivery == nil)
        #expect(capsule.presented.isEmpty)
        #expect(center.removedPendingIdentifiers == [[requestID], [requestID]])
        #expect(center.removedDeliveredIdentifiers == [[requestID], [requestID]])
        #expect(coordinator.cachedDeliveryCount == 1)

        coordinator.releasePersistedDelivery(deliveryID: deliveryID)
        #expect(coordinator.cachedDeliveryCount == 0)
    }

    @Test("Retraction removes a confirmed native notification and blocks stale redelivery")
    func retractConfirmedNotification() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-00000000005B")!
        let requestID = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[requestID]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .notification,
        ) == .notification)

        coordinator.withdraw(.retractPresented(deliveryID))

        #expect(center.removedPendingIdentifiers == [[requestID]])
        #expect(center.removedDeliveredIdentifiers == [[requestID]])
        #expect(capsule.dismissedDeliveryIDs == [deliveryID])
        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .notification,
        ) == nil)
        #expect(center.addedRequests.count == 1)
    }

    @Test("Retraction dismisses a confirmed capsule by exact delivery identity")
    func retractConfirmedCapsule() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-00000000005C")!
        let otherID = UUID(uuidString: "00000000-0000-0000-0000-00000000005D")!
        let center = FakeHeadsUpNotificationCenter(settings: [])
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .merged),
            preferredChannel: .capsule,
        ) == .capsule)

        coordinator.withdraw(.retractPresented(deliveryID))
        coordinator.withdraw(.cancelBeforePresentation(otherID))

        #expect(capsule.dismissedDeliveryIDs == [deliveryID, otherID])
        #expect(center.removedPendingIdentifiers == [
            [HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)],
            [HeadsUpNotificationIdentifiers.requestIdentifier(for: otherID)],
        ])
        #expect(center.removedDeliveredIdentifiers == center.removedPendingIdentifiers)
    }

    @Test("Withdrawal during capsule presentation makes the late confirmation inert")
    func withdrawDuringCapsulePresentation() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-00000000005E")!
        let gate = HeadsUpNotificationTestGate()
        let center = FakeHeadsUpNotificationCenter(settings: [])
        let capsule = FakeHeadsUpCapsulePresenter()
        capsule.onPresent = { await gate.wait() }
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        async let delivery = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .merged),
            preferredChannel: .capsule,
        )
        while capsule.presented.isEmpty {
            await Task.yield()
        }

        coordinator.withdraw(.retractPresented(deliveryID))
        gate.open()

        #expect(await delivery == nil)
        #expect(capsule.dismissedDeliveryIDs == [deliveryID, deliveryID])
        #expect(coordinator.cachedDeliveryCount == 1)
    }

    @Test("A native response confirms delivery before reconciliation without bypassing fact readiness")
    func nativeResponseConfirmsDelivery() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-00000000005F")!
        let gate = HeadsUpNotificationTestGate()
        let registry = HeadsUpNotificationResponseRegistry()
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[]],
        )
        center.onDeliveredRead = { await gate.wait() }
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            responseRegistry: registry,
            reconciliationAttempts: 1,
        )
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        async let delivery = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        while center.deliveredReadCount == 0 {
            await Task.yield()
        }
        let nativeResponse = HeadsUpNotificationResponseMapper.map(
            HeadsUpNotificationResponseEnvelope(
                requestIdentifier: HeadsUpNotificationIdentifiers.requestIdentifier(
                    for: deliveryID,
                ),
                categoryIdentifier: HeadsUpNotificationIdentifiers.category,
                actionIdentifier: HeadsUpNotificationIdentifiers.startNowAction,
                userInfo: [
                    HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey:
                        deliveryID.uuidString.lowercased(),
                ],
            ),
        )
        #expect(nativeResponse == .startNow(deliveryID))
        buffer.receive(nativeResponse)
        gate.open()

        #expect(await delivery == .notification)
        #expect(capsule.presented.isEmpty)
        #expect(center.removedPendingIdentifiers.isEmpty)
        #expect(center.removedDeliveredIdentifiers.isEmpty)
        #expect(buffer.queuedResponseCount == 1)
        #expect(routed.isEmpty)

        buffer.markRuntimeRestored()
        #expect(routed.isEmpty)
        buffer.markPromptFactReady(deliveryID: deliveryID)
        #expect(routed == [.startNow(deliveryID)])
    }

    @Test("A response during suspended capsule fallback retracts it and confirms notification")
    func nativeResponseDuringFallback() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000067")!
        let gate = HeadsUpNotificationTestGate()
        let registry = HeadsUpNotificationResponseRegistry()
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[]],
        )
        let capsule = FakeHeadsUpCapsulePresenter()
        capsule.onPresent = { await gate.wait() }
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            responseRegistry: registry,
            reconciliationAttempts: 1,
        )
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        async let delivery = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
            preferredChannel: .notification,
        )
        while capsule.presented.isEmpty {
            await Task.yield()
        }
        let nativeResponse = HeadsUpNotificationResponseMapper.map(
            HeadsUpNotificationResponseEnvelope(
                requestIdentifier: HeadsUpNotificationIdentifiers.requestIdentifier(
                    for: deliveryID,
                ),
                categoryIdentifier: HeadsUpNotificationIdentifiers.category,
                actionIdentifier: HeadsUpNotificationIdentifiers.startNowAction,
                userInfo: [
                    HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey:
                        deliveryID.uuidString.lowercased(),
                ],
            ),
        )
        #expect(nativeResponse == .startNow(deliveryID))
        buffer.receive(nativeResponse)
        gate.open()

        #expect(await delivery == .notification)
        #expect(capsule.dismissedDeliveryIDs == [deliveryID])
        #expect(buffer.queuedResponseCount == 1)
        #expect(routed.isEmpty)
        buffer.markRuntimeRestored()
        #expect(routed.isEmpty)
        buffer.markPromptFactReady(deliveryID: deliveryID)
        #expect(routed == [.startNow(deliveryID)])
    }

    @Test("Early withdrawal release waits for quiescence and requires a fresh logical UUID")
    func withdrawalReleaseWaitsForQuiescence() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000060")!
        let freshID = UUID(uuidString: "00000000-0000-0000-0000-00000000006C")!
        let gate = HeadsUpNotificationTestGate()
        let center = FakeHeadsUpNotificationCenter(
            settings: [],
            deliveredIdentifiers: [[]],
        )
        center.onAdd = { await gate.wait() }
        let capsule = FakeHeadsUpCapsulePresenter()
        let coordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            reconciliationAttempts: 1,
        )

        async let oldAttempt = coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .notification,
        )
        while center.addedRequests.isEmpty {
            await Task.yield()
        }
        coordinator.withdraw(.cancelBeforePresentation(deliveryID))
        coordinator.releasePersistedDelivery(deliveryID: deliveryID)

        #expect(coordinator.cachedDeliveryCount == 1)
        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == nil)
        #expect(capsule.presented.isEmpty)

        gate.open()
        #expect(await oldAttempt == nil)
        #expect(coordinator.cachedDeliveryCount == 0)
        center.onAdd = nil

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == nil)
        #expect(await coordinator.deliver(
            deliveryID: freshID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == .capsule)
        #expect(capsule.presented.map(\.deliveryID) == [freshID])
        #expect(capsule.dismissedDeliveryIDs == [deliveryID])
    }
}

@Suite("Heads-up notification delivery cache")
struct HeadsUpNotificationDeliveryCacheTests {
    @Test("Failed outcome coalesces until persisted release then retries")
    func failedOutcomeLifecycle() async {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000059")!
        let center = FakeHeadsUpNotificationCenter(settings: [])
        let capsule = FakeHeadsUpCapsulePresenter()
        capsule.shouldConfirm = false
        let coordinator = HeadsUpNotificationDeliveryCoordinator(center: center, capsule: capsule)

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == nil)
        capsule.shouldConfirm = true
        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == nil)
        #expect(capsule.presented.count == 1)
        #expect(coordinator.cachedDeliveryCount == 1)
        coordinator.releasePersistedDelivery(deliveryID: deliveryID)

        #expect(await coordinator.deliver(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
            preferredChannel: .capsule,
        ) == .capsule)
        #expect(capsule.presented.count == 2)
        #expect(capsule.presented.map(\.content.deliveryID) == [deliveryID, deliveryID])
    }
}

@Suite("Heads-up notification response buffer")
struct HeadsUpNotificationResponseBufferTests {
    @Test("Crash relaunch restores the stable delivery before draining its launch response")
    func crashRelaunchRestoresStableIdentity() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000069")!
        let registry = HeadsUpNotificationResponseRegistry()
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        let launchResponse = HeadsUpNotificationResponseMapper.map(
            HeadsUpNotificationResponseEnvelope(
                requestIdentifier: HeadsUpNotificationIdentifiers.requestIdentifier(
                    for: deliveryID,
                ),
                categoryIdentifier: HeadsUpNotificationIdentifiers.category,
                actionIdentifier: HeadsUpNotificationIdentifiers.startNowAction,
                userInfo: [
                    HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey:
                        deliveryID.uuidString.lowercased(),
                ],
            ),
        )
        #expect(launchResponse == .startNow(deliveryID))
        buffer.receive(launchResponse)
        #expect(buffer.queuedResponseCount == 1)
        #expect(registry.registerActive(deliveryID: deliveryID))
        buffer.markPromptFactReady(deliveryID: deliveryID)
        buffer.markRuntimeRestored()

        #expect(routed == [.startNow(deliveryID)])
        #expect(buffer.queuedResponseCount == 0)
    }

    @Test("Terminal retirement rejects the old UUID while a fresh logical UUID registers")
    func retirementRejectsReuse() {
        let retiredID = UUID(uuidString: "00000000-0000-0000-0000-00000000006A")!
        let freshID = UUID(uuidString: "00000000-0000-0000-0000-00000000006B")!
        let registry = HeadsUpNotificationResponseRegistry(retiredDeliveryLimit: 2)

        #expect(registry.registerActive(deliveryID: retiredID))
        registry.retire(deliveryID: retiredID)

        #expect(!registry.registerActive(deliveryID: retiredID))
        #expect(registry.registerActive(deliveryID: freshID))
        #expect(registry.registeredDeliveryCount == 1)
        #expect(registry.retiredDeliveryCount == 1)
    }

    @Test("Readiness for one delivery does not flush another before or after restore")
    func responseBeforeRestore() {
        let one = UUID(uuidString: "00000000-0000-0000-0000-000000000061")!
        let two = UUID(uuidString: "00000000-0000-0000-0000-000000000062")!
        let registry = HeadsUpNotificationResponseRegistry()
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        buffer.receive(.startNow(one))
        buffer.receive(.snoozeFiveMinutes(two))
        #expect(routed.isEmpty)

        #expect(registry.registerActive(deliveryID: one))
        #expect(registry.registerActive(deliveryID: two))
        buffer.markPromptFactReady(deliveryID: one)
        #expect(routed.isEmpty)
        buffer.markRuntimeRestored()
        #expect(routed == [.startNow(one)])
        #expect(buffer.queuedResponseCount == 1)

        buffer.markPromptFactReady(deliveryID: two)
        buffer.markRuntimeRestored()
        buffer.markPromptFactReady(deliveryID: two)
        #expect(routed == [.startNow(one), .snoozeFiveMinutes(two)])
        #expect(buffer.queuedResponseCount == 0)
    }

    @Test("Per-delivery drain preserves order exactly once and cleared state is bounded")
    func restoreBeforePromptFact() {
        let one = UUID(uuidString: "00000000-0000-0000-0000-000000000063")!
        let two = UUID(uuidString: "00000000-0000-0000-0000-000000000064")!
        let registry = HeadsUpNotificationResponseRegistry()
        #expect(registry.registerActive(deliveryID: one))
        #expect(registry.registerActive(deliveryID: two))
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        buffer.markRuntimeRestored()
        buffer.receive(.startNow(one))
        buffer.receive(.moreOptions(two))
        buffer.receive(.snoozeFiveMinutes(one))
        #expect(routed.isEmpty)

        buffer.markPromptFactReady(deliveryID: one)
        buffer.markPromptFactReady(deliveryID: one)
        #expect(routed == [.startNow(one), .snoozeFiveMinutes(one)])
        #expect(buffer.readyDeliveryCount == 1)
        #expect(buffer.queuedResponseCount == 1)

        buffer.clearDelivery(deliveryID: one)
        #expect(buffer.readyDeliveryCount == 0)
        buffer.markPromptFactReady(deliveryID: two)
        #expect(routed == [
            .startNow(one),
            .snoozeFiveMinutes(one),
            .moreOptions(two),
        ])
        buffer.clearDelivery(deliveryID: two)
        #expect(buffer.readyDeliveryCount == 0)
        buffer.receive(.dismiss(two))
        #expect(buffer.queuedResponseCount == 0)
        buffer.clearDelivery(deliveryID: two)
        #expect(buffer.queuedResponseCount == 0)
        #expect(registry.registeredDeliveryCount == 0)
    }

    @Test("Dismiss and unresolved body tap responses preserve identity through readiness")
    func factFreeResponsesRemainBuffered() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000065")!
        let registry = HeadsUpNotificationResponseRegistry()
        #expect(registry.registerActive(deliveryID: deliveryID))
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )

        buffer.receive(.dismiss(deliveryID))
        buffer.receive(.defaultBodyTapAwaitingOwnerDecision(deliveryID))
        buffer.markRuntimeRestored()
        #expect(routed.isEmpty)

        buffer.markPromptFactReady(deliveryID: deliveryID)

        #expect(routed == [
            .dismiss(deliveryID),
            .defaultBodyTapAwaitingOwnerDecision(deliveryID),
        ])
        #expect(buffer.queuedResponseCount == 0)
    }

    @Test("Terminal clear discards late responses and readiness cannot revive them")
    func terminalClearTombstonesIdentity() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000066")!
        let registry = HeadsUpNotificationResponseRegistry()
        #expect(registry.registerActive(deliveryID: deliveryID))
        var routed: [HeadsUpNotificationResponse] = []
        let buffer = HeadsUpNotificationResponseBuffer(
            responseRegistry: registry,
            onResponse: { routed.append($0) },
        )
        buffer.markRuntimeRestored()
        buffer.markPromptFactReady(deliveryID: deliveryID)
        buffer.clearDelivery(deliveryID: deliveryID)
        buffer.markPromptFactReady(deliveryID: deliveryID)

        buffer.receive(.startNow(deliveryID))
        buffer.receive(.dismiss(deliveryID))
        buffer.receive(.defaultBodyTapAwaitingOwnerDecision(deliveryID))

        #expect(routed.isEmpty)
        #expect(buffer.queuedResponseCount == 0)
        #expect(buffer.readyDeliveryCount == 0)
        #expect(registry.registeredDeliveryCount == 0)
        #expect(!registry.registerActive(deliveryID: deliveryID))
    }

    @Test("Retired UUID tombstones stay within their explicit bound")
    func retiredStorageIsBounded() {
        let registry = HeadsUpNotificationResponseRegistry(retiredDeliveryLimit: 2)
        let deliveryIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-00000000006D")!,
            UUID(uuidString: "00000000-0000-0000-0000-00000000006E")!,
            UUID(uuidString: "00000000-0000-0000-0000-00000000006F")!,
        ]

        for deliveryID in deliveryIDs {
            #expect(registry.registerActive(deliveryID: deliveryID))
            registry.retire(deliveryID: deliveryID)
        }

        #expect(registry.registeredDeliveryCount == 0)
        #expect(registry.retiredDeliveryCount == 2)
        #expect(!registry.registerActive(deliveryID: deliveryIDs[1]))
        #expect(!registry.registerActive(deliveryID: deliveryIDs[2]))
    }
}
