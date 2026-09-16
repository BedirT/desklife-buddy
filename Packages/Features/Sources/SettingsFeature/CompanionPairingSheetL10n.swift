import FeatureLocalization
import Foundation

enum CompanionPairingSheetL10n {
    static let rowTitle = string("settings.companion.row.title", default: "Pair iPhone")
    static let rowDetail = string(
        "settings.companion.row.detail",
        default: "Show a pairing code on this Mac, then scan it with the phone to keep a break timer running when you step away.",
    )
    static let rowAction = string("settings.companion.row.action", default: "Show pairing code…")
    static let sheetTitle = string("settings.companion.sheet.title", default: "Pair iPhone")
    static let close = string("settings.companion.sheet.close", default: "Close")
    static let done = string("settings.companion.sheet.done", default: "Done")
    static let loadingMessage = string(
        "settings.companion.sheet.loading",
        default: "Preparing a pairing code…",
    )
    static let codeInstructions = string(
        "settings.companion.sheet.code_instructions",
        default: "Scan this code with the phone to pair. The code carries one pairing key and nothing else.",
    )
    static let codeRegenerateNote = string(
        "settings.companion.sheet.code_regenerate_note",
        default: "If the code will not scan, generate a new one. The old code stops working right away.",
    )
    static let regenerate = string("settings.companion.sheet.regenerate", default: "Generate a new code")
    static let unpair = string("settings.companion.sheet.unpair", default: "Unpair")
    static let qrCodeLabel = string("settings.companion.sheet.qr_code_label", default: "Pairing QR code")
    static let pairedTitle = string("settings.companion.sheet.paired_title", default: "Phone paired")
    static let pairedMessage = string(
        "settings.companion.sheet.paired_message",
        default: "This Mac and the phone share a pairing key. Only break-timer session bytes move between the two paired devices, and unpaired devices are ignored.",
    )
    static let failedTitle = string(
        "settings.companion.sheet.failed_title",
        default: "Pairing code unavailable",
    )
    static let failedMessage = string(
        "settings.companion.sheet.failed_message",
        default: "Something went wrong while preparing the code. Try again.",
    )
    static let retry = string("settings.companion.sheet.retry", default: "Try again")
    static let unpairedTitle = string("settings.companion.sheet.unpaired_title", default: "Unpaired")
    static let unpairedMessage = string(
        "settings.companion.sheet.unpaired_message",
        default: "This Mac no longer shares a pairing key with the phone.",
    )
    static let generateFresh = string("settings.companion.sheet.generate_fresh", default: "Pair a new phone")

    private static func string(_ key: String, default value: String) -> String {
        FeatureL10n.string(key, default: value)
    }
}
