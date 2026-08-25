import Foundation
import SwiftData

@Model
final class StoredItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date

    init(id: UUID, title: String, isDone: Bool, createdAt: Date) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }

    func update(title: String, isDone: Bool, createdAt: Date) {
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
    }
}
