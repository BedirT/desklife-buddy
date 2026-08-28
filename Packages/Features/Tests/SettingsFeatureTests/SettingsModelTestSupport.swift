import Domain
import Foundation
@testable import SettingsFeature

enum TestFailure: Error { case load, save }
enum TestClientOutcome { case applied, temporarilyBusy }

final class TestSettingsClient: SettingsFeatureClientProtocol {
    var preferences: AppPreferences
    var configuration: ProtocolConfiguration
    var loadError: (any Error)?
    var results: [Result<TestClientOutcome, any Error>]
    private(set) var applyCount = 0

    init(
        preferences: AppPreferences,
        loadError: (any Error)? = nil,
        results: [Result<TestClientOutcome, any Error>] = [],
    ) {
        self.preferences = preferences
        let catalog = fixtureCatalog()
        let base = catalog.configuration(for: preferences.schedule.profile.protocolProfileID) ?? catalog.balanced
        configuration = preferences.protocolConfiguration(applyingTo: base)
        self.loadError = loadError
        self.results = results
    }

    func loadSettings() async throws -> SettingsFeatureState {
        if let loadError { throw loadError }
        return SettingsFeatureState(preferences: preferences, configuration: configuration)
    }

    func applySettings(_ mutation: SettingsFeatureMutation) async throws -> SettingsApplyResult {
        applyCount += 1
        let result = results.isEmpty ? .success(.applied) : results.removeFirst()
        switch try result.get() {
        case .applied:
            let state = mergedState(for: mutation)
            preferences = state.preferences
            configuration = state.configuration
            return .applied(state)
        case .temporarilyBusy:
            return .temporarilyBusy
        }
    }

    func mergedState(for mutation: SettingsFeatureMutation) -> SettingsFeatureState {
        let merged: (preferences: AppPreferences, base: ProtocolConfiguration) = switch mutation {
        case .setScheduleProfile, .setHeadsUpEnabled, .setWorkingHoursOnly:
            mergedScheduleState(for: mutation)
        case .setPreferredMovement, .setShowsQuickMovementOption,
             .setIncludesBreathingContent, .setStandingDeskModeEnabled:
            mergedContentState(for: mutation)
        case .addExcludedApplicationBundleID, .removeExcludedApplicationBundleID,
             .setWaitsForLowFrictionMoment, .setPresentationModeSuppressionEnabled:
            mergedContextState(for: mutation)
        case .setAccessibleBreakPresentation, .setStaticOverlayBrightness,
             .setTimerAnnouncements, .setSeatedContentFirst:
            mergedAccessibilityState(for: mutation)
        case let .setHistoryRetention(policy):
            (preferences.applying(.setHistoryRetention(policy)), configuration)
        case .setNotificationsEnabled, .setLaunchAtLoginEnabled, .reconcileLaunchAtLoginEnabled:
            mergedIntegrationsState(for: mutation)
        }
        return SettingsFeatureState(
            preferences: merged.preferences,
            configuration: merged.preferences.protocolConfiguration(applyingTo: merged.base),
        )
    }

    private func mergedScheduleState(
        for mutation: SettingsFeatureMutation,
    ) -> (AppPreferences, ProtocolConfiguration) {
        let schedule: SchedulePreferences
        let base: ProtocolConfiguration
        switch mutation {
        case let .setScheduleProfile(profile, baseConfiguration):
            schedule = SchedulePreferences(
                profile: profile,
                headsUpEnabled: preferences.schedule.headsUpEnabled,
                workingHoursOnly: preferences.schedule.workingHoursOnly,
            )
            base = baseConfiguration
        case let .setHeadsUpEnabled(enabled):
            schedule = SchedulePreferences(
                profile: preferences.schedule.profile,
                headsUpEnabled: enabled,
                workingHoursOnly: preferences.schedule.workingHoursOnly,
            )
            base = configuration
        case let .setWorkingHoursOnly(enabled):
            schedule = SchedulePreferences(
                profile: preferences.schedule.profile,
                headsUpEnabled: preferences.schedule.headsUpEnabled,
                workingHoursOnly: enabled,
            )
            base = configuration
        default:
            preconditionFailure("Expected schedule mutation")
        }
        return (preferences.applying(.setSchedule(schedule)), base)
    }

    private func mergedContentState(
        for mutation: SettingsFeatureMutation,
    ) -> (AppPreferences, ProtocolConfiguration) {
        let content: BreakContentPreferences
        switch mutation {
        case let .setPreferredMovement(preference):
            content = mergedContent(preferredMovement: preference)
        case let .setShowsQuickMovementOption(enabled):
            content = mergedContent(showsQuickMovementOption: enabled)
        case let .setIncludesBreathingContent(enabled):
            content = mergedContent(includesBreathingContent: enabled)
        case let .setStandingDeskModeEnabled(enabled):
            content = mergedContent(standingDeskModeEnabled: enabled)
        default:
            preconditionFailure("Expected content mutation")
        }
        return (preferences.applying(.setContent(content)), configuration)
    }

    private func mergedContextState(
        for mutation: SettingsFeatureMutation,
    ) -> (AppPreferences, ProtocolConfiguration) {
        let context: ContextPreferences
        switch mutation {
        case let .addExcludedApplicationBundleID(bundleID):
            context = mergedContext(
                excludedApplicationBundleIDs: preferences.context.excludedApplicationBundleIDs + [bundleID],
            )
        case let .removeExcludedApplicationBundleID(bundleID):
            context = mergedContext(
                excludedApplicationBundleIDs: preferences.context.excludedApplicationBundleIDs.filter {
                    $0 != bundleID
                },
            )
        case let .setWaitsForLowFrictionMoment(enabled):
            context = mergedContext(waitsForLowFrictionMoment: enabled)
        case let .setPresentationModeSuppressionEnabled(enabled):
            context = mergedContext(presentationModeSuppressionEnabled: enabled)
        default:
            preconditionFailure("Expected context mutation")
        }
        return (preferences.applying(.setContext(context)), configuration)
    }

    private func mergedAccessibilityState(
        for mutation: SettingsFeatureMutation,
    ) -> (AppPreferences, ProtocolConfiguration) {
        let accessibility: AccessibilityPreferences
        switch mutation {
        case let .setAccessibleBreakPresentation(presentation):
            accessibility = mergedAccessibility(presentation: presentation)
        case let .setStaticOverlayBrightness(brightness):
            accessibility = mergedAccessibility(staticOverlayBrightness: brightness)
        case let .setTimerAnnouncements(preference):
            accessibility = mergedAccessibility(timerAnnouncements: preference)
        case let .setSeatedContentFirst(enabled):
            accessibility = mergedAccessibility(seatedContentFirst: enabled)
        default:
            preconditionFailure("Expected accessibility mutation")
        }
        return (preferences.applying(.setAccessibility(accessibility)), configuration)
    }

    private func mergedIntegrationsState(
        for mutation: SettingsFeatureMutation,
    ) -> (AppPreferences, ProtocolConfiguration) {
        let current = preferences.integrations
        let integrations: IntegrationPreferences
        switch mutation {
        case let .setNotificationsEnabled(enabled):
            integrations = IntegrationPreferences(
                notificationsEnabled: enabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: current.launchAtLoginEnabled,
            )
        case let .setLaunchAtLoginEnabled(enabled),
             let .reconcileLaunchAtLoginEnabled(enabled):
            integrations = IntegrationPreferences(
                notificationsEnabled: current.notificationsEnabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: enabled,
            )
        default:
            preconditionFailure("Expected integrations mutation")
        }
        return (preferences.applying(.setIntegrations(integrations)), configuration)
    }

    private func mergedContent(
        preferredMovement: PreferredMovementContent? = nil,
        showsQuickMovementOption: Bool? = nil,
        includesBreathingContent: Bool? = nil,
        standingDeskModeEnabled: Bool? = nil,
    ) -> BreakContentPreferences {
        let current = preferences.content
        return BreakContentPreferences(
            preferredMovement: preferredMovement ?? current.preferredMovement,
            showsQuickMovementOption: showsQuickMovementOption ?? current.showsQuickMovementOption,
            includesBreathingContent: includesBreathingContent ?? current.includesBreathingContent,
            standingDeskModeEnabled: standingDeskModeEnabled ?? current.standingDeskModeEnabled,
        )
    }

    private func mergedContext(
        excludedApplicationBundleIDs: [String]? = nil,
        waitsForLowFrictionMoment: Bool? = nil,
        presentationModeSuppressionEnabled: Bool? = nil,
    ) -> ContextPreferences {
        let current = preferences.context
        do {
            return try ContextPreferences(
                excludedApplicationBundleIDs: excludedApplicationBundleIDs
                    ?? current.excludedApplicationBundleIDs,
                waitsForLowFrictionMoment: waitsForLowFrictionMoment
                    ?? current.waitsForLowFrictionMoment,
                presentationModeSuppressionEnabled: presentationModeSuppressionEnabled
                    ?? current.presentationModeSuppressionEnabled,
                idleBehavior: current.idleBehavior,
            )
        } catch {
            preconditionFailure("Existing valid context failed to merge")
        }
    }

    private func mergedAccessibility(
        presentation: AccessibleBreakPresentation? = nil,
        staticOverlayBrightness: Double? = nil,
        timerAnnouncements: TimerAnnouncementPreference? = nil,
        seatedContentFirst: Bool? = nil,
    ) -> AccessibilityPreferences {
        let current = preferences.accessibility
        do {
            return try AccessibilityPreferences(
                presentation: presentation ?? current.presentation,
                staticOverlayBrightness: staticOverlayBrightness ?? current.staticOverlayBrightness,
                timerAnnouncements: timerAnnouncements ?? current.timerAnnouncements,
                seatedContentFirst: seatedContentFirst ?? current.seatedContentFirst,
            )
        } catch {
            preconditionFailure("Existing valid accessibility failed to merge")
        }
    }
}

final class SuspendedSettingsClient: SettingsFeatureClientProtocol {
    private var preferences: AppPreferences
    private var configuration: ProtocolConfiguration
    private var applyingContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<TestClientOutcome, Never>?
    private(set) var applyCount = 0

    init(preferences: AppPreferences) {
        self.preferences = preferences
        configuration = preferences.protocolConfiguration(applyingTo: fixtureCatalog().balanced)
    }

    func loadSettings() async throws -> SettingsFeatureState {
        SettingsFeatureState(preferences: preferences, configuration: configuration)
    }

    func applySettings(_ mutation: SettingsFeatureMutation) async throws -> SettingsApplyResult {
        applyCount += 1
        applyingContinuation?.resume()
        applyingContinuation = nil
        switch await withCheckedContinuation({ resultContinuation = $0 }) {
        case .applied:
            let merger = TestSettingsClient(preferences: preferences)
            merger.configuration = configuration
            let state = merger.mergedState(for: mutation)
            preferences = state.preferences
            configuration = state.configuration
            return .applied(state)
        case .temporarilyBusy:
            return .temporarilyBusy
        }
    }

    func waitUntilApplying() async {
        if applyCount > 0 { return }
        await withCheckedContinuation { applyingContinuation = $0 }
    }

    func finish(with outcome: TestClientOutcome) {
        resultContinuation?.resume(returning: outcome)
        resultContinuation = nil
    }
}

final class ReloadStates {
    private var states: [SettingsFeatureState]
    init(_ states: [SettingsFeatureState]) { self.states = states }
    func next() -> SettingsFeatureState { states.removeFirst() }
}

func fixtureCatalog() -> SettingsScheduleCatalog {
    do {
        return try .fixture()
    } catch {
        preconditionFailure("Settings test catalog failed validation")
    }
}

func customTiming(visual: Double, movement: Double) throws -> CustomProtocolTiming {
    try CustomProtocolTiming(
        visual: OpportunityTiming(
            softDueSeconds: (visual - 5) * 60,
            targetSeconds: visual * 60,
            latestPreferredSeconds: (visual + 5) * 60,
            durationOptionsSeconds: [20],
        ),
        movement: OpportunityTiming(
            softDueSeconds: (movement - 5) * 60,
            targetSeconds: movement * 60,
            latestPreferredSeconds: (movement + 5) * 60,
            durationOptionsSeconds: [300, 120],
        ),
    )
}

func nonDefaultPreferences() throws -> AppPreferences {
    try AppPreferences(
        schedule: SchedulePreferences(),
        historyRetention: .ninetyDays,
        content: BreakContentPreferences(
            preferredMovement: .seatedActive,
            showsQuickMovementOption: false,
            includesBreathingContent: true,
            standingDeskModeEnabled: true,
        ),
        context: ContextPreferences(
            excludedApplicationBundleIDs: ["com.example.Editor"],
            waitsForLowFrictionMoment: true,
            presentationModeSuppressionEnabled: false,
        ),
        accessibility: AccessibilityPreferences(
            presentation: .textOnly,
            staticOverlayBrightness: 0.7,
            timerAnnouncements: .none,
            seatedContentFirst: true,
        ),
        integrations: IntegrationPreferences(notificationsEnabled: true),
    )
}

extension SettingsScheduleCatalog {
    static func fixture(
        effectivelyDisabledThresholdSeconds: TimeInterval = 86400,
    ) throws -> SettingsScheduleCatalog {
        try SettingsScheduleCatalog(
            gentle: fixtureConfiguration(visual: 30, movement: 75),
            balanced: fixtureConfiguration(visual: 25, movement: 60),
            frequentMovement: fixtureConfiguration(visual: 25, movement: 35),
            researchInformedHighFrequency: fixtureConfiguration(visual: 20, movement: 30),
            effectivelyDisabledThresholdSeconds: effectivelyDisabledThresholdSeconds,
        )
    }
}

func fixtureConfiguration(visual: Double, movement: Double) throws -> ProtocolConfiguration {
    try ProtocolConfiguration(
        visual: OpportunitySchedule(
            softDueSeconds: (visual - 5) * 60,
            targetSeconds: visual * 60,
            latestPreferredSeconds: (visual + 5) * 60,
            durationOptionsSeconds: [20],
        ),
        movement: OpportunitySchedule(
            softDueSeconds: (movement - 5) * 60,
            targetSeconds: movement * 60,
            latestPreferredSeconds: (movement + 5) * 60,
            durationOptionsSeconds: [300, 120],
        ),
        activityEstimator: ActivityEstimatorConfiguration(
            recentInputWindowSeconds: 60,
            longIdleResetSeconds: 300,
            wakeUnlockGraceSeconds: 90,
        ),
        delivery: OpportunityDeliveryConfiguration(
            waitForLowFrictionMoment: true,
            mergeWindowSeconds: 300,
            headsUpDefault: true,
            headsUpSecondsBeforeTarget: 45,
            snoozeOptionsSeconds: [300],
            maximumRepeatedEscalations: 1,
            lockoutAllowed: false,
        ),
    )
}
