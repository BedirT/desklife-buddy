import Domain
import Foundation
import Testing
@testable import App

@Suite("SwiftDataItemStore")
struct SwiftDataItemStoreTests {
    @Test("Seed writes only when the store is empty")
    func seedIfNeeded() async throws {
        let store = try SwiftDataItemStore(inMemory: true)
        let first = Item(title: "First", createdAt: Date(timeIntervalSince1970: 1))
        let second = Item(title: "Second", createdAt: Date(timeIntervalSince1970: 2))

        try store.seedIfNeeded([first])
        try store.seedIfNeeded([second])

        let loaded = try await store.loadItems()
        #expect(loaded == [first])
    }

    @Test("Save round-trips add, update, and delete")
    func saveRoundTrip() async throws {
        let store = try SwiftDataItemStore(inMemory: true)
        let createdAt = Date(timeIntervalSince1970: 10)
        let kept = Item(id: UUID(), title: "Kept", isDone: false, createdAt: createdAt)
        let removed = Item(id: UUID(), title: "Removed", isDone: false, createdAt: createdAt)

        try await store.save([kept, removed])

        var updated = kept
        updated.title = "Updated"
        updated.isDone = true
        try await store.save([updated])

        let loaded = try await store.loadItems()
        #expect(loaded == [updated])
    }
}
