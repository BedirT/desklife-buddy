import Domain
import Foundation
import Testing
@testable import App

@Suite("Weekly rhythm App route")
struct WeeklyRhythmRouteTests {
    @Test("Weekly is presented only after the explicit status-menu route")
    func explicitRouteOnly() {
        let delegate = AppDelegate()
        let probe = WeeklyRouteProbe()
        delegate.weeklyRhythmPresentationOverride = {
            probe.presentations += 1
            return true
        }

        #expect(probe.presentations == 0)
        delegate.route(.openWeeklyRhythm)
        #expect(probe.presentations == 1)
    }

    @Test("Current week uses local Monday boundaries")
    func currentWeekInterval() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Vancouver")!
        let date = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 28,
            hour: 14,
        ))!

        let interval = try WeeklyRhythmInterval.currentWeek(containing: date, calendar: calendar)

        #expect(calendar.component(.weekday, from: interval.startedAt) == 2)
        #expect(calendar.component(.day, from: interval.startedAt) == 24)
        #expect(calendar.component(.day, from: interval.endedAt) == 31)
    }
}

private final class WeeklyRouteProbe {
    var presentations = 0
}
