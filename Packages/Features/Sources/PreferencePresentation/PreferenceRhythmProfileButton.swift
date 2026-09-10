import AppKit
import DesignSystem
import SwiftUI

public enum PreferenceRhythmStage: CaseIterable, Equatable, Identifiable, Sendable {
    case gentle
    case balanced
    case frequentMovement

    public var id: Self { self }

    var resourceName: String {
        switch self {
        case .gentle: "gentle-ceramic-stage-v2"
        case .balanced: "balanced-ceramic-stage"
        case .frequentMovement: "frequent-ceramic-stage-v2"
        }
    }
}

public struct PreferenceRhythmStageView: View {
    public let stage: PreferenceRhythmStage

    private static var imageCache: [String: CGImage] = [:]

    public init(stage: PreferenceRhythmStage) {
        self.stage = stage
    }

    public var body: some View {
        GeometryReader { proxy in
            Group {
                if let cgImage {
                    Image(decorative: cgImage, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                } else {
                    Color.dsSurfaceSecondary
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .accessibilityHidden(true)
    }

    var cgImage: CGImage? {
        if let cachedImage = Self.imageCache[stage.resourceName] {
            return cachedImage
        }

        guard let url = Bundle.module.url(forResource: stage.resourceName, withExtension: "png"),
              let image = NSImage(contentsOf: url)
        else {
            return nil
        }

        var rect = CGRect(origin: .zero, size: image.size)
        let resolvedImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        Self.imageCache[stage.resourceName] = resolvedImage
        return resolvedImage
    }
}

public struct PreferenceRhythmProfileButton: View {
    @Environment(\.dsTextScale) private var textScale
    public let stage: PreferenceRhythmStage
    public let title: String
    public let subtitle: String?
    public let accessibilityLabel: String
    public let selected: Bool
    public let increaseContrast: Bool
    public let accessibilityIdentifier: String
    public let horizontalLayout: Bool
    public let compactVerticalLayout: Bool
    public let castsSelectionShadow: Bool
    public let action: () -> Void

    public init(
        stage: PreferenceRhythmStage,
        title: String,
        subtitle: String?,
        accessibilityLabel: String,
        selected: Bool,
        increaseContrast: Bool,
        accessibilityIdentifier: String,
        horizontalLayout: Bool = false,
        compactVerticalLayout: Bool = false,
        castsSelectionShadow: Bool = true,
        action: @escaping () -> Void,
    ) {
        self.stage = stage
        self.title = title
        self.subtitle = subtitle
        self.accessibilityLabel = accessibilityLabel
        self.selected = selected
        self.increaseContrast = increaseContrast
        self.accessibilityIdentifier = accessibilityIdentifier
        self.horizontalLayout = horizontalLayout
        self.compactVerticalLayout = compactVerticalLayout
        self.castsSelectionShadow = castsSelectionShadow
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                if horizontalLayout {
                    HStack(spacing: 0) {
                        PreferenceRhythmStageView(stage: stage)
                            .frame(
                                width: DSSpacing.xxl * 4,
                                height: DSSpacing.xxl * 3,
                            )
                        cardCopy
                            .padding(DSSpacing.md)
                    }
                } else if textScale == .largest {
                    HStack(spacing: 0) {
                        PreferenceRhythmStageView(stage: stage)
                            .frame(width: 188)
                        cardCopy
                            .padding(DSSpacing.md)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        PreferenceRhythmStageView(stage: stage)
                            .frame(height: compactVerticalLayout ? DSSpacing.xxl * 3 : 116)
                        cardCopy
                            .padding(.horizontal, DSSpacing.md)
                            .padding(.vertical, DSSpacing.sm)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .fill(Color.dsSurface)
                    .overlay {
                        if selected {
                            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                                .fill(Color.dsAccent.opacity(0.08))
                        }
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .stroke(
                        selected ? Color.dsAccent : Color.dsSeparator,
                        lineWidth: increaseContrast ? 2 : 1,
                    )
            }
            .shadow(
                color: selected && castsSelectionShadow ? Color.dsAccent.opacity(0.14) : Color.clear,
                radius: DSSpacing.sm,
                y: DSSpacing.xs,
            )
            .contentShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var cardCopy: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            HStack(alignment: .top, spacing: DSSpacing.sm) {
                Text(title)
                    .font(textScale == .largest ? DSTypography.title : DSTypography.headline)
                    .foregroundStyle(Color.dsTextPrimary)
                    .lineLimit(2)
                Spacer(minLength: DSSpacing.xs)
                DSSelectionIndicator(selected: selected)
            }

            if let subtitle {
                Text(subtitle)
                    .font(textScale == .largest ? DSTypography.body : DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview("Ceramic rhythm profile") {
    PreferenceRhythmProfileButton(
        stage: .balanced,
        title: PreferencePresentationPreviewL10n.balanced,
        subtitle: PreferencePresentationPreviewL10n.balancedDetail,
        accessibilityLabel: PreferencePresentationPreviewL10n.balanced,
        selected: true,
        increaseContrast: false,
        accessibilityIdentifier: "preferencePresentation.preview.rhythm",
        action: {},
    )
    .padding(DSSpacing.xl)
    .frame(width: 360, height: 300)
    .background(Color.dsBackground)
}
