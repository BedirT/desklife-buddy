import AppKit
import BreakFlow
import CoreGraphics

final class BreakFlowOverlayCoordinator {
    typealias PanelFactory = (
        OverlayDisplay,
        BreakFlowModel,
        @escaping () -> Void,
    ) -> any BreakFlowPanelPresenting
    typealias ScreenObserver = (
        @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation

    private let policy: OverlayDisplayPolicy
    private let snoozeDurationsSeconds: [TimeInterval]
    private let displays: () -> [OverlayDisplay]
    private let makePanel: PanelFactory
    private let captureFrontmostProcessIdentifier: () -> pid_t?
    private let activate: () -> Void
    private let isAppFrontmost: () -> Bool
    private let restore: (pid_t) -> Void
    private let observeScreenChanges: ScreenObserver
    private let onAction: (
        BreakFlowAction,
        @escaping (Result<Void, any Error>) -> Void,
    ) -> Void
    private let onAnnouncement: (BreakFlowAnnouncement) -> Void

    private var panels: [OverlayDisplayID: any BreakFlowPanelPresenting] = [:]
    private var model: BreakFlowModel?
    private var priorProcessIdentifier: pid_t?
    private var screenCancellation: OverlayCancellation?
    private var isDismissing = false
    private var restorationPending = false

    init(
        policy: OverlayDisplayPolicy = .allDisplays,
        snoozeDurationsSeconds: [TimeInterval],
        displays: @escaping () -> [OverlayDisplay],
        makePanel: @escaping PanelFactory,
        captureFrontmostProcessIdentifier: @escaping () -> pid_t?,
        activate: @escaping () -> Void,
        isAppFrontmost: @escaping () -> Bool,
        restore: @escaping (pid_t) -> Void,
        observeScreenChanges: @escaping ScreenObserver,
        onAction: @escaping (
            BreakFlowAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (BreakFlowAnnouncement) -> Void = { _ in },
    ) {
        self.policy = policy
        self.snoozeDurationsSeconds = snoozeDurationsSeconds
        self.displays = displays
        self.makePanel = makePanel
        self.captureFrontmostProcessIdentifier = captureFrontmostProcessIdentifier
        self.activate = activate
        self.isAppFrontmost = isAppFrontmost
        self.restore = restore
        self.observeScreenChanges = observeScreenChanges
        self.onAction = onAction
        self.onAnnouncement = onAnnouncement
    }

    convenience init(
        policy: OverlayDisplayPolicy = .allDisplays,
        snoozeDurationsSeconds: [TimeInterval] = [300, 600, 900],
        onAction: @escaping (
            BreakFlowAction,
            @escaping (Result<Void, any Error>) -> Void,
        ) -> Void,
        onAnnouncement: @escaping (BreakFlowAnnouncement) -> Void = { _ in },
    ) {
        self.init(
            policy: policy,
            snoozeDurationsSeconds: snoozeDurationsSeconds,
            displays: AppKitOverlayDisplays.current,
            makePanel: { display, model, onCancel in
                BreakFlowPanel(
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
            observeScreenChanges: VisualResetOverlayCoordinator.observeScreenChanges,
            onAction: onAction,
            onAnnouncement: onAnnouncement,
        )
    }

    func presentSnooze(scope: BreakScope) {
        guard model == nil else { return }
        let plan = OverlayDisplayPlan.resolve(displays(), policy: policy)
        guard !plan.displays.isEmpty else { return }

        priorProcessIdentifier = captureFrontmostProcessIdentifier()
        let model = BreakFlowModel(
            surface: .snooze(scope: scope, calendarEnd: nil),
            snoozeDurationsSeconds: snoozeDurationsSeconds,
            recoveryDurationsSeconds: [300, 600],
            onAction: { [weak self] action in self?.handle(action) },
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
        screenCancellation = observeScreenChanges { [weak self] in
            self?.screenParametersChanged()
        }
    }

    var isPresenting: Bool {
        model != nil
    }

    #if DEBUG
        @discardableResult
        func captureForVerification() -> Bool {
            let livePanels = panels.values.compactMap { $0 as? BreakFlowPanel }
            let panel = livePanels.first(where: \.isKeyWindow) ?? livePanels.first
            return panel?.captureForVerification() ?? false
        }

        var scopeForVerification: String? {
            guard case let .snooze(scope, _) = model?.surface else { return nil }
            return switch scope {
            case .visual: "visual"
            case .movement: "movement"
            case .merged: "merged"
            }
        }
    #endif

    func tearDown() {
        screenCancellation?.cancel()
        screenCancellation = nil
        panels.values.forEach { $0.close() }
        panels.removeAll()
        model = nil
        priorProcessIdentifier = nil
        restorationPending = false
        isDismissing = false
    }

    private func handle(_ action: BreakFlowAction) {
        guard let actionModel = model else { return }
        onAction(action) { [weak self, weak actionModel] result in
            guard let self,
                  let actionModel,
                  model === actionModel
            else {
                return
            }
            switch result {
            case .success:
                actionModel.confirmPersistence(action)
                if let announcement = Self.announcement(for: action) {
                    onAnnouncement(announcement)
                }
                dismissPanels()
                restorePriorApplication()
            case .failure:
                actionModel.rejectPersistence(action)
            }
        }
    }

    private static func announcement(for action: BreakFlowAction) -> BreakFlowAnnouncement? {
        switch action {
        case let .snooze(_, durationSeconds):
            .snoozed(minutes: Int(durationSeconds / 60))
        case .pauseOneHour:
            .pausedOneHour
        case .notAppropriate:
            .notedForSession
        case .skip:
            .skipped
        case .acknowledgementFinished, .snoozeUntil, .chooseRecovery, .dismissRecovery:
            nil
        }
    }

    private func dismissPanels() {
        guard !isDismissing, model != nil else { return }
        isDismissing = true
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
        model: BreakFlowModel,
        presenting: Bool,
    ) {
        let retainedIDs = Set(plan.displays.map(\.id))
        for display in plan.displays {
            if let panel = panels[display.id] {
                panel.update(frame: display.frame)
            } else {
                let panel = makePanel(display, model) { [weak model] in
                    model?.send(.skip)
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

    deinit {
        MainActor.assumeIsolated {
            tearDown()
        }
    }
}
