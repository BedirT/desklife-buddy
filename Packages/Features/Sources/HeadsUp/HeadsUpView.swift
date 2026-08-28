import DesignSystem
import SwiftUI

/// Pointer-first capsule content. Window activation, focus, placement, and Escape stay App-owned.
public struct HeadsUpView: View {
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.colorSchemeContrast) private var systemContrast
    @Environment(\.dsTextScale) private var textScale
    @State private var model: HeadsUpModel
    @State private var hasEntered = false
    private let entranceEndpoint: HeadsUpEntranceEndpoint

    public init(
        model: HeadsUpModel,
        entranceEndpoint: HeadsUpEntranceEndpoint = .automatic,
    ) {
        _model = State(initialValue: model)
        self.entranceEndpoint = entranceEndpoint
    }

    public var body: some View {
        DSHeadsUpCapsule(
            title: presentation.title,
            detail: presentation.detail,
            indicator: indicator,
            showsActions: presentation.showsActions,
            nowTitle: model.capsuleActions.nowTitle,
            laterTitle: model.capsuleActions.laterTitle,
            laterOptions: model.capsuleActions.laterOptions.map(\.title),
            laterOptionAccessibilityIdentifiers: model.capsuleActions.laterOptions
                .map(\.accessibilityIdentifier),
            statusAccessibilityLabel: presentation.statusAccessibilityLabel,
            nowAccessibilityLabel: HeadsUpL10n.startNow,
            laterAccessibilityLabel: HeadsUpL10n.later,
            accessibilityIdentifier: "headsUp.capsule",
            reduceTransparency: reduceTransparency,
            increaseContrast: increaseContrast,
            nowAction: model.startNow,
            laterAction: chooseLater,
        )
        .opacity(isEntered ? 1 : HeadsUpEntrancePresentation.initialOpacity)
        .offset(y: isEntered ? 0 : -DSSpacing.sm)
        .animation(
            allowsAuthoredMotion ? DSMotion.headsUpGlint : nil,
            value: presentation.normalizedGlint,
        )
        .environment(
            \.dsTextScale,
            presentation.accessibility.largeText ? .largest : textScale,
        )
        .onHover(perform: model.setHovered)
        .onAppear(perform: appear)
    }

    private var presentation: HeadsUpPresentation {
        model.presentation
    }

    private var indicator: DSHeadsUpCapsule.Indicator? {
        guard presentation.showsDecorativeIndicator else { return nil }

        switch presentation.phase {
        case let .approaching(mark):
            return .sun(
                glint: CGFloat(presentation.normalizedGlint),
                descent: reduceMotion
                    ? reducedMotionDescent(for: mark)
                    : CGFloat(presentation.approachProgress),
            )
        case .landedWaiting:
            return .sun(glint: CGFloat(presentation.normalizedGlint), descent: 1)
        case .hold:
            return .hold
        }
    }

    private var reduceMotion: Bool {
        renderedAccessibility.reduceMotion
    }

    private var allowsAuthoredMotion: Bool {
        !reduceMotion
            && !presentation.accessibility.staticPresentation
            && !presentation.accessibility.textOnly
    }

    private var isEntered: Bool {
        switch entranceEndpoint {
        case .automatic:
            hasEntered || !allowsAuthoredMotion
        case .before:
            false
        case .after:
            true
        }
    }

    private var reduceTransparency: Bool {
        renderedAccessibility.reduceTransparency
    }

    private var increaseContrast: Bool {
        renderedAccessibility.increaseContrast
    }

    private var renderedAccessibility: HeadsUpRenderedAccessibility {
        HeadsUpRenderedAccessibility(
            systemReduceMotion: systemReduceMotion,
            systemReduceTransparency: systemReduceTransparency,
            systemIncreaseContrast: systemContrast == .increased,
            preview: presentation.accessibility,
        )
    }

    private func reducedMotionDescent(for mark: HeadsUpApproachMark) -> CGFloat {
        switch mark.seconds {
        case let seconds where seconds >= 16:
            0
        case 6 ... 15:
            0.5
        default:
            0.85
        }
    }

    private func chooseLater(at index: Int) {
        let options = model.capsuleActions.laterOptions
        guard options.indices.contains(index) else { return }
        model.chooseLater(options[index])
    }

    private func appear() {
        model.presentationDidAppear()
        guard entranceEndpoint == .automatic, allowsAuthoredMotion else {
            hasEntered = true
            return
        }
        withAnimation(DSMotion.headsUpEnter) {
            hasEntered = true
        }
    }
}

public enum HeadsUpEntranceEndpoint: CaseIterable, Equatable, Sendable {
    case automatic
    case before
    case after
}

private enum HeadsUpEntrancePresentation {
    static let initialOpacity = 0.55
}

struct HeadsUpRenderedAccessibility: Equatable {
    let reduceMotion: Bool
    let reduceTransparency: Bool
    let increaseContrast: Bool

    init(
        systemReduceMotion: Bool,
        systemReduceTransparency: Bool,
        systemIncreaseContrast: Bool,
        preview: HeadsUpAccessibility,
    ) {
        reduceMotion = systemReduceMotion || preview.reduceMotion
        reduceTransparency = systemReduceTransparency || preview.reduceTransparency
        increaseContrast = systemIncreaseContrast || preview.increaseContrast
    }
}

private struct HeadsUpPreviewCanvas: View {
    let model: HeadsUpModel

    var body: some View {
        HeadsUpView(model: model)
            .padding(DSSpacing.xxl)
            .frame(width: 760, height: 150, alignment: .top)
            .background(Color.dsBackground)
    }
}

#Preview("Approach — visual") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual))
}

#Preview("Approach — movement") {
    HeadsUpPreviewCanvas(model: .preview(scope: .movement))
}

#Preview("Approach — merged") {
    HeadsUpPreviewCanvas(model: .preview(scope: .merged))
}

#Preview("Approach — 45 seconds") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, phase: .approaching(.seconds45)))
}

#Preview("Approach — 30 seconds") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, phase: .approaching(.seconds30)))
}

#Preview("Approach — 15 seconds") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, phase: .approaching(.seconds15)))
}

#Preview("Approach — 5 seconds") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, phase: .approaching(.seconds5)))
}

#Preview("Hovered actions") {
    HeadsUpPreviewCanvas(model: .preview(scope: .merged, isHovered: true))
}

#Preview("Landed and waiting") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, phase: .landedWaiting))
}

#Preview("Calendar hold") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .visual,
        phase: .hold(.calendarBusy(until: Date(timeIntervalSince1970: 1_800_000_000))),
    ))
}

#Preview("Text only") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .visual,
        accessibility: .init(textOnly: true),
    ))
}

#Preview("Reduce Motion") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .visual,
        phase: .approaching(.seconds15),
        accessibility: .init(reduceMotion: true),
    ))
}

#Preview("Static presentation") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .visual,
        accessibility: .init(staticPresentation: true),
    ))
}

#Preview("Reactive glint left") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, normalizedGlint: -1))
}

#Preview("Reactive glint right") {
    HeadsUpPreviewCanvas(model: .preview(scope: .visual, normalizedGlint: 1))
}

#Preview("Reduce Transparency") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .movement,
        accessibility: .init(reduceTransparency: true),
    ))
}

#Preview("Increase Contrast") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .merged,
        isHovered: true,
        accessibility: .init(increaseContrast: true),
    ))
}

#Preview("+35% text") {
    HeadsUpPreviewCanvas(model: .preview(scope: .merged, isHovered: true))
        .environment(\.dynamicTypeSize, .xxxLarge)
        .environment(\.dsTextScale, .plusThirtyFivePercent)
}

#Preview("Largest text") {
    HeadsUpPreviewCanvas(model: .preview(
        scope: .merged,
        isHovered: true,
        accessibility: .init(
            reduceMotion: true,
            reduceTransparency: true,
            increaseContrast: true,
            largeText: true,
        ),
    ))
    .environment(\.dynamicTypeSize, .accessibility3)
    .environment(\.dsTextScale, .largest)
}
