import Foundation
import HeadsUp

enum HeadsUpNotificationIdentifiers {
    static let category = "heads-up.opportunity.v1"
    static let startNowAction = "heads-up.action.start-now.v1"
    static let snoozeFiveAction = "heads-up.action.snooze-five.v1"
    static let moreOptionsAction = "heads-up.action.more-options.v1"
    static let deliveryIDUserInfoKey = "heads-up.delivery-id"

    static let defaultAction = "com.apple.UNNotificationDefaultActionIdentifier"
    static let dismissAction = "com.apple.UNNotificationDismissActionIdentifier"

    static func requestIdentifier(for deliveryID: UUID) -> String {
        "heads-up.delivery.\(deliveryID.uuidString.lowercased())"
    }
}

enum HeadsUpNotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case revoked
    case authorized
    case provisional
    case unknown
}

struct HeadsUpNotificationSettings: Equatable, Sendable {
    let authorizationStatus: HeadsUpNotificationAuthorizationStatus
    let alertsEnabled: Bool
}

struct HeadsUpNotificationAuthorizationOptions: OptionSet, Equatable, Sendable {
    let rawValue: Int

    static let alert = Self(rawValue: 1 << 0)
}

enum HeadsUpNotificationInterruptionLevel: Equatable, Sendable {
    case active
}

struct HeadsUpNotificationActionDescriptor: Equatable, Sendable {
    enum Activation: Equatable, Sendable {
        case background
        case foreground
    }

    let identifier: String
    let title: String
    let activation: Activation
}

struct HeadsUpNotificationCategory: Equatable, Sendable {
    let identifier: String
    let actions: [HeadsUpNotificationActionDescriptor]
    let reportsDismissals: Bool

    static var breakOpportunity: Self {
        let featureActions = HeadsUpNotificationContent(scope: .visual).actions
        return Self(
            identifier: HeadsUpNotificationIdentifiers.category,
            actions: featureActions.map { action in
                HeadsUpNotificationActionDescriptor(
                    identifier: identifier(for: action.kind),
                    title: action.title,
                    activation: activation(for: action.kind),
                )
            },
            reportsDismissals: true,
        )
    }

    private static func identifier(for kind: HeadsUpNotificationActionKind) -> String {
        switch kind {
        case .startNow:
            HeadsUpNotificationIdentifiers.startNowAction
        case .snoozeFiveMinutes:
            HeadsUpNotificationIdentifiers.snoozeFiveAction
        case .moreOptions:
            HeadsUpNotificationIdentifiers.moreOptionsAction
        }
    }

    private static func activation(
        for kind: HeadsUpNotificationActionKind,
    ) -> HeadsUpNotificationActionDescriptor.Activation {
        switch kind {
        case .startNow, .moreOptions:
            .foreground
        case .snoozeFiveMinutes:
            .background
        }
    }
}

struct HeadsUpNotificationRequest: Equatable, Sendable {
    let identifier: String
    let deliveryID: UUID
    let scope: HeadsUpScope
    let title: String
    let body: String
    let categoryIdentifier: String
    let userInfo: [String: String]
    let interruptionLevel: HeadsUpNotificationInterruptionLevel

    init(
        registration: HeadsUpNotificationRegistration,
        content: HeadsUpNotificationContent,
    ) {
        let deliveryID = registration.deliveryID
        identifier = HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID)
        self.deliveryID = deliveryID
        scope = content.scope
        title = content.title
        body = content.body
        categoryIdentifier = HeadsUpNotificationIdentifiers.category
        userInfo = [
            HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey: deliveryID.uuidString.lowercased(),
        ]
        interruptionLevel = .active
    }
}

protocol HeadsUpNotificationCenterClient: AnyObject {
    func notificationSettings() async throws -> HeadsUpNotificationSettings
    func requestAuthorization(options: HeadsUpNotificationAuthorizationOptions) async throws -> Bool
    func add(_ request: HeadsUpNotificationRequest) async throws
    func pendingRequestIdentifiers() async throws -> [String]
    func deliveredRequestIdentifiers() async throws -> [String]
    func removePendingRequestIdentifiers(_ identifiers: [String])
    func removeDeliveredRequestIdentifiers(_ identifiers: [String])
    func registerCategories(_ categories: [HeadsUpNotificationCategory])
}

enum HeadsUpPresentationChannel: Equatable, Sendable {
    case notification
    case capsule
}

protocol HeadsUpCapsulePresenting: AnyObject {
    func present(
        deliveryID: UUID,
        content: HeadsUpNotificationRequest,
    ) async throws -> Bool
    func dismiss(deliveryID: UUID)
}
