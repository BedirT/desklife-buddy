import Domain
import Foundation
import Observation

/// Truthful menu-bar states. Buckets are text-distinct by design (region
/// headline, VoiceOver value, Dock line) and never color-only: the 18px menu
/// mark stays on the five monochrome DSProtocolMark shapes, with every quiet
/// bucket sharing the dashed quiet mark and every active bucket the plain mark.
public enum StatusMenuGlyph: Equatable, Sendable {
    case operating
    case visualDue
    case movementDue
    case bothDue
    case paused
    /// User-declared holds and waits: quiet, but counting continues and
    /// reminders resume on their own. Shares the quiet mark with paused.
    case held
    /// Protected contexts (presenting, Focus, Calendar, excluded app,
    /// inactive Mac): quiet to protect the current context. Quiet mark.
    case protected
    /// An accepted ritual is running: a break the user started is in
    /// progress. Plain mark; the region names the ritual in text.
    case acceptedRitual
    /// Heads-up is off: reminders stay in the menu. Plain mark; the region
    /// names the off state and its Settings way back in text.
    case degraded
}

public enum StatusClockTiming: Equatable, Sendable {
    case next(aboutMinutes: Int)
    case due
}

public struct StatusClockSummary: Equatable, Sendable {
    public let opportunity: OpportunityType
    public let progress: Double
    public let timing: StatusClockTiming
    /// Whole counted minutes behind this clock, feeding the Why-now line.
    public let activeUseMinutes: Int
    /// Whether this clock's ritual is currently running (accepted).
    public let isRunning: Bool

    public init(
        opportunity: OpportunityType,
        progress: Double,
        timing: StatusClockTiming,
        activeUseMinutes: Int = 0,
        isRunning: Bool = false,
    ) {
        self.opportunity = opportunity
        self.progress = progress
        self.timing = timing
        self.activeUseMinutes = activeUseMinutes
        self.isRunning = isRunning
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

    public var hasActionableHeadsUp: Bool {
        switch liveHeadsUp {
        case .visual, .movement, .merged: true
        case .recovery, nil: false
        }
    }
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
    case openSnoozeOptions
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
                state: state,
                visualDue: visual.timing == .due,
                movementDue: movement.timing == .due,
                suppression: context.activeSuppression,
                headsUpOff: !configuration.delivery.headsUpDefault,
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
            activeUseMinutes: wholeMinutes(elapsed),
            isRunning: clock.phase == .running,
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

    /// Bucket precedence: quiet first (paused, then protected, then held),
    /// then an accepted ritual in progress, then heads-up off, then due.
    /// Every SuppressionReason maps to exactly one quiet bucket; the switch
    /// is exhaustive so a new reason fails to compile here, not silently.
    static func glyph(
        state: ProtocolState,
        visualDue: Bool,
        movementDue: Bool,
        suppression: SuppressionReason?,
        headsUpOff: Bool,
    ) -> StatusMenuGlyph {
        if let suppression {
            switch suppression {
            case .manualPause, .outsideWorkingHours:
                return .paused
            case .systemInactiveOrLocked, .explicitPresentationMode, .focusFilter,
                 .calendarBusy, .excludedApplication:
                return .protected
            case .userDeclaredMeetingOrCall, .userDeclaredScreenSharingOrPresentation,
                 .userSelectedTimedTask, .snooze, .lowFrictionWait:
                return .held
            }
        }
        if state.visualClock.phase == .running || state.movementClock.phase == .running {
            return .acceptedRitual
        }
        if headsUpOff {
            return .degraded
        }
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
        case held
        case protected
        case acceptedRitual
        case headsUpOff
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
        case .calendarBusy, .protected: .calendarBusy
        case .held: .userDeclaredMeetingOrCall
        case .normal, .visualDue, .movementDue, .bothDue, .headsUp, .acceptedRitual, .headsUpOff: nil
        }
        let manualPause: StatusMenuManualPause? = switch state {
        case .paused: .untilResume
        case .timedPause: .until(Date(timeIntervalSince1970: 1_787_686_800))
        case .normal, .visualDue, .movementDue, .bothDue, .calendarBusy, .headsUp,
             .held, .protected, .acceptedRitual, .headsUpOff: nil
        }
        let visualRunning = state == .acceptedRitual
        return StatusMenuSnapshot(
            glyph: previewGlyph(
                state,
                visualDue: visualDue,
                movementDue: movementDue,
                suppression: suppression,
            ),
            visual: StatusClockSummary(
                opportunity: .visual,
                progress: visualDue || visualRunning ? 1 : 0.64,
                timing: visualDue || visualRunning ? .due : .next(aboutMinutes: 9),
                activeUseMinutes: visualDue || visualRunning ? 47 : 12,
                isRunning: visualRunning,
            ),
            movement: StatusClockSummary(
                opportunity: .movement,
                progress: movementDue ? 1 : 0.43,
                timing: movementDue ? .due : .next(aboutMinutes: 34),
                activeUseMinutes: movementDue ? 34 : 8,
            ),
            estimatedActiveUseMinutes: 63,
            activeSuppression: suppression,
            manualPause: manualPause,
            liveHeadsUp: state == .headsUp ? .visual : nil,
            workingHoursOnly: true,
        )
    }

    /// Preview glyphs mirror makeSnapshot precedence without a full engine:
    /// quiet buckets first, then the accepted ritual, then heads-up off.
    static func previewGlyph(
        _ state: PreviewState,
        visualDue: Bool,
        movementDue: Bool,
        suppression: SuppressionReason?,
    ) -> StatusMenuGlyph {
        if suppression != nil {
            switch state {
            case .held: return .held
            case .protected, .calendarBusy: return .protected
            case .paused, .timedPause: return .paused
            case .normal, .visualDue, .movementDue, .bothDue, .headsUp, .acceptedRitual, .headsUpOff:
                return .paused
            }
        }
        if state == .acceptedRitual {
            return .acceptedRitual
        }
        if state == .headsUpOff {
            return .degraded
        }
        return switch (visualDue, movementDue) {
        case (true, true): .bothDue
        case (true, false): .visualDue
        case (false, true): .movementDue
        case (false, false): .operating
        }
    }
}
