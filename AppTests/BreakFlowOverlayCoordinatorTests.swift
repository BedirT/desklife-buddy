import AppKit
import BreakFlow
import CoreGraphics
import Testing
@testable import App

@Suite("Break flow overlay coordinator")
struct BreakFlowOverlayCoordinatorTests {
    @Test("A snooze sheet shares one scoped model across displays and makes one panel key")
    func sharedSnoozeSession() {
        let harness = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true), breakFlowDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()

        coordinator.presentSnooze(scope: .merged)

        #expect(harness.operations == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
        #expect(harness.panels.filter(\.wasMadeKey).map(\.displayID) == [.direct(1)])
        #expect(harness.panels[0].model === harness.panels[1].model)
        #expect(harness.panels[0].model.surface == .snooze(
            scope: .merged,
            calendarEnd: nil,
        ))
        #expect(harness.screenObservationCount == 1)
    }

    @Test("Snooze persistence succeeds before every panel closes and focus restores once")
    func snoozePersistenceHandshake() {
        let harness = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true), breakFlowDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.presentSnooze(scope: .visual)

        harness.panels[1].model.snooze(for: 600)

        #expect(harness.actions == [.snooze(scope: .visual, durationSeconds: 600)])
        #expect(harness.announcements == [.snoozed(minutes: 10)])
        let allPanelsClosed = harness.panels.allSatisfy(\.wasClosed)
        #expect(allPanelsClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.screenCancellationCount == 1)
    }

    @Test("A failed write rejects the action and leaves the same sheet retryable")
    func persistenceFailureRecovery() {
        let harness = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true)],
        )
        harness.failNextActions = [.snooze(scope: .movement, durationSeconds: 300)]
        let coordinator = harness.makeCoordinator()
        coordinator.presentSnooze(scope: .movement)
        let model = harness.panels[0].model

        model.snooze(for: 300)

        #expect(!model.isFinished)
        #expect(!harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers.isEmpty)
        #expect(harness.announcements.isEmpty)

        model.snooze(for: 300)

        #expect(model.isFinished)
        #expect(harness.actions == [
            .snooze(scope: .movement, durationSeconds: 300),
            .snooze(scope: .movement, durationSeconds: 300),
        ])
        #expect(harness.announcements == [.snoozed(minutes: 5)])
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
    }

    @Test("Escape truthfully persists Skip for the explicit scope")
    func escapeMapsToSkip() {
        let harness = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.presentSnooze(scope: .merged)

        harness.panels[0].cancel()

        #expect(harness.actions == [.skip(scope: .merged)])
        #expect(harness.announcements == [.skipped])
        #expect(harness.panels[0].model.isFinished)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
    }

    @Test("Every secondary action announces only its confirmed persisted result")
    func secondaryActionAnnouncements() {
        let pause = BreakFlowOverlayHarness(displays: [breakFlowDisplay(1, isMain: true)])
        let pauseCoordinator = pause.makeCoordinator()
        pauseCoordinator.presentSnooze(scope: .visual)
        pause.panels[0].model.send(.pauseOneHour)

        let notAppropriate = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true)],
        )
        let notAppropriateCoordinator = notAppropriate.makeCoordinator()
        notAppropriateCoordinator.presentSnooze(scope: .movement)
        notAppropriate.panels[0].model.send(.notAppropriate)

        #expect(pause.announcements == [.pausedOneHour])
        #expect(notAppropriate.announcements == [.notedForSession])
    }

    @Test("After meeting stays absent without the optional Calendar integration")
    func calendarBoundaryUnavailable() {
        let withoutCalendar = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true)],
        )
        let withoutCalendarCoordinator = withoutCalendar.makeCoordinator()
        withoutCalendarCoordinator.presentSnooze(scope: .visual)
        withoutCalendar.panels[0].model.snoozeUntilMeetingEnds()
        #expect(withoutCalendar.actions.isEmpty)
        #expect(!withoutCalendar.panels[0].model.isFinished)
    }

    @Test("Display changes retain the active model and keep one reachable key panel")
    func displayReconciliation() {
        let harness = BreakFlowOverlayHarness(
            displays: [breakFlowDisplay(1, isMain: true), breakFlowDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.presentSnooze(scope: .visual)
        let session = harness.panels[0].model

        harness.displays = [breakFlowDisplay(2, isMain: true), breakFlowDisplay(3)]
        harness.fireScreenChange()

        #expect(harness.panels.first { $0.displayID == .direct(1) }?.wasClosed == true)
        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(Set(openPanels.map(\.displayID)) == [.direct(2), .direct(3)])
        #expect(openPanels.allSatisfy { $0.model === session })
        #expect(openPanels.filter(\.wasMadeKey).map(\.displayID).contains(.direct(2)))
        #expect(harness.operations == ["capture", "activate"])
    }
}

@Suite("Break flow panel keyboard contract")
struct BreakFlowPanelTests {
    @Test("The key snooze panel is floating and Escape and Command-period cancel")
    func panelContract() throws {
        var cancelCount = 0
        let panel = BreakFlowPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: .preview(.snooze(scope: .visual, calendarEnd: nil)),
            onCancel: { cancelCount += 1 },
        )
        defer { panel.close() }

        #expect(panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.level == .floating)
        #expect(panel.collectionBehavior.contains(.canJoinAllSpaces))
        #expect(panel.collectionBehavior.contains(.canJoinAllApplications))
        #expect(panel.collectionBehavior.contains(.ignoresCycle))
        #expect(!panel.hidesOnDeactivate)
        #expect(panel.title == "Not a good moment? Snooze or skip.")
        #expect(panel.accessibilityTitle() == "Not a good moment? Snooze or skip.")

        let escape = try #require(breakFlowKeyEvent(keyCode: 53, characters: "\u{1B}"))
        #expect(panel.performKeyEquivalent(with: escape))
        let commandPeriod = try #require(breakFlowKeyEvent(
            keyCode: 47,
            characters: ".",
            modifiers: .command,
        ))
        #expect(panel.performKeyEquivalent(with: commandPeriod))
        #expect(cancelCount == 2)
    }

    @Test("The merged snooze window exposes its scope in the AX title")
    func mergedAccessibilityTitle() {
        let panel = BreakFlowPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            model: .preview(.snooze(scope: .merged, calendarEnd: nil)),
            onCancel: {},
        )
        defer { panel.close() }

        #expect(panel.accessibilityTitle() == "Not a good moment? Snooze or skip. Both are due — one break covers them")
    }
}

private func breakFlowDisplay(
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

private func breakFlowKeyEvent(
    keyCode: UInt16,
    characters: String,
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

private final class BreakFlowOverlayHarness {
    var displays: [OverlayDisplay]
    var appIsFrontmost = true
    var operations: [String] = []
    var panels: [TestBreakFlowPanel] = []
    var actions: [BreakFlowAction] = []
    var announcements: [BreakFlowAnnouncement] = []
    var restoredProcessIdentifiers: [pid_t] = []
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var failNextActions: [BreakFlowAction] = []
    private var screenChangeAction: (() -> Void)?

    init(displays: [OverlayDisplay]) {
        self.displays = displays
    }

    func makeCoordinator() -> BreakFlowOverlayCoordinator {
        BreakFlowOverlayCoordinator(
            policy: .allDisplays,
            snoozeDurationsSeconds: [300, 600, 900],
            displays: { self.displays },
            makePanel: { display, model, onCancel in
                let panel = TestBreakFlowPanel(
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
            observeScreenChanges: { action in
                self.screenObservationCount += 1
                self.screenChangeAction = action
                return OverlayCancellation { self.screenCancellationCount += 1 }
            },
            onAction: { action, completion in
                self.actions.append(action)
                if let index = self.failNextActions.firstIndex(of: action) {
                    self.failNextActions.remove(at: index)
                    completion(.failure(BreakFlowOverlayTestFailure.requested))
                } else {
                    completion(.success(()))
                }
            },
            onAnnouncement: { self.announcements.append($0) },
        )
    }

    func fireScreenChange() {
        screenChangeAction?()
    }
}

private enum BreakFlowOverlayTestFailure: Error {
    case requested
}

private final class TestBreakFlowPanel: BreakFlowPanelPresenting {
    let displayID: OverlayDisplayID
    let model: BreakFlowModel
    private let onCancel: () -> Void
    private(set) var frame: CGRect
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        model: BreakFlowModel,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.frame = frame
        self.model = model
        self.onCancel = onCancel
    }

    func present(makeKey: Bool) {
        wasMadeKey = wasMadeKey || makeKey
    }

    func update(frame: CGRect) {
        self.frame = frame
    }

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
