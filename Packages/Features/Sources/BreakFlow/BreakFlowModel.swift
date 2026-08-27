import Foundation
import Observation

public enum BreakScope: Equatable, Hashable, Sendable {
    case visual
    case movement
    case merged
}

public enum BreakFlowSurface: Equatable, Sendable {
    case visualOnlyAcknowledgement
    case snooze(scope: BreakScope, calendarEnd: Date?)
    case recoveryOffer
}

public enum BreakFlowCommand: Equatable, Sendable {
    case pauseOneHour
    case notAppropriate
    case skip
}

public enum BreakFlowAction: Equatable, Sendable {
    case acknowledgementFinished
    case snooze(scope: BreakScope, durationSeconds: TimeInterval)
    case snoozeUntil(scope: BreakScope, deadline: Date)
    case pauseOneHour
    case notAppropriate(scope: BreakScope)
    case skip(scope: BreakScope)
    case chooseRecovery(durationSeconds: TimeInterval)
    case dismissRecovery
}

public enum BreakFlowAnnouncement: Equatable, Sendable {
    case snoozed(minutes: Int)
    case pausedOneHour
    case notedForSession
    case skipped
}

public struct BreakFlowPresentation: Equatable, Sendable {
    public let surface: BreakFlowSurface
    public let snoozeDurationsSeconds: [TimeInterval]
    public let recoveryDurationsSeconds: [TimeInterval]
    public let acknowledgementDurationSeconds: TimeInterval
}

public struct BreakFlowAccessibility: Equatable, Sendable {
    public var reduceMotion: Bool
    public var reduceTransparency: Bool
    public var increaseContrast: Bool
    public var staticPresentation: Bool

    public init(
        reduceMotion: Bool = false,
        reduceTransparency: Bool = false,
        increaseContrast: Bool = false,
        staticPresentation: Bool = false,
    ) {
        self.reduceMotion = reduceMotion
        self.reduceTransparency = reduceTransparency
        self.increaseContrast = increaseContrast
        self.staticPresentation = staticPresentation
    }
}

public enum BreakFlowControl: Equatable, Hashable, Sendable {
    case recoveryFive
    case recoveryTen
    case recoveryNotNow
    case snooze(TimeInterval)
    case afterMeeting
    case pauseOneHour
    case notAppropriate
    case skip
}

@Observable
public final class BreakFlowModel {
    public let surface: BreakFlowSurface
    public let snoozeDurationsSeconds: [TimeInterval]
    public let recoveryDurationsSeconds: [TimeInterval]
    public let acknowledgementDurationSeconds: TimeInterval
    public private(set) var isFinished = false

    public var presentation: BreakFlowPresentation {
        BreakFlowPresentation(
            surface: surface,
            snoozeDurationsSeconds: snoozeDurationsSeconds,
            recoveryDurationsSeconds: recoveryDurationsSeconds,
            acknowledgementDurationSeconds: acknowledgementDurationSeconds,
        )
    }

    public var showsEscalation: Bool { false }

    @ObservationIgnored private let onAction: (BreakFlowAction) -> Void
    @ObservationIgnored private var pendingPersistenceAction: BreakFlowAction?

    public init(
        surface: BreakFlowSurface,
        snoozeDurationsSeconds: [TimeInterval],
        recoveryDurationsSeconds: [TimeInterval],
        acknowledgementDurationSeconds: TimeInterval = 2,
        onAction: @escaping (BreakFlowAction) -> Void = { _ in },
    ) {
        precondition(!snoozeDurationsSeconds.isEmpty)
        precondition(snoozeDurationsSeconds.allSatisfy { $0.isFinite && $0 > 0 })
        precondition(recoveryDurationsSeconds.count == 2)
        precondition(recoveryDurationsSeconds.allSatisfy { $0.isFinite && $0 > 0 })
        precondition(
            acknowledgementDurationSeconds.isFinite && acknowledgementDurationSeconds > 0,
        )
        self.surface = surface
        self.snoozeDurationsSeconds = snoozeDurationsSeconds
        self.recoveryDurationsSeconds = recoveryDurationsSeconds
        self.acknowledgementDurationSeconds = acknowledgementDurationSeconds
        self.onAction = onAction
    }

    public func snooze(for durationSeconds: TimeInterval) {
        guard case let .snooze(scope, _) = surface,
              snoozeDurationsSeconds.contains(durationSeconds)
        else {
            return
        }
        requestPersistence(.snooze(scope: scope, durationSeconds: durationSeconds))
    }

    public func acknowledgementDidFinish() {
        guard surface == .visualOnlyAcknowledgement else { return }
        finish(.acknowledgementFinished)
    }

    public func snoozeUntilMeetingEnds() {
        guard case let .snooze(scope, calendarEnd?) = surface else { return }
        requestPersistence(.snoozeUntil(scope: scope, deadline: calendarEnd))
    }

    public func send(_ command: BreakFlowCommand) {
        guard case let .snooze(scope, _) = surface else { return }
        let action: BreakFlowAction = switch command {
        case .pauseOneHour: .pauseOneHour
        case .notAppropriate: .notAppropriate(scope: scope)
        case .skip: .skip(scope: scope)
        }
        requestPersistence(action)
    }

    public func confirmPersistence(_ action: BreakFlowAction) {
        guard pendingPersistenceAction == action else { return }
        pendingPersistenceAction = nil
        isFinished = true
    }

    public func rejectPersistence(_ action: BreakFlowAction) {
        guard pendingPersistenceAction == action else { return }
        pendingPersistenceAction = nil
    }

    public func chooseRecovery(durationSeconds: TimeInterval) {
        guard surface == .recoveryOffer,
              recoveryDurationsSeconds.contains(durationSeconds)
        else {
            return
        }
        finish(.chooseRecovery(durationSeconds: durationSeconds))
    }

    public func dismissRecovery() {
        guard surface == .recoveryOffer else { return }
        finish(.dismissRecovery)
    }
}

public extension BreakFlowModel {
    static func preview(
        _ surface: BreakFlowSurface,
        deferralCount _: Int = 0,
        onAction: @escaping (BreakFlowAction) -> Void = { _ in },
    ) -> BreakFlowModel {
        BreakFlowModel(
            surface: surface,
            snoozeDurationsSeconds: [300, 600, 900],
            recoveryDurationsSeconds: [300, 600],
            onAction: onAction,
        )
    }
}

private extension BreakFlowModel {
    func requestPersistence(_ action: BreakFlowAction) {
        guard !isFinished, pendingPersistenceAction == nil else { return }
        pendingPersistenceAction = action
        onAction(action)
    }

    func finish(_ action: BreakFlowAction) {
        guard !isFinished else { return }
        isFinished = true
        onAction(action)
    }
}
