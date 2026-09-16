import Domain
import Foundation

/// String-catalog access for the phone flow. Views use these constants;
/// no raw English lives in views or accessibility strings.
public enum PhoneL10n {
    public static func string(_ key: String, default defaultValue: String) -> String {
        Bundle.module.localizedString(forKey: key, value: defaultValue, table: "Localizable")
    }

    public static func format(_ key: String, default defaultValue: String, _ args: CVarArg...) -> String {
        String(
            format: Bundle.module.localizedString(forKey: key, value: defaultValue, table: "Localizable"),
            arguments: args,
        )
    }
}

/// Pairing failures the scan pane reports.
public enum PhonePairingError: Equatable, Hashable, Sendable {
    /// The scanned text is not a pairing payload at all.
    case invalidQR
    /// The payload carries a schema version this build refuses to default past.
    case unsupportedVersion
    /// The decoded key could not be stored.
    case storageFailed
}

/// Localized copy for the take-with-you break flow.
public enum PhoneBreakL10n {
    public static let scanTitle = PhoneL10n.string("phone.scan.title", default: "Take this break with you")
    public static let scanHint = PhoneL10n.string(
        "phone.scan.hint",
        default: "Point the camera at the code on your Mac. The code carries only a pairing key — no break content.",
    )
    public static let scanDenied = PhoneL10n.string(
        "phone.scan.camera_denied",
        default: "Camera access is off, so the code cannot be scanned. Turn it on in Settings to pair.",
    )
    public static let waitingTitle = PhoneL10n.string("phone.waiting.title", default: "Paired with your Mac")
    public static let waitingBody = PhoneL10n.string(
        "phone.waiting.body",
        default: "The countdown starts here when your Mac begins a break. Nothing leaves this phone except your finished-break note.",
    )
    public static let countdownTitle = PhoneL10n.string("phone.countdown.title", default: "Break in progress")
    public static let finishTitle = PhoneL10n.string("phone.finish.title", default: "How did the break end?")
    public static let certaintyLocal = PhoneL10n.string(
        "phone.certainty.local",
        default: "On this phone only — your Mac has not heard back yet.",
    )
    public static let certaintyRemote = PhoneL10n.string(
        "phone.certainty.remote",
        default: "Sent — waiting for your Mac to confirm.",
    )
    public static let certaintyAcknowledged = PhoneL10n.string(
        "phone.certainty.acknowledged",
        default: "Your Mac confirmed it.",
    )
    public static let pendingSends = PhoneL10n.string(
        "phone.finish.pending",
        default: "Waiting to send: %d",
    )
    public static let liveActivityTitle = PhoneL10n.string(
        "phone.live_activity.title",
        default: "Break",
    )
    public static let retrySending = PhoneL10n.string("phone.finish.retry", default: "Try sending again")

    /// Localized finish-button title for one terminal claim.
    public static func claimTitle(_ claim: CompanionTerminalClaim) -> String {
        switch claim {
        case .completed: PhoneL10n.string("phone.finish.completed", default: "Finished the break")
        case .skipped: PhoneL10n.string("phone.finish.skipped", default: "Skipped")
        case .snoozed: PhoneL10n.string("phone.finish.snoozed", default: "Snoozed")
        case .notAppropriate: PhoneL10n.string("phone.finish.not_appropriate", default: "Not a good moment")
        case .positionChanged: PhoneL10n.string("phone.finish.position_changed", default: "Changed position")
        case .alreadyMoved: PhoneL10n.string("phone.finish.already_moved", default: "Already moved")
        case .timerFinished: PhoneL10n.string("phone.finish.timer_finished", default: "Timer ran out")
        }
    }

    /// Accessibility label for the remaining countdown.
    public static func remainingAccessibility(minutes: Int, seconds: Int) -> String {
        PhoneL10n.format(
            "phone.countdown.remaining_accessibility",
            default: "%d minutes %d seconds left",
            minutes,
            seconds,
        )
    }

    /// Accessibility description of one pairing failure.
    public static func pairingErrorAccessibility(_ error: PhonePairingError) -> String {
        switch error {
        case .invalidQR: PhoneL10n.string(
                "phone.scan.error_invalid",
                default: "That code is not a DeskLife pairing code.",
            )
        case .unsupportedVersion: PhoneL10n.string(
                "phone.scan.error_version",
                default: "That code uses a newer format this version cannot read.",
            )
        case .storageFailed: PhoneL10n.string(
                "phone.scan.error_storage",
                default: "The pairing key could not be saved on this phone.",
            )
        }
    }
}
