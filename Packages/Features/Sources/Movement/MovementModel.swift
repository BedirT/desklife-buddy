import Domain
import Foundation
import Observation

@Observable
public final class MovementModel {
    public enum Phase: Equatable {
        case ready
        case running
        case finished(MovementTerminalAction)
    }

    public private(set) var phase: Phase = .ready
    public private(set) var selectedChoice: MovementChoice = .walkOrWheel
    public private(set) var selectedDurationSeconds: TimeInterval
    public private(set) var remainingSeconds: Int
    public private(set) var progress: Double = 0
    public private(set) var deadline: TimeInterval?
    public private(set) var isDeclarationArmed = false
    public private(set) var accessibility: MovementAccessibility

    public let recommendedDurationSeconds: TimeInterval
    public let quickDurationSeconds: TimeInterval

    public var guidance: MovementGuidance {
        MovementGuidance(choice: selectedChoice)
    }

    @ObservationIgnored private let declarationArmDelay: TimeInterval
    @ObservationIgnored private let requiresLifecycleConfirmation: Bool
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let onAction: (MovementAction) -> Void
    @ObservationIgnored private let onAnnouncement: (MovementAnnouncement) -> Void
    @ObservationIgnored private var openedAt: TimeInterval?
    @ObservationIgnored private var announcedOneMinute = false
    @ObservationIgnored private var lastExplicitDurationSelection: TimeInterval?
    @ObservationIgnored private var pendingOpenAnnouncement: MovementAnnouncement?
    @ObservationIgnored private var pendingTerminalAnnouncement: MovementAnnouncement?

    public init(
        schedule: OpportunitySchedule,
        initialDurationSeconds: TimeInterval? = nil,
        declarationArmDelay: TimeInterval = 0.8,
        accessibility: MovementAccessibility = .init(),
        requiresLifecycleConfirmation: Bool = false,
        now: @escaping () -> TimeInterval,
        onAction: @escaping (MovementAction) -> Void = { _ in },
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        precondition(schedule.durationOptionsSeconds.count >= 2)
        precondition(declarationArmDelay.isFinite && declarationArmDelay >= 0)
        let recommendedDuration = schedule.durationOptionsSeconds[0]
        let quickDuration = schedule.durationOptionsSeconds[1]
        precondition(recommendedDuration.isFinite && quickDuration.isFinite)
        let initialDuration = initialDurationSeconds ?? recommendedDuration
        precondition(initialDuration == recommendedDuration || initialDuration == quickDuration)

        recommendedDurationSeconds = recommendedDuration
        quickDurationSeconds = quickDuration
        selectedDurationSeconds = initialDuration
        remainingSeconds = Int(ceil(initialDuration))
        self.declarationArmDelay = declarationArmDelay
        self.requiresLifecycleConfirmation = requiresLifecycleConfirmation
        self.accessibility = accessibility
        self.now = now
        self.onAction = onAction
        self.onAnnouncement = onAnnouncement
    }

    public convenience init(
        schedule: OpportunitySchedule,
        initialDurationSeconds: TimeInterval? = nil,
        accessibility: MovementAccessibility = .init(),
        requiresLifecycleConfirmation: Bool = false,
        onAction: @escaping (MovementAction) -> Void = { _ in },
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        let clock = MovementMonotonicClock()
        self.init(
            schedule: schedule,
            initialDurationSeconds: initialDurationSeconds,
            accessibility: accessibility,
            requiresLifecycleConfirmation: requiresLifecycleConfirmation,
            now: { clock.seconds },
            onAction: onAction,
            onAnnouncement: onAnnouncement,
        )
    }

    public func open() {
        guard phase == .ready else { return }
        let start = now()
        openedAt = start
        deadline = start + selectedDurationSeconds
        phase = .running
        pendingOpenAnnouncement = .opened(durationSeconds: Int(ceil(selectedDurationSeconds)))
        onAction(.opened)
        if !requiresLifecycleConfirmation {
            confirmLifecycle(.opened)
        }
    }

    public func refresh() {
        guard let openedAt, let deadline, phase == .running else { return }
        let currentTime = now()
        let previousRemainingSeconds = remainingSeconds
        let rawProgress = min(
            1,
            max(0, currentTime - openedAt) / selectedDurationSeconds,
        )

        remainingSeconds = Int(ceil(max(0, deadline - currentTime)))
        progress = displayedProgress(rawProgress)
        isDeclarationArmed = currentTime - openedAt >= declarationArmDelay

        if remainingSeconds == 0 {
            finish(.timerFinished, announcement: .finished)
            return
        }
        if !announcedOneMinute,
           previousRemainingSeconds > 60,
           remainingSeconds <= 60 {
            announcedOneMinute = true
            onAnnouncement(.oneMinuteRemaining)
        }
    }

    public func select(_ choice: MovementChoice) {
        guard phase == .running, choice != selectedChoice else { return }
        selectedChoice = choice
        onAnnouncement(.selectionChanged(choice))
    }

    public func selectFromKeyboard(_ choice: MovementChoice) {
        refresh()
        guard phase == .running, isDeclarationArmed else { return }
        select(choice)
    }

    public func selectRecommendedDuration() {
        guard phase == .running,
              selectedDurationSeconds == recommendedDurationSeconds,
              lastExplicitDurationSelection != recommendedDurationSeconds
        else {
            return
        }

        confirmSelectedDuration()
    }

    public func selectQuickDuration() {
        guard phase == .running,
              selectedDurationSeconds != quickDurationSeconds,
              let openedAt
        else {
            return
        }

        selectedDurationSeconds = quickDurationSeconds
        deadline = openedAt + quickDurationSeconds
        announcedOneMinute = false
        confirmSelectedDuration()
    }

    public func confirmSelectedDuration() {
        guard phase == .running,
              lastExplicitDurationSelection != selectedDurationSeconds
        else {
            return
        }
        lastExplicitDurationSelection = selectedDurationSeconds
        onAction(.selectedDuration(selectedDurationSeconds))
        refresh()
    }

    public func selectQuickDurationFromKeyboard() {
        refresh()
        guard phase == .running, isDeclarationArmed else { return }
        selectQuickDuration()
    }

    public func doneEarly() {
        finish(.doneEarly, announcement: .doneEarly)
    }

    public func doneEarlyFromKeyboard() {
        finishFromKeyboard(.doneEarly, announcement: .doneEarly)
    }

    public func alreadyMoved() {
        finish(.alreadyMoved, announcement: .alreadyMoved)
    }

    public func alreadyMovedFromKeyboard() {
        finishFromKeyboard(.alreadyMoved, announcement: .alreadyMoved)
    }

    public func positionChanged() {
        finish(.positionChanged, announcement: .positionChanged)
    }

    public func positionChangedFromKeyboard() {
        finishFromKeyboard(.positionChanged, announcement: .positionChanged)
    }

    public func skip() {
        finish(.skipped, announcement: .skipped)
    }

    public func confirmLifecycle(_ action: MovementAction) {
        switch action {
        case .opened:
            guard let pendingOpenAnnouncement else { return }
            self.pendingOpenAnnouncement = nil
            onAnnouncement(pendingOpenAnnouncement)
        case .selectedDuration:
            break
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .skipped:
            guard let terminal = action.terminal,
                  phase == .finished(terminal),
                  let pendingTerminalAnnouncement
            else {
                return
            }
            self.pendingTerminalAnnouncement = nil
            onAnnouncement(pendingTerminalAnnouncement)
        }
    }

    public func rejectLifecycle(_ action: MovementAction) {
        switch action {
        case .opened:
            guard pendingOpenAnnouncement != nil else { return }
            phase = .ready
            openedAt = nil
            deadline = nil
            remainingSeconds = Int(ceil(selectedDurationSeconds))
            progress = 0
            isDeclarationArmed = false
            announcedOneMinute = false
            pendingOpenAnnouncement = nil
            pendingTerminalAnnouncement = nil
        case let .selectedDuration(duration):
            if lastExplicitDurationSelection == duration {
                lastExplicitDurationSelection = nil
            }
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .skipped:
            guard let terminal = action.terminal,
                  phase == .finished(terminal)
            else {
                return
            }
            phase = .running
            pendingTerminalAnnouncement = nil
        }
    }

    public func updateAccessibility(_ accessibility: MovementAccessibility) {
        self.accessibility = accessibility
        refresh()
    }
}

public extension MovementModel {
    static func preview(
        _ phase: Phase = .running,
        selectedChoice: MovementChoice = .walkOrWheel,
        selectedDurationSeconds: TimeInterval = 300,
        remainingSeconds: Int = 225,
        accessibility: MovementAccessibility = .init(),
    ) -> MovementModel {
        let schedule = previewSchedule()
        let duration = schedule.durationOptionsSeconds.contains(selectedDurationSeconds)
            ? selectedDurationSeconds
            : schedule.durationOptionsSeconds[0]
        let elapsed = duration - min(max(TimeInterval(remainingSeconds), 0), duration)
        let model = MovementModel(
            schedule: schedule,
            accessibility: accessibility,
            now: { elapsed },
        )
        model.selectedChoice = selectedChoice
        model.selectedDurationSeconds = duration
        model.remainingSeconds = Int(ceil(duration))
        switch phase {
        case .ready:
            return model
        case .running:
            model.openedAt = 0
            model.deadline = duration
            model.phase = .running
            model.refresh()
        case .finished:
            model.openedAt = 0
            model.deadline = duration
            model.phase = phase
            model.remainingSeconds = 0
            model.progress = 1
            model.isDeclarationArmed = true
        }
        return model
    }
}

private extension MovementModel {
    static func previewSchedule() -> OpportunitySchedule {
        // Preview fixtures mirror the normative recommended and quick durations.
        guard let schedule = try? OpportunitySchedule(
            softDueSeconds: 3000,
            targetSeconds: 3600,
            latestPreferredSeconds: 4200,
            durationOptionsSeconds: [300, 120],
        ) else {
            preconditionFailure("Static movement preview timing is invalid")
        }
        return schedule
    }

    func finishFromKeyboard(
        _ terminal: MovementTerminalAction,
        announcement: MovementAnnouncement,
    ) {
        refresh()
        guard phase == .running, isDeclarationArmed else { return }
        finish(terminal, announcement: announcement)
    }

    func finish(
        _ terminal: MovementTerminalAction,
        announcement: MovementAnnouncement,
    ) {
        guard phase == .running else { return }
        phase = .finished(terminal)
        pendingTerminalAnnouncement = announcement
        onAction(terminal.action)
        if !requiresLifecycleConfirmation {
            confirmLifecycle(terminal.action)
        }
    }

    func displayedProgress(_ rawProgress: Double) -> Double {
        guard accessibility.reduceMotion || accessibility.staticPresentation else {
            return rawProgress
        }
        if rawProgress >= 1 { return 1 }
        if rawProgress >= 0.5 { return 0.5 }
        return 0
    }
}

private extension MovementTerminalAction {
    var action: MovementAction {
        switch self {
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .alreadyMoved: .alreadyMoved
        case .positionChanged: .positionChanged
        case .skipped: .skipped
        }
    }
}

private extension MovementAction {
    var terminal: MovementTerminalAction? {
        switch self {
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .alreadyMoved: .alreadyMoved
        case .positionChanged: .positionChanged
        case .skipped: .skipped
        case .opened, .selectedDuration: nil
        }
    }
}

private final class MovementMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
