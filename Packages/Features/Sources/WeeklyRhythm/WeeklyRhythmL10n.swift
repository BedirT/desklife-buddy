import Domain
import Foundation

enum WeeklyRhythmL10n {
    static let title = string("weekly.title", default: "Weekly rhythm")
    static let subtitle = string(
        "weekly.subtitle",
        default: "Rhythm and gaps in retained active-use facts",
    )
    static let activeComputerUse = string(
        "weekly.active_computer_use",
        default: "estimated active computer use",
    )
    static let rhythmTitle = string("weekly.rhythm.title", default: "When active use showed up")
    static let rhythmDetail = string(
        "weekly.rhythm.detail",
        default: "Each named cell is retained timing only.",
    )
    static let gapNote = string(
        "weekly.rhythm.gap_note",
        default: "Open space means no retained active-use run. It is not proof of movement or a break.",
    )
    static let longestRun = string("weekly.longest_run", default: "Longest retained run")
    static let recordedFacts = string("weekly.recorded_facts", default: "Recorded facts")
    static let timingOnly = string(
        "weekly.longest_run.detail",
        default: "Recorded as timing only. No interpretation is added.",
    )
    static let opportunityFacts = string(
        "weekly.opportunity_facts",
        default: "Recorded opportunities",
    )
    static let opportunityDetail = string(
        "weekly.opportunity_facts.detail",
        default: "Exact presentation and timer facts",
    )
    static let choiceFacts = string("weekly.choice_facts", default: "You chose")
    static let choiceDetail = string(
        "weekly.choice_facts.detail",
        default: "Only explicit actions you took",
    )
    static let contextFacts = string("weekly.context_facts", default: "Available context")
    static let contextDetail = string(
        "weekly.context_facts.detail",
        default: "Generic signals only, with no app or event names",
    )
    static let noFacts = string("weekly.no_facts", default: "No retained facts")
    static let sparseTitle = string("weekly.sparse.title", default: "Nothing much to show yet")
    static let sparseDetail = string(
        "weekly.sparse.detail",
        default: "This first view stays literal while history fills in.",
    )
    static let emptyTitle = string("weekly.empty.title", default: "No retained facts this week")
    static let emptyDetail = string(
        "weekly.empty.detail",
        default: "There is no activity or opportunity history to describe for this interval.",
    )
    static let historyDisabledTitle = string(
        "weekly.history_disabled.title",
        default: "Weekly history is off",
    )
    static let historyDisabledDetail = string(
        "weekly.history_disabled.detail",
        default: "No activity or opportunity history is kept.",
    )
    static let reviewHistory = string(
        "weekly.history_disabled.action",
        default: "Review history setting",
    )
    static let adjustTitle = string("weekly.adjust.title", default: "Adjust the fit")
    static let adjustDetail = string(
        "weekly.adjust.detail",
        default: "Your current schedule is context, not a target.",
    )
    static let reviewSchedule = string("weekly.adjust.action", default: "Review schedule")
    static let workingHoursOnly = string(
        "weekly.schedule.working_hours",
        default: "working hours only",
    )
    static let allHours = string("weekly.schedule.all_hours", default: "all hours")
    static let loading = string("weekly.loading", default: "Reading retained Weekly facts…")
    static let loadFailedTitle = string("weekly.failure.title", default: "Weekly could not be read")
    static let loadFailedDetail = string(
        "weekly.failure.detail",
        default: "Nothing was inferred or replaced with an empty week.",
    )
    static let tryAgain = string("weekly.failure.action", default: "Try again")
    static let noRetainedActiveUse = string(
        "weekly.cell.empty_accessibility",
        default: "no retained active use",
    )

    static func daypart(_ daypart: WeeklyDaypart) -> String {
        switch daypart {
        case .overnight: string("weekly.daypart.overnight", default: "Overnight")
        case .morning: string("weekly.daypart.morning", default: "Morning")
        case .afternoon: string("weekly.daypart.afternoon", default: "Afternoon")
        case .evening: string("weekly.daypart.evening", default: "Evening")
        }
    }

    static func estimatedDuration(_ seconds: TimeInterval) -> String {
        format(
            "weekly.estimated_duration",
            default: "%@ estimated",
            duration(seconds),
        )
    }

    static func count(_ count: Int) -> String {
        format("weekly.count", default: "%d", count)
    }

    static func countAndOpportunity(_ count: Int, _ opportunity: OpportunityType?) -> String {
        guard let opportunity else { return self.count(count) }
        return format(
            "weekly.count_opportunity",
            default: "%d %@",
            count,
            opportunityTitle(opportunity),
        )
    }

    static func selectedDuration(_ seconds: TimeInterval?) -> String? {
        seconds.map(duration)
    }

    static func eventTitle(_ kind: OpportunityEventKind) -> String {
        switch kind {
        case .promptPresented: string("weekly.event.prompt_presented", default: "Shown")
        case .timerFinished: string("weekly.event.timer_finished", default: "Timer finished")
        case .breakStarted: string("weekly.event.break_started", default: "Started")
        case .userDeclaredCompleted: string("weekly.event.declared_completed", default: "Marked done")
        case .userDeclaredAlreadyMoved: string("weekly.event.already_moved", default: "Marked already moved")
        case .positionChanged: string("weekly.event.position_changed", default: "Position change selected")
        case .snoozed: string("weekly.event.snoozed", default: "Snoozed")
        case .skipped: string("weekly.event.skipped", default: "Skipped")
        case .notAppropriate: string("weekly.event.not_appropriate", default: "Not appropriate selected")
        case .likelyNaturalInterruption: string("weekly.event.system_context", default: "System context recorded")
        }
    }

    static func contextTitle(_ fact: WeeklyContextFact) -> String {
        switch fact.kind {
        case .notAppropriate:
            string("weekly.context.not_appropriate", default: "Not appropriate")
        case .likelyNaturalInterruption:
            string("weekly.context.system", default: "System context")
        default:
            eventTitle(fact.kind)
        }
    }

    static func contextDetail(_ fact: WeeklyContextFact) -> String {
        let source: String = switch fact.source {
        case .calendarBusyFree:
            string("weekly.context.source.calendar", default: "Calendar busy/free")
        case .focusFilter:
            string("weekly.context.source.focus", default: "Focus")
        case .systemContext:
            string("weekly.context.source.system", default: "System context")
        case .localTimer:
            string("weekly.context.source.timer", default: "Local timer")
        case .user:
            string("weekly.context.source.user", default: "You")
        case .companionFuture:
            string("weekly.context.source.companion", default: "Companion")
        }
        return format(
            "weekly.context.detail_format",
            default: "%@ · %@",
            source,
            daypart(fact.daypart).lowercased(),
        )
    }

    static func scheduleProfile(_ id: ProtocolProfileID) -> String {
        switch id {
        case .gentle: string("settings.profile.gentle", default: "Gentle")
        case .balanced: string("settings.profile.balanced", default: "Balanced")
        case .frequentMovement: string("settings.profile.frequent", default: "Frequent movement")
        case .researchInformedHighFrequency:
            string("settings.profile.research_informed", default: "Research-informed")
        case .custom:
            string("settings.profile.custom", default: "Custom")
        }
    }

    static func cellAccessibility(day: String, daypart: String, duration: String?) -> String {
        format(
            "weekly.cell.accessibility",
            default: "%@, %@, %@",
            day,
            daypart,
            duration ?? noRetainedActiveUse,
        )
    }

    private static func opportunityTitle(_ opportunity: OpportunityType) -> String {
        switch opportunity {
        case .visual: string("weekly.opportunity.visual", default: "visual")
        case .movement: string("weekly.opportunity.movement", default: "movement")
        case .positionChange: string("weekly.opportunity.position", default: "position change")
        case .recovery: string("weekly.opportunity.recovery", default: "recovery")
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int(seconds.rounded()) / 60)
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0, remainder > 0 {
            return format("weekly.duration.hours_minutes", default: "%dh %dm", hours, remainder)
        }
        if hours > 0 {
            return format("weekly.duration.hours", default: "%dh", hours)
        }
        return format("weekly.duration.minutes", default: "%dm", minutes)
    }

    private static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }

    private static func format(
        _ key: String,
        default defaultValue: String,
        _ arguments: CVarArg...,
    ) -> String {
        String(
            format: string(key, default: defaultValue),
            locale: .current,
            arguments: arguments,
        )
    }
}
