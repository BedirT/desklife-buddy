import Domain
import Foundation
import Testing
@testable import App

@Suite("SwiftData opportunity event history")
struct SwiftDataOpportunityEventStoreTests {
    @Test("Every canonical event kind retains its exact raw value", arguments: OpportunityEventKind.allCases)
    func canonicalKindRoundTrip(_ kind: OpportunityEventKind) async throws {
        let event = OpportunityEvent(
            id: UUID(),
            kind: kind,
            recordedAt: Date(timeIntervalSince1970: 50),
            source: .localTimer,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { event.recordedAt })

        try await store.append(event)

        #expect(try await store.loadEvents() == [event])
    }

    @Test("Events round-trip every privacy-minimized field in append order")
    func appendAndLoad() async throws {
        let recordedAt = Date(timeIntervalSince1970: 100)
        let first = OpportunityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            kind: .breakStarted,
            recordedAt: recordedAt,
            source: .user,
            opportunity: .movement,
            selectedDurationSeconds: 300,
        )
        let second = OpportunityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            kind: .likelyNaturalInterruption,
            recordedAt: recordedAt,
            source: .systemContext,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { recordedAt })

        try await store.append(first)
        try await store.append(second)

        #expect(try await store.loadEvents() == [first, second])
    }

    @Test("Retrying an identical event is idempotent")
    func idempotentRetry() async throws {
        let event = OpportunityEvent(
            id: UUID(),
            kind: .positionChanged,
            recordedAt: Date(timeIntervalSince1970: 150),
            source: .user,
            opportunity: .positionChange,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { event.recordedAt })

        try await store.append(event)
        try await store.append(event)

        #expect(try await store.loadEvents() == [event])
    }

    @Test("A reused identifier with different facts is rejected")
    func conflictingID() async throws {
        let id = UUID()
        let first = OpportunityEvent(
            id: id,
            kind: .snoozed,
            recordedAt: Date(timeIntervalSince1970: 175),
            source: .user,
            opportunity: .visual,
            selectedDurationSeconds: 300,
        )
        let conflicting = OpportunityEvent(
            id: id,
            kind: .skipped,
            recordedAt: first.recordedAt,
            source: .user,
            opportunity: .visual,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { first.recordedAt })
        try await store.append(first)

        do {
            try await store.append(conflicting)
            Issue.record("Expected a conflicting identifier error")
        } catch let error as ProtocolPersistenceError {
            #expect(error == .conflictingEventID(id))
        }
    }

    @Test("Invalid selected durations never reach persistent history")
    func invalidDuration() async throws {
        let event = OpportunityEvent(
            id: UUID(),
            kind: .breakStarted,
            recordedAt: Date(timeIntervalSince1970: 180),
            source: .user,
            opportunity: .movement,
            selectedDurationSeconds: -.infinity,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { event.recordedAt })

        do {
            try await store.append(event)
            Issue.record("Expected invalid duration to be rejected")
        } catch let error as ProtocolPersistenceError {
            guard case .invalidSelectedDuration = error else {
                Issue.record("Unexpected error: \(error)")
                return
            }
        }
        #expect(try await store.loadEvents().isEmpty)
    }

    @Test("A file-backed container preserves history across reconstruction")
    func fileBackedReconstruction() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "protocol-store-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appending(path: "protocol.store")
        let event = OpportunityEvent(
            id: UUID(),
            kind: .userDeclaredAlreadyMoved,
            recordedAt: Date(timeIntervalSince1970: 190),
            source: .user,
            opportunity: .movement,
        )

        do {
            let container = try AppModelContainer.make(url: storeURL)
            let store = try SwiftDataProtocolStore(container: container, now: { event.recordedAt })
            try await store.append(event)
        }

        let reopenedContainer = try AppModelContainer.make(url: storeURL)
        let reopenedStore = try SwiftDataProtocolStore(
            container: reopenedContainer,
            now: { event.recordedAt },
        )
        #expect(try await reopenedStore.loadEvents() == [event])
    }

    @Test("Deleting history removes every retained event")
    func deleteAll() async throws {
        let event = OpportunityEvent(
            id: UUID(),
            kind: .skipped,
            recordedAt: Date(timeIntervalSince1970: 200),
            source: .user,
            opportunity: .visual,
        )
        let store = try SwiftDataOpportunityEventStore(inMemory: true, now: { event.recordedAt })

        try await store.append(event)
        try await store.deleteAllEvents()

        #expect(try await store.loadEvents().isEmpty)
    }
}
