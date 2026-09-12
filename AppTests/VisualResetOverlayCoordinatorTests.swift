import AppKit
import CoreGraphics
import Domain
import Testing
import VisualReset
@testable import App

@Suite("Visual reset overlay coordinator")
struct VisualResetOverlayCoordinatorTests {
    @Test("Each presentation mode reaches the shared model and every display role")
    func accessibilityPresentationPropagation() throws {
        let scenarios: [(AccessibleBreakPresentation, Bool)] = [
            (.standard, false),
            (.staticPresentation, true),
            (.textOnly, true),
        ]

        for (presentation, expectsStaticModel) in scenarios {
            let preferences = try AccessibilityPreferences(
                presentation: presentation,
                staticOverlayBrightness: 0.72,
            )
            let harness = OverlayHarness(
                displays: [display(1, isMain: true), display(2)],
                accessibilityPreferences: preferences,
            )
            let coordinator = harness.makeCoordinator()

            coordinator.present()

            #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
            #expect(harness.panels.allSatisfy {
                $0.accessibilityPreferences == preferences
            })
            #expect(harness.panels[0].model.accessibility.staticPresentation == expectsStaticModel)
        }
    }

    @Test("Timer announcement Off suppresses progress but preserves declared state changes")
    func timerAnnouncementsOff() throws {
        let preferences = try AccessibilityPreferences(timerAnnouncements: .none)
        let harness = OverlayHarness(
            displays: [display(1, isMain: true)],
            accessibilityPreferences: preferences,
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()
        harness.monotonicNow = 11
        harness.fireRefresh()

        #expect(harness.announcements.isEmpty)

        harness.panels[0].model.skip()

        #expect(harness.announcements == [.skipped])
    }

    @Test("All-display planning collapses mirrors and keys the pointer display")
    func allDisplayPlanning() {
        let displays = [
            display(1, isMain: true),
            display(2, mirrorRootID: 1),
            display(3, containsPointer: true),
        ]

        let plan = OverlayDisplayPlan.resolve(displays, policy: .allDisplays)

        #expect(plan.displays.map(\.id) == [.direct(1), .direct(3)])
        #expect(plan.assignments.map(\.role) == [.atmosphere, .interactive])
        #expect(plan.interactiveDisplayID == .direct(3))
    }

    @Test("Primary-only planning retains the canonical main display")
    func primaryOnlyPlanning() {
        let displays = [
            display(10, containsPointer: true),
            display(20, isMain: true),
            display(21, mirrorRootID: 20),
        ]

        let plan = OverlayDisplayPlan.resolve(displays, policy: .primaryOnly)

        #expect(plan.displays.map(\.id) == [.direct(20)])
        #expect(plan.assignments.map(\.role) == [.interactive])
        #expect(plan.interactiveDisplayID == .direct(20))
    }

    @Test("A screen without a direct display ID remains eligible")
    func fallbackDisplayPlanning() {
        let token = NSObject()
        let fallbackID = OverlayDisplayID.fallback(ObjectIdentifier(token))
        let fallback = OverlayDisplay(
            id: fallbackID,
            mirrorRootID: fallbackID,
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            isMain: true,
            containsPointer: false,
        )

        let plan = OverlayDisplayPlan.resolve([fallback], policy: .allDisplays)

        #expect(plan.displays.map(\.id) == [fallbackID])
        #expect(plan.assignments.map(\.role) == [.interactive])
        #expect(plan.interactiveDisplayID == fallbackID)
    }

    @Test("An existing interactive display stays selected when only the pointer moves")
    func stableInteractiveSelection() {
        let plan = OverlayDisplayPlan.resolve(
            [display(1, isMain: true), display(2, containsPointer: true)],
            policy: .allDisplays,
            preferredInteractiveDisplayID: .direct(1),
        )

        #expect(plan.interactiveDisplayID == .direct(1))
        #expect(plan.role(for: .direct(1)) == .interactive)
        #expect(plan.role(for: .direct(2)) == .atmosphere)
    }

    @Test("A missing interactive display falls back to the pre-activation main, then first")
    func interactiveFallbackOrder() {
        let preActivationMain = OverlayDisplayPlan.resolve(
            [display(2, isMain: true), display(3, containsPointer: true)],
            policy: .allDisplays,
            preferredInteractiveDisplayID: .direct(1),
            fallbackInteractiveDisplayID: .direct(2),
        )
        let first = OverlayDisplayPlan.resolve(
            [display(3), display(4, containsPointer: true)],
            policy: .allDisplays,
            preferredInteractiveDisplayID: .direct(1),
            fallbackInteractiveDisplayID: .direct(2),
        )

        #expect(preActivationMain.interactiveDisplayID == .direct(2))
        #expect(first.interactiveDisplayID == .direct(3))
    }

    @Test("A preferred mirrored member keeps its surviving canonical root interactive")
    func mirroredInteractiveReassignment() {
        let plan = OverlayDisplayPlan.resolve(
            [
                display(1),
                display(2, mirrorRootID: 1),
                display(3, isMain: true, containsPointer: true),
            ],
            policy: .allDisplays,
            preferredInteractiveDisplayID: .direct(2),
            fallbackInteractiveDisplayID: .direct(3),
        )

        #expect(plan.displays.map(\.id) == [.direct(1), .direct(3)])
        #expect(plan.interactiveDisplayID == .direct(1))
        #expect(plan.role(for: .direct(1)) == .interactive)
    }

    @Test("Live topology observation includes screen and active Space changes until cancellation")
    func liveTopologyObservationSources() {
        let applicationNotifications = NotificationCenter()
        let workspaceNotifications = NotificationCenter()
        var reconciliationCount = 0
        let cancellation = VisualResetOverlayCoordinator.observeScreenChanges(
            applicationNotifications: applicationNotifications,
            workspaceNotifications: workspaceNotifications,
            screenParametersObject: nil,
        ) {
            reconciliationCount += 1
        }

        applicationNotifications.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
        workspaceNotifications.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
        )
        #expect(reconciliationCount == 2)

        cancellation.cancel()
        applicationNotifications.post(
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil,
        )
        workspaceNotifications.post(
            name: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
        )
        #expect(reconciliationCount == 2)
    }

    @Test("Presentation captures before activation and shares one session across every panel")
    func presentation() {
        let harness = OverlayHarness(displays: [display(1, isMain: true), display(2)])
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.operations.prefix(2) == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
        #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
        #expect(harness.panels.filter(\.wasMadeKey).map(\.displayID) == [.direct(1)])
        #expect(harness.panels[0].model === harness.panels[1].model)
        #expect(harness.lifecycle == [.opened])
        #expect(harness.refreshScheduleCount == 1)
        #expect(harness.screenObservationCount == 1)
    }

    @Test("The visual countdown starts in the committed open action")
    func countdownStartsWithoutEntranceSettlement() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        harness.automaticallySettlesEntrance = false
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.monotonicNow = 1.1
        harness.fireRefresh()
        #expect(harness.panels[0].model.remainingSeconds == 19)
    }

    @Test("Only the interactive display routes Escape and restores once")
    func onlyInteractiveEscapeClosesAll() {
        let harness = OverlayHarness(displays: [display(1, isMain: true), display(2)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.panels[1].cancel()
        #expect(harness.lifecycle == [.opened])
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        harness.panels[0].cancel()

        #expect(harness.lifecycle == [.opened, .skipped])
        #expect(!harness.panels.contains { !$0.wasClosed })
        #expect(harness.panels.filter { !$0.wasDismissed }.isEmpty)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshCancellationCount == 1)
        #expect(harness.screenCancellationCount == 1)
        #expect(harness.operations.suffix(2) == ["announce.skipped", "restore"])
    }

    @Test("Restoration waits until every display finishes its exit")
    func restorationWaitsForAllPanels() {
        let harness = OverlayHarness(displays: [display(1, isMain: true), display(2)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.panels.forEach { $0.completesDismissalAutomatically = false }

        harness.panels[0].cancel()

        #expect(harness.panels.filter { !$0.wasDismissed }.isEmpty)
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.panels[0].finishDismissal()
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.panels[1].finishDismissal()
        #expect(harness.restoredProcessIdentifiers == [41])
    }

    @Test("Duplicate presentation is idempotent")
    func duplicatePresentation() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        let coordinator = harness.makeCoordinator()

        coordinator.present()
        coordinator.present()

        #expect(harness.panels.count == 1)
        #expect(harness.lifecycle == [.opened])
        #expect(harness.refreshScheduleCount == 1)
    }

    @Test("A newly frontmost app is never displaced during dismissal")
    func noFocusStealing() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.appIsFrontmost = false

        harness.panels[0].cancel()

        #expect(harness.restoredProcessIdentifiers.isEmpty)
    }

    @Test("Display changes preserve the shared session and leave one reachable key panel")
    func displayReconciliation() {
        let harness = OverlayHarness(displays: [display(1, isMain: true), display(2)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        let session = harness.panels[0].model

        harness.displays = [display(2, isMain: true), display(3)]
        harness.fireScreenChange()

        #expect(harness.panels.first(where: { $0.displayID == .direct(1) })?.wasClosed == true)
        #expect(harness.panels.last?.displayID == .direct(3))
        #expect(harness.panels.last?.model === session)
        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(Set(openPanels.map(\.displayID)) == [.direct(2), .direct(3)])
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(2)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(3)])
    }

    @Test("Screen reconciliation does not chase a moved pointer while the interactive display remains")
    func screenReconciliationDoesNotChasePointer() {
        let harness = OverlayHarness(displays: [
            display(1, isMain: true, containsPointer: true),
            display(2),
        ])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.displays = [display(1, isMain: true), display(2, containsPointer: true)]
        harness.fireScreenChange()

        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(1)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(2)])
    }

    @Test("A temporarily empty display plan closes stale panels without restarting the session")
    func temporarilyEmptyDisplayPlan() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        let session = harness.panels[0].model

        harness.displays = []
        harness.fireScreenChange()

        #expect(harness.panels[0].wasClosed)
        #expect(harness.lifecycle == [.opened])

        harness.displays = [display(2, isMain: true)]
        harness.fireScreenChange()

        #expect(harness.panels.count == 2)
        #expect(harness.panels[1].model === session)
        #expect(!harness.panels[1].wasClosed)
        #expect(harness.lifecycle == [.opened])
    }

    @Test("Releasing an active coordinator closes panels and cancels its sources")
    func releaseCleanup() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        var coordinator: VisualResetOverlayCoordinator? = harness.makeCoordinator()
        weak let releasedCoordinator = coordinator
        coordinator?.present()

        coordinator = nil

        #expect(releasedCoordinator == nil)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.refreshCancellationCount == 1)
        #expect(harness.screenCancellationCount == 1)
        #expect(harness.lifecycle == [.opened])
        #expect(harness.restoredProcessIdentifiers.isEmpty)
    }

    @Test("One refresh source drives deadline completion for the shared model")
    func timerCompletion() {
        let harness = OverlayHarness(displays: [display(1, isMain: true), display(2)])
        let coordinator = harness.makeCoordinator(durationSeconds: 20)
        coordinator.present()

        harness.monotonicNow = 20
        harness.fireRefresh()

        #expect(harness.lifecycle == [.opened, .timerFinished])
        #expect(!harness.panels.contains { !$0.wasClosed })
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.completionCount == 1)
        #expect(harness.operations.suffix(2) == ["restore", "completion"])
    }

    @Test("Only successful completed visual resets request completion")
    func completionEligibility() {
        let done = OverlayHarness(displays: [display(1, isMain: true)])
        let doneCoordinator = done.makeCoordinator()
        doneCoordinator.present()
        done.panels[0].model.doneEarly()
        #expect(done.completionCount == 1)
        #expect(done.lifecycle == [.opened, .doneEarly])

        let skipped = OverlayHarness(displays: [display(1, isMain: true)])
        let skippedCoordinator = skipped.makeCoordinator()
        skippedCoordinator.present()
        skipped.panels[0].model.skip()
        #expect(skipped.completionCount == 0)
        #expect(skipped.lifecycle == [.opened, .skipped])

        let failed = OverlayHarness(displays: [display(1, isMain: true)])
        failed.failNextActions = [.doneEarly]
        let failedCoordinator = failed.makeCoordinator()
        failedCoordinator.present()
        failed.panels[0].model.doneEarly()
        #expect(failed.completionCount == 0)
        #expect(!failed.panels[0].wasClosed)
    }

    @Test("A failed opening write dismisses the surface instead of trapping input")
    func lifecycleFailureRecovery() {
        let harness = OverlayHarness(displays: [display(1, isMain: true)])
        harness.failNextActions = [.opened]
        let coordinator = harness.makeCoordinator()

        coordinator.present()
        #expect(harness.panels[0].model.phase == .ready)
        #expect(harness.announcements.isEmpty)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshScheduleCount == 0)
        #expect(harness.screenObservationCount == 0)
        #expect(!coordinator.isPresenting)
    }

    @Test("Lifecycle persistence operations cannot overtake an earlier event")
    func lifecycleSerialization() async {
        let queue = VisualResetLifecycleQueue()
        var recorded: [VisualResetLifecycleEvent] = []

        queue.enqueue(.opened) { event in
            await Task.yield()
            recorded.append(event)
        }
        queue.enqueue(.skipped) { event in recorded.append(event) }
        let failure = await queue.drain()

        #expect(recorded == [.opened, .skipped])
        #expect(failure == nil)
    }

    @Test("A failed opening write blocks that session's terminal write and a later open retries")
    func lifecycleFailureOrdering() async {
        enum Failure: Error {
            case requested
        }
        let queue = VisualResetLifecycleQueue()
        var attempted: [VisualResetLifecycleEvent] = []

        queue.enqueue(.opened) { event in
            attempted.append(event)
            throw Failure.requested
        }
        queue.enqueue(.skipped) { event in attempted.append(event) }
        let firstFailure = await queue.drain()

        #expect(firstFailure is Failure)
        #expect(attempted == [.opened])

        queue.enqueue(.opened) { event in attempted.append(event) }
        queue.enqueue(.timerFinished) { event in attempted.append(event) }
        let retryFailure = await queue.drain()

        #expect(retryFailure == nil)
        #expect(attempted == [.opened, .opened, .timerFinished])
    }

    @Test("A failed terminal write can be retried without poisoning the lifecycle queue")
    func lifecycleTerminalRetry() async {
        enum Failure: Error {
            case requested
        }
        let queue = VisualResetLifecycleQueue()
        var attempted: [VisualResetLifecycleEvent] = []
        var failuresRemaining = 1

        queue.enqueue(.opened) { event in attempted.append(event) }
        queue.enqueue(.doneEarly) { event in
            attempted.append(event)
            if failuresRemaining > 0 {
                failuresRemaining -= 1
                throw Failure.requested
            }
        }
        let firstFailure = await queue.drain()

        #expect(firstFailure is Failure)
        #expect(attempted == [.opened, .doneEarly])

        queue.enqueue(.doneEarly) { event in attempted.append(event) }
        let retryFailure = await queue.drain()

        #expect(retryFailure == nil)
        #expect(attempted == [.opened, .doneEarly, .doneEarly])
    }

    @Test("The live refresh scheduler advances on the application run loop")
    func liveRefreshScheduler() {
        var tickCount = 0
        let cancellation = VisualResetOverlayCoordinator.liveRefreshScheduler {
            tickCount += 1
        }

        RunLoop.main.run(until: Date().addingTimeInterval(0.12))
        cancellation.cancel()

        #expect(tickCount >= 2)
    }
}

@Suite("Visual reset panel keyboard contract")
struct VisualResetPanelTests {
    @Test("A break panel can become key but never main and uses the floating level")
    func panelContract() {
        let panel = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: .preview(.ready),
            role: .interactive,
            onCancel: {},
        )
        defer { panel.close() }

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.canJoinAllApplications))
        #expect(panel.collectionBehavior.contains(.ignoresCycle))
        #expect(!panel.hidesOnDeactivate)
        #expect(!panel.isFloatingPanel)
        #expect(!panel.showsDefaultActionForTesting)

        panel.becomeKey()
        #expect(panel.showsDefaultActionForTesting)

        panel.resignKey()
        #expect(!panel.showsDefaultActionForTesting)
    }

    @Test("An atmosphere panel ignores input and contributes no accessibility children")
    func atmospherePanelContract() {
        let panel = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: .preview(.ready),
            role: .atmosphere,
            onCancel: {},
        )
        defer { panel.close() }

        #expect(!panel.canBecomeKey)
        #expect(panel.ignoresMouseEvents)
        #expect(panel.accessibilityChildren()?.isEmpty == true)

        panel.update(frame: panel.frame, role: .interactive)
        #expect(panel.canBecomeKey)
        #expect(!panel.ignoresMouseEvents)
        #expect(panel.accessibilityChildren() == nil)
    }

    @Test("Escape and Command-period route through the immediate cancel seam")
    func immediateCancel() throws {
        var cancelCount = 0
        let panel = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: .preview(.ready),
            role: .interactive,
            onCancel: { cancelCount += 1 },
        )
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
        let commandPeriod = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: ".",
            charactersIgnoringModifiers: ".",
            isARepeat: false,
            keyCode: 47,
        ))
        #expect(panel.performKeyEquivalent(with: commandPeriod))
        #expect(cancelCount == 2)
    }

    @Test("Return reaches the hosted model immediately")
    func hostedReturnKey() throws {
        let clock = VisualResetPanelTestClock()
        let model = VisualResetModel(durationSeconds: 20, now: { clock.value })
        let panel = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        defer { panel.close() }
        model.open()

        let returnKey = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36,
        ))
        #expect(panel.performKeyEquivalent(with: returnKey))
        #expect(model.phase == .finished(.doneEarly))

        let modifiedReturn = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: .command,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36,
        ))
        #expect(!panel.performKeyEquivalent(with: modifiedReturn))
    }

    @Test("Return keyDown reaches the hosted model immediately")
    func hostedReturnKeyDown() throws {
        let clock = VisualResetPanelTestClock()
        let model = VisualResetModel(durationSeconds: 20, now: { clock.value })
        let panel = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        defer { panel.close() }
        model.open()

        let returnKey = try #require(NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\r",
            charactersIgnoringModifiers: "\r",
            isARepeat: false,
            keyCode: 36,
        ))
        panel.keyDown(with: returnKey)
        #expect(model.phase == .finished(.doneEarly))
    }

    @Test("Only the panel receiving key-window lifecycle exposes the initial default action")
    func keyPanelDefaultAction() {
        let model = VisualResetModel.preview(.ready)
        let first = VisualResetPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        let second = VisualResetPanel(
            displayID: .direct(2),
            frame: CGRect(x: 800, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        defer {
            first.close()
            second.close()
        }

        first.resignKey()
        second.becomeKey()

        #expect(!first.showsDefaultActionForTesting)
        #expect(second.showsDefaultActionForTesting)

        second.resignKey()
        first.becomeKey()

        #expect(first.showsDefaultActionForTesting)
        #expect(!second.showsDefaultActionForTesting)
    }
}

private func display(
    _ id: CGDirectDisplayID,
    mirrorRootID: CGDirectDisplayID? = nil,
    isMain: Bool = false,
    containsPointer: Bool = false,
) -> OverlayDisplay {
    OverlayDisplay(
        id: .direct(id),
        mirrorRootID: .direct(mirrorRootID ?? id),
        frame: CGRect(x: Int(id) * 100, y: 0, width: 100, height: 100),
        isMain: isMain,
        containsPointer: containsPointer,
    )
}

private final class OverlayHarness {
    var displays: [OverlayDisplay]
    var accessibilityPreferences: AccessibilityPreferences
    var monotonicNow: TimeInterval = 0
    var appIsFrontmost = true
    var operations: [String] = []
    var panels: [TestVisualResetPanel] = []
    var lifecycle: [VisualResetAction] = []
    var announcements: [VisualResetAnnouncement] = []
    var failNextActions: [VisualResetAction] = []
    var restoredProcessIdentifiers: [pid_t] = []
    var refreshScheduleCount = 0
    var refreshCancellationCount = 0
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var completionCount = 0
    var automaticallySettlesEntrance = true
    private var refreshAction: (() -> Void)?
    private var screenChangeAction: (() -> Void)?

    init(
        displays: [OverlayDisplay],
        accessibilityPreferences: AccessibilityPreferences = .defaults,
    ) {
        self.displays = displays
        self.accessibilityPreferences = accessibilityPreferences
    }

    func makeCoordinator(durationSeconds: TimeInterval = 20) -> VisualResetOverlayCoordinator {
        VisualResetOverlayCoordinator(
            policy: .allDisplays,
            durationSeconds: durationSeconds,
            accessibilityPreferences: accessibilityPreferences,
            now: { self.monotonicNow },
            displays: { self.displays },
            makePanel: {
                display,
                    role,
                    model,
                    accessibilityPreferences,
                    onEntranceSettled,
                    onCancel in
                let panel = TestVisualResetPanel(
                    displayID: display.id,
                    frame: display.frame,
                    model: model,
                    role: role,
                    accessibilityPreferences: accessibilityPreferences,
                    onEntranceSettled: onEntranceSettled,
                    automaticallySettlesEntrance: self.automaticallySettlesEntrance,
                    onCancel: onCancel,
                )
                self.panels.append(panel)
                return panel
            },
            captureFrontmostProcessIdentifier: {
                self.operations.append("capture")
                return 41
            },
            activate: { self.operations.append("activate") },
            isAppFrontmost: { self.appIsFrontmost },
            restore: {
                self.operations.append("restore")
                self.restoredProcessIdentifiers.append($0)
            },
            scheduleRefresh: { action in
                self.refreshScheduleCount += 1
                self.refreshAction = action
                return OverlayCancellation { self.refreshCancellationCount += 1 }
            },
            observeScreenChanges: { action in
                self.screenObservationCount += 1
                self.screenChangeAction = action
                return OverlayCancellation { self.screenCancellationCount += 1 }
            },
            onLifecycle: { action, completion in
                self.lifecycle.append(action)
                if let index = self.failNextActions.firstIndex(of: action) {
                    self.failNextActions.remove(at: index)
                    completion(.failure(VisualResetOverlayTestFailure.requested))
                } else {
                    completion(.success(()))
                }
            },
            onAnnouncement: {
                self.announcements.append($0)
                self.operations.append("announce.\($0.operationName)")
            },
            onCompletion: {
                self.operations.append("completion")
                self.completionCount += 1
            },
        )
    }

    func fireRefresh() {
        refreshAction?()
    }

    func fireScreenChange() {
        screenChangeAction?()
    }
}

private enum VisualResetOverlayTestFailure: Error {
    case requested
}

private final class VisualResetPanelTestClock {
    var value: TimeInterval = 0
}

private extension VisualResetAnnouncement {
    var operationName: String {
        switch self {
        case .opened: "opened"
        case .tenSecondsRemaining: "tenSeconds"
        case .finished: "finished"
        case .doneEarly: "doneEarly"
        case .skipped: "skipped"
        }
    }
}

private final class TestVisualResetPanel: VisualResetPanelPresenting {
    let displayID: OverlayDisplayID
    let model: VisualResetModel
    let accessibilityPreferences: AccessibilityPreferences
    private let onCancel: () -> Void
    private let onEntranceSettled: () -> Void
    private let automaticallySettlesEntrance: Bool
    private(set) var frame: CGRect
    private(set) var role: OverlayDisplayRole
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false
    private(set) var wasDismissed = false
    var completesDismissalAutomatically = true
    private var pendingDismissalCompletion: (() -> Void)?

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: VisualResetModel,
        role: OverlayDisplayRole,
        accessibilityPreferences: AccessibilityPreferences,
        onEntranceSettled: @escaping () -> Void,
        automaticallySettlesEntrance: Bool,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.frame = frame
        self.model = model
        self.role = role
        self.accessibilityPreferences = accessibilityPreferences
        self.onEntranceSettled = onEntranceSettled
        self.automaticallySettlesEntrance = automaticallySettlesEntrance
        self.onCancel = onCancel
    }

    func present(makeKey: Bool) {
        wasMadeKey = makeKey
        if makeKey, automaticallySettlesEntrance {
            onEntranceSettled()
        }
    }

    func update(frame: CGRect, role: OverlayDisplayRole) {
        self.frame = frame
        self.role = role
    }

    func close() {
        wasClosed = true
    }

    func dismiss(onClosed: @escaping () -> Void) {
        wasDismissed = true
        guard completesDismissalAutomatically else {
            pendingDismissalCompletion = onClosed
            return
        }
        close()
        onClosed()
    }

    func finishDismissal() {
        let completion = pendingDismissalCompletion
        pendingDismissalCompletion = nil
        close()
        completion?()
    }

    func makeKey() {
        wasMadeKey = true
    }

    func cancel() {
        guard role == .interactive else { return }
        onCancel()
    }

    func settleEntrance() {
        onEntranceSettled()
    }
}
