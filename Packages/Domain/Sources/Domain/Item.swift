import Foundation

/// Sample domain entity. Replace alongside ItemStore when starting a real app;
/// it exists so the harness has something end-to-end to verify.
public struct Item: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var isDone: Bool
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, isDone: Bool = false, createdAt: Date) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}

public extension [Item] {
    /// Display order: open items first, newest first within each group.
    func sortedForDisplay() -> [Item] {
        sorted { lhs, rhs in
            if lhs.isDone != rhs.isDone { return !lhs.isDone }
            return lhs.createdAt > rhs.createdAt
        }
    }
}
