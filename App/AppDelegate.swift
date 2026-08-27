import AppKit
import BreakFlow
import Domain
import HeadsUp
import Movement
import StatusMenu
import VisualReset

final class AppDelegate: NSObject, NSApplicationDelegate {
    var runtime: ProtocolRuntime?
    private var activitySource: SystemActivitySource?
    private var statusItemCoordinator: StatusItemCoordinator?
    private var dockMenuController: DockMenuController?
    var overlayCoordinator: VisualResetOverlayCoordinator?
    var movementOverlayCoordinator: MovementOverlayCoordinator?
    var mergedOverlayCoordinator: MergedOverlayCoordinator?
    var breakFlowOverlayCoordinator: BreakFlowOverlayCoordinator?
    var headsUpLifecycleCoordinator: HeadsUpLifecycleCoordinator?
    var headsUpOpeningBinding: HeadsUpOpeningBinding?
    #if DEBUG
        private var verificationOverlayCoordinator: VisualResetOverlayCoordinator?
    #endif
    private var activityTimer: Timer?
    let visualResetLifecycleQueue = VisualResetLifecycleQueue()
    let movementLifecycleQueue = MovementLifecycleQueue()
    let mergedLifecycleQueue = MergedLifecycleQueue()
    var configuration: ProtocolConfiguration?
    private var verificationPreviewState: StatusMenuModel.PreviewState?
    private var latestSnapshot = StatusMenuModel.preview(.normal).snapshot
    private var headsUpStatusProjection: HeadsUpStatusMenuProjection?
    private var visualResetCaptureCount = 0
    private var movementCaptureCount = 0
    var mergedCaptureCount = 0
    var snoozeCaptureCount = 0
    var lastRuntimeError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let configuration = try ProtocolProfiles.configuration(for: .balanced)
            let store = try SwiftDataProtocolStore(
                inMemory: Self.isRunningTests || Self.isVerificationRun,
            )
            let headsUpPolicy = Self.verificationHeadsUpPolicy(
                arguments: ProcessInfo.processInfo.arguments,
            )
            let runtime = if let headsUpPolicy {
                ProtocolRuntime(
                    configuration: configuration,
                    store: store,
                    headsUpRuntimePolicy: headsUpPolicy,
                )
            } else {
                ProtocolRuntime(configuration: configuration, store: store)
            }
            install(
                configuration: configuration,
                runtime: runtime,
                headsUpPolicy: headsUpPolicy,
            )
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
        mergedOverlayCoordinator?.tearDown()
        breakFlowOverlayCoordinator?.tearDown()
        headsUpLifecycleCoordinator?.tearDown()
        #if DEBUG
            verificationOverlayCoordinator?.tearDown()
        #endif
    }
}

extension AppDelegate {
    func install(
        configuration: ProtocolConfiguration,
        runtime: ProtocolRuntime,
        headsUpPolicy: HeadsUpRuntimePolicy?,
    ) {
        let arguments = ProcessInfo.processInfo.arguments
        verificationPreviewState = Self.verificationState(from: arguments)
        self.configuration = configuration
        self.runtime = runtime
        installPrimaryOverlays(configuration: configuration)
        installStepSixOverlays(configuration: configuration)
        installHeadsUpLifecycle(runtime: runtime, policy: headsUpPolicy)
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
            headsUpProjection: headsUpStatusProjection,
            onAction: { [weak self] action in self?.handle(action) },
            onHeadsUpIntent: { [weak self] intent in
                self?.headsUpLifecycleCoordinator?.send(intent)
            },
        )
        dockMenuController = DockMenuController(
            onAction: { [weak self] action in self?.handle(action) },
        )
        activitySource = SystemActivitySource(
            onAvailabilityChange: { [weak self] sample in self?.observe(sample) },
        )
        configureVerification(arguments: arguments)
    }

    func installStepSixOverlays(configuration: ProtocolConfiguration) {
        mergedOverlayCoordinator = MergedOverlayCoordinator(
            visualDurationSeconds: configuration.visual.durationOptionsSeconds[0],
            movementSchedule: configuration.movement,
            onLifecycle: { [weak self] event, completion in
                guard let self else {
                    completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                    return
                }
                enqueueMerged(event, completion: completion)
            },
            onVisualAnnouncement: VisualResetAccessibilityAnnouncer.post,
            onMovementAnnouncement: MovementAccessibilityAnnouncer.post,
        )
        breakFlowOverlayCoordinator = BreakFlowOverlayCoordinator(
            snoozeDurationsSeconds: configuration.delivery.snoozeOptionsSeconds,
            onAction: { [weak self] action, completion in
                guard let self else {
                    completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                    return
                }
                enqueueBreakFlow(action, completion: completion)
            },
            onAnnouncement: BreakFlowAccessibilityAnnouncer.post,
        )
    }

    func restore(_ runtime: ProtocolRuntime) {
        Task { [weak self] in
            guard let self else { return }
            if let headsUpLifecycleCoordinator {
                await headsUpLifecycleCoordinator.start(
                    initialSample: activitySource?.sample(),
                )
                startActivityTimer()
                return
            }
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
                    onLifecycle: { _, completion in completion(.success(())) },
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
            if arguments.contains("--verify-merged") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationMerged))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationMerged))
                }
            }
            if arguments.contains("--verify-snooze") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationSnooze))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationSnooze))
                }
            }
        #endif
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
        if let headsUpLifecycleCoordinator {
            headsUpLifecycleCoordinator.observe(sample)
            return
        }
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
        statusItemCoordinator?.update(
            model: model,
            headsUpProjection: headsUpStatusProjection,
        )
    }

    func updateHeadsUpStatusProjection(_ projection: HeadsUpStatusMenuProjection?) {
        headsUpStatusProjection = projection
        guard let runtime, let configuration else { return }
        let model = verificationPreviewState.map(StatusMenuModel.preview)
            ?? StatusMenuModel(
                state: runtime.state,
                configuration: configuration,
                context: runtime.statusContext,
            )
        statusItemCoordinator?.update(
            model: model,
            headsUpProjection: projection,
        )
    }

    func route(_ action: StatusMenuAction) {
        if let overlayRoute = AppOverlayRoute.resolve(
            action: action,
            liveHeadsUp: runtime?.statusContext.liveHeadsUp,
        ) {
            present(overlayRoute, for: action)
            return
        }

        switch action {
        case .openSettings:
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            NSApp.activate()
        case .quit:
            NSApp.terminate(nil)
        case .openWeeklyRhythm:
            NSApp.activate()
            NotificationCenter.default.post(name: .statusMenuRoute, object: action)
        case .startHeadsUpNow, .openSnoozeOptions, .startVisualReset, .startMovement:
            break
        case .snooze, .pause, .resume, .toggleWorkingHours:
            break
        }
    }

}
