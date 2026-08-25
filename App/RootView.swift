import DesignSystem
import SwiftUI

/// Composition root for the primary desktop window.
struct RootView: View {
    var body: some View {
        DSEmptyState(
            systemImage: "macwindow",
            title: AppL10n.placeholderTitle,
            message: AppL10n.placeholderMessage,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
        .accessibilityIdentifier("root.placeholder")
    }
}

#Preview {
    RootView()
        .frame(width: 900, height: 560)
}
