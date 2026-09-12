import AppIntents
import Domain
import Foundation

/// One Shortcuts/Siri request into the manual context seam. Pure user
/// declaration only: no sensor input is read, and the request fans into the
/// same `ProtocolRuntime` path the status menu uses — never a parallel
/// reducer.
enum ManualContextIntentRequest: Sendable {
    case start(mode: ManualContextMode, durationSeconds: TimeInterval)
    case end
}

enum ManualContextIntentError: Error, LocalizedError {
    case appNotReady

    var errorDescription: String? {
        "The app isn't running yet, so the manual hold wasn't changed."
    }
}

/// Registered by `AppDelegate.install`. The intents below stay a thin
/// projection: they build a `ManualContextIntentRequest` and hand it to the
/// live runtime through this handler.
enum ManualContextIntentCenter {
    static var handler: (@Sendable (ManualContextIntentRequest) async throws -> ManualContextHold?)?
}

/// AppEnum projection of the Domain modes so Shortcuts can start each mode
/// by name.
enum ManualContextModeParameter: String, AppEnum {
    case meetingOrCall
    case presentingOrSharing
    case timedFocus
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Manual hold mode")

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .meetingOrCall: "Meeting or call",
        .presentingOrSharing: "Presenting or sharing",
        .timedFocus: "Timed focus",
    ]
    var mode: ManualContextMode {
        switch self {
        case .meetingOrCall: .meetingOrCall
        case .presentingOrSharing: .presentingOrSharing
        case .timedFocus: .timedFocus
        }
    }
}
struct StartManualContextIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a manual hold"
    static let description: IntentDescription = "Holds reminders for a meeting, presenting, or timed focus you declare. Need clocks keep accruing, and the hold always ends at a set time."
    static let openAppWhenRun = false
    @Parameter(title: "Mode", description: "The manual hold to start.")
    var mode: ManualContextModeParameter

    @Parameter(
        title: "Duration",
        description: "Hold length in minutes. Defaults to the mode's standard length.",
    )
    var durationMinutes: Int?

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$mode) hold")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        // AppIntent `perform` runs off the main actor while the Domain seam
        // and the registered handler live on it. Only `Sendable` values
        // cross each hop; every Domain member access happens on the actor.
        let domainMode = mode.mode
        let requestedMinutes = durationMinutes
        let fallbackMinutes = await MainActor.run {
            Int(domainMode.defaultDurationSeconds / 60)
        }
        let minutes = max(1, requestedMinutes ?? fallbackMinutes)
        let request = ManualContextIntentRequest.start(
            mode: domainMode,
            durationSeconds: TimeInterval(minutes * 60),
        )
        guard let handler = await ManualContextIntentCenter.handler else {
            throw ManualContextIntentError.appNotReady
        }
        let hold = try await handler(request)
        let dialog = await MainActor.run {
            let until = hold.map { Self.timeText($0.expiresAt) }
                ?? Self.timeText(Date().addingTimeInterval(TimeInterval(minutes * 60)))
            return "You marked \(Self.modeText(domainMode)) — reminders held until \(until)."
        }
        return .result(dialog: IntentDialog(stringLiteral: dialog))
    }

    private static func modeText(_ mode: ManualContextMode) -> String {
        switch mode {
        case .meetingOrCall: "a meeting or call"
        case .presentingOrSharing: "presenting or sharing"
        case .timedFocus: "timed focus"
        }
    }

    private static func timeText(_ date: Date) -> String {
        DateFormatter.localizedString(from: date, dateStyle: .none, timeStyle: .short)
    }
}

struct EndManualContextIntent: AppIntent {
    static let title: LocalizedStringResource = "End the manual hold"
    static let description: IntentDescription = "Ends the declared meeting, presenting, or timed-focus hold. Reminders resume."
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let handler = await ManualContextIntentCenter.handler else {
            throw ManualContextIntentError.appNotReady
        }
        _ = try await handler(.end)
        return .result(dialog: "Manual hold ended — reminders are back on.")
    }
}

struct ManualContextShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartManualContextIntent(),
            phrases: ["Start a manual hold with \(.applicationName)"],
            shortTitle: "Start manual hold",
            systemImageName: "pause.circle",
        )
        AppShortcut(
            intent: EndManualContextIntent(),
            phrases: ["End the manual hold with \(.applicationName)"],
            shortTitle: "End manual hold",
            systemImageName: "play.circle",
        )
    }
}
