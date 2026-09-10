import DesignSystem
import SwiftUI

enum SettingsPageLayout {
    static func contentInset(for textScale: DSTextScale) -> CGFloat {
        textScale == .largest ? DSSpacing.xl : DSSpacing.lg
    }

    static func sectionGap(for textScale: DSTextScale) -> CGFloat {
        textScale == .largest ? DSSpacing.xxl : DSSpacing.xl
    }

    static let rowIconWidth = DSSpacing.xl
    static let rowGap = DSSpacing.md
    static let trailingControlWidth = DSSpacing.xxl * 4
}
