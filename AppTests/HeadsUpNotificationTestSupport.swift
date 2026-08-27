import Foundation
import HeadsUp
@testable import App

extension HeadsUpNotificationRequest {
    init(deliveryID: UUID, content: HeadsUpNotificationContent) {
        let registry = HeadsUpNotificationResponseRegistry()
        precondition(registry.registerActive(deliveryID: deliveryID))
        self.init(
            registration: registry.registration(deliveryID: deliveryID)!,
            content: content,
        )
    }
}

extension HeadsUpNotificationDeliveryCoordinator {
    convenience init(
        center: any HeadsUpNotificationCenterClient,
        capsule: any HeadsUpCapsulePresenting,
        reconciliationAttempts: Int = 5,
        wait: @escaping Wait = {
            try? await Task.sleep(for: .milliseconds(100))
        },
    ) {
        self.init(
            center: center,
            capsule: capsule,
            responseRegistry: .init(),
            reconciliationAttempts: reconciliationAttempts,
            wait: wait,
        )
    }
}

final class FakeHeadsUpNotificationCenter: HeadsUpNotificationCenterClient {
    enum Failure: Error {
        case requested
    }

    var settingsError: Error?
    var authorizationError: Error?
    var addError: Error?
    var onAdd: (() async -> Void)?
    var onDeliveredRead: (() async -> Void)?
    var onEvent: ((String) -> Void)?
    var requestedOptions: HeadsUpNotificationAuthorizationOptions = []
    var addedRequests: [HeadsUpNotificationRequest] = []
    var removedPendingIdentifiers: [[String]] = []
    var removedDeliveredIdentifiers: [[String]] = []
    var registeredCategories: [[HeadsUpNotificationCategory]] = []
    private(set) var settingsReadCount = 0
    private(set) var authorizationRequestCount = 0
    private(set) var deliveredReadCount = 0

    private var settings: [HeadsUpNotificationSettings]
    private var deliveredIdentifiers: [[String]]

    init(
        settings: [HeadsUpNotificationSettings],
        deliveredIdentifiers: [[String]] = [],
    ) {
        self.settings = settings
        self.deliveredIdentifiers = deliveredIdentifiers
    }

    func notificationSettings() async throws -> HeadsUpNotificationSettings {
        onEvent?("settings")
        settingsReadCount += 1
        if let settingsError { throw settingsError }
        if settings.count > 1 { return settings.removeFirst() }
        return settings.first ?? .init(authorizationStatus: .unknown, alertsEnabled: false)
    }

    func requestAuthorization(
        options: HeadsUpNotificationAuthorizationOptions,
    ) async throws -> Bool {
        onEvent?("request")
        authorizationRequestCount += 1
        requestedOptions = options
        if let authorizationError { throw authorizationError }
        return true
    }

    func add(_ request: HeadsUpNotificationRequest) async throws {
        addedRequests.append(request)
        await onAdd?()
        if let addError { throw addError }
    }

    func pendingRequestIdentifiers() async -> [String] { [] }

    func deliveredRequestIdentifiers() async -> [String] {
        deliveredReadCount += 1
        await onDeliveredRead?()
        if deliveredIdentifiers.count > 1 { return deliveredIdentifiers.removeFirst() }
        return deliveredIdentifiers.first ?? []
    }

    func removePendingRequestIdentifiers(_ identifiers: [String]) {
        removedPendingIdentifiers.append(identifiers)
    }

    func removeDeliveredRequestIdentifiers(_ identifiers: [String]) {
        removedDeliveredIdentifiers.append(identifiers)
    }

    func registerCategories(_ categories: [HeadsUpNotificationCategory]) {
        registeredCategories.append(categories)
    }
}

final class FakeHeadsUpAuthorizationStore: HeadsUpAuthorizationStore {
    var state = HeadsUpNotificationAuthorizationState()

    func load() -> HeadsUpNotificationAuthorizationState {
        state
    }

    func save(_ state: HeadsUpNotificationAuthorizationState) {
        self.state = state
    }
}

final class HeadsUpNotificationTestGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation = $0 }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

actor HeadsUpNotificationTestCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

final class FakeHeadsUpCapsulePresenter: HeadsUpCapsulePresenting {
    var shouldConfirm = true
    var onPresent: (() async -> Void)?
    var presented: [(deliveryID: UUID, content: HeadsUpNotificationRequest)] = []
    var dismissedDeliveryIDs: [UUID] = []

    func present(
        deliveryID: UUID,
        content: HeadsUpNotificationRequest,
    ) async throws -> Bool {
        presented.append((deliveryID, content))
        await onPresent?()
        return shouldConfirm
    }

    func dismiss(deliveryID: UUID) {
        dismissedDeliveryIDs.append(deliveryID)
    }
}
