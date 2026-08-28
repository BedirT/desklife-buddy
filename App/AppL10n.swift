import Foundation

enum AppL10n {
    static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.main.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }

    static let appName = string("app.name", default: "Base Mac App")
    static let settingsTitle = string("app.settings.title", default: "Settings")
    static let onboardingTitle = string("app.onboarding.title", default: "Set up breaks")
    static let weeklyRhythmTitle = string("app.weekly.title", default: "Weekly rhythm")
    static let historyExportSuggestedFilename = string(
        "app.settings.privacy.export.suggested_filename",
        default: "Break History",
    )
    static let settingsPlaceholderTitle = string("app.settings.placeholder.title", default: "No settings yet")
    static let settingsPlaceholderMessage = string(
        "app.settings.placeholder.message",
        default: "Add settings when the app needs user preferences.",
    )
}
