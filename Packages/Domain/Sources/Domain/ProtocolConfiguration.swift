import Foundation

/// Validation failures that keep protocol timing internally coherent.
public enum ProtocolConfigurationError: Error, Equatable {
    case nonPositiveValue
    case invalidOpportunityWindow
    case invalidActivityThresholds
    case invalidDeliveryOptions
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

    /// Creates estimator thresholds while preserving a distinct long-idle boundary.
    public init(
        recentInputWindowSeconds: TimeInterval,
        longIdleResetSeconds: TimeInterval,
        wakeUnlockGraceSeconds: TimeInterval,
    ) throws {
        guard recentInputWindowSeconds > 0,
              longIdleResetSeconds > 0,
              wakeUnlockGraceSeconds >= 0
        else {
            throw ProtocolConfigurationError.nonPositiveValue
        }
        guard recentInputWindowSeconds < longIdleResetSeconds else {
            throw ProtocolConfigurationError.invalidActivityThresholds
        }

        self.recentInputWindowSeconds = recentInputWindowSeconds
        self.longIdleResetSeconds = longIdleResetSeconds
        self.wakeUnlockGraceSeconds = wakeUnlockGraceSeconds
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

    /// Groups already validated configuration without introducing hidden defaults.
    public init(
        visual: OpportunitySchedule,
        movement: OpportunitySchedule,
        activityEstimator: ActivityEstimatorConfiguration,
        delivery: OpportunityDeliveryConfiguration,
    ) {
        self.visual = visual
        self.movement = movement
        self.activityEstimator = activityEstimator
        self.delivery = delivery
    }
}
