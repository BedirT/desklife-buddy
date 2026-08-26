import SwiftUI

/// Semantic type ramp. Every style maps to a system text style, so Dynamic Type
/// works everywhere by construction. A future brand font is swapped here only.
public enum DSTypography {
    /// Large screen titles (use sparingly; navigation titles handle most cases).
    public static let largeTitle = Font.largeTitle.weight(.bold)
    /// Screen and modal titles.
    public static let title = Font.title2.weight(.semibold)
    /// Section headers, emphasized row text, button labels.
    public static let headline = Font.headline
    /// Default reading text.
    public static let body = Font.body
    /// Supporting/secondary text.
    public static let subtext = Font.subheadline
    /// Timestamps, tags, fine print.
    public static let caption = Font.caption

    // MARK: - Break fields

    public static let breakEyebrowSize: CGFloat = 13
    public static let breakInstructionSize: CGFloat = 62
    public static let breakLongInstructionSize: CGFloat = 58
    public static let breakSupportingSize: CGFloat = 19
    public static let breakCountdownSize: CGFloat = 27
    public static let breakMetaSize: CGFloat = 13
    public static let breakActionSize: CGFloat = 15
    public static let breakChoiceSize: CGFloat = 18
    public static let breakSafetySize: CGFloat = 12.5
    public static let headsUpTextSize: CGFloat = 12.5
    public static let headsUpActionSize: CGFloat = 11.5

    public static func breakEyebrow(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .semibold)
    }

    public static func breakInstruction(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .semibold)
    }

    public static func breakInstructionEmphasis(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .medium, design: .serif).italic()
    }

    public static func breakSupporting(pointSize: CGFloat) -> Font {
        .system(size: pointSize)
    }

    public static func breakSupportingEmphasis(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .semibold)
    }

    public static func breakCountdown(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .medium, design: .monospaced)
    }

    public static func breakMeta(pointSize: CGFloat) -> Font {
        .system(size: pointSize)
    }

    public static func breakAction(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .medium)
    }

    public static func breakChoice(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .semibold)
    }

    public static func breakSafety(pointSize: CGFloat) -> Font {
        .system(size: pointSize)
    }

    public static func headsUpText(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .medium)
    }

    public static func headsUpAction(pointSize: CGFloat) -> Font {
        .system(size: pointSize, weight: .medium)
    }

    /// Custom content embedded in a native menu follows the menu's current point size.
    public static func menuLabel(pointSize: CGFloat) -> Font {
        .system(size: pointSize)
    }

    /// Supporting native-menu copy stays one step below the current menu font.
    public static func menuSupporting(pointSize: CGFloat) -> Font {
        .system(size: max(9, pointSize - 2))
    }
}
