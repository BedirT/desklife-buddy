import Foundation

protocol HeadsUpAuthorizationStore: AnyObject {
    func load() -> HeadsUpNotificationAuthorizationState
    func save(_ state: HeadsUpNotificationAuthorizationState)
}

final class UserDefaultsHeadsUpAuthorizationStore: HeadsUpAuthorizationStore {
    private enum Key {
        static let hasPresentedExplainer = "heads-up.authorization.has-presented-explainer"
        static let hasRequestedAuthorization = "heads-up.authorization.has-requested"
        static let usesInAppHeadsUp = "heads-up.authorization.uses-in-app"
        static let hasBeenAuthorized = "heads-up.authorization.has-been-authorized"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HeadsUpNotificationAuthorizationState {
        HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: defaults.bool(forKey: Key.hasPresentedExplainer),
            hasRequestedAuthorization: defaults.bool(forKey: Key.hasRequestedAuthorization),
            usesInAppHeadsUp: defaults.bool(forKey: Key.usesInAppHeadsUp),
            hasBeenAuthorized: defaults.bool(forKey: Key.hasBeenAuthorized),
        )
    }

    func save(_ state: HeadsUpNotificationAuthorizationState) {
        defaults.set(state.hasPresentedExplainer, forKey: Key.hasPresentedExplainer)
        defaults.set(state.hasRequestedAuthorization, forKey: Key.hasRequestedAuthorization)
        defaults.set(state.usesInAppHeadsUp, forKey: Key.usesInAppHeadsUp)
        defaults.set(state.hasBeenAuthorized, forKey: Key.hasBeenAuthorized)
    }
}
