import SwiftUI

/// Surface container for grouped content. Flat by design — separation comes
/// from the surface/background contrast, not shadows.
public struct DSCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.dsSurface)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
    }
}

#Preview("Card") {
    DSCard {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(DesignSystemL10n.Card.previewTitle).font(DSTypography.headline).foregroundStyle(Color.dsTextPrimary)
            Text(DesignSystemL10n.Card.previewText)
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
        }
    }
    .padding(DSSpacing.lg)
    .background(Color.dsBackground)
}
