import AppKit
import SwiftUI

// The only file in the repo where raw color values are legal.
// Feature code composes from the semantic tokens below; SwiftLint enforces this.

public extension Color {
    // MARK: - Surfaces

    /// Screen background.
    static let dsBackground = Color(light: Color(hex: 0xF6F6F8), dark: Color(hex: 0x0E0E11))
    /// Cards, sheets, grouped content.
    static let dsSurface = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1B1B20))
    /// Secondary fills: inputs, secondary buttons, tag backgrounds.
    static let dsSurfaceSecondary = Color(light: Color(hex: 0xECECF1), dark: Color(hex: 0x26262C))

    // MARK: - Content

    static let dsTextPrimary = Color(light: Color(hex: 0x1A1A1E), dark: Color(hex: 0xF2F2F5))
    static let dsTextSecondary = Color(light: Color(hex: 0x63636B), dark: Color(hex: 0x9C9CA6))
    static let dsSeparator = Color(
        light: Color(hex: 0x000000).opacity(0.10),
        dark: Color(hex: 0xFFFFFF).opacity(0.12),
    )

    /// Platform-owned ink for custom content embedded inside a native menu.
    static let dsMenuTextPrimary = Color(nsColor: .labelColor)
    static let dsMenuTextSecondary = Color(nsColor: .secondaryLabelColor)
    static let dsMenuTrack = Color(nsColor: .separatorColor)

    /// The dark working direction's clock accents; light remains neutral until DQ-18 closes.
    static let dsVisualBar = Color(light: Color(hex: 0x1A1A1E), dark: Color(hex: 0xFFC98F))
    static let dsMovementBar = Color(light: Color(hex: 0x1A1A1E), dark: Color(hex: 0xFF9EC0))

    // MARK: - Break fields

    /// Working-reference break-field ink. Final field colors remain gated by DQ-18.
    static let dsBreakTextPrimary = Color(light: Color(hex: 0x241D2E), dark: Color(hex: 0xFDF6EF))
    static let dsBreakTextSecondary = Color(light: Color(hex: 0x665C70), dark: Color(hex: 0xD5CBD1))
    static let dsBreakEyebrow = Color(light: Color(hex: 0x7A4234), dark: Color(hex: 0xE4BFA8))
    static let dsBreakTextPrimaryIncreased = Color(light: Color(hex: 0x120C18), dark: Color(hex: 0xFFFFFF))
    static let dsBreakTextSecondaryIncreased = Color(light: Color(hex: 0x403648), dark: Color(hex: 0xFFF7FB))
    static let dsBreakEyebrowIncreased = Color(light: Color(hex: 0x5B281E), dark: Color(hex: 0xFFE0CC))
    static let dsBreakControlSolid = Color(light: Color(hex: 0xF7F3F6), dark: Color(hex: 0x20182A))
    static let dsBreakControlBorder = Color(light: Color(hex: 0x604B62), dark: Color(hex: 0xB9A9BA))
    static let dsBreakControlBorderIncreased = Color(light: Color(hex: 0x39283A), dark: Color(hex: 0xF5EAF3))
    static let dsBreakKeycap = Color(light: Color(hex: 0xE4DDE5), dark: Color(hex: 0x493B50))
    static let dsBreakHorizonTrack = Color(light: Color(hex: 0x665266), dark: Color(hex: 0x9D8E9D))
    static let dsBreakHorizonTrackIncreased = Color(light: Color(hex: 0x39283A), dark: Color(hex: 0xF5EAF3))
    static let dsBreakHorizonFill = Color(light: Color(hex: 0xB95B34), dark: Color(hex: 0xFFD0A8))
    static let dsBreakFocusRing = Color(light: Color(hex: 0x3A2438), dark: Color(hex: 0xFFD6B2))
    static let dsBreakSkyTop = Color(light: Color(hex: 0xDBE1F6), dark: Color(hex: 0x08091B))
    static let dsBreakSkyMiddle = Color(light: Color(hex: 0xE7E5F2), dark: Color(hex: 0x14132E))
    static let dsBreakSkyHorizon = Color(light: Color(hex: 0xFDE9D8), dark: Color(hex: 0x55303F))
    static let dsBreakGroundTop = Color(light: Color(hex: 0xF3EBE9), dark: Color(hex: 0x241A30))
    static let dsBreakGroundBottom = Color(light: Color(hex: 0xE2E4EE), dark: Color(hex: 0x0A0A19))
    static let dsBreakGlow = Color(light: Color(hex: 0xFFD6AE), dark: Color(hex: 0xFFDCC2))
    static let dsBreakTextShadow = Color(
        light: .clear,
        dark: Color(hex: 0x000000).opacity(0.72),
    )

    // MARK: - Brand & status

    static let dsAccent = Color(light: Color(hex: 0x4F46E5), dark: Color(hex: 0x8B85F4))
    /// Text/icons placed on top of dsAccent fills.
    static let dsOnAccent = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x101014))
    static let dsPositive = Color(light: Color(hex: 0x1E9E5A), dark: Color(hex: 0x4CC98A))
    static let dsWarning = Color(light: Color(hex: 0xB07A0C), dark: Color(hex: 0xE3A93B))
    static let dsDanger = Color(light: Color(hex: 0xC93A3A), dark: Color(hex: 0xE06C6C))
}

extension Color {
    /// Appearance-dynamic color. DesignSystem-internal.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(dark)
                : NSColor(light)
        })
    }

    /// RGB hex literal. DesignSystem-internal.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
        )
    }
}
