import Domain
import Foundation
import Observation

@Observable
public final class SettingsFeatureModel {
    public enum Phase: Equatable { case loading, ready, loadFailed }
    public enum ApplyState: Equatable { case idle, applying, temporarilyBusy, failed }

    public internal(set) var phase: Phase = .loading
    public internal(set) var applyState: ApplyState = .idle
    public internal(set) var preferences: AppPreferences?
    public internal(set) var appliedConfiguration: ProtocolConfiguration?
    public internal(set) var retainedHistoryCount = 0
    public var selectedSection: SettingsSection = .schedule
    public var isAdvancedScheduleExpanded = false
    public internal(set) var customDraft: CustomScheduleDraft
    public internal(set) var isCustomEditing = false
    public internal(set) var customFieldTexts: [CustomScheduleField: String]
    public internal(set) var selectedContentLibraryItemID: String?
    public internal(set) var isContentLibraryPresented = false
    public internal(set) var isExportDisclosurePresented = false
    public internal(set) var selectedExportFormat: HistoryExportFormat = .csv
    public internal(set) var selectedExportFields = Set(HistoryExportField.allCases)
    public internal(set) var isExportColumnsExpanded = false
    public internal(set) var pendingDestructiveOperation: SettingsDestructiveOperation?
    public internal(set) var privacyOperation: SettingsPrivacyOperation = .idle

    let client: SettingsFeatureClient
    let catalog: SettingsScheduleCatalog
    var retryMutation: SettingsFeatureMutation?
    var hasRetainedCustomDraft = false
    var invalidCustomFields: Set<CustomScheduleField> = []
    var retryPrivacyAction: SettingsPrivacyAction?

    public init(client: SettingsFeatureClient, catalog: SettingsScheduleCatalog) {
        self.client = client
        self.catalog = catalog
        let draft = CustomScheduleDraft(configuration: catalog.balanced)
        customDraft = draft
        customFieldTexts = Self.fieldTexts(for: draft)
    }

    public convenience init(client: any SettingsFeatureClientProtocol, catalog: SettingsScheduleCatalog) {
        self.init(
            client: SettingsFeatureClient(
                load: { try await client.loadSettings() },
                apply: { try await client.applySettings($0) },
            ),
            catalog: catalog,
        )
    }

    public var operationState: ApplyState {
        get { applyState }
        set { applyState = newValue }
    }

    public var selectedScheduleChoice: SettingsScheduleChoice? {
        guard let profile = preferences?.schedule.profile else { return nil }
        return SettingsScheduleChoice(profileID: profile.protocolProfileID)
    }

    public var selectedProfileID: ProtocolProfileID? {
        selectedScheduleChoice?.protocolProfileID
    }

    public var selectedConfiguration: ProtocolConfiguration? {
        appliedConfiguration
    }

    public var breakContentPreferences: BreakContentPreferences? {
        preferences?.content
    }

    public var excludedApplicationBundleIDs: [String] {
        preferences?.context.excludedApplicationBundleIDs ?? []
    }

    public var idleBehavior: IdlePreference? {
        preferences?.context.idleBehavior
    }

    public var visualTimingSummary: String? {
        guard let schedule = selectedConfiguration?.visual else { return nil }
        return SettingsFeatureL10n.visualTimingSummary(
            intervalMinutes: settingsDisplayNumber(settingsMinutes(from: schedule.targetSeconds)),
            durationSeconds: settingsDisplayNumber(schedule.durationOptionsSeconds[0]),
        )
    }

    public var movementTimingSummary: String? {
        guard let schedule = selectedConfiguration?.movement else { return nil }
        return SettingsFeatureL10n.movementTimingSummary(
            intervalMinutes: settingsDisplayNumber(settingsMinutes(from: schedule.targetSeconds)),
            durationMinutes: settingsDisplayNumber(settingsMinutes(from: schedule.durationOptionsSeconds[0])),
        )
    }

    public var headsUpSummary: String? {
        guard let seconds = selectedConfiguration?.delivery.headsUpSecondsBeforeTarget else { return nil }
        return SettingsFeatureL10n.headsUpSummary(seconds: settingsDisplayNumber(seconds))
    }

    public var customValidation: CustomScheduleValidation {
        guard invalidCustomFields.isEmpty else { return .invalidNumber }
        guard customDraft.values.allSatisfy({ $0 != nil }) else { return .incomplete }
        guard customDraft.values.compactMap(\.self).allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return .nonFiniteOrNonPositive
        }
        guard customDraft.convertedMinuteValuesAreFinite else { return .valueTooLarge }
        return (try? customDraft.timing()) == nil ? .invalidWindow : .valid
    }

    public var customDraftValidation: CustomDraftValidation {
        customValidation == .valid ? .valid : .invalid
    }

    public func customIssue(for field: CustomScheduleField) -> CustomScheduleFieldIssue? {
        guard !invalidCustomFields.contains(field) else { return .invalidNumber }
        guard let value = customDraft.value(for: field) else { return .required }
        guard value.isFinite, value > 0 else { return .positiveFinite }
        guard !field.isMinuteValue || (value * 60).isFinite else { return .valueTooLarge }
        guard customValidation == .invalidWindow else { return nil }
        switch field {
        case .visualSoftDue, .visualTarget, .visualLatestPreferred:
            return customDraft.visualWindowIsOrdered ? nil : .orderedWindow
        case .movementSoftDue, .movementTarget, .movementLatestPreferred:
            return customDraft.movementWindowIsOrdered ? nil : .orderedWindow
        case .visualDuration, .movementSuggestedDuration, .movementQuickDuration:
            return nil
        }
    }

    public var customAdvisory: CustomScheduleAdvisory? {
        for advisory in scheduleAdvisories {
            switch advisory {
            case .veryFrequent: return .veryFrequent
            case .effectivelyDisabled: return .effectivelyDisabled
            }
        }
        return nil
    }

    public var canApplyCustom: Bool {
        phase == .ready && applyState != .applying && customValidation == .valid
    }

    public var scheduleAdvisories: [ScheduleAdvisory] {
        guard customValidation == .valid,
              let visual = customDraft.secondsValue(for: .visualTarget),
              let movement = customDraft.secondsValue(for: .movementTarget)
        else { return [] }
        var frequent: Set<OpportunityType> = []
        var disabled: Set<OpportunityType> = []
        if visual < catalog.researchInformedHighFrequency.visual.targetSeconds { frequent.insert(.visual) }
        if movement < catalog.researchInformedHighFrequency.movement.targetSeconds { frequent.insert(.movement) }
        if visual >= catalog.effectivelyDisabledAfterActiveUseSeconds { disabled.insert(.visual) }
        if movement >= catalog.effectivelyDisabledAfterActiveUseSeconds { disabled.insert(.movement) }
        var result: [ScheduleAdvisory] = []
        if !frequent.isEmpty { result.append(.veryFrequent(frequent)) }
        if !disabled.isEmpty { result.append(.effectivelyDisabled(disabled)) }
        return result
    }

    public var canRetryLastChange: Bool { retryMutation != nil && applyState != .applying }
    public var controlsEnabled: Bool {
        phase == .ready && applyState != .applying && !privacyOperation.isInProgress
    }

    public var hasRetainedHistory: Bool { retainedHistoryCount > 0 }

    public func customFieldText(for field: CustomScheduleField) -> String {
        customFieldTexts[field] ?? ""
    }

    func replaceCustomDraft(_ draft: CustomScheduleDraft) {
        customDraft = draft
        customFieldTexts = Self.fieldTexts(for: draft)
        invalidCustomFields = []
    }

    private static func fieldTexts(for draft: CustomScheduleDraft) -> [CustomScheduleField: String] {
        Dictionary(uniqueKeysWithValues: CustomScheduleField.allCases.map { field in
            (field, draft.value(for: field).map(settingsDisplayNumber) ?? "")
        })
    }
}

private extension CustomScheduleDraft {
    var visualWindowIsOrdered: Bool {
        guard let softDue = secondsValue(for: .visualSoftDue),
              let target = secondsValue(for: .visualTarget),
              let latestPreferred = secondsValue(for: .visualLatestPreferred)
        else { return true }
        return softDue <= target && target <= latestPreferred
    }

    var movementWindowIsOrdered: Bool {
        guard let softDue = secondsValue(for: .movementSoftDue),
              let target = secondsValue(for: .movementTarget),
              let latestPreferred = secondsValue(for: .movementLatestPreferred)
        else { return true }
        return softDue <= target && target <= latestPreferred
    }
}

extension SettingsFeatureModel {
    func optimisticState(for mutation: SettingsFeatureMutation) -> SettingsFeatureState? {
        guard let preferences, let appliedConfiguration else { return nil }
        let merged: (preferences: AppPreferences, base: ProtocolConfiguration)? = switch mutation {
        case .setScheduleProfile, .setHeadsUpEnabled, .setWorkingHoursOnly:
            optimisticScheduleState(for: mutation, preferences: preferences, base: appliedConfiguration)
        case .setPreferredMovement, .setShowsQuickMovementOption,
             .setIncludesBreathingContent, .setStandingDeskModeEnabled:
            optimisticContentState(for: mutation, preferences: preferences, base: appliedConfiguration)
        case .addExcludedApplicationBundleID, .removeExcludedApplicationBundleID,
             .setWaitsForLowFrictionMoment, .setPresentationModeSuppressionEnabled:
            optimisticContextState(for: mutation, preferences: preferences, base: appliedConfiguration)
        case .setAccessibleBreakPresentation, .setStaticOverlayBrightness,
             .setTimerAnnouncements, .setSeatedContentFirst:
            optimisticAccessibilityState(for: mutation, preferences: preferences, base: appliedConfiguration)
        case .setHistoryRetention:
            optimisticPrivacyState(for: mutation, preferences: preferences, base: appliedConfiguration)
        case .setNotificationsEnabled, .setLaunchAtLoginEnabled, .reconcileLaunchAtLoginEnabled:
            optimisticIntegrationsState(for: mutation, preferences: preferences, base: appliedConfiguration)
        }
        guard let merged else { return nil }
        return SettingsFeatureState(
            preferences: merged.preferences,
            configuration: merged.preferences.protocolConfiguration(applyingTo: merged.base),
            retainedHistoryCount: retainedHistoryCount,
        )
    }

    private func optimisticScheduleState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        let schedule: SchedulePreferences
        let mergedBase: ProtocolConfiguration
        switch mutation {
        case let .setScheduleProfile(profile, baseConfiguration):
            schedule = SchedulePreferences(
                profile: profile,
                headsUpEnabled: preferences.schedule.headsUpEnabled,
                workingHoursOnly: preferences.schedule.workingHoursOnly,
            )
            mergedBase = baseConfiguration
        case let .setHeadsUpEnabled(enabled):
            schedule = SchedulePreferences(
                profile: preferences.schedule.profile,
                headsUpEnabled: enabled,
                workingHoursOnly: preferences.schedule.workingHoursOnly,
            )
            mergedBase = base
        case let .setWorkingHoursOnly(enabled):
            schedule = SchedulePreferences(
                profile: preferences.schedule.profile,
                headsUpEnabled: preferences.schedule.headsUpEnabled,
                workingHoursOnly: enabled,
            )
            mergedBase = base
        default:
            return nil
        }
        return (preferences.applying(.setSchedule(schedule)), mergedBase)
    }

    private func optimisticContentState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        let current = preferences.content
        let content: BreakContentPreferences
        switch mutation {
        case let .setPreferredMovement(preference):
            content = BreakContentPreferences(
                preferredMovement: preference,
                showsQuickMovementOption: current.showsQuickMovementOption,
                includesBreathingContent: current.includesBreathingContent,
                standingDeskModeEnabled: current.standingDeskModeEnabled,
            )
        case let .setShowsQuickMovementOption(enabled):
            content = BreakContentPreferences(
                preferredMovement: current.preferredMovement,
                showsQuickMovementOption: enabled,
                includesBreathingContent: current.includesBreathingContent,
                standingDeskModeEnabled: current.standingDeskModeEnabled,
            )
        case let .setIncludesBreathingContent(enabled):
            content = BreakContentPreferences(
                preferredMovement: current.preferredMovement,
                showsQuickMovementOption: current.showsQuickMovementOption,
                includesBreathingContent: enabled,
                standingDeskModeEnabled: current.standingDeskModeEnabled,
            )
        case let .setStandingDeskModeEnabled(enabled):
            content = BreakContentPreferences(
                preferredMovement: current.preferredMovement,
                showsQuickMovementOption: current.showsQuickMovementOption,
                includesBreathingContent: current.includesBreathingContent,
                standingDeskModeEnabled: enabled,
            )
        default:
            return nil
        }
        return (preferences.applying(.setContent(content)), base)
    }

    private func optimisticContextState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        let context: ContextPreferences?
        switch mutation {
        case let .addExcludedApplicationBundleID(bundleID):
            context = contextPreferences(
                excludedApplicationBundleIDs: preferences.context.excludedApplicationBundleIDs + [bundleID],
            )
        case let .removeExcludedApplicationBundleID(bundleID):
            context = contextPreferences(
                excludedApplicationBundleIDs: preferences.context.excludedApplicationBundleIDs.filter {
                    $0 != bundleID
                },
            )
        case let .setWaitsForLowFrictionMoment(enabled):
            context = contextPreferences(waitsForLowFrictionMoment: enabled)
        case let .setPresentationModeSuppressionEnabled(enabled):
            context = contextPreferences(presentationModeSuppressionEnabled: enabled)
        default:
            return nil
        }
        guard let context else { return nil }
        return (preferences.applying(.setContext(context)), base)
    }

    private func optimisticAccessibilityState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        let accessibility: AccessibilityPreferences?
        switch mutation {
        case let .setAccessibleBreakPresentation(presentation):
            accessibility = try? accessibilityPreferences(presentation: presentation)
        case let .setStaticOverlayBrightness(brightness):
            accessibility = try? accessibilityPreferences(staticOverlayBrightness: brightness)
        case let .setTimerAnnouncements(preference):
            accessibility = try? accessibilityPreferences(timerAnnouncements: preference)
        case let .setSeatedContentFirst(enabled):
            accessibility = try? accessibilityPreferences(seatedContentFirst: enabled)
        default:
            return nil
        }
        guard let accessibility else { return nil }
        return (preferences.applying(.setAccessibility(accessibility)), base)
    }

    private func optimisticPrivacyState(
        for mutation: SettingsFeatureMutation,
        preferences: AppPreferences,
        base: ProtocolConfiguration,
    ) -> (AppPreferences, ProtocolConfiguration)? {
        guard case let .setHistoryRetention(policy) = mutation else { return nil }
        return (preferences.applying(.setHistoryRetention(policy)), base)
    }
}

func settingsDisplayNumber(_ value: Double) -> String {
    if value == 0 || (value.magnitude >= 0.01 && value.magnitude < 1_000_000_000) {
        return value.formatted(.number.grouping(.never).precision(.fractionLength(0 ... 2)))
    }
    return value.formatted(
        .number
            .notation(.scientific)
            .precision(.significantDigits(1 ... 4)),
    )
}
