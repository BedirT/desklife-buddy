import AppKit
import CoreGraphics
import HeadsUp
import Observation

struct HeadsUpCapsulePresentation {
    let deliveryID: UUID
    let model: HeadsUpModel
}

private struct HeadsUpCapsuleLayoutObservationIdentity: Equatable {
    let deliveryID: UUID
    let modelID: ObjectIdentifier
}

final class HeadsUpCapsuleCoordinator: HeadsUpCapsulePresenting {
    typealias PanelFactory = (
        HeadsUpDisplayID,
        CGRect,
        HeadsUpModel,
        @escaping () -> Void,
    ) -> any HeadsUpCapsulePanelPresenting
    typealias ScreenObserver = (
        @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation
    typealias NotificationModel = (HeadsUpNotificationRequest) -> HeadsUpModel?
    typealias EscapeHandler = (
        UUID,
        @escaping (Result<Void, any Error>) -> Void,
    ) -> Void

    private let screens: () -> [HeadsUpScreen]
    private let pointerLocation: () -> CGPoint
    private let contentSize: (HeadsUpModel) -> CGSize
    private let makePanel: PanelFactory
    private let observeScreenChanges: ScreenObserver
    private let onEscape: EscapeHandler
    private let notificationModel: NotificationModel?

    private var activePresentation: HeadsUpCapsulePresentation?
    private var panel: (any HeadsUpCapsulePanelPresenting)?
    private var screenCancellation: OverlayCancellation?
    private var pendingEscapeDeliveryID: UUID?
    private var layoutObservationGeneration = 0
    private var layoutObservationIdentity: HeadsUpCapsuleLayoutObservationIdentity?
    private(set) var layoutObservationRegistrationCount = 0

    var activeDeliveryID: UUID? { activePresentation?.deliveryID }

    init(
        screens: @escaping () -> [HeadsUpScreen],
        pointerLocation: @escaping () -> CGPoint,
        contentSize: @escaping (HeadsUpModel) -> CGSize,
        makePanel: @escaping PanelFactory,
        observeScreenChanges: @escaping ScreenObserver,
        onEscape: @escaping EscapeHandler,
        notificationModel: NotificationModel? = nil,
    ) {
        self.screens = screens
        self.pointerLocation = pointerLocation
        self.contentSize = contentSize
        self.makePanel = makePanel
        self.observeScreenChanges = observeScreenChanges
        self.onEscape = onEscape
        self.notificationModel = notificationModel
    }

    convenience init(
        onEscape: @escaping EscapeHandler,
        notificationModel: NotificationModel? = nil,
    ) {
        self.init(
            screens: AppKitHeadsUpScreens.current,
            pointerLocation: { NSEvent.mouseLocation },
            contentSize: HeadsUpCapsulePanel.fittingSize,
            makePanel: { displayID, frame, model, onPanelEscape in
                HeadsUpCapsulePanel(
                    displayID: displayID,
                    frame: frame,
                    model: model,
                    onEscape: onPanelEscape,
                )
            },
            observeScreenChanges: Self.observeLiveScreenChanges,
            onEscape: onEscape,
            notificationModel: notificationModel,
        )
    }

    @discardableResult
    func present(_ presentation: HeadsUpCapsulePresentation) -> Bool {
        if activePresentation?.deliveryID != presentation.deliveryID {
            pendingEscapeDeliveryID = nil
            closePanel()
        }
        activePresentation = presentation
        observeLayoutChanges(for: presentation)
        ensureScreenObservation()
        let didPresent = reconcilePresentation()
        if !didPresent {
            tearDown()
        }
        return didPresent
    }

    func present(
        deliveryID: UUID,
        content: HeadsUpNotificationRequest,
    ) async throws -> Bool {
        guard content.deliveryID == deliveryID,
              let model = notificationModel?(content)
        else {
            return false
        }
        return present(HeadsUpCapsulePresentation(deliveryID: deliveryID, model: model))
    }

    func dismiss(deliveryID: UUID) {
        guard activePresentation?.deliveryID == deliveryID else { return }
        tearDown()
    }

    func tearDown() {
        layoutObservationGeneration &+= 1
        layoutObservationIdentity = nil
        closePanel()
        activePresentation = nil
        pendingEscapeDeliveryID = nil
        screenCancellation?.cancel()
        screenCancellation = nil
    }

    private func ensureScreenObservation() {
        guard screenCancellation == nil else { return }
        screenCancellation = observeScreenChanges { [weak self] in
            _ = self?.reconcilePresentation()
        }
    }

    private func observeLayoutChanges(for presentation: HeadsUpCapsulePresentation) {
        let identity = HeadsUpCapsuleLayoutObservationIdentity(
            deliveryID: presentation.deliveryID,
            modelID: ObjectIdentifier(presentation.model),
        )
        guard layoutObservationIdentity != identity else { return }
        layoutObservationIdentity = identity
        layoutObservationRegistrationCount += 1
        layoutObservationGeneration &+= 1
        let generation = layoutObservationGeneration
        let deliveryID = presentation.deliveryID
        let modelID = ObjectIdentifier(presentation.model)

        withObservationTracking {
            _ = presentation.model.isHovered
            _ = presentation.model.presentationPhase
            _ = presentation.model.pendingPersistenceIntent
            _ = presentation.model.isFinished
        } onChange: { [weak self] in
            Task { [weak self] in
                await self?.handleLayoutChange(
                    deliveryID: deliveryID,
                    modelID: modelID,
                    generation: generation,
                )
            }
        }
    }

    private func handleLayoutChange(
        deliveryID: UUID,
        modelID: ObjectIdentifier,
        generation: Int,
    ) {
        guard generation == layoutObservationGeneration,
              let presentation = activePresentation,
              presentation.deliveryID == deliveryID,
              ObjectIdentifier(presentation.model) == modelID
        else {
            return
        }

        layoutObservationIdentity = nil
        observeLayoutChanges(for: presentation)
        _ = reconcilePresentation()
    }

    @discardableResult
    private func reconcilePresentation() -> Bool {
        guard let presentation = activePresentation else { return false }

        // The pointer sample stays inside this reconciliation and is never retained.
        let currentScreens = screens()
        let pointer = pointerLocation()
        guard let screen = HeadsUpScreenResolver.targetScreen(
            in: currentScreens,
            pointerLocation: pointer,
        ) else {
            closePanel()
            return false
        }
        let placement = HeadsUpCapsuleGeometry.placement(
            on: screen,
            contentSize: contentSize(presentation.model),
        )

        if let panel, panel.displayID == screen.id {
            panel.update(frame: placement.frame, model: presentation.model)
            return true
        }

        closePanel()
        let deliveryID = presentation.deliveryID
        let newPanel = makePanel(
            screen.id,
            placement.frame,
            presentation.model,
            { [weak self] in self?.handleEscape(deliveryID: deliveryID) },
        )
        panel = newPanel
        newPanel.presentWithoutActivation()
        return true
    }

    private func handleEscape(deliveryID: UUID) {
        guard activePresentation?.deliveryID == deliveryID,
              pendingEscapeDeliveryID == nil
        else {
            return
        }
        pendingEscapeDeliveryID = deliveryID
        onEscape(deliveryID) { [weak self] result in
            guard let self,
                  pendingEscapeDeliveryID == deliveryID,
                  activePresentation?.deliveryID == deliveryID
            else {
                return
            }
            pendingEscapeDeliveryID = nil
            guard case .success = result else { return }
            tearDown()
        }
    }

    private func closePanel() {
        panel?.close()
        panel = nil
    }

    deinit {
        MainActor.assumeIsolated { tearDown() }
    }
}

extension HeadsUpCapsuleCoordinator {
    static func observeLiveScreenChanges(
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        observeLiveScreenChanges(
            applicationNotifications: .default,
            workspaceNotifications: NSWorkspace.shared.notificationCenter,
            screenParametersObject: NSApplication.shared,
            action,
        )
    }

    static func observeLiveScreenChanges(
        applicationNotifications: NotificationCenter,
        workspaceNotifications: NotificationCenter,
        screenParametersObject: Any?,
        _ action: @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation {
        let applicationToken = applicationNotifications.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: screenParametersObject,
            queue: .main,
        ) { _ in
            MainActor.assumeIsolated { action() }
        }
        let workspaceToken = workspaceNotifications.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main,
        ) { _ in
            MainActor.assumeIsolated { action() }
        }
        return OverlayCancellation {
            applicationNotifications.removeObserver(applicationToken)
            workspaceNotifications.removeObserver(workspaceToken)
        }
    }
}

enum AppKitHeadsUpScreens {
    static func current() -> [HeadsUpScreen] {
        NSScreen.screens.map { screen in
            let fallbackID = HeadsUpDisplayID.fallback(ObjectIdentifier(screen))
            let id = screen.cgDirectDisplayID.map(HeadsUpDisplayID.direct) ?? fallbackID
            let mirrorRootID: HeadsUpDisplayID
            if let directID = screen.cgDirectDisplayID {
                let mirroredDisplay = CGDisplayMirrorsDisplay(directID)
                mirrorRootID = mirroredDisplay == kCGNullDirectDisplay
                    ? .direct(directID)
                    : .direct(mirroredDisplay)
            } else {
                mirrorRootID = fallbackID
            }
            return HeadsUpScreen(
                id: id,
                mirrorRootID: mirrorRootID,
                frame: screen.frame,
                visibleFrame: screen.visibleFrame,
                safeAreaTopInset: screen.safeAreaInsets.top,
                auxiliaryTopLeftArea: screen.auxiliaryTopLeftArea,
                auxiliaryTopRightArea: screen.auxiliaryTopRightArea,
                isMain: screen == NSScreen.main,
            )
        }
    }
}
