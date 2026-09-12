import Domain
import Foundation
import Testing
@testable import Movement

/// Projection-only break surface: the movement surface renders from a
/// projected durations value. It never receives the engine's schedule type,
/// so no presenter can reach past the facade into clocks or configuration
/// behavior.
@Suite("Movement projection binding")
struct MovementProjectionTests {
    @Test("The surface opens with the projected recommended duration")
    func opensWithProjectedRecommendedDuration() {
        let model = MovementModel(
            durations: MovementDurations(recommendedSeconds: 300, quickSeconds: 120),
            now: { 0 },
        )
        model.open()

        #expect(model.selectedDurationSeconds == 300)
        #expect(model.recommendedDurationSeconds == 300)
        #expect(model.quickDurationSeconds == 120)
        #expect(model.remainingSeconds == 300)
    }

    @Test("A projected quick entry opens with the matching announcement")
    func opensWithProjectedQuickEntry() {
        var announcements: [MovementAnnouncement] = []
        let model = MovementModel(
            durations: MovementDurations(recommendedSeconds: 300, quickSeconds: 120),
            initialDurationSeconds: 120,
            now: { 0 },
            onAnnouncement: { announcements.append($0) },
        )
        model.open()

        #expect(model.selectedDurationSeconds == 120)
        #expect(announcements == [.opened(durationSeconds: 120)])
    }

    @Test("The countdown derives from the projected duration and the injected now")
    func refreshDerivesCountdownFromProjection() {
        let clock = MovementProjectionTestClock()
        let model = MovementModel(
            durations: MovementDurations(recommendedSeconds: 300, quickSeconds: 120),
            now: { clock.value },
        )
        model.open()

        clock.value = 75
        model.refresh()

        #expect(model.remainingSeconds == 225)
    }
}

private final class MovementProjectionTestClock {
    var value: TimeInterval = 0
}
