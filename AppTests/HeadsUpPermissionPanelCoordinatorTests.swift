import AppKit
import DesignSystem
import HeadsUp
import Testing
@testable import App

@Suite("Heads-up permission explainer panel coordinator")
struct HeadsUpPermissionPanelCoordinatorTests {
    @Test("Native PM-01 closes before Notification Center authorization begins")
    func nativeExplainerClosesBeforeAuthorizationRequest() async {
        let center = FakeHeadsUpNotificationCenter(settings: [
            .init(authorizationStatus: .notDetermined, alertsEnabled: false),
            .init(authorizationStatus: .authorized, alertsEnabled: true),
        ])
        let authorization = HeadsUpAuthorizationCoordinator(
            center: center,
            store: FakeHeadsUpAuthorizationStore(),
        )
        let panelHarness = HeadsUpPermissionPanelHarness()
        center.onEvent = { panelHarness.events.append($0) }
        let permission = panelHarness.makeCoordinator()
        let selection = Task {
            await authorization.selectChannel { await permission.present() }
        }
        await panelHarness.waitForPanel()

        panelHarness.panel?.send(.continueToSystemRequest)

        #expect(await selection.value == .notification)
        #expect(panelHarness.events == ["settings", "present", "close", "request", "settings"])
    }

    @Test("Continue closes the explainer before returning and resolves only once")
    func continueClosesBeforeReturning() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()

        let task = Task {
            let result = await coordinator.present()
            harness.events.append("return")
            return result
        }
        await harness.waitForPanel()
        harness.events.append("continue")
        harness.panel?.send(.continueToSystemRequest)
        harness.panel?.send(.useInAppHeadsUp)

        #expect(await task.value == .continueWithNotifications)
        #expect(harness.events == ["present", "continue", "close", "return"])
        #expect(harness.panel?.closeCount == 1)
    }

    @Test("In-app choice and Escape both resolve to the in-app channel")
    func inAppAndEscape() async {
        let directHarness = HeadsUpPermissionPanelHarness()
        let direct = directHarness.makeCoordinator()
        async let directResult = direct.present()
        await directHarness.waitForPanel()
        directHarness.panel?.send(.useInAppHeadsUp)

        #expect(await directResult == .useInAppHeadsUp)

        let escapeHarness = HeadsUpPermissionPanelHarness()
        let escape = escapeHarness.makeCoordinator()
        async let escapeResult = escape.present()
        await escapeHarness.waitForPanel()
        escapeHarness.panel?.send(.useInAppHeadsUp)

        #expect(await escapeResult == .useInAppHeadsUp)
        #expect(escapeHarness.panel?.closeCount == 1)
    }

    @Test("Concurrent callers share one native panel and one pending selection")
    func concurrentCallsCoalesce() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()

        async let first = coordinator.present()
        async let second = coordinator.present()
        await harness.waitForPanel()

        #expect(harness.makePanelCount == 1)
        #expect(harness.panel?.presentCount == 1)
        harness.panel?.send(.useInAppHeadsUp)

        #expect(await [first, second] == [.useInAppHeadsUp, .useInAppHeadsUp])
        #expect(harness.panel?.closeCount == 1)
    }

    @Test("External close and coordinator teardown safely choose in-app")
    func closeAndTeardown() async {
        let closeHarness = HeadsUpPermissionPanelHarness()
        let closeCoordinator = closeHarness.makeCoordinator()
        async let closeResult = closeCoordinator.present()
        await closeHarness.waitForPanel()
        closeHarness.panel?.simulateExternalClose()

        #expect(await closeResult == .useInAppHeadsUp)
        #expect(closeHarness.panel?.closeCount == 1)
        #expect(closeHarness.panel?.closeInvocationCount == 1)

        let teardownHarness = HeadsUpPermissionPanelHarness()
        let teardownCoordinator = teardownHarness.makeCoordinator()
        async let teardownResult = teardownCoordinator.present()
        await teardownHarness.waitForPanel()
        teardownCoordinator.tearDown()

        #expect(await teardownResult == .cancelled)
        #expect(teardownHarness.panel?.closeCount == 1)
    }

    @Test("A completed presentation can be presented again")
    func subsequentPresentation() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()

        async let first = coordinator.present()
        await harness.waitForPanel(count: 1)
        harness.panels[0].send(.useInAppHeadsUp)
        #expect(await first == .useInAppHeadsUp)

        async let second = coordinator.present()
        await harness.waitForPanel(count: 2)
        harness.panels[1].send(.continueToSystemRequest)

        #expect(await second == .continueWithNotifications)
        #expect(harness.makePanelCount == 2)
    }

    @Test("Teardown after resolution cannot poison the next presentation")
    func postResolutionTeardownDoesNotPoisonNextPresentation() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()
        let first = Task { await coordinator.present() }
        await harness.waitForPanel(count: 1)

        harness.panels[0].send(.useInAppHeadsUp)
        coordinator.tearDown()
        #expect(await first.value == .useInAppHeadsUp)

        let second = Task { await coordinator.present() }
        for _ in 0 ..< 20 where harness.panels.count < 2 {
            await Task.yield()
        }
        guard harness.panels.count == 2 else {
            _ = await second.value
            Issue.record("The next presentation resolved from stale teardown state")
            return
        }
        harness.panels[1].send(.continueToSystemRequest)

        #expect(await second.value == .continueWithNotifications)
    }

    @Test("Selected text scale reaches the detached native host")
    func selectedTextScaleIsInjected() async {
        let harness = HeadsUpPermissionPanelHarness(textScale: .largest)
        let coordinator = harness.makeCoordinator()
        async let result = coordinator.present()
        await harness.waitForPanel()

        #expect(harness.textScales == [.largest])
        harness.panel?.send(.useInAppHeadsUp)
        #expect(await result == .useInAppHeadsUp)
    }

    @Test("Cancelling the final waiter safely closes and resolves the presentation")
    func finalWaiterCancellation() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()
        let task = Task { await coordinator.present() }
        await harness.waitForPanel()

        task.cancel()
        for _ in 0 ..< 20 where harness.panel?.closeCount == 0 {
            await Task.yield()
        }
        let didCloseFromCancellation = harness.panel?.closeCount == 1
        if !didCloseFromCancellation {
            coordinator.tearDown()
        }

        #expect(didCloseFromCancellation)
        #expect(await task.value == .cancelled)
    }

    @Test("Cancelling one coalesced waiter leaves the shared presentation available")
    func oneWaiterCancellationKeepsSharedPresentation() async {
        let harness = HeadsUpPermissionPanelHarness()
        let coordinator = harness.makeCoordinator()
        let first = Task { await coordinator.present() }
        let second = Task { await coordinator.present() }
        await harness.waitForPanel()

        first.cancel()
        for _ in 0 ..< 20 {
            await Task.yield()
        }

        #expect(harness.panel?.closeCount == 0)
        harness.panel?.send(.useInAppHeadsUp)
        #expect(await first.value == .useInAppHeadsUp)
        #expect(await second.value == .useInAppHeadsUp)
        #expect(harness.panel?.closeCount == 1)
    }
}

@Suite("Heads-up permission native panel")
struct HeadsUpPermissionPanelTests {
    @Test("Panel is a key floating explainer with neutral native chrome")
    func panelContract() {
        let panel = HeadsUpPermissionPanel(onAction: { _ in }, onClose: {})
        defer { panel.close() }

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.level == .floating)
        #expect(!panel.styleMask.contains(.nonactivatingPanel))
        #expect(!panel.hidesOnDeactivate)
        #expect(panel.contentViewController != nil)
        #expect(panel.title == HeadsUpPermissionPresentation.inContextExplainer.title)
        #expect(
            panel.accessibilityTitle() == HeadsUpPermissionPresentation.inContextExplainer.title,
        )
        #expect(panel.accessibilityIdentifier() == "headsUp.permission.explainer.panel")
    }

    @Test("Large text uses the verified permission layout")
    func largeTextLayout() {
        let panel = HeadsUpPermissionPanel(
            textScale: .largest,
            onAction: { _ in },
            onClose: {},
        )
        defer { panel.close() }

        #expect(HeadsUpPermissionPanel.contentSize(for: .largest) == CGSize(width: 680, height: 520))
        #expect(panel.contentViewController?.view.frame.size == CGSize(width: 680, height: 520))
    }

    @Test("Native close notifies its owner exactly once")
    func nativeCloseIsOneShot() {
        var closeCount = 0
        let panel = HeadsUpPermissionPanel(
            onAction: { _ in },
            onClose: { closeCount += 1 },
        )

        panel.close()
        panel.close()

        #expect(closeCount == 1)
    }

    @Test("Native Escape uses the Feature cancel action")
    func nativeEscape() throws {
        var actions: [HeadsUpPermissionAction] = []
        let panel = HeadsUpPermissionPanel(onAction: { actions.append($0) }, onClose: {})
        defer { panel.close() }
        let escape = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{1B}",
            charactersIgnoringModifiers: "\u{1B}",
            isARepeat: false,
            keyCode: 53,
        ))

        #expect(panel.performKeyEquivalent(with: escape))
        #expect(actions == [.useInAppHeadsUp])
    }
}

final class HeadsUpPermissionPanelHarness {
    private let textScale: DSTextScale
    private(set) var panels: [FakeHeadsUpPermissionPanel] = []
    private(set) var textScales: [DSTextScale] = []
    var panel: FakeHeadsUpPermissionPanel? { panels.last }
    var makePanelCount: Int { panels.count }
    var events: [String] = []

    init(textScale: DSTextScale = .standard) {
        self.textScale = textScale
    }

    func makeCoordinator() -> HeadsUpPermissionPanelCoordinator {
        let makePanel: HeadsUpPermissionPanelCoordinator.PanelFactory = { [weak self] textScale, onAction, onClose in
            self?.textScales.append(textScale)
            let panel = FakeHeadsUpPermissionPanel(
                onAction: onAction,
                onClose: onClose,
                onPresent: { self?.events.append("present") },
                onCloseEvent: { self?.events.append("close") },
            )
            self?.panels.append(panel)
            return panel
        }
        return HeadsUpPermissionPanelCoordinator(
            textScale: textScale,
            makePanel: makePanel,
        )
    }

    func waitForPanel(count: Int = 1) async {
        while panels.count < count {
            await Task.yield()
        }
    }
}

final class FakeHeadsUpPermissionPanel: HeadsUpPermissionPanelPresenting {
    private let onAction: (HeadsUpPermissionAction) -> Void
    private let onClose: () -> Void
    private let onPresent: () -> Void
    private let onCloseEvent: () -> Void
    private(set) var presentCount = 0
    private(set) var closeCount = 0
    private(set) var closeInvocationCount = 0

    init(
        onAction: @escaping (HeadsUpPermissionAction) -> Void,
        onClose: @escaping () -> Void,
        onPresent: @escaping () -> Void,
        onCloseEvent: @escaping () -> Void,
    ) {
        self.onAction = onAction
        self.onClose = onClose
        self.onPresent = onPresent
        self.onCloseEvent = onCloseEvent
    }

    func present() {
        presentCount += 1
        onPresent()
    }

    func close() {
        closeInvocationCount += 1
        guard closeCount == 0 else { return }
        closeCount += 1
        onCloseEvent()
        onClose()
    }

    func send(_ action: HeadsUpPermissionAction) {
        onAction(action)
    }

    func simulateExternalClose() {
        close()
    }
}

final class GatedAuthorizationNotificationCenter: HeadsUpNotificationCenterClient {
    private var settingsContinuations: [CheckedContinuation<HeadsUpNotificationSettings, Never>] = []
    private(set) var settingsCallCount = 0

    func notificationSettings() async throws -> HeadsUpNotificationSettings {
        settingsCallCount += 1
        return await withCheckedContinuation { settingsContinuations.append($0) }
    }

    func releaseSettings(call: Int) {
        settingsContinuations[call].resume(returning: .init(
            authorizationStatus: .notDetermined,
            alertsEnabled: false,
        ))
    }

    func waitForSettingsCalls(count: Int) async {
        while settingsCallCount < count {
            await Task.yield()
        }
    }

    func requestAuthorization(options _: HeadsUpNotificationAuthorizationOptions) async throws -> Bool { true }
    func add(_: HeadsUpNotificationRequest) async throws {}
    func pendingRequestIdentifiers() async throws -> [String] { [] }
    func deliveredRequestIdentifiers() async throws -> [String] { [] }
    func removePendingRequestIdentifiers(_: [String]) {}
    func removeDeliveredRequestIdentifiers(_: [String]) {}
    func registerCategories(_: [HeadsUpNotificationCategory]) {}
}

func settleConcurrentTasks() async {
    for _ in 0 ..< 20 {
        await Task.yield()
    }
}
