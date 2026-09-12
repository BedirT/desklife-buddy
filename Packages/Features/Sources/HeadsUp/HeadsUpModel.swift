import Foundation
import Observation

public enum HeadsUpScope: CaseIterable, Equatable, Hashable, Sendable {
    case visual, movement, merged
}

public struct HeadsUpApproachMark: Equatable, Hashable, Sendable {
    public static let seconds45 = HeadsUpApproachMark(validatedSeconds: 45),
                      seconds30 = HeadsUpApproachMark(validatedSeconds: 30)
    public static let seconds15 = HeadsUpApproachMark(validatedSeconds: 15),
                      seconds5 = HeadsUpApproachMark(validatedSeconds: 5)

    public let seconds: Int

    public init?(seconds: Int) {
        guard (1 ... 60).contains(seconds) else { return nil }
        self.seconds = seconds
    }

    public static func coarseMarks(leadSeconds: Int) -> [HeadsUpApproachMark] {
        guard (30 ... 60).contains(leadSeconds) else { return [] }
        let values = [leadSeconds, 30, 15, 5]
        return values.reduce(into: []) { marks, seconds in
            let mark = HeadsUpApproachMark(validatedSeconds: seconds)
            if !marks.contains(mark) { marks.append(mark) }
        }
    }

    private init(validatedSeconds: Int) {
        seconds = validatedSeconds
    }
}

public enum HeadsUpHold: Equatable, Sendable {
    case manualPause(until: Date?)
    case systemInactiveOrLocked, explicitPresentationMode, focusFilter
    case calendarBusy(until: Date?)
    case userDeclaredMeetingOrCall(until: Date?)
    case userDeclaredScreenSharingOrPresentation(until: Date?)
    case userSelectedTimedTask(until: Date?)
    case excludedApplication, outsideWorkingHours, snooze
}

public enum HeadsUpPhase: Equatable, Sendable {
    case approaching(HeadsUpApproachMark), landedWaiting, hold(HeadsUpHold)
}

public struct HeadsUpAccessibility: Equatable, Sendable {
    public var textOnly, staticPresentation, reduceMotion: Bool
    public var reduceTransparency, increaseContrast, largeText: Bool

    public init(
        textOnly: Bool = false,
        staticPresentation: Bool = false,
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        largeText: Bool = false,
    ) {
        self.textOnly = textOnly
        self.staticPresentation = staticPresentation
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.largeText = largeText
    }
}

public enum HeadsUpLaterOption: Equatable, Sendable {
    case snooze(durationSeconds: TimeInterval)
    case afterMeeting(deadline: Date)
    case manualHold(durationSeconds: TimeInterval)
    case moreOptions

    public var title: String {
        switch self {
        case let .snooze(durationSeconds):
            HeadsUpL10n.minutes(Int(durationSeconds / 60))
        case .afterMeeting:
            HeadsUpL10n.afterMeeting
        case .manualHold:
            HeadsUpL10n.presentingOneHour
        case .moreOptions:
            HeadsUpL10n.moreOptions
        }
    }

    public var accessibilityIdentifier: String {
        switch self {
        case let .snooze(durationSeconds):
            "headsUp.capsule.later.snooze.\(Int(durationSeconds))"
        case .afterMeeting:
            "headsUp.capsule.later.afterMeeting"
        case let .manualHold(durationSeconds):
            "headsUp.capsule.later.manualHold.\(Int(durationSeconds))"
        case .moreOptions:
            "headsUp.capsule.later.moreOptions"
        }
    }
}

public struct HeadsUpCapsuleActions: Equatable, Sendable {
    public let nowTitle, laterTitle: String
    public let laterOptions: [HeadsUpLaterOption]
}

public enum HeadsUpIntent: Equatable, Sendable {
    case start(scope: HeadsUpScope)
    case snooze(scope: HeadsUpScope, durationSeconds: TimeInterval)
    case snoozeUntil(scope: HeadsUpScope, deadline: Date)
    case manualHold(scope: HeadsUpScope, durationSeconds: TimeInterval)
    case moreOptions(scope: HeadsUpScope)
    case skip(scope: HeadsUpScope)
}

public struct HeadsUpAnnouncement: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case appearance
        case holdChange
    }

    public let kind: Kind
    public let localizedText: String

    public init(kind: Kind, localizedText: String) {
        self.kind = kind
        self.localizedText = localizedText
    }
}

public struct HeadsUpPresentation: Equatable, Sendable {
    public let scope: HeadsUpScope
    public let phase: HeadsUpPhase
    public let accessibility: HeadsUpAccessibility
    public let title, detail, statusAccessibilityLabel: String
    public let approachProgress: Double
    public let normalizedGlint: Double
    public let hold: HeadsUpHold?
    public let showsActions, showsDecorativeIndicator, allowsReactiveGlint: Bool
}

public struct HeadsUpStatusMenuProjection: Equatable, Sendable {
    public let scope: HeadsUpScope
    public let startTitle, laterTitle: String
    public let laterOptions: [HeadsUpLaterOption]
    public let moreOptionsTitle: String
    public let intents: [HeadsUpIntent]
}

@Observable
public final class HeadsUpModel {
    public let scope: HeadsUpScope
    public let snoozeDurationsSeconds: [TimeInterval]
    public let calendarBusyEnd: Date?, manualHoldDurationSeconds: TimeInterval?
    public let accessibility: HeadsUpAccessibility
    public private(set) var presentationPhase: HeadsUpPhase
    public private(set) var approachProgress: Double
    public private(set) var normalizedGlint = 0.0
    public private(set) var isHovered = false
    public private(set) var pendingPersistenceIntent: HeadsUpIntent?
    public private(set) var isFinished = false

    @ObservationIgnored private let onIntent: (HeadsUpIntent) -> Void
    @ObservationIgnored private let onAnnouncement: (HeadsUpAnnouncement) -> Void
    @ObservationIgnored private let formatDeadline: (Date) -> String
    @ObservationIgnored private var didAnnounceAppearance = false
    @ObservationIgnored private var didAnnounceHoldChange = false

    public init(
        scope: HeadsUpScope,
        phase: HeadsUpPhase = .approaching(.seconds45),
        approachProgress: Double = 0,
        snoozeDurationsSeconds: [TimeInterval],
        calendarBusyEnd: Date? = nil,
        manualHoldDurationSeconds: TimeInterval? = nil,
        accessibility: HeadsUpAccessibility = HeadsUpAccessibility(),
        formatDeadline: @escaping (Date) -> String = {
            DateFormatter.localizedString(from: $0, dateStyle: .none, timeStyle: .short)
        },
        onIntent: @escaping (HeadsUpIntent) -> Void = { _ in },
        onAnnouncement: @escaping (HeadsUpAnnouncement) -> Void = { _ in },
    ) {
        precondition(!snoozeDurationsSeconds.isEmpty)
        precondition(snoozeDurationsSeconds.allSatisfy { $0.isFinite && $0 > 0 })
        precondition(snoozeDurationsSeconds.contains(300))
        precondition(
            manualHoldDurationSeconds.map { $0 == 3600 } ?? true,
        )
        self.scope = scope
        presentationPhase = phase
        self.approachProgress = Self.normalizedProgress(approachProgress, for: phase)
        self.snoozeDurationsSeconds = snoozeDurationsSeconds
        self.calendarBusyEnd = calendarBusyEnd
        self.manualHoldDurationSeconds = manualHoldDurationSeconds
        self.accessibility = accessibility
        self.formatDeadline = formatDeadline
        self.onIntent = onIntent
        self.onAnnouncement = onAnnouncement
    }

    public var notificationContent: HeadsUpNotificationContent { HeadsUpNotificationContent(scope: scope) }

    public var capsuleActions: HeadsUpCapsuleActions {
        HeadsUpCapsuleActions(
            nowTitle: HeadsUpL10n.now,
            laterTitle: HeadsUpL10n.later,
            laterOptions: laterOptions,
        )
    }

    public var statusMenuProjection: HeadsUpStatusMenuProjection {
        let options = laterOptions
        return HeadsUpStatusMenuProjection(
            scope: scope,
            startTitle: HeadsUpL10n.startNow,
            laterTitle: HeadsUpL10n.later,
            laterOptions: options,
            moreOptionsTitle: HeadsUpL10n.moreOptions,
            intents: [.start(scope: scope)]
                + options.map(intent(for:)),
        )
    }

    public var presentation: HeadsUpPresentation {
        let hold: HeadsUpHold? = if case let .hold(value) = presentationPhase {
            value
        } else {
            nil
        }
        let copy = HeadsUpL10n.presentation(
            scope: scope,
            phase: presentationPhase,
            formatDeadline: formatDeadline,
        )
        return HeadsUpPresentation(
            scope: scope,
            phase: presentationPhase,
            accessibility: accessibility,
            title: copy.title,
            detail: copy.detail,
            statusAccessibilityLabel: copy.statusAccessibilityLabel,
            approachProgress: approachProgress,
            normalizedGlint: normalizedGlint,
            hold: hold,
            showsActions: isHovered && hold == nil,
            showsDecorativeIndicator: !accessibility.textOnly,
            allowsReactiveGlint: allowsReactiveGlint,
        )
    }

    public func updateNormalizedGlint(_ value: Double) {
        guard allowsReactiveGlint else {
            normalizedGlint = 0
            return
        }
        guard value.isFinite else {
            normalizedGlint = 0
            return
        }
        normalizedGlint = min(1, max(-1, value))
    }

    public func resetGlint() {
        normalizedGlint = 0
    }

    public func setHovered(_ isHovered: Bool) {
        guard !isFinished,
              pendingPersistenceIntent == nil,
              presentation.hold == nil
        else {
            return
        }
        self.isHovered = isHovered
    }

    public func presentationDidAppear() {
        guard !isFinished, !didAnnounceAppearance else { return }
        didAnnounceAppearance = true
        onAnnouncement(HeadsUpL10n.appearanceAnnouncement(
            scope: scope,
            phase: presentationPhase,
            formatDeadline: formatDeadline,
        ))
    }

    public func updatePhase(_ phase: HeadsUpPhase) {
        guard !isFinished, pendingPersistenceIntent == nil else { return }
        presentationPhase = phase
        if phase == .landedWaiting { approachProgress = 1 }
        guard case let .hold(hold) = phase else { return }
        isHovered = false
        resetGlint()
        guard !didAnnounceHoldChange else { return }
        didAnnounceHoldChange = true
        onAnnouncement(HeadsUpL10n.holdAnnouncement(
            hold,
            formatDeadline: formatDeadline,
        ))
    }

    public func updateApproachProgress(_ progress: Double) {
        guard !isFinished,
              pendingPersistenceIntent == nil,
              case .approaching = presentationPhase
        else {
            return
        }
        approachProgress = Self.normalizedProgress(progress, for: presentationPhase)
    }

    public func startNow() { requestPersistence(.start(scope: scope)) }

    public func snooze(for durationSeconds: TimeInterval) {
        guard snoozeDurationsSeconds.contains(durationSeconds) else { return }
        requestPersistence(.snooze(scope: scope, durationSeconds: durationSeconds))
    }

    public func chooseLater(_ option: HeadsUpLaterOption) {
        guard laterOptions.contains(option) else { return }
        if option == .moreOptions {
            moreOptions()
            return
        }
        requestPersistence(intent(for: option))
    }

    public func moreOptions() { requestPersistence(.moreOptions(scope: scope)) }

    public func skip() { requestPersistence(.skip(scope: scope)) }

    public func confirmPersistence(_ intent: HeadsUpIntent) {
        guard pendingPersistenceIntent == intent else { return }
        pendingPersistenceIntent = nil
        isFinished = true
    }

    public func rejectPersistence(_ intent: HeadsUpIntent) {
        guard pendingPersistenceIntent == intent else { return }
        pendingPersistenceIntent = nil
    }
}

private extension HeadsUpModel {
    var laterOptions: [HeadsUpLaterOption] {
        var options = snoozeDurationsSeconds.map(HeadsUpLaterOption.snooze(durationSeconds:))
        if let calendarBusyEnd {
            options.append(.afterMeeting(deadline: calendarBusyEnd))
        }
        if let manualHoldDurationSeconds {
            options.append(.manualHold(durationSeconds: manualHoldDurationSeconds))
        }
        options.append(.moreOptions)
        return options
    }

    func intent(for option: HeadsUpLaterOption) -> HeadsUpIntent {
        switch option {
        case let .snooze(durationSeconds):
            .snooze(scope: scope, durationSeconds: durationSeconds)
        case let .afterMeeting(deadline):
            .snoozeUntil(scope: scope, deadline: deadline)
        case let .manualHold(durationSeconds):
            .manualHold(scope: scope, durationSeconds: durationSeconds)
        case .moreOptions:
            .moreOptions(scope: scope)
        }
    }

    static func normalizedProgress(_ progress: Double, for phase: HeadsUpPhase) -> Double {
        guard phase != .landedWaiting else { return 1 }
        guard progress.isFinite else { return 0 }
        return min(max(progress, 0), 1)
    }

    func requestPersistence(_ intent: HeadsUpIntent) {
        guard !isFinished, pendingPersistenceIntent == nil else { return }
        isHovered = false
        resetGlint()
        pendingPersistenceIntent = intent
        onIntent(intent)
    }

    var allowsReactiveGlint: Bool {
        let isHeld = if case .hold = presentationPhase { true } else { false }
        return !accessibility.textOnly
            && !accessibility.staticPresentation
            && !accessibility.reduceMotion
            && !isFinished
            && pendingPersistenceIntent == nil
            && !isHeld
    }
}
