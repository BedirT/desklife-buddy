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
                enterDuration: DSMotion.breakFieldEnterDuration,
                exitDuration: DSMotion.breakFieldExitDuration,
                initialAlpha: 1,
                transitionStyle: .frostDissolve,
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
    case instant
}

struct BreakFieldPanelMotionProfile: Equatable {
    let enterDuration: TimeInterval
    let exitDuration: TimeInterval
    let initialAlpha: CGFloat
    let transitionStyle: BreakFieldPanelTransitionStyle

    var hasAnimatedEntrance: Bool { enterDuration > 0 }
    var hasAnimatedExit: Bool { exitDuration > 0 }
    var isAnimated: Bool { hasAnimatedEntrance || hasAnimatedExit }
}

class BreakFieldAnimatedPanel: NSPanel {
    var breakFieldMotionMode: BreakFieldPanelMotionMode = .standard
    var dockVisibilityController: any BreakPresentationDockControlling =
        BreakPresentationDockController.shared
    var breakFieldReduceTransparency =
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
    let breakFieldEntranceState = DSBreakEntranceState()
    let breakFieldTransitionState = DSBreakFieldTransitionState()
    var breakFieldEntranceDidSettle: () -> Void = {}

    private var isSuppressingDock = false
    private var activationObserver: NSObjectProtocol?
    private var frostTransition: BreakFieldFrostTransition?
    private var requestsEntranceWhenActive = false
    private var requestsKeyPresentation = false
    private var didNotifyEntranceSettlement = false
    private var isDismissing = false
    private var ignoredMouseEventsBeforeDismissal = false
    private var exitRetainer: BreakFieldAnimatedPanel?
    private var dismissalCompletions: [() -> Void] = []

    func presentBreakField(makeKey: Bool) {
        guard !isVisible else {
            if makeKey { requestInteractiveActivation() }
            return
        }
        beginDockSuppressionIfNeeded()
        didNotifyEntranceSettlement = false
        requestsKeyPresentation = makeKey
        let profile = breakFieldMotionMode.profile
        let transitionStyle = breakFieldReduceTransparency
            ? BreakFieldPanelTransitionStyle.instant
            : profile.transitionStyle
        switch transitionStyle {
        case .instant:
            breakFieldEntranceState.phase = .settled
            breakFieldTransitionState.phase = .sharp
            orderBreakFieldFront(makeKey: makeKey)
            notifyEntranceSettlement()
        case .frostDissolve:
            breakFieldEntranceState.phase = .hidden
            breakFieldTransitionState.phase = .hidden
            frostTransition = BreakFieldFrostTransition.install(
                on: self,
                entranceState: breakFieldEntranceState,
                fieldTransitionState: breakFieldTransitionState,
                onSettled: { [weak self] in self?.notifyEntranceSettlement() },
            )
            guard frostTransition != nil else {
                breakFieldEntranceState.phase = .settled
                breakFieldTransitionState.phase = .sharp
                orderBreakFieldFront(makeKey: makeKey)
                notifyEntranceSettlement()
                if makeKey { requestInteractiveActivation() }
                return
            }
            requestsEntranceWhenActive = true
            orderBreakFieldFront(makeKey: makeKey)
        }
        prepareForApplicationActivation(makeKey: makeKey)
    }

    override func close() {
        let wasDismissing = isDismissing
        frostTransition?.cancel()
        frostTransition = nil
        breakFieldEntranceState.phase = .settled
        breakFieldTransitionState.phase = .sharp
        requestsEntranceWhenActive = false
        requestsKeyPresentation = false
        isDismissing = false
        removeActivationObserver()
        super.close()
        endDockSuppressionIfNeeded()
        if wasDismissing {
            ignoresMouseEvents = ignoredMouseEventsBeforeDismissal
        }
        exitRetainer = nil
        completeDismissalCallbacks()
    }

    func dismissBreakField(onClosed: @escaping () -> Void = {}) {
        dismissalCompletions.append(onClosed)
        guard isVisible else {
            completeDismissalCallbacks()
            return
        }
        guard !isDismissing else { return }
        let profile = breakFieldMotionMode.profile
        guard profile.hasAnimatedExit,
              !breakFieldReduceTransparency,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              didNotifyEntranceSettlement,
              let frostTransition
        else {
            close()
            return
        }

        isDismissing = true
        ignoredMouseEventsBeforeDismissal = ignoresMouseEvents
        ignoresMouseEvents = true
        exitRetainer = self
        guard frostTransition.startExit(onComplete: { [weak self] in
            self?.finishAnimatedDismissal()
        }) else {
            close()
            return
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
        prepareForApplicationActivation(makeKey: true)
    }

    private func prepareForApplicationActivation(makeKey: Bool) {
        requestsKeyPresentation = requestsKeyPresentation || makeKey
        guard requestsKeyPresentation || requestsEntranceWhenActive else { return }
        installActivationObserverIfNeeded()
        if makeKey { NSApp.activate(ignoringOtherApps: true) }
        if NSApp.isActive { completeApplicationActivation() }
    }

    private func installActivationObserverIfNeeded() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: NSApp,
            queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.completeApplicationActivation()
            }
        }
    }

    private func completeApplicationActivation() {
        dockVisibilityController.refreshSuppression()
        if requestsKeyPresentation { makeKeyAndOrderFront(nil) }
        if requestsEntranceWhenActive {
            requestsEntranceWhenActive = false
            frostTransition?.start()
        }
        removeActivationObserver()
    }

    private func removeActivationObserver() {
        guard let activationObserver else { return }
        NotificationCenter.default.removeObserver(activationObserver)
        self.activationObserver = nil
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

    private func notifyEntranceSettlement() {
        guard !didNotifyEntranceSettlement else { return }
        didNotifyEntranceSettlement = true
        breakFieldEntranceDidSettle()
    }

    private func finishAnimatedDismissal() {
        frostTransition = nil
        super.close()
        endDockSuppressionIfNeeded()
        ignoresMouseEvents = ignoredMouseEventsBeforeDismissal
        isDismissing = false
        exitRetainer = nil
        completeDismissalCallbacks()
    }

    private func completeDismissalCallbacks() {
        let completions = dismissalCompletions
        dismissalCompletions.removeAll()
        completions.forEach { $0() }
    }

    deinit {
        MainActor.assumeIsolated {
            frostTransition?.cancel()
            removeActivationObserver()
            if isSuppressingDock {
                dockVisibilityController.endSuppression()
            }
        }
    }

    #if DEBUG
        func settleBreakFieldEntranceForTesting() {
            frostTransition?.settle()
        }

        func settleBreakFieldExitForTesting() {
            frostTransition?.settleExit()
        }
    #endif
}
