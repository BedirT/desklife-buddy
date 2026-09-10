import DesignSystem
import SwiftUI

extension SettingsSection {
    var systemImage: String {
        switch self {
        case .schedule: "clock"
        case .breakContent: "figure.walk"
        case .contextAndExclusions: "moon"
        case .accessibility: "accessibility"
        case .privacyAndData: "hand.raised"
        case .integrations: "puzzlepiece.extension"
        case .whyTheseDefaults: "info.circle"
        case .safetyAndSupport: "cross.case"
        }
    }

    var tileGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .schedule: [.dsMovementSeatedTileTop, .dsMovementSeatedTileBottom]
        case .breakContent: [.dsMovementWalkTileTop, .dsMovementWalkTileBottom]
        case .contextAndExclusions: [.dsMovementSmallSpaceTileTop, .dsMovementSmallSpaceTileBottom]
        case .accessibility: [.dsMovementSeatedTileTop, .dsMovementSmallSpaceTileBottom]
        case .privacyAndData: [.dsPositive, .dsAccent]
        case .integrations: [.dsMovementWalkTileTop, .dsMovementSmallSpaceTileBottom]
        case .whyTheseDefaults: [.dsWarning, .dsMovementWalkTileBottom]
        case .safetyAndSupport: [.dsDanger, .dsMovementSmallSpaceTileBottom]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
