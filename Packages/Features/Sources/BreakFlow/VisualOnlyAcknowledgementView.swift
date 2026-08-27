import DesignSystem
import SwiftUI

struct VisualOnlyAcknowledgementView: View {
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dsTextScale) private var textScale
    @State private var model: BreakFlowModel

    private let accessibilityOverride: BreakFlowAccessibility?

    init(
        model: BreakFlowModel,
        accessibilityOverride: BreakFlowAccessibility?,
    ) {
        _model = State(initialValue: model)
        self.accessibilityOverride = accessibilityOverride
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                BreakFlowField(staticPresentation: accessibility.staticPresentation)
                    .accessibilityHidden(true)
                Text(BreakFlowL10n.visualOnlyAcknowledgement)
                    .font(DSTypography.breakInstruction(pointSize: instructionSize))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(primaryInk)
                    .frame(maxWidth: 920)
                    .fixedSize(horizontal: false, vertical: true)
                    .background { staticTextBackdrop }
                    .position(
                        x: proxy.size.width / 2,
                        y: proxy.size.height * verticalPosition,
                    )
                    .accessibilityIdentifier("merged.visualOnly.status")
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("merged.surface")
        .onKeyPress(.escape) {
            model.acknowledgementDidFinish()
            return .handled
        }
        .task {
            do {
                try await Task.sleep(
                    for: .seconds(model.acknowledgementDurationSeconds),
                )
            } catch {
                return
            }
            model.acknowledgementDidFinish()
        }
    }

    private var accessibility: BreakFlowAccessibility {
        accessibilityOverride ?? BreakFlowAccessibility(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
        )
    }

    private var instructionSize: CGFloat {
        textScale.apply(to: DSTypography.breakLongInstructionSize)
    }

    private var verticalPosition: CGFloat {
        textScale == .largest ? 0.35 : 0.5
    }

    private var primaryInk: Color {
        if accessibility.staticPresentation { return .dsStaticText }
        return accessibility.increaseContrast ? .dsBreakTextPrimaryIncreased : .dsBreakTextPrimary
    }

    @ViewBuilder
    private var staticTextBackdrop: some View {
        if accessibility.staticPresentation {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(Color.dsStaticTextScrim)
                .padding(.horizontal, -DSSpacing.lg)
                .padding(.vertical, -DSSpacing.md)
        }
    }
}

#Preview("BR-10 · Dark") {
    VisualOnlyAcknowledgementView(
        model: .preview(.visualOnlyAcknowledgement),
        accessibilityOverride: nil,
    )
    .environment(\.colorScheme, .dark)
    .frame(width: 1440, height: 900)
}

#Preview("BR-10 · Static presentation") {
    ZStack {
        Color.dsBackground
        VisualOnlyAcknowledgementView(
            model: .preview(.visualOnlyAcknowledgement),
            accessibilityOverride: .init(staticPresentation: true),
        )
    }
    .frame(width: 1440, height: 900)
}

#Preview("BR-10 · Largest text") {
    VisualOnlyAcknowledgementView(
        model: .preview(.visualOnlyAcknowledgement),
        accessibilityOverride: nil,
    )
    .environment(\.dynamicTypeSize, .accessibility3)
    .frame(width: 1440, height: 900)
}
