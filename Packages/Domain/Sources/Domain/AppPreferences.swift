import Foundation

/// Validation failures for user-authored local preference values.
public enum AppPreferencesValidationError: Error, Equatable {
    case nonFiniteOrNonPositiveTiming
    case invalidOpportunityWindow
    case invalidBrightness
    case unsupportedFormatVersion(Int)
    case invalidBundleIdentifier(String)
}

/// Complete versioned local preference state, separate from runtime clocks and event facts.
public struct AppPreferences: Codable, Equatable, Sendable {
    public static let currentFormatVersion = 1

    public let formatVersion: Int
    public let schedule: SchedulePreferences
    public let historyRetention: HistoryRetentionPolicy
    public let content: BreakContentPreferences
    public let context: ContextPreferences
    public let accessibility: AccessibilityPreferences
    public let integrations: IntegrationPreferences

    /// Creates a versioned durable preference value without touching protocol lifecycle state.
    public init(
        schedule: SchedulePreferences = SchedulePreferences(),
        historyRetention: HistoryRetentionPolicy = .thirtyDays,
        content: BreakContentPreferences = BreakContentPreferences(),
        context: ContextPreferences = .defaults,
        accessibility: AccessibilityPreferences = .defaults,
        integrations: IntegrationPreferences = .disabled,
    ) {
        formatVersion = Self.currentFormatVersion
        self.schedule = schedule
        self.historyRetention = historyRetention
        self.content = content
        self.context = context
        self.accessibility = accessibility
        self.integrations = integrations
    }

    /// Current Balanced, local-only, privacy-minimal defaults.
    public static let defaults = AppPreferences()

    /// Applies preference overrides to App-owned generated timing without duplicating its constants.
    public func protocolConfiguration(applyingTo base: ProtocolConfiguration) -> ProtocolConfiguration {
        let scheduled: ProtocolConfiguration = switch schedule.profile {
        case let .custom(timing):
            timing.applying(to: base)
        case .gentle, .balanced, .frequentMovement, .researchInformedHighFrequency:
            base
        }
        return ProtocolConfiguration(
            visual: scheduled.visual,
            movement: scheduled.movement,
            activityEstimator: scheduled.activityEstimator,
            delivery: validatedDeliveryConfiguration(
                base: scheduled.delivery,
                waitForLowFrictionMoment: context.waitsForLowFrictionMoment,
                headsUpDefault: schedule.headsUpEnabled,
            ),
            recovery: scheduled.recovery,
        )
    }

    /// Decodes only the current durable format so migration remains an explicit App concern.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedVersion = try container.decode(Int.self, forKey: .formatVersion)
        guard decodedVersion == Self.currentFormatVersion else {
            throw AppPreferencesValidationError.unsupportedFormatVersion(decodedVersion)
        }
        formatVersion = decodedVersion
        schedule = try container.decode(SchedulePreferences.self, forKey: .schedule)
        historyRetention = try container.decode(HistoryRetentionPolicy.self, forKey: .historyRetention)
        content = try container.decode(BreakContentPreferences.self, forKey: .content)
        context = try container.decode(ContextPreferences.self, forKey: .context)
        accessibility = try container.decode(AccessibilityPreferences.self, forKey: .accessibility)
        integrations = try container.decode(IntegrationPreferences.self, forKey: .integrations)
    }

    /// Applies one explicit preference mutation and preserves every unrelated preference.
    public func applying(_ mutation: AppPreferencesMutation) -> AppPreferences {
        switch mutation {
        case let .setSchedule(schedule):
            replacing(schedule: schedule)
        case let .setHistoryRetention(policy):
            replacing(historyRetention: policy)
        case let .setContent(content):
            replacing(content: content)
        case let .setContext(context):
            replacing(context: context)
        case let .setAccessibility(accessibility):
            replacing(accessibility: accessibility)
        case let .setIntegrations(selection):
            replacing(integrations: selection)
        }
    }

    private func replacing(
        schedule: SchedulePreferences? = nil,
        historyRetention: HistoryRetentionPolicy? = nil,
        content: BreakContentPreferences? = nil,
        context: ContextPreferences? = nil,
        accessibility: AccessibilityPreferences? = nil,
        integrations: IntegrationPreferences? = nil,
    ) -> AppPreferences {
        AppPreferences(
            schedule: schedule ?? self.schedule,
            historyRetention: historyRetention ?? self.historyRetention,
            content: content ?? self.content,
            context: context ?? self.context,
            accessibility: accessibility ?? self.accessibility,
            integrations: integrations ?? self.integrations,
        )
    }
}

/// Narrow preference edits that cannot carry event or runtime-clock side effects.
public enum AppPreferencesMutation: Equatable, Sendable {
    case setSchedule(SchedulePreferences)
    case setHistoryRetention(HistoryRetentionPolicy)
    case setContent(BreakContentPreferences)
    case setContext(ContextPreferences)
    case setAccessibility(AccessibilityPreferences)
    case setIntegrations(IntegrationPreferences)
}

private func validatedDeliveryConfiguration(
    base: OpportunityDeliveryConfiguration,
    waitForLowFrictionMoment: Bool,
    headsUpDefault: Bool,
) -> OpportunityDeliveryConfiguration {
    do {
        return try OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: waitForLowFrictionMoment,
            mergeWindowSeconds: base.mergeWindowSeconds,
            headsUpDefault: headsUpDefault,
            headsUpSecondsBeforeTarget: base.headsUpSecondsBeforeTarget,
            snoozeOptionsSeconds: base.snoozeOptionsSeconds,
            maximumRepeatedEscalations: base.maximumRepeatedEscalations,
            lockoutAllowed: base.lockoutAllowed,
        )
    } catch {
        preconditionFailure("Normative delivery constants failed validation")
    }
}
