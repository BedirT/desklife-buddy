import Domain
import Foundation
import Observation

public struct SettingsFeatureState: Equatable, Sendable {
    public let preferences: AppPreferences
    public let configuration: ProtocolConfiguration
    public let retainedHistoryCount: Int

    public init(
        preferences: AppPreferences,
        configuration: ProtocolConfiguration,
        retainedHistoryCount: Int = 0,
    ) {
        self.preferences = preferences
        self.configuration = configuration
        self.retainedHistoryCount = max(0, retainedHistoryCount)
    }
}

public enum SettingsFeatureMutation: Equatable, Sendable {
    case setScheduleProfile(ScheduleProfile, baseConfiguration: ProtocolConfiguration)
    case setHeadsUpEnabled(Bool)
    case setWorkingHoursOnly(Bool)
    case setPreferredMovement(PreferredMovementContent)
    case setShowsQuickMovementOption(Bool)
    case setIncludesBreathingContent(Bool)
    case setStandingDeskModeEnabled(Bool)
    case addExcludedApplicationBundleID(String)
    case removeExcludedApplicationBundleID(String)
    case setWaitsForLowFrictionMoment(Bool)
    case setPresentationModeSuppressionEnabled(Bool)
    case setAccessibleBreakPresentation(AccessibleBreakPresentation)
    case setStaticOverlayBrightness(Double)
    case setTimerAnnouncements(TimerAnnouncementPreference)
    case setSeatedContentFirst(Bool)
    case setHistoryRetention(HistoryRetentionPolicy)
    case setNotificationsEnabled(Bool)
    case setLaunchAtLoginEnabled(Bool)
    case reconcileLaunchAtLoginEnabled(Bool)
}

public enum SettingsApplyResult: Equatable, Sendable {
    case applied(SettingsFeatureState)
    case temporarilyBusy
}

public protocol SettingsFeatureClientProtocol {
    func loadSettings() async throws -> SettingsFeatureState
    func applySettings(_ mutation: SettingsFeatureMutation) async throws -> SettingsApplyResult
}

public struct SettingsFeatureClient {
    public var load: () async throws -> SettingsFeatureState
    public var apply: (SettingsFeatureMutation) async throws -> SettingsApplyResult
    public var exportHistory: (HistoryExportRequest) async throws -> SettingsHistoryExportResult
    public var deleteHistory: () async throws -> SettingsDestructiveResult
    public var resetAll: () async throws -> SettingsDestructiveResult

    public init(
        load: @escaping () async throws -> SettingsFeatureState,
        apply: @escaping (SettingsFeatureMutation) async throws -> SettingsApplyResult,
        exportHistory: @escaping (HistoryExportRequest) async throws -> SettingsHistoryExportResult = { _ in
            throw SettingsPrivacyClientError.unavailable
        },
        deleteHistory: @escaping () async throws -> SettingsDestructiveResult = {
            throw SettingsPrivacyClientError.unavailable
        },
        resetAll: @escaping () async throws -> SettingsDestructiveResult = {
            throw SettingsPrivacyClientError.unavailable
        },
    ) {
        self.load = load
        self.apply = apply
        self.exportHistory = exportHistory
        self.deleteHistory = deleteHistory
        self.resetAll = resetAll
    }
}

public enum SettingsSection: String, CaseIterable, Identifiable, Sendable {
    case schedule
    case breakContent
    case contextAndExclusions
    case accessibility
    case integrations
    case privacyAndData
    case whyTheseDefaults
    case safetyAndSupport
    public var id: Self { self }
}

public enum SettingsScheduleChoice: String, CaseIterable, Identifiable, Sendable {
    case gentle
    case balanced
    case frequentMovement
    case researchInformedHighFrequency
    case custom
    public var id: Self { self }

    public init(profileID: ProtocolProfileID) {
        switch profileID {
        case .gentle: self = .gentle
        case .balanced: self = .balanced
        case .frequentMovement: self = .frequentMovement
        case .researchInformedHighFrequency: self = .researchInformedHighFrequency
        case .custom: self = .custom
        }
    }

    public var protocolProfileID: ProtocolProfileID {
        switch self {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        case .researchInformedHighFrequency: .researchInformedHighFrequency
        case .custom: .custom
        }
    }

    public var scheduleProfile: ScheduleProfile? {
        switch self {
        case .gentle: .gentle
        case .balanced: .balanced
        case .frequentMovement: .frequentMovement
        case .researchInformedHighFrequency: .researchInformedHighFrequency
        case .custom: nil
        }
    }
}

public struct SettingsScheduleCatalog: Sendable {
    public enum ValidationError: Error { case invalidDisabledThreshold }

    public let gentle: ProtocolConfiguration
    public let balanced: ProtocolConfiguration
    public let frequentMovement: ProtocolConfiguration
    public let researchInformedHighFrequency: ProtocolConfiguration
    public let effectivelyDisabledAfterActiveUseSeconds: TimeInterval

    public init(
        gentle: ProtocolConfiguration,
        balanced: ProtocolConfiguration,
        frequentMovement: ProtocolConfiguration,
        researchInformedHighFrequency: ProtocolConfiguration,
        effectivelyDisabledAfterActiveUseSeconds: TimeInterval,
    ) throws {
        guard effectivelyDisabledAfterActiveUseSeconds.isFinite,
              effectivelyDisabledAfterActiveUseSeconds > 0
        else { throw ValidationError.invalidDisabledThreshold }
        self.gentle = gentle
        self.balanced = balanced
        self.frequentMovement = frequentMovement
        self.researchInformedHighFrequency = researchInformedHighFrequency
        self.effectivelyDisabledAfterActiveUseSeconds = effectivelyDisabledAfterActiveUseSeconds
    }

    public init(
        gentle: ProtocolConfiguration,
        balanced: ProtocolConfiguration,
        frequentMovement: ProtocolConfiguration,
        researchInformedHighFrequency: ProtocolConfiguration,
        effectivelyDisabledThresholdSeconds: TimeInterval,
    ) throws {
        try self.init(
            gentle: gentle,
            balanced: balanced,
            frequentMovement: frequentMovement,
            researchInformedHighFrequency: researchInformedHighFrequency,
            effectivelyDisabledAfterActiveUseSeconds: effectivelyDisabledThresholdSeconds,
        )
    }

    public func configuration(for choice: SettingsScheduleChoice) -> ProtocolConfiguration? {
        switch choice {
        case .gentle: gentle
        case .balanced: balanced
        case .frequentMovement: frequentMovement
        case .researchInformedHighFrequency: researchInformedHighFrequency
        case .custom: nil
        }
    }

    public func configuration(for profile: ProtocolProfileID) -> ProtocolConfiguration? {
        configuration(for: SettingsScheduleChoice(profileID: profile))
    }
}

public struct CustomScheduleDraft: Equatable, Sendable {
    public var visualSoftDueMinutes: Double?
    public var visualTargetMinutes: Double?
    public var visualLatestPreferredMinutes: Double?
    public var visualDurationSeconds: Double?
    public var movementSoftDueMinutes: Double?
    public var movementTargetMinutes: Double?
    public var movementLatestPreferredMinutes: Double?
    public var movementSuggestedDurationMinutes: Double?
    public var movementQuickDurationMinutes: Double?
    private var sourceSeconds: [CustomScheduleField: TimeInterval]
    private var editedFields: Set<CustomScheduleField> = []

    public var movementDurationMinutes: Double? { movementSuggestedDurationMinutes }

    init(configuration: ProtocolConfiguration) {
        self.init(visual: configuration.visual, movement: configuration.movement)
    }

    init(timing: CustomProtocolTiming) {
        self.init(visual: timing.visual, movement: timing.movement)
    }

    private init(visual: some ScheduleDisplayValues, movement: some ScheduleDisplayValues) {
        visualSoftDueMinutes = settingsMinutes(from: visual.softDueSeconds)
        visualTargetMinutes = settingsMinutes(from: visual.targetSeconds)
        visualLatestPreferredMinutes = settingsMinutes(from: visual.latestPreferredSeconds)
        visualDurationSeconds = visual.durationOptionsSeconds.first
        movementSoftDueMinutes = settingsMinutes(from: movement.softDueSeconds)
        movementTargetMinutes = settingsMinutes(from: movement.targetSeconds)
        movementLatestPreferredMinutes = settingsMinutes(from: movement.latestPreferredSeconds)
        movementSuggestedDurationMinutes = movement.durationOptionsSeconds.first.map(settingsMinutes(from:))
        movementQuickDurationMinutes = movement.durationOptionsSeconds.dropFirst().first.map(settingsMinutes(from:))
            ?? movement.durationOptionsSeconds.first.map(settingsMinutes(from:))
        sourceSeconds = [
            .visualSoftDue: visual.softDueSeconds,
            .visualTarget: visual.targetSeconds,
            .visualLatestPreferred: visual.latestPreferredSeconds,
            .visualDuration: visual.durationOptionsSeconds[0],
            .movementSoftDue: movement.softDueSeconds,
            .movementTarget: movement.targetSeconds,
            .movementLatestPreferred: movement.latestPreferredSeconds,
            .movementSuggestedDuration: movement.durationOptionsSeconds[0],
            .movementQuickDuration: movement.durationOptionsSeconds.dropFirst().first
                ?? movement.durationOptionsSeconds[0],
        ]
    }

    func timing() throws -> CustomProtocolTiming {
        guard let visualSoftDueMinutes,
              let visualTargetMinutes,
              let visualLatestPreferredMinutes,
              let visualDurationSeconds,
              let movementSoftDueMinutes,
              let movementTargetMinutes,
              let movementLatestPreferredMinutes,
              let movementSuggestedDurationMinutes,
              let movementQuickDurationMinutes
        else { throw CustomDraftError.incomplete }
        return try CustomProtocolTiming(
            visual: OpportunityTiming(
                softDueSeconds: seconds(for: .visualSoftDue, displayedValue: visualSoftDueMinutes),
                targetSeconds: seconds(for: .visualTarget, displayedValue: visualTargetMinutes),
                latestPreferredSeconds: seconds(
                    for: .visualLatestPreferred,
                    displayedValue: visualLatestPreferredMinutes,
                ),
                durationOptionsSeconds: [seconds(for: .visualDuration, displayedValue: visualDurationSeconds)],
            ),
            movement: OpportunityTiming(
                softDueSeconds: seconds(for: .movementSoftDue, displayedValue: movementSoftDueMinutes),
                targetSeconds: seconds(for: .movementTarget, displayedValue: movementTargetMinutes),
                latestPreferredSeconds: seconds(
                    for: .movementLatestPreferred,
                    displayedValue: movementLatestPreferredMinutes,
                ),
                durationOptionsSeconds: [
                    seconds(for: .movementSuggestedDuration, displayedValue: movementSuggestedDurationMinutes),
                    seconds(for: .movementQuickDuration, displayedValue: movementQuickDurationMinutes),
                ],
            ),
        )
    }

    var values: [Double?] {
        [
            visualSoftDueMinutes, visualTargetMinutes, visualLatestPreferredMinutes, visualDurationSeconds,
            movementSoftDueMinutes, movementTargetMinutes, movementLatestPreferredMinutes,
            movementSuggestedDurationMinutes, movementQuickDurationMinutes,
        ]
    }

    func value(for field: CustomScheduleField) -> Double? {
        switch field {
        case .visualSoftDue: visualSoftDueMinutes
        case .visualTarget: visualTargetMinutes
        case .visualLatestPreferred: visualLatestPreferredMinutes
        case .visualDuration: visualDurationSeconds
        case .movementSoftDue: movementSoftDueMinutes
        case .movementTarget: movementTargetMinutes
        case .movementLatestPreferred: movementLatestPreferredMinutes
        case .movementSuggestedDuration: movementSuggestedDurationMinutes
        case .movementQuickDuration: movementQuickDurationMinutes
        }
    }

    var convertedMinuteValuesAreFinite: Bool {
        CustomScheduleField.allCases
            .filter(\.isMinuteValue)
            .allSatisfy { field in
                !editedFields.contains(field) || value(for: field).map { ($0 * 60).isFinite } != false
            }
    }

    mutating func set(_ field: CustomScheduleField, to value: Double?) {
        switch field {
        case .visualSoftDue: visualSoftDueMinutes = value
        case .visualTarget: visualTargetMinutes = value
        case .visualLatestPreferred: visualLatestPreferredMinutes = value
        case .visualDuration: visualDurationSeconds = value
        case .movementSoftDue: movementSoftDueMinutes = value
        case .movementTarget: movementTargetMinutes = value
        case .movementLatestPreferred: movementLatestPreferredMinutes = value
        case .movementSuggestedDuration: movementSuggestedDurationMinutes = value
        case .movementQuickDuration: movementQuickDurationMinutes = value
        }
        editedFields.insert(field)
    }

    func secondsValue(for field: CustomScheduleField) -> TimeInterval? {
        guard let displayedValue = value(for: field) else { return nil }
        return seconds(for: field, displayedValue: displayedValue)
    }

    private func seconds(for field: CustomScheduleField, displayedValue: Double) -> TimeInterval {
        if !editedFields.contains(field), let exact = sourceSeconds[field] {
            return exact
        }
        return field.isMinuteValue ? displayedValue * 60 : displayedValue
    }
}

public enum CustomScheduleField: CaseIterable, Equatable, Hashable, Sendable {
    case visualSoftDue
    case visualTarget
    case visualLatestPreferred
    case visualDuration
    case movementSoftDue
    case movementTarget
    case movementLatestPreferred
    case movementSuggestedDuration
    case movementQuickDuration
}

extension CustomScheduleField {
    var isMinuteValue: Bool {
        switch self {
        case .visualDuration:
            false
        case .visualSoftDue, .visualTarget, .visualLatestPreferred,
             .movementSoftDue, .movementTarget, .movementLatestPreferred,
             .movementSuggestedDuration, .movementQuickDuration:
            true
        }
    }
}

public enum CustomScheduleFieldIssue: Equatable, Sendable {
    case required
    case invalidNumber
    case positiveFinite
    case valueTooLarge
    case orderedWindow
}

public enum CustomScheduleValidation: Equatable, Sendable {
    case valid
    case incomplete
    case invalidNumber
    case nonFiniteOrNonPositive
    case valueTooLarge
    case invalidWindow
}

public enum CustomDraftValidation: Equatable, Sendable { case valid, invalid }
public enum CustomScheduleAdvisory: Equatable, Sendable { case veryFrequent, effectivelyDisabled }

public enum ScheduleAdvisory: Equatable, Sendable {
    case veryFrequent(Set<OpportunityType>)
    case effectivelyDisabled(Set<OpportunityType>)
}

private enum CustomDraftError: Error { case incomplete }

private protocol ScheduleDisplayValues {
    var softDueSeconds: TimeInterval { get }
    var targetSeconds: TimeInterval { get }
    var latestPreferredSeconds: TimeInterval { get }
    var durationOptionsSeconds: [TimeInterval] { get }
}

extension OpportunitySchedule: ScheduleDisplayValues {}
extension OpportunityTiming: ScheduleDisplayValues {}

struct SettingsNumberParseStrategy: ParseStrategy {
    func parse(_ value: String) throws -> Double {
        try FloatingPointFormatStyle<Double>.number.parseStrategy.parse(value)
    }
}

func settingsMinutes(from seconds: TimeInterval) -> Double {
    let minutes = seconds / 60
    return minutes == 0 && seconds > 0 ? .leastNonzeroMagnitude : minutes
}
