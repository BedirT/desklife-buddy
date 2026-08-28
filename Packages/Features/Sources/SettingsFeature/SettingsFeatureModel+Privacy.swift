import Domain
import Foundation

public extension SettingsFeatureModel {
    var historyRetention: HistoryRetentionPolicy? {
        preferences?.historyRetention
    }

    var storedDataSummary: [SettingsStoredDataSummaryItem] {
        SettingsStoredDataID.allCases.map(SettingsStoredDataSummaryItem.init(id:))
    }

    var exportedDataCategories: [SettingsExportedDataCategory] {
        [.opportunityHistory]
    }

    var exportFieldDisclosures: [SettingsExportFieldDisclosure] {
        [
            SettingsExportFieldDisclosure(
                field: .id,
                explanation: SettingsPrivacyL10n.exportIDExplanation,
            ),
            SettingsExportFieldDisclosure(
                field: .recordedAt,
                explanation: SettingsPrivacyL10n.exportRecordedAtExplanation,
            ),
            SettingsExportFieldDisclosure(
                field: .kind,
                explanation: SettingsPrivacyL10n.exportKindExplanation,
            ),
            SettingsExportFieldDisclosure(
                field: .source,
                explanation: SettingsPrivacyL10n.exportSourceExplanation,
            ),
            SettingsExportFieldDisclosure(
                field: .opportunity,
                explanation: SettingsPrivacyL10n.exportOpportunityExplanation,
            ),
            SettingsExportFieldDisclosure(
                field: .selectedDurationSeconds,
                explanation: SettingsPrivacyL10n.exportSelectedDurationExplanation,
            ),
        ]
    }

    var exportRequest: HistoryExportRequest? {
        try? HistoryExportRequest(
            format: selectedExportFormat,
            selectedFields: selectedExportFields,
        )
    }

    var canRetryPrivacyOperation: Bool {
        retryPrivacyAction != nil && !privacyOperation.isInProgress
    }

    func presentExportDisclosure() {
        guard canStartPrivacyOperation else { return }
        pendingDestructiveOperation = nil
        isExportDisclosurePresented = true
        privacyOperation = .idle
        retryPrivacyAction = nil
        selectedExportFormat = .csv
        selectedExportFields = Set(HistoryExportField.allCases)
        isExportColumnsExpanded = false
    }

    func setExportFormat(_ format: HistoryExportFormat) {
        guard canEditExportRequest else { return }
        selectedExportFormat = format
    }

    func toggleExportColumns() {
        guard canEditExportRequest else { return }
        isExportColumnsExpanded.toggle()
    }

    func toggleExportField(_ field: HistoryExportField) {
        guard canEditExportRequest else { return }
        if selectedExportFields.contains(field) {
            selectedExportFields.remove(field)
        } else {
            selectedExportFields.insert(field)
        }
    }

    func dismissExportDisclosure() {
        guard !privacyOperation.isInProgress else { return }
        isExportDisclosurePresented = false
        if case .exportSucceeded = privacyOperation { privacyOperation = .idle }
        if case .failed(.exportHistory) = privacyOperation { privacyOperation = .idle }
        if case .temporarilyBusy(.exportHistory) = privacyOperation { privacyOperation = .idle }
        if case .exportHistory = retryPrivacyAction { retryPrivacyAction = nil }
    }

    func exportHistory() async {
        guard let exportRequest else { return }
        await exportHistory(exportRequest)
    }

    private func exportHistory(_ request: HistoryExportRequest) async {
        guard canStartPrivacyOperation, isExportDisclosurePresented else { return }
        retryPrivacyAction = nil
        privacyOperation = .exporting
        do {
            switch try await client.exportHistory(request) {
            case let .saved(destinationName):
                isExportDisclosurePresented = false
                privacyOperation = .exportSucceeded(destinationName: destinationName)
            case .cancelled:
                privacyOperation = .idle
            case .temporarilyBusy:
                retryPrivacyAction = .exportHistory(request)
                privacyOperation = .temporarilyBusy(.exportHistory(request))
            }
        } catch {
            retryPrivacyAction = .exportHistory(request)
            privacyOperation = .failed(.exportHistory(request))
        }
    }

    func requestDeleteHistoryConfirmation() {
        requestConfirmation(for: .deleteHistory)
    }

    func requestResetAllConfirmation() {
        requestConfirmation(for: .resetAll)
    }

    func cancelPendingDestructiveOperation() {
        guard !privacyOperation.isInProgress else { return }
        pendingDestructiveOperation = nil
        if retryPrivacyAction == .deleteHistory || retryPrivacyAction == .resetAll {
            retryPrivacyAction = nil
            privacyOperation = .idle
        }
    }

    func confirmPendingDestructiveOperation() async {
        guard let pendingDestructiveOperation else { return }
        await performDestructiveOperation(pendingDestructiveOperation)
    }

    func retryPrivacyOperation() async {
        guard let action = retryPrivacyAction, !privacyOperation.isInProgress else { return }
        switch action {
        case let .exportHistory(request):
            await exportHistory(request)
        case .deleteHistory:
            await performDestructiveOperation(.deleteHistory)
        case .resetAll:
            await performDestructiveOperation(.resetAll)
        }
    }

    func dismissPrivacyOperationFeedback() {
        guard !privacyOperation.isInProgress, retryPrivacyAction == nil else { return }
        privacyOperation = .idle
    }
}

private extension SettingsFeatureModel {
    var canStartPrivacyOperation: Bool {
        phase == .ready && applyState != .applying && !privacyOperation.isInProgress
    }

    var canEditExportRequest: Bool {
        canStartPrivacyOperation && isExportDisclosurePresented && retryPrivacyAction == nil
    }

    func requestConfirmation(for operation: SettingsDestructiveOperation) {
        guard canStartPrivacyOperation else { return }
        isExportDisclosurePresented = false
        pendingDestructiveOperation = operation
        retryPrivacyAction = nil
        privacyOperation = .idle
    }

    func performDestructiveOperation(_ operation: SettingsDestructiveOperation) async {
        guard canStartPrivacyOperation, pendingDestructiveOperation == operation else { return }
        let action = privacyAction(for: operation)
        retryPrivacyAction = nil
        privacyOperation = operation == .deleteHistory ? .deletingHistory : .resettingAll
        do {
            let result = switch operation {
            case .deleteHistory:
                try await client.deleteHistory()
            case .resetAll:
                try await client.resetAll()
            }
            switch result {
            case let .acknowledged(authoritative):
                publishAcknowledgedState(authoritative, for: operation)
                pendingDestructiveOperation = nil
                privacyOperation = operation == .deleteHistory
                    ? .historyDeletionSucceeded
                    : .resetSucceeded
            case .temporarilyBusy:
                retryPrivacyAction = action
                privacyOperation = .temporarilyBusy(action)
            }
        } catch {
            retryPrivacyAction = action
            privacyOperation = .failed(action)
        }
    }

    func publishAcknowledgedState(
        _ authoritative: SettingsFeatureState,
        for operation: SettingsDestructiveOperation,
    ) {
        switch operation {
        case .deleteHistory:
            preferences = authoritative.preferences
            appliedConfiguration = authoritative.configuration
            retainedHistoryCount = authoritative.retainedHistoryCount
        case .resetAll:
            publishLoadedState(authoritative)
            applyState = .idle
        }
    }

    func privacyAction(for operation: SettingsDestructiveOperation) -> SettingsPrivacyAction {
        switch operation {
        case .deleteHistory: .deleteHistory
        case .resetAll: .resetAll
        }
    }
}
