import AppKit
import CoreGraphics
import Domain
import Movement

final class MovementOverlayCoordinator {
    typealias PanelFactory = (
        OverlayDisplay,
        MovementModel,
        @escaping () -> Void,
    ) -> any MovementPanelPresenting
    typealias Scheduler = (@escaping @MainActor @Sendable () -> Void) -> OverlayCancellation

    private let policy: OverlayDisplayPolicy
    private let schedule: OpportunitySchedule
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
        MovementAction,
        @escaping (Result<Void, any Error>) -> Void,
    ) -> Void
    private let onAnnouncement: (MovementAnnouncement) -> Void

    private var panels: [OverlayDisplayID: any MovementPanelPresenting] = [:]
    private var model: MovementModel?
    private var priorProcessIdentifier: pid_t?
    private var refreshCancellation: OverlayCancellation?
    private var screenCancellation: OverlayCancellation?
    private var isDismissing = false
    private var restorationPending = false

    init(
        policy: OverlayDisplayPolicy = .allDisplays,
        schedule: OpportunitySchedule,
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
            MovementAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        self.policy = policy
        self.schedule = schedule
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
        schedule: OpportunitySchedule,
        onLifecycle: @escaping (
            MovementAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (MovementAnnouncement) -> Void,
    ) {
        let clock = MovementOverlayMonotonicClock()
        self.init(
            policy: policy,
            schedule: schedule,
            now: { clock.seconds },
            displays: AppKitOverlayDisplays.current,
            makePanel: { display, model, onCancel in
                MovementPanel(
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
            restore: VisualResetOverlayCoordinator.restoreApplication,
            scheduleRefresh: VisualResetOverlayCoordinator.liveRefreshScheduler,
            observeScreenChanges: VisualResetOverlayCoordinator.observeScreenChanges,
            onLifecycle: onLifecycle,
            onAnnouncement: onAnnouncement,
        )
    }

    func present(selectedDurationSeconds: TimeInterval? = nil) {
        if let selectedDurationSeconds {
            guard schedule.durationOptionsSeconds.contains(selectedDurationSeconds) else { return }
        }
        if let model {
            if model.phase == .ready {
                model.open()
            }
            if let selectedDurationSeconds {
                applyExplicitDuration(selectedDurationSeconds, to: model)
            }
            return
        }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        guard !plan.displays.isEmpty else { return }

        priorProcessIdentifier = captureFrontmostProcessIdentifier()
        let model = MovementModel(
            schedule: schedule,
            initialDurationSeconds: selectedDurationSeconds,
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
        if let selectedDurationSeconds {
            applyExplicitDuration(selectedDurationSeconds, to: model)
        }
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
            let livePanels = panels.values.compactMap { $0 as? MovementPanel }
            let panel = livePanels.first(where: \.isKeyWindow) ?? livePanels.first
            return panel?.captureForVerification() ?? false
        }

        var remainingSecondsForVerification: Int? {
            model?.remainingSeconds
        }

        var selectedDurationForVerification: TimeInterval? {
            model?.selectedDurationSeconds
        }
    #endif

    private func handle(_ action: MovementAction) {
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
                guard action.isTerminal else { return }
                dismissPanels()
                restorePriorApplication()
            case .failure:
                actionModel.rejectLifecycle(action)
            }
        }
    }

    private func handle(_ announcement: MovementAnnouncement) {
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
        model: MovementModel,
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

private extension MovementOverlayCoordinator {
    func applyExplicitDuration(
        _ duration: TimeInterval,
        to model: MovementModel,
    ) {
        if duration == model.recommendedDurationSeconds {
            model.selectRecommendedDuration()
        } else if model.selectedDurationSeconds == model.quickDurationSeconds {
            model.confirmSelectedDuration()
        } else {
            model.selectQuickDuration()
        }
    }
}

private extension MovementAction {
    var isTerminal: Bool {
        switch self {
        case .opened, .selectedDuration:
            false
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .visualOnly, .skipped:
            true
        }
    }
}

private final class MovementOverlayMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
