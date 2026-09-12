import Domain
import FeatureLocalization
import Foundation

/// Proposed-rule management copy (Epic 13 R2).
///
/// Descriptive only: each row names the proposed behavior change, its
/// owner status, evidence counts, and throttle. No scores, praise, shame,
/// grades, or claims about the person.
enum TrustCenterRulesL10n {
    static let rulesTitle = string(
        "settings.trust.rules.title",
        default: "Proposed rules",
    )
    static let rulesDetail = string(
        "settings.trust.rules.detail",
        default: "Each proposal waits for your decision. Adding is the only way a proposal starts acting. Not now sets it aside, Never declines it for good.",
    )
    static let rulesEmptyTitle = string(
        "settings.trust.rules.empty.title",
        default: "No proposed rules",
    )
    static let rulesEmptyMessage = string(
        "settings.trust.rules.empty.message",
        default: "Nothing has been proposed yet. New proposals appear here for your decision.",
    )
    static let add = string("settings.trust.rules.add", default: "Add")
    static let notNow = string("settings.trust.rules.not_now", default: "Not now")
    static let never = string("settings.trust.rules.never", default: "Never")
    static let undo = string("settings.trust.rules.undo", default: "Undo")
    static let reset = string("settings.trust.rules.reset", default: "Reset")

    static func ruleTitle(_ ruleKey: String) -> String {
        switch ruleKey {
        case "quiet-when-weak":
            string(
                "settings.trust.rules.quiet_when_weak",
                default: "Stay quiet when weak movement is recorded",
            )
        case "shift-within-window":
            string(
                "settings.trust.rules.shift_within_window",
                default: "Shift timing within the window",
            )
        case "restart-on-strong-motion":
            string(
                "settings.trust.rules.restart_on_strong_motion",
                default: "Restart timing on strong movement",
            )
        case "release-on-strong-absence":
            string(
                "settings.trust.rules.release_on_strong_absence",
                default: "Resume after a recorded absence",
            )
        default:
            ruleKey
        }
    }

    static func statusName(_ status: RuleProposalStatus) -> String {
        switch status {
        case .pending:
            string("settings.trust.rules.status.proposed", default: "Proposed")
        case .added:
            string("settings.trust.rules.status.added", default: "Added")
        case .notNow:
            string("settings.trust.rules.status.not_now", default: "Not now")
        case .never:
            string("settings.trust.rules.status.never", default: "Never")
        }
    }

    static func evidenceDetail(have: Int, required: Int) -> String {
        format(
            "settings.trust.rules.evidence",
            default: "%d of %d supporting records",
            have,
            required,
        )
    }

    static func capDetail(weeklyMax: Int, cooldownTicks: TimeInterval) -> String {
        format(
            "settings.trust.rules.cap",
            default: "At most %d per week · at least %@ apart",
            weeklyMax,
            cooldownDuration(cooldownTicks),
        )
    }

    static func rowAccessibility(title: String, status: RuleProposalStatus, evidence: String, cap: String) -> String {
        format(
            "settings.trust.rules.accessibility",
            default: "%@, %@, %@, %@",
            title,
            statusName(status),
            evidence,
            cap,
        )
    }

    static func cooldownDuration(_ ticks: TimeInterval) -> String {
        let seconds = Int(ticks.rounded())
        if seconds % 3600 == 0, seconds >= 3600 {
            let hours = seconds / 3600
            return format("settings.trust.rules.cooldown.hours", default: "%d hours", hours)
        }
        if seconds % 60 == 0 {
            let minutes = max(1, seconds / 60)
            return format("settings.trust.rules.cooldown.minutes", default: "%d minutes", minutes)
        }
        return format("settings.trust.rules.cooldown.seconds", default: "%d seconds", max(1, seconds))
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
