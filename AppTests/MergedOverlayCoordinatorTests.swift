import AppKit
import BreakFlow
import CoreGraphics
import Domain
import Movement
import Testing
import VisualReset
@testable import App

@Suite("Merged overlay coordinator")
struct MergedOverlayCoordinatorTests {
    @Test("One visual session, scheduler, observer, capture, and activation are shared across displays")
    func sharedVisualSession() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.operations == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
        #expect(harness.panels.filter(\.wasMadeKey).map(\.displayID) == [.direct(1)])
        #expect(harness.panels[0].visualModel === harness.panels[1].visualModel)
        #expect(harness.lifecycle == [.opened])
        #expect(harness.refreshScheduleCount == 1)
        #expect(harness.screenObservationCount == 1)
    }

    @Test("A confirmed visual timer swaps existing panels to one merged movement session")
    func visualTimerAdvancesInPlace() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        let originalPanels = harness.panels

        harness.monotonicNow = 20
        harness.fireRefresh()

        #expect(harness.lifecycle == [.opened, .visualTimerFinished])
        #expect(harness.panels.count == 2)
        #expect(harness.panels[0] === originalPanels[0])
        #expect(harness.panels[1] === originalPanels[1])
        #expect(harness.panels[0].movementModel === harness.panels[1].movementModel)
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        #expect(harness.operations == ["capture", "activate"])
        #expect(harness.refreshScheduleCount == 1)
        #expect(harness.screenObservationCount == 1)
    }

    @Test("Done early advances the visual segment while Escape skips only the active segment")
    func activeSegmentEscape() throws {
        let visualHarness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        let visualCoordinator = visualHarness.makeCoordinator()
        visualCoordinator.present()
        visualHarness.panels[0].cancel()

        #expect(visualHarness.lifecycle == [.opened, .skipped])
        #expect(visualHarness.restoredProcessIdentifiers == [41])

        let movementHarness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        let movementCoordinator = movementHarness.makeCoordinator()
        movementCoordinator.present()
        movementHarness.visualModel.doneEarly()
        movementHarness.panels[0].cancel()

        #expect(movementHarness.lifecycle == [.opened, .doneEarly, .skipped])
        #expect(movementHarness.restoredProcessIdentifiers == [41])
    }

    @Test("Movement duration selection remains live and a terminal action restores once")
    func movementSelectionAndTerminal() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.visualModel.doneEarly()
        let movementModel = try #require(harness.panels[0].movementModel)

        movementModel.selectQuickDuration()

        #expect(movementModel.selectedDurationSeconds == 120)
        #expect(!harness.panels[0].wasClosed)
        #expect(harness.lifecycle == [.opened, .doneEarly, .selectedDuration(120)])

        movementModel.alreadyMoved()

        #expect(harness.lifecycle == [
            .opened,
            .doneEarly,
            .selectedDuration(120),
            .alreadyMoved,
        ])
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshCancellationCount == 1)
        #expect(harness.screenCancellationCount == 1)
    }

    @Test("Visual-only persistence swaps to passive acknowledgement without another lifecycle fact")
    func visualOnlyAcknowledgement() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.visualModel.doneEarly()
        let originalPanels = harness.panels

        harness.movementModel.justTheVisualOne()

        #expect(harness.lifecycle == [.opened, .doneEarly, .visualOnly])
        #expect(harness.panels[0] === originalPanels[0])
        #expect(harness.panels[1] === originalPanels[1])
        #expect(harness.panels[0].acknowledgementModel === harness.panels[1].acknowledgementModel)
        #expect(harness.panels.allSatisfy { !$0.wasClosed })
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.monotonicNow = 1.9
        harness.fireRefresh()
        #expect(harness.panels.allSatisfy { !$0.wasClosed })

        harness.monotonicNow = 2
        harness.fireRefresh()

        #expect(harness.lifecycle == [.opened, .doneEarly, .visualOnly])
        #expect(harness.panels.map(\.wasClosed) == [true, true])
        #expect(harness.restoredProcessIdentifiers == [41])
    }

    @Test("A failed visual-only write rejects the terminal state and remains retryable")
    func visualOnlyFailure() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.visualModel.doneEarly()
        harness.failNextEvents = [.visualOnly]

        harness.movementModel.justTheVisualOne()

        #expect(harness.movementModel.phase == .running)
        #expect(harness.panels[0].acknowledgementModel == nil)
        #expect(!harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.movementModel.justTheVisualOne()

        #expect(harness.lifecycle.suffix(2) == [.visualOnly, .visualOnly])
        #expect(harness.panels[0].acknowledgementModel != nil)
    }

    @Test("Screen reconciliation retains the current phase and shared model")
    func screenReconciliation() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.visualModel.doneEarly()
        let session = harness.movementModel

        harness.displays = [mergedDisplay(2, isMain: true), mergedDisplay(3)]
        harness.fireScreenChange()

        #expect(harness.panels.first { $0.displayID == .direct(1) }?.wasClosed == true)
        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(Set(openPanels.map(\.displayID)) == [.direct(2), .direct(3)])
        #expect(openPanels.allSatisfy { $0.movementModel === session })
        #expect(openPanels.filter(\.wasMadeKey).map(\.displayID).contains(.direct(2)))
        #expect(harness.operations == ["capture", "activate"])
    }

    @Test("Failed movement persistence rejects the exact action without dismissing")
    func movementFailure() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()
        harness.visualModel.doneEarly()
        harness.failNextEvents = [.alreadyMoved]

        harness.movementModel.alreadyMoved()

        #expect(harness.movementModel.phase == .running)
        #expect(!harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers.isEmpty)

        harness.movementModel.alreadyMoved()

        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
    }
}

@Suite("Merged panel content and focus contract")
struct MergedPanelTests {
    @Test("The same key panel carries default focus from visual into movement")
    func focusAcrossContentSwap() throws {
        let schedule = try mergedSchedule()
        let panel = MergedPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            content: .visual(.preview(.ready)),
            onCancel: {},
        )
        defer { panel.close() }

        panel.becomeKey()
        #expect(panel.showsDefaultActionForTesting)

        panel.update(content: .movement(MovementModel(
            schedule: schedule,
            context: .merged,
            now: { 0 },
        )))

        #expect(panel.showsDefaultActionForTesting)
        panel.resignKey()
        #expect(!panel.showsDefaultActionForTesting)
    }
}

private func mergedDisplay(
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

private func mergedSchedule() throws -> OpportunitySchedule {
    try OpportunitySchedule(
        softDueSeconds: 3000,
        targetSeconds: 3600,
        latestPreferredSeconds: 4200,
        durationOptionsSeconds: [300, 120],
    )
}

private final class MergedOverlayHarness {
    var displays: [OverlayDisplay]
    var monotonicNow: TimeInterval = 0
    var appIsFrontmost = true
    var operations: [String] = []
    var panels: [TestMergedPanel] = []
    var lifecycle: [MergedLifecycleEvent] = []
    var restoredProcessIdentifiers: [pid_t] = []
    var refreshScheduleCount = 0
    var refreshCancellationCount = 0
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var failNextEvents: [MergedLifecycleEvent] = []
    let schedule: OpportunitySchedule
    private var refreshAction: (() -> Void)?
    private var screenChangeAction: (() -> Void)?

    var visualModel: VisualResetModel {
        panels.compactMap(\.visualModel).last!
    }

    var movementModel: MovementModel {
        panels.compactMap(\.movementModel).last!
    }

    var acknowledgementModel: BreakFlowModel {
        panels.compactMap(\.acknowledgementModel).last!
    }

    init(displays: [OverlayDisplay]) throws {
        self.displays = displays
        schedule = try mergedSchedule()
    }

    func makeCoordinator() -> MergedOverlayCoordinator {
        MergedOverlayCoordinator(
            policy: .allDisplays,
            visualDurationSeconds: 20,
            movementSchedule: schedule,
            acknowledgementDurationSeconds: 2,
            now: { self.monotonicNow },
            displays: { self.displays },
            makePanel: { display, content, onCancel in
                let panel = TestMergedPanel(
                    displayID: display.id,
                    frame: display.frame,
                    content: content,
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
            onLifecycle: { event, completion in
                self.lifecycle.append(event)
                if let index = self.failNextEvents.firstIndex(of: event) {
                    self.failNextEvents.remove(at: index)
                    completion(.failure(MergedOverlayTestFailure.requested))
                } else {
                    completion(.success(()))
                }
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

private enum MergedOverlayTestFailure: Error {
    case requested
}

private final class TestMergedPanel: MergedPanelPresenting {
    let displayID: OverlayDisplayID
    private let onCancel: () -> Void
    private(set) var frame: CGRect
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false
    private(set) var contentHistory: [MergedPanelContent] = []

    var visualModel: VisualResetModel? {
        guard case let .visual(model) = contentHistory.last else { return nil }
        return model
    }

    var movementModel: MovementModel? {
        guard case let .movement(model) = contentHistory.last else { return nil }
        return model
    }

    var acknowledgementModel: BreakFlowModel? {
        guard case let .acknowledgement(model) = contentHistory.last else { return nil }
        return model
    }

    init(
        displayID: OverlayDisplayID,
        frame: CGRect,
        content: MergedPanelContent,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.frame = frame
        self.onCancel = onCancel
        contentHistory = [content]
    }

    func present(makeKey: Bool) {
        wasMadeKey = wasMadeKey || makeKey
    }

    func update(frame: CGRect) {
        self.frame = frame
    }

    func update(content: MergedPanelContent) {
        contentHistory.append(content)
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
