import DesignSystem
import SwiftUI

public struct PreferencePresentationChoiceButton: View {
    @Environment(\.dsTextScale) private var textScale
    public let systemImage: String
    public let title: String
    public let detail: String
    public let selected: Bool
    public let increaseContrast: Bool
    public let accessibilityIdentifier: String
    public let action: () -> Void

    public init(
        systemImage: String,
        title: String,
        detail: String,
        selected: Bool,
        increaseContrast: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void,
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.selected = selected
        self.increaseContrast = increaseContrast
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                HStack(alignment: .top, spacing: DSSpacing.md) {
                    Image(systemName: systemImage)
                        .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                        .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                        .accessibilityHidden(true)

                    Spacer(minLength: DSSpacing.sm)

                    DSSelectionIndicator(selected: selected)
                }

                Text(title)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)

                Text(detail)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: textScale == .largest ? 0 : 150, alignment: .topLeading)
            .padding(DSSpacing.lg)
            .background(
                selected ? Color.dsAccent.opacity(0.08) : Color.dsSurface,
                in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
            )
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(
                        selected ? Color.dsAccent : Color.dsSeparator,
                        lineWidth: selected || increaseContrast ? 2 : 1,
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#Preview("Static presentation choice") {
    PreferencePresentationChoiceButton(
        systemImage: "rectangle.dashed",
        title: PreferencePresentationPreviewL10n.staticPresentation,
        detail: PreferencePresentationPreviewL10n.staticPresentationDetail,
        selected: true,
        increaseContrast: false,
        accessibilityIdentifier: "preferencePresentation.preview.presentation",
        action: {},
    )
    .padding(DSSpacing.xl)
    .frame(width: 360, height: 260)
    .background(Color.dsBackground)
}
