import Foundation
import Testing
@testable import Domain

@Suite("History export")
struct HistoryExportTests {
    private struct EventFixture {
        let id: String
        let kind: OpportunityEventKind
        let source: OpportunityEventSource
        let opportunity: OpportunityType?
        let duration: TimeInterval?
    }

    @Test("Export field vocabulary and order are stable")
    func stableFieldVocabulary() {
        #expect(HistoryExportField.allCases.map(\.rawValue) == [
            "id",
            "recordedAt",
            "kind",
            "source",
            "opportunity",
            "selectedDurationSeconds",
        ])
    }

    @Test("Export request retains format and canonicalizes a typed field selection")
    func typedRequestCanonicalOrder() throws {
        let request = try HistoryExportRequest(
            format: .csv,
            selectedFields: [.source, .id, .opportunity],
        )

        #expect(request.format == .csv)
        #expect(request.fields == [.id, .source, .opportunity])
        #expect(throws: HistoryExportRequestError.noSelectedFields) {
            _ = try HistoryExportRequest(format: .json, selectedFields: [])
        }
    }

    @Test("Projection is chronological with identifier tie-breaking and no inferred fields")
    func stableProjection() {
        let sameTime = Date(timeIntervalSince1970: 1_767_225_600)
        let later = event(
            EventFixture(
                id: "00000000-0000-4000-8000-000000000083",
                kind: .skipped,
                source: .user,
                opportunity: .movement,
                duration: nil,
            ),
            recordedAt: sameTime.addingTimeInterval(1),
        )
        let tieSecond = event(
            EventFixture(
                id: "00000000-0000-4000-8000-000000000082",
                kind: .breakStarted,
                source: .user,
                opportunity: .movement,
                duration: 120,
            ),
            recordedAt: sameTime,
        )
        let tieFirst = event(
            EventFixture(
                id: "00000000-0000-4000-8000-000000000081",
                kind: .promptPresented,
                source: .localTimer,
                opportunity: .visual,
                duration: nil,
            ),
            recordedAt: sameTime,
        )

        let export = HistoryExport.project(
            events: [later, tieSecond, tieFirst],
            fields: HistoryExportField.allCases,
        )

        #expect(export.formatVersion == 2)
        #expect(export.fields == HistoryExportField.allCases)
        #expect(export.records.map(\.id) == [tieFirst.id, tieSecond.id, later.id])
        #expect(export.records[0] == HistoryExportRecord(
            id: tieFirst.id,
            recordedAt: sameTime,
            kind: "promptPresented",
            source: "localTimer",
            opportunity: "visual",
            selectedDurationSeconds: nil,
        ))
        #expect(export.records[1].selectedDurationSeconds == 120)
        #expect(export.records[2].opportunity == "movement")
    }

    private func event(_ fixture: EventFixture, recordedAt: Date) -> OpportunityEvent {
        OpportunityEvent(
            id: UUID(uuidString: fixture.id)!,
            kind: fixture.kind,
            recordedAt: recordedAt,
            source: fixture.source,
            opportunity: fixture.opportunity,
            selectedDurationSeconds: fixture.duration,
        )
    }
}
