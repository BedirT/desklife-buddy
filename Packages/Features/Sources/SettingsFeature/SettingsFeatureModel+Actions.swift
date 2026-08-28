import Domain
import Foundation

public extension SettingsFeatureModel {
    func select(_ section: SettingsSection) { selectedSection = section }

    func moveSidebarSelection(by offset: Int) {
        let sections = SettingsSection.allCases
        guard let currentIndex = sections.firstIndex(of: selectedSection) else { return }
        let nextIndex = min(max(currentIndex + offset, sections.startIndex), sections.index(before: sections.endIndex))
        selectedSection = sections[nextIndex]
    }

    func configuration(for choice: SettingsScheduleChoice) -> ProtocolConfiguration? {
        if choice == selectedScheduleChoice {
            return selectedConfiguration
        }
        return catalog.configuration(for: choice)
    }

    func configuration(for profile: ProtocolProfileID) -> ProtocolConfiguration? {
        configuration(for: SettingsScheduleChoice(profileID: profile))
    }

    func load() async {
        guard applyState != .applying, !privacyOperation.isInProgress else { return }
        phase = .loading
        do {
            let state = try await client.load()
            publishLoadedState(state)
            retryMutation = nil
            applyState = .idle
            phase = .ready
        } catch {
            phase = .loadFailed
        }
    }

    func selectProfile(_ choice: SettingsScheduleChoice) async {
        guard applyState != .applying else { return }
        if choice == .custom {
            beginCustomEditing()
            return
        }
        guard let profile = choice.scheduleProfile,
              let configuration = catalog.configuration(for: choice)
        else { return }
        guard selectedScheduleChoice != choice else { return }
        await apply(.setScheduleProfile(profile, baseConfiguration: configuration))
    }

    func selectProfile(_ profile: ProtocolProfileID) async {
        await selectProfile(SettingsScheduleChoice(profileID: profile))
    }

    func beginCustomEditing() {
        guard applyState != .applying else { return }
        if !hasRetainedCustomDraft, let selectedConfiguration {
            replaceCustomDraft(CustomScheduleDraft(configuration: selectedConfiguration))
        }
        isCustomEditing = true
        isAdvancedScheduleExpanded = true
    }

    func editCustomField(_ field: CustomScheduleField, value: Double?) {
        guard applyState != .applying else { return }
        customDraft.set(field, to: value)
        customFieldTexts[field] = value.map(settingsDisplayNumber) ?? ""
        invalidCustomFields.remove(field)
        hasRetainedCustomDraft = true
        invalidateRetryAfterDraftEdit()
    }

    func editCustomFieldText(_ field: CustomScheduleField, text: String) {
        guard applyState != .applying else { return }
        guard customFieldTexts[field] != text else { return }
        customFieldTexts[field] = text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            customDraft.set(field, to: nil)
            invalidCustomFields.remove(field)
        } else if let value = try? SettingsNumberParseStrategy().parse(text) {
            customDraft.set(field, to: value)
            invalidCustomFields.remove(field)
        } else {
            customDraft.set(field, to: nil)
            invalidCustomFields.insert(field)
        }
        hasRetainedCustomDraft = true
        invalidateRetryAfterDraftEdit()
    }

    func applyCustomDraft() async {
        guard canApplyCustom,
              let timing = try? customDraft.timing(),
              let selectedConfiguration
        else { return }
        await apply(
            .setScheduleProfile(
                .custom(timing),
                baseConfiguration: timing.applying(to: selectedConfiguration),
            ),
        )
    }

    func setHeadsUpEnabled(_ enabled: Bool) async {
        await apply(.setHeadsUpEnabled(enabled))
    }

    func setWorkingHoursOnly(_ enabled: Bool) async {
        await apply(.setWorkingHoursOnly(enabled))
    }

    func setPreferredMovement(_ preference: PreferredMovementContent) async {
        await apply(.setPreferredMovement(preference))
    }

    func setShowsQuickMovementOption(_ enabled: Bool) async {
        await apply(.setShowsQuickMovementOption(enabled))
    }

    func setIncludesBreathingContent(_ enabled: Bool) async {
        await apply(.setIncludesBreathingContent(enabled))
    }

    func setStandingDeskModeEnabled(_ enabled: Bool) async {
        await apply(.setStandingDeskModeEnabled(enabled))
    }

    func addExcludedApplicationBundleID(_ bundleID: String) async {
        guard applyState != .applying,
              let canonicalBundleID = canonicalBundleID(bundleID),
              !excludedApplicationBundleIDs.contains(canonicalBundleID)
        else { return }
        await apply(.addExcludedApplicationBundleID(canonicalBundleID))
    }

    func removeExcludedApplicationBundleID(_ bundleID: String) async {
        guard applyState != .applying,
              let canonicalBundleID = canonicalBundleID(bundleID),
              excludedApplicationBundleIDs.contains(canonicalBundleID)
        else { return }
        await apply(.removeExcludedApplicationBundleID(canonicalBundleID))
    }

    func setWaitsForLowFrictionMoment(_ enabled: Bool) async {
        await apply(.setWaitsForLowFrictionMoment(enabled))
    }

    func setPresentationModeSuppressionEnabled(_ enabled: Bool) async {
        await apply(.setPresentationModeSuppressionEnabled(enabled))
    }

    func setAccessibleBreakPresentation(_ presentation: AccessibleBreakPresentation) async {
        await apply(.setAccessibleBreakPresentation(presentation))
    }

    func setStaticOverlayBrightness(_ brightness: Double) async {
        guard (try? accessibilityPreferences(staticOverlayBrightness: brightness)) != nil else { return }
        await apply(.setStaticOverlayBrightness(brightness))
    }

    func setTimerAnnouncements(_ preference: TimerAnnouncementPreference) async {
        await apply(.setTimerAnnouncements(preference))
    }

    func setSeatedContentFirst(_ enabled: Bool) async {
        await apply(.setSeatedContentFirst(enabled))
    }

    func setHistoryRetention(_ policy: HistoryRetentionPolicy) async {
        await apply(.setHistoryRetention(policy))
    }

    func setNotificationsEnabled(
        _ enabled: Bool,
        capability: IntegrationCapabilityState,
    ) async {
        guard !enabled || capability.canEnable else { return }
        await apply(.setNotificationsEnabled(enabled))
    }

    func setLaunchAtLoginEnabled(
        _ enabled: Bool,
        state: SettingsLaunchAtLoginState,
    ) async {
        guard state.canToggle else { return }
        await apply(.setLaunchAtLoginEnabled(enabled))
    }

    func reconcileLaunchAtLoginEnabled(_ enabled: Bool) async {
        guard preferences?.integrations.launchAtLoginEnabled != enabled else { return }
        await apply(.reconcileLaunchAtLoginEnabled(enabled))
    }

    func selectContentLibraryItem(id: String) {
        guard contentLibraryItems.contains(where: { $0.id == id }) else { return }
        selectedContentLibraryItemID = id
    }

    func openContentLibrary(selecting itemID: String? = nil) {
        isContentLibraryPresented = true
        if let itemID {
            selectContentLibraryItem(id: itemID)
        }
    }

    func closeContentLibrary() {
        isContentLibraryPresented = false
        selectedContentLibraryItemID = nil
    }

    func showContentLibraryList() {
        selectedContentLibraryItemID = nil
    }

    func retryLastChange() async {
        guard let retryMutation, applyState != .applying else { return }
        await apply(retryMutation)
    }

    internal func apply(_ mutation: SettingsFeatureMutation) async {
        guard let priorPreferences = preferences,
              let priorConfiguration = appliedConfiguration,
              let optimistic = optimisticState(for: mutation),
              applyState != .applying,
              !privacyOperation.isInProgress
        else { return }
        let priorEditing = isCustomEditing
        let priorAdvanced = isAdvancedScheduleExpanded
        preferences = optimistic.preferences
        appliedConfiguration = optimistic.configuration
        if case let .setScheduleProfile(profile, _) = mutation {
            if profile.protocolProfileID != .custom {
                isCustomEditing = false
            }
        }
        applyState = .applying
        do {
            switch try await client.apply(mutation) {
            case let .applied(authoritative):
                preferences = authoritative.preferences
                appliedConfiguration = authoritative.configuration
                retainedHistoryCount = authoritative.retainedHistoryCount
                publishAppliedDerivedState(for: mutation, authoritative: authoritative)
                retryMutation = nil
                applyState = .idle
            case .temporarilyBusy:
                restore(
                    preferences: priorPreferences,
                    configuration: priorConfiguration,
                    editing: priorEditing,
                    advanced: priorAdvanced,
                )
                retryMutation = mutation
                applyState = .temporarilyBusy
            }
        } catch {
            restore(
                preferences: priorPreferences,
                configuration: priorConfiguration,
                editing: priorEditing,
                advanced: priorAdvanced,
            )
            retryMutation = mutation
            applyState = .failed
        }
    }

    func publishLoadedState(_ state: SettingsFeatureState) {
        preferences = state.preferences
        appliedConfiguration = state.configuration
        retainedHistoryCount = state.retainedHistoryCount
        retryMutation = nil
        switch state.preferences.schedule.profile {
        case let .custom(timing):
            replaceCustomDraft(CustomScheduleDraft(timing: timing))
            hasRetainedCustomDraft = true
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
        case .gentle, .balanced, .frequentMovement, .researchInformedHighFrequency:
            replaceCustomDraft(CustomScheduleDraft(configuration: state.configuration))
            hasRetainedCustomDraft = false
            isCustomEditing = false
            isAdvancedScheduleExpanded = state.preferences.schedule.profile.protocolProfileID
                == .researchInformedHighFrequency
        }
    }

    private func publishAppliedDerivedState(
        for mutation: SettingsFeatureMutation,
        authoritative: SettingsFeatureState,
    ) {
        guard case .setScheduleProfile = mutation else { return }
        switch authoritative.preferences.schedule.profile {
        case let .custom(timing):
            replaceCustomDraft(CustomScheduleDraft(timing: timing))
            hasRetainedCustomDraft = true
            isCustomEditing = true
            isAdvancedScheduleExpanded = true
        case .gentle, .balanced, .frequentMovement, .researchInformedHighFrequency:
            isCustomEditing = false
        }
    }

    private func restore(
        preferences: AppPreferences,
        configuration: ProtocolConfiguration,
        editing: Bool,
        advanced: Bool,
    ) {
        self.preferences = preferences
        appliedConfiguration = configuration
        isCustomEditing = editing
        isAdvancedScheduleExpanded = advanced
    }

    private func invalidateRetryAfterDraftEdit() {
        if retryMutation != nil {
            retryMutation = nil
            applyState = .idle
        }
    }

    private func canonicalBundleID(_ bundleID: String) -> String? {
        try? ContextPreferences(excludedApplicationBundleIDs: [bundleID])
            .excludedApplicationBundleIDs.first
    }

    func contextPreferences(
        excludedApplicationBundleIDs: [String]? = nil,
        waitsForLowFrictionMoment: Bool? = nil,
        presentationModeSuppressionEnabled: Bool? = nil,
    ) -> ContextPreferences? {
        guard let current = preferences?.context else { return nil }
        return try? ContextPreferences(
            excludedApplicationBundleIDs: excludedApplicationBundleIDs
                ?? current.excludedApplicationBundleIDs,
            waitsForLowFrictionMoment: waitsForLowFrictionMoment
                ?? current.waitsForLowFrictionMoment,
            presentationModeSuppressionEnabled: presentationModeSuppressionEnabled
                ?? current.presentationModeSuppressionEnabled,
            idleBehavior: current.idleBehavior,
        )
    }

    func accessibilityPreferences(
        presentation: AccessibleBreakPresentation? = nil,
        staticOverlayBrightness: Double? = nil,
        timerAnnouncements: TimerAnnouncementPreference? = nil,
        seatedContentFirst: Bool? = nil,
    ) throws -> AccessibilityPreferences {
        guard let current = preferences?.accessibility else {
            throw SettingsFeatureActionError.settingsNotLoaded
        }
        return try AccessibilityPreferences(
            presentation: presentation ?? current.presentation,
            staticOverlayBrightness: staticOverlayBrightness ?? current.staticOverlayBrightness,
            timerAnnouncements: timerAnnouncements ?? current.timerAnnouncements,
            seatedContentFirst: seatedContentFirst ?? current.seatedContentFirst,
        )
    }
}

private enum SettingsFeatureActionError: Error {
    case settingsNotLoaded
}
