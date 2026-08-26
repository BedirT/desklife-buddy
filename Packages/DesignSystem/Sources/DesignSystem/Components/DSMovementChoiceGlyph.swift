import SwiftUI

/// The three equal-status movement glyphs specified for break choice chips.
public struct DSMovementChoiceGlyph: View {
    public enum Kind: CaseIterable, Sendable {
        case walkOrWheel
        case smallSpace
        case seated
    }

    private let kind: Kind

    public init(_ kind: Kind) {
        self.kind = kind
    }

    public var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width, proxy.size.height) / 24
            ZStack(alignment: .topLeading) {
                DSMovementGlyphStroke(kind: kind)
                    .stroke(
                        Color.dsMovementGlyphInk.opacity(0.58),
                        style: StrokeStyle(
                            lineWidth: 2 * scale,
                            lineCap: .round,
                            lineJoin: .round,
                        ),
                    )
                Circle()
                    .fill(Color.dsMovementGlyphInk)
                    .frame(width: headRadius * scale * 2, height: headRadius * scale * 2)
                    .position(x: headCenter.x * scale, y: headCenter.y * scale)
            }
        }
        .frame(width: 22, height: 22)
        .frame(width: 38, height: 38)
        .background(tileGradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.26), radius: 7, y: 4)
        .accessibilityHidden(true)
    }

    private var tileGradient: LinearGradient {
        let colors: [Color] = switch kind {
        case .walkOrWheel: [.dsMovementWalkTileTop, .dsMovementWalkTileBottom]
        case .smallSpace: [.dsMovementSmallSpaceTileTop, .dsMovementSmallSpaceTileBottom]
        case .seated: [.dsMovementSeatedTileTop, .dsMovementSeatedTileBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var headCenter: CGPoint {
        switch kind {
        case .walkOrWheel: CGPoint(x: 17.5, y: 10)
        case .smallSpace: CGPoint(x: 12, y: 5.5)
        case .seated: CGPoint(x: 12, y: 7)
        }
    }

    private var headRadius: CGFloat {
        switch kind {
        case .walkOrWheel: 2.4
        case .smallSpace, .seated: 2.2
        }
    }
}

private struct DSMovementGlyphStroke: Shape {
    let kind: DSMovementChoiceGlyph.Kind

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        func point(_ coordinateX: CGFloat, _ coordinateY: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + coordinateX * scale, y: rect.minY + coordinateY * scale)
        }
        var path = Path()

        switch kind {
        case .walkOrWheel:
            path.move(to: point(3, 17))
            path.addCurve(
                to: point(21, 17),
                control1: point(7, 8),
                control2: point(17, 8),
            )
        case .smallSpace:
            let center = point(12, 12)
            let radius = 6.5 * scale
            path.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2,
                ),
            )
        case .seated:
            path.move(to: point(4, 15))
            path.addCurve(
                to: point(20, 15),
                control1: point(6, 5),
                control2: point(18, 5),
            )
            path.move(to: point(3, 19))
            path.addLine(to: point(21, 19))
        }
        return path
    }
}

#Preview("Movement choice glyphs") {
    HStack(spacing: DSSpacing.md) {
        DSMovementChoiceGlyph(.walkOrWheel)
        DSMovementChoiceGlyph(.smallSpace)
        DSMovementChoiceGlyph(.seated)
    }
    .padding(DSSpacing.xl)
    .background(Color.dsMovementGroundTop)
}
