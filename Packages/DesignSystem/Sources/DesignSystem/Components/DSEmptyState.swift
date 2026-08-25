import SwiftUI

/// Empty/error state with optional call to action. Use for every list's empty
/// case and every recoverable failure — never leave a blank screen.
public struct DSEmptyState: View {
    private let systemImage: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil,
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: systemImage)
                .font(.system(size: 44))
                .foregroundStyle(Color.dsTextSecondary)
            Text(title)
                .font(DSTypography.headline)
                .foregroundStyle(Color.dsTextPrimary)
            Text(message)
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
                // Wraps correctly even in intrinsic-size (sizeThatFits) layouts.
                .fixedSize(horizontal: false, vertical: true)
            if let actionTitle, let action {
                DSButton(actionTitle, action: action)
                    .frame(maxWidth: 240)
                    .padding(.top, DSSpacing.sm)
            }
        }
        .padding(DSSpacing.xxl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Empty state") {
    DSEmptyState(
        systemImage: "tray",
        title: DesignSystemL10n.EmptyState.previewTitle,
        message: DesignSystemL10n.EmptyState.previewMessage,
        actionTitle: DesignSystemL10n.EmptyState.previewAction,
        action: {},
    )
    .background(Color.dsBackground)
}
