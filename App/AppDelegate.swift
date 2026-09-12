import AppKit
import BreakFlow
import Domain
import HeadsUp
import Movement
import Onboarding
import StatusMenu
import VisualReset
import WeeklyRhythm

final class AppDelegate: NSObject, NSApplicationDelegate {
    var runtime: ProtocolRuntime?
    var settingsStore: SwiftDataSettingsStore?
    lazy var settingsIntegrationsRuntime = SettingsIntegrationsAppRuntime.live()
    lazy var settingsTrustCenterRuntime = SettingsTrustCenterAppRuntime.live()
    lazy var settingsSceneModel = buildSettingsSceneModel()
    var settingsWindowController: NSWindowController?
    lazy var appWindowActivationController = AppWindowActivationController.live()
    var onboardingWindowController: OnboardingWindowController?
    var weeklyRhythmWindowController: NSWindowController?
    var weeklyRhythmPresentationOverride: (() -> Bool)?
    var onboardingWindowPresenter: OnboardingWindowPresenter?
    var onboardingModel: OnboardingModel?
    var activitySource: SystemActivitySource?
    var statusItemCoordinator: StatusItemCoordinator?
    var hasInstalledStatusItem: Bool { statusItemCoordinator != nil }
    var dockMenuController: DockMenuController?
    var overlayCoordinator: VisualResetOverlayCoordinator?
    var movementOverlayCoordinator: MovementOverlayCoordinator?
    var mergedOverlayCoordinator: MergedOverlayCoordinator?
    var completionCapsuleCoordinator: CompletionCapsuleCoordinator?
    var breakFlowOverlayCoordinator: BreakFlowOverlayCoordinator?
    var headsUpLifecycleCoordinator: HeadsUpLifecycleCoordinator?
    var headsUpOpeningBinding: HeadsUpOpeningBinding?
    #if DEBUG
        var verificationOverlayCoordinator: VisualResetOverlayCoordinator?
        var headsUpVerificationStore: HeadsUpVerificationRuntimeStore?
        var headsUpVerificationMode: HeadsUpVerificationMode?
        var headsUpVerificationSettings: HeadsUpNotificationSettings?
        var headsUpVerificationPermissionPanel: HeadsUpPermissionPanel?
        var headsUpVerificationCaptureCount = 0
        var automaticTimingVerificationCaptureCount = 0
        var settingsVerificationRouteAccepted: Bool?
    #endif
    var activityTimer: Timer?
    let visualResetLifecycleQueue = VisualResetLifecycleQueue()
    let movementLifecycleQueue = MovementLifecycleQueue()
    let mergedLifecycleQueue = MergedLifecycleQueue()
    var configuration: ProtocolConfiguration?
    var verificationPreviewState: StatusMenuModel.PreviewState?
    private var latestSnapshot = StatusMenuModel.preview(.normal).snapshot
    var headsUpStatusProjection: HeadsUpStatusMenuProjection?
    private var visualResetCaptureCount = 0
    private var movementCaptureCount = 0
    var mergedCaptureCount = 0
    var snoozeCaptureCount = 0
    var lastRuntimeError: Error?

    func applicationDidFinishLaunching(_ notification: Notification) {
        appWindowActivationController.enterMenuBarOnlyMode()
        let arguments = ProcessInfo.processInfo.arguments
        Task { [weak self] in
            guard let self else { return }
            do {
                try await startApplication(arguments: arguments)
            } catch {
                lastRuntimeError = error
            }
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
        completionCapsuleCoordinator?.tearDown()
        breakFlowOverlayCoordinator?.tearDown()
        headsUpLifecycleCoordinator?.tearDown()
        settingsWindowController?.close()
        onboardingWindowController?.close()
        weeklyRhythmWindowController?.close()
        #if DEBUG
            verificationOverlayCoordinator?.tearDown()
            headsUpVerificationPermissionPanel?.close()
        #endif
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool,
    ) -> Bool {
        guard runtime == nil, let onboardingModel, let onboardingWindowPresenter else {
            return false
        }
        onboardingWindowPresenter.present(onboardingModel)
        return true
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
        ManualContextIntentCenter.handler = { [weak runtime] request in
            guard let runtime else { throw ManualContextIntentError.appNotReady }
            switch request {
            case let .start(mode, durationSeconds):
                let until = await MainActor.run {
                    runtime.now().addingTimeInterval(durationSeconds)
                }
                try await runtime.startManualContext(mode: mode, until: until)
                return await MainActor.run { runtime.manualContextHold }
            case .end:
                try await runtime.clearManualContext()
                return nil
            }
        }
        installCompletionCapsule()
        installPrimaryOverlays(configuration: configuration)
        installStepSixOverlays(configuration: configuration)
        installHeadsUpLifecycle(runtime: runtime, policy: headsUpPolicy)
        runtime.onChange = { [weak self] state, context in
            self?.refreshStatus(state: state, context: context)
        }
        runtime.onConfigurationChange = { [weak self] configuration in
            self?.applyRuntimeConfiguration(configuration)
        }
        installSettingsPresentationBoundary(on: runtime)
        runtime.onRoute = { [weak self] action in self?.route(action) }

        if Self.isRunningTests {
            activitySource = nil
        } else {
            activitySource = SystemActivitySource(
                onAvailabilityChange: { [weak self] sample in self?.observe(sample) },
            )
        }
    }

    func installSettingsPresentationBoundary(on runtime: ProtocolRuntime) {
        runtime.settingsPresentationBusyReason = { [weak self] in
            guard self?.activeOverlayFamilies.isEmpty == false else { return nil }
            return .activeBreak
        }
    }

    func installStepSixOverlays(configuration: ProtocolConfiguration) {
        let accessibilityPreferences = runtime?.preferences?.accessibility ?? .defaults
        mergedOverlayCoordinator = MergedOverlayCoordinator(
            visualDurationSeconds: configuration.visual.durationOptionsSeconds[0],
            movementSchedule: configuration.movement,
            accessibilityPreferences: accessibilityPreferences,
            onLifecycle: { [weak self] event, completion in
                guard let self else {
                    completion(.failure(AppDelegateLifecycleError.coordinatorUnavailable))
                    return
                }
                enqueueMerged(event, completion: completion)
            },
            onVisualAnnouncement: VisualResetAccessibilityAnnouncer.post,
            onMovementAnnouncement: MovementAccessibilityAnnouncer.post,
            onCompletion: { [weak self] in self?.presentCompletionAcknowledgement() },
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

    func restore(_ runtime: ProtocolRuntime) async throws {
        if let headsUpLifecycleCoordinator {
            #if DEBUG
                let initialSample = headsUpVerificationMode?.usesInjectedSnapshot == true
                    ? nil
                    : activitySource?.sample()
            #else
                let initialSample = activitySource?.sample()
            #endif
            try await headsUpLifecycleCoordinator.start(
                initialSample: initialSample,
            )
            #if DEBUG
                await runHeadsUpVerificationAfterRestore()
                if headsUpVerificationMode?.usesInjectedSnapshot == true { return }
            #endif
            startActivityTimer()
            return
        }
        try await runtime.restore()
        if let activitySource, !Self.isRunningTests {
            try await runtime.observe(activitySource.sample())
        }
        startActivityTimer()
    }

    func startActivityTimer() {
        activityTimer?.invalidate()
        guard !Self.isRunningTests else {
            activityTimer = nil
            return
        }
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
            let dockStatus = NSApp.currentSystemPresentationOptions.contains(.hideDock)
                ? "hidden"
                : "visible"
            let value = "\(visualResetCaptureCount) \(remainingSeconds) "
                + "\(monotonicSeconds) \(dockStatus)"
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
            let dockStatus = NSApp.currentSystemPresentationOptions.contains(.hideDock)
                ? "hidden"
                : "visible"
            let value = "\(movementCaptureCount) \(remainingSeconds) "
                + "\(selectedDuration) \(runtimeSelectedDuration) \(runtimeStatus) \(dockStatus)"
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

    func applyRuntimeConfiguration(_ configuration: ProtocolConfiguration) {
        self.configuration = configuration
        overlayCoordinator?.tearDown()
        movementOverlayCoordinator?.tearDown()
        mergedOverlayCoordinator?.tearDown()
        completionCapsuleCoordinator?.dismiss()
        breakFlowOverlayCoordinator?.tearDown()
        installPrimaryOverlays(configuration: configuration)
        installStepSixOverlays(configuration: configuration)
        guard let runtime else { return }
        refreshStatus(state: runtime.state, context: runtime.statusContext)
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
            openSettingsWindow()
        case .quit:
            NSApp.terminate(nil)
        case .openWeeklyRhythm:
            _ = openWeeklyRhythmWindow()
        case .startHeadsUpNow, .openSnoozeOptions, .startVisualReset, .startMovement:
            break
        case .snooze, .pause, .resume, .toggleWorkingHours:
            break
        }
    }

    @discardableResult
    func openSettingsWindow() -> Bool {
        if runtime == nil, let onboardingModel, let onboardingWindowPresenter {
            onboardingWindowPresenter.present(onboardingModel)
            return false
        }
        showSettingsWindow(nil)
        return settingsWindowController?.window?.isVisible == true
    }
}
