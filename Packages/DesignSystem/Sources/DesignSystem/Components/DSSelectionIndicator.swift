import SwiftUI

/// A fixed-footprint selection mark that swaps its visual state without
/// replacing the view node. This keeps native controls from briefly re-laying
/// out when an optimistic setting update arrives.
public struct DSSelectionIndicator: View {
    public let selected: Bool
    public let selectedSystemImage: String
    public let unselectedSystemImage: String
    public let selectedColor: Color
    public let unselectedColor: Color
    public let font: Font

    public init(
        selected: Bool,
        selectedSystemImage: String = "checkmark.circle.fill",
        unselectedSystemImage: String = "circle",
        selectedColor: Color = .dsAccent,
        unselectedColor: Color = .dsTextSecondary,
        font: Font = DSTypography.headline,
    ) {
        self.selected = selected
        self.selectedSystemImage = selectedSystemImage
        self.unselectedSystemImage = unselectedSystemImage
        self.selectedColor = selectedColor
        self.unselectedColor = unselectedColor
        self.font = font
    }

    public var body: some View {
        ZStack {
            Image(systemName: unselectedSystemImage)
                .foregroundStyle(unselectedColor)
                .opacity(selected ? 0 : 1)

            Image(systemName: selectedSystemImage)
                .foregroundStyle(selectedColor)
                .opacity(selected ? 1 : 0)
        }
        .font(font)
        .frame(width: 20, height: 20)
        .contentTransition(.identity)
        .transaction { transaction in
            transaction.animation = nil
        }
        .accessibilityHidden(true)
    }
}

#Preview("Selection indicator") {
    HStack(spacing: DSSpacing.xl) {
        DSSelectionIndicator(selected: false)
        DSSelectionIndicator(selected: true)
        DSSelectionIndicator(
            selected: true,
            selectedSystemImage: "checkmark",
            font: DSTypography.headline,
        )
    }
    .padding(DSSpacing.xl)
    .background(Color.dsBackground)
}
