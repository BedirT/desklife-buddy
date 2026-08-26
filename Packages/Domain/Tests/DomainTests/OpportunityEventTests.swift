import Foundation
import Testing
@testable import Domain

@Suite("Exhaustive opportunity events")
struct OpportunityEventTests {
    private let eventID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let recordedAt = Date(timeIntervalSince1970: 1_767_225_600)

    @Test("Vocabulary contains exactly the ten canonical events")
    func exhaustiveVocabulary() {
        #expect(OpportunityEventKind.allCases.map(\.rawValue) == [
            "promptPresented",
            "breakStarted",
            "timerFinished",
            "userDeclaredCompleted",
            "userDeclaredAlreadyMoved",
            "positionChanged",
            "snoozed",
            "skipped",
            "notAppropriate",
            "likelyNaturalInterruption",
        ])
    }

    @Test("Record preserves only injected privacy-minimized context")
    func recordPreservesContext() {
        let record = OpportunityEvent(
            id: eventID,
            kind: .breakStarted,
            recordedAt: recordedAt,
            source: .user,
            opportunity: .movement,
            selectedDurationSeconds: 120,
        )

        #expect(record.id == eventID)
        #expect(record.recordedAt == recordedAt)
        #expect(record.opportunity == .movement)
        #expect(record.selectedDurationSeconds == 120)
    }

    @Test("In-memory store preserves append order and deletes all events")
    func inMemoryStore() async throws {
        let first = OpportunityEvent(
            id: eventID,
            kind: .promptPresented,
            recordedAt: recordedAt,
            source: .localTimer,
            opportunity: .visual,
        )
        let second = OpportunityEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            kind: .skipped,
            recordedAt: recordedAt.addingTimeInterval(1),
            source: .user,
            opportunity: .visual,
        )
        let store = InMemoryOpportunityEventStore()

        try await store.append(first)
        try await store.append(second)
        #expect(try await store.loadEvents() == [first, second])

        try await store.deleteAllEvents()
        #expect(try await store.loadEvents().isEmpty)
    }
}
