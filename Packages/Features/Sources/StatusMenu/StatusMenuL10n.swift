import Domain
import FeatureLocalization
import Foundation

enum StatusMenuL10n {
    static let visualReset = string("status_menu.visual_reset", default: "Visual reset")
    static let movement = string("status_menu.movement", default: "Movement")
    static let positionChange = string("status_menu.position_change", default: "Position change")
    static let recoverySuggestion = string(
        "status_menu.recovery_suggestion",
        default: "Recovery suggestion",
    )
    static let due = string("status_menu.due", default: "Due")
    static let startNow = string("status_menu.start_now", default: "Start now")
    static let later = string("status_menu.later", default: "Later")
    static let moreOptions = string("status_menu.more_options", default: "More options")
    static let snoozeFiveMinutes = string("status_menu.snooze_five_minutes", default: "5 minutes")
    static let snoozeTenMinutes = string("status_menu.snooze_ten_minutes", default: "10 minutes")
    static let snoozeFifteenMinutes = string("status_menu.snooze_fifteen_minutes", default: "15 minutes")
    static let startVisualReset = string("status_menu.start_visual_reset", default: "Start a visual reset")
    static let startMovement = string("status_menu.start_movement", default: "Start movement")
    static let movementRecommended = string("status_menu.movement_recommended", default: "5 minutes")
    static let movementQuick = string("status_menu.movement_quick", default: "2 minutes")
    static let movementPosition = string("status_menu.movement_position", default: "Position change")
    static let pause = string("status_menu.pause", default: "Pause")
    static let resume = string("status_menu.resume", default: "Resume")
    static let pauseThirtyMinutes = string("status_menu.pause_thirty_minutes", default: "For 30 minutes")
    static let pauseOneHour = string("status_menu.pause_one_hour", default: "For 1 hour")
    static let pauseRestOfDay = string("status_menu.pause_rest_of_day", default: "For the rest of the day")
    static let pauseUntilResume = string("status_menu.pause_until_resume", default: "Until I resume")
    static let presenting = string("status_menu.presenting", default: "Presenting")
    static let workingHoursOnly = string("status_menu.working_hours_only", default: "Only during working hours")
    static let weeklyRhythm = string("status_menu.weekly_rhythm", default: "Weekly rhythm…")
    static let settings = string("status_menu.settings", default: "Settings…")
    static let quit = string("status_menu.quit", default: "Quit")
    static let statePaused = string("status_menu.state.paused", default: "Paused")
    static let stateOnHold = string("status_menu.state.on_hold", default: "On hold")
    static let stateQuiet = string("status_menu.state.quiet", default: "Quiet")
    static let stateInProgress = string("status_menu.state.in_progress", default: "In progress")
    static let stateHeadsUpOff = string("status_menu.state.heads_up_off", default: "Heads-up off")
    static let countingPaused = string(
        "status_menu.state.counting_paused",
        default: "Counting is paused.",
    )
    static let countingContinues = string(
        "status_menu.state.counting_continues",
        default: "Counting continues. Reminders resume on their own.",
    )
    static let headsUpOffDetail = string(
        "status_menu.state.heads_up_off_detail",
        default: "Reminders stay in the menu. Turn heads-up back on in Settings.",
    )
    static let ritualVisualStarted = string(
        "status_menu.ritual.visual_started",
        default: "You started a visual reset.",
    )
    static let ritualMovementStarted = string(
        "status_menu.ritual.movement_started",
        default: "You started movement.",
    )
    static let ritualMergedStarted = string(
        "status_menu.ritual.merged_started",
        default: "You started a break.",
    )
    static let clockInProgress = string("status_menu.clock.in_progress", default: "In progress")
    static let dockVisualDue = string("status_menu.dock.visual_due", default: "Visual reset due")
    static let dockMovementDue = string("status_menu.dock.movement_due", default: "Movement due")
    static let dockBothDue = string("status_menu.dock.both_due", default: "Visual reset and movement due")
    static let dockHeadsUpOff = string(
        "status_menu.dock.heads_up_off",
        default: "Heads-up off (menu only)",
    )
    static let accessibilityLabel = string("status_menu.accessibility_label", default: "Break status")

    static func onHoldDetail(_ reason: String) -> String {
        format("status_menu.state.on_hold_format", default: "On hold: %@", reason)
    }

    static func whyNow(label: String, minutes: Int) -> String {
        format(
            "status_menu.why_now_format",
            default: "%@ due after about %d minutes of estimated active use.",
            label,
            minutes,
        )
    }
    static func next(aboutMinutes: Int) -> String {
        format("status_menu.next_format", default: "Next: about %d minutes", aboutMinutes)
    }

    static func estimatedActiveUse(minutes: Int) -> String {
        format(
            "status_menu.estimated_active_use_format",
            default: "%d minutes of estimated active computer use",
            minutes,
        )
    }

    static func suppression(
        _ reason: SuppressionReason,
        manualPause: StatusMenuManualPause? = nil,
    ) -> String {
        switch reason {
        case .manualPause:
            switch manualPause {
            case let .until(date):
                format(
                    "status_menu.suppression.manual_pause_until_format",
                    default: "Paused until %@",
                    DateFormatter.localizedString(
                        from: date,
                        dateStyle: .none,
                        timeStyle: .short,
                    ),
                )
            case .untilResume:
                string("status_menu.suppression.manual_pause", default: "Paused until you resume")
            case nil:
                string("status_menu.suppression.manual_pause_generic", default: "Paused")
            }
        case .systemInactiveOrLocked:
            string("status_menu.suppression.system_inactive", default: "Quiet while the Mac is inactive")
        case .explicitPresentationMode:
            string("status_menu.suppression.presentation", default: "Presenting, reminders off")
        case .focusFilter:
            string("status_menu.suppression.focus", default: "Quiet in Focus")
        case .calendarBusy:
            string("status_menu.suppression.calendar", default: "Quiet during Calendar busy time")
        case .excludedApplication:
            string("status_menu.suppression.excluded_app", default: "Quiet in this app")
        case .outsideWorkingHours:
            string("status_menu.suppression.outside_hours", default: "Outside working hours")
        case .userDeclaredMeetingOrCall:
            string("status_menu.suppression.manual_meeting", default: "In a meeting you marked")
        case .userDeclaredScreenSharingOrPresentation:
            string("status_menu.suppression.manual_presenting", default: "Presenting you marked")
        case .userSelectedTimedTask:
            string("status_menu.suppression.manual_timed_focus", default: "In timed focus you marked")
        case .snooze:
            string("status_menu.suppression.snooze", default: "Snoozed")
        case .lowFrictionWait:
            string("status_menu.suppression.low_friction", default: "Waiting for a pause")
        }
    }

    static func clockLabel(_ opportunity: OpportunityType) -> String {
        switch opportunity {
        case .visual: visualReset
        case .movement: movement
        case .positionChange: positionChange
        case .recovery: recoverySuggestion
        }
    }

    static func accessibilityClock(_ summary: StatusClockSummary) -> String {
        let label = clockLabel(summary.opportunity)
        if summary.isRunning {
            return format(
                "status_menu.accessibility_in_progress_format",
                default: "%@ in progress.",
                label,
            )
        }
        return switch summary.timing {
        case let .next(aboutMinutes):
            format(
                "status_menu.accessibility_next_format",
                default: "%@ in about %d minutes.",
                label,
                aboutMinutes,
            )
        case .due:
            format(
                "status_menu.accessibility_due_format",
                default: "%@ due.",
                label,
            )
        }
    }

    static func accessibilityEstimatedActiveUse(minutes: Int) -> String {
        format(
            "status_menu.accessibility_estimated_active_use_format",
            default: "Estimated active computer use, %d minutes.",
            minutes,
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
        String(
            format: string(key, default: value),
            locale: .current,
            arguments: arguments,
        )
    }
}

/// Localized labels shared with AppKit's native menu composition.
public enum StatusMenuCopy {
    public static let startNow = StatusMenuL10n.startNow
    public static let later = StatusMenuL10n.later
    public static let moreOptions = StatusMenuL10n.moreOptions
    public static let snoozeFiveMinutes = StatusMenuL10n.snoozeFiveMinutes
    public static let snoozeTenMinutes = StatusMenuL10n.snoozeTenMinutes
    public static let snoozeFifteenMinutes = StatusMenuL10n.snoozeFifteenMinutes
    public static let startVisualReset = StatusMenuL10n.startVisualReset
    public static let startMovement = StatusMenuL10n.startMovement
    public static let movementRecommended = StatusMenuL10n.movementRecommended
    public static let movementQuick = StatusMenuL10n.movementQuick
    public static let movementPosition = StatusMenuL10n.movementPosition
    public static let pause = StatusMenuL10n.pause
    public static let resume = StatusMenuL10n.resume
    public static let pauseThirtyMinutes = StatusMenuL10n.pauseThirtyMinutes
    public static let pauseOneHour = StatusMenuL10n.pauseOneHour
    public static let pauseRestOfDay = StatusMenuL10n.pauseRestOfDay
    public static let pauseUntilResume = StatusMenuL10n.pauseUntilResume
    public static let presenting = StatusMenuL10n.presenting
    public static let workingHoursOnly = StatusMenuL10n.workingHoursOnly
    public static let weeklyRhythm = StatusMenuL10n.weeklyRhythm
    public static let settings = StatusMenuL10n.settings
    public static let quit = StatusMenuL10n.quit
    public static let accessibilityLabel = StatusMenuL10n.accessibilityLabel

    /// Text headline for the state bucket, or nil when the two clock rows
    /// already tell the story (operating and plain due states).
    public static func stateHeadline(for snapshot: StatusMenuSnapshot) -> String? {
        switch snapshot.glyph {
        case .paused: StatusMenuL10n.statePaused
        case .held: StatusMenuL10n.stateOnHold
        case .protected: StatusMenuL10n.stateQuiet
        case .acceptedRitual: StatusMenuL10n.stateInProgress
        case .degraded: StatusMenuL10n.stateHeadsUpOff
        case .operating, .visualDue, .movementDue, .bothDue: nil
        }
    }

    /// What counting does under a suppression reason. Mirrors
    /// SuppressionReason's accumulation policy; the switch is exhaustive so
    /// a new reason fails to compile here, not silently.
    public static func countingLine(for reason: SuppressionReason) -> String {
        switch reason {
        case .manualPause, .systemInactiveOrLocked, .outsideWorkingHours:
            StatusMenuL10n.countingPaused
        case .explicitPresentationMode, .focusFilter, .calendarBusy,
             .excludedApplication, .userDeclaredMeetingOrCall,
             .userDeclaredScreenSharingOrPresentation, .userSelectedTimedTask,
             .snooze, .lowFrictionWait:
            StatusMenuL10n.countingContinues
        }
    }

    /// What changed: names the accepted ritual that is running.
    public static func ritualLine(for snapshot: StatusMenuSnapshot) -> String? {
        guard snapshot.glyph == .acceptedRitual else { return nil }
        let visual = snapshot.visual.isRunning
        let movement = snapshot.movement.isRunning
        if visual, !movement {
            return StatusMenuL10n.ritualVisualStarted
        }
        if movement, !visual {
            return StatusMenuL10n.ritualMovementStarted
        }
        return StatusMenuL10n.ritualMergedStarted
    }

    /// Why now: one line per due clock that is still waiting, naming the
    /// counted minutes behind it. Suppressed clocks stay quiet instead.
    public static func whyNowLines(for snapshot: StatusMenuSnapshot) -> [String] {
        guard snapshot.activeSuppression == nil else { return [] }
        return [snapshot.visual, snapshot.movement].compactMap { summary in
            guard summary.timing == .due, !summary.isRunning else { return nil }
            return StatusMenuL10n.whyNow(
                label: StatusMenuL10n.clockLabel(summary.opportunity),
                minutes: summary.activeUseMinutes,
            )
        }
    }

    /// Dock parity line: the same truth as the region headline, shortened to
    /// one menu item. Nil only for plain operating, which keeps today's menu.
    public static func dockStateTitle(for snapshot: StatusMenuSnapshot) -> String? {
        switch snapshot.glyph {
        case .operating: return nil
        case .paused:
            guard let reason = snapshot.activeSuppression else { return StatusMenuL10n.statePaused }
            return StatusMenuL10n.suppression(reason, manualPause: snapshot.manualPause)
        case .held:
            guard let reason = snapshot.activeSuppression else { return StatusMenuL10n.stateOnHold }
            return StatusMenuL10n.onHoldDetail(StatusMenuL10n.suppression(
                reason,
                manualPause: snapshot.manualPause,
            ))
        case .protected:
            // Protected reasons name the quiet themselves ("Quiet during ..."),
            // so the Dock line stays verbatim instead of stuttering a prefix.
            guard let reason = snapshot.activeSuppression else { return StatusMenuL10n.stateQuiet }
            return StatusMenuL10n.suppression(reason, manualPause: snapshot.manualPause)
        case .acceptedRitual:
            return ritualLine(for: snapshot) ?? StatusMenuL10n.ritualMergedStarted
        case .degraded: return StatusMenuL10n.dockHeadsUpOff
        case .visualDue: return StatusMenuL10n.dockVisualDue
        case .movementDue: return StatusMenuL10n.dockMovementDue
        case .bothDue: return StatusMenuL10n.dockBothDue
        }
    }

    public static func accessibilityValue(for snapshot: StatusMenuSnapshot) -> String {
        var components: [String] = []
        if let headline = stateHeadline(for: snapshot) {
            components.append(headline + ".")
        }
        components += [
            StatusMenuL10n.accessibilityClock(snapshot.visual),
            StatusMenuL10n.accessibilityClock(snapshot.movement),
            StatusMenuL10n.accessibilityEstimatedActiveUse(
                minutes: snapshot.estimatedActiveUseMinutes,
            ),
        ]
        if let suppression = snapshot.activeSuppression {
            components.append(
                StatusMenuL10n.suppression(
                    suppression,
                    manualPause: snapshot.manualPause,
                ) + ".",
            )
        }
        if let ritual = ritualLine(for: snapshot) {
            components.append(ritual)
        }
        if snapshot.glyph == .degraded {
            components.append(StatusMenuL10n.headsUpOffDetail)
        }
        components += whyNowLines(for: snapshot)
        return components.joined(separator: " ")
    }
}
