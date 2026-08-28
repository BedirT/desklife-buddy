import Domain
import Foundation
import SettingsFeature

struct SettingsFeatureAppAdapter {
    typealias ExportDestinationChooser = @MainActor (
        HistoryExportRequest,
        String,
    ) async throws -> URL?
    typealias ExportDataWriter = (Data, URL, Data.WritingOptions) throws -> Void

    let runtime: () -> ProtocolRuntime?
    let store: () -> SwiftDataSettingsStore?
    let chooseExportDestination: ExportDestinationChooser
    let writeExportData: ExportDataWriter
    let launchAtLoginMutationBoundary: LaunchAtLoginMutationBoundary?
    let authorizationMetadataResetBoundary: HeadsUpAuthorizationResetBoundary?

    init(
        runtime: @escaping () -> ProtocolRuntime?,
        store: @escaping () -> SwiftDataSettingsStore?,
        chooseExportDestination: @escaping ExportDestinationChooser,
        writeExportData: @escaping ExportDataWriter,
        launchAtLoginMutationBoundary: LaunchAtLoginMutationBoundary? = nil,
        authorizationMetadataResetBoundary: HeadsUpAuthorizationResetBoundary? = nil,
    ) {
        self.runtime = runtime
        self.store = store
        self.chooseExportDestination = chooseExportDestination
        self.writeExportData = writeExportData
        self.launchAtLoginMutationBoundary = launchAtLoginMutationBoundary
        self.authorizationMetadataResetBoundary = authorizationMetadataResetBoundary
    }

    var client: SettingsFeatureClient {
        SettingsFeatureClient(
            load: load,
            apply: apply,
            exportHistory: exportHistory,
            deleteHistory: deleteHistory,
            resetAll: resetAll,
        )
    }

    private func load() async throws -> SettingsFeatureState {
        let (_, store) = try dependencies()
        let resolved = try await store.loadResolvedPreferences()
        return try await featureState(resolved, store: store)
    }

    private func apply(_ mutation: SettingsFeatureMutation) async throws -> SettingsApplyResult {
        if case let .setLaunchAtLoginEnabled(enabled) = mutation,
           let launchAtLoginMutationBoundary
        {
            return try await launchAtLoginMutationBoundary.apply(enabled: enabled) {
                try await applyToRuntime(mutation)
            }
        }
        return try await applyToRuntime(mutation)
    }

    private func applyToRuntime(
        _ mutation: SettingsFeatureMutation,
    ) async throws -> SettingsApplyResult {
        let (runtime, _) = try dependencies()
        guard let currentPreferences = runtime.preferences else {
            throw SettingsPrivacyClientError.unavailable
        }
        let preferences = try updatedPreferences(currentPreferences, mutation: mutation)

        switch try await runtime.reconfigure(preferences) {
        case let .applied(acknowledgement):
            return .applied(featureState(acknowledgement))
        case .busy:
            return .temporarilyBusy
        }
    }

    private func exportHistory(
        _ request: HistoryExportRequest,
    ) async throws -> SettingsHistoryExportResult {
        let (_, store) = try dependencies()
        let pathExtension = request.format.pathExtension
        let suggestedName = "\(AppL10n.historyExportSuggestedFilename).\(pathExtension)"
        guard let selectedURL = try await chooseExportDestination(request, suggestedName) else {
            return .cancelled
        }

        let destinationURL = selectedURL.normalizingPathExtension(pathExtension)
        let data = try await store.exportHistory(request: request)
        try writeExportData(data, destinationURL, .atomic)
        return .saved(destinationName: destinationURL.lastPathComponent)
    }

    private func deleteHistory() async throws -> SettingsDestructiveResult {
        let (runtime, _) = try dependencies()
        let acknowledgement = try await runtime.deleteLocalHistory()
        return .acknowledged(featureState(acknowledgement))
    }

    private func resetAll() async throws -> SettingsDestructiveResult {
        let resetAuthorizationMetadata = {
            if let authorizationMetadataResetBoundary {
                return try await authorizationMetadataResetBoundary.reset(persist: resetRuntime)
            }
            return try await resetRuntime()
        }
        if let launchAtLoginMutationBoundary {
            return try await launchAtLoginMutationBoundary.reset(
                persist: resetAuthorizationMetadata,
            )
        }
        return try await resetAuthorizationMetadata()
    }

    private func resetRuntime() async throws -> SettingsDestructiveResult {
        let (runtime, _) = try dependencies()
        switch try await runtime.resetAllLocalData() {
        case let .applied(acknowledgement):
            return .acknowledged(featureState(acknowledgement))
        case .busy:
            return .temporarilyBusy
        }
    }

    private func dependencies() throws -> (ProtocolRuntime, SwiftDataSettingsStore) {
        guard let runtime = runtime(), let store = store() else {
            throw SettingsPrivacyClientError.unavailable
        }
        return (runtime, store)
    }

    private func featureState(
        _ resolved: ResolvedAppPreferences,
        store: SwiftDataSettingsStore,
    ) async throws -> SettingsFeatureState {
        let retainedHistoryCount = try await store.retainedHistoryCount()
        return SettingsFeatureState(
            preferences: resolved.preferences,
            configuration: resolved.configuration,
            retainedHistoryCount: retainedHistoryCount,
        )
    }

    private func featureState(
        _ acknowledgement: SettingsRuntimeMutationAcknowledgement,
    ) -> SettingsFeatureState {
        SettingsFeatureState(
            preferences: acknowledgement.resolvedPreferences.preferences,
            configuration: acknowledgement.resolvedPreferences.configuration,
            retainedHistoryCount: acknowledgement.retainedHistoryCount,
        )
    }
}

extension AppDelegate {
    func makeSettingsFeatureClient(
        chooseExportDestination: @escaping SettingsFeatureAppAdapter.ExportDestinationChooser,
        writeExportData: @escaping SettingsFeatureAppAdapter.ExportDataWriter,
    ) -> SettingsFeatureClient {
        SettingsFeatureAppAdapter(
            runtime: { [weak self] in self?.runtime },
            store: { [weak self] in self?.settingsStore },
            chooseExportDestination: chooseExportDestination,
            writeExportData: writeExportData,
            launchAtLoginMutationBoundary: settingsIntegrationsRuntime.launchAtLoginMutationBoundary,
            authorizationMetadataResetBoundary: settingsIntegrationsRuntime
                .authorizationMetadataResetBoundary,
        ).client
    }
}

private extension SettingsFeatureAppAdapter {
    func updatedPreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) throws -> AppPreferences {
        switch mutation {
        case .setScheduleProfile, .setHeadsUpEnabled, .setWorkingHoursOnly:
            preferences.applying(.setSchedule(schedulePreferences(preferences, mutation: mutation)))
        case .setPreferredMovement, .setShowsQuickMovementOption,
             .setIncludesBreathingContent, .setStandingDeskModeEnabled:
            preferences.applying(.setContent(contentPreferences(preferences, mutation: mutation)))
        case .addExcludedApplicationBundleID, .removeExcludedApplicationBundleID,
             .setWaitsForLowFrictionMoment, .setPresentationModeSuppressionEnabled:
            try preferences.applying(.setContext(contextPreferences(preferences, mutation: mutation)))
        case .setAccessibleBreakPresentation, .setStaticOverlayBrightness,
             .setTimerAnnouncements, .setSeatedContentFirst:
            try preferences.applying(.setAccessibility(accessibilityPreferences(
                preferences,
                mutation: mutation,
            )))
        case let .setHistoryRetention(policy):
            preferences.applying(.setHistoryRetention(policy))
        case .setNotificationsEnabled, .setLaunchAtLoginEnabled, .reconcileLaunchAtLoginEnabled:
            preferences.applying(.setIntegrations(integrationPreferences(preferences, mutation: mutation)))
        }
    }

    func schedulePreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) -> SchedulePreferences {
        let current = preferences.schedule
        switch mutation {
        case let .setScheduleProfile(profile, _):
            return SchedulePreferences(
                profile: profile,
                headsUpEnabled: current.headsUpEnabled,
                workingHoursOnly: current.workingHoursOnly,
            )
        case let .setHeadsUpEnabled(enabled):
            return SchedulePreferences(
                profile: current.profile,
                headsUpEnabled: enabled,
                workingHoursOnly: current.workingHoursOnly,
            )
        case let .setWorkingHoursOnly(enabled):
            return SchedulePreferences(
                profile: current.profile,
                headsUpEnabled: current.headsUpEnabled,
                workingHoursOnly: enabled,
            )
        default:
            preconditionFailure("Expected a schedule mutation")
        }
    }

    func contentPreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) -> BreakContentPreferences {
        let current = preferences.content
        switch mutation {
        case let .setPreferredMovement(preferredMovement):
            return contentPreferences(
                current,
                preferredMovement: preferredMovement,
            )
        case let .setShowsQuickMovementOption(enabled):
            return contentPreferences(
                current,
                showsQuickMovementOption: enabled,
            )
        case let .setIncludesBreathingContent(enabled):
            return contentPreferences(
                current,
                includesBreathingContent: enabled,
            )
        case let .setStandingDeskModeEnabled(enabled):
            return contentPreferences(
                current,
                standingDeskModeEnabled: enabled,
            )
        default:
            preconditionFailure("Expected a content mutation")
        }
    }

    func contextPreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) throws -> ContextPreferences {
        let current = preferences.context
        switch mutation {
        case let .addExcludedApplicationBundleID(bundleID):
            return try contextPreferences(
                current,
                excludedApplicationBundleIDs: current.excludedApplicationBundleIDs + [bundleID],
            )
        case let .removeExcludedApplicationBundleID(bundleID):
            return try contextPreferences(
                current,
                excludedApplicationBundleIDs: current.excludedApplicationBundleIDs.filter { $0 != bundleID },
            )
        case let .setWaitsForLowFrictionMoment(enabled):
            return try contextPreferences(
                current,
                waitsForLowFrictionMoment: enabled,
            )
        case let .setPresentationModeSuppressionEnabled(enabled):
            return try contextPreferences(
                current,
                presentationModeSuppressionEnabled: enabled,
            )
        default:
            preconditionFailure("Expected a context mutation")
        }
    }

    func accessibilityPreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) throws -> AccessibilityPreferences {
        let current = preferences.accessibility
        switch mutation {
        case let .setAccessibleBreakPresentation(presentation):
            return try accessibilityPreferences(
                current,
                presentation: presentation,
            )
        case let .setStaticOverlayBrightness(brightness):
            return try accessibilityPreferences(
                current,
                staticOverlayBrightness: brightness,
            )
        case let .setTimerAnnouncements(timerAnnouncements):
            return try accessibilityPreferences(
                current,
                timerAnnouncements: timerAnnouncements,
            )
        case let .setSeatedContentFirst(enabled):
            return try accessibilityPreferences(
                current,
                seatedContentFirst: enabled,
            )
        default:
            preconditionFailure("Expected an accessibility mutation")
        }
    }

    func integrationPreferences(
        _ preferences: AppPreferences,
        mutation: SettingsFeatureMutation,
    ) -> IntegrationPreferences {
        let current = preferences.integrations
        switch mutation {
        case let .setNotificationsEnabled(enabled):
            return IntegrationPreferences(
                notificationsEnabled: enabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: current.launchAtLoginEnabled,
            )
        case let .setLaunchAtLoginEnabled(enabled),
             let .reconcileLaunchAtLoginEnabled(enabled):
            return IntegrationPreferences(
                notificationsEnabled: current.notificationsEnabled,
                calendarBusySuppressionEnabled: current.calendarBusySuppressionEnabled,
                focusFilterEnabled: current.focusFilterEnabled,
                launchAtLoginEnabled: enabled,
            )
        default:
            preconditionFailure("Expected an integrations mutation")
        }
    }

    func contentPreferences(
        _ current: BreakContentPreferences,
        preferredMovement: PreferredMovementContent? = nil,
        showsQuickMovementOption: Bool? = nil,
        includesBreathingContent: Bool? = nil,
        standingDeskModeEnabled: Bool? = nil,
    ) -> BreakContentPreferences {
        BreakContentPreferences(
            preferredMovement: preferredMovement ?? current.preferredMovement,
            showsQuickMovementOption: showsQuickMovementOption ?? current.showsQuickMovementOption,
            includesBreathingContent: includesBreathingContent ?? current.includesBreathingContent,
            standingDeskModeEnabled: standingDeskModeEnabled ?? current.standingDeskModeEnabled,
        )
    }

    func contextPreferences(
        _ current: ContextPreferences,
        excludedApplicationBundleIDs: [String]? = nil,
        waitsForLowFrictionMoment: Bool? = nil,
        presentationModeSuppressionEnabled: Bool? = nil,
    ) throws -> ContextPreferences {
        try ContextPreferences(
            excludedApplicationBundleIDs: excludedApplicationBundleIDs ?? current.excludedApplicationBundleIDs,
            waitsForLowFrictionMoment: waitsForLowFrictionMoment ?? current.waitsForLowFrictionMoment,
            presentationModeSuppressionEnabled: presentationModeSuppressionEnabled
                ?? current.presentationModeSuppressionEnabled,
            idleBehavior: current.idleBehavior,
        )
    }

    func accessibilityPreferences(
        _ current: AccessibilityPreferences,
        presentation: AccessibleBreakPresentation? = nil,
        staticOverlayBrightness: Double? = nil,
        timerAnnouncements: TimerAnnouncementPreference? = nil,
        seatedContentFirst: Bool? = nil,
    ) throws -> AccessibilityPreferences {
        try AccessibilityPreferences(
            presentation: presentation ?? current.presentation,
            staticOverlayBrightness: staticOverlayBrightness ?? current.staticOverlayBrightness,
            timerAnnouncements: timerAnnouncements ?? current.timerAnnouncements,
            seatedContentFirst: seatedContentFirst ?? current.seatedContentFirst,
        )
    }
}

private extension HistoryExportFormat {
    var pathExtension: String {
        switch self {
        case .csv: "csv"
        case .json: "json"
        }
    }
}

private extension URL {
    func normalizingPathExtension(_ pathExtension: String) -> URL {
        guard self.pathExtension != pathExtension else { return self }
        let base = self.pathExtension.isEmpty ? self : deletingPathExtension()
        return base.appendingPathExtension(pathExtension)
    }
}
