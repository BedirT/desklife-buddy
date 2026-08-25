import DesignSystem
import SwiftUI

@main
struct BaseMacApp: App {
    var body: some Scene {
        WindowGroup(AppL10n.appName, id: "main") {
            RootView()
                .frame(minWidth: 900, minHeight: 560)
                .tint(.dsAccent)
                .containerBackground(Color.dsBackground, for: .window)
        }

        Settings {
            SettingsView()
        }
    }
}
