import Testing
@testable import Domain

@Suite("Estimated active computer use")
struct ActivityEstimatorTests {
    private let configuration: ActivityEstimatorConfiguration

    init() throws {
        configuration = try ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
        )
    }

    @Test("First sample establishes a monotonic baseline")
    func firstSampleAddsNothing() {
        var estimator = ActivityEstimator(configuration: configuration)

        let assessment = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        #expect(assessment.accumulatedSeconds == 0)
        #expect(!assessment.didBeginLikelyNaturalInterruption)
    }

    @Test("Recent input boundary is inclusive")
    func recentInputBoundaryIsInclusive() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 110, secondsSinceInput: 60))

        #expect(assessment.accumulatedSeconds == 10)
    }

    @Test("Input idle above the recent window pauses accumulation")
    func inputIdlePausesAccumulation() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 110, secondsSinceInput: 60.001))

        #expect(assessment.accumulatedSeconds == 0)
    }

    @Test("Awake active unlocked state is required")
    func systemAvailabilityIsRequired() {
        let unavailableSamples = [
            ActivitySample(
                uptimeSeconds: 110,
                secondsSinceInput: 0,
                systemAwake: false,
                sessionActive: true,
                screenLocked: false,
            ),
            ActivitySample(
                uptimeSeconds: 110,
                secondsSinceInput: 0,
                systemAwake: true,
                sessionActive: false,
                screenLocked: false,
            ),
            ActivitySample(
                uptimeSeconds: 110,
                secondsSinceInput: 0,
                systemAwake: true,
                sessionActive: true,
                screenLocked: true,
            ),
        ]

        for sample in unavailableSamples {
            var estimator = ActivityEstimator(configuration: configuration)
            _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

            #expect(estimator.assess(sample).accumulatedSeconds == 0)
        }
    }

    @Test("Long idle emits once per idle episode and rearms after recent input")
    func longIdleIsEdgeTriggered() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let firstIdle = estimator.assess(.active(uptimeSeconds: 400, secondsSinceInput: 300))
        let continuedIdle = estimator.assess(.active(uptimeSeconds: 410, secondsSinceInput: 310))
        _ = estimator.assess(.active(uptimeSeconds: 420, secondsSinceInput: 0))
        let secondIdle = estimator.assess(.active(uptimeSeconds: 720, secondsSinceInput: 300))

        #expect(firstIdle.didBeginLikelyNaturalInterruption)
        #expect(!continuedIdle.didBeginLikelyNaturalInterruption)
        #expect(secondIdle.didBeginLikelyNaturalInterruption)
    }

    @Test("Backward uptime resets the baseline without adding elapsed time")
    func backwardUptimeResetsBaseline() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 90, secondsSinceInput: 0))

        #expect(assessment.accumulatedSeconds == 0)
    }

    @Test("Wake grace excludes elapsed time until its configured boundary")
    func wakeGracePausesAccumulation() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(ActivitySample(
            uptimeSeconds: 100,
            secondsSinceInput: 0,
            systemAwake: false,
            sessionActive: false,
            screenLocked: true,
        ))
        let woke = estimator.assess(.active(uptimeSeconds: 110, secondsSinceInput: 0))
        let duringGrace = estimator.assess(.active(uptimeSeconds: 199, secondsSinceInput: 0))
        let afterGrace = estimator.assess(.active(uptimeSeconds: 205, secondsSinceInput: 0))

        #expect(woke.accumulatedSeconds == 0)
        #expect(duringGrace.accumulatedSeconds == 0)
        #expect(afterGrace.accumulatedSeconds == 5)
    }
}
