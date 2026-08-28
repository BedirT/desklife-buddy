import DesignSystem
import SwiftUI

public struct PreferenceMovementChoiceButton: View {
    @Environment(\.dsTextScale) private var textScale
    public let title: String
    public let detail: String
    public let selected: Bool
    public let increaseContrast: Bool
    public let accessibilityIdentifier: String
    public let action: () -> Void

    public init(
        title: String,
        detail: String,
        selected: Bool,
        increaseContrast: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.detail = detail
        self.selected = selected
        self.increaseContrast = increaseContrast
        self.accessibilityIdentifier = accessibilityIdentifier
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    Text(title)
                        .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                        .foregroundStyle(Color.dsTextPrimary)
                    Text(detail)
                        .font(textScale == .largest ? DSTypography.body : DSTypography.subtext)
                        .foregroundStyle(Color.dsTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: DSSpacing.xs)

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.dsAccent : Color.dsTextSecondary)
                    .accessibilityHidden(true)
            }
            .padding(DSSpacing.lg)
            .frame(maxWidth: .infinity, minHeight: textScale == .largest ? nil : 104, alignment: .topLeading)
            .background(
                selected ? Color.dsAccent.opacity(0.08) : Color.dsSurface,
                in: RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous),
            )
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(selected ? Color.dsAccent : Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#Preview("Equal-rank movement choice") {
    PreferenceMovementChoiceButton(
        title: PreferencePresentationPreviewL10n.walkOrWheel,
        detail: PreferencePresentationPreviewL10n.walkOrWheelDetail,
        selected: true,
        increaseContrast: false,
        accessibilityIdentifier: "preferencePresentation.preview.movement",
        action: {},
    )
    .padding(DSSpacing.xl)
    .frame(width: 440, height: 180)
    .background(Color.dsBackground)
}
