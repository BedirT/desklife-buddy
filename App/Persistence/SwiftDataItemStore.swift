import Domain
import Foundation
import SwiftData

final class SwiftDataItemStore: ItemStore {
    private let container: ModelContainer
    private let context: ModelContext

    convenience init(inMemory: Bool = false) throws {
        try self.init(container: AppModelContainer.make(inMemory: inMemory))
    }

    init(container: ModelContainer) throws {
        self.container = container
        context = ModelContext(container)
    }

    func loadItems() async throws -> [Item] {
        try fetchStoredItems().map(item(from:)).sortedForDisplay()
    }

    func save(_ items: [Item]) async throws {
        let storedItems = try fetchStoredItems()
        var storedByID = Dictionary(uniqueKeysWithValues: storedItems.map { ($0.id, $0) })
        let incomingIDs = Set(items.map(\.id))

        for item in items {
            if let stored = storedByID[item.id] {
                stored.update(title: item.title, isDone: item.isDone, createdAt: item.createdAt)
            } else {
                context.insert(storedItem(from: item))
            }
            storedByID[item.id] = nil
        }

        for stale in storedItems where !incomingIDs.contains(stale.id) {
            context.delete(stale)
        }

        try context.save()
    }

    func seedIfNeeded(_ items: [Item]) throws {
        guard try fetchStoredItems().isEmpty else { return }
        for item in items {
            context.insert(storedItem(from: item))
        }
        try context.save()
    }

    private func item(from stored: StoredItem) -> Item {
        Item(id: stored.id, title: stored.title, isDone: stored.isDone, createdAt: stored.createdAt)
    }

    private func storedItem(from item: Item) -> StoredItem {
        StoredItem(id: item.id, title: item.title, isDone: item.isDone, createdAt: item.createdAt)
    }

    private func fetchStoredItems() throws -> [StoredItem] {
        let descriptor = FetchDescriptor<StoredItem>()
        return try context.fetch(descriptor)
    }
}
