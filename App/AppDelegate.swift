import AppKit
import Domain
import Movement
import StatusMenu
import VisualReset

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var runtime: ProtocolRuntime?
    private var activitySource: SystemActivitySource?
    private var statusItemCoordinator: StatusItemCoordinator?
    private var dockMenuController: DockMenuController?
    private var overlayCoordinator: VisualResetOverlayCoordinator?
    private var movementOverlayCoordinator: MovementOverlayCoordinator?
    #if DEBUG
        private var verificationOverlayCoordinator: VisualResetOverlayCoordinator?
    #endif
    private var activityTimer: Timer?
    private let visualResetLifecycleQueue = VisualResetLifecycleQueue()
    private let movementLifecycleQueue = MovementLifecycleQueue()
    private var configuration: ProtocolConfiguration?
    private var verificationPreviewState: StatusMenuModel.PreviewState?
    private var latestSnapshot = StatusMenuModel.preview(.normal).snapshot
    private var visualResetCaptureCount = 0
    private var movementCaptureCount = 0
    private(set) var lastRuntimeError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let configuration = try ProtocolProfiles.configuration(for: .balanced)
            let runtime = try ProtocolRuntime(
                configuration: configuration,
                store: SwiftDataProtocolStore(
                    inMemory: Self.isRunningTests || Self.isVerificationRun,
                ),
            )
            install(configuration: configuration, runtime: runtime)
            restore(runtime)
        } catch {
            lastRuntimeError = error
        }
    }

    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        dockMenuController?.makeMenu(snapshot: latestSnapshot)
    }

    func applicationWillTerminate(_ notification: Notification) {
        activityTimer?.invalidate()
        overlayCoordinator?.tearDown()
        movementOverlayCoordinator?.tearDown()
        #if DEBUG
            verificationOverlayCoordinator?.tearDown()
        #endif
    }
}

private extension AppDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isVerificationRun: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--verify-") }
    }
}

private extension AppDelegate {
    func install(configuration: ProtocolConfiguration, runtime: ProtocolRuntime) {
        let arguments = ProcessInfo.processInfo.arguments
        verificationPreviewState = Self.verificationState(from: arguments)
        self.configuration = configuration
        self.runtime = runtime
        overlayCoordinator = VisualResetOverlayCoordinator(
            durationSeconds: configuration.visual.durationOptionsSeconds[0],
            onLifecycle: { [weak self] action in self?.enqueueVisualReset(action) },
            onAnnouncement: VisualResetAccessibilityAnnouncer.post,
        )
        movementOverlayCoordinator = MovementOverlayCoordinator(
            schedule: configuration.movement,
            onLifecycle: { [weak self] action, completion in
                self?.enqueueMovement(action, completion: completion)
            },
            onAnnouncement: MovementAccessibilityAnnouncer.post,
        )
        runtime.onChange = { [weak self] state, context in
            self?.refreshStatus(state: state, context: context)
        }
        runtime.onRoute = { [weak self] action in self?.route(action) }

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
        configureVerification(arguments: arguments)
    }

    func restore(_ runtime: ProtocolRuntime) {
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
    }

    func configureVerification(arguments: [String]) {
        #if DEBUG
            if arguments.contains("--verify-status-menu") {
                addVerificationTimer(delay: 1, selector: #selector(openVerificationMenu))
                for delay in [2.0, 2.4, 2.8, 3.2] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationMenu))
                }
            }
            if arguments.contains("--verify-visual-reset") {
                let coordinator = VisualResetOverlayCoordinator(
                    durationSeconds: configuration?.visual.durationOptionsSeconds[0] ?? 20,
                    onLifecycle: { _ in },
                    onAnnouncement: VisualResetAccessibilityAnnouncer.post,
                )
                verificationOverlayCoordinator = coordinator
                coordinator.present()
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(
                        delay: delay,
                        selector: #selector(captureVerificationVisualReset),
                    )
                }
            }
            if arguments.contains("--verify-movement") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationMovement))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(
                        delay: delay,
                        selector: #selector(captureVerificationMovement),
                    )
                }
            }
        #endif
    }

    func addVerificationTimer(delay: TimeInterval, selector: Selector) {
        let timer = Timer(
            timeInterval: delay,
            target: self,
            selector: selector,
            userInfo: nil,
            repeats: false,
        )
        RunLoop.main.add(timer, forMode: .common)
    }

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

    @objc func openVerificationMovement() {
        handle(.startMovement(.recommended))
    }

    #if DEBUG
        @objc func captureVerificationMenu() {
            _ = statusItemCoordinator?.captureMenuForVerification()
        }

        @objc func captureVerificationVisualReset() {
            guard let coordinator = verificationOverlayCoordinator,
                  let remainingSeconds = coordinator.remainingSecondsForVerification,
                  let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else {
                return
            }
            visualResetCaptureCount += 1
            let state = caches.appendingPathComponent(
                "visual-reset-state-\(ProcessInfo.processInfo.processIdentifier).txt",
            )
            let monotonicSeconds = coordinator.monotonicSecondsForVerification
            let value = "\(visualResetCaptureCount) \(remainingSeconds) \(monotonicSeconds)"
            try? value.write(to: state, atomically: true, encoding: .utf8)
            _ = coordinator.captureForVerification()
        }

        @objc func captureVerificationMovement() {
            guard let coordinator = movementOverlayCoordinator,
                  let remainingSeconds = coordinator.remainingSecondsForVerification,
                  let selectedDuration = coordinator.selectedDurationForVerification,
                  let runtimeSelectedDuration = runtime?.movementSessionDurationForVerification,
                  let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            else {
                return
            }
            movementCaptureCount += 1
            let state = caches.appendingPathComponent(
                "movement-state-\(ProcessInfo.processInfo.processIdentifier).txt",
            )
            let runtimeStatus = lastRuntimeError == nil ? "ok" : "error"
            let value = "\(movementCaptureCount) \(remainingSeconds) "
                + "\(selectedDuration) \(runtimeSelectedDuration) \(runtimeStatus)"
            try? value.write(to: state, atomically: true, encoding: .utf8)
            _ = coordinator.captureForVerification()
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
        case .startVisualReset:
            overlayCoordinator?.present()
        case let .startMovement(choice):
            let selectedDuration: TimeInterval? = switch choice {
            case .recommended:
                configuration?.movement.durationOptionsSeconds.first
            case .quick:
                configuration?.movement.durationOptionsSeconds.dropFirst().first
            case .positionChange:
                nil
            }
            movementOverlayCoordinator?.present(selectedDurationSeconds: selectedDuration)
        case .startHeadsUpNow, .openWeeklyRhythm:
            NSApp.activate()
            NotificationCenter.default.post(name: .statusMenuRoute, object: action)
        case .snooze, .pause, .resume, .toggleWorkingHours:
            break
        }
    }

    func enqueueVisualReset(_ action: VisualResetAction) {
        let event: VisualResetLifecycleEvent = switch action {
        case .opened: .opened
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .skipped: .skipped
        }
        visualResetLifecycleQueue.enqueue(
            event,
            operation: { [weak self] event in
                guard let self, let runtime else { return }
                try await runtime.handleVisualReset(event)
            },
            onFailure: { [weak self] error in self?.lastRuntimeError = error },
        )
    }

    func enqueueMovement(
        _ action: MovementAction,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        let event: MovementLifecycleEvent = switch action {
        case .opened: .opened
        case let .selectedDuration(duration): .selectedDuration(duration)
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .alreadyMoved: .alreadyMoved
        case .positionChanged: .positionChanged
        case .skipped: .skipped
        }
        movementLifecycleQueue.enqueue(
            event,
            operation: { [weak self] event in
                guard let self, let runtime else { return }
                try await runtime.handleMovement(event)
            },
            onFailure: { [weak self] error in self?.lastRuntimeError = error },
            completion: completion,
        )
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
