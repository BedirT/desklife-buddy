import SwiftUI

/// App-owned display metadata for a durable bundle identifier.
///
/// Settings persists only `bundleID`. Names and icons are presentation-only and
/// may be refreshed whenever the App builds this value.
public struct SettingsExcludedApplicationPresentation: Identifiable {
    public let bundleID: String
    public let displayName: String
    public let icon: Image

    public var id: String { bundleID }

    public init(bundleID: String, displayName: String, icon: Image) {
        self.bundleID = bundleID
        self.displayName = displayName
        self.icon = icon
    }
}

public typealias SettingsExcludedApplicationPicker = @MainActor () async
    -> SettingsExcludedApplicationPresentation?
