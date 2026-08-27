import AppKit
import CoreGraphics
import Domain
import Movement
import Testing
@testable import App

@Suite("Movement overlay coordinator")
struct MovementOverlayCoordinatorTests {
    @Test("Automatic presentation shares one non-explicit session across all displays")
    func automaticPresentation() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.operations.prefix(2) == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
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

    @Test("Escape from any display closes every panel and restores once")
    func escapeClosesAll() throws {
        let harness = try MovementOverlayHarness(
            displays: [movementDisplay(1, isMain: true), movementDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.panels[1].cancel()
        harness.panels[0].cancel()

        #expect(harness.lifecycle == [.opened, .skipped])
        #expect(!harness.panels.contains { !$0.wasClosed })
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshCancellationCount == 1)
        #expect(harness.screenCancellationCount == 1)
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
        #expect(openPanels.filter(\.wasMadeKey).map(\.displayID) == [.direct(2)])
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

    @Test("Failed lifecycle commits keep the surface retryable and defer terminal claims")
    func lifecycleFailureRecovery() throws {
        let harness = try MovementOverlayHarness(displays: [movementDisplay(1, isMain: true)])
        harness.failNextActions = [.opened, .selectedDuration(300), .doneEarly]
        let coordinator = harness.makeCoordinator()

        coordinator.present(selectedDurationSeconds: 300)
        #expect(harness.panels[0].model.phase == .ready)
        #expect(harness.announcements.isEmpty)
        #expect(!harness.panels[0].wasClosed)

        coordinator.present(selectedDurationSeconds: 300)
        #expect(harness.panels[0].model.phase == .running)
        #expect(harness.lifecycle == [
            .opened,
            .opened,
            .selectedDuration(300),
        ])
        #expect(harness.announcements == [.opened(durationSeconds: 300)])

        coordinator.present(selectedDurationSeconds: 300)
        #expect(harness.lifecycle == [
            .opened,
            .opened,
            .selectedDuration(300),
            .selectedDuration(300),
        ])

        harness.panels[0].model.doneEarly()
        #expect(harness.panels[0].model.phase == .running)
        #expect(!harness.panels[0].wasClosed)
        #expect(!harness.announcements.contains(.doneEarly))

        harness.panels[0].model.doneEarly()
        #expect(harness.panels[0].wasClosed)
        #expect(harness.announcements.last == .doneEarly)
        #expect(harness.restoredProcessIdentifiers == [41])
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
        #expect(!harness.panels[0].wasClosed)

        coordinator.present()
        harness.completeNextLifecycle(.success(()))
        #expect(harness.panels[0].model.phase == .running)
        #expect(harness.announcements == [.opened(durationSeconds: 300)])
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
            onCancel: {},
        )
        let second = MovementPanel(
            displayID: .direct(2),
            frame: CGRect(x: 800, y: 0, width: 800, height: 600),
            model: model,
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

    @Test("Escape and Command-period route through the immediate cancel seam")
    func immediateCancel() throws {
        var cancelCount = 0
        let panel = try MovementPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: MovementModel(schedule: movementSchedule(), now: { 0 }),
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
) -> OverlayDisplay {
    OverlayDisplay(
        id: .direct(id),
        mirrorRootID: .direct(id),
        frame: CGRect(x: Int(id) * 100, y: 0, width: 100, height: 100),
        isMain: isMain,
        containsPointer: false,
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
    var failNextActions: [MovementAction] = []
    var defersLifecycleCompletions = false
    var pendingLifecycleActions: [MovementAction] {
        pendingLifecycleCompletions.map(\.action)
    }
    let schedule: OpportunitySchedule
    private var refreshAction: (() -> Void)?
    private var screenChangeAction: (() -> Void)?
    private var pendingLifecycleCompletions: [PendingMovementLifecycleCompletion] = []

    init(displays: [OverlayDisplay]) throws {
        self.displays = displays
        schedule = try movementSchedule()
    }

    func makeCoordinator() -> MovementOverlayCoordinator {
        MovementOverlayCoordinator(
            policy: .allDisplays,
            schedule: schedule,
            now: { self.monotonicNow },
            displays: { self.displays },
            makePanel: { display, model, onCancel in
                let panel = TestMovementPanel(
                    displayID: display.id,
                    frame: display.frame,
                    model: model,
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
    let onCancel: () -> Void
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: MovementModel,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.model = model
        self.onCancel = onCancel
    }

    func present(makeKey: Bool) {
        wasMadeKey = wasMadeKey || makeKey
    }

    func update(frame: CGRect) {}

    func close() {
        wasClosed = true
    }

    func makeKey() {
        wasMadeKey = true
    }

    func cancel() {
        onCancel()
    }
}
