import StatusMenu

extension AppDelegate {
    func publishOperatingSurfaces(arguments: [String]) {
        guard let runtime, let configuration else { return }
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
        configureVerification(arguments: arguments)
    }

    func discardFailedRuntimeInstallation() {
        activityTimer?.invalidate()
        activityTimer = nil
        overlayCoordinator?.tearDown()
        overlayCoordinator = nil
        movementOverlayCoordinator?.tearDown()
        movementOverlayCoordinator = nil
        mergedOverlayCoordinator?.tearDown()
        mergedOverlayCoordinator = nil
        completionCapsuleCoordinator?.tearDown()
        completionCapsuleCoordinator = nil
        breakFlowOverlayCoordinator?.tearDown()
        breakFlowOverlayCoordinator = nil
        headsUpLifecycleCoordinator?.tearDown()
        headsUpLifecycleCoordinator = nil
        headsUpOpeningBinding = nil
        statusItemCoordinator = nil
        dockMenuController = nil
        activitySource = nil
        runtime = nil
        configuration = nil
        headsUpStatusProjection = nil
    }
}
