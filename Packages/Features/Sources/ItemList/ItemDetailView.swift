import DesignSystem
import Domain
import SwiftUI

/// Read-only detail screen. Stateless views that render a value directly
/// take it in the initializer — no model class needed until there's logic.
public struct ItemDetailView: View {
    private let item: Item

    public init(item: Item) {
        self.item = item
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                if item.isDone {
                    DSTag(ItemDetailL10n.doneStatus, style: .positive)
                }
                DSCard {
                    VStack(alignment: .leading, spacing: DSSpacing.md) {
                        labeledRow(ItemDetailL10n.createdLabel) {
                            Text(item.createdAt, format: .dateTime.day().month(.wide).hour().minute())
                        }
                        labeledRow(ItemDetailL10n.statusLabel) {
                            Text(item.isDone ? ItemDetailL10n.doneStatus : ItemDetailL10n.openStatus)
                        }
                    }
                }
            }
            .padding(DSSpacing.lg)
        }
        .navigationTitle(item.title)
        .accessibilityIdentifier("itemDetail.screen")
    }

    private func labeledRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(DSTypography.subtext)
                .foregroundStyle(Color.dsTextSecondary)
            Spacer(minLength: DSSpacing.md)
            value()
                .font(DSTypography.body)
                .foregroundStyle(Color.dsTextPrimary)
        }
    }
}

public struct ItemDetailPlaceholder: View {
    public init() {}

    public var body: some View {
        DSEmptyState(
            systemImage: "sidebar.left",
            title: ItemDetailL10n.placeholderTitle,
            message: ItemDetailL10n.placeholderMessage,
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("itemDetail.placeholder")
    }
}

#Preview("Open item") {
    NavigationSplitView {
        ItemListView(
            model: .preview(.loaded),
            selection: .constant(SampleData.items(now: SampleData.referenceDate)[1].id),
        )
    } detail: {
        ItemDetailView(item: SampleData.items(now: SampleData.referenceDate)[1])
    }
    .tint(.dsAccent)
}

#Preview("Done item") {
    NavigationSplitView {
        ItemListView(
            model: .preview(.loaded),
            selection: .constant(SampleData.items(now: SampleData.referenceDate)[0].id),
        )
    } detail: {
        ItemDetailView(item: SampleData.items(now: SampleData.referenceDate)[0])
    }
    .tint(.dsAccent)
}
