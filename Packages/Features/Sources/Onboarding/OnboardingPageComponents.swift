import DesignSystem
import PreferencePresentation
import SwiftUI

struct OnboardingPageHeader: View {
    let title: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            Text(title)
                .font(DSTypography.largeTitle)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(DSTypography.body)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OnboardingFactRow: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(alignment: .top, spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsAccent)
                .frame(width: DSSpacing.xl)
                .accessibilityHidden(true)
            Text(title)
                .font(DSTypography.body)
                .foregroundStyle(Color.dsTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct OnboardingSystemFact: View {
    let title: String
    let enabled: Bool

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(enabled ? Color.dsAccent : Color.dsTextSecondary)
                .accessibilityHidden(true)
            Text(title)
                .foregroundStyle(Color.dsTextPrimary)
            Text(enabled ? OnboardingL10n.on : OnboardingL10n.off)
                .foregroundStyle(Color.dsTextSecondary)
        }
        .font(DSTypography.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(enabled ? OnboardingL10n.on : OnboardingL10n.off)
    }
}

struct OnboardingSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DSSpacing.md) {
            Text(title)
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer(minLength: DSSpacing.md)
            Text(value)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

extension OnboardingRhythm {
    var preferenceStage: PreferenceRhythmStage {
        switch self {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        }
    }

    var identifier: String {
        switch self {
        case .gentle: "gentle"
        case .balanced: "balanced"
        case .frequentMovement: "frequentMovement"
        }
    }
}

extension OnboardingMovement {
    var identifier: String {
        switch self {
        case .walkOrEquivalent: "walkOrEquivalent"
        case .seatedActive: "seatedActive"
        case .mixed: "mixed"
        case .positionChangeOnly: "positionChangeOnly"
        }
    }
}

extension OnboardingPresentation {
    var identifier: String {
        switch self {
        case .standard: "standard"
        case .staticPresentation: "static"
        }
    }
}

#Preview("Onboarding fact row") {
    OnboardingFactRow(
        systemImage: "keyboard",
        title: OnboardingL10n.estimatedUse,
    )
    .padding()
    .frame(width: 560)
}
