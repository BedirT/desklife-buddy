import Foundation
import Testing
@testable import Domain

@Suite("History policy")
struct HistoryPolicyTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Retention exposes exactly keep nothing, 30 days, and 90 days")
    func normativeChoices() {
        #expect(HistoryRetentionPolicy.allCases == [.keepNothing, .thirtyDays, .ninetyDays])
        #expect(HistoryRetentionPolicy.keepNothing.retentionDurationSeconds == 0)
        #expect(HistoryRetentionPolicy.thirtyDays.retentionDurationSeconds == 30 * 24 * 60 * 60)
        #expect(HistoryRetentionPolicy.ninetyDays.retentionDurationSeconds == 90 * 24 * 60 * 60)
    }

    @Test("Keep nothing retains no raw opportunity history")
    func keepNothing() {
        #expect(HistoryRetentionPolicy.keepNothing.retainedEvents([event(ageInDays: 0)], asOf: now).isEmpty)
    }

    @Test("30-day retention includes the boundary and drops older events")
    func thirtyDays() {
        let events = [event(ageInDays: 31), event(ageInDays: 30), event(ageInDays: 29)]

        #expect(HistoryRetentionPolicy.thirtyDays.retainedEvents(events, asOf: now) == [events[1], events[2]])
    }

    @Test("90-day retention includes the boundary and drops older events")
    func ninetyDays() {
        let events = [event(ageInDays: 91), event(ageInDays: 90), event(ageInDays: 89)]

        #expect(HistoryRetentionPolicy.ninetyDays.retainedEvents(events, asOf: now) == [events[1], events[2]])
    }

    private func event(ageInDays: Int) -> OpportunityEvent {
        OpportunityEvent(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", ageInDays))!,
            kind: .promptPresented,
            recordedAt: now.addingTimeInterval(-Double(ageInDays * 24 * 60 * 60)),
            source: .localTimer,
            opportunity: .visual,
        )
    }
}
