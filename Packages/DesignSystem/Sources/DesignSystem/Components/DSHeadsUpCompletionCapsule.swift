import SwiftUI

/// Passive, wordless completion beat for a finished break.
public struct DSHeadsUpCompletionCapsule: View {
    private let shape = Capsule(style: .continuous)
    private let crinkleProgress: CGFloat
    private let reduceTransparency: Bool
    private let increaseContrast: Bool

    public init(
        crinkleProgress: CGFloat,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
    ) {
        self.crinkleProgress = crinkleProgress
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
    }

    public var body: some View {
        completionSky
            .frame(width: DSCapsuleSkyGeometry.skySize, height: DSCapsuleSkyGeometry.skySize)
            .frame(width: 44, height: 34)
            .background { capsuleBackground }
            .overlay {
                shape.strokeBorder(
                    increaseContrast ? Color.dsCapsuleBorderIncreased : Color.dsCapsuleBorder,
                    lineWidth: increaseContrast ? 2 : 1,
                )
            }
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.44), radius: 14, y: 8)
            .accessibilityHidden(true)
    }

    private var completionSky: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [.dsCapsuleSkyTop, .dsCapsuleSkyMiddle, .dsCapsuleSkyHorizon],
                startPoint: .top,
                endPoint: .bottom,
            )
            Rectangle()
                .fill(Color.dsCapsuleHoldRing.opacity(0.72))
                .frame(height: 1)
                .offset(y: DSCapsuleSkyGeometry.horizonY)
            completionSun
                .frame(
                    width: DSCapsuleSkyGeometry.sunSize,
                    height: DSCapsuleSkyGeometry.sunSize,
                )
                .offset(
                    x: DSCapsuleSkyGeometry.sunHorizontalOffset,
                    y: DSCapsuleSkyGeometry.verticalOffset(for: 1),
                )
        }
        .clipShape(Circle())
    }

    private var completionSun: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.dsSunCore, .dsSunMiddle, .dsSunEdge],
                    center: UnitPoint(x: 0.38, y: 0.34),
                    startRadius: 0,
                    endRadius: 6,
                ),
            )
            .shadow(color: Color.dsSunGlow, radius: 4)
            .overlay {
                DSCompletionEyes(progress: crinkleProgress)
                    .stroke(
                        Color.dsCapsuleSkyMiddle,
                        style: StrokeStyle(lineWidth: 0.8, lineCap: .round),
                    )
            }
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        if reduceTransparency || increaseContrast {
            shape.fill(Color.dsCapsuleSurfaceOpaque)
        } else {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.dsCapsuleSurface)
        }
    }
}

private struct DSCompletionEyes: Shape {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let canonicalProgress = min(1, max(0, progress))
        let baseline = rect.midY + 1
        let rise = 0.7 * canonicalProgress
        let eyeWidth: CGFloat = 2.1
        let centerGap: CGFloat = 1.3
        let firstStart = rect.midX - centerGap / 2 - eyeWidth
        let secondStart = rect.midX + centerGap / 2
        var path = Path()
        addEye(to: &path, startX: firstStart, baseline: baseline, width: eyeWidth, rise: rise)
        addEye(to: &path, startX: secondStart, baseline: baseline, width: eyeWidth, rise: rise)
        return path
    }

    private func addEye(
        to path: inout Path,
        startX: CGFloat,
        baseline: CGFloat,
        width: CGFloat,
        rise: CGFloat,
    ) {
        path.move(to: CGPoint(x: startX, y: baseline))
        path.addQuadCurve(
            to: CGPoint(x: startX + width, y: baseline),
            control: CGPoint(x: startX + width / 2, y: baseline - rise),
        )
    }
}

#Preview("Completion capsule endpoints") {
    HStack(spacing: DSSpacing.xl) {
        DSHeadsUpCompletionCapsule(crinkleProgress: 0)
        DSHeadsUpCompletionCapsule(crinkleProgress: 1)
    }
    .padding(DSSpacing.xxl)
    .background(Color.dsBackground)
}
