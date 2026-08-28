import DesignSystem
import SwiftUI

public struct PreferenceBrightnessWell: View {
    @Binding private var value: Double
    public let darkerTitle: String
    public let brighterTitle: String
    public let accessibilityLabel: String
    public let accessibilityValue: String
    public let accessibilityIdentifier: String
    public let increaseContrast: Bool
    public let onEditingChanged: (Bool) -> Void

    public init(
        value: Binding<Double>,
        darkerTitle: String,
        brighterTitle: String,
        accessibilityLabel: String,
        accessibilityValue: String,
        accessibilityIdentifier: String,
        increaseContrast: Bool,
        onEditingChanged: @escaping (Bool) -> Void,
    ) {
        _value = value
        self.darkerTitle = darkerTitle
        self.brighterTitle = brighterTitle
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
        self.accessibilityIdentifier = accessibilityIdentifier
        self.increaseContrast = increaseContrast
        self.onEditingChanged = onEditingChanged
    }

    public var body: some View {
        HStack(spacing: DSSpacing.md) {
            Label(darkerTitle, systemImage: "moon.fill")
                .font(DSTypography.caption)

            Slider(
                value: $value,
                in: 0 ... 1,
                step: 0.05,
                onEditingChanged: onEditingChanged,
            )
            .tint(Color.dsBreakHorizonFill)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityIdentifier(accessibilityIdentifier)

            Label(brighterTitle, systemImage: "sun.max.fill")
                .font(DSTypography.caption)
        }
        .padding(DSSpacing.md)
        .background(
            LinearGradient(
                colors: [Color.dsSurfaceSecondary, Color.dsBreakGlow.opacity(0.42)],
                startPoint: .leading,
                endPoint: .trailing,
            ),
            in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous),
        )
        .overlay {
            RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                .stroke(Color.dsSeparator, lineWidth: increaseContrast ? 2 : 1)
        }
    }
}

#Preview("Static background brightness") {
    PreferenceBrightnessWell(
        value: .constant(0.35),
        darkerTitle: PreferencePresentationPreviewL10n.darker,
        brighterTitle: PreferencePresentationPreviewL10n.brighter,
        accessibilityLabel: PreferencePresentationPreviewL10n.brightness,
        accessibilityValue: PreferencePresentationPreviewL10n.brightness,
        accessibilityIdentifier: "preferencePresentation.preview.brightness",
        increaseContrast: false,
        onEditingChanged: { _ in },
    )
    .padding(DSSpacing.xl)
    .frame(width: 620)
    .background(Color.dsBackground)
}
