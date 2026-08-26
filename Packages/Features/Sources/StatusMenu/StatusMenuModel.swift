import Domain
import Foundation
import Observation

public enum StatusMenuGlyph: Equatable, Sendable {
    case operating
    case visualDue
    case movementDue
    case bothDue
    case paused
}

public enum StatusClockTiming: Equatable, Sendable {
    case next(aboutMinutes: Int)
    case due
}

public struct StatusClockSummary: Equatable, Sendable {
    public let opportunity: OpportunityType
    public let progress: Double
    public let timing: StatusClockTiming

    public init(
        opportunity: OpportunityType,
        progress: Double,
        timing: StatusClockTiming,
    ) {
        self.opportunity = opportunity
        self.progress = progress
        self.timing = timing
    }
}

public struct StatusMenuSnapshot: Equatable, Sendable {
    public let glyph: StatusMenuGlyph
    public let visual: StatusClockSummary
    public let movement: StatusClockSummary
    public let estimatedActiveUseMinutes: Int
    public let activeSuppression: SuppressionReason?
    public let manualPause: StatusMenuManualPause?
    public let liveHeadsUp: OpportunityPresentation?
    public let workingHoursOnly: Bool
}

public struct StatusMenuContext: Equatable, Sendable {
    public let estimatedActiveUseSeconds: TimeInterval
    public let activeSuppression: SuppressionReason?
    public let manualPause: StatusMenuManualPause?
    public let liveHeadsUp: OpportunityPresentation?
    public let workingHoursOnly: Bool

    public init(
        estimatedActiveUseSeconds: TimeInterval = 0,
        activeSuppression: SuppressionReason? = nil,
        manualPause: StatusMenuManualPause? = nil,
        liveHeadsUp: OpportunityPresentation? = nil,
        workingHoursOnly: Bool = false,
    ) {
        self.estimatedActiveUseSeconds = estimatedActiveUseSeconds
        self.activeSuppression = activeSuppression
        self.manualPause = manualPause
        self.liveHeadsUp = liveHeadsUp
        self.workingHoursOnly = workingHoursOnly
    }
}

public enum StatusMenuMovementChoice: Equatable, Sendable {
    case recommended
    case quick
    case positionChange
}

public enum StatusMenuPauseChoice: Equatable, Sendable {
    case thirtyMinutes
    case oneHour
    case restOfDay
    case untilResume
    case presenting
}

public enum StatusMenuManualPause: Equatable, Sendable {
    case until(Date)
    case untilResume
}

public enum StatusMenuAction: Equatable, Sendable {
    case startHeadsUpNow
    case snooze(TimeInterval)
    case startVisualReset
    case startMovement(StatusMenuMovementChoice)
    case pause(StatusMenuPauseChoice)
    case resume
    case toggleWorkingHours
    case openWeeklyRhythm
    case openSettings
    case quit
}

@Observable
public final class StatusMenuModel {
    public private(set) var snapshot: StatusMenuSnapshot
    private let onAction: (StatusMenuAction) -> Void

    public init(
        state: ProtocolState,
        configuration: ProtocolConfiguration,
        context: StatusMenuContext = StatusMenuContext(),
        onAction: @escaping (StatusMenuAction) -> Void = { _ in },
    ) {
        snapshot = Self.makeSnapshot(
            state: state,
            configuration: configuration,
            context: context,
        )
        self.onAction = onAction
    }

    private init(snapshot: StatusMenuSnapshot) {
        self.snapshot = snapshot
        onAction = { _ in }
    }

    public func refresh(
        state: ProtocolState,
        configuration: ProtocolConfiguration,
        context: StatusMenuContext,
    ) {
        snapshot = Self.makeSnapshot(
            state: state,
            configuration: configuration,
            context: context,
        )
    }

    public func send(_ action: StatusMenuAction) {
        onAction(action)
    }
}

private extension StatusMenuModel {
    static func makeSnapshot(
        state: ProtocolState,
        configuration: ProtocolConfiguration,
        context: StatusMenuContext,
    ) -> StatusMenuSnapshot {
        let visual = summary(
            opportunity: .visual,
            clock: state.visualClock,
            schedule: configuration.visual,
        )
        let movement = summary(
            opportunity: .movement,
            clock: state.movementClock,
            schedule: configuration.movement,
        )
        return StatusMenuSnapshot(
            glyph: glyph(
                visualDue: visual.timing == .due,
                movementDue: movement.timing == .due,
                isPaused: context.activeSuppression != nil,
            ),
            visual: visual,
            movement: movement,
            estimatedActiveUseMinutes: wholeMinutes(context.estimatedActiveUseSeconds),
            activeSuppression: context.activeSuppression,
            manualPause: context.manualPause,
            liveHeadsUp: context.liveHeadsUp,
            workingHoursOnly: context.workingHoursOnly,
        )
    }

    static func summary(
        opportunity: OpportunityType,
        clock: OpportunityClockState,
        schedule: OpportunitySchedule,
    ) -> StatusClockSummary {
        let elapsed = clock.accumulatedActiveUseSeconds
        let isDue = elapsed >= schedule.softDueSeconds || phaseIsDue(clock.phase)
        let remaining = max(0, schedule.targetSeconds - elapsed)
        return StatusClockSummary(
            opportunity: opportunity,
            progress: min(1, max(0, elapsed / schedule.targetSeconds)),
            timing: isDue ? .due : .next(aboutMinutes: roundedUpMinutes(remaining)),
        )
    }

    static func phaseIsDue(_ phase: OpportunityPhase) -> Bool {
        switch phase {
        case .softDue, .headsUpPresented, .waitingForLowFrictionMoment, .readyToPresent:
            true
        case .accumulating, .running, .snoozed, .suppressed, .gracedAfterSuppression:
            false
        }
    }

    static func glyph(
        visualDue: Bool,
        movementDue: Bool,
        isPaused: Bool,
    ) -> StatusMenuGlyph {
        if isPaused { return .paused }
        return switch (visualDue, movementDue) {
        case (true, true): .bothDue
        case (true, false): .visualDue
        case (false, true): .movementDue
        case (false, false): .operating
        }
    }

    static func roundedUpMinutes(_ seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(ceil(seconds / 60))
    }

    static func wholeMinutes(_ seconds: TimeInterval) -> Int {
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return Int(seconds / 60)
    }
}

public extension StatusMenuModel {
    enum PreviewState: CaseIterable {
        case normal
        case visualDue
        case movementDue
        case bothDue
        case paused
        case timedPause
        case calendarBusy
        case headsUp
    }

    static func preview(_ state: PreviewState = .normal) -> StatusMenuModel {
        StatusMenuModel(snapshot: previewSnapshot(state))
    }
}

private extension StatusMenuModel {
    static func previewSnapshot(_ state: PreviewState) -> StatusMenuSnapshot {
        let visualDue = state == .visualDue || state == .bothDue
        let movementDue = state == .movementDue || state == .bothDue
        let suppression: SuppressionReason? = switch state {
        case .paused, .timedPause: .manualPause
        case .calendarBusy: .calendarBusy
        case .normal, .visualDue, .movementDue, .bothDue, .headsUp: nil
        }
        let manualPause: StatusMenuManualPause? = switch state {
        case .paused: .untilResume
        case .timedPause: .until(Date(timeIntervalSince1970: 1_787_686_800))
        case .normal, .visualDue, .movementDue, .bothDue, .calendarBusy, .headsUp: nil
        }
        return StatusMenuSnapshot(
            glyph: glyph(
                visualDue: visualDue,
                movementDue: movementDue,
                isPaused: suppression != nil,
            ),
            visual: StatusClockSummary(
                opportunity: .visual,
                progress: visualDue ? 1 : 0.64,
                timing: visualDue ? .due : .next(aboutMinutes: 9),
            ),
            movement: StatusClockSummary(
                opportunity: .movement,
                progress: movementDue ? 1 : 0.43,
                timing: movementDue ? .due : .next(aboutMinutes: 34),
            ),
            estimatedActiveUseMinutes: 63,
            activeSuppression: suppression,
            manualPause: manualPause,
            liveHeadsUp: state == .headsUp ? .visual : nil,
            workingHoursOnly: true,
        )
    }
}
