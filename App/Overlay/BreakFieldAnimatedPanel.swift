import AppKit
import DesignSystem

enum BreakFieldPanelMotionMode: Equatable {
    case standard
    case reduced
    case staticPresentation

    static func resolve(staticPresentation: Bool, reduceMotion: Bool) -> Self {
        if staticPresentation { return .staticPresentation }
        return reduceMotion ? .reduced : .standard
    }

    var profile: BreakFieldPanelMotionProfile {
        switch self {
        case .standard:
            BreakFieldPanelMotionProfile(
                enterDuration: 0,
                exitDuration: 0,
                initialAlpha: 1,
                transitionStyle: .instant,
            )
        case .reduced:
            BreakFieldPanelMotionProfile(
                enterDuration: 0,
                exitDuration: 0,
                initialAlpha: 1,
                transitionStyle: .instant,
            )
        case .staticPresentation:
            BreakFieldPanelMotionProfile(
                enterDuration: 0,
                exitDuration: 0,
                initialAlpha: 1,
                transitionStyle: .instant,
            )
        }
    }
}

enum BreakFieldPanelTransitionStyle: Equatable {
    case frostDissolve
    case crossDissolve
    case instant
}

struct BreakFieldPanelMotionProfile: Equatable {
    let enterDuration: TimeInterval
    let exitDuration: TimeInterval
    let initialAlpha: CGFloat
    let transitionStyle: BreakFieldPanelTransitionStyle

    var isAnimated: Bool { enterDuration > 0 || exitDuration > 0 }
}

class BreakFieldAnimatedPanel: NSPanel {
    var breakFieldMotionMode: BreakFieldPanelMotionMode = .standard
    var dockVisibilityController: any BreakPresentationDockControlling =
        BreakPresentationDockController.shared
    var breakFieldReduceTransparency =
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    let breakFieldEntranceState = DSBreakEntranceState()

    private var isAnimatingClose = false
    private var isSuppressingDock = false
    private var ignoredMouseEventsBeforeClose = false
    private var activationObserver: NSObjectProtocol?
    private var requestsKeyPresentation = false

    func presentBreakField(makeKey: Bool) {
        guard !isVisible else {
            if makeKey { requestInteractiveActivation() }
            return
        }
        beginDockSuppressionIfNeeded()
        requestsKeyPresentation = makeKey
        let profile = breakFieldMotionMode.profile
        switch profile.transitionStyle {
        case .instant:
            breakFieldEntranceState.phase = .settled
            orderBreakFieldFront(makeKey: makeKey)
        case .crossDissolve:
            breakFieldEntranceState.phase = .settled
            alphaValue = profile.initialAlpha
            orderBreakFieldFront(makeKey: makeKey)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = profile.enterDuration
                animator().alphaValue = 1
            }
        case .frostDissolve:
            assertionFailure("The rejected frost transition must not be used")
            breakFieldEntranceState.phase = .settled
            orderBreakFieldFront(makeKey: makeKey)
        }
        if makeKey { requestInteractiveActivation() }
    }

    override func close() {
        let profile = breakFieldMotionMode.profile
        guard isVisible, profile.isAnimated, !isAnimatingClose else {
            if !isAnimatingClose {
                super.close()
                endDockSuppressionIfNeeded()
            }
            return
        }

        isAnimatingClose = true
        ignoredMouseEventsBeforeClose = ignoresMouseEvents
        ignoresMouseEvents = true

        NSAnimationContext.runAnimationGroup { context in
            context.duration = profile.exitDuration
            animator().alphaValue = 0
        } completionHandler: { [weak self] in
            Task { @MainActor [weak self] in
                self?.finishAnimatedClose()
            }
        }
    }

    private func orderBreakFieldFront(makeKey: Bool) {
        if makeKey {
            makeKeyAndOrderFront(nil)
        } else {
            orderFront(nil)
        }
    }

    private func requestInteractiveActivation() {
        requestsKeyPresentation = true
        installActivationObserverIfNeeded()
        NSApp.activate(ignoringOtherApps: true)
        if NSApp.isActive {
            completeInteractiveActivation()
        }
    }

    private func installActivationObserverIfNeeded() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.completeInteractiveActivation()
            }
        }
    }

    private func completeInteractiveActivation() {
        guard requestsKeyPresentation else { return }
        dockVisibilityController.refreshSuppression()
        makeKeyAndOrderFront(nil)
        removeActivationObserver()
    }

    private func removeActivationObserver() {
        guard let activationObserver else { return }
        NotificationCenter.default.removeObserver(activationObserver)
        self.activationObserver = nil
    }

    private func finishAnimatedClose() {
        super.close()
        requestsKeyPresentation = false
        removeActivationObserver()
        alphaValue = 1
        ignoresMouseEvents = ignoredMouseEventsBeforeClose
        breakFieldEntranceState.phase = .settled
        isAnimatingClose = false
        endDockSuppressionIfNeeded()
    }

    private func beginDockSuppressionIfNeeded() {
        guard !isSuppressingDock else { return }
        isSuppressingDock = true
        dockVisibilityController.beginSuppression()
    }

    private func endDockSuppressionIfNeeded() {
        guard isSuppressingDock else { return }
        isSuppressingDock = false
        dockVisibilityController.endSuppression()
    }

    deinit {
        MainActor.assumeIsolated {
            removeActivationObserver()
            if isSuppressingDock {
                dockVisibilityController.endSuppression()
            }
        }
    }
}
