import CoreGraphics

enum DSCapsuleSkyGeometry {
    static let skySize: CGFloat = 24
    static let sunSize: CGFloat = 11
    static let horizonY: CGFloat = 18
    static let inset: CGFloat = 1
    static let glintTravel: CGFloat = 1.8
    static let sunHorizontalOffset = (skySize - sunSize) / 2

    static func verticalOffset(for progress: CGFloat) -> CGFloat {
        let travel = horizonY - sunSize - inset
        return inset + clamped(progress) * travel
    }

    static func sunBottom(for progress: CGFloat) -> CGFloat {
        verticalOffset(for: progress) + sunSize
    }

    static func clamped(_ value: CGFloat) -> CGFloat {
        min(1, max(0, value))
    }

    static func normalizedGlint(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(1, max(-1, value))
    }

    static func glintOffset(for normalizedGlint: CGFloat) -> CGFloat {
        Self.normalizedGlint(normalizedGlint) * glintTravel
    }
}
