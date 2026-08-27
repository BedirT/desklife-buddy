import SwiftUI

/// App-owned text scaling for macOS, where `dynamicTypeSize` doesn't resize text.
public enum DSTextScale: CGFloat, Sendable {
    case standard = 1
    case plusThirtyFivePercent = 1.35
    case largest = 1.7

    public func apply(to pointSize: CGFloat) -> CGFloat {
        pointSize * rawValue
    }
}

private struct DSTextScaleEnvironmentKey: EnvironmentKey {
    static let defaultValue = DSTextScale.standard
}

public extension EnvironmentValues {
    var dsTextScale: DSTextScale {
        get { self[DSTextScaleEnvironmentKey.self] }
        set { self[DSTextScaleEnvironmentKey.self] = newValue }
    }
}
