import Domain
import Foundation
import Observation

/// Screen state for the item list. All logic lives here (testable on the host
/// in seconds); the view is a pure function of this model.
@Observable
public final class ItemListModel {
    public enum Phase: Equatable {
        case loading
        case ready
        case failed(message: String)
    }

    public private(set) var phase: Phase = .loading
    public private(set) var items: [Item] = []
    public private(set) var persistenceErrorMessage: String?

    private let store: any ItemStore
    private let now: () -> Date
    private var pendingSave: Task<Void, Never>?

    /// `now` is injected so tests and previews control time; the composition
    /// root (App/RootView) is the only place the real clock is used.
    public init(store: any ItemStore, now: @escaping () -> Date = { Date() }) {
        self.store = store
        self.now = now
    }

    public var showsEmptyState: Bool {
        phase == .ready && items.isEmpty
    }

    public var canMutateItems: Bool {
        phase == .ready
    }

    public func item(id: Item.ID?) -> Item? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    public func load() async {
        phase = .loading
        do {
            items = try await store.loadItems().sortedForDisplay()
            phase = .ready
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
    }

    @discardableResult
    public func addItem(titled title: String) -> Item? {
        guard canMutateItems else { return nil }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let item = Item(title: trimmed, createdAt: now())
        items.insert(item, at: 0)
        persist()
        return item
    }

    public func toggleDone(_ item: Item) {
        guard canMutateItems else { return }
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        items = items.sortedForDisplay()
        persist()
    }

    public func delete(_ item: Item) {
        guard canMutateItems else { return }
        items.removeAll { $0.id == item.id }
        persist()
    }

    private func persist() {
        let snapshot = items
        pendingSave?.cancel()
        pendingSave = Task {
            do {
                try await store.save(snapshot)
                persistenceErrorMessage = nil
            } catch {
                persistenceErrorMessage = error.localizedDescription
            }
        }
    }

    public func waitForPendingSave() async {
        await pendingSave?.value
    }
}

// MARK: - Preview & snapshot factories

// Same file on purpose: they assign private(set) state to freeze the model in a
// known phase, so previews and snapshots never depend on async loading.

public extension ItemListModel {
    enum PreviewState {
        case loaded
        case loading
        case empty
        case failed
    }

    static func preview(_ state: PreviewState) -> ItemListModel {
        let model = ItemListModel(
            store: InMemoryItemStore(),
            now: { SampleData.referenceDate },
        )
        switch state {
        case .loaded:
            model.items = SampleData.items(now: SampleData.referenceDate).sortedForDisplay()
            model.phase = .ready
        case .loading:
            model.phase = .loading
        case .empty:
            model.phase = .ready
        case .failed:
            model.phase = .failed(message: ItemListL10n.previewError)
        }
        return model
    }
}
