import AppKit
import CoreGraphics
import Domain
import Movement
import Testing
@testable import App

@Suite("Movement overlay coordinator")
struct MovementOverlayCoordinatorTests {
    @Test("Presentation, brightness, and seated-first ordering reach every display role")
    func accessibilityPreferencePropagation() throws {
        let scenarios: [(AccessibleBreakPresentation, Bool)] = [
            (.standard, false),
            (.staticPresentation, true),
            (.textOnly, true),
        ]

        for (presentation, expectsStaticModel) in scenarios {
            let preferences = try AccessibilityPreferences(
                presentation: presentation,
                staticOverlayBrightness: 0.68,
                seatedContentFirst: true,
            )
            let harness = try MovementOverlayHarness(
                displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
                accessibilityPreferences: preferences,
            )
            let coordinator = harness.makeCoordinator()

            coordinator.present()

            #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
            #expect(harness.panels.allSatisfy {
                $0.accessibilityPreferences == preferences
            })
            #expect(harness.panels[0].model.accessibility.staticPresentation == expectsStaticModel)
            #expect(harness.panels[0].model.choiceOrder == [
                .seated,
                .walkOrWheel,
                .smallSpace,
            ])
            #expect(harness.panels[0].model.selectedChoice == .walkOrWheel)
        }
    }

    @Test("Timer announcement Off suppresses progress but preserves movement state changes")
    func timerAnnouncementsOff() throws {
        let preferences = try AccessibilityPreferences(timerAnnouncements: .none)
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true)],
            accessibilityPreferences: preferences,
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()
        harness.monotonicNow = 241
        harness.fireRefresh()

        #expect(harness.announcements.isEmpty)

        harness.panels[0].model.select(.seated)

        #expect(harness.announcements == [.selectionChanged(.seated)])
    }

    @Test("Automatic presentation shares one non-explicit session across all displays")
    func automaticPresentation() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.operations.prefix(2) == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
        #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
        #expect(harness.panels.filter(\.wasMadeKey).map(\.displayID) == [.direct(1)])
        #expect(harness.panels[0].model === harness.panels[1].model)
        #expect(harness.lifecycle == [.opened])
        #expect(harness.announcements == [.opened(durationSeconds: 300)])
        #expect(harness.refreshScheduleCount == 1)
        #expect(harness.screenObservationCount == 1)
    }

    @Test("Menu duration entries are explicit and quick entry announces two minutes")
    func explicitDurationEntries() throws {
        let recommended = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let recommendedCoordinator = recommended.makeCoordinator()
        recommendedCoordinator.present(selectedDurationSeconds: 300)

        #expect(recommended.lifecycle == [.opened, .selectedDuration(300)])
        #expect(recommended.announcements == [.opened(durationSeconds: 300)])

        let quick = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let quickCoordinator = quick.makeCoordinator()
        quickCoordinator.present(selectedDurationSeconds: 120)

        #expect(quick.lifecycle == [.opened, .selectedDuration(120)])
        #expect(quick.announcements == [.opened(durationSeconds: 120)])
        #expect(quick.panels[0].model.remainingSeconds == 120)
    }

    @Test("Only the interactive display routes Escape and restores once")
    func onlyInteractiveEscapeClosesAll() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.panels[1].cancel()
        #expect(harness.lifecycle == [.opened])
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        harness.panels[0].cancel()

        #expect(harness.lifecycle == [.opened, .skipped])
        #expect(!harness.panels.contains { !$0.wasClosed })
        #expect(harness.panels.allSatisfy { $0.wasDismissed })
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshCancellationCount == 1)
        #expect(harness.screenCancellationCount == 1)
    }

    @Test("Restoration waits until every movement display finishes its exit")
    func restorationWaitsForAllPanels() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.panels.forEach { $0.completesDismissalAutomatically = false }

        harness.panels[0].cancel()

        #expect(harness.panels.allSatisfy { $0.wasDismissed })
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.panels[0].finishDismissal()
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.panels[1].finishDismissal()
        #expect(harness.restoredProcessIdentifiers == [41])
    }

    @Test("Selection stays live while terminal declarations dismiss the shared surface")
    func selectionAndTerminalActions() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.panels[0].model.select(.smallSpace)
        #expect(!harness.panels[0].wasClosed)
        #expect(harness.lifecycle == [.opened])

        harness.panels[0].model.alreadyMoved()

        #expect(harness.lifecycle == [.opened, .alreadyMoved])
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.completionCount == 1)
    }

    @Test("One refresh source drives deadline completion for the shared model")
    func timerCompletion() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.monotonicNow = 300
        harness.fireRefresh()

        #expect(harness.lifecycle == [.opened, .timerFinished])
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.completionCount == 1)
    }

    @Test("Only completed movement terminals request completion")
    func completionEligibility() throws {
        let done = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let doneCoordinator = done.makeCoordinator()
        doneCoordinator.present()
        done.panels[0].model.doneEarly()
        #expect(done.completionCount == 1)

        let position = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let positionCoordinator = position.makeCoordinator()
        positionCoordinator.present()
        position.panels[0].model.positionChanged()
        #expect(position.completionCount == 0)

        let skipped = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let skippedCoordinator = skipped.makeCoordinator()
        skippedCoordinator.present()
        skipped.panels[0].model.skip()
        #expect(skipped.completionCount == 0)
    }

    @Test("Display changes preserve the shared session and one reachable key panel")
    func displayReconciliation() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        let session = harness.panels[0].model

        harness.displays = [movementDisplay(2, isMain: true), movementDisplay(3)]
        harness.fireScreenChange()

        #expect(harness.panels.first(where: { $0.displayID == .direct(1) })?.wasClosed == true)
        #expect(harness.panels.last?.model === session)
        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(Set(openPanels.map(\.displayID)) == [.direct(2), .direct(3)])
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(2)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(3)])
    }

    @Test("Pointer movement alone does not move the interactive movement surface")
    func noPointerChasing() throws {
        let harness = try MovementOverlayHarness(displays: [
            movementDisplay(1, isMain: true, containsPointer: true),
            movementDisplay(2),
        ])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.displays = [
            movementDisplay(1, isMain: true),
            movementDisplay(2, containsPointer: true),
        ]
        harness.fireScreenChange()

        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(1)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(2)])
    }

    @Test("Lifecycle persistence operations stay ordered and allow explicit retries after failure")
    func lifecycleQueue() async {
        enum Failure: Error { case requested }
        let queue = MovementLifecycleQueue()
        var attempted: [MovementLifecycleEvent] = []

        queue.enqueue(.opened) { event in
            attempted.append(event)
            throw Failure.requested
        }
        queue.enqueue(.skipped) { event in attempted.append(event) }
        let firstFailure = await queue.drain()

        #expect(firstFailure == nil)
        #expect(attempted == [.opened, .skipped])

        queue.enqueue(.opened) { event in attempted.append(event) }
        queue.enqueue(.selectedDuration(300)) { event in attempted.append(event) }
        queue.enqueue(.doneEarly) { event in attempted.append(event) }
        let retryFailure = await queue.drain()

        #expect(retryFailure == nil)
        #expect(attempted == [
            .opened,
            .skipped,
            .opened,
            .selectedDuration(300),
            .doneEarly,
        ])
    }

    @Test("A failed opening commit dismisses the movement surface instead of trapping input")
    func lifecycleFailureRecovery() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        harness.failNextActions = [.opened]
        let coordinator = harness.makeCoordinator()

        coordinator.present(selectedDurationSeconds: 300)
        #expect(harness.panels[0].model.phase == .ready)
        #expect(harness.announcements.isEmpty)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshScheduleCount == 0)
        #expect(harness.screenObservationCount == 0)
        #expect(!coordinator.isPresenting)
    }

    @Test("An open failure invalidates a terminal queued before its acknowledgement")
    func openingFailureWithPendingTerminal() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        harness.defersLifecycleCompletions = true
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.panels[0].model.skip()

        #expect(harness.panels[0].model.phase == .finished(.skipped))
        #expect(harness.pendingLifecycleActions == [.opened, .skipped])

        harness.completeNextLifecycle(.failure(MovementOverlayTestFailure.requested))
        #expect(harness.panels[0].model.phase == .ready)
        harness.completeNextLifecycle(.failure(MovementOverlayTestFailure.requested))
        #expect(harness.panels[0].model.phase == .ready)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(!coordinator.isPresenting)
    }

    @Test("A quick menu command applies its requested duration to an existing session")
    func existingSessionQuickEntry() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        coordinator.present(selectedDurationSeconds: 120)

        #expect(harness.panels[0].model.selectedDurationSeconds == 120)
        #expect(harness.lifecycle == [.opened, .selectedDuration(120)])
    }
}

@Suite("Movement panel keyboard contract")
struct MovementPanelTests {
    @Test("Only a key panel presents the initial default focus")
    func keyPanelFocus() throws {
        let schedule = try movementSchedule()
        let model = MovementModel(schedule: schedule, now: { 0 })
        let first = MovementPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        let second = MovementPanel(
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

    @Test("An atmosphere movement panel ignores input and accessibility")
    func atmospherePanelContract() throws {
        let panel = try MovementPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: MovementModel(schedule: movementSchedule(), now: { 0 }),
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
        let panel = try MovementPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: MovementModel(schedule: movementSchedule(), now: { 0 }),
            role: .interactive,
            onCancel: { cancelCount += 1 },
        )
        defer { panel.close() }

        let escape = try #require(keyEvent(characters: "\u{1B}", keyCode: 53))
        #expect(panel.performKeyEquivalent(with: escape))
        let commandPeriod = try #require(keyEvent(
            characters: ".",
            keyCode: 47,
            modifiers: .command,
        ))
        #expect(panel.performKeyEquivalent(with: commandPeriod))
        #expect(cancelCount == 2)
    }

    @Test("Printed selection and quick keys reach the hosted model after the guard")
    func hostedSelectionKeys() throws {
        let clock = MovementPanelTestClock()
        var actions: [MovementAction] = []
        let model = try MovementModel(
            schedule: movementSchedule(),
            now: { clock.value },
            onAction: { actions.append($0) },
        )
        let panel = MovementPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: model,
            role: .interactive,
            onCancel: {},
        )
        defer { panel.close() }
        model.open()
        clock.value = 0.8

        for (character, keyCode) in [("2", 19), ("3", 20), ("1", 18), ("q", 12)] {
            let event = try #require(keyEvent(characters: character, keyCode: UInt16(keyCode)))
            #expect(panel.performKeyEquivalent(with: event))
        }

        #expect(model.selectedChoice == .walkOrWheel)
        #expect(model.selectedDurationSeconds == 120)
        #expect(actions == [.opened, .selectedDuration(120)])
    }

    @Test("Printed terminal keys reach the hosted model and keep the immediate pointer guard")
    func hostedTerminalKeys() throws {
        for (character, keyCode, expected) in [
            ("\r", UInt16(36), MovementTerminalAction.doneEarly),
            ("a", UInt16(0), .alreadyMoved),
            ("p", UInt16(35), .positionChanged),
        ] {
            let clock = MovementPanelTestClock()
            let model = try MovementModel(schedule: movementSchedule(), now: { clock.value })
            let panel = MovementPanel(
                displayID: .direct(1),
                frame: CGRect(x: 0, y: 0, width: 800, height: 600),
                model: model,
                role: .interactive,
                onCancel: {},
            )
            defer { panel.close() }
            model.open()

            let guardedEvent = try #require(keyEvent(characters: character, keyCode: keyCode))
            #expect(panel.performKeyEquivalent(with: guardedEvent))
            #expect(model.phase == .running)

            clock.value = 0.8
            #expect(panel.performKeyEquivalent(with: guardedEvent))
            #expect(model.phase == .finished(expected))
        }
    }
}

private func movementDisplay(
    _ id: CGDirectDisplayID,
    isMain: Bool = false,
    containsPointer: Bool = false,
) -> OverlayDisplay {
    OverlayDisplay(
        id: .direct(id),
        mirrorRootID: .direct(id),
        frame: CGRect(x: Int(id) * 100, y: 0, width: 100, height: 100),
        isMain: isMain,
        containsPointer: containsPointer,
    )
}

private func movementSchedule() throws -> OpportunitySchedule {
    try OpportunitySchedule(
        softDueSeconds: 3000,
        targetSeconds: 3600,
        latestPreferredSeconds: 4200,
        durationOptionsSeconds: [300, 120],
    )
}

private func keyEvent(
    characters: String,
    keyCode: UInt16,
    modifiers: NSEvent.ModifierFlags = [],
) -> NSEvent? {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode,
    )
}

private final class MovementOverlayHarness {
    var displays: [OverlayDisplay]
    var accessibilityPreferences: AccessibilityPreferences
    var monotonicNow: TimeInterval = 0
    var appIsFrontmost = true
    var operations: [String] = []
    var panels: [TestMovementPanel] = []
    var lifecycle: [MovementAction] = []
    var announcements: [MovementAnnouncement] = []
    var restoredProcessIdentifiers: [pid_t] = []
    var refreshScheduleCount = 0
    var refreshCancellationCount = 0
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var completionCount = 0
    var failNextActions: [MovementAction] = []
    var defersLifecycleCompletions = false
    var pendingLifecycleActions: [MovementAction] {
        pendingLifecycleCompletions.map(\.action)
    }

    let schedule: OpportunitySchedule
    private var refreshAction: (() -> Void)?
    private var screenChangeAction: (() -> Void)?
    private var pendingLifecycleCompletions: [PendingMovementLifecycleCompletion] = []

    init(
        displays: [OverlayDisplay],
        accessibilityPreferences: AccessibilityPreferences = .defaults,
    ) throws {
        self.displays = displays
        self.accessibilityPreferences = accessibilityPreferences
        schedule = try movementSchedule()
    }

    func makeCoordinator() -> MovementOverlayCoordinator {
        MovementOverlayCoordinator(
            policy: .allDisplays,
            schedule: schedule,
            accessibilityPreferences: accessibilityPreferences,
            now: { self.monotonicNow },
            displays: { self.displays },
            makePanel: { display, role, model, accessibilityPreferences, onCancel in
                let panel = TestMovementPanel(
                    displayID: display.id,
                    frame: display.frame,
                    model: model,
                    role: role,
                    accessibilityPreferences: accessibilityPreferences,
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
            restore: { self.restoredProcessIdentifiers.append($0) },
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
                if self.defersLifecycleCompletions {
                    self.pendingLifecycleCompletions.append(.init(
                        action: action,
                        completion: completion,
                    ))
                } else if let index = self.failNextActions.firstIndex(of: action) {
                    self.failNextActions.remove(at: index)
                    completion(.failure(MovementOverlayTestFailure.requested))
                } else {
                    completion(.success(()))
                }
            },
            onAnnouncement: { self.announcements.append($0) },
            onCompletion: { self.completionCount += 1 },
        )
    }

    func fireRefresh() {
        refreshAction?()
    }

    func fireScreenChange() {
        screenChangeAction?()
    }

    func completeNextLifecycle(_ result: Result<Void, any Error>) {
        guard !pendingLifecycleCompletions.isEmpty else { return }
        pendingLifecycleCompletions.removeFirst().completion(result)
    }
}

private struct PendingMovementLifecycleCompletion {
    let action: MovementAction
    let completion: (Result<Void, any Error>) -> Void
}

private enum MovementOverlayTestFailure: Error {
    case requested
}

private final class MovementPanelTestClock {
    var value: TimeInterval = 0
}

private final class TestMovementPanel: MovementPanelPresenting {
    let displayID: OverlayDisplayID
    let model: MovementModel
    let accessibilityPreferences: AccessibilityPreferences
    let onCancel: () -> Void
    private(set) var role: OverlayDisplayRole
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false
    private(set) var wasDismissed = false
    var completesDismissalAutomatically = true
    private var pendingDismissalCompletion: (() -> Void)?

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: MovementModel,
        role: OverlayDisplayRole,
        accessibilityPreferences: AccessibilityPreferences,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.model = model
        self.role = role
        self.accessibilityPreferences = accessibilityPreferences
        self.onCancel = onCancel
    }

    func present(makeKey: Bool) {
        wasMadeKey = wasMadeKey || makeKey
    }

    func update(frame: CGRect, role: OverlayDisplayRole) {
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
}
