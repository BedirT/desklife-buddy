import Domain
import Foundation

public enum SettingsPrivacyClientError: Error, Equatable {
    case unavailable
}

public enum SettingsPrivacyControl: CaseIterable, Equatable, Sendable {
    case retention
    case exportHistory
    case deleteHistory
    case resetAll
}

public enum SettingsStoredDataID: CaseIterable, Equatable, Identifiable, Sendable {
    case settingsAndPreferences
    case opportunityHistory
    case estimatedActiveUseHistory
    case excludedApplicationBundleIdentifiers
    case integrationSelections
    case runtimeRecoveryState
    case onboardingCompletionMarker
    case notificationAuthorizationMetadata

    public var id: Self { self }
}

public struct SettingsStoredDataSummaryItem: Equatable, Identifiable, Sendable {
    public let id: SettingsStoredDataID

    public init(id: SettingsStoredDataID) {
        self.id = id
    }
}

public enum SettingsPrivacyRetentionChoice: CaseIterable, Equatable, Hashable, Identifiable, Sendable {
    case thirtyDays
    case ninetyDays
    case keepNothing

    public var id: Self { self }

    public var policy: HistoryRetentionPolicy {
        switch self {
        case .thirtyDays: .thirtyDays
        case .ninetyDays: .ninetyDays
        case .keepNothing: .keepNothing
        }
    }
}

public enum SettingsExportedDataCategory: CaseIterable, Equatable, Sendable {
    case opportunityHistory
}

public enum SettingsHistoryExportResult: Equatable, Sendable {
    case saved(destinationName: String)
    case cancelled
    case temporarilyBusy
}

public enum SettingsDestructiveResult: Equatable, Sendable {
    case acknowledged(SettingsFeatureState)
    case temporarilyBusy
}

public typealias SettingsDestructiveOperation = LocalDataOperation

public struct SettingsExportFieldDisclosure: Equatable, Sendable {
    public let field: HistoryExportField
    public let explanation: String

    public init(
        field: HistoryExportField,
        explanation: String,
    ) {
        self.field = field
        self.explanation = explanation
    }
}

public enum SettingsPrivacyAction: Equatable, Sendable {
    case exportHistory(HistoryExportRequest)
    case deleteHistory
    case resetAll
}

public enum SettingsPrivacyOperation: Equatable, Sendable {
    case idle
    case exporting
    case exportSucceeded(destinationName: String)
    case deletingHistory
    case historyDeletionSucceeded
    case resettingAll
    case resetSucceeded
    case temporarilyBusy(SettingsPrivacyAction)
    case failed(SettingsPrivacyAction)

    var isInProgress: Bool {
        switch self {
        case .exporting, .deletingHistory, .resettingAll:
            true
        case .idle, .exportSucceeded, .historyDeletionSucceeded, .resetSucceeded,
             .temporarilyBusy, .failed:
            false
        }
    }
}

enum SettingsPrivacyFocusTarget: Hashable {
    case reviewExport
    case dataControlsDisclosure
    case requestDeleteHistory
    case requestResetAll
    case cancel
    case format
    case columns
    case field(HistoryExportField)
    case chooseDestination
    case retry
    case confirm

    static let initialModalTarget: Self = .cancel

    static func restoreTarget(
        exportDisclosurePresented: Bool,
        destructiveOperation: SettingsDestructiveOperation?,
    ) -> Self? {
        if exportDisclosurePresented { return .reviewExport }
        switch destructiveOperation {
        case .deleteHistory: return .requestDeleteHistory
        case .resetAll: return .requestResetAll
        case nil: return nil
        }
    }

    static func restorationTarget(
        after operation: SettingsPrivacyOperation,
        fallback: Self?,
    ) -> Self? {
        switch operation {
        case .historyDeletionSucceeded, .resetSucceeded:
            .dataControlsDisclosure
        case .idle, .exporting, .exportSucceeded, .deletingHistory, .resettingAll,
             .temporarilyBusy, .failed:
            fallback
        }
    }

    static func modalTargets(
        isExport: Bool,
        canRetry: Bool,
        columnsExpanded: Bool,
        canChooseDestination: Bool,
    ) -> [Self] {
        if canRetry { return [.cancel, .retry] }
        guard isExport else { return [.cancel, .confirm] }
        let fields = columnsExpanded ? HistoryExportField.allCases.map(Self.field) : []
        let destination: [Self] = canChooseDestination ? [.chooseDestination] : []
        return [.cancel, .format, .columns] + fields + destination
    }

    static func nextModalTarget(
        after current: Self?,
        in targets: [Self],
        reverse: Bool,
    ) -> Self? {
        guard !targets.isEmpty else { return nil }
        guard let current, let currentIndex = targets.firstIndex(of: current) else {
            return reverse ? targets.last : targets.first
        }
        let offset = reverse ? targets.count - 1 : 1
        return targets[(currentIndex + offset) % targets.count]
    }
}
