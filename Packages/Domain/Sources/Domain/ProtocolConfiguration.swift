import Foundation

/// Validation failures that keep protocol timing internally coherent.
public enum ProtocolConfigurationError: Error, Equatable {
    case nonPositiveValue
    case invalidOpportunityWindow
    case invalidActivityThresholds
    case invalidDeliveryOptions
    case invalidRecoveryOptions
}

/// Injected timing for one independently scheduled opportunity.
public struct OpportunitySchedule: Equatable, Sendable {
    public let softDueSeconds: TimeInterval
    public let targetSeconds: TimeInterval
    public let latestPreferredSeconds: TimeInterval
    public let durationOptionsSeconds: [TimeInterval]

    /// Creates an ordered opportunity window without choosing a product default.
    public init(
        softDueSeconds: TimeInterval,
        targetSeconds: TimeInterval,
        latestPreferredSeconds: TimeInterval,
        durationOptionsSeconds: [TimeInterval],
    ) throws {
        guard softDueSeconds > 0,
              targetSeconds > 0,
              latestPreferredSeconds > 0,
              !durationOptionsSeconds.isEmpty,
              durationOptionsSeconds.allSatisfy({ $0 > 0 })
        else {
            throw ProtocolConfigurationError.nonPositiveValue
        }
        guard softDueSeconds <= targetSeconds, targetSeconds <= latestPreferredSeconds else {
            throw ProtocolConfigurationError.invalidOpportunityWindow
        }

        self.softDueSeconds = softDueSeconds
        self.targetSeconds = targetSeconds
        self.latestPreferredSeconds = latestPreferredSeconds
        self.durationOptionsSeconds = durationOptionsSeconds
    }
}

/// Injected thresholds for the privacy-minimized activity estimate.
public struct ActivityEstimatorConfiguration: Equatable, Sendable {
    public let recentInputWindowSeconds: TimeInterval
    public let longIdleResetSeconds: TimeInterval
    public let wakeUnlockGraceSeconds: TimeInterval
    public let lowFrictionInputPauseSeconds: TimeInterval
    public let postInterruptionGraceSeconds: TimeInterval
    public let maximumSampleGapSeconds: TimeInterval

    /// Creates estimator thresholds while preserving a distinct long-idle boundary.
    public init(
        recentInputWindowSeconds: TimeInterval,
        longIdleResetSeconds: TimeInterval,
        wakeUnlockGraceSeconds: TimeInterval,
        lowFrictionInputPauseSeconds: TimeInterval? = nil,
        postInterruptionGraceSeconds: TimeInterval = 60,
        maximumSampleGapSeconds: TimeInterval? = nil,
    ) throws {
        let lowFrictionInputPauseSeconds = lowFrictionInputPauseSeconds
            ?? min(5, longIdleResetSeconds / 2)
        let maximumSampleGapSeconds = maximumSampleGapSeconds
            ?? min(90, longIdleResetSeconds / 2)
        guard recentInputWindowSeconds > 0,
              longIdleResetSeconds > 0,
              wakeUnlockGraceSeconds >= 0,
              lowFrictionInputPauseSeconds > 0,
              postInterruptionGraceSeconds >= 0,
              maximumSampleGapSeconds > 0
        else {
            throw ProtocolConfigurationError.nonPositiveValue
        }
        guard lowFrictionInputPauseSeconds < longIdleResetSeconds,
              recentInputWindowSeconds < longIdleResetSeconds,
              maximumSampleGapSeconds < longIdleResetSeconds
        else {
            throw ProtocolConfigurationError.invalidActivityThresholds
        }

        self.recentInputWindowSeconds = recentInputWindowSeconds
        self.longIdleResetSeconds = longIdleResetSeconds
        self.wakeUnlockGraceSeconds = wakeUnlockGraceSeconds
        self.lowFrictionInputPauseSeconds = lowFrictionInputPauseSeconds
        self.postInterruptionGraceSeconds = postInterruptionGraceSeconds
        self.maximumSampleGapSeconds = maximumSampleGapSeconds
    }
}

/// Injected scheduling policy shared by visual and movement opportunities.
public struct OpportunityDeliveryConfiguration: Equatable, Sendable {
    public let waitForLowFrictionMoment: Bool
    public let mergeWindowSeconds: TimeInterval
    public let headsUpDefault: Bool
    public let headsUpSecondsBeforeTarget: TimeInterval
    public let snoozeOptionsSeconds: [TimeInterval]
    public let maximumRepeatedEscalations: Int
    public let lockoutAllowed: Bool

    /// Creates delivery policy without assuming any profile or UI representation.
    public init(
        waitForLowFrictionMoment: Bool,
        mergeWindowSeconds: TimeInterval,
        headsUpDefault: Bool,
        headsUpSecondsBeforeTarget: TimeInterval,
        snoozeOptionsSeconds: [TimeInterval],
        maximumRepeatedEscalations: Int,
        lockoutAllowed: Bool,
    ) throws {
        guard mergeWindowSeconds >= 0,
              headsUpSecondsBeforeTarget >= 0,
              !snoozeOptionsSeconds.isEmpty,
              snoozeOptionsSeconds.allSatisfy({ $0 > 0 }),
              maximumRepeatedEscalations >= 0,
              !lockoutAllowed
        else {
            throw ProtocolConfigurationError.invalidDeliveryOptions
        }

        self.waitForLowFrictionMoment = waitForLowFrictionMoment
        self.mergeWindowSeconds = mergeWindowSeconds
        self.headsUpDefault = headsUpDefault
        self.headsUpSecondsBeforeTarget = headsUpSecondsBeforeTarget
        self.snoozeOptionsSeconds = snoozeOptionsSeconds
        self.maximumRepeatedEscalations = maximumRepeatedEscalations
        self.lockoutAllowed = lockoutAllowed
    }
}

/// Optional recovery-suggestion policy sourced from the normative protocol profile.
public struct RecoveryConfiguration: Equatable, Sendable {
    public let eligibleAfterSeconds: TimeInterval
    public let latestTypicalSeconds: TimeInterval
    public let suggestedDurationMinSeconds: TimeInterval
    public let suggestedDurationMaxSeconds: TimeInterval
    public let requiredMovementDeferrals: Int
    public let maximumOffersPerSession: Int

    public init(
        eligibleAfterSeconds: TimeInterval,
        latestTypicalSeconds: TimeInterval? = nil,
        suggestedDurationMinSeconds: TimeInterval = 300,
        suggestedDurationMaxSeconds: TimeInterval = 600,
        requiredMovementDeferrals: Int,
        maximumOffersPerSession: Int = 1,
    ) throws {
        let latestTypicalSeconds = latestTypicalSeconds ?? eligibleAfterSeconds
        guard eligibleAfterSeconds.isFinite,
              latestTypicalSeconds.isFinite,
              suggestedDurationMinSeconds.isFinite,
              suggestedDurationMaxSeconds.isFinite,
              eligibleAfterSeconds > 0,
              latestTypicalSeconds >= eligibleAfterSeconds,
              suggestedDurationMinSeconds > 0,
              suggestedDurationMaxSeconds >= suggestedDurationMinSeconds,
              requiredMovementDeferrals > 0,
              maximumOffersPerSession == 1
        else {
            throw ProtocolConfigurationError.invalidRecoveryOptions
        }

        self.eligibleAfterSeconds = eligibleAfterSeconds
        self.latestTypicalSeconds = latestTypicalSeconds
        self.suggestedDurationMinSeconds = suggestedDurationMinSeconds
        self.suggestedDurationMaxSeconds = suggestedDurationMaxSeconds
        self.requiredMovementDeferrals = requiredMovementDeferrals
        self.maximumOffersPerSession = maximumOffersPerSession
    }
}

/// Stable identifiers for machine-readable built-in profiles and user-supplied custom timing.
public enum ProtocolProfileID: String, CaseIterable, Codable, Sendable {
    case gentle
    case balanced
    case frequentMovement = "frequent_movement"
    case researchInformedHighFrequency = "research_informed_high_frequency"
    case custom

    /// Profiles whose timings are projected directly from the normative YAML.
    public static let builtInCases: [ProtocolProfileID] = [
        .gentle,
        .balanced,
        .frequentMovement,
        .researchInformedHighFrequency,
    ]
}

/// Complete typed input to the protocol engine, supplied by the App composition root.
public struct ProtocolConfiguration: Equatable, Sendable {
    public let visual: OpportunitySchedule
    public let movement: OpportunitySchedule
    public let activityEstimator: ActivityEstimatorConfiguration
    public let delivery: OpportunityDeliveryConfiguration
    public let recovery: RecoveryConfiguration?

    /// Groups already validated configuration without introducing hidden defaults.
    public init(
        visual: OpportunitySchedule,
        movement: OpportunitySchedule,
        activityEstimator: ActivityEstimatorConfiguration,
        delivery: OpportunityDeliveryConfiguration,
        recovery: RecoveryConfiguration? = nil,
    ) {
        self.visual = visual
        self.movement = movement
        self.activityEstimator = activityEstimator
        self.delivery = delivery
        self.recovery = recovery
    }
}
