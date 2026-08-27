import Foundation
import HeadsUp
import Testing
@testable import App

@Suite("Heads-up notification authorization")
struct HeadsUpAuthorizationCoordinatorTests {
    @Test("User defaults store round-trips authorization history")
    func userDefaultsRoundTrip() throws {
        let suiteName = "AppTests.HeadsUpAuthorization.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let expected = HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: false,
            hasBeenAuthorized: true,
        )

        UserDefaultsHeadsUpAuthorizationStore(defaults: defaults).save(expected)

        let restored = UserDefaultsHeadsUpAuthorizationStore(defaults: defaults).load()
        #expect(restored == expected)
    }

    @Test("PM-01 Continue precedes one system request and settings are reread")
    func continueRequestsOnce() async {
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .authorized, alertsEnabled: true),
        ])
        var events: [String] = []
        center.onEvent = { events.append($0) }
        let coordinator = HeadsUpAuthorizationCoordinator(
            center: center,
            store: FakeHeadsUpAuthorizationStore(),
        )

        let first = await coordinator.selectChannel {
            events.append("explainer")
            return .continueWithNotifications
        }
        let second = await coordinator.selectChannel {
            events.append("unexpected-explainer")
            return .continueWithNotifications
        }

        #expect(first == .notification)
        #expect(second == .notification)
        #expect(center.authorizationRequestCount == 1)
        #expect(center.requestedOptions == [.alert])
        #expect(events.prefix(3) == ["settings", "explainer", "request"])
        #expect(events.count(where: { $0 == "settings" }) == 3)
        #expect(events.contains("unexpected-explainer") == false)
    }

    @Test("Choosing in-app after PM-01 never asks Notification Center")
    func inAppChoiceNeverRequests() async {
        let store = FakeHeadsUpAuthorizationStore()
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        var explainerCount = 0
        let coordinator = HeadsUpAuthorizationCoordinator(center: center, store: store)

        let first = await coordinator.selectChannel {
            explainerCount += 1
            return .useInAppHeadsUp
        }
        let second = await coordinator.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        }

        #expect(first == .capsule)
        #expect(second == .capsule)
        #expect(explainerCount == 1)
        #expect(center.authorizationRequestCount == 0)
        #expect(center.settingsReadCount == 1)

        let relaunchedCenter = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let relaunched = HeadsUpAuthorizationCoordinator(center: relaunchedCenter, store: store)
        let relaunchedChannel = await relaunched.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        }

        #expect(relaunchedChannel == .capsule)
        #expect(explainerCount == 1)
        #expect(relaunchedCenter.settingsReadCount == 0)
        #expect(relaunchedCenter.authorizationRequestCount == 0)
    }

    @Test("Prior authorization persists and later denial is inferred as revoked without nag")
    func revokedAfterRelaunch() async {
        let store = FakeHeadsUpAuthorizationStore()
        let initialCenter = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .authorized, alertsEnabled: true),
        ])
        let initial = HeadsUpAuthorizationCoordinator(center: initialCenter, store: store)
        var explainerCount = 0

        #expect(await initial.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        } == .notification)
        #expect(store.state.hasBeenAuthorized)

        let relaunchedCenter = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .denied, alertsEnabled: false),
        ])
        let relaunched = HeadsUpAuthorizationCoordinator(center: relaunchedCenter, store: store)
        let channel = await relaunched.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        }

        #expect(channel == .capsule)
        #expect(relaunched.resolvedAuthorizationStatus == .revoked)
        #expect(explainerCount == 1)
        #expect(relaunchedCenter.authorizationRequestCount == 0)
    }

    @Test("Unavailable notification states silently choose capsule", arguments: [
        HeadsUpNotificationSettings(authorizationStatus: .denied, alertsEnabled: false),
        .init(authorizationStatus: .revoked, alertsEnabled: false),
        .init(authorizationStatus: .authorized, alertsEnabled: false),
        .init(authorizationStatus: .provisional, alertsEnabled: true),
        .init(authorizationStatus: .unknown, alertsEnabled: true),
    ])
    func unavailableStates(settings: HeadsUpNotificationSettings) async {
        let center = FakeHeadsUpNotificationCenter(settings: [settings])
        var explainerCount = 0
        let coordinator = HeadsUpAuthorizationCoordinator(
            center: center,
            store: FakeHeadsUpAuthorizationStore(),
        )

        let channel = await coordinator.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        }

        #expect(channel == .capsule)
        #expect(explainerCount == 0)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("Settings and authorization failures silently choose capsule without repeat nag")
    func failures() async {
        let settingsFailure = FakeHeadsUpNotificationCenter(settings: [])
        settingsFailure.settingsError = FakeHeadsUpNotificationCenter.Failure.requested
        let settingsCoordinator = HeadsUpAuthorizationCoordinator(
            center: settingsFailure,
            store: FakeHeadsUpAuthorizationStore(),
        )
        var explainerCount = 0

        #expect(await settingsCoordinator.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        } == .capsule)
        #expect(explainerCount == 0)

        let requestFailure = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        requestFailure.authorizationError = FakeHeadsUpNotificationCenter.Failure.requested
        let requestCoordinator = HeadsUpAuthorizationCoordinator(
            center: requestFailure,
            store: FakeHeadsUpAuthorizationStore(),
        )

        #expect(await requestCoordinator.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        } == .capsule)
        #expect(await requestCoordinator.selectChannel {
            explainerCount += 1
            return .continueWithNotifications
        } == .capsule)
        #expect(requestFailure.authorizationRequestCount == 1)
        #expect(explainerCount == 1)
    }
}

@Suite("Heads-up authorization explainer lifecycle")
struct HeadsUpAuthorizationExplainerTests {
    @Test("Cancelling the only authorization waiter closes PM-01 without persisting a choice")
    func finalAuthorizationWaiterCancellation() async {
        let store = FakeHeadsUpAuthorizationStore()
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let authorization = HeadsUpAuthorizationCoordinator(center: center, store: store)
        let panelHarness = HeadsUpPermissionPanelHarness()
        let permission = panelHarness.makeCoordinator()
        let first = Task {
            await authorization.selectChannel { await permission.present() }
        }
        await panelHarness.waitForPanel(count: 1)

        first.cancel()
        for _ in 0 ..< 20 where panelHarness.panels[0].closeCount == 0 {
            await Task.yield()
        }
        let cancelledPanelClosed = panelHarness.panels[0].closeCount == 1
        if !cancelledPanelClosed {
            permission.tearDown()
        }

        #expect(cancelledPanelClosed)
        #expect(await first.value == .capsule)
        #expect(store.state == HeadsUpNotificationAuthorizationState())

        let retry = Task {
            await authorization.selectChannel { await permission.present() }
        }
        await panelHarness.waitForPanel(count: 2)
        panelHarness.panels[1].send(.useInAppHeadsUp)

        #expect(await retry.value == .capsule)
        #expect(store.state.hasPresentedExplainer)
        #expect(store.state.usesInAppHeadsUp)
    }

    @Test("Only cancelling the final coalesced authorization waiter closes PM-01")
    func coalescedAuthorizationWaiterCancellation() async {
        let store = FakeHeadsUpAuthorizationStore()
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let authorization = HeadsUpAuthorizationCoordinator(center: center, store: store)
        let panelHarness = HeadsUpPermissionPanelHarness()
        let permission = panelHarness.makeCoordinator()
        let first = Task {
            await authorization.selectChannel { await permission.present() }
        }
        let second = Task {
            await authorization.selectChannel { await permission.present() }
        }
        await panelHarness.waitForPanel(count: 1)

        first.cancel()
        for _ in 0 ..< 20 {
            await Task.yield()
        }
        #expect(panelHarness.panels[0].closeCount == 0)

        second.cancel()
        for _ in 0 ..< 20 where panelHarness.panels[0].closeCount == 0 {
            await Task.yield()
        }
        let finalCancellationClosedPanel = panelHarness.panels[0].closeCount == 1
        if !finalCancellationClosedPanel {
            permission.tearDown()
        }

        #expect(finalCancellationClosedPanel)
        #expect(await [first.value, second.value] == [.capsule, .capsule])
        #expect(panelHarness.panels.count == 1)
        #expect(store.state == HeadsUpNotificationAuthorizationState())
    }

    @Test("Settings lookup is coalesced before cancellation counts authorization waiters")
    func settingsLookupCancellationRace() async {
        let center = GatedAuthorizationNotificationCenter()
        let authorization = HeadsUpAuthorizationCoordinator(
            center: center,
            store: FakeHeadsUpAuthorizationStore(),
        )
        let panelHarness = HeadsUpPermissionPanelHarness()
        let permission = panelHarness.makeCoordinator()
        let first = Task { await authorization.selectChannel { await permission.present() } }
        let second = Task { await authorization.selectChannel { await permission.present() } }
        await center.waitForSettingsCalls(count: 1)
        await settleConcurrentTasks()
        let settingsWereCoalesced = center.settingsCallCount == 1

        center.releaseSettings(call: 0)
        await panelHarness.waitForPanel()
        first.cancel()
        await settleConcurrentTasks()
        let sharedPanelWasPreserved = panelHarness.panels[0].closeCount == 0

        if center.settingsCallCount > 1 {
            center.releaseSettings(call: 1)
            await settleConcurrentTasks()
        }
        panelHarness.panel?.send(.useInAppHeadsUp)

        #expect(settingsWereCoalesced)
        #expect(sharedPanelWasPreserved)
        #expect(await [first.value, second.value] == [.capsule, .capsule])
        #expect(panelHarness.panels.count == 1)
    }

    @Test("Cancelled explainer is not persisted and remains eligible")
    func cancelledExplainerRemainsEligible() async {
        let store = FakeHeadsUpAuthorizationStore()
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let coordinator = HeadsUpAuthorizationCoordinator(center: center, store: store)
        var explainerCount = 0

        #expect(await coordinator.selectChannel {
            explainerCount += 1
            return .cancelled
        } == .capsule)
        #expect(store.state == HeadsUpNotificationAuthorizationState())
        #expect(center.authorizationRequestCount == 0)

        #expect(await coordinator.selectChannel {
            explainerCount += 1
            return .useInAppHeadsUp
        } == .capsule)
        #expect(explainerCount == 2)
        #expect(store.state.hasPresentedExplainer)
        #expect(store.state.usesInAppHeadsUp)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("Concurrent selection presents once and persists only after explicit choice")
    func concurrentSelectionDedupe() async {
        let store = FakeHeadsUpAuthorizationStore()
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let gate = HeadsUpNotificationTestGate()
        let explainer = HeadsUpNotificationTestCounter()
        let coordinator = HeadsUpAuthorizationCoordinator(center: center, store: store)

        async let first = coordinator.selectChannel {
            await explainer.increment()
            await gate.wait()
            return .useInAppHeadsUp
        }
        while await explainer.value() == 0 {
            await Task.yield()
        }
        async let second = coordinator.selectChannel {
            await explainer.increment()
            return .continueWithNotifications
        }
        await Task.yield()

        #expect(await explainer.value() == 1)
        #expect(store.state.hasPresentedExplainer == false)
        gate.open()
        #expect(await [first, second] == [.capsule, .capsule])
        #expect(store.state.hasPresentedExplainer)
        #expect(store.state.usesInAppHeadsUp)
        #expect(center.authorizationRequestCount == 0)
    }

    @Test("Unresolved explainer remains eligible after a simulated relaunch")
    func unresolvedRelaunch() async {
        let store = FakeHeadsUpAuthorizationStore()
        let originalCenter = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let gate = HeadsUpNotificationTestGate()
        let explainer = HeadsUpNotificationTestCounter()
        let original = HeadsUpAuthorizationCoordinator(center: originalCenter, store: store)

        async let unresolved = original.selectChannel {
            await explainer.increment()
            await gate.wait()
            return .useInAppHeadsUp
        }
        while await explainer.value() == 0 {
            await Task.yield()
        }
        #expect(store.state.hasPresentedExplainer == false)

        let relaunchedCenter = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
        ])
        let relaunched = HeadsUpAuthorizationCoordinator(center: relaunchedCenter, store: store)
        #expect(await relaunched.selectChannel {
            await explainer.increment()
            return .useInAppHeadsUp
        } == .capsule)
        #expect(await explainer.value() == 2)

        gate.open()
        #expect(await unresolved == .capsule)
        #expect(relaunchedCenter.authorizationRequestCount == 0)
    }
}
