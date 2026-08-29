import AppKit
import CoreGraphics
import Domain
import Movement

final class MovementOverlayCoordinator {
    typealias PanelFactory = (
        OverlayDisplay,
        OverlayDisplayRole,
        MovementModel,
        AccessibilityPreferences,
        @escaping () -> Void,
    ) -> any MovementPanelPresenting
    typealias Scheduler = (@escaping @MainActor @Sendable () -> Void) -> OverlayCancellation

    private let policy: OverlayDisplayPolicy
    private let schedule: OpportunitySchedule
    private let accessibilityPreferences: AccessibilityPreferences
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
    private let onCompletion: () -> Void

    private var panels: [OverlayDisplayID: any MovementPanelPresenting] = [:]
    private var model: MovementModel?
    private var priorProcessIdentifier: pid_t?
    private var refreshCancellation: OverlayCancellation?
    private var screenCancellation: OverlayCancellation?
    private var isDismissing = false
    private var restorationPending = false
    private var interactiveDisplayID: OverlayDisplayID?
    private var preActivationMainDisplayID: OverlayDisplayID?

    init(
        policy: OverlayDisplayPolicy = .allDisplays,
        schedule: OpportunitySchedule,
        accessibilityPreferences: AccessibilityPreferences = .defaults,
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
        onCompletion: @escaping () -> Void = {},
    ) {
        self.policy = policy
        self.schedule = schedule
        self.accessibilityPreferences = accessibilityPreferences
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
        self.onCompletion = onCompletion
    }

    convenience init(
        policy: OverlayDisplayPolicy = .allDisplays,
        schedule: OpportunitySchedule,
        accessibilityPreferences: AccessibilityPreferences = .defaults,
        onLifecycle: @escaping (
            MovementAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (MovementAnnouncement) -> Void,
        onCompletion: @escaping () -> Void = {},
    ) {
        let clock = MovementOverlayMonotonicClock()
        self.init(
            policy: policy,
            schedule: schedule,
            accessibilityPreferences: accessibilityPreferences,
            now: { clock.seconds },
            displays: AppKitOverlayDisplays.current,
            makePanel: { display, role, model, accessibilityPreferences, onCancel in
                MovementPanel(
                    displayID: display.id,
                    frame: display.frame,
                    model: model,
                    role: role,
                    accessibilityPreferences: accessibilityPreferences,
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
            onCompletion: onCompletion,
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
        interactiveDisplayID = plan.interactiveDisplayID
        preActivationMainDisplayID = plan.canonicalMainDisplayID

        priorProcessIdentifier = captureFrontmostProcessIdentifier()
        let model = MovementModel(
            schedule: schedule,
            initialDurationSeconds: selectedDurationSeconds,
            accessibility: accessibilityPreferences.movementAccessibility,
            seatedContentFirst: accessibilityPreferences.seatedContentFirst,
            requiresLifecycleConfirmation: true,
            now: now,
            onAction: { [weak self] action in self?.handle(action) },
            onAnnouncement: { [weak self] announcement in self?.handle(announcement) },
        )
        self.model = model
        reconcile(to: plan, model: model, presenting: true)
        activate()
        for assignment in plan.assignments where assignment.role == .atmosphere {
            panels[assignment.display.id]?.present(makeKey: false)
        }
        if let interactiveDisplayID = plan.interactiveDisplayID {
            panels[interactiveDisplayID]?.present(makeKey: true)
        }
        model.open()
        guard self.model === model else { return }
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
        interactiveDisplayID = nil
        preActivationMainDisplayID = nil
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

        var accessibilityPreferencesForTesting: AccessibilityPreferences {
            accessibilityPreferences
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
                dismissPanels { [weak self] in
                    guard let self else { return }
                    restorePriorApplication()
                    if action.showsCompletion {
                        onCompletion()
                    }
                }
            case .failure:
                actionModel.rejectLifecycle(action)
                guard action == .opened else { return }
                dismissPanels { [weak self] in
                    self?.restorePriorApplication()
                }
            }
        }
    }

    private func dismissPanels(onClosed: @escaping () -> Void) {
        guard !isDismissing, model != nil else {
            onClosed()
            return
        }
        isDismissing = true
        refreshCancellation?.cancel()
        refreshCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        let outgoingPanels = Array(panels.values)
        panels.removeAll()
        model = nil
        restorationPending = true
        isDismissing = false
        let barrier = OverlayDismissalBarrier(
            count: outgoingPanels.count,
            onComplete: onClosed,
        )
        outgoingPanels.forEach { panel in
            panel.dismiss(onClosed: barrier.panelDidClose)
        }
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

    deinit {
        MainActor.assumeIsolated {
            tearDown()
        }
    }
}

private extension MovementOverlayCoordinator {
    func screenParametersChanged() {
        guard let model else { return }
        let plan = OverlayDisplayPlan.resolve(
            displays(),
            policy: policy,
            preferredInteractiveDisplayID: interactiveDisplayID,
            fallbackInteractiveDisplayID: preActivationMainDisplayID,
        )
        reconcile(to: plan, model: model, presenting: false)
    }

    func handle(_ announcement: MovementAnnouncement) {
        guard accessibilityPreferences.includes(announcement) else { return }
        onAnnouncement(announcement)
    }

    func reconcile(
        to plan: OverlayDisplayPlan,
        model: MovementModel,
        presenting: Bool,
    ) {
        let retainedIDs = Set(plan.displays.map(\.id))
        for assignment in plan.assignments where assignment.role == .atmosphere {
            panels[assignment.display.id]?.update(
                frame: assignment.display.frame,
                role: assignment.role,
            )
        }
        for assignment in plan.assignments {
            let display = assignment.display
            if let panel = panels[display.id] {
                panel.update(frame: display.frame, role: assignment.role)
            } else {
                let panel = makePanel(
                    display,
                    assignment.role,
                    model,
                    accessibilityPreferences,
                ) { [weak model] in
                    model?.skip()
                }
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
        if let resolvedInteractiveDisplayID = plan.interactiveDisplayID {
            interactiveDisplayID = resolvedInteractiveDisplayID
        }
        if !presenting, isAppFrontmost(), let interactiveDisplayID = plan.interactiveDisplayID {
            panels[interactiveDisplayID]?.makeKey()
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

    var showsCompletion: Bool {
        switch self {
        case .timerFinished, .doneEarly, .alreadyMoved: true
        case .opened, .selectedDuration, .positionChanged, .visualOnly, .skipped: false
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
