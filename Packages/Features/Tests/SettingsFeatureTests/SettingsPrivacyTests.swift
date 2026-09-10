import Domain
import Foundation
import Testing
@testable import SettingsFeature

// swiftlint:disable file_length

@Suite("Settings privacy state")
struct SettingsPrivacyStateTests {
    @Test("Privacy dialogs start safely and restore focus to an enabled deterministic control")
    func modalFocusContract() {
        #expect(SettingsPrivacyFocusTarget.initialModalTarget == .cancel)
        let exportOrigin = SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: true,
            destructiveOperation: nil,
        )
        let deleteOrigin = SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: false,
            destructiveOperation: .deleteHistory,
        )
        let resetOrigin = SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: false,
            destructiveOperation: .resetAll,
        )

        #expect(exportOrigin == .reviewExport)
        #expect(deleteOrigin == .requestDeleteHistory)
        #expect(resetOrigin == .requestResetAll)
        #expect(SettingsPrivacyFocusTarget.modalTargets(
            isExport: true,
            canRetry: false,
            columnsExpanded: false,
            canChooseDestination: true,
        ) == [
            .cancel, .format, .columns, .chooseDestination,
        ])
        #expect(SettingsPrivacyFocusTarget.modalTargets(
            isExport: true,
            canRetry: false,
            columnsExpanded: true,
            canChooseDestination: true,
        ) == [
            .cancel,
            .format,
            .columns,
            .field(.id),
            .field(.recordedAt),
            .field(.kind),
            .field(.source),
            .field(.opportunity),
            .field(.selectedDurationSeconds),
            .chooseDestination,
        ])
        #expect(SettingsPrivacyFocusTarget.modalTargets(
            isExport: true,
            canRetry: false,
            columnsExpanded: true,
            canChooseDestination: false,
        ) == [
            .cancel,
            .format,
            .columns,
            .field(.id),
            .field(.recordedAt),
            .field(.kind),
            .field(.source),
            .field(.opportunity),
            .field(.selectedDurationSeconds),
        ])
        #expect(SettingsPrivacyFocusTarget.modalTargets(
            isExport: false,
            canRetry: false,
            columnsExpanded: false,
            canChooseDestination: false,
        ) == [
            .cancel, .confirm,
        ])
        #expect(SettingsPrivacyFocusTarget.modalTargets(
            isExport: true,
            canRetry: true,
            columnsExpanded: false,
            canChooseDestination: true,
        ) == [
            .cancel, .retry,
        ])
        #expect(SettingsPrivacyFocusTarget.nextModalTarget(
            after: .cancel,
            in: [.cancel, .format, .columns, .chooseDestination],
            reverse: false,
        ) == .format)
        #expect(SettingsPrivacyFocusTarget.nextModalTarget(
            after: .cancel,
            in: [.cancel, .confirm],
            reverse: true,
        ) == .confirm)
    }

    @Test("Choosing a destination requires at least one typed history column")
    func exportRequiresASelectedField() async {
        let model = privacyModel(preferences: .defaults)
        await model.load()
        model.presentExportDisclosure()

        for field in HistoryExportField.allCases {
            model.toggleExportField(field)
        }

        #expect(model.selectedExportFields.isEmpty)
        #expect(model.exportRequest == nil)
    }

    @Test("Privacy dismissal chooses an enabled target from the operation outcome")
    func modalDismissalFocusPolicy() {
        #expect(SettingsPrivacyFocusTarget.restorationTarget(
            after: .idle,
            fallback: .requestDeleteHistory,
        ) == .requestDeleteHistory)
        #expect(SettingsPrivacyFocusTarget.restorationTarget(
            after: .historyDeletionSucceeded,
            fallback: .requestDeleteHistory,
        ) == .dataControlsDisclosure)
        #expect(SettingsPrivacyFocusTarget.restorationTarget(
            after: .resetSucceeded,
            fallback: .requestResetAll,
        ) == .dataControlsDisclosure)
        #expect(SettingsPrivacyFocusTarget.restorationTarget(
            after: .exportSucceeded(destinationName: "Break History.json"),
            fallback: .reviewExport,
        ) == .reviewExport)
    }

    @Test("Privacy state plainly inventories local data without analytics or check-ins")
    func storedDataSummaryIsCompleteAndBounded() async throws {
        let model = try privacyModel(preferences: nonDefaultPreferences())

        await model.load()

        #expect(model.storedDataSummary.map(\.id) == [
            .settingsAndPreferences,
            .opportunityHistory,
            .estimatedActiveUseHistory,
            .excludedApplicationBundleIdentifiers,
            .integrationSelections,
            .runtimeRecoveryState,
            .onboardingCompletionMarker,
            .notificationAuthorizationMetadata,
        ])
        #expect(
            SettingsPrivacyL10n.preferencesDetail
                ==
                "Schedule, break content, exclusions, accessibility, integration choices, the exact clock configuration, a setup-completion marker with its outcome and time, and the app's notification prompt and authorization history.",
        )
        #expect(SettingsPrivacyL10n.estimatedActiveUseHistoryTitle == "Estimated active-use history")
        #expect(
            SettingsPrivacyL10n.estimatedActiveUseHistoryDetail
                ==
                "Retained records contain the start and end time of each estimated active-use run used by Weekly.",
        )
        #expect(SettingsPrivacyControl.allCases == [
            .retention,
            .exportHistory,
            .deleteHistory,
            .resetAll,
        ])
    }

    @Test("Retention exposes only 30 days, 90 days, and keep nothing")
    func retentionChoicesAreBoundedAndOrdered() async throws {
        let original = try nonDefaultPreferences()
        let model = privacyModel(preferences: original)

        await model.load()

        #expect(model.historyRetention == .ninetyDays)
        #expect(SettingsPrivacyRetentionChoice.allCases.map(\.policy) == [
            .thirtyDays,
            .ninetyDays,
            .keepNothing,
        ])
    }

    @Test("A retention edit changes only retention and uses persistence acknowledgement")
    func retentionChangePreservesEverySibling() async throws {
        let original = try nonDefaultPreferences()
        let expected = original.applying(.setHistoryRetention(.keepNothing))
        let catalog = try SettingsScheduleCatalog.fixture()
        var attempts: [SettingsFeatureMutation] = []
        let model = privacyModel(
            preferences: original,
            apply: { mutation in
                attempts.append(mutation)
                return .applied(state(expected, base: catalog.balanced))
            },
        )

        await model.load()
        await model.setHistoryRetention(.keepNothing)

        #expect(attempts == [.setHistoryRetention(.keepNothing)])
        #expect(model.preferences == expected)
        #expect(model.historyRetention == .keepNothing)
        expectEveryPreferenceExceptRetention(expected, equals: original)
        #expect(model.operationState == .idle)
    }

    @Test("Busy retention save rolls back and retries the exact selection")
    func retentionBusyRollbackAndRetry() async throws {
        let original = try nonDefaultPreferences()
        let expected = original.applying(.setHistoryRetention(.thirtyDays))
        let catalog = try SettingsScheduleCatalog.fixture()
        var attempts: [SettingsFeatureMutation] = []
        let model = privacyModel(
            preferences: original,
            apply: { mutation in
                attempts.append(mutation)
                if attempts.count == 1 { return .temporarilyBusy }
                return .applied(state(expected, base: catalog.balanced))
            },
        )

        await model.load()
        await model.setHistoryRetention(.thirtyDays)

        #expect(model.preferences == original)
        #expect(model.operationState == .temporarilyBusy)
        #expect(model.canRetryLastChange)

        await model.retryLastChange()

        let mutation = SettingsFeatureMutation.setHistoryRetention(.thirtyDays)
        #expect(attempts == [mutation, mutation])
        #expect(model.preferences == expected)
        #expect(model.operationState == .idle)
    }
}

@Suite("Settings privacy export")
struct SettingsPrivacyExportTests {
    @Test("Export disclosure exposes one format and six typed selectable fields")
    func exportDisclosureMatchesDomainProjection() async throws {
        let model = privacyModel(preferences: .defaults)

        await model.load()
        model.presentExportDisclosure()

        #expect(model.isExportDisclosurePresented)
        #expect(model.exportedDataCategories == [.opportunityHistory])
        #expect(model.exportFieldDisclosures.map(\.field) == [
            .id,
            .recordedAt,
            .kind,
            .source,
            .opportunity,
            .selectedDurationSeconds,
        ])
        #expect(
            HistoryExportField.allCases.map(\.rawValue) == model.exportFieldDisclosures
                .map(\.field.rawValue),
        )
        #expect(model.exportFieldDisclosures.map(\.explanation) == [
            "A random identifier for this local record.",
            "The date and time when the event was recorded.",
            "The event type, such as presented, started, skipped, or completed.",
            "What created the event: the local timer, an action you took, or available system context.",
            "Whether the event belongs to a visual reset, movement, position change, or recovery, when applicable.",
            "The break duration you selected, in seconds, when applicable.",
        ])
        #expect(model.selectedExportFormat == .csv)
        #expect(model.selectedExportFields == Set(HistoryExportField.allCases))
        #expect(!model.isExportColumnsExpanded)
        #expect(SettingsPrivacyL10n.reviewExportTitle == "Your history export")
        #expect(SettingsPrivacyL10n.exportHistorySummaryTitle == "Local history")
        #expect(SettingsPrivacyL10n.exportReadyStatus == "Ready to export")
        #expect(SettingsPrivacyL10n.exportNeedsColumnsStatus == "Select columns")
        #expect(SettingsPrivacyL10n.exportEventCount(1) == "1 event")
        #expect(SettingsPrivacyL10n.exportEventCount(14) == "14 events")
        #expect(SettingsPrivacyL10n.exportContains == "Contains")
        #expect(SettingsPrivacyL10n.exportExcludes == "Excludes")
        #expect(SettingsPrivacyL10n.exportFormat == "Format")
        #expect(SettingsPrivacyL10n.exportColumns == "Columns")
    }

    @Test("Export asks App to write to a user-chosen destination and acknowledges only after success")
    func exportUsesDestinationSeamAndAcknowledgesSuccess() async throws {
        let gate = PrivacyOperationGate<SettingsHistoryExportResult>()
        var requests: [HistoryExportRequest] = []
        let model = privacyModel(
            preferences: .defaults,
            exportHistory: { request in
                requests.append(request)
                return await gate.wait()
            },
        )
        await model.load()
        model.presentExportDisclosure()
        model.setExportFormat(.json)
        model.toggleExportField(.source)
        model.toggleExportField(.recordedAt)

        let operation = Task { await model.exportHistory() }
        await gate.waitUntilStarted()

        #expect(try requests == [HistoryExportRequest(
            format: .json,
            selectedFields: [.id, .kind, .opportunity, .selectedDurationSeconds],
        )])
        #expect(model.privacyOperation == .exporting)
        #expect(model.isExportDisclosurePresented)

        gate.finish(with: .saved(destinationName: "Break History.json"))
        await operation.value

        #expect(model.privacyOperation == .exportSucceeded(destinationName: "Break History.json"))
        #expect(!model.isExportDisclosurePresented)
    }

    @Test("Cancelling the destination picker is not reported as a successful export")
    func exportCancellationIsQuiet() async throws {
        let model = privacyModel(
            preferences: .defaults,
            exportHistory: { _ in .cancelled },
        )
        await model.load()
        model.presentExportDisclosure()

        await model.exportHistory()

        #expect(model.privacyOperation == .idle)
        #expect(model.isExportDisclosurePresented)
    }

    @Test("Export failure keeps disclosure open and retries the exact immutable request")
    func exportFailureAndRetry() async throws {
        var requests: [HistoryExportRequest] = []
        let model = privacyModel(
            preferences: .defaults,
            exportHistory: { request in
                requests.append(request)
                if requests.count == 1 { throw TestFailure.save }
                return .saved(destinationName: "Break History.csv")
            },
        )
        await model.load()
        model.presentExportDisclosure()
        model.setExportFormat(.csv)
        model.toggleExportField(.opportunity)
        let request = try #require(model.exportRequest)

        await model.exportHistory()

        #expect(model.privacyOperation == .failed(.exportHistory(request)))
        #expect(model.isExportDisclosurePresented)
        #expect(model.canRetryPrivacyOperation)

        await model.retryPrivacyOperation()

        model.setExportFormat(.json)
        model.toggleExportField(.source)
        #expect(requests == [request, request])
        #expect(model.privacyOperation == .exportSucceeded(destinationName: "Break History.csv"))
        #expect(!model.canRetryPrivacyOperation)
    }
}

@Suite("Settings privacy destructive operations")
struct SettingsPrivacyDestructiveTests {
    @Test("Delete-history confirmation states exactly what is removed and retained")
    func deleteHistoryExactConfirmation() async throws {
        let model = try privacyModel(preferences: nonDefaultPreferences())
        await model.load()

        model.requestDeleteHistoryConfirmation()

        #expect(model.pendingDestructiveOperation == .deleteHistory)
        #expect(SettingsPrivacyL10n.deleteHistoryConfirmationTitle == "Delete all break history?")
        #expect(
            SettingsPrivacyL10n.deleteHistoryConfirmationBody
                ==
                "This deletes retained opportunity events and Weekly history. Your schedule, content choices, exclusions, accessibility, integrations, and current timers remain.",
        )
    }

    @Test("Delete history claims success only after persistence acknowledges it")
    func deleteHistoryAcknowledgementAndPreservation() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        let gate = PrivacyOperationGate<SettingsDestructiveResult>()
        let model = privacyModel(
            preferences: original,
            deleteHistory: { await gate.wait() },
        )
        await model.load()
        model.requestDeleteHistoryConfirmation()
        let modalOrigin = SettingsPrivacyFocusTarget.restoreTarget(
            exportDisclosurePresented: model.isExportDisclosurePresented,
            destructiveOperation: model.pendingDestructiveOperation,
        )

        let operation = Task { await model.confirmPendingDestructiveOperation() }
        await gate.waitUntilStarted()

        #expect(model.privacyOperation == .deletingHistory)
        #expect(model.pendingDestructiveOperation == .deleteHistory)
        #expect(model.preferences == original)

        gate.finish(with: .acknowledged(state(original, base: catalog.balanced, retainedHistoryCount: 0)))
        await operation.value

        #expect(model.preferences == original)
        #expect(model.retainedHistoryCount == 0)
        #expect(!model.hasRetainedHistory)
        #expect(model.pendingDestructiveOperation == nil)
        #expect(model.privacyOperation == .historyDeletionSucceeded)
        #expect(SettingsPrivacyFocusTarget.restorationTarget(
            after: model.privacyOperation,
            fallback: modalOrigin,
        ) == .dataControlsDisclosure)
        #expect(
            SettingsPrivacyL10n.historyDeletedAcknowledgement
                == "History deleted. Your settings and current timers were kept.",
        )

        model.dismissPrivacyOperationFeedback()

        #expect(model.privacyOperation == .idle)
        #expect(!model.hasRetainedHistory)
    }

    @Test("History availability comes from the authoritative loaded count")
    func authoritativeHistoryAvailability() async throws {
        let empty = privacyModel(preferences: .defaults, retainedHistoryCount: 0)
        await empty.load()
        #expect(empty.retainedHistoryCount == 0)
        #expect(!empty.hasRetainedHistory)

        let populated = privacyModel(preferences: .defaults, retainedHistoryCount: 3)
        await populated.load()
        #expect(populated.retainedHistoryCount == 3)
        #expect(populated.hasRetainedHistory)
    }

    @Test("Reset-all confirmation states the broader boundary exactly")
    func resetAllExactConfirmation() async throws {
        let model = try privacyModel(preferences: nonDefaultPreferences())
        await model.load()

        model.requestResetAllConfirmation()

        #expect(model.pendingDestructiveOperation == .resetAll)
        #expect(SettingsPrivacyL10n.resetAllConfirmationTitle == "Reset history and app preferences?")
        #expect(
            SettingsPrivacyL10n.resetAllConfirmationBody
                ==
                "This deletes history and every app preference, including exclusions, integration choices, and the app's notification prompt and authorization history. The Balanced schedule is restored. The setup-completion marker is kept so setup does not reopen. macOS permissions are not changed.",
        )
    }

    @Test("Reset all publishes authoritative defaults only after persistence acknowledges it")
    func resetAllAcknowledgementAndBoundary() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        let gate = PrivacyOperationGate<SettingsDestructiveResult>()
        let defaults = AppPreferences.defaults
        let model = privacyModel(
            preferences: original,
            resetAll: { await gate.wait() },
        )
        await model.load()
        model.requestResetAllConfirmation()

        let operation = Task { await model.confirmPendingDestructiveOperation() }
        await gate.waitUntilStarted()

        #expect(model.privacyOperation == .resettingAll)
        #expect(model.preferences == original)

        gate.finish(with: .acknowledged(state(defaults, base: catalog.balanced)))
        await operation.value

        #expect(model.preferences == defaults)
        #expect(model.selectedScheduleChoice == .balanced)
        #expect(model.pendingDestructiveOperation == nil)
        #expect(model.privacyOperation == .resetSucceeded)
        let expectedAcknowledgement =
            "History, app preferences, and the app's notification prompt and authorization history were reset. Balanced is now selected. "
                + "The setup-completion marker and macOS permissions were not changed."
        #expect(
            SettingsPrivacyL10n.resetAllAcknowledgement
                == expectedAcknowledgement,
        )
    }

    @Test("Reset success supersedes a failed preference save and its retry")
    func resetAllClearsFailedApplyState() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        var applyCalls = 0
        let model = privacyModel(
            preferences: original,
            apply: { _ in
                applyCalls += 1
                throw TestFailure.save
            },
            resetAll: {
                .acknowledged(state(.defaults, base: catalog.balanced, retainedHistoryCount: 0))
            },
        )
        await model.load()

        await model.setHistoryRetention(.thirtyDays)

        #expect(model.operationState == .failed)
        #expect(model.canRetryLastChange)

        model.requestResetAllConfirmation()
        await model.confirmPendingDestructiveOperation()

        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)
        #expect(model.privacyOperation == .resetSucceeded)

        await model.retryLastChange()

        #expect(applyCalls == 1)
    }

    @Test("Reset success supersedes a temporarily busy preference save and its retry")
    func resetAllClearsBusyApplyState() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        var applyCalls = 0
        let model = privacyModel(
            preferences: original,
            apply: { _ in
                applyCalls += 1
                return .temporarilyBusy
            },
            resetAll: {
                .acknowledged(state(.defaults, base: catalog.balanced, retainedHistoryCount: 0))
            },
        )
        await model.load()

        await model.setHistoryRetention(.thirtyDays)

        #expect(model.operationState == .temporarilyBusy)
        #expect(model.canRetryLastChange)

        model.requestResetAllConfirmation()
        await model.confirmPendingDestructiveOperation()

        #expect(model.operationState == .idle)
        #expect(!model.canRetryLastChange)
        #expect(model.privacyOperation == .resetSucceeded)

        await model.retryLastChange()

        #expect(applyCalls == 1)
    }

    @Test("Busy destructive operation keeps confirmation and retries the exact boundary")
    func destructiveBusyRollbackAndRetry() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        var resetCalls = 0
        let model = privacyModel(
            preferences: original,
            resetAll: {
                resetCalls += 1
                if resetCalls == 1 { return .temporarilyBusy }
                return .acknowledged(state(.defaults, base: catalog.balanced))
            },
        )
        await model.load()
        model.requestResetAllConfirmation()

        await model.confirmPendingDestructiveOperation()

        #expect(model.preferences == original)
        #expect(model.pendingDestructiveOperation == .resetAll)
        #expect(model.privacyOperation == .temporarilyBusy(.resetAll))
        #expect(model.canRetryPrivacyOperation)

        await model.retryPrivacyOperation()

        #expect(resetCalls == 2)
        #expect(model.preferences == .defaults)
        #expect(model.pendingDestructiveOperation == nil)
        #expect(model.privacyOperation == .resetSucceeded)
    }

    @Test("Failed destructive operation preserves data and retries the exact boundary")
    func destructiveFailureRollbackAndRetry() async throws {
        let original = try nonDefaultPreferences()
        let catalog = try SettingsScheduleCatalog.fixture()
        var deleteCalls = 0
        let model = privacyModel(
            preferences: original,
            deleteHistory: {
                deleteCalls += 1
                if deleteCalls == 1 { throw TestFailure.save }
                return .acknowledged(state(original, base: catalog.balanced))
            },
        )
        await model.load()
        model.requestDeleteHistoryConfirmation()

        await model.confirmPendingDestructiveOperation()

        #expect(model.preferences == original)
        #expect(model.pendingDestructiveOperation == .deleteHistory)
        #expect(model.privacyOperation == .failed(.deleteHistory))
        #expect(model.canRetryPrivacyOperation)

        await model.retryPrivacyOperation()

        #expect(deleteCalls == 2)
        #expect(model.preferences == original)
        #expect(model.pendingDestructiveOperation == nil)
        #expect(model.privacyOperation == .historyDeletionSucceeded)
    }
}

private func privacyModel(
    preferences: AppPreferences,
    retainedHistoryCount: Int = 1,
    apply: @escaping (SettingsFeatureMutation) async throws -> SettingsApplyResult = { _ in
        throw TestFailure.save
    },
    exportHistory: @escaping (HistoryExportRequest) async throws -> SettingsHistoryExportResult = { _ in
        throw TestFailure.save
    },
    deleteHistory: @escaping () async throws -> SettingsDestructiveResult = {
        throw TestFailure.save
    },
    resetAll: @escaping () async throws -> SettingsDestructiveResult = {
        throw TestFailure.save
    },
) -> SettingsFeatureModel {
    let catalog = fixtureCatalog()
    return SettingsFeatureModel(
        client: SettingsFeatureClient(
            load: { state(
                preferences,
                base: catalog.balanced,
                retainedHistoryCount: retainedHistoryCount,
            ) },
            apply: apply,
            exportHistory: exportHistory,
            deleteHistory: deleteHistory,
            resetAll: resetAll,
        ),
        catalog: catalog,
    )
}

private func state(
    _ preferences: AppPreferences,
    base: ProtocolConfiguration,
    retainedHistoryCount: Int = 1,
) -> SettingsFeatureState {
    SettingsFeatureState(
        preferences: preferences,
        configuration: preferences.protocolConfiguration(applyingTo: base),
        retainedHistoryCount: retainedHistoryCount,
    )
}

private func expectEveryPreferenceExceptRetention(
    _ actual: AppPreferences,
    equals original: AppPreferences,
) {
    #expect(actual.schedule == original.schedule)
    #expect(actual.content == original.content)
    #expect(actual.context == original.context)
    #expect(actual.accessibility == original.accessibility)
    #expect(actual.integrations == original.integrations)
    #expect(actual.formatVersion == original.formatVersion)
}

private final class PrivacyOperationGate<Result: Sendable> {
    private var startedContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<Result, Never>?
    private var hasStarted = false

    func wait() async -> Result {
        hasStarted = true
        startedContinuation?.resume()
        startedContinuation = nil
        return await withCheckedContinuation { resultContinuation = $0 }
    }

    func waitUntilStarted() async {
        if hasStarted { return }
        await withCheckedContinuation { startedContinuation = $0 }
    }

    func finish(with result: Result) {
        resultContinuation?.resume(returning: result)
        resultContinuation = nil
    }
}

// swiftlint:enable file_length
