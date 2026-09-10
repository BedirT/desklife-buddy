import FeatureLocalization
import Foundation

enum SettingsPrivacyL10n {
    static let storedOnThisMac = string(
        "settings.privacy.stored.title",
        default: "Stored on this Mac",
    )
    static let storedDetail = string(
        "settings.privacy.stored.detail",
        default: "A complete view of the local records this build keeps.",
    )
    static let localStorageSummary = string(
        "settings.privacy.local_summary",
        default: "No account or cloud sync. You choose how long history stays here.",
    )
    static let whatIsStored = string(
        "settings.privacy.stored.disclosure_title",
        default: "What is stored",
    )
    static let whatIsStoredDetail = string(
        "settings.privacy.stored.disclosure_detail",
        default: "See the local records this app keeps.",
    )
    static let preferencesTitle = string(
        "settings.privacy.stored.preferences.title",
        default: "Preferences & configuration",
    )
    static let preferencesDetail = string(
        "settings.privacy.stored.preferences.detail",
        default: "Schedule, break content, exclusions, accessibility, integration choices, the exact clock configuration, a setup-completion marker with its outcome and time, and the app's notification prompt and authorization history.",
    )
    static let timingTitle = string(
        "settings.privacy.stored.timing.title",
        default: "Current timing & recovery state",
    )
    static let timingDetail = string(
        "settings.privacy.stored.timing.detail",
        default: "Visual and movement timing, snoozes, recovery, and limited session state needed to continue after relaunch.",
    )
    static let opportunityHistoryTitle = string(
        "settings.privacy.stored.history.title",
        default: "Opportunity history",
    )
    static let opportunityHistoryDetail = string(
        "settings.privacy.stored.history.detail",
        default: "Retained records contain six fields: identifier, recorded time, kind, source, opportunity, and selected duration.",
    )
    static let estimatedActiveUseHistoryTitle = string(
        "settings.privacy.stored.active_use.title",
        default: "Estimated active-use history",
    )
    static let estimatedActiveUseHistoryDetail = string(
        "settings.privacy.stored.active_use.detail",
        default: "Retained records contain the start and end time of each estimated active-use run used by Weekly.",
    )
    static let storedBoundary = string(
        "settings.privacy.stored.boundary",
        default: "Reset app data clears the app's notification prompt and authorization history, but keeps the setup-completion marker and does not change macOS permissions.",
    )
    static let historyTitle = string(
        "settings.privacy.history.title",
        default: "History",
    )
    static let historyDetail = string(
        "settings.privacy.history.detail",
        default: "Choose what stays on this Mac and manage it here.",
    )
    static let keepHistoryFor = string(
        "settings.privacy.retention.label",
        default: "Keep history for",
    )
    static let thirtyDays = string("settings.privacy.retention.thirty.title", default: "30 days")
    static let thirtyDaysDetail = string(
        "settings.privacy.retention.thirty.detail",
        default: "Keep the most recent 30 days.",
    )
    static let ninetyDays = string("settings.privacy.retention.ninety.title", default: "90 days")
    static let ninetyDaysDetail = string(
        "settings.privacy.retention.ninety.detail",
        default: "Keep the most recent 90 days.",
    )
    static let keepNothing = string(
        "settings.privacy.retention.none.title",
        default: "Keep nothing",
    )
    static let keepNothingDetail = string(
        "settings.privacy.retention.none.detail",
        default: "Do not retain Weekly active-use runs or opportunity history.",
    )
    static let applyingRetention = string(
        "settings.privacy.retention.applying",
        default: "Applying the new history-retention choice…",
    )
    static let noHistoryTitle = string(
        "settings.privacy.history.empty.title",
        default: "No retained opportunity history",
    )
    static let noHistoryKeepNothing = string(
        "settings.privacy.history.empty.keep_nothing",
        default: "Keep nothing is selected. New Weekly active-use runs and opportunity events are not stored.",
    )
    static let noHistoryCleared = string(
        "settings.privacy.history.empty.cleared",
        default: "Opportunity history is empty right now. New active-use runs and opportunity events follow the selected retention period.",
    )
    static let exportHistory = string(
        "settings.privacy.export.title",
        default: "Export history",
    )
    static let exportHistoryDetail = string(
        "settings.privacy.export.detail",
        default: "Review the included fields before choosing a destination.",
    )
    static let reviewExport = string(
        "settings.privacy.export.review",
        default: "Review export…",
    )
    static let dataControls = string(
        "settings.privacy.controls.title",
        default: "Data controls",
    )
    static let dataControlsDetail = string(
        "settings.privacy.controls.detail",
        default: "Reset local data and restore the default schedule.",
    )
    static let deleteHistory = string(
        "settings.privacy.delete.title",
        default: "Delete history…",
    )
    static let deleteHistoryDetail = string(
        "settings.privacy.delete.detail",
        default: "Removes retained Weekly active-use runs and opportunity history. Preferences and current timing state remain.",
    )
    static let resetAll = string("settings.privacy.reset.title", default: "Reset app data…")
    static let resetAllDetail = string(
        "settings.privacy.reset.detail",
        default: "Removes history, app preferences, current timing state, and the app's notification prompt and authorization history, then restores Balanced defaults. The setup-completion marker and macOS permissions remain.",
    )
}

extension SettingsPrivacyL10n {
    static let reviewExportTitle = string(
        "settings.privacy.export.review_title",
        default: "Your history export",
    )
    static let reviewExportDetail = string(
        "settings.privacy.export.review_detail",
        default: "Review what the file will contain before choosing a destination.",
    )
    static let exportHistorySummaryTitle = string(
        "settings.privacy.export.summary_title",
        default: "Local history",
    )
    static let exportReadyStatus = string(
        "settings.privacy.export.ready_status",
        default: "Ready to export",
    )
    static let exportNeedsColumnsStatus = string(
        "settings.privacy.export.needs_columns_status",
        default: "Select columns",
    )
    static let exportContains = string(
        "settings.privacy.export.contains",
        default: "Contains",
    )
    static let exportContainsDetail = string(
        "settings.privacy.export.contains_detail",
        default: "Retained opportunity history",
    )
    static let exportExcludes = string(
        "settings.privacy.export.excludes",
        default: "Excludes",
    )
    static let exportExcludesDetail = string(
        "settings.privacy.export.excludes_detail",
        default: "Weekly active-use runs, preferences, exclusions, integration choices, current timing state, and other settings",
    )
    static let csv = string("settings.privacy.export.csv", default: "CSV")
    static let json = string("settings.privacy.export.json", default: "JSON")
    static let exportFormat = string(
        "settings.privacy.export.format",
        default: "Format",
    )
    static let exportColumns = string(
        "settings.privacy.export.columns",
        default: "Columns",
    )
    static let chooseExportDestination = string(
        "settings.privacy.export.choose_destination",
        default: "Choose destination…",
    )
    static let exportExpandColumnsHint = string(
        "settings.privacy.export.columns.expand_hint",
        default: "Show the available history columns.",
    )
    static let exportCollapseColumnsHint = string(
        "settings.privacy.export.columns.collapse_hint",
        default: "Hide the available history columns.",
    )
    static let exportSelectAtLeastOneColumn = string(
        "settings.privacy.export.columns.required",
        default: "Select at least one column.",
    )
    static let cancel = string("settings.privacy.cancel", default: "Cancel")
    static let exporting = string("settings.privacy.export.exporting", default: "Exporting history…")
    static let exportFailed = string(
        "settings.privacy.export.failed",
        default: "History wasn't exported. No file was saved.",
    )
    static let exportTemporarilyBusy = string(
        "settings.privacy.export.busy",
        default: "A break is in progress. Finish or dismiss it, then try the export again.",
    )
    static let deletingHistory = string(
        "settings.privacy.delete.deleting",
        default: "Deleting retained history…",
    )
    static let deleteFailed = string(
        "settings.privacy.delete.failed",
        default: "History wasn't deleted. Your existing data remains.",
    )
    static let deleteTemporarilyBusy = string(
        "settings.privacy.delete.busy",
        default: "A break is in progress. Finish or dismiss it, then try deleting history again.",
    )
    static let resettingAll = string(
        "settings.privacy.reset.resetting",
        default: "Resetting history and app preferences…",
    )
    static let resetFailed = string(
        "settings.privacy.reset.failed",
        default: "Local data wasn't reset. Your existing data and settings remain.",
    )
    static let resetTemporarilyBusy = string(
        "settings.privacy.reset.busy",
        default: "A break is in progress. Finish or dismiss it, then try the reset again.",
    )
    static let deleteHistoryAction = string(
        "settings.privacy.delete.action",
        default: "Delete history",
    )
    static let resetAllAction = string(
        "settings.privacy.reset.action",
        default: "Reset app data",
    )
}

extension SettingsPrivacyL10n {
    static let exportIDTitle = string(
        "settings.privacy.export.field.id.title",
        default: "Identifier",
    )
    static let exportRecordedAtTitle = string(
        "settings.privacy.export.field.recorded_at.title",
        default: "Recorded time",
    )
    static let exportKindTitle = string(
        "settings.privacy.export.field.kind.title",
        default: "Event kind",
    )
    static let exportSourceTitle = string(
        "settings.privacy.export.field.source.title",
        default: "Source",
    )
    static let exportOpportunityTitle = string(
        "settings.privacy.export.field.opportunity.title",
        default: "Opportunity",
    )
    static let exportSelectedDurationTitle = string(
        "settings.privacy.export.field.selected_duration.title",
        default: "Selected duration",
    )

    static let exportIDExplanation = string(
        "settings.privacy.export.field.id",
        default: "A random identifier for this local record.",
    )
    static let exportRecordedAtExplanation = string(
        "settings.privacy.export.field.recorded_at",
        default: "The date and time when the event was recorded.",
    )
    static let exportKindExplanation = string(
        "settings.privacy.export.field.kind",
        default: "The event type, such as presented, started, skipped, or completed.",
    )
    static let exportSourceExplanation = string(
        "settings.privacy.export.field.source",
        default: "What created the event: the local timer, an action you took, or available system context.",
    )
    static let exportOpportunityExplanation = string(
        "settings.privacy.export.field.opportunity",
        default: "Whether the event belongs to a visual reset, movement, position change, or recovery, when applicable.",
    )
    static let exportSelectedDurationExplanation = string(
        "settings.privacy.export.field.selected_duration",
        default: "The break duration you selected, in seconds, when applicable.",
    )
    static let deleteHistoryConfirmationTitle = string(
        "settings.privacy.delete.confirmation_title",
        default: "Delete all break history?",
    )
    static let deleteHistoryConfirmationBody = string(
        "settings.privacy.delete.confirmation_body",
        default: "This deletes retained opportunity events and Weekly history. Your schedule, content choices, exclusions, accessibility, integrations, and current timers remain.",
    )
    static let historyDeletedAcknowledgement = string(
        "settings.privacy.delete.acknowledgement",
        default: "History deleted. Your settings and current timers were kept.",
    )
    static let resetAllConfirmationTitle = string(
        "settings.privacy.reset.confirmation_title",
        default: "Reset history and app preferences?",
    )
    static let resetAllConfirmationBody = string(
        "settings.privacy.reset.confirmation_body",
        default: "This deletes history and every app preference, including exclusions, integration choices, and the app's notification prompt and authorization history. The Balanced schedule is restored. The setup-completion marker is kept so setup does not reopen. macOS permissions are not changed.",
    )
    static let resetAllAcknowledgement = string(
        "settings.privacy.reset.acknowledgement",
        default: "History, app preferences, and the app's notification prompt and authorization history were reset. Balanced is now selected. The setup-completion marker and macOS permissions were not changed.",
    )

    static func exportSucceeded(destinationName: String) -> String {
        format(
            "settings.privacy.export.acknowledgement",
            default: "History exported as %@.",
            destinationName,
        )
    }

    static func exportEventCount(_ count: Int) -> String {
        if count == 1 {
            return format(
                "settings.privacy.export.event_count.one",
                default: "%lld event",
                Int64(count),
            )
        }
        return format(
            "settings.privacy.export.event_count.other",
            default: "%lld events",
            Int64(count),
        )
    }

    static func exportSelectedColumnCount(_ selected: Int, total: Int) -> String {
        format(
            "settings.privacy.export.columns.selected_count",
            default: "%lld of %lld selected",
            Int64(selected),
            Int64(total),
        )
    }

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }

    private static func format(
        _ key: String,
        default value: String,
        _ arguments: CVarArg...,
    ) -> String {
        String(format: string(key, default: value), locale: .current, arguments: arguments)
    }
}
