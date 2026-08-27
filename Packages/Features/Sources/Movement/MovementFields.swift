import DesignSystem
import SwiftUI

struct MovementWorkingField: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [.dsMovementSkyTop, .dsMovementSkyMiddle, .dsMovementSkyHorizon],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                )
                RadialGradient(
                    colors: [.dsMovementGlow.opacity(0.62), .clear],
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
        .accessibilityHidden(true)
    }
}

struct MovementStaticField: View {
    var body: some View {
        Color.dsStaticDesktopScrim.accessibilityHidden(true)
    }
}

#Preview("Movement fields") {
    HStack(spacing: 0) {
        MovementWorkingField()
        MovementStaticField()
    }
    .frame(width: 960, height: 600)
}
