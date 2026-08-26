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
