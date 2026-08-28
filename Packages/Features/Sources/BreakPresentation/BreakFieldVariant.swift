import Foundation

public enum BreakFieldVariant: String, CaseIterable, Equatable, Identifiable, Sendable {
    case visualReset
    case movementWalkOrWheel
    case movementSmallSpace
    case movementSeated

    public var id: Self { self }

    var resourceName: String {
        switch self {
        case .visualReset: "b2-visual-reset"
        case .movementWalkOrWheel: "b2-movement-walk-or-wheel"
        case .movementSmallSpace: "b2-movement-small-space"
        case .movementSeated: "b2-movement-seated"
        }
    }
}

public enum BreakFieldColorScheme: Equatable, Sendable {
    case light
    case dark
}

public struct BreakFieldAppearance: Equatable, Sendable {
    public let colorScheme: BreakFieldColorScheme
    public let increaseContrast: Bool
    public let reduceTransparency: Bool

    public init(
        colorScheme: BreakFieldColorScheme,
        increaseContrast: Bool = false,
        reduceTransparency: Bool = false,
    ) {
        self.colorScheme = colorScheme
        self.increaseContrast = increaseContrast
        self.reduceTransparency = reduceTransparency
    }

    var scrimLayerCount: Int {
        increaseContrast || reduceTransparency ? 1 : 0
    }

    var imageBrightness: Double {
        0
    }

    var imageSaturation: Double {
        if reduceTransparency { return 0.9 }
        return 1
    }

    var imageContrast: Double {
        if increaseContrast { return 1.12 }
        return 1
    }
}
