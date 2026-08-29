import AppKit
import DesignSystem
import Testing
@testable import App

@Suite("Break field panel motion")
struct BreakFieldPanelMotionTests {
    @Test("Standard presentation uses a slow whole-screen frost and field sharpen")
    func standardProfile() {
        let profile = BreakFieldPanelMotionMode.standard.profile

        #expect(profile.enterDuration == DSMotion.breakFieldEnterDuration)
        #expect(profile.exitDuration == DSMotion.breakFieldExitDuration)
        #expect(profile.initialAlpha == 1)
        #expect(profile.transitionStyle == .frostDissolve)
        #expect(profile.isAnimated)
        #expect(profile.hasAnimatedExit)
        #expect(
            profile.enterDuration
                == DSMotion.breakFieldDesktopFrostDuration
                + DSMotion.breakFieldFrostHoldDuration
                + DSMotion.breakFieldBlurredFieldCrossfadeDuration
                + DSMotion.breakFieldFieldSharpenDuration,
        )
    }

    @Test("A settled standard field reverses through frost before restoring the Dock")
    func standardExitLifecycle() throws {
        let dockVisibility = TestBreakPresentationDockController()
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = false
        panel.dockVisibilityController = dockVisibility
        panel.presentBreakField(makeKey: false)
        panel.settleBreakFieldEntranceForTesting()

        panel.dismissBreakField()
        #expect(panel.isVisible)
        #expect(dockVisibility.endCount == 0)

        panel.settleBreakFieldExitForTesting()
        #expect(!panel.isVisible)
        #expect(dockVisibility.endCount == 1)
    }

    @Test("An exit requested before entrance settlement closes immediately")
    func earlyExitIsImmediate() {
        let dockVisibility = TestBreakPresentationDockController()
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = false
        panel.dockVisibilityController = dockVisibility
        panel.presentBreakField(makeKey: false)

        panel.dismissBreakField()

        #expect(!panel.isVisible)
        #expect(dockVisibility.endCount == 1)
    }

    @Test("Reduce Transparency bypasses the animated exit")
    func reduceTransparencyExitIsImmediate() {
        let dockVisibility = TestBreakPresentationDockController()
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = true
        panel.dockVisibilityController = dockVisibility
        panel.presentBreakField(makeKey: false)

        panel.dismissBreakField()

        #expect(!panel.isVisible)
        #expect(dockVisibility.endCount == 1)
    }

    @Test("Timer controls begin arriving by the eighteen-second mark")
    func controlArrivalTiming() {
        let controlArrival = DSMotion.breakFieldDesktopFrostDuration
            + DSMotion.breakFieldFrostHoldDuration
            + DSMotion.breakFieldBlurredFieldCrossfadeDuration
            + DSMotion.breakFieldControlDelay

        #expect(controlArrival <= 2)
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

    @Test("Synchronous cleanup bypasses the standard exit")
    func cleanupCloseIsImmediate() {
        let dockVisibility = TestBreakPresentationDockController()
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        panel.contentView = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = false
        panel.dockVisibilityController = dockVisibility
        panel.presentBreakField(makeKey: false)
        panel.settleBreakFieldEntranceForTesting()

        panel.close()

        #expect(!panel.isVisible)
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

    @Test("The frost entrance keeps one stable content root through settlement")
    func stableContentRoot() throws {
        let panel = BreakFieldAnimatedPanel(
            contentRect: CGRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
        )
        let field = NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        panel.contentView = field
        panel.breakFieldMotionMode = .standard
        panel.breakFieldReduceTransparency = false
        defer {
            panel.breakFieldMotionMode = .staticPresentation
            panel.close()
        }

        panel.presentBreakField(makeKey: false)
        let stableRoot = try #require(panel.contentView)
        #expect(stableRoot !== field)
        #expect(field.superview === stableRoot)

        panel.settleBreakFieldEntranceForTesting()

        #expect(panel.contentView === stableRoot)
        #expect(field.superview === stableRoot)
        #expect(panel.breakFieldEntranceState.phase == .settled)
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
