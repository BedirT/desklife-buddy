import Domain
import HeadsUp

enum HeadsUpLifecycleComposition {
    static func makeIfConfigured(
        policy: HeadsUpRuntimePolicy?,
        make: () -> HeadsUpLifecycleCoordinator,
    ) -> HeadsUpLifecycleCoordinator? {
        guard policy != nil else { return nil }
        return make()
    }

    static func makeLive(
        runtime: ProtocolRuntime,
        authorizationStore: (any HeadsUpAuthorizationStore)? = nil,
        presentBreak: @escaping HeadsUpLifecycleCoordinator.BreakPresenter,
        presentMoreOptions: @escaping HeadsUpLifecycleCoordinator.MoreOptionsPresenter,
        onStatusProjection: @escaping (HeadsUpStatusMenuProjection?) -> Void,
        onError: @escaping (any Error) -> Void,
    ) -> HeadsUpLifecycleCoordinator {
        let relay = HeadsUpLifecycleRelay()
        let bridge = HeadsUpNotificationDelegateBridge { envelope in
            relay.coordinator?.receive(envelope)
        }
        let center = UNUserNotificationCenterAdapter(delegateBridge: bridge)
        let capsule = HeadsUpCapsuleCoordinator(
            onEscape: { deliveryID, completion in
                guard let coordinator = relay.coordinator else {
                    completion(.failure(HeadsUpLifecycleError.coordinatorUnavailable))
                    return
                }
                coordinator.handleCapsuleEscape(
                    deliveryID: deliveryID,
                    completion: completion,
                )
            },
            notificationModel: { request in
                relay.coordinator?.modelForCapsule(
                    deliveryID: request.deliveryID,
                    content: request,
                )
            },
        )
        let coordinator = HeadsUpLifecycleCoordinator(
            runtime: runtime,
            center: center,
            authorizationStore: authorizationStore ?? UserDefaultsHeadsUpAuthorizationStore(),
            permissionPanelCoordinator: HeadsUpPermissionPanelCoordinator(),
            capsule: capsule,
            presentBreak: presentBreak,
            presentMoreOptions: presentMoreOptions,
            onStatusProjection: onStatusProjection,
            onError: onError,
        )
        #if DEBUG
            coordinator.verificationCapture = { [weak capsule] in
                capsule?.captureForVerification() ?? false
            }
        #endif
        relay.coordinator = coordinator
        return coordinator
    }
}

private final class HeadsUpLifecycleRelay {
    weak var coordinator: HeadsUpLifecycleCoordinator?
}
