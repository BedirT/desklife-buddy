import Domain
import Foundation
import Testing
@testable import ItemList

@Suite("ItemListModel")
struct ItemListModelTests {
    let fixedNow = SampleData.referenceDate

    private func makeModel(items: [Item] = []) -> ItemListModel {
        ItemListModel(store: InMemoryItemStore(items: items), now: { fixedNow })
    }

    @Test("Load sorts open items first")
    func loadSuccess() async {
        let model = makeModel(items: SampleData.items(now: fixedNow))

        await model.load()

        #expect(model.phase == .ready)
        #expect(model.items.count == 3)
        #expect(model.items.allSatisfy { !$0.isDone } == false)
        #expect(model.items.first?.isDone == false)
        #expect(model.items.last?.isDone == true)
    }

    @Test("Load failure surfaces a message")
    func loadFailure() async {
        struct FailingStore: ItemStore {
            struct Failure: Error {}
            func loadItems() async throws -> [Item] { throw Failure() }
            func save(_ items: [Item]) async throws {}
        }
        let model = ItemListModel(store: FailingStore(), now: { fixedNow })

        await model.load()

        guard case .failed = model.phase else {
            Issue.record("Expected .failed, got \(model.phase)")
            return
        }
        #expect(model.items.isEmpty)
    }

    @Test("Add inserts at the top and uses the injected clock")
    func addItem() async {
        let model = makeModel()
        await model.load()

        let item = model.addItem(titled: "  Buy milk  ")

        #expect(item?.title == "Buy milk")
        #expect(model.items.first?.title == "Buy milk")
        #expect(model.items.first?.createdAt == fixedNow)
    }

    @Test("Mutations are disabled until the initial load completes")
    func mutationsWaitForReady() async {
        let model = makeModel(items: SampleData.items(now: fixedNow))

        let item = model.addItem(titled: "Too early")

        #expect(item == nil)
        #expect(model.items.isEmpty)
    }

    @Test("Save failures are observable")
    func saveFailureIsObservable() async {
        struct FailingSaveStore: ItemStore {
            struct Failure: LocalizedError {
                var errorDescription: String? { "Could not save items." }
            }

            func loadItems() async throws -> [Item] { [] }
            func save(_ items: [Item]) async throws { throw Failure() }
        }

        let model = ItemListModel(store: FailingSaveStore(), now: { fixedNow })
        await model.load()

        _ = model.addItem(titled: "Cannot persist")
        await model.waitForPendingSave()

        #expect(model.persistenceErrorMessage == "Could not save items.")
    }

    @Test("Blank titles are ignored", arguments: ["", "   ", "\n"])
    func blankTitlesIgnored(title: String) async {
        let model = makeModel()
        await model.load()

        let item = model.addItem(titled: title)

        #expect(item == nil)
        #expect(model.items.isEmpty)
    }

    @Test("Lookup returns the selected item")
    func lookupSelectedItem() async throws {
        let model = makeModel(items: SampleData.items(now: fixedNow))
        await model.load()
        let first = try #require(model.items.first)

        #expect(model.item(id: first.id) == first)
        #expect(model.item(id: nil) == nil)
    }

    @Test("Toggling done moves the item into the done group")
    func toggleResorts() async throws {
        let model = makeModel(items: SampleData.items(now: fixedNow))
        await model.load()
        let first = try #require(model.items.first)
        #expect(first.isDone == false)

        model.toggleDone(first)

        let toggled = try #require(model.items.first { $0.id == first.id })
        #expect(toggled.isDone)
        // Display invariant: open items always precede done items.
        let firstDoneIndex = model.items.firstIndex { $0.isDone } ?? model.items.count
        let doneTail = model.items[firstDoneIndex...].allSatisfy(\.isDone)
        #expect(doneTail)
    }

    @Test("Delete removes the item")
    func delete() async throws {
        let model = makeModel(items: SampleData.items(now: fixedNow))
        await model.load()
        let first = try #require(model.items.first)

        model.delete(first)

        #expect(model.items.count == 2)
        #expect(!model.items.contains { $0.id == first.id })
    }
}
