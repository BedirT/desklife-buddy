import Foundation

enum AppL10n {
    static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }

    static let appName = string("app.name", default: "Base Mac App")
    static let settingsTitle = string("app.settings.title", default: "Settings")
    static let placeholderTitle = string("app.placeholder.title", default: "Ready to build")
    static let placeholderMessage = string(
        "app.placeholder.message",
        default: "Replace this placeholder with your first macOS feature.",
    )
    static let settingsPlaceholderTitle = string("app.settings.placeholder.title", default: "No settings yet")
    static let settingsPlaceholderMessage = string(
        "app.settings.placeholder.message",
        default: "Add settings when the app needs user preferences.",
    )
}
