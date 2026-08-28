import DesignSystem
import SwiftUI

/// Wordless, noninteractive completion presentation. Window lifetime stays App-owned.
public struct CompletionCapsuleView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var hasEntered = false
    @State private var hasCrinkled = false
    private let endpoint: CompletionCapsuleEndpoint

    public init(endpoint: CompletionCapsuleEndpoint = .automatic) {
        self.endpoint = endpoint
    }

    public var body: some View {
        DSHeadsUpCompletionCapsule(
            crinkleProgress: crinkleProgress,
            reduceTransparency: reduceTransparency,
            increaseContrast: colorSchemeContrast == .increased,
        )
        .opacity(isEntered ? 1 : 0.55)
        .offset(y: isEntered ? 0 : -DSSpacing.sm)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: appear)
    }

    private var isEntered: Bool {
        switch endpoint {
        case .automatic: hasEntered
        case .before: false
        case .after: true
        }
    }

    private var crinkleProgress: CGFloat {
        switch endpoint {
        case .automatic: hasCrinkled ? 1 : 0
        case .before: 0
        case .after: 1
        }
    }

    private func appear() {
        guard endpoint == .automatic else { return }
        withAnimation(DSMotion.headsUpEnter) {
            hasEntered = true
        }
        withAnimation(DSMotion.headsUpCompletionCrinkle) {
            hasCrinkled = true
        }
    }
}

public enum CompletionCapsuleEndpoint: CaseIterable, Equatable, Sendable {
    case automatic
    case before
    case after
}

/// Visual-only fixed-placement context for the passive completion beat.
public struct CompletionCapsulePlacementPreview: View {
    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            Color.dsBackground
            VStack(spacing: 0) {
                Color.dsSurface
                    .frame(height: DSSpacing.xxl)
                    .accessibilityHidden(true)
                Spacer()
            }
            CompletionCapsuleView(endpoint: .after)
                .padding(.top, DSSpacing.xxl)
        }
        .frame(width: 1000, height: 220)
        .accessibilityIdentifier("completionCapsule.placementPreview")
    }
}

private struct CompletionCapsulePreviewCanvas: View {
    let endpoint: CompletionCapsuleEndpoint

    var body: some View {
        CompletionCapsuleView(endpoint: endpoint)
            .padding(DSSpacing.xxl)
            .frame(width: 360, height: 140)
            .background(Color.dsBackground)
    }
}

#Preview("Completion - resting endpoint") {
    CompletionCapsulePreviewCanvas(endpoint: .before)
}

#Preview("Completion - crinkled endpoint") {
    CompletionCapsulePreviewCanvas(endpoint: .after)
}

#Preview("Completion - fixed top-center context") {
    CompletionCapsulePlacementPreview()
}
