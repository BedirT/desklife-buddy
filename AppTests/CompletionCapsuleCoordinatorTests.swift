import AppKit
import CoreGraphics
import Domain
import Testing
@testable import App

@Suite("Completion capsule coordinator")
struct CompletionCapsuleCoordinatorTests {
    @Test("Presentation targets pointer, then main, then first without activating")
    func targetPriority() {
        let screens = [
            completionScreen(1),
            completionScreen(2, isMain: true),
            completionScreen(3),
        ]
        let pointed = CompletionCapsuleHarness(
            screens: screens,
            pointerLocation: CGPoint(x: 250, y: 50),
        )
        #expect(pointed.makeCoordinator().present())
        #expect(pointed.panels.map(\.displayID) == [.direct(3)])
        #expect(pointed.panels[0].presentCount == 1)
        #expect(pointed.scheduleCount == 1)

        let main = CompletionCapsuleHarness(
            screens: screens,
            pointerLocation: CGPoint(x: -100, y: -100),
        )
        #expect(main.makeCoordinator().present())
        #expect(main.panels.map(\.displayID) == [.direct(2)])

        let first = CompletionCapsuleHarness(
            screens: screens.map { completionScreen($0.id.directValue) },
            pointerLocation: CGPoint(x: -100, y: -100),
        )
        #expect(first.makeCoordinator().present())
        #expect(first.panels.map(\.displayID) == [.direct(1)])
    }

    @Test("A stale expiry cannot close a newer completion")
    func staleExpiry() {
        let harness = CompletionCapsuleHarness(
            screens: [completionScreen(1, isMain: true)],
            pointerLocation: .zero,
        )
        let coordinator = harness.makeCoordinator()

        #expect(coordinator.present())
        #expect(coordinator.present())
        #expect(harness.panels.count == 2)
        #expect(harness.panels[0].wasClosed)
        #expect(!harness.panels[1].wasClosed)
        #expect(harness.scheduledDurations == [2, 2])

        harness.fireScheduled(at: 0)
        #expect(!harness.panels[1].wasClosed)

        harness.fireScheduled(at: 1)
        #expect(harness.panels[1].wasClosed)
        #expect(!coordinator.isPresenting)
    }

    @Test("Topology changes retain the chosen display and never chase the pointer")
    func topologyTarget() {
        let harness = CompletionCapsuleHarness(
            screens: [completionScreen(1, isMain: true), completionScreen(2)],
            pointerLocation: CGPoint(x: 150, y: 50),
        )
        let coordinator = harness.makeCoordinator()
        #expect(coordinator.present())
        #expect(harness.panels.last?.displayID == .direct(2))

        harness.pointerLocation = CGPoint(x: 50, y: 50)
        harness.fireScreenChange()
        #expect(harness.panels.count == 1)
        #expect(harness.panels.last?.displayID == .direct(2))

        harness.screens = [completionScreen(1), completionScreen(3, isMain: true)]
        harness.fireScreenChange()
        #expect(harness.panels.count == 2)
        #expect(harness.panels[0].wasClosed)
        #expect(harness.panels.last?.displayID == .direct(1))
    }

    @Test("Suppressed presentation creates no panel, observer, or timer")
    func suppressed() {
        let harness = CompletionCapsuleHarness(
            screens: [completionScreen(1, isMain: true)],
            pointerLocation: .zero,
        )
        harness.shouldPresent = false

        #expect(!harness.makeCoordinator().present())
        #expect(harness.panels.isEmpty)
        #expect(harness.scheduleCount == 0)
        #expect(harness.observationCount == 0)
    }

    @Test("Reduce Motion, Static, and Text only omit the completion beat")
    func accessibilitySuppression() {
        #expect(CompletionCapsulePolicy.allowsPresentation(
            systemReduceMotion: false,
            presentation: .standard,
        ))
        #expect(!CompletionCapsulePolicy.allowsPresentation(
            systemReduceMotion: true,
            presentation: .standard,
        ))
        #expect(!CompletionCapsulePolicy.allowsPresentation(
            systemReduceMotion: false,
            presentation: .staticPresentation,
        ))
        #expect(!CompletionCapsulePolicy.allowsPresentation(
            systemReduceMotion: false,
            presentation: .textOnly,
        ))
    }

    @Test("Native completion panel is decorative and cannot activate")
    func panelContract() {
        let panel = CompletionCapsulePanel(
            displayID: .direct(1),
            frame: CGRect(x: 0, y: 0, width: 120, height: 52),
        )
        defer { panel.close() }

        #expect(!panel.canBecomeKey)
        #expect(!panel.canBecomeMain)
        #expect(panel.ignoresMouseEvents)
        #expect(panel.accessibilityChildren()?.isEmpty == true)
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }
}

private final class CompletionCapsuleHarness {
    var screens: [HeadsUpScreen]
    var pointerLocation: CGPoint
    var shouldPresent = true
    var panels: [TestCompletionCapsulePanel] = []
    var scheduleCount = 0
    var observationCount = 0
    var scheduledDurations: [TimeInterval] = []
    private var scheduled: [() -> Void] = []
    private var screenChange: (() -> Void)?

    init(screens: [HeadsUpScreen], pointerLocation: CGPoint) {
        self.screens = screens
        self.pointerLocation = pointerLocation
    }

    func makeCoordinator() -> CompletionCapsuleCoordinator {
        CompletionCapsuleCoordinator(
            durationSeconds: 2,
            screens: { self.screens },
            pointerLocation: { self.pointerLocation },
            contentSize: { CGSize(width: 44, height: 34) },
            makePanel: { displayID, frame in
                let panel = TestCompletionCapsulePanel(displayID: displayID, frame: frame)
                self.panels.append(panel)
                return panel
            },
            scheduleDismissal: { duration, action in
                self.scheduleCount += 1
                self.scheduledDurations.append(duration)
                self.scheduled.append(action)
                return OverlayCancellation {}
            },
            observeScreenChanges: { action in
                self.observationCount += 1
                self.screenChange = action
                return OverlayCancellation {}
            },
            shouldPresent: { self.shouldPresent },
        )
    }

    func fireScheduled(at index: Int) { scheduled[index]() }
    func fireScreenChange() { screenChange?() }
}

private final class TestCompletionCapsulePanel: CompletionCapsulePanelPresenting {
    let displayID: HeadsUpDisplayID
    private(set) var frame: CGRect
    private(set) var presentCount = 0
    private(set) var wasClosed = false

    init(displayID: HeadsUpDisplayID, frame: CGRect) {
        self.displayID = displayID
        self.frame = frame
    }

    func presentWithoutActivation() { presentCount += 1 }
    func update(frame: CGRect) { self.frame = frame }
    func close() { wasClosed = true }
}

private func completionScreen(_ id: UInt32, isMain: Bool = false) -> HeadsUpScreen {
    HeadsUpScreen(
        id: .direct(id),
        mirrorRootID: .direct(id),
        frame: CGRect(x: CGFloat(id - 1) * 100, y: 0, width: 100, height: 100),
        visibleFrame: CGRect(x: CGFloat(id - 1) * 100, y: 0, width: 100, height: 100),
        safeAreaTopInset: 0,
        auxiliaryTopLeftArea: nil,
        auxiliaryTopRightArea: nil,
        isMain: isMain,
    )
}

private extension HeadsUpDisplayID {
    var directValue: UInt32 {
        guard case let .direct(value) = self else { return 0 }
        return value
    }
}
