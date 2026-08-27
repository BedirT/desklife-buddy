import CoreGraphics

enum DSCapsuleSkyGeometry {
    static let sunSize: CGFloat = 11
    static let horizonY: CGFloat = 18
    static let inset: CGFloat = 1

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
}
