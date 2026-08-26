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
    public let accumulatedSeconds: TimeInterval
    public let didBeginLikelyNaturalInterruption: Bool
}

/// Stateful coarse estimator that never observes or retains input content.
public struct ActivityEstimator: Sendable {
    private let configuration: ActivityEstimatorConfiguration
    private var previousUptimeSeconds: TimeInterval?
    private var previousSystemAvailable: Bool?
    private var wakeGraceEndsAtUptime: TimeInterval?
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

        let didBeginLongIdle = assessLongIdle(for: sample)

        guard let previousUptimeSeconds,
              sample.uptimeSeconds >= previousUptimeSeconds
        else {
            wakeGraceEndsAtUptime = nil
            return noAccumulation(didBeginLongIdle: didBeginLongIdle)
        }

        guard sample.systemAvailable else {
            longIdleWasReported = true
            wakeGraceEndsAtUptime = nil
            return noAccumulation()
        }

        if previousSystemAvailable == false {
            wakeGraceEndsAtUptime = sample.uptimeSeconds + configuration.wakeUnlockGraceSeconds
        }

        guard sample.secondsSinceInput <= configuration.recentInputWindowSeconds else {
            return noAccumulation(didBeginLongIdle: didBeginLongIdle)
        }

        let accumulationStart = max(previousUptimeSeconds, wakeGraceEndsAtUptime ?? previousUptimeSeconds)
        let accumulatedSeconds = max(0, sample.uptimeSeconds - accumulationStart)
        if let wakeGraceEndsAtUptime, sample.uptimeSeconds >= wakeGraceEndsAtUptime {
            self.wakeGraceEndsAtUptime = nil
        }

        return ActivityAssessment(
            accumulatedSeconds: accumulatedSeconds,
            didBeginLikelyNaturalInterruption: didBeginLongIdle,
        )
    }

    private mutating func assessLongIdle(for sample: ActivitySample) -> Bool {
        guard sample.systemAvailable else { return false }

        if sample.secondsSinceInput <= configuration.recentInputWindowSeconds {
            longIdleWasReported = false
            return false
        }

        guard sample.secondsSinceInput >= configuration.longIdleResetSeconds,
              !longIdleWasReported
        else {
            return false
        }

        longIdleWasReported = true
        return true
    }

    private mutating func resetMonotonicBaseline() {
        previousUptimeSeconds = nil
        previousSystemAvailable = nil
        wakeGraceEndsAtUptime = nil
    }

    private func noAccumulation(didBeginLongIdle: Bool = false) -> ActivityAssessment {
        ActivityAssessment(
            accumulatedSeconds: 0,
            didBeginLikelyNaturalInterruption: didBeginLongIdle,
        )
    }
}
