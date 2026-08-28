import DesignSystem
import SwiftUI

/// Visual-only seam. The App coordinator owns screen discovery and actual panel coordinates.
public struct HeadsUpPlacementPreview: View {
    private let model: HeadsUpModel

    public init(model: HeadsUpModel) {
        self.model = model
    }

    public var body: some View {
        ZStack(alignment: .top) {
            Color.dsBackground

            VStack(spacing: 0) {
                menuBar
                Spacer()
            }

            HeadsUpView(model: model, entranceEndpoint: .after)
                .padding(.top, DSSpacing.xxl)
                .padding(.horizontal, DSSpacing.xl)
        }
        .frame(width: 1000, height: 220)
        .accessibilityIdentifier("headsUp.placementPreview")
    }

    private var menuBar: some View {
        Color.dsSurface
            .frame(height: DSSpacing.xxl)
            .accessibilityHidden(true)
    }
}

#Preview("Fixed top-center placement context") {
    HeadsUpPlacementPreview(
        model: .preview(scope: .visual, phase: .approaching(.seconds15)),
    )
}
