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
    @Test("Accessibility preferences reach both merged phases and every display role")
    func accessibilityPreferencePropagation() throws {
        let scenarios: [(AccessibleBreakPresentation, Bool)] = [
            (.standard, false),
            (.staticPresentation, true),
            (.textOnly, true),
        ]

        for (presentation, expectsStaticModel) in scenarios {
            let preferences = try AccessibilityPreferences(
                presentation: presentation,
                staticOverlayBrightness: 0.61,
                seatedContentFirst: true,
            )
            let harness = try MergedOverlayHarness(
                displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
                accessibilityPreferences: preferences,
            )
            let coordinator = harness.makeCoordinator()

            coordinator.present()

            #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
            #expect(harness.panels.allSatisfy {
                $0.accessibilityPreferences == preferences
            })
            #expect(harness.visualModel.accessibility.staticPresentation == expectsStaticModel)

            harness.visualModel.doneEarly()

            #expect(harness.movementModel.accessibility.staticPresentation == expectsStaticModel)
            #expect(harness.movementModel.choiceOrder == [
                .seated,
                .walkOrWheel,
                .smallSpace,
            ])
            #expect(harness.movementModel.selectedChoice == .walkOrWheel)
            #expect(harness.panels.allSatisfy {
                $0.accessibilityPreferences == preferences
            })
        }
    }

    @Test("Timer announcement Off spans merged phases without hiding state changes")
    func timerAnnouncementsOff() throws {
        let preferences = try AccessibilityPreferences(timerAnnouncements: .none)
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
            accessibilityPreferences: preferences,
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()
        harness.monotonicNow = 11
        harness.fireRefresh()

        #expect(harness.visualAnnouncements.isEmpty)

        harness.visualModel.doneEarly()

        #expect(harness.visualAnnouncements == [.doneEarly])
        #expect(harness.movementAnnouncements.isEmpty)

        harness.movementModel.select(.seated)

        #expect(harness.movementAnnouncements == [.selectionChanged(.seated)])
    }

    @Test("One visual session, scheduler, observer, capture, and activation are shared across displays")
    func sharedVisualSession() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.operations == ["capture", "activate"])
        #expect(harness.panels.map(\.displayID) == [.direct(1), .direct(2)])
        #expect(harness.panels.map(\.role) == [.interactive, .atmosphere])
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
        #expect(visualHarness.panels.filter { !$0.wasDismissed }.isEmpty)
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

    @Test("Restoration waits until every merged display finishes its exit")
    func restorationWaitsForAllPanels() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true), mergedDisplay(2)],
        )
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
        #expect(harness.completionCount == 1)
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
        #expect(harness.completionCount == 0)
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

    @Test("A failed opening write dismisses the merged surface instead of trapping input")
    func openingFailureDismisses() throws {
        let harness = try MergedOverlayHarness(
            displays: [mergedDisplay(1, isMain: true)],
        )
        harness.failNextEvents = [.opened]
        let coordinator = harness.makeCoordinator()

        coordinator.present()

        #expect(harness.visualModel.phase == .ready)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.restoredProcessIdentifiers == [41])
        #expect(harness.refreshScheduleCount == 0)
        #expect(harness.screenObservationCount == 0)
        #expect(!coordinator.isPresenting)
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
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(2)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(3)])
        #expect(harness.operations == ["capture", "activate"])
    }

    @Test("Pointer movement alone does not move the interactive merged surface")
    func noPointerChasing() throws {
        let harness = try MergedOverlayHarness(
            displays: [
                mergedDisplay(1, isMain: true, containsPointer: true),
                mergedDisplay(2),
            ],
        )
        let coordinator = harness.makeCoordinator()
        coordinator.present()

        harness.displays = [
            mergedDisplay(1, isMain: true),
            mergedDisplay(2, containsPointer: true),
        ]
        harness.fireScreenChange()

        let openPanels = harness.panels.filter { !$0.wasClosed }
        #expect(openPanels.filter { $0.role == .interactive }.map(\.displayID) == [.direct(1)])
        #expect(openPanels.filter { $0.role == .atmosphere }.map(\.displayID) == [.direct(2)])
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
        #expect(harness.completionCount == 1)
    }

    @Test("Final merged movement completion excludes position and skip")
    func finalMovementCompletionEligibility() throws {
        let position = try MergedOverlayHarness(displays: [mergedDisplay(1, isMain: true)])
        let positionCoordinator = position.makeCoordinator()
        positionCoordinator.present()
        position.visualModel.doneEarly()
        position.movementModel.positionChanged()
        #expect(position.completionCount == 0)

        let skipped = try MergedOverlayHarness(displays: [mergedDisplay(1, isMain: true)])
        let skippedCoordinator = skipped.makeCoordinator()
        skippedCoordinator.present()
        skipped.visualModel.doneEarly()
        skipped.movementModel.skip()
        #expect(skipped.completionCount == 0)
    }

    @Test("Every final merged movement completion terminal requests the same beat")
    func finalMovementCompletionTerminals() throws {
        let timer = try MergedOverlayHarness(displays: [mergedDisplay(1, isMain: true)])
        let timerCoordinator = timer.makeCoordinator()
        timerCoordinator.present()
        timer.visualModel.doneEarly()
        timer.monotonicNow = 300
        timer.fireRefresh()
        #expect(timer.completionCount == 1)

        let done = try MergedOverlayHarness(displays: [mergedDisplay(1, isMain: true)])
        let doneCoordinator = done.makeCoordinator()
        doneCoordinator.present()
        done.visualModel.doneEarly()
        done.movementModel.doneEarly()
        #expect(done.completionCount == 1)

        let alreadyMoved = try MergedOverlayHarness(displays: [mergedDisplay(1, isMain: true)])
        let alreadyMovedCoordinator = alreadyMoved.makeCoordinator()
        alreadyMovedCoordinator.present()
        alreadyMoved.visualModel.doneEarly()
        alreadyMoved.movementModel.alreadyMoved()
        #expect(alreadyMoved.completionCount == 1)
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
            role: .interactive,
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

    @Test("An atmosphere merged panel stays inert while its field follows the active segment")
    func atmospherePanelContract() throws {
        let panel = MergedPanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            content: .visual(.preview(.ready)),
            role: .atmosphere,
            onCancel: {},
        )
        defer { panel.close() }

        #expect(!panel.canBecomeKey)
        #expect(panel.ignoresMouseEvents)
        #expect(panel.accessibilityChildren()?.isEmpty == true)
        #expect(panel.atmosphereKindForTesting == "visual")

        try panel.update(content: .movement(MovementModel(
            schedule: mergedSchedule(),
            context: .merged,
            now: { 0 },
        )))
        #expect(panel.atmosphereKindForTesting == "movement")

        panel.update(frame: panel.frame, role: .interactive)
        #expect(panel.canBecomeKey)
        #expect(!panel.ignoresMouseEvents)
        #expect(panel.accessibilityChildren() == nil)
    }
}

private func mergedDisplay(
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
    var accessibilityPreferences: AccessibilityPreferences
    var monotonicNow: TimeInterval = 0
    var appIsFrontmost = true
    var operations: [String] = []
    var panels: [TestMergedPanel] = []
    var lifecycle: [MergedLifecycleEvent] = []
    var visualAnnouncements: [VisualResetAnnouncement] = []
    var movementAnnouncements: [MovementAnnouncement] = []
    var restoredProcessIdentifiers: [pid_t] = []
    var refreshScheduleCount = 0
    var refreshCancellationCount = 0
    var screenObservationCount = 0
    var screenCancellationCount = 0
    var completionCount = 0
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

    init(
        displays: [OverlayDisplay],
        accessibilityPreferences: AccessibilityPreferences = .defaults,
    ) throws {
        self.displays = displays
        self.accessibilityPreferences = accessibilityPreferences
        schedule = try mergedSchedule()
    }

    func makeCoordinator() -> MergedOverlayCoordinator {
        MergedOverlayCoordinator(
            policy: .allDisplays,
            visualDurationSeconds: 20,
            movementSchedule: schedule,
            acknowledgementDurationSeconds: 2,
            accessibilityPreferences: accessibilityPreferences,
            now: { self.monotonicNow },
            displays: { self.displays },
            makePanel: {
                display,
                    role,
                    content,
                    accessibilityPreferences,
                    onEntranceSettled,
                    onCancel in
                let panel = TestMergedPanel(
                    displayID: display.id,
                    frame: display.frame,
                    content: content,
                    role: role,
                    accessibilityPreferences: accessibilityPreferences,
                    onEntranceSettled: onEntranceSettled,
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
            onVisualAnnouncement: { self.visualAnnouncements.append($0) },
            onMovementAnnouncement: { self.movementAnnouncements.append($0) },
            onCompletion: { self.completionCount += 1 },
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
    let accessibilityPreferences: AccessibilityPreferences
    private let onCancel: () -> Void
    private let onEntranceSettled: () -> Void
    private(set) var frame: CGRect
    private(set) var wasMadeKey = false
    private(set) var wasClosed = false
    private(set) var wasDismissed = false
    var completesDismissalAutomatically = true
    private var pendingDismissalCompletion: (() -> Void)?
    private(set) var contentHistory: [MergedPanelContent] = []
    private(set) var role: OverlayDisplayRole

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
        role: OverlayDisplayRole,
        accessibilityPreferences: AccessibilityPreferences,
        onEntranceSettled: @escaping () -> Void,
        onCancel: @escaping () -> Void,
    ) {
        self.displayID = displayID
        self.frame = frame
        self.role = role
        self.accessibilityPreferences = accessibilityPreferences
        self.onEntranceSettled = onEntranceSettled
        self.onCancel = onCancel
        contentHistory = [content]
    }

    func present(makeKey: Bool) {
        wasMadeKey = wasMadeKey || makeKey
        if makeKey {
            onEntranceSettled()
        }
    }

    func update(frame: CGRect, role: OverlayDisplayRole) {
        self.frame = frame
        self.role = role
    }

    func update(content: MergedPanelContent) {
        contentHistory.append(content)
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
