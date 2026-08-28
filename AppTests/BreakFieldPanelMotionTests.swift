import AppKit
import DesignSystem
import Testing
@testable import App

@Suite("Break field panel motion")
struct BreakFieldPanelMotionTests {
    @Test("Standard presentation shows the final field without a compositor transition")
    func standardProfile() {
        let profile = BreakFieldPanelMotionMode.standard.profile

        #expect(profile.enterDuration == 0)
        #expect(profile.exitDuration == 0)
        #expect(profile.initialAlpha == 1)
        #expect(profile.transitionStyle == .instant)
        #expect(!profile.isAnimated)
    }

    @Test("Reduce Motion uses the same immediate presentation")
    func reducedProfile() {
        let profile = BreakFieldPanelMotionMode.reduced.profile

        #expect(profile.enterDuration == 0)
        #expect(profile.exitDuration == 0)
        #expect(profile.initialAlpha == 1)
        #expect(profile.transitionStyle == .instant)
        #expect(!profile.isAnimated)
    }

    @Test("Static presentation has no app motion")
    func staticProfile() {
        let mode = BreakFieldPanelMotionMode.resolve(
            staticPresentation: true,
            reduceMotion: true,
        )
        let profile = mode.profile

        #expect(mode == .staticPresentation)
        #expect(!profile.isAnimated)
        #expect(profile.initialAlpha == 1)
        #expect(profile.transitionStyle == .instant)
    }

    @Test("Presenting a break hides the Dock until the panel closes")
    func dockSuppressionLifecycle() {
        let dockVisibility = TestBreakPresentationDockController()
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.breakFieldMotionMode = .staticPresentation
        panel.dockVisibilityController = dockVisibility

        panel.presentBreakField(makeKey: false)
        panel.presentBreakField(makeKey: false)
        #expect(dockVisibility.beginCount == 1)

        panel.close()
        panel.close()
        #expect(dockVisibility.endCount == 1)
    }

    @Test("Standard entrance never disables pointer input on the panel")
    func standardEntrancePreservesPointerInput() {
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = true
        panel.ignoresMouseEvents = false
        defer {
            panel.breakFieldMotionMode = .staticPresentation
            panel.close()
        }

        panel.presentBreakField(makeKey: false)

        #expect(!panel.ignoresMouseEvents)
    }

    @Test("Dock suppression preserves unrelated presentation options")
    func dockSuppressionOptions() {
        let original: NSApplication.PresentationOptions = [
            .autoHideDock,
            .disableProcessSwitching,
        ]
        let suppressed = BreakPresentationDockController.suppressedOptions(from: original)

        #expect(suppressed.contains(.hideDock))
        #expect(!suppressed.contains(.autoHideDock))
        #expect(suppressed.contains(.disableProcessSwitching))
    }

    @Test("Multi-display suppression restores the exact prior options after the last panel")
    func dockSuppressionReferenceCount() {
        let original: NSApplication.PresentationOptions = [
            .autoHideDock,
            .disableProcessSwitching,
        ]
        var current = original
        var writes: [NSApplication.PresentationOptions] = []
        let controller = BreakPresentationDockController(
            readOptions: { current },
            writeOptions: {
                current = $0
                writes.append($0)
            },
        )

        controller.beginSuppression()
        controller.beginSuppression()
        controller.endSuppression()
        #expect(current.contains(.hideDock))
        #expect(writes.count == 1)

        controller.endSuppression()
        controller.endSuppression()
        #expect(current == original)
        #expect(writes.count == 2)
    }

    @Test("Dock suppression can be reapplied after application activation")
    func dockSuppressionRefresh() {
        let original: NSApplication.PresentationOptions = [.autoHideDock]
        var current = original
        var writes: [NSApplication.PresentationOptions] = []
        let controller = BreakPresentationDockController(
            readOptions: { current },
            writeOptions: {
                current = $0
                writes.append($0)
            },
        )

        controller.beginSuppression()
        current = original
        controller.refreshSuppression()

        #expect(current.contains(.hideDock))
        #expect(writes.count == 2)
    }
}

private final class TestBreakPresentationDockController: BreakPresentationDockControlling {
    private(set) var beginCount = 0
    private(set) var refreshCount = 0
    private(set) var endCount = 0

    func beginSuppression() {
        beginCount += 1
    }

    func refreshSuppression() {
        refreshCount += 1
    }

    func endSuppression() {
        endCount += 1
    }
}
