---
read_when: adding or changing app persistence, model containers, @Model types, fetches, or migrations
verified: 2026-06-17, Apple Developer Documentation / Xcode 26.5
---

# SwiftData in this harness

SwiftData is the default persistence layer for macOS apps created from this
template. The framework gives declarative stored models, model containers, model
contexts, and fetch descriptors; the harness keeps those details at the app
edge so Domain and Features stay testable.

## The shape of it

```swift
@Model
final class StoredItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
}

final class SwiftDataItemStore: ItemStore {
    private let container: ModelContainer
    private let context: ModelContext

    init(inMemory: Bool = false) throws {
        let schema = Schema([StoredItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
    }
}
```

## Rules here

- `App/` owns SwiftData: `@Model` classes, `ModelContainer`, `ModelContext`, and
  app-store seeding/fallbacks live there.
- `Packages/Domain` owns value models and protocols only. It never imports
  SwiftData, SwiftUI, or AppKit.
- `Packages/Features` depends on Domain protocols and in-memory preview/test
  stores. Feature code should not know whether persistence is SwiftData.
- Use `ModelConfiguration(isStoredInMemoryOnly:)` for in-memory test/preview
  stores when you need to exercise a real SwiftData stack.
- Persisted schemas, migrations, CloudKit sync, encryption, and destructive data
  resets are ask-first changes.

## Sharp edges

- `@Model` macro expansion can create nonisolated helpers. If Swift 6.2
  isolation complains about touching MainActor-default Domain values from a
  model method, keep conversion in the store layer instead of adding broad
  `@MainActor` annotations.
- Fetch descriptors describe criteria and sort order, but simple stores can
  fetch raw stored models and apply Domain ordering afterward. Keep display
  ordering centralized in Domain when tests assert on it.
- Do not hide SwiftData behind singletons. Build the real store in
  `AppComposition.live()` and inject protocols into feature models.

## Sources

- Apple: [SwiftData](https://developer.apple.com/documentation/swiftdata)
- Apple: [@Model](https://developer.apple.com/documentation/swiftdata/model())
- Apple: [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer)
- Apple: [FetchDescriptor](https://developer.apple.com/documentation/swiftdata/fetchdescriptor)
