import DesignSystem
import Domain
import SwiftUI

public struct ItemListView: View {
    @AppStorage("showCompletedInSidebar") private var showCompletedInSidebar = true
    @State private var model: ItemListModel
    @Binding private var selection: Item.ID?
    private let loadsAutomatically: Bool

    public init(model: ItemListModel, selection: Binding<Item.ID?>, loadsAutomatically: Bool = true) {
        _model = State(initialValue: model)
        _selection = selection
        self.loadsAutomatically = loadsAutomatically
    }

    public var body: some View {
        content
            .navigationTitle(ItemListL10n.navigationTitle)
            .navigationSplitViewColumnWidth(min: 220, ideal: 280, max: 360)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(DSMotion.reveal) {
                            selection = model.addItem(titled: ItemListL10n.addDefaultTitle)?.id
                        }
                    } label: {
                        Label(ItemListL10n.addAction, systemImage: "plus")
                    }
                    .accessibilityIdentifier("itemList.add")
                    .disabled(!model.canMutateItems)
                }
            }
            // Preview/snapshot models arrive frozen in a non-loading phase;
            // only a fresh model actually loads.
            .task {
                if loadsAutomatically, model.phase == .loading {
                    await model.load()
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .failed(message):
            DSEmptyState(
                systemImage: "exclamationmark.triangle",
                title: ItemListL10n.errorTitle,
                message: message,
                actionTitle: ItemListL10n.errorRetry,
                action: { Task { await model.load() } },
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("itemList.error")
        case .ready where model.showsEmptyState:
            DSEmptyState(
                systemImage: "tray",
                title: ItemListL10n.emptyTitle,
                message: ItemListL10n.emptyMessage,
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("itemList.empty")
        case .ready:
            list
        }
    }

    private var list: some View {
        List(selection: $selection) {
            ForEach(visibleItems) { item in
                ItemRow(item: item)
                    .tag(item.id)
                    .contextMenu {
                        Button(item.isDone ? ItemListL10n.markNotDone : ItemListL10n.markDone) {
                            withAnimation(DSMotion.tap) {
                                model.toggleDone(item)
                            }
                        }
                        .accessibilityIdentifier("itemList.context.toggleDone")

                        Button(ItemListL10n.deleteAction, role: .destructive) {
                            if selection == item.id {
                                selection = nil
                            }
                            withAnimation(DSMotion.dismiss) {
                                model.delete(item)
                            }
                        }
                        .accessibilityIdentifier("itemList.context.delete")
                    }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: DSSpacing.xxl)
        }
        .accessibilityIdentifier("itemList.list")
    }

    private var visibleItems: [Item] {
        showCompletedInSidebar ? model.items : model.items.filter { !$0.isDone }
    }
}

private struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isDone ? Color.dsPositive : Color.dsTextSecondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                Text(item.title)
                    .font(DSTypography.body)
                    .foregroundStyle(item.isDone ? Color.dsTextSecondary : Color.dsTextPrimary)
                    .strikethrough(item.isDone, color: .dsTextSecondary)
                Text(item.createdAt, format: .dateTime.hour().minute())
                    .font(DSTypography.caption)
                    .foregroundStyle(Color.dsTextSecondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, DSSpacing.xs)
        .accessibilityIdentifier("itemList.row")
    }
}

// Previews cover every reachable screen state. The .tint matches RootView's
// composition so live previews and baselines see real app chrome.

#Preview("Loaded") {
    @Previewable @State var selection: Item.ID?
    NavigationSplitView {
        ItemListView(model: .preview(.loaded), selection: $selection)
    } detail: {
        ItemDetailPlaceholder()
    }
    .tint(.dsAccent)
}

#Preview("Loading") {
    @Previewable @State var selection: Item.ID?
    NavigationSplitView {
        ItemListView(model: .preview(.loading), selection: $selection, loadsAutomatically: false)
    } detail: {
        ItemDetailPlaceholder()
    }
    .tint(.dsAccent)
}

#Preview("Empty") {
    @Previewable @State var selection: Item.ID?
    NavigationSplitView {
        ItemListView(model: .preview(.empty), selection: $selection)
    } detail: {
        ItemDetailPlaceholder()
    }
    .tint(.dsAccent)
}

#Preview("Failed") {
    @Previewable @State var selection: Item.ID?
    NavigationSplitView {
        ItemListView(model: .preview(.failed), selection: $selection)
    } detail: {
        ItemDetailPlaceholder()
    }
    .tint(.dsAccent)
}
