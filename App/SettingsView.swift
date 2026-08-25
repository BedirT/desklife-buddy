import DesignSystem
import SwiftUI

struct SettingsView: View {
    var body: some View {
        DSEmptyState(
            systemImage: "gearshape",
            title: AppL10n.settingsPlaceholderTitle,
            message: AppL10n.settingsPlaceholderMessage,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
        .accessibilityIdentifier("settings.placeholder")
        .frame(width: 460, height: 240)
    }
}

#Preview("Settings") {
    SettingsView()
}
