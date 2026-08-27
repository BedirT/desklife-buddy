import Foundation

struct HeadsUpNotificationResponseEnvelope: Equatable, Sendable {
    let requestIdentifier: String
    let categoryIdentifier: String
    let actionIdentifier: String
    let userInfo: [String: String]
}

enum HeadsUpNotificationResponse: Equatable, Sendable {
    case startNow(UUID)
    case snoozeFiveMinutes(UUID)
    case moreOptions(UUID)
    case dismiss(UUID)
    case defaultBodyTapAwaitingOwnerDecision(UUID)
    case unknown

    var deliveryID: UUID? {
        switch self {
        case let .startNow(deliveryID),
             let .snoozeFiveMinutes(deliveryID),
             let .moreOptions(deliveryID),
             let .dismiss(deliveryID),
             let .defaultBodyTapAwaitingOwnerDecision(deliveryID):
            deliveryID
        case .unknown:
            nil
        }
    }
}

enum HeadsUpNotificationRoute: Equatable, Sendable {
    case startNow(UUID)
    case snoozeFiveMinutes(UUID)
    case moreOptions(UUID)
    case dismissedWithoutAction(UUID)
    case defaultBodyTapAwaitingOwnerDecision(UUID)
}

enum HeadsUpDefaultBodyTapBehavior: Equatable, Sendable {
    // Production must inject one of these only after the owner resolves the body-tap policy.
    case startNow
    case moreOptions
    case noAction
}

enum HeadsUpNotificationResponseMapper {
    static func map(_ envelope: HeadsUpNotificationResponseEnvelope) -> HeadsUpNotificationResponse {
        guard envelope.categoryIdentifier == HeadsUpNotificationIdentifiers.category,
              let deliveryIDValue = envelope.userInfo[
                  HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey,
              ],
              let deliveryID = UUID(uuidString: deliveryIDValue),
              envelope.requestIdentifier == HeadsUpNotificationIdentifiers.requestIdentifier(
                  for: deliveryID,
              )
        else {
            return .unknown
        }
        return switch envelope.actionIdentifier {
        case HeadsUpNotificationIdentifiers.startNowAction:
            .startNow(deliveryID)
        case HeadsUpNotificationIdentifiers.snoozeFiveAction:
            .snoozeFiveMinutes(deliveryID)
        case HeadsUpNotificationIdentifiers.moreOptionsAction:
            .moreOptions(deliveryID)
        case HeadsUpNotificationIdentifiers.dismissAction:
            .dismiss(deliveryID)
        case HeadsUpNotificationIdentifiers.defaultAction:
            .defaultBodyTapAwaitingOwnerDecision(deliveryID)
        default:
            .unknown
        }
    }

    static func route(
        _ response: HeadsUpNotificationResponse,
        defaultBodyTapBehavior: HeadsUpDefaultBodyTapBehavior? = nil,
    ) -> HeadsUpNotificationRoute? {
        switch response {
        case let .startNow(deliveryID):
            .startNow(deliveryID)
        case let .snoozeFiveMinutes(deliveryID):
            .snoozeFiveMinutes(deliveryID)
        case let .moreOptions(deliveryID):
            .moreOptions(deliveryID)
        case let .dismiss(deliveryID):
            .dismissedWithoutAction(deliveryID)
        case let .defaultBodyTapAwaitingOwnerDecision(deliveryID):
            routeDefaultBodyTap(
                deliveryID: deliveryID,
                behavior: defaultBodyTapBehavior,
            )
        case .unknown:
            nil
        }
    }

    private static func routeDefaultBodyTap(
        deliveryID: UUID,
        behavior: HeadsUpDefaultBodyTapBehavior?,
    ) -> HeadsUpNotificationRoute {
        switch behavior {
        case .startNow:
            .startNow(deliveryID)
        case .moreOptions:
            .moreOptions(deliveryID)
        case .noAction:
            .dismissedWithoutAction(deliveryID)
        case nil:
            .defaultBodyTapAwaitingOwnerDecision(deliveryID)
        }
    }
}

struct HeadsUpNotificationRegistration: Equatable, Sendable {
    let deliveryID: UUID

    fileprivate init(deliveryID: UUID) {
        self.deliveryID = deliveryID
    }
}

final class HeadsUpNotificationResponseRegistry {
    private let retiredDeliveryLimit: Int
    private var registeredDeliveryIDs: Set<UUID> = []
    private var observedDeliveryIDs: Set<UUID> = []
    private var retiredDeliveryIDs: Set<UUID> = []
    private var retirementOrder: [UUID] = []

    var registeredDeliveryCount: Int { registeredDeliveryIDs.count }
    var retiredDeliveryCount: Int { retiredDeliveryIDs.count }

    init(retiredDeliveryLimit: Int = 256) {
        self.retiredDeliveryLimit = max(1, retiredDeliveryLimit)
    }

    func registerActive(deliveryID: UUID) -> Bool {
        guard !retiredDeliveryIDs.contains(deliveryID) else { return false }
        registeredDeliveryIDs.insert(deliveryID)
        return true
    }

    func registration(deliveryID: UUID) -> HeadsUpNotificationRegistration? {
        guard registeredDeliveryIDs.contains(deliveryID) else { return nil }
        return HeadsUpNotificationRegistration(deliveryID: deliveryID)
    }

    @discardableResult
    func observe(deliveryID: UUID) -> Bool {
        guard registeredDeliveryIDs.contains(deliveryID) else { return false }
        observedDeliveryIDs.insert(deliveryID)
        return true
    }

    func hasObserved(deliveryID: UUID) -> Bool {
        observedDeliveryIDs.contains(deliveryID)
    }

    func isRegistered(deliveryID: UUID) -> Bool {
        registeredDeliveryIDs.contains(deliveryID)
    }

    func retire(deliveryID: UUID) {
        registeredDeliveryIDs.remove(deliveryID)
        observedDeliveryIDs.remove(deliveryID)
        guard retiredDeliveryIDs.insert(deliveryID).inserted else { return }
        retirementOrder.append(deliveryID)
        if retirementOrder.count > retiredDeliveryLimit {
            retiredDeliveryIDs.remove(retirementOrder.removeFirst())
        }
    }
}

final class HeadsUpNotificationResponseBuffer {
    private let responseRegistry: HeadsUpNotificationResponseRegistry
    private let onResponse: (HeadsUpNotificationResponse) -> Void
    private var queuedResponses: [HeadsUpNotificationResponse] = []
    private var readyDeliveryIDs: Set<UUID> = []
    private var isRuntimeRestored = false

    var queuedResponseCount: Int { queuedResponses.count }
    var readyDeliveryCount: Int { readyDeliveryIDs.count }

    init(
        responseRegistry: HeadsUpNotificationResponseRegistry,
        onResponse: @escaping (HeadsUpNotificationResponse) -> Void,
    ) {
        self.responseRegistry = responseRegistry
        self.onResponse = onResponse
    }

    func receive(_ response: HeadsUpNotificationResponse) {
        if let deliveryID = response.deliveryID {
            if !responseRegistry.observe(deliveryID: deliveryID) {
                guard !isRuntimeRestored else { return }
                queuedResponses.append(response)
                return
            }
        }
        guard isReady(response) else {
            queuedResponses.append(response)
            return
        }
        onResponse(response)
    }

    func markRuntimeRestored() {
        guard !isRuntimeRestored else { return }
        isRuntimeRestored = true
        for response in queuedResponses {
            guard let deliveryID = response.deliveryID else { continue }
            responseRegistry.observe(deliveryID: deliveryID)
        }
        queuedResponses.removeAll { response in
            guard let deliveryID = response.deliveryID else { return false }
            return !responseRegistry.isRegistered(deliveryID: deliveryID)
        }
        drainReadyResponses()
    }

    func markPromptFactReady(deliveryID: UUID) {
        guard responseRegistry.isRegistered(deliveryID: deliveryID) else { return }
        readyDeliveryIDs.insert(deliveryID)
        drainReadyResponses()
    }

    func clearDelivery(deliveryID: UUID) {
        responseRegistry.retire(deliveryID: deliveryID)
        readyDeliveryIDs.remove(deliveryID)
        queuedResponses.removeAll { $0.deliveryID == deliveryID }
    }

    private func drainReadyResponses() {
        guard isRuntimeRestored else { return }
        let responses = queuedResponses.filter(isReady)
        queuedResponses.removeAll(where: isReady)
        responses.forEach(onResponse)
    }

    private func isReady(_ response: HeadsUpNotificationResponse) -> Bool {
        guard isRuntimeRestored else { return false }
        guard let deliveryID = response.deliveryID else { return true }
        return readyDeliveryIDs.contains(deliveryID)
    }
}
