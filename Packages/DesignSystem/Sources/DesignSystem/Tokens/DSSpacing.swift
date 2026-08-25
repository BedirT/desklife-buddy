import Foundation

/// 4pt-grid spacing scale. If a layout needs a value that isn't here,
/// the layout is probably wrong — adjust composition before adding a token.
public enum DSSpacing {
    /// Hairline gaps inside compact controls.
    public static let xs: CGFloat = 4
    /// Icon-to-label, intra-row gaps.
    public static let sm: CGFloat = 8
    /// Default stack spacing.
    public static let md: CGFloat = 12
    /// Content insets, card padding.
    public static let lg: CGFloat = 16
    /// Section separation.
    public static let xl: CGFloat = 24
    /// Screen-level breathing room, hero spacing.
    public static let xxl: CGFloat = 32
}

/// Corner radii. Continuous curves are applied by components, not callers.
public enum DSRadius {
    /// Tags, small inline controls.
    public static let sm: CGFloat = 6
    /// Buttons, inputs.
    public static let md: CGFloat = 12
    /// Cards, sheets, prominent containers.
    public static let lg: CGFloat = 16
}
