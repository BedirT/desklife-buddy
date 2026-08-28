import Foundation

/// Codable timing for one custom opportunity, kept separate from engine configuration storage.
public struct OpportunityTiming: Codable, Equatable, Sendable {
    public let softDueSeconds: TimeInterval
    public let targetSeconds: TimeInterval
    public let latestPreferredSeconds: TimeInterval
    public let durationOptionsSeconds: [TimeInterval]

    /// Creates a finite, positive, ordered opportunity window without limiting neutral extremes.
    public init(
        softDueSeconds: TimeInterval,
        targetSeconds: TimeInterval,
        latestPreferredSeconds: TimeInterval,
        durationOptionsSeconds: [TimeInterval],
    ) throws {
        let values = [softDueSeconds, targetSeconds, latestPreferredSeconds] + durationOptionsSeconds
        guard !durationOptionsSeconds.isEmpty,
              values.allSatisfy({ $0.isFinite && $0 > 0 })
        else {
            throw AppPreferencesValidationError.nonFiniteOrNonPositiveTiming
        }
        guard softDueSeconds <= targetSeconds, targetSeconds <= latestPreferredSeconds else {
            throw AppPreferencesValidationError.invalidOpportunityWindow
        }

        self.softDueSeconds = softDueSeconds
        self.targetSeconds = targetSeconds
        self.latestPreferredSeconds = latestPreferredSeconds
        self.durationOptionsSeconds = durationOptionsSeconds
    }

    /// Decodes persisted custom timing through the same validation as an interactive edit.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            softDueSeconds: container.decode(TimeInterval.self, forKey: .softDueSeconds),
            targetSeconds: container.decode(TimeInterval.self, forKey: .targetSeconds),
            latestPreferredSeconds: container.decode(TimeInterval.self, forKey: .latestPreferredSeconds),
            durationOptionsSeconds: container.decode([TimeInterval].self, forKey: .durationOptionsSeconds),
        )
    }

    var opportunitySchedule: OpportunitySchedule {
        do {
            return try OpportunitySchedule(
                softDueSeconds: softDueSeconds,
                targetSeconds: targetSeconds,
                latestPreferredSeconds: latestPreferredSeconds,
                durationOptionsSeconds: durationOptionsSeconds,
            )
        } catch {
            preconditionFailure("Validated custom timing could not form an opportunity schedule")
        }
    }
}

/// The two independently scheduled windows supplied by a user choosing Custom.
public struct CustomProtocolTiming: Codable, Equatable, Sendable {
    public let visual: OpportunityTiming
    public let movement: OpportunityTiming

    /// Groups already validated visual and movement timing without adding policy limits.
    public init(visual: OpportunityTiming, movement: OpportunityTiming) {
        self.visual = visual
        self.movement = movement
    }

    /// Replaces only schedules on a caller-resolved configuration and preserves every other field.
    public func applying(to base: ProtocolConfiguration) -> ProtocolConfiguration {
        ProtocolConfiguration(
            visual: visual.opportunitySchedule,
            movement: movement.opportunitySchedule,
            activityEstimator: base.activityEstimator,
            delivery: base.delivery,
            recovery: base.recovery,
        )
    }
}

/// Normative profile identifiers and the one explicit user-authored schedule choice.
public enum ScheduleProfile: Equatable, Sendable {
    case gentle
    case balanced
    case frequentMovement
    case researchInformedHighFrequency
    case custom(CustomProtocolTiming)

    /// Stable identifier for App-owned built-in resolution and runtime state.
    public var protocolProfileID: ProtocolProfileID {
        switch self {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        case .researchInformedHighFrequency: .researchInformedHighFrequency
        case .custom: .custom
        }
    }
}

extension ScheduleProfile: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case customTiming
    }

    private enum Kind: String, Codable {
        case gentle
        case balanced
        case frequentMovement = "frequent_movement"
        case researchInformedHighFrequency = "research_informed_high_frequency"
        case custom
    }

    /// Decodes the explicit stable tag rather than compiler-synthesized enum representation.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .gentle: self = .gentle
        case .balanced: self = .balanced
        case .frequentMovement: self = .frequentMovement
        case .researchInformedHighFrequency: self = .researchInformedHighFrequency
        case .custom: self = try .custom(container.decode(CustomProtocolTiming.self, forKey: .customTiming))
        }
    }

    /// Encodes a stable kind tag and includes custom timing only for the Custom choice.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .gentle:
            try container.encode(Kind.gentle, forKey: .kind)
        case .balanced:
            try container.encode(Kind.balanced, forKey: .kind)
        case .frequentMovement:
            try container.encode(Kind.frequentMovement, forKey: .kind)
        case .researchInformedHighFrequency:
            try container.encode(Kind.researchInformedHighFrequency, forKey: .kind)
        case let .custom(timing):
            try container.encode(Kind.custom, forKey: .kind)
            try container.encode(timing, forKey: .customTiming)
        }
    }
}

/// Durable schedule selections that remain separate from live protocol clocks.
public struct SchedulePreferences: Codable, Equatable, Sendable {
    public let profile: ScheduleProfile
    public let headsUpEnabled: Bool
    public let workingHoursOnly: Bool

    /// Creates explicit schedule choices without inventing a working-hours range.
    public init(
        profile: ScheduleProfile = .balanced,
        headsUpEnabled: Bool = true,
        workingHoursOnly: Bool = true,
    ) {
        self.profile = profile
        self.headsUpEnabled = headsUpEnabled
        self.workingHoursOnly = workingHoursOnly
    }
}
