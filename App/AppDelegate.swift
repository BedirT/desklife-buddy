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
    private var verificationPreviewState: StatusMenuModel.PreviewState?
    private var latestSnapshot = StatusMenuModel.preview(.normal).snapshot
    private(set) var lastRuntimeError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            verificationPreviewState = Self.verificationState(from: ProcessInfo.processInfo.arguments)
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

            let initialModel = verificationPreviewState.map(StatusMenuModel.preview)
                ?? StatusMenuModel(
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

            #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--verify-status-menu") {
                    let openTimer = Timer(
                        timeInterval: 1,
                        target: self,
                        selector: #selector(openVerificationMenu),
                        userInfo: nil,
                        repeats: false,
                    )
                    RunLoop.main.add(openTimer, forMode: .common)

                    for delay in [2.0, 2.4, 2.8, 3.2] {
                        let captureTimer = Timer(
                            timeInterval: delay,
                            target: self,
                            selector: #selector(captureVerificationMenu),
                            userInfo: nil,
                            repeats: false,
                        )
                        RunLoop.main.add(captureTimer, forMode: .common)
                    }
                }
            #endif

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

    @objc func openVerificationMenu() {
        statusItemCoordinator?.openMenuForVerification()
    }

    #if DEBUG
        @objc func captureVerificationMenu() {
            _ = statusItemCoordinator?.captureMenuForVerification()
        }
    #endif

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
        let model = verificationPreviewState.map(StatusMenuModel.preview)
            ?? StatusMenuModel(
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

    static func verificationState(from arguments: [String]) -> StatusMenuModel.PreviewState? {
        #if DEBUG
            guard let index = arguments.firstIndex(of: "--verify-status-state"),
                  arguments.indices.contains(index + 1)
            else {
                return nil
            }
            return switch arguments[index + 1] {
            case "operating": .normal
            case "visual-due": .visualDue
            case "movement-due": .movementDue
            case "both-due": .bothDue
            case "paused": .paused
            case "timed-pause": .timedPause
            default: nil
            }
        #else
            nil
        #endif
    }
}

extension Notification.Name {
    static let statusMenuRoute = Notification.Name("app.statusMenuRoute")
}
