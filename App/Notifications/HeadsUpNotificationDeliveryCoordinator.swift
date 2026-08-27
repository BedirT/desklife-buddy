import Foundation
import HeadsUp

enum HeadsUpNotificationWithdrawal: Equatable, Sendable {
    case cancelBeforePresentation(UUID)
    case retractPresented(UUID)

    var deliveryID: UUID {
        switch self {
        case let .cancelBeforePresentation(deliveryID),
             let .retractPresented(deliveryID):
            deliveryID
        }
    }
}

final class HeadsUpNotificationDeliveryCoordinator {
    typealias Wait = () async -> Void

    private enum CachedDelivery {
        case inFlight(attempt: UInt64, task: Task<HeadsUpPresentationChannel?, Never>)
        case completed(HeadsUpPresentationChannel?)
        // Retained until persistence releases it so late async completions cannot revive delivery.
        case withdrawn(
            attempt: UInt64?,
            task: Task<HeadsUpPresentationChannel?, Never>?,
            releaseWhenSettled: Bool,
        )
    }

    private let center: any HeadsUpNotificationCenterClient
    private let capsule: any HeadsUpCapsulePresenting
    private let responseRegistry: HeadsUpNotificationResponseRegistry
    private let reconciliationAttempts: Int
    private let wait: Wait
    // Completed outcomes stay cached until their prompt fact or terminal state is durably persisted.
    private var cachedDeliveries: [UUID: CachedDelivery] = [:]
    private var nextAttempt: UInt64 = 0

    var cachedDeliveryCount: Int { cachedDeliveries.count }

    init(
        center: any HeadsUpNotificationCenterClient,
        capsule: any HeadsUpCapsulePresenting,
        responseRegistry: HeadsUpNotificationResponseRegistry,
        reconciliationAttempts: Int = 5,
        wait: @escaping Wait = {
            try? await Task.sleep(for: .milliseconds(100))
        },
    ) {
        self.center = center
        self.capsule = capsule
        self.responseRegistry = responseRegistry
        self.reconciliationAttempts = max(1, reconciliationAttempts)
        self.wait = wait
    }

    func deliver(
        deliveryID: UUID,
        content: HeadsUpNotificationContent,
        preferredChannel: HeadsUpPresentationChannel,
    ) async -> HeadsUpPresentationChannel? {
        if let cached = cachedDeliveries[deliveryID] {
            return switch cached {
            case let .inFlight(_, task):
                await task.value
            case let .completed(channel):
                channel
            case .withdrawn:
                nil
            }
        }

        guard responseRegistry.registerActive(deliveryID: deliveryID),
              let registration = responseRegistry.registration(deliveryID: deliveryID)
        else {
            return nil
        }
        nextAttempt &+= 1
        let attempt = nextAttempt
        let task = Task {
            let channel = await performDelivery(
                registration: registration,
                content: content,
                preferredChannel: preferredChannel,
            )
            return finishDelivery(
                deliveryID: deliveryID,
                attempt: attempt,
                channel: channel,
            )
        }
        cachedDeliveries[deliveryID] = .inFlight(attempt: attempt, task: task)
        return await task.value
    }

    func releasePersistedDelivery(deliveryID: UUID) {
        switch cachedDeliveries[deliveryID] {
        case .completed:
            removeCachedDelivery(deliveryID: deliveryID)
        case let .withdrawn(attempt, task, _):
            guard attempt != nil else {
                removeCachedDelivery(deliveryID: deliveryID)
                return
            }
            cachedDeliveries[deliveryID] = .withdrawn(
                attempt: attempt,
                task: task,
                releaseWhenSettled: true,
            )
        case .inFlight:
            break
        case nil:
            break
        }
    }

    func withdraw(_ withdrawal: HeadsUpNotificationWithdrawal) {
        let deliveryID = withdrawal.deliveryID
        switch cachedDeliveries[deliveryID] {
        case let .inFlight(attempt, task):
            task.cancel()
            cachedDeliveries[deliveryID] = .withdrawn(
                attempt: attempt,
                task: task,
                releaseWhenSettled: false,
            )
        case .completed, nil:
            cachedDeliveries[deliveryID] = .withdrawn(
                attempt: nil,
                task: nil,
                releaseWhenSettled: false,
            )
        case .withdrawn:
            break
        }
        responseRegistry.retire(deliveryID: deliveryID)
        removeNotification(deliveryID: deliveryID)
        capsule.dismiss(deliveryID: deliveryID)
    }

    private func finishDelivery(
        deliveryID: UUID,
        attempt: UInt64,
        channel: HeadsUpPresentationChannel?,
    ) -> HeadsUpPresentationChannel? {
        switch cachedDeliveries[deliveryID] {
        case let .inFlight(cachedAttempt, _) where cachedAttempt == attempt:
            cachedDeliveries[deliveryID] = .completed(channel)
            return channel
        case let .withdrawn(cachedAttempt, _, releaseWhenSettled)
            where cachedAttempt == attempt:
            if releaseWhenSettled {
                removeCachedDelivery(deliveryID: deliveryID)
            } else {
                cachedDeliveries[deliveryID] = .withdrawn(
                    attempt: nil,
                    task: nil,
                    releaseWhenSettled: false,
                )
            }
            return nil
        default:
            return nil
        }
    }

    private func performDelivery(
        registration: HeadsUpNotificationRegistration,
        content: HeadsUpNotificationContent,
        preferredChannel: HeadsUpPresentationChannel,
    ) async -> HeadsUpPresentationChannel? {
        let deliveryID = registration.deliveryID
        let request = HeadsUpNotificationRequest(
            registration: registration,
            content: content,
        )
        switch preferredChannel {
        case .notification:
            if await deliverNotification(request) {
                return .notification
            }
            guard !Task.isCancelled else { return nil }
            if responseRegistry.hasObserved(deliveryID: deliveryID) {
                return .notification
            }
            let didPresentCapsule = await deliverCapsule(
                deliveryID: deliveryID,
                content: request,
            )
            guard !Task.isCancelled else { return nil }
            if responseRegistry.hasObserved(deliveryID: deliveryID) {
                capsule.dismiss(deliveryID: deliveryID)
                return .notification
            }
            return didPresentCapsule ? .capsule : nil
        case .capsule:
            return await deliverCapsule(deliveryID: deliveryID, content: request)
                ? .capsule
                : nil
        }
    }

    private func deliverNotification(_ request: HeadsUpNotificationRequest) async -> Bool {
        guard !Task.isCancelled else { return false }
        do {
            try await center.add(request)
            guard !Task.isCancelled else {
                removeNotification(deliveryID: request.deliveryID)
                return false
            }
            if responseRegistry.hasObserved(deliveryID: request.deliveryID) {
                return true
            }
            for attempt in 0 ..< reconciliationAttempts {
                let delivered = try await center.deliveredRequestIdentifiers()
                guard !Task.isCancelled else {
                    removeNotification(deliveryID: request.deliveryID)
                    return false
                }
                if responseRegistry.hasObserved(deliveryID: request.deliveryID) {
                    return true
                }
                if delivered.contains(request.identifier) {
                    return true
                }
                if attempt < reconciliationAttempts - 1 {
                    await wait()
                }
            }
        } catch {
            // The cleanup below also covers an accepted request whose delivery lookup failed.
        }

        let didObserveNativeResponse = responseRegistry.hasObserved(deliveryID: request.deliveryID)
        if !Task.isCancelled, didObserveNativeResponse {
            return true
        }

        removeNotification(deliveryID: request.deliveryID)
        return false
    }

    private func deliverCapsule(
        deliveryID: UUID,
        content: HeadsUpNotificationRequest,
    ) async -> Bool {
        guard !Task.isCancelled else { return false }
        do {
            let didPresent = try await capsule.present(deliveryID: deliveryID, content: content)
            guard !Task.isCancelled else {
                capsule.dismiss(deliveryID: deliveryID)
                return false
            }
            return didPresent
        } catch {
            return false
        }
    }

    private func removeNotification(deliveryID: UUID) {
        let identifier = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        center.removePendingRequestIdentifiers([identifier])
        center.removeDeliveredRequestIdentifiers([identifier])
    }

    private func removeCachedDelivery(deliveryID: UUID) {
        cachedDeliveries[deliveryID] = nil
    }
}
