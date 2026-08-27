import AppKit
import BreakFlow
import CoreGraphics
import Domain
import Movement
import VisualReset

final class MergedOverlayCoordinator {
    typealias PanelFactory = (
        OverlayDisplay,
        MergedPanelContent,
        @escaping () -> Void,
    ) -> any MergedPanelPresenting
    typealias Scheduler = (@escaping @MainActor @Sendable () -> Void) -> OverlayCancellation
    typealias LifecycleCallback = (
        MergedLifecycleEvent,
        @escaping (Result<Void, any Error>) -> Void,
    ) -> Void
    private enum Phase {
        case visual(VisualResetModel)
        case movement(MovementModel)
        case acknowledgement(BreakFlowModel)
    }

    private let policy: OverlayDisplayPolicy
    private let visualDurationSeconds: TimeInterval
    private let movementSchedule: OpportunitySchedule
    private let acknowledgementDurationSeconds: TimeInterval
    private let now: () -> TimeInterval
    private let displays: () -> [OverlayDisplay]
    private let makePanel: PanelFactory
    private let captureFrontmostProcessIdentifier: () -> pid_t?
    private let activate: () -> Void
    private let isAppFrontmost: () -> Bool
    private let restore: (pid_t) -> Void
    private let scheduleRefresh: Scheduler
    private let observeScreenChanges: Scheduler
    private let onLifecycle: LifecycleCallback
    private let onVisualAnnouncement: (VisualResetAnnouncement) -> Void
    private let onMovementAnnouncement: (MovementAnnouncement) -> Void
    private var panels: [OverlayDisplayID: any MergedPanelPresenting] = [:]
    private var phase: Phase?
    private var priorProcessIdentifier: pid_t?
    private var refreshCancellation: OverlayCancellation?
    private var screenCancellation: OverlayCancellation?
    private var acknowledgementDeadline: TimeInterval?
    private var isDismissing = false
    private var restorationPending = false
    init(
        policy: OverlayDisplayPolicy = .allDisplays,
        visualDurationSeconds: TimeInterval = 20,
        movementSchedule: OpportunitySchedule,
        acknowledgementDurationSeconds: TimeInterval = 2,
        now: @escaping () -> TimeInterval,
        displays: @escaping () -> [OverlayDisplay],
        makePanel: @escaping PanelFactory,
        captureFrontmostProcessIdentifier: @escaping () -> pid_t?,
        activate: @escaping () -> Void,
        isAppFrontmost: @escaping () -> Bool,
        restore: @escaping (pid_t) -> Void,
        scheduleRefresh: @escaping Scheduler,
        observeScreenChanges: @escaping Scheduler,
        onLifecycle: @escaping LifecycleCallback,
        onVisualAnnouncement: @escaping (VisualResetAnnouncement) -> Void = { _ in },
        onMovementAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        self.policy = policy
        self.visualDurationSeconds = visualDurationSeconds
        self.movementSchedule = movementSchedule
        self.acknowledgementDurationSeconds = acknowledgementDurationSeconds
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
        self.onVisualAnnouncement = onVisualAnnouncement
        self.onMovementAnnouncement = onMovementAnnouncement
    }

    func present() {
        if case let .visual(model) = phase, model.phase == .ready {
            model.open()
            return
        }
        guard phase == nil else { return }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        guard !plan.displays.isEmpty else { return }
        priorProcessIdentifier = captureFrontmostProcessIdentifier()
        let model = VisualResetModel(
            durationSeconds: visualDurationSeconds,
            requiresLifecycleConfirmation: true,
            now: now,
            onAction: { [weak self] action in self?.handleVisual(action) },
            onAnnouncement: { [weak self] announcement in
                self?.onVisualAnnouncement(announcement)
            },
        )
        phase = .visual(model)
        reconcile(to: plan, content: .visual(model), presenting: true)
        activate()
        for display in plan.displays where display.id != plan.keyDisplayID {
            panels[display.id]?.present(makeKey: false)
        }
        if let keyDisplayID = plan.keyDisplayID {
            panels[keyDisplayID]?.present(makeKey: true)
        }
        model.open()
        refreshCancellation = scheduleRefresh { [weak self] in self?.refresh() }
        screenCancellation = observeScreenChanges { [weak self] in self?.screenParametersChanged() }
    }

    var isPresenting: Bool {
        phase != nil
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            let livePanels = panels.values.compactMap { $0 as? MergedPanel }
            let panel = livePanels.first(where: \.isKeyWindow) ?? livePanels.first
            return panel?.captureForVerification() ?? false
        }

        var phaseForVerification: String? {
            switch phase {
            case .visual: "visual"
            case .movement: "movement"
            case .acknowledgement: "acknowledgement"
            case nil: nil
            }
        }

        var remainingSecondsForVerification: Int? {
            switch phase {
            case let .visual(model): model.remainingSeconds
            case let .movement(model): model.remainingSeconds
            case .acknowledgement, nil: nil
            }
        }
    #endif
    func tearDown() {
        refreshCancellation?.cancel()
        refreshCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        phase = nil
        acknowledgementDeadline = nil
        priorProcessIdentifier = nil
        restorationPending = false
        isDismissing = false
    }

    deinit {
        MainActor.assumeIsolated {
            tearDown()
        }
    }
}

extension MergedOverlayCoordinator {
    private func handleVisual(_ action: VisualResetAction) {
        guard case let .visual(model) = phase else { return }
        let event = Self.lifecycleEvent(for: action)
        onLifecycle(event) { [weak self, weak model] result in
            guard let self,
                  let model,
                  case let .visual(activeModel) = phase,
                  activeModel === model
            else {
                return
            }
            switch result {
            case .success:
                switch action {
                case .opened:
                    model.confirmLifecycle(action)
                case .timerFinished, .doneEarly, .skipped:
                    guard model.phase == .finished(action) else { return }
                    model.confirmLifecycle(action)
                    if action == .skipped {
                        dismissAndRestore()
                    } else {
                        presentMovement()
                    }
                }
            case .failure:
                model.rejectLifecycle(action)
            }
        }
    }

    private func handleMovement(_ action: MovementAction) {
        guard case let .movement(model) = phase else { return }
        guard let event = Self.lifecycleEvent(for: action) else {
            model.confirmLifecycle(.opened)
            return
        }
        onLifecycle(event) { [weak self, weak model] result in
            guard let self,
                  let model,
                  case let .movement(activeModel) = phase,
                  activeModel === model
            else {
                return
            }
            switch result {
            case .success:
                completeMovement(action, model: model)
            case .failure:
                model.rejectLifecycle(action)
            }
        }
    }

    private func completeMovement(_ action: MovementAction, model: MovementModel) {
        if let terminal = action.terminal {
            guard model.phase == .finished(terminal) else { return }
        }
        model.confirmLifecycle(action)
        switch action {
        case .selectedDuration, .opened:
            break
        case .visualOnly:
            presentAcknowledgement()
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .skipped:
            dismissAndRestore()
        }
    }

    private func presentMovement() {
        let model = MovementModel(
            schedule: movementSchedule,
            context: .merged,
            requiresLifecycleConfirmation: true,
            now: now,
            onAction: { [weak self] action in self?.handleMovement(action) },
            onAnnouncement: { [weak self] announcement in
                self?.onMovementAnnouncement(announcement)
            },
        )
        phase = .movement(model)
        updatePanelContent(.movement(model))
        model.open()
    }

    private func presentAcknowledgement() {
        let model = BreakFlowModel(
            surface: .visualOnlyAcknowledgement,
            snoozeDurationsSeconds: [movementSchedule.durationOptionsSeconds[0]],
            recoveryDurationsSeconds: Array(movementSchedule.durationOptionsSeconds.prefix(2)),
            acknowledgementDurationSeconds: acknowledgementDurationSeconds,
            onAction: { [weak self] action in self?.handleAcknowledgement(action) },
        )
        phase = .acknowledgement(model)
        acknowledgementDeadline = now() + acknowledgementDurationSeconds
        updatePanelContent(.acknowledgement(model))
    }

    private func handleAcknowledgement(_ action: BreakFlowAction) {
        guard case .acknowledgement = phase,
              action == .acknowledgementFinished
        else {
            return
        }
        dismissAndRestore()
    }

    private func refresh() {
        switch phase {
        case let .visual(model): model.refresh()
        case let .movement(model): model.refresh()
        case let .acknowledgement(model):
            if let acknowledgementDeadline, now() >= acknowledgementDeadline {
                model.acknowledgementDidFinish()
            }
        case nil: break
        }
    }

    private func cancelActiveSegment() {
        switch phase {
        case let .visual(model): model.skip()
        case let .movement(model): model.skip()
        case let .acknowledgement(model): model.acknowledgementDidFinish()
        case nil: break
        }
    }

    private func updatePanelContent(_ content: MergedPanelContent) {
        panels.values.forEach { $0.update(content: content) }
    }

    private func dismissAndRestore() {
        dismissPanels()
        restorePriorApplication()
    }

    private func dismissPanels() {
        guard !isDismissing, phase != nil else { return }
        isDismissing = true
        refreshCancellation?.cancel()
        refreshCancellation = nil
        screenCancellation?.cancel()
        screenCancellation = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        phase = nil
        acknowledgementDeadline = nil
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
        guard let content = activeContent else { return }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        reconcile(to: plan, content: content, presenting: false)
    }

    private var activeContent: MergedPanelContent? {
        switch phase {
        case let .visual(model): .visual(model)
        case let .movement(model): .movement(model)
        case let .acknowledgement(model): .acknowledgement(model)
        case nil: nil
        }
    }

    private func reconcile(
        to plan: OverlayDisplayPlan,
        content: MergedPanelContent,
        presenting: Bool,
    ) {
        let retainedIDs = Set(plan.displays.map(\.id))
        for display in plan.displays {
            if let panel = panels[display.id] {
                panel.update(frame: display.frame)
            } else {
                let panel = makePanel(display, content) { [weak self] in
                    self?.cancelActiveSegment()
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
        if !presenting, isAppFrontmost(), let keyDisplayID = plan.keyDisplayID {
            panels[keyDisplayID]?.makeKey()
        }
    }
}
