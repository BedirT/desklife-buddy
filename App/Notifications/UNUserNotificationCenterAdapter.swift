import Foundation
import UserNotifications

final class UNUserNotificationCenterAdapter: HeadsUpNotificationCenterClient {
    private let center: UNUserNotificationCenter
    let delegateBridge: HeadsUpNotificationDelegateBridge

    init(
        center: UNUserNotificationCenter = .current(),
        delegateBridge: HeadsUpNotificationDelegateBridge = HeadsUpNotificationDelegateBridge(),
    ) {
        self.center = center
        self.delegateBridge = delegateBridge
        center.delegate = delegateBridge
    }

    func notificationSettings() async throws -> HeadsUpNotificationSettings {
        let settings = await center.notificationSettings()
        return HeadsUpNotificationSettings(
            authorizationStatus: Self.map(settings.authorizationStatus),
            alertsEnabled: settings.alertSetting == .enabled,
        )
    }

    func requestAuthorization(
        options: HeadsUpNotificationAuthorizationOptions,
    ) async throws -> Bool {
        try await center.requestAuthorization(options: Self.map(options))
    }

    func add(_ request: HeadsUpNotificationRequest) async throws {
        try await center.add(Self.makeRequest(request))
    }

    func pendingRequestIdentifiers() async throws -> [String] {
        await center.pendingNotificationRequests().map(\.identifier)
    }

    func deliveredRequestIdentifiers() async throws -> [String] {
        await center.deliveredNotifications().map(\.request.identifier)
    }

    func removePendingRequestIdentifiers(_ identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDeliveredRequestIdentifiers(_ identifiers: [String]) {
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func registerCategories(_ categories: [HeadsUpNotificationCategory]) {
        let mapped = categories.map(Self.makeCategory)
        center.setNotificationCategories(Set(mapped))
    }

    static func makeRequest(_ request: HeadsUpNotificationRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.categoryIdentifier = request.categoryIdentifier
        content.userInfo = request.userInfo
        content.interruptionLevel = .active
        content.sound = nil
        content.badge = nil
        return UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: nil,
        )
    }

    static func makeCategories() -> [UNNotificationCategory] {
        [makeCategory(.breakOpportunity)]
    }

    private static func makeCategory(
        _ category: HeadsUpNotificationCategory,
    ) -> UNNotificationCategory {
        let options: UNNotificationCategoryOptions = category.reportsDismissals
            ? [.customDismissAction]
            : []
        return UNNotificationCategory(
            identifier: category.identifier,
            actions: category.actions.map {
                let options: UNNotificationActionOptions = switch $0.activation {
                case .background: []
                case .foreground: [.foreground]
                }
                return UNNotificationAction(
                    identifier: $0.identifier,
                    title: $0.title,
                    options: options,
                )
            },
            intentIdentifiers: [],
            options: options,
        )
    }

    private static func map(
        _ status: UNAuthorizationStatus,
    ) -> HeadsUpNotificationAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .denied:
            .denied
        case .authorized:
            .authorized
        case .provisional, .ephemeral:
            .provisional
        @unknown default:
            .unknown
        }
    }

    private static func map(
        _ options: HeadsUpNotificationAuthorizationOptions,
    ) -> UNAuthorizationOptions {
        var mapped: UNAuthorizationOptions = []
        if options.contains(.alert) { mapped.insert(.alert) }
        return mapped
    }
}

final class HeadsUpNotificationDelegateBridge: NSObject, UNUserNotificationCenterDelegate {
    private let onResponse: (HeadsUpNotificationResponseEnvelope) -> Void

    init(onResponse: @escaping (HeadsUpNotificationResponseEnvelope) -> Void = { _ in }) {
        self.onResponse = onResponse
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
    ) async {
        let request = response.notification.request
        let userInfo = request.content.userInfo.reduce(into: [String: String]()) { result, entry in
            guard let key = entry.key as? String, let value = entry.value as? String else { return }
            result[key] = value
        }
        onResponse(HeadsUpNotificationResponseEnvelope(
            requestIdentifier: request.identifier,
            categoryIdentifier: request.content.categoryIdentifier,
            actionIdentifier: response.actionIdentifier,
            userInfo: userInfo,
        ))
    }
}
