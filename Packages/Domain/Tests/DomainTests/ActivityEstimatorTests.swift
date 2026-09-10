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
            lowFrictionInputPauseSeconds: 5,
            postInterruptionGraceSeconds: 60,
        )
    }

    @Test("First sample establishes a monotonic baseline")
    func firstSampleAddsNothing() {
        var estimator = ActivityEstimator(configuration: configuration)

        let assessment = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        #expect(assessment.visualSessionSeconds == 0)
        #expect(assessment.movementActiveUseSeconds == 0)
        #expect(!assessment.didBeginLikelyNaturalInterruption)
    }

    @Test("Recent input boundary is inclusive")
    func recentInputBoundaryIsInclusive() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 110, secondsSinceInput: 60))

        #expect(assessment.visualSessionSeconds == 10)
        #expect(assessment.movementActiveUseSeconds == 10)
    }

    @Test("Passive reading advances visual timing without claiming active input")
    func passiveReadingAdvancesVisualButNotMovement() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 110, secondsSinceInput: 70))

        #expect(assessment.visualSessionSeconds == 10)
        #expect(assessment.movementActiveUseSeconds == 0)
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

            let assessment = estimator.assess(sample)
            #expect(assessment.visualSessionSeconds == 0)
            #expect(assessment.movementActiveUseSeconds == 0)
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

        #expect(assessment.visualSessionSeconds == 0)
        #expect(assessment.movementActiveUseSeconds == 0)
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

        #expect(woke.visualSessionSeconds == 0)
        #expect(duringGrace.visualSessionSeconds == 0)
        #expect(afterGrace.visualSessionSeconds == 5)
    }

    @Test("Five seconds without input is the inclusive low-friction boundary")
    func shortInputPauseIsBoundaryInclusive() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let before = estimator.assess(.active(uptimeSeconds: 101, secondsSinceInput: 4.999))
        let boundary = estimator.assess(.active(uptimeSeconds: 102, secondsSinceInput: 5))

        #expect(!before.isShortInputPause)
        #expect(boundary.isShortInputPause)
    }

    @Test("Long idle advances neither clock and emits only once")
    func longIdleAdvancesNeitherClock() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let boundary = estimator.assess(.active(uptimeSeconds: 400, secondsSinceInput: 300))
        let continued = estimator.assess(.active(uptimeSeconds: 410, secondsSinceInput: 310))

        #expect(boundary.visualSessionSeconds == 0)
        #expect(boundary.movementActiveUseSeconds == 0)
        #expect(boundary.didBeginLikelyNaturalInterruption)
        #expect(!continued.didBeginLikelyNaturalInterruption)
    }

    @Test("Input return starts a bounded grace that expires without a caller")
    func returnFromLongIdleStartsGraceOnce() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))
        _ = estimator.assess(.active(uptimeSeconds: 400, secondsSinceInput: 300))
        _ = estimator.assess(.active(uptimeSeconds: 410, secondsSinceInput: 310))

        let returned = estimator.assess(.active(uptimeSeconds: 420, secondsSinceInput: 0))
        let duringGrace = estimator.assess(.active(uptimeSeconds: 479, secondsSinceInput: 0))
        let afterGrace = estimator.assess(.active(uptimeSeconds: 485, secondsSinceInput: 0))

        #expect(returned.didReturnFromLongIdle)
        #expect(returned.visualSessionSeconds == 0)
        #expect(duringGrace.visualSessionSeconds == 0)
        #expect(afterGrace.visualSessionSeconds == 5)
        #expect(afterGrace.movementActiveUseSeconds == 5)
    }

    @Test("A large unobserved interval is not inferred as screen-session time")
    func unobservedGapAddsNothing() {
        var estimator = ActivityEstimator(configuration: configuration)
        _ = estimator.assess(.active(uptimeSeconds: 100, secondsSinceInput: 0))

        let assessment = estimator.assess(.active(uptimeSeconds: 200, secondsSinceInput: 0))

        #expect(assessment.visualSessionSeconds == 0)
        #expect(assessment.movementActiveUseSeconds == 0)
    }
}
