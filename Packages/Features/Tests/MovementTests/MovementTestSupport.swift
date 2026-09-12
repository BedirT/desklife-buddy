import Domain
import Foundation
@testable import Movement

func makeModel(
    clock: TestClock = TestClock(),
    durations: [TimeInterval] = [300, 120],
    onAction: @escaping (MovementAction) -> Void = { _ in },
    onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
) throws -> MovementModel {
    let schedule = try movementSchedule(durations: durations)
    return MovementModel(
        durations: MovementDurations.projected(from: schedule),
        now: { clock.value },
        onAction: onAction,
        onAnnouncement: onAnnouncement,
    )
}

func movementSchedule(durations: [TimeInterval]) throws -> OpportunitySchedule {
    try OpportunitySchedule(
        softDueSeconds: 3000,
        targetSeconds: 3600,
        latestPreferredSeconds: 4200,
        durationOptionsSeconds: durations,
    )
}

final class TestClock {
    var value: TimeInterval = 0
}
