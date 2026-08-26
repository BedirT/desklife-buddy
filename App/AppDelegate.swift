import AppKit
import Domain
import StatusMenu

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: ProtocolRuntime?
    private var activitySource: SystemActivitySource?
    private var statusItemCoordinator: StatusItemCoordinator?
    private var dockMenuController: DockMenuController?
    private var activityTimer: Timer?
    private var configuration: ProtocolConfiguration?
    private var latestSnapshot = StatusMenuModel.preview(.normal).snapshot
    private(set) var lastRuntimeError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let configuration = try ProtocolProfiles.configuration(for: .balanced)
            let runtime = try ProtocolRuntime(
                configuration: configuration,
                store: SwiftDataProtocolStore(),
            )
            self.configuration = configuration
            self.runtime = runtime

            runtime.onChange = { [weak self] state, context in
                self?.refreshStatus(state: state, context: context)
            }
            runtime.onRoute = { [weak self] action in
                self?.route(action)
            }

            let initialModel = StatusMenuModel(
                state: runtime.state,
                configuration: configuration,
                context: runtime.statusContext,
            )
            statusItemCoordinator = StatusItemCoordinator(
                model: initialModel,
                onAction: { [weak self] action in self?.handle(action) },
            )
            dockMenuController = DockMenuController(
                onAction: { [weak self] action in self?.handle(action) },
            )

            activitySource = SystemActivitySource(
                onAvailabilityChange: { [weak self] sample in self?.observe(sample) },
            )

            Task { [weak self] in
                guard let self else { return }
                do {
                    try await runtime.restore()
                    if let activitySource {
                        try await runtime.observe(activitySource.sample())
                    }
                    startActivityTimer()
                } catch {
                    lastRuntimeError = error
                }
            }
        } catch {
            lastRuntimeError = error
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        dockMenuController?.makeMenu(snapshot: latestSnapshot)
    }

    func applicationWillTerminate(_ notification: Notification) {
        activityTimer?.invalidate()
    }
}

private extension AppDelegate {
    func startActivityTimer() {
        activityTimer?.invalidate()
        activityTimer = Timer.scheduledTimer(
            timeInterval: 5,
            target: self,
            selector: #selector(activityTimerFired),
            userInfo: nil,
            repeats: true,
        )
    }

    @objc func activityTimerFired() {
        guard let activitySource else { return }
        observe(activitySource.sample())
    }

    func observe(_ sample: ActivitySample) {
        guard let runtime else { return }
        Task { [weak self] in
            do {
                try await runtime.observe(sample)
            } catch {
                self?.lastRuntimeError = error
            }
        }
    }

    func handle(_ action: StatusMenuAction) {
        guard let runtime else { return }
        Task { [weak self] in
            do {
                try await runtime.handle(action)
            } catch {
                self?.lastRuntimeError = error
            }
        }
    }

    func refreshStatus(state: ProtocolState, context: StatusMenuContext) {
        guard let configuration else { return }
        let model = StatusMenuModel(
            state: state,
            configuration: configuration,
            context: context,
        )
        latestSnapshot = model.snapshot
        statusItemCoordinator?.update(model: model)
    }

    func route(_ action: StatusMenuAction) {
        switch action {
        case .openSettings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate()
        case .quit:
            NSApp.terminate(nil)
        case .startHeadsUpNow, .startVisualReset, .startMovement, .openWeeklyRhythm:
            NSApp.activate()
            NotificationCenter.default.post(name: .statusMenuRoute, object: action)
        case .snooze, .pause, .resume, .toggleWorkingHours:
            break
        }
    }
}

extension Notification.Name {
    static let statusMenuRoute = Notification.Name("app.statusMenuRoute")
}
