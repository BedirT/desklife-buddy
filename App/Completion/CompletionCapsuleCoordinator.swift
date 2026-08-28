import AppKit
import CoreGraphics

final class CompletionCapsuleCoordinator {
    typealias PanelFactory = (
        HeadsUpDisplayID,
        CGRect,
    ) -> any CompletionCapsulePanelPresenting
    typealias Scheduler = (
        TimeInterval,
        @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation
    typealias ScreenObserver = (
        @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation

    private let durationSeconds: TimeInterval
    private let screens: () -> [HeadsUpScreen]
    private let pointerLocation: () -> CGPoint
    private let contentSize: () -> CGSize
    private let makePanel: PanelFactory
    private let scheduleDismissal: Scheduler
    private let observeScreenChanges: ScreenObserver
    private let shouldPresent: () -> Bool

    private var panel: (any CompletionCapsulePanelPresenting)?
    private var dismissalCancellation: OverlayCancellation?
    private var screenCancellation: OverlayCancellation?
    private var selectedDisplayID: HeadsUpDisplayID?
    private var generation = 0

    init(
        durationSeconds: TimeInterval = 2,
        screens: @escaping () -> [HeadsUpScreen],
        pointerLocation: @escaping () -> CGPoint,
        contentSize: @escaping () -> CGSize,
        makePanel: @escaping PanelFactory,
        scheduleDismissal: @escaping Scheduler,
        observeScreenChanges: @escaping ScreenObserver,
        shouldPresent: @escaping () -> Bool,
    ) {
        self.durationSeconds = durationSeconds
        self.screens = screens
        self.pointerLocation = pointerLocation
        self.contentSize = contentSize
        self.makePanel = makePanel
        self.scheduleDismissal = scheduleDismissal
        self.observeScreenChanges = observeScreenChanges
        self.shouldPresent = shouldPresent
    }

    convenience init(shouldPresent: @escaping () -> Bool) {
        self.init(
            screens: AppKitHeadsUpScreens.current,
            pointerLocation: { NSEvent.mouseLocation },
            contentSize: { CompletionCapsulePanel.fittingSize },
            makePanel: { displayID, frame in
                CompletionCapsulePanel(displayID: displayID, frame: frame)
            },
            scheduleDismissal: Self.liveDismissalScheduler,
            observeScreenChanges: HeadsUpCapsuleCoordinator.observeLiveScreenChanges,
            shouldPresent: shouldPresent,
        )
    }

    var isPresenting: Bool {
        dismissalCancellation != nil
    }

    @discardableResult
    func present() -> Bool {
        guard shouldPresent() else { return false }
        tearDown()
        generation &+= 1
        let activeGeneration = generation
        let currentScreens = screens()
        selectedDisplayID = HeadsUpScreenResolver.targetScreen(
            in: currentScreens,
            pointerLocation: pointerLocation(),
        )?.id
        reconcile(currentScreens)
        guard panel != nil else {
            selectedDisplayID = nil
            return false
        }
        screenCancellation = observeScreenChanges { [weak self] in
            guard let self, generation == activeGeneration else { return }
            reconcile(screens())
        }
        dismissalCancellation = scheduleDismissal(durationSeconds) { [weak self] in
            guard let self, generation == activeGeneration else { return }
            tearDown()
        }
        return true
    }

    func dismiss() {
        tearDown()
    }

    func tearDown() {
        generation &+= 1
        dismissalCancellation?.cancel()
        dismissalCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        panel?.close()
        panel = nil
        selectedDisplayID = nil
    }

    private func reconcile(_ currentScreens: [HeadsUpScreen]) {
        let canonicalScreens = HeadsUpScreenResolver.canonicalScreens(currentScreens)
        let retainedTarget = retainedScreen(
            selectedDisplayID: selectedDisplayID,
            screens: currentScreens,
            canonicalScreens: canonicalScreens,
        )
        let target = retainedTarget ?? HeadsUpScreenResolver.targetScreen(
            in: currentScreens,
            pointerLocation: pointerLocation(),
        )
        guard let target else {
            panel?.close()
            panel = nil
            return
        }
        selectedDisplayID = target.id
        let placement = HeadsUpCapsuleGeometry.placement(
            on: target,
            contentSize: contentSize(),
        )
        if let panel, panel.displayID == target.id {
            panel.update(frame: placement.frame)
            return
        }
        panel?.close()
        let newPanel = makePanel(target.id, placement.frame)
        panel = newPanel
        newPanel.presentWithoutActivation()
    }

    private func retainedScreen(
        selectedDisplayID: HeadsUpDisplayID?,
        screens: [HeadsUpScreen],
        canonicalScreens: [HeadsUpScreen],
    ) -> HeadsUpScreen? {
        guard let selectedDisplayID else { return nil }
        if let selected = screens.first(where: { $0.id == selectedDisplayID }) {
            return canonicalScreens.first(where: { $0.mirrorRootID == selected.mirrorRootID })
        }
        return canonicalScreens.first(where: {
            $0.id == selectedDisplayID || $0.mirrorRootID == selectedDisplayID
        })
    }

    deinit {
        MainActor.assumeIsolated { tearDown() }
    }
}

extension CompletionCapsuleCoordinator {
    static func liveDismissalScheduler(
        duration: TimeInterval,
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let timer = Timer(timeInterval: duration, repeats: false) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return OverlayCancellation { timer.invalidate() }
    }
}
