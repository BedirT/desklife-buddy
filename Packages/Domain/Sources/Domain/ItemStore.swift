import Foundation

/// Persistence seam. Features depend on this protocol, never on a concrete store,
/// so previews/tests inject deterministic data and the real store can change freely.
public protocol ItemStore {
    func loadItems() async throws -> [Item]
    func save(_ items: [Item]) async throws
}

/// In-memory store for previews, tests, and the template app itself.
public final class InMemoryItemStore: ItemStore {
    private var items: [Item]

    public init(items: [Item] = []) {
        self.items = items
    }

    public func loadItems() async throws -> [Item] {
        items
    }

    public func save(_ items: [Item]) async throws {
        self.items = items
    }
}

public enum SampleData {
    /// Deterministic sample content. `now` is injected so previews and snapshot
    /// baselines never depend on the wall clock.
    public static func items(now: Date) -> [Item] {
        [
            Item(title: "Wire up the design system", isDone: true, createdAt: now.addingTimeInterval(-7200)),
            Item(title: "Write snapshot tests", isDone: false, createdAt: now.addingTimeInterval(-3600)),
            Item(title: "Ship the evidence pack", isDone: false, createdAt: now.addingTimeInterval(-60)),
        ]
    }

    /// Fixed reference instant for previews and tests (2026-01-01 00:00:00 UTC).
    public static let referenceDate = Date(timeIntervalSince1970: 1_767_225_600)
}
