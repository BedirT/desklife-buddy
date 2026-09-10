import Foundation

/// One coarse observation of system availability and elapsed time since input.
public struct ActivitySample: Equatable, Sendable {
    public let uptimeSeconds: TimeInterval
    public let secondsSinceInput: TimeInterval
    public let systemAwake: Bool
    public let sessionActive: Bool
    public let screenLocked: Bool

    /// Creates an observation containing timing only, never input content.
    public init(
        uptimeSeconds: TimeInterval,
        secondsSinceInput: TimeInterval,
        systemAwake: Bool,
        sessionActive: Bool,
        screenLocked: Bool,
    ) {
        self.uptimeSeconds = uptimeSeconds
        self.secondsSinceInput = secondsSinceInput
        self.systemAwake = systemAwake
        self.sessionActive = sessionActive
        self.screenLocked = screenLocked
    }

    /// Convenience fixture for an awake, active, unlocked system.
    public static func active(
        uptimeSeconds: TimeInterval,
        secondsSinceInput: TimeInterval,
    ) -> ActivitySample {
        ActivitySample(
            uptimeSeconds: uptimeSeconds,
            secondsSinceInput: secondsSinceInput,
            systemAwake: true,
            sessionActive: true,
            screenLocked: false,
        )
    }

    var systemAvailable: Bool {
        systemAwake && sessionActive && !screenLocked
    }
}

/// Reducer output for one observed monotonic interval.
public struct ActivityAssessment: Equatable, Sendable {
    public let visualSessionSeconds: TimeInterval
    public let movementActiveUseSeconds: TimeInterval
    public let didBeginLikelyNaturalInterruption: Bool
    public let didReturnFromLongIdle: Bool
    public let isShortInputPause: Bool
}

/// Stateful coarse estimator that never observes or retains input content.
public struct ActivityEstimator: Sendable {
    private let configuration: ActivityEstimatorConfiguration
    private var previousUptimeSeconds: TimeInterval?
    private var previousSystemAvailable: Bool?
    private var wakeGraceEndsAtUptime: TimeInterval?
    private var returnGraceEndsAtUptime: TimeInterval?
    private var longIdleWasReported = false

    /// Creates an estimator with explicit thresholds from the protocol configuration.
    public init(configuration: ActivityEstimatorConfiguration) {
        self.configuration = configuration
    }

    /// Reduces one observation using monotonic elapsed time only.
    public mutating func assess(_ sample: ActivitySample) -> ActivityAssessment {
        guard sample.uptimeSeconds.isFinite,
              sample.secondsSinceInput.isFinite,
              sample.uptimeSeconds >= 0,
              sample.secondsSinceInput >= 0
        else {
            resetMonotonicBaseline()
            return noAccumulation()
        }

        defer {
            previousUptimeSeconds = sample.uptimeSeconds
            previousSystemAvailable = sample.systemAvailable
        }

        let idleTransition = assessLongIdle(for: sample)

        guard let previousUptimeSeconds,
              sample.uptimeSeconds >= previousUptimeSeconds
        else {
            wakeGraceEndsAtUptime = nil
            returnGraceEndsAtUptime = nil
            return noAccumulation(didBeginLongIdle: idleTransition.didBegin)
        }

        guard sample.systemAvailable else {
            longIdleWasReported = true
            wakeGraceEndsAtUptime = nil
            returnGraceEndsAtUptime = nil
            return noAccumulation()
        }

        if previousSystemAvailable == false {
            wakeGraceEndsAtUptime = sample.uptimeSeconds + configuration.wakeUnlockGraceSeconds
        }

        if idleTransition.didReturn {
            returnGraceEndsAtUptime = sample.uptimeSeconds
                + configuration.postInterruptionGraceSeconds
        }

        guard sample.secondsSinceInput < configuration.longIdleResetSeconds else {
            return noAccumulation(didBeginLongIdle: idleTransition.didBegin)
        }

        let observedInterval = sample.uptimeSeconds - previousUptimeSeconds
        guard observedInterval <= configuration.maximumSampleGapSeconds else {
            return noAccumulation(didReturnFromLongIdle: idleTransition.didReturn)
        }

        let graceEndsAt = max(
            wakeGraceEndsAtUptime ?? previousUptimeSeconds,
            returnGraceEndsAtUptime ?? previousUptimeSeconds,
        )
        let accumulationStart = max(previousUptimeSeconds, graceEndsAt)
        let visualSessionSeconds = max(0, sample.uptimeSeconds - accumulationStart)
        if let wakeGraceEndsAtUptime, sample.uptimeSeconds >= wakeGraceEndsAtUptime {
            self.wakeGraceEndsAtUptime = nil
        }
        if let returnGraceEndsAtUptime, sample.uptimeSeconds >= returnGraceEndsAtUptime {
            self.returnGraceEndsAtUptime = nil
        }

        let isInGrace = visualSessionSeconds == 0 && sample.uptimeSeconds < graceEndsAt
        let isShortInputPause = !isInGrace
            && sample.secondsSinceInput >= configuration.lowFrictionInputPauseSeconds
            && sample.secondsSinceInput < configuration.longIdleResetSeconds
        let movementActiveUseSeconds = sample.secondsSinceInput
            <= configuration.recentInputWindowSeconds
            ? visualSessionSeconds
            : 0

        return ActivityAssessment(
            visualSessionSeconds: visualSessionSeconds,
            movementActiveUseSeconds: movementActiveUseSeconds,
            didBeginLikelyNaturalInterruption: idleTransition.didBegin,
            didReturnFromLongIdle: idleTransition.didReturn,
            isShortInputPause: isShortInputPause,
        )
    }

    private mutating func assessLongIdle(
        for sample: ActivitySample,
    ) -> (didBegin: Bool, didReturn: Bool) {
        guard sample.systemAvailable else { return (false, false) }

        if sample.secondsSinceInput <= configuration.recentInputWindowSeconds {
            let didReturn = longIdleWasReported
            longIdleWasReported = false
            return (false, didReturn)
        }

        guard sample.secondsSinceInput >= configuration.longIdleResetSeconds,
              !longIdleWasReported
        else {
            return (false, false)
        }

        longIdleWasReported = true
        return (true, false)
    }

    private mutating func resetMonotonicBaseline() {
        previousUptimeSeconds = nil
        previousSystemAvailable = nil
        wakeGraceEndsAtUptime = nil
        returnGraceEndsAtUptime = nil
    }

    private func noAccumulation(
        didBeginLongIdle: Bool = false,
        didReturnFromLongIdle: Bool = false,
    ) -> ActivityAssessment {
        ActivityAssessment(
            visualSessionSeconds: 0,
            movementActiveUseSeconds: 0,
            didBeginLikelyNaturalInterruption: didBeginLongIdle,
            didReturnFromLongIdle: didReturnFromLongIdle,
            isShortInputPause: false,
        )
    }
}
