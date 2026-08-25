import SwiftUI

/// Standard button. Full-width by default; wrap in a frame to constrain.
public struct DSButton: View {
    public enum Style {
        case primary
        case secondary
        case destructive
    }

    private let title: String
    private let systemImage: String?
    private let style: Style
    private let action: () -> Void

    public init(
        _ title: String,
        systemImage: String? = nil,
        style: Style = .primary,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.systemImage = systemImage
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
        }
        .buttonStyle(DSButtonStyle(style: style))
    }
}

private struct DSButtonStyle: ButtonStyle {
    let style: DSButton.Style

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSTypography.headline)
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(DSMotion.tap, value: configuration.isPressed)
    }

    private var background: Color {
        switch style {
        case .primary: .dsAccent
        case .secondary: .dsSurfaceSecondary
        case .destructive: .dsDanger
        }
    }

    private var foreground: Color {
        switch style {
        case .primary: .dsOnAccent
        case .secondary: .dsTextPrimary
        case .destructive: .white
        }
    }
}

#Preview("Buttons") {
    VStack(spacing: DSSpacing.md) {
        DSButton(DesignSystemL10n.Buttons.continueTitle, style: .primary) {}
        DSButton(DesignSystemL10n.Buttons.addItem, systemImage: "plus", style: .secondary) {}
        DSButton(DesignSystemL10n.Buttons.delete, style: .destructive) {}
    }
    .padding(DSSpacing.lg)
    .background(Color.dsBackground)
}
