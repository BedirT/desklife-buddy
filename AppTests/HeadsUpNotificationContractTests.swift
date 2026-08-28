import Foundation
import HeadsUp
import Testing
import UserNotifications
@testable import App

@Suite("Heads-up notification contract")
struct HeadsUpNotificationContractTests {
    @Test("Stable delivery UUID is the sole native and response identity")
    func stableIdentifiers() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000ABCDEF")!
        let request = HeadsUpNotificationRequest(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
        )

        #expect(HeadsUpNotificationIdentifiers.category == "heads-up.opportunity.v1")
        #expect(HeadsUpNotificationIdentifiers.startNowAction == "heads-up.action.start-now.v1")
        #expect(HeadsUpNotificationIdentifiers.snoozeFiveAction == "heads-up.action.snooze-five.v1")
        #expect(HeadsUpNotificationIdentifiers.moreOptionsAction == "heads-up.action.more-options.v1")
        #expect(HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey == "heads-up.delivery-id")
        #expect(HeadsUpNotificationIdentifiers.defaultAction == UNNotificationDefaultActionIdentifier)
        #expect(HeadsUpNotificationIdentifiers.dismissAction == UNNotificationDismissActionIdentifier)
        #expect(request.identifier == "heads-up.delivery.00000000-0000-0000-0000-000000abcdef")
        #expect(request.userInfo == [
            "heads-up.delivery-id": deliveryID.uuidString.lowercased(),
        ])
        #expect(request.scope == .visual)
        #expect(request == HeadsUpNotificationRequest(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .visual),
        ))
        #expect(request != HeadsUpNotificationRequest(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .movement),
        ))
    }

    @Test("Request preserves approved Feature copy and an ordinary silent immediate contract")
    func requestContract() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000043")!
        let request = HeadsUpNotificationRequest(
            deliveryID: deliveryID,
            content: HeadsUpNotificationContent(scope: .merged),
        )
        let frameworkRequest = UNUserNotificationCenterAdapter.makeRequest(request)
        let content = frameworkRequest.content

        #expect(request.scope == .merged)
        #expect(frameworkRequest.identifier == request.identifier)
        #expect(content.title == "Visual reset and movement")
        #expect(content.body == "Both are due. One break covers them.")
        #expect(content.categoryIdentifier == HeadsUpNotificationIdentifiers.category)
        #expect(content.interruptionLevel == .active)
        #expect(content.sound == nil)
        #expect(content.badge == nil)
        #expect(frameworkRequest.trigger == nil)
    }

    @Test("Registered actions are exact, ordinary, and ordered")
    func registeredActions() throws {
        let categories = UNUserNotificationCenterAdapter.makeCategories()
        let category = try #require(categories.first)

        #expect(categories.count == 1)
        #expect(category.identifier == HeadsUpNotificationIdentifiers.category)
        #expect(category.actions.map(\.identifier) == [
            HeadsUpNotificationIdentifiers.startNowAction,
            HeadsUpNotificationIdentifiers.snoozeFiveAction,
            HeadsUpNotificationIdentifiers.moreOptionsAction,
        ])
        #expect(category.actions.map(\.title) == ["Start now", "In 5 minutes", "More options"])
        #expect(category.actions.map(\.options.rawValue) == [
            UNNotificationActionOptions.foreground.rawValue,
            0,
            UNNotificationActionOptions.foreground.rawValue,
        ])
        #expect(category.options == [.customDismissAction])
    }

    @Test("Response mapper validates category, request identity, and delivery identity")
    func responseValidation() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000044")!
        #expect(
            map(action: HeadsUpNotificationIdentifiers.startNowAction, deliveryID: deliveryID)
                == .startNow(deliveryID),
        )
        #expect(
            map(action: HeadsUpNotificationIdentifiers.snoozeFiveAction, deliveryID: deliveryID)
                == .snoozeFiveMinutes(deliveryID),
        )
        #expect(
            map(action: HeadsUpNotificationIdentifiers.moreOptionsAction, deliveryID: deliveryID)
                == .moreOptions(deliveryID),
        )
        #expect(
            map(action: HeadsUpNotificationIdentifiers.dismissAction, deliveryID: deliveryID)
                == .dismiss(deliveryID),
        )
        #expect(
            map(action: HeadsUpNotificationIdentifiers.defaultAction, deliveryID: deliveryID)
                == .defaultBodyTapAwaitingOwnerDecision(deliveryID),
        )

        let wrongRequest = envelope(
            action: HeadsUpNotificationIdentifiers.startNowAction,
            deliveryID: deliveryID,
            requestIdentifier: "wrong",
        )
        #expect(HeadsUpNotificationResponseMapper.map(wrongRequest) == .unknown)

        let wrongUserInfo = HeadsUpNotificationResponseEnvelope(
            requestIdentifier: HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID),
            categoryIdentifier: HeadsUpNotificationIdentifiers.category,
            actionIdentifier: HeadsUpNotificationIdentifiers.startNowAction,
            userInfo: [
                HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey: UUID().uuidString.lowercased(),
            ],
        )
        #expect(HeadsUpNotificationResponseMapper.map(wrongUserInfo) == .unknown)

        let wrongCategory = HeadsUpNotificationResponseEnvelope(
            requestIdentifier: HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID),
            categoryIdentifier: "wrong",
            actionIdentifier: HeadsUpNotificationIdentifiers.startNowAction,
            userInfo: [
                HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey: deliveryID.uuidString.lowercased(),
            ],
        )
        #expect(HeadsUpNotificationResponseMapper.map(wrongCategory) == .unknown)
    }

    @Test("Dismiss and unresolved body taps remain explicit lifecycle routes")
    func factFreeActionsRemainExplicit() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000045")!
        #expect(HeadsUpNotificationResponseMapper.route(
            .defaultBodyTapAwaitingOwnerDecision(deliveryID),
        ) == .defaultBodyTapAwaitingOwnerDecision(deliveryID))
        #expect(HeadsUpNotificationResponseMapper.route(
            .dismiss(deliveryID),
        ) == .dismissedWithoutAction(deliveryID))
        #expect(HeadsUpNotificationResponseMapper.route(.unknown) == nil)
    }

    @Test("Default body behavior is injected without a production default")
    func defaultBodyBehaviorIsInjected() {
        let deliveryID = UUID(uuidString: "00000000-0000-0000-0000-000000000046")!
        let response = HeadsUpNotificationResponse.defaultBodyTapAwaitingOwnerDecision(deliveryID)

        #expect(HeadsUpNotificationResponseMapper.route(
            response,
            defaultBodyTapBehavior: .startNow,
        ) == .startNow(deliveryID))
        #expect(HeadsUpNotificationResponseMapper.route(
            response,
            defaultBodyTapBehavior: .moreOptions,
        ) == .moreOptions(deliveryID))
        #expect(HeadsUpNotificationResponseMapper.route(
            response,
            defaultBodyTapBehavior: .noAction,
        ) == .dismissedWithoutAction(deliveryID))
    }

    private func map(
        action: String,
        deliveryID: UUID,
    ) -> HeadsUpNotificationResponse {
        HeadsUpNotificationResponseMapper.map(envelope(action: action, deliveryID: deliveryID))
    }

    private func envelope(
        action: String,
        deliveryID: UUID,
        requestIdentifier: String? = nil,
    ) -> HeadsUpNotificationResponseEnvelope {
        HeadsUpNotificationResponseEnvelope(
            requestIdentifier: requestIdentifier
                ?? HeadsUpNotificationIdentifiers.requestIdentifier(for: deliveryID),
            categoryIdentifier: HeadsUpNotificationIdentifiers.category,
            actionIdentifier: action,
            userInfo: [
                HeadsUpNotificationIdentifiers.deliveryIDUserInfoKey:
                    deliveryID.uuidString.lowercased(),
            ],
        )
    }
}
