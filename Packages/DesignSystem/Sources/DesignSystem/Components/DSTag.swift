import SwiftUI

/// Small capsule label for status and metadata.
public struct DSTag: View {
    public enum Style {
        case neutral
        case accent
        case positive
        case warning
        case danger
    }

    private let text: String
    private let style: Style

    public init(_ text: String, style: Style = .neutral) {
        self.text = text
        self.style = style
    }

    public var body: some View {
        Text(text)
            .font(DSTypography.caption.weight(.medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xs)
            .background(foreground.opacity(0.14))
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .neutral: .dsTextSecondary
        case .accent: .dsAccent
        case .positive: .dsPositive
        case .warning: .dsWarning
        case .danger: .dsDanger
        }
    }
}

#Preview("Tags") {
    HStack(spacing: DSSpacing.sm) {
        DSTag(DesignSystemL10n.Tags.neutral)
        DSTag(DesignSystemL10n.Tags.new, style: .accent)
        DSTag(DesignSystemL10n.Tags.done, style: .positive)
        DSTag(DesignSystemL10n.Tags.expiring, style: .warning)
        DSTag(DesignSystemL10n.Tags.failed, style: .danger)
    }
    .padding(DSSpacing.lg)
    .background(Color.dsBackground)
}
