import Domain
import Foundation
import HeadsUp

final class HeadsUpLifecycleCoordinator {
    typealias ModelFactory = (
        HeadsUpScope,
        HeadsUpPhase,
        Double,
        HeadsUpAccessibility,
        @escaping (HeadsUpIntent) -> Void,
    ) -> HeadsUpModel
    typealias DriverFactory = (HeadsUpModel, TimeInterval) -> HeadsUpApproachDriver
    typealias SuppressionRetractionScheduler = (
        TimeInterval,
        @escaping @MainActor @Sendable () -> Void,
    ) -> OverlayCancellation
    typealias BreakPresenter = (
        HeadsUpDeliveryID,
        HeadsUpOpportunityID,
    ) -> AppOverlayPresentationDecision
    typealias MoreOptionsPresenter = (
        HeadsUpDeliveryID,
        HeadsUpOpportunityID,
    ) -> BreakFlowOverlayCoordinator.PresentationResult

    struct ActivePresentation {
        let id: HeadsUpDeliveryID
        let opportunity: HeadsUpOpportunityID
        let model: HeadsUpModel
        let driver: HeadsUpApproachDriver
        var targetAt: Date?
    }

    struct PendingBreakOpening {
        let id: HeadsUpDeliveryID
        let opportunity: HeadsUpOpportunityID
    }

    let runtime: ProtocolRuntime
    let center: any HeadsUpNotificationCenterClient
    let responseRegistry: HeadsUpNotificationResponseRegistry
    lazy var responseBuffer = HeadsUpNotificationResponseBuffer(
        responseRegistry: responseRegistry,
        onResponse: { [weak self] response in self?.enqueueResponse(response) },
    )
    let authorizationCoordinator: HeadsUpAuthorizationCoordinator
    let permissionPanelCoordinator: HeadsUpPermissionPanelCoordinator
    let deliveryCoordinator: HeadsUpNotificationDeliveryCoordinator
    let modelFactory: ModelFactory
    let driverFactory: DriverFactory
    let suppressionHoldDurationSeconds: TimeInterval
    let scheduleSuppressionRetraction: SuppressionRetractionScheduler
    let presentBreak: BreakPresenter
    let presentMoreOptions: MoreOptionsPresenter
    let wallNow: () -> Date
    let onStatusProjection: (HeadsUpStatusMenuProjection?) -> Void
    let onError: (any Error) -> Void

    var activePresentation: ActivePresentation?
    var pendingBreakOpening: PendingBreakOpening?
    var pendingModelIntents: [HeadsUpDeliveryID: HeadsUpIntent] = [:]
    var readyDeliveryIDs: Set<HeadsUpDeliveryID> = []
    var deliveryTasks: [HeadsUpDeliveryID: Task<Void, Never>] = [:]
    var serialTaskTail: Task<Void, Never>?
    var suppressionRetractionCancellation: OverlayCancellation?
    var didStart = false
    #if DEBUG
        var verificationCapture: (() -> Bool)?
    #endif

    var activeDeliveryID: HeadsUpDeliveryID? { activePresentation?.id }
    var statusProjection: HeadsUpStatusMenuProjection? {
        guard let activePresentation,
              readyDeliveryIDs.contains(activePresentation.id)
        else {
            return nil
        }
        return activePresentation.model.statusMenuProjection
    }

    init(
        runtime: ProtocolRuntime,
        center: any HeadsUpNotificationCenterClient,
        authorizationStore: any HeadsUpAuthorizationStore,
        permissionPanelCoordinator: HeadsUpPermissionPanelCoordinator,
        capsule: any HeadsUpCapsulePresenting,
        responseRegistry: HeadsUpNotificationResponseRegistry = .init(),
        allowsNotificationFallback: @escaping () -> Bool = { true },
        reconciliationAttempts: Int = 5,
        reconciliationWait: @escaping HeadsUpNotificationDeliveryCoordinator.Wait = {
            try? await Task.sleep(for: .milliseconds(100))
        },
        wallNow: @escaping () -> Date = Date.init,
        modelFactory: ModelFactory? = nil,
        driverFactory: DriverFactory? = nil,
        suppressionHoldDurationSeconds: TimeInterval = 2,
        scheduleSuppressionRetraction: SuppressionRetractionScheduler? = nil,
        presentBreak: @escaping BreakPresenter,
        presentMoreOptions: @escaping MoreOptionsPresenter,
        onStatusProjection: @escaping (HeadsUpStatusMenuProjection?) -> Void = { _ in },
        onError: @escaping (any Error) -> Void = { _ in },
    ) {
        self.runtime = runtime
        self.center = center
        self.responseRegistry = responseRegistry
        authorizationCoordinator = HeadsUpAuthorizationCoordinator(
            center: center,
            store: authorizationStore,
        )
        self.permissionPanelCoordinator = permissionPanelCoordinator
        deliveryCoordinator = HeadsUpNotificationDeliveryCoordinator(
            center: center,
            capsule: capsule,
            responseRegistry: responseRegistry,
            allowsNotificationFallback: allowsNotificationFallback,
            reconciliationAttempts: reconciliationAttempts,
            wait: reconciliationWait,
        )
        self.wallNow = wallNow
        self.modelFactory = modelFactory ?? Self.makeModel
        self.driverFactory = driverFactory ?? { HeadsUpApproachDriver(model: $0, leadSeconds: $1) }
        precondition(
            suppressionHoldDurationSeconds.isFinite && suppressionHoldDurationSeconds > 0,
        )
        self.suppressionHoldDurationSeconds = suppressionHoldDurationSeconds
        self.scheduleSuppressionRetraction = scheduleSuppressionRetraction
            ?? Self.liveSuppressionRetractionScheduler
        self.presentBreak = presentBreak
        self.presentMoreOptions = presentMoreOptions
        self.onStatusProjection = onStatusProjection
        self.onError = onError
    }

    func start(initialSample: ActivitySample? = nil) async throws {
        guard !didStart else { return }
        didStart = true
        center.registerCategories([.breakOpportunity])
        installRuntimeCallbacks()
        do {
            try await runtime.restore()
            responseBuffer.markRuntimeRestored()
            await drain()
            if let initialSample {
                try await runtime.observe(initialSample)
            }
        } catch {
            didStart = false
            onError(error)
            throw error
        }
        await drain()
    }

    func receive(_ envelope: HeadsUpNotificationResponseEnvelope) {
        responseBuffer.receive(HeadsUpNotificationResponseMapper.map(envelope))
    }

    func receive(_ response: HeadsUpNotificationResponse) {
        responseBuffer.receive(response)
    }

    func observe(_ sample: ActivitySample) {
        enqueue { [weak self] in
            guard let self else { return }
            do {
                try await runtime.observe(sample)
            } catch {
                onError(error)
            }
        }
    }

    func observeHeadsUp(_ snapshot: HeadsUpDeliverySnapshot) {
        enqueue { [weak self] in
            guard let self else { return }
            do {
                try await runtime.observeHeadsUp(snapshot)
            } catch {
                onError(error)
            }
        }
    }

    func send(_ intent: HeadsUpIntent) {
        guard let activePresentation,
              activePresentation.model.scope == intent.scope
        else {
            return
        }
        pendingModelIntents[activePresentation.id] = intent
        guard readyDeliveryIDs.contains(activePresentation.id) else { return }
        enqueueIntent(intent, deliveryID: activePresentation.id)
    }

    @discardableResult
    func completePendingBreakOpening(
        actionID: HeadsUpDeliveryID,
        family: OverlayOpeningFamily,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) -> Bool {
        guard let pendingBreakOpening,
              pendingBreakOpening.id == actionID,
              Self.family(for: pendingBreakOpening.opportunity) == family
        else {
            return false
        }
        enqueue { [weak self] in
            guard let self else {
                completion(.failure(HeadsUpLifecycleError.coordinatorUnavailable))
                return
            }
            do {
                let completed = try await runtime.completeHeadsUpPendingAction(
                    pendingBreakOpening.id,
                    kind: .openBreak,
                    opportunity: pendingBreakOpening.opportunity,
                )
                guard completed != nil else {
                    completion(.failure(HeadsUpLifecycleError.stalePendingAction))
                    return
                }
                self.pendingBreakOpening = nil
                completion(.success(()))
            } catch {
                onError(error)
                completion(.failure(error))
            }
        }
        return true
    }

    func retryPendingPresentation() {
        guard let pending = runtime.state.headsUpDeliveryState.pendingAction else { return }
        handlePendingAction(pending)
    }

    func retryActiveDelivery() {
        guard let active = runtime.state.headsUpDeliveryState.activeDelivery,
              active.phase == .reserved,
              activePresentation?.id == active.id
        else {
            return
        }
        startDelivery(HeadsUpDeliveryReservation(
            id: active.id,
            opportunity: active.opportunity,
            countdownMark: active.countdownMark,
            targetAt: active.targetAt,
        ))
    }
}

extension HeadsUpLifecycleCoordinator {
    func modelForCapsule(
        deliveryID: UUID,
        content: HeadsUpNotificationRequest,
    ) -> HeadsUpModel? {
        guard let activePresentation,
              activePresentation.id.rawValue == deliveryID,
              activePresentation.model.scope == content.scope
        else {
            return nil
        }
        return activePresentation.model
    }

    func handleCapsuleEscape(
        deliveryID: UUID,
        completion: @escaping (Result<Void, any Error>) -> Void,
    ) {
        let id = HeadsUpDeliveryID(rawValue: deliveryID)
        enqueue { [weak self] in
            guard let self else {
                completion(.failure(HeadsUpLifecycleError.coordinatorUnavailable))
                return
            }
            do {
                try await runtime.respondToHeadsUp(id, response: .skip)
                guard runtime.state.headsUpDeliveryState.activeDelivery?.id != id else {
                    completion(.failure(HeadsUpLifecycleError.stalePendingAction))
                    return
                }
                completion(.success(()))
            } catch {
                onError(error)
                completion(.failure(error))
            }
        }
    }
}

enum HeadsUpLifecycleError: Error, Equatable {
    case coordinatorUnavailable
    case stalePendingAction
}

extension HeadsUpIntent {
    var scope: HeadsUpScope {
        switch self {
        case let .start(scope), let .snooze(scope, _), let .snoozeUntil(scope, _),
             let .manualHold(scope, _), let .moreOptions(scope), let .skip(scope):
            scope
        }
    }
}
