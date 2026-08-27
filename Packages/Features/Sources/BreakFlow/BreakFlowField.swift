import DesignSystem
import SwiftUI

struct BreakFlowField: View {
    let staticPresentation: Bool

    var body: some View {
        if staticPresentation {
            Color.dsStaticDesktopScrim
        } else {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    LinearGradient(
                        colors: [
                            .dsMovementSkyTop,
                            .dsMovementSkyMiddle,
                            .dsMovementSkyHorizon,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )
                    RadialGradient(
                        colors: [.dsMovementGlow.opacity(0.52), .clear],
                        center: .bottom,
                        startRadius: 0,
                        endRadius: proxy.size.width * 0.34,
                    )
                    .frame(height: proxy.size.height * 0.72)
                    LinearGradient(
                        colors: [.dsMovementGroundTop, .dsMovementGroundBottom],
                        startPoint: .top,
                        endPoint: .bottom,
                    )
                    .frame(height: proxy.size.height * 0.289)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

#Preview("Break flow fields") {
    HStack(spacing: 0) {
        BreakFlowField(staticPresentation: false)
        BreakFlowField(staticPresentation: true)
    }
    .frame(width: 960, height: 600)
}
