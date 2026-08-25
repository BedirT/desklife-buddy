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
}
