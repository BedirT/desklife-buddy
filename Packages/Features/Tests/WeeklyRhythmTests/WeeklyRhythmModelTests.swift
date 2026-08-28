import Domain
import Testing
@testable import WeeklyRhythm

@Suite("Weekly rhythm model")
struct WeeklyRhythmModelTests {
    @Test("Constructing the model does not load or present Weekly automatically")
    func doesNotLoadAutomatically() {
        let probe = WeeklyClientProbe(report: report(.populated))

        let model = WeeklyRhythmModel(client: probe.client)

        #expect(model.state == .notLoaded)
        #expect(probe.loadCount == 0)
    }

    @Test("An explicit load publishes the exact projected report")
    func loadsExactReport() async {
        let expected = report(.populated)
        let probe = WeeklyClientProbe(report: expected)
        let model = WeeklyRhythmModel(client: probe.client)

        await model.load()

        #expect(model.state == .loaded(expected))
        #expect(probe.loadCount == 1)
    }

    @Test("History disabled remains distinct from an empty or failed read")
    func preservesHistoryDisabled() async {
        let expected = report(.historyDisabled)
        let model = WeeklyRhythmModel(client: WeeklyClientProbe(report: expected).client)

        await model.load()

        #expect(model.state == .loaded(expected))
        #expect(model.report?.state == .historyDisabled)
    }

    @Test("A query failure is honest and can be retried")
    func failureAndRetry() async {
        let probe = WeeklyClientProbe(report: report(.sparse), failuresBeforeSuccess: 1)
        let model = WeeklyRhythmModel(client: probe.client)

        await model.load()
        #expect(model.state == .failed)

        await model.retry()
        #expect(model.state == .loaded(report(.sparse)))
        #expect(probe.loadCount == 2)
    }

    @Test("Schedule adjustment happens only after the explicit action")
    func explicitAdjustment() {
        let probe = WeeklyClientProbe(report: report(.populated))
        let model = WeeklyRhythmModel(client: probe.client)

        #expect(probe.settingsCount == 0)
        model.openScheduleSettings()
        #expect(probe.settingsCount == 1)
    }

    @Test("History review is a distinct explicit Settings route")
    func explicitHistoryReview() {
        let probe = WeeklyClientProbe(report: report(.historyDisabled))
        let model = WeeklyRhythmModel(client: probe.client)

        #expect(probe.historySettingsCount == 0)
        model.openHistorySettings()
        #expect(probe.historySettingsCount == 1)
        #expect(probe.settingsCount == 0)
    }
}

private final class WeeklyClientProbe {
    private let result: WeeklyRhythmReport
    private let failuresBeforeSuccess: Int
    var loadCount = 0
    var settingsCount = 0
    var historySettingsCount = 0

    init(report: WeeklyRhythmReport, failuresBeforeSuccess: Int = 0) {
        result = report
        self.failuresBeforeSuccess = failuresBeforeSuccess
    }

    var client: WeeklyRhythmClient {
        WeeklyRhythmClient(
            load: { [self] in
                loadCount += 1
                if loadCount <= failuresBeforeSuccess {
                    throw WeeklyTestFailure.forced
                }
                return result
            },
            openScheduleSettings: { [self] in settingsCount += 1 },
            openHistorySettings: { [self] in historySettingsCount += 1 },
        )
    }
}

private enum WeeklyTestFailure: Error {
    case forced
}

private func report(_ state: WeeklyRhythmDataState) -> WeeklyRhythmReport {
    let input = switch state {
    case .populated: WeeklyRhythmFixtures.populated
    case .sparse: WeeklyRhythmFixtures.sparse
    case .empty: WeeklyRhythmFixtures.empty
    case .historyDisabled: WeeklyRhythmFixtures.historyDisabled
    }
    return WeeklyRhythmProjection.project(input)
}
