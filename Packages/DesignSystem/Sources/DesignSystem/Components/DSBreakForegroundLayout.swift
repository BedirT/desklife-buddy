import Foundation

public enum DSBreakForegroundLayout {
    public static let systemChromeBottomExclusion: CGFloat = 96

    public static func usableHeight(in height: CGFloat) -> CGFloat {
        max(0, height - systemChromeBottomExclusion)
    }

    public static func y(_ fraction: CGFloat, in height: CGFloat) -> CGFloat {
        usableHeight(in: height) * fraction
    }
}
