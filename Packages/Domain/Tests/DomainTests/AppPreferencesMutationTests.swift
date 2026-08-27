import Foundation
import Testing
@testable import Domain

@Suite("App preference mutations")
struct AppPreferencesMutationTests {
    @Test("Every typed mutation replaces only its field")
    func mutationFieldPreservation() throws {
        let original = try configuredPreferences()
        let schedule = SchedulePreferences(profile: .gentle, headsUpEnabled: true, workingHoursOnly: true)
        let content = BreakContentPreferences(preferredMovement: .mixed)
        let context = try ContextPreferences(excludedApplicationBundleIDs: ["org.example.editor"])
        let accessibility = try AccessibilityPreferences(presentation: .staticPresentation)
        let integrations = IntegrationPreferences(notificationsEnabled: true)

        assertOnlyScheduleChanged(original.applying(.setSchedule(schedule)), from: original, to: schedule)
        assertOnlyRetentionChanged(original.applying(.setHistoryRetention(.keepNothing)), from: original)
        assertOnlyContentChanged(original.applying(.setContent(content)), from: original, to: content)
        assertOnlyContextChanged(original.applying(.setContext(context)), from: original, to: context)
        assertOnlyAccessibilityChanged(
            original.applying(.setAccessibility(accessibility)),
            from: original,
            to: accessibility,
        )
        assertOnlyIntegrationsChanged(
            original.applying(.setIntegrations(integrations)),
            from: original,
            to: integrations,
        )
    }

    @Test("History deletion preserves every preference field")
    func historyOnlyDeletionBoundary() throws {
        let selected = try configuredPreferences()
        let snapshot = LocalDataSnapshot(preferences: selected, history: [.fixture])

        let result = snapshot.applying(.deleteHistory)

        #expect(result.preferences == selected)
        #expect(result.history.isEmpty)
    }

    @Test("Reset all removes history and restores the current Balanced defaults")
    func resetAllSemantics() throws {
        let snapshot = LocalDataSnapshot(preferences: try configuredPreferences(), history: [.fixture])

        let result = snapshot.applying(.resetAll)

        #expect(result == LocalDataSnapshot(preferences: .defaults, history: []))
    }

    private func configuredPreferences() throws -> AppPreferences {
        AppPreferences(
            schedule: SchedulePreferences(profile: .frequentMovement, headsUpEnabled: false, workingHoursOnly: false),
            historyRetention: .ninetyDays,
            content: BreakContentPreferences(preferredMovement: .seatedActive, showsQuickMovementOption: false),
            context: try ContextPreferences(excludedApplicationBundleIDs: ["com.example.call"]),
            accessibility: try AccessibilityPreferences(presentation: .textOnly, staticOverlayBrightness: 0.2),
            integrations: IntegrationPreferences(calendarBusySuppressionEnabled: true, launchAtLoginEnabled: true),
        )
    }

    private func assertOnlyScheduleChanged(
        _ result: AppPreferences,
        from original: AppPreferences,
        to expected: SchedulePreferences,
    ) {
        #expect(result.schedule == expected)
        assertSharedFields(result, original, excluding: .schedule)
    }

    private func assertOnlyRetentionChanged(_ result: AppPreferences, from original: AppPreferences) {
        #expect(result.historyRetention == .keepNothing)
        assertSharedFields(result, original, excluding: .retention)
    }

    private func assertOnlyContentChanged(
        _ result: AppPreferences,
        from original: AppPreferences,
        to expected: BreakContentPreferences,
    ) {
        #expect(result.content == expected)
        assertSharedFields(result, original, excluding: .content)
    }

    private func assertOnlyContextChanged(
        _ result: AppPreferences,
        from original: AppPreferences,
        to expected: ContextPreferences,
    ) {
        #expect(result.context == expected)
        assertSharedFields(result, original, excluding: .context)
    }

    private func assertOnlyAccessibilityChanged(
        _ result: AppPreferences,
        from original: AppPreferences,
        to expected: AccessibilityPreferences,
    ) {
        #expect(result.accessibility == expected)
        assertSharedFields(result, original, excluding: .accessibility)
    }

    private func assertOnlyIntegrationsChanged(
        _ result: AppPreferences,
        from original: AppPreferences,
        to expected: IntegrationPreferences,
    ) {
        #expect(result.integrations == expected)
        assertSharedFields(result, original, excluding: .integrations)
    }

    private func assertSharedFields(
        _ result: AppPreferences,
        _ original: AppPreferences,
        excluding field: PreferenceField,
    ) {
        if field != .schedule { #expect(result.schedule == original.schedule) }
        if field != .retention { #expect(result.historyRetention == original.historyRetention) }
        if field != .content { #expect(result.content == original.content) }
        if field != .context { #expect(result.context == original.context) }
        if field != .accessibility { #expect(result.accessibility == original.accessibility) }
        if field != .integrations { #expect(result.integrations == original.integrations) }
        #expect(result.formatVersion == original.formatVersion)
    }

    private enum PreferenceField {
        case schedule
        case retention
        case content
        case context
        case accessibility
        case integrations
    }
}

private extension OpportunityEvent {
    static let fixture = OpportunityEvent(
        id: UUID(uuidString: "00000000-0000-4000-8000-000000000072")!,
        kind: .skipped,
        recordedAt: Date(timeIntervalSince1970: 1_767_225_600),
        source: .user,
        opportunity: .visual,
    )
}
