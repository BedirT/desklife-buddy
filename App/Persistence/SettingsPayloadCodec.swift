import Domain
import Foundation

enum SettingsPersistenceError: Error, Equatable {
    case unsupportedSchemaVersion(Int)
    case unsupportedConfigurationFormatVersion(Int)
    case invalidConfiguration
    case profileStateMismatch
    case runtimeStateRequiresAtomicCommit
}

struct ResolvedAppPreferences: Equatable {
    let preferences: AppPreferences
    let configuration: ProtocolConfiguration

    var profileID: ProtocolProfileID {
        preferences.schedule.profile.protocolProfileID
    }
}

enum SettingsPreferenceResolver {
    static func resolve(_ preferences: AppPreferences) throws -> ResolvedAppPreferences {
        let profileID = preferences.schedule.profile.protocolProfileID
        let generatedBase: ProtocolConfiguration = switch preferences.schedule.profile {
        case .custom:
            try ProtocolProfiles.configuration(for: .balanced)
        case .gentle, .balanced, .frequentMovement, .researchInformedHighFrequency:
            try ProtocolProfiles.configuration(for: profileID)
        }
        return ResolvedAppPreferences(
            preferences: preferences,
            configuration: preferences.protocolConfiguration(applyingTo: generatedBase),
        )
    }
}

enum SettingsPayloadCodec {
    static func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    static func encode(_ configuration: ProtocolConfiguration) throws -> Data {
        try encode(ProtocolConfigurationPayload(configuration: configuration))
    }

    static func decodePreferences(_ data: Data) throws -> AppPreferences {
        try JSONDecoder().decode(AppPreferences.self, from: data)
    }

    static func decodeConfiguration(_ data: Data) throws -> ProtocolConfiguration {
        try JSONDecoder().decode(ProtocolConfigurationPayload.self, from: data).configuration()
    }
}

private struct ProtocolConfigurationPayload: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let visual: OpportunitySchedulePayload
    let movement: OpportunitySchedulePayload
    let activityEstimator: ActivityEstimatorPayload
    let delivery: OpportunityDeliveryPayload
    let recovery: RecoveryPayload?

    init(configuration: ProtocolConfiguration) {
        formatVersion = Self.currentFormatVersion
        visual = OpportunitySchedulePayload(value: configuration.visual)
        movement = OpportunitySchedulePayload(value: configuration.movement)
        activityEstimator = ActivityEstimatorPayload(value: configuration.activityEstimator)
        delivery = OpportunityDeliveryPayload(value: configuration.delivery)
        recovery = configuration.recovery.map(RecoveryPayload.init(value:))
    }

    func configuration() throws -> ProtocolConfiguration {
        guard formatVersion == Self.currentFormatVersion else {
            throw SettingsPersistenceError.unsupportedConfigurationFormatVersion(formatVersion)
        }
        do {
            return try ProtocolConfiguration(
                visual: visual.value(),
                movement: movement.value(),
                activityEstimator: activityEstimator.value(),
                delivery: delivery.value(),
                recovery: recovery?.value(),
            )
        } catch let error as SettingsPersistenceError {
            throw error
        } catch {
            throw SettingsPersistenceError.invalidConfiguration
        }
    }
}

private struct OpportunitySchedulePayload: Codable {
    let softDueSeconds: TimeInterval
    let targetSeconds: TimeInterval
    let latestPreferredSeconds: TimeInterval
    let durationOptionsSeconds: [TimeInterval]

    init(value: OpportunitySchedule) {
        softDueSeconds = value.softDueSeconds
        targetSeconds = value.targetSeconds
        latestPreferredSeconds = value.latestPreferredSeconds
        durationOptionsSeconds = value.durationOptionsSeconds
    }

    func value() throws -> OpportunitySchedule {
        try OpportunitySchedule(
            softDueSeconds: softDueSeconds,
            targetSeconds: targetSeconds,
            latestPreferredSeconds: latestPreferredSeconds,
            durationOptionsSeconds: durationOptionsSeconds,
        )
    }
}

private struct ActivityEstimatorPayload: Codable {
    let recentInputWindowSeconds: TimeInterval
    let longIdleResetSeconds: TimeInterval
    let wakeUnlockGraceSeconds: TimeInterval
    let lowFrictionInputPauseSeconds: TimeInterval?
    let postInterruptionGraceSeconds: TimeInterval?
    let maximumSampleGapSeconds: TimeInterval?

    init(value: ActivityEstimatorConfiguration) {
        recentInputWindowSeconds = value.recentInputWindowSeconds
        longIdleResetSeconds = value.longIdleResetSeconds
        wakeUnlockGraceSeconds = value.wakeUnlockGraceSeconds
        lowFrictionInputPauseSeconds = value.lowFrictionInputPauseSeconds
        postInterruptionGraceSeconds = value.postInterruptionGraceSeconds
        maximumSampleGapSeconds = value.maximumSampleGapSeconds
    }

    func value() throws -> ActivityEstimatorConfiguration {
        try ActivityEstimatorConfiguration(
            recentInputWindowSeconds: recentInputWindowSeconds,
            longIdleResetSeconds: longIdleResetSeconds,
            wakeUnlockGraceSeconds: wakeUnlockGraceSeconds,
            lowFrictionInputPauseSeconds: lowFrictionInputPauseSeconds,
            postInterruptionGraceSeconds: postInterruptionGraceSeconds ?? 60,
            maximumSampleGapSeconds: maximumSampleGapSeconds,
        )
    }
}

private struct OpportunityDeliveryPayload: Codable {
    let waitForLowFrictionMoment: Bool
    let mergeWindowSeconds: TimeInterval
    let headsUpDefault: Bool
    let headsUpSecondsBeforeTarget: TimeInterval
    let snoozeOptionsSeconds: [TimeInterval]
    let maximumRepeatedEscalations: Int
    let lockoutAllowed: Bool

    init(value: OpportunityDeliveryConfiguration) {
        waitForLowFrictionMoment = value.waitForLowFrictionMoment
        mergeWindowSeconds = value.mergeWindowSeconds
        headsUpDefault = value.headsUpDefault
        headsUpSecondsBeforeTarget = value.headsUpSecondsBeforeTarget
        snoozeOptionsSeconds = value.snoozeOptionsSeconds
        maximumRepeatedEscalations = value.maximumRepeatedEscalations
        lockoutAllowed = value.lockoutAllowed
    }

    func value() throws -> OpportunityDeliveryConfiguration {
        try OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: waitForLowFrictionMoment,
            mergeWindowSeconds: mergeWindowSeconds,
            headsUpDefault: headsUpDefault,
            headsUpSecondsBeforeTarget: headsUpSecondsBeforeTarget,
            snoozeOptionsSeconds: snoozeOptionsSeconds,
            maximumRepeatedEscalations: maximumRepeatedEscalations,
            lockoutAllowed: lockoutAllowed,
        )
    }
}

private struct RecoveryPayload: Codable {
    let eligibleAfterSeconds: TimeInterval
    let latestTypicalSeconds: TimeInterval
    let suggestedDurationMinSeconds: TimeInterval
    let suggestedDurationMaxSeconds: TimeInterval
    let requiredMovementDeferrals: Int
    let maximumOffersPerSession: Int

    init(value: RecoveryConfiguration) {
        eligibleAfterSeconds = value.eligibleAfterSeconds
        latestTypicalSeconds = value.latestTypicalSeconds
        suggestedDurationMinSeconds = value.suggestedDurationMinSeconds
        suggestedDurationMaxSeconds = value.suggestedDurationMaxSeconds
        requiredMovementDeferrals = value.requiredMovementDeferrals
        maximumOffersPerSession = value.maximumOffersPerSession
    }

    func value() throws -> RecoveryConfiguration {
        try RecoveryConfiguration(
            eligibleAfterSeconds: eligibleAfterSeconds,
            latestTypicalSeconds: latestTypicalSeconds,
            suggestedDurationMinSeconds: suggestedDurationMinSeconds,
            suggestedDurationMaxSeconds: suggestedDurationMaxSeconds,
            requiredMovementDeferrals: requiredMovementDeferrals,
            maximumOffersPerSession: maximumOffersPerSession,
        )
    }
}
