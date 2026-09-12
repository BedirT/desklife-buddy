import Domain
import FeatureLocalization
import Foundation

enum TrustCenterL10n {
    static let subtitle = string(
        "settings.trust.subtitle",
        default: "What sensing is allowed, what is happening now, and what was decided.",
    )
    static let killSwitchTitle = string(
        "settings.trust.stopped.title",
        default: "Sensing is stopped",
    )
    static let killSwitchMessage = string(
        "settings.trust.stopped.message",
        default: "The stop control is engaged. Nothing new is sensed and nothing changes automatically. Each capability stays off until you allow it again.",
    )
    static let capabilitiesTitle = string(
        "settings.trust.capabilities.title",
        default: "Capabilities",
    )
    static let capabilitiesDetail = string(
        "settings.trust.capabilities.detail",
        default: "Each capability is decided separately. Placeholder signals only; the permission-free core stays available throughout.",
    )
    static let inspectorTitle = string(
        "settings.trust.inspector.title",
        default: "Live status",
    )
    static let inspectorDetail = string(
        "settings.trust.inspector.detail",
        default: "Counts and verdict classes only. No readings, confidence values, providers, or payloads ever appear here.",
    )
    static let leaseTitle = string(
        "settings.trust.inspector.lease",
        default: "Sensing windows",
    )
    static let busTitle = string(
        "settings.trust.inspector.bus",
        default: "Recorded decisions",
    )
    static let firewallTitle = string(
        "settings.trust.inspector.firewall",
        default: "Timing holds",
    )
    static let receiptsTitle = string(
        "settings.trust.receipts.title",
        default: "Decisions",
    )
    static let receiptsDetail = string(
        "settings.trust.receipts.detail",
        default: "One row per grant, refusal, or withdrawal, newest first.",
    )
    static let receiptsEmptyTitle = string(
        "settings.trust.receipts.empty.title",
        default: "No decisions yet",
    )
    static let receiptsEmptyMessage = string(
        "settings.trust.receipts.empty.message",
        default: "Nothing has been allowed or stopped. New decisions are recorded here as they happen.",
    )
    static let guidanceTitle = string(
        "settings.trust.guidance.title",
        default: "Stop or change a decision",
    )
    static let guidanceDetail = string(
        "settings.trust.guidance.detail",
        default: "Stopping takes effect right away. Starting again always asks first, including after the stop-everything control.",
    )
    static let stopEverything = string(
        "settings.trust.stop_everything",
        default: "Stop everything",
    )
    static let resumeEverything = string(
        "settings.trust.resume_everything",
        default: "Resume",
    )
    static let learn = string("settings.trust.learn", default: "Learn")
    static let allow = string("settings.trust.allow", default: "Allow")
    static let stop = string("settings.trust.stop", default: "Stop")
    static let dataTitle = string(
        "settings.trust.data.title",
        default: "Sensing data",
    )
    static let dataDetail = string(
        "settings.trust.data.detail",
        default: "Export a copy of the decision ledgers, or delete them from this Mac.",
    )
    static let export = string("settings.trust.export", default: "Export sensing data")
    static let delete = string("settings.trust.delete", default: "Delete sensing data")
    static let deleteConfirmTitle = string(
        "settings.trust.delete.confirm.title",
        default: "Delete sensing data?",
    )
    static let deleteConfirmMessage = string(
        "settings.trust.delete.confirm.message",
        default: "This removes every recorded decision from this Mac. Capabilities turn off and stay off until you allow them again.",
    )
    static let cancel = string("settings.trust.cancel", default: "Cancel")
    static let confirmDelete = string("settings.trust.delete.confirm", default: "Delete")
    static let exportSaved = string(
        "settings.trust.export.saved",
        default: "The export was saved.",
    )
    static let exportCancelled = string(
        "settings.trust.export.cancelled",
        default: "The export was cancelled. Nothing was saved.",
    )
    static let exportFailed = string(
        "settings.trust.export.failed",
        default: "The export could not be saved. Your data is unchanged.",
    )
    static func deleteDone(receipts: Int, decisions: Int) -> String {
        format(
            "settings.trust.delete.done",
            default: "Sensing data was deleted: %d consent records and %d policy records removed.",
            receipts,
            decisions,
        )
    }

    static let deleteFailed = string(
        "settings.trust.delete.failed",
        default: "Sensing data could not be deleted. Your data is unchanged.",
    )

    static func stateName(_ state: PermissionConsentState) -> String {
        switch state {
        case .unknown:
            string("settings.trust.state.unknown", default: "Not decided")
        case .educating:
            string("settings.trust.state.educating", default: "Learning")
        case .granted:
            string("settings.trust.state.granted", default: "On")
        case .denied:
            string("settings.trust.state.denied", default: "Off")
        case .revoked:
            string("settings.trust.state.revoked", default: "Stopped")
        }
    }

    static func capabilityName(_ capability: PermissionCapability) -> String {
        switch capability {
        case .sensingPresence:
            string("settings.trust.capability.presence", default: "Presence")
        case .sensingMotion:
            string("settings.trust.capability.motion", default: "Motion")
        case .sensingAmbient:
            string("settings.trust.capability.ambient", default: "Ambient")
        case .effectHold:
            string("settings.trust.capability.hold", default: "Hold timing")
        case .effectRestart:
            string("settings.trust.capability.restart", default: "Restart timing")
        }
    }

    static func capabilityPurpose(_ capability: PermissionCapability) -> String {
        switch capability {
        case .sensingPresence:
            string(
                "settings.trust.capability.presence.purpose",
                default: "Placeholder presence signals only. Lets sensing windows start when allowed.",
            )
        case .sensingMotion:
            string(
                "settings.trust.capability.motion.purpose",
                default: "Placeholder motion signals only. Lets sensing windows start when allowed.",
            )
        case .sensingAmbient:
            string(
                "settings.trust.capability.ambient.purpose",
                default: "Placeholder ambient signals only. Lets sensing windows start when allowed.",
            )
        case .effectHold:
            string(
                "settings.trust.capability.hold.purpose",
                default: "Lets timing hold or shift automatically when allowed. Manual timing always works.",
            )
        case .effectRestart:
            string(
                "settings.trust.capability.restart.purpose",
                default: "Lets timing restart automatically on strong motion when allowed. Manual timing always works.",
            )
        }
    }

    static func pathDetail(open: Bool, sensing: Bool) -> String {
        if sensing {
            if open {
                string(
                    "settings.trust.path.sensing.open",
                    default: "Sensing windows can start.",
                )
            } else {
                string(
                    "settings.trust.path.sensing.closed",
                    default: "Sensing windows cannot start.",
                )
            }
        } else if open {
            string(
                "settings.trust.path.effect.open",
                default: "Automatic timing changes can occur.",
            )
        } else {
            string(
                "settings.trust.path.effect.closed",
                default: "Timing stays manual.",
            )
        }
    }

    static func explainer(for capability: PermissionCapability) -> String {
        switch capability {
        case .sensingPresence, .sensingMotion, .sensingAmbient:
            string(
                "settings.trust.explainer.sensing",
                default: "Allowing starts placeholder sensing windows. Nothing leaves this Mac, and you can stop at any time.",
            )
        case .effectHold, .effectRestart:
            string(
                "settings.trust.explainer.effect",
                default: "Allowing lets timing adjust on its own within its current bounds. Nothing leaves this Mac, and you can stop at any time.",
            )
        }
    }

    static let settingsGuidance = string(
        "settings.trust.guidance.stopped",
        default: "This stays off until you allow it again. Use Stop everything to halt all capabilities at once.",
    )

    static func leaseDetail(openWindows: Int, blocked: Bool) -> String {
        if blocked {
            string(
                "settings.trust.inspector.lease.blocked",
                default: "No sensing window can start right now.",
            )
        } else {
            format(
                "settings.trust.inspector.lease.open",
                default: "%d sensing window can start.",
                openWindows,
            )
        }
    }

    static func busDetail(admitted: Int, verdict: String) -> String {
        format(
            "settings.trust.inspector.bus.detail",
            default: "%d recorded, latest verdict: %@.",
            admitted,
            verdictName(verdict),
        )
    }

    static func firewallDetail(holds: Int, windowSeconds: Int) -> String {
        format(
            "settings.trust.inspector.firewall.detail",
            default: "%d hold events on record across %d seconds of coordinator windows.",
            holds,
            windowSeconds,
        )
    }

    static func verdictName(_ code: String) -> String {
        switch code {
        case "quiet":
            string("settings.trust.verdict.quiet", default: "Quiet")
        case "shift":
            string("settings.trust.verdict.shift", default: "Shift")
        case "restart":
            string("settings.trust.verdict.restart", default: "Restart")
        case "resume":
            string("settings.trust.verdict.resume", default: "Resume")
        default:
            string("settings.trust.verdict.none", default: "None yet")
        }
    }

    static func receiptAccessibility(scope: String, status: String, date: String) -> String {
        format(
            "settings.trust.receipt.accessibility",
            default: "%@, %@, %@",
            scope,
            statusName(status),
            date,
        )
    }

    static func statusName(_ code: String) -> String {
        switch code {
        case "granted":
            string("settings.trust.receipt.granted", default: "Allowed")
        case "revoked":
            string("settings.trust.receipt.revoked", default: "Stopped")
        case "expired":
            string("settings.trust.receipt.expired", default: "Expired")
        default:
            code
        }
    }

    static func capabilityAccessibility(name: String, state: PermissionConsentState) -> String {
        format(
            "settings.trust.capability.accessibility",
            default: "%@, %@",
            name,
            stateName(state),
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
