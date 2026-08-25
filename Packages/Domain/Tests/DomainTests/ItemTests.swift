import Foundation
import Testing
@testable import Domain

@Suite("Item display sorting")
struct ItemSortingTests {
    let base = SampleData.referenceDate

    @Test("Open items come before done items")
    func openBeforeDone() {
        let done = Item(title: "done", isDone: true, createdAt: base.addingTimeInterval(100))
        let open = Item(title: "open", isDone: false, createdAt: base)

        let sorted = [done, open].sortedForDisplay()

        #expect(sorted.map(\.title) == ["open", "done"])
    }

    @Test("Newest first within the same done-state", arguments: [true, false])
    func newestFirst(isDone: Bool) {
        let older = Item(title: "older", isDone: isDone, createdAt: base)
        let newer = Item(title: "newer", isDone: isDone, createdAt: base.addingTimeInterval(60))

        let sorted = [older, newer].sortedForDisplay()

        #expect(sorted.map(\.title) == ["newer", "older"])
    }

    @Test("Sample data is deterministic")
    func sampleDataIsDeterministic() {
        let first = SampleData.items(now: base)
        let second = SampleData.items(now: base)

        #expect(first.map(\.title) == second.map(\.title))
        #expect(first.map(\.createdAt) == second.map(\.createdAt))
    }
}
