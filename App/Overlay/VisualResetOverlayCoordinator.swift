import AppKit
import CoreGraphics
import VisualReset

final class VisualResetOverlayCoordinator {
    typealias PanelFactory = (
        OverlayDisplay,
        VisualResetModel,
        @escaping () -> Void,
    ) -> any VisualResetPanelPresenting
    typealias Scheduler = (@escaping @MainActor @Sendable () -> Void) -> OverlayCancellation

    private let policy: OverlayDisplayPolicy
    private let durationSeconds: TimeInterval
    private let now: () -> TimeInterval
    private let displays: () -> [OverlayDisplay]
    private let makePanel: PanelFactory
    private let captureFrontmostProcessIdentifier: () -> pid_t?
    private let activate: () -> Void
    private let isAppFrontmost: () -> Bool
    private let restore: (pid_t) -> Void
    private let scheduleRefresh: Scheduler
    private let observeScreenChanges: Scheduler
    private let onLifecycle: (
        VisualResetAction,
        @escaping (Result<Void, any Error>) -> Void,
    ) -> Void
    private let onAnnouncement: (VisualResetAnnouncement) -> Void

    private var panels: [OverlayDisplayID: any VisualResetPanelPresenting] = [:]
    private var model: VisualResetModel?
    private var priorProcessIdentifier: pid_t?
    private var refreshCancellation: OverlayCancellation?
    private var screenCancellation: OverlayCancellation?
    private var isDismissing = false
    private var restorationPending = false

    init(
        policy: OverlayDisplayPolicy = .allDisplays,
        durationSeconds: TimeInterval = 20,
        now: @escaping () -> TimeInterval,
        displays: @escaping () -> [OverlayDisplay],
        makePanel: @escaping PanelFactory,
        captureFrontmostProcessIdentifier: @escaping () -> pid_t?,
        activate: @escaping () -> Void,
        isAppFrontmost: @escaping () -> Bool,
        restore: @escaping (pid_t) -> Void,
        scheduleRefresh: @escaping Scheduler,
        observeScreenChanges: @escaping Scheduler,
        onLifecycle: @escaping (
            VisualResetAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (VisualResetAnnouncement) -> Void = { _ in },
    ) {
        self.policy = policy
        self.durationSeconds = durationSeconds
        self.now = now
        self.displays = displays
        self.makePanel = makePanel
        self.captureFrontmostProcessIdentifier = captureFrontmostProcessIdentifier
        self.activate = activate
        self.isAppFrontmost = isAppFrontmost
        self.restore = restore
        self.scheduleRefresh = scheduleRefresh
        self.observeScreenChanges = observeScreenChanges
        self.onLifecycle = onLifecycle
        self.onAnnouncement = onAnnouncement
    }

    convenience init(
        policy: OverlayDisplayPolicy = .allDisplays,
        durationSeconds: TimeInterval = 20,
        onLifecycle: @escaping (
            VisualResetAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (VisualResetAnnouncement) -> Void,
    ) {
        let clock = OverlayMonotonicClock()
        self.init(
            policy: policy,
            durationSeconds: durationSeconds,
            now: { clock.seconds },
            displays: AppKitOverlayDisplays.current,
            makePanel: { display, model, onCancel in
                VisualResetPanel(
                    displayID: display.id,
                    frame: display.frame,
                    model: model,
                    onCancel: onCancel,
                )
            },
            captureFrontmostProcessIdentifier: {
                NSWorkspace.shared.frontmostApplication?.processIdentifier
            },
            activate: { NSApp.activate() },
            isAppFrontmost: { NSApp.isActive },
            restore: Self.restoreApplication,
            scheduleRefresh: Self.liveRefreshScheduler,
            observeScreenChanges: Self.observeScreenChanges,
            onLifecycle: onLifecycle,
            onAnnouncement: onAnnouncement,
        )
    }

    func present() {
        if let model {
            if model.phase == .ready {
                model.open()
            }
            return
        }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        guard !plan.displays.isEmpty else { return }

        priorProcessIdentifier = captureFrontmostProcessIdentifier()
        let model = VisualResetModel(
            durationSeconds: durationSeconds,
            requiresLifecycleConfirmation: true,
            now: now,
            onAction: { [weak self] action in self?.handle(action) },
            onAnnouncement: { [weak self] announcement in self?.handle(announcement) },
        )
        self.model = model
        reconcile(to: plan, model: model, presenting: true)
        activate()
        for display in plan.displays where display.id != plan.keyDisplayID {
            panels[display.id]?.present(makeKey: false)
        }
        if let keyDisplayID = plan.keyDisplayID {
            panels[keyDisplayID]?.present(makeKey: true)
        }
        model.open()
        refreshCancellation = scheduleRefresh { [weak self] in self?.model?.refresh() }
        screenCancellation = observeScreenChanges { [weak self] in self?.screenParametersChanged() }
    }

    var isPresenting: Bool {
        model != nil
    }

    func tearDown() {
        refreshCancellation?.cancel()
        refreshCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        model = nil
        priorProcessIdentifier = nil
        restorationPending = false
        isDismissing = false
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            let livePanels = panels.values.compactMap { $0 as? VisualResetPanel }
            let panel = livePanels.first(where: \.isKeyWindow) ?? livePanels.first
            return panel?.captureForVerification() ?? false
        }

        var remainingSecondsForVerification: Int? {
            model?.remainingSeconds
        }

        var monotonicSecondsForVerification: TimeInterval {
            now()
        }
    #endif

    private func handle(_ action: VisualResetAction) {
        guard let actionModel = model else { return }
        onLifecycle(action) { [weak self, weak actionModel] result in
            guard let self,
                  let actionModel,
                  model === actionModel
            else {
                return
            }
            switch result {
            case .success:
                actionModel.confirmLifecycle(action)
                guard action != .opened else { return }
                dismissPanels()
                restorePriorApplication()
            case .failure:
                actionModel.rejectLifecycle(action)
            }
        }
    }

    private func handle(_ announcement: VisualResetAnnouncement) {
        onAnnouncement(announcement)
    }

    private func dismissPanels() {
        guard !isDismissing, model != nil else { return }
        isDismissing = true
        refreshCancellation?.cancel()
        refreshCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        model = nil
        restorationPending = true
        isDismissing = false
    }

    private func restorePriorApplication() {
        guard restorationPending else { return }
        restorationPending = false
        defer { priorProcessIdentifier = nil }
        guard let priorProcessIdentifier,
              priorProcessIdentifier != ProcessInfo.processInfo.processIdentifier,
              isAppFrontmost()
        else {
            return
        }
        restore(priorProcessIdentifier)
    }

    private func screenParametersChanged() {
        guard let model else { return }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        reconcile(to: plan, model: model, presenting: false)
    }

    private func reconcile(
        to plan: OverlayDisplayPlan,
        model: VisualResetModel,
        presenting: Bool,
    ) {
        let retainedIDs = Set(plan.displays.map(\.id))
        for display in plan.displays {
            if let panel = panels[display.id] {
                panel.update(frame: display.frame)
            } else {
                let panel = makePanel(display, model) { [weak model] in model?.skip() }
                panels[display.id] = panel
                if !presenting {
                    panel.present(makeKey: false)
                }
            }
        }

        for (id, panel) in panels where !retainedIDs.contains(id) {
            panel.close()
            panels[id] = nil
        }
        if !presenting, isAppFrontmost(), let keyDisplayID = plan.keyDisplayID {
            panels[keyDisplayID]?.makeKey()
        }
    }

    deinit {
        MainActor.assumeIsolated {
            tearDown()
        }
    }
}

extension VisualResetOverlayCoordinator {
    static func liveRefreshScheduler(
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { _ in
            MainActor.assumeIsolated { action() }
        }
        RunLoop.main.add(timer, forMode: .common)
        return OverlayCancellation { timer.invalidate() }
    }

    static func observeScreenChanges(
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let target = OverlayActionTarget(action)
        NotificationCenter.default.addObserver(
            target,
            selector: #selector(OverlayActionTarget.perform(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: NSApplication.shared,
        )
        return OverlayCancellation {
            NotificationCenter.default.removeObserver(target)
        }
    }

    static func restoreApplication(processIdentifier: pid_t) {
        guard let application = NSRunningApplication(processIdentifier: processIdentifier) else { return }
        NSApp.yieldActivation(to: application)
        application.activate()
    }
}

private final class OverlayActionTarget: NSObject {
    private let action: @MainActor @Sendable () -> Void

    init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @objc func perform(_ sender: Any?) {
        action()
    }
}

private final class OverlayMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
