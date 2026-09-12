import Domain
import Foundation
import Observation

@Observable
public final class MovementModel {
    private static let automaticTimerRetryDelay: TimeInterval = 1

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
    public private(set) var accessibility: MovementAccessibility

    public let recommendedDurationSeconds: TimeInterval
    public let quickDurationSeconds: TimeInterval
    public let context: MovementContext
    public let choiceOrder: [MovementChoice]

    public var guidance: MovementGuidance {
        MovementGuidance(choice: selectedChoice)
    }

    @ObservationIgnored private let requiresLifecycleConfirmation: Bool
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let onAction: (MovementAction) -> Void
    @ObservationIgnored private let onAnnouncement: (MovementAnnouncement) -> Void
    @ObservationIgnored private var openedAt: TimeInterval?
    @ObservationIgnored private var announcedOneMinute = false
    @ObservationIgnored private var lastExplicitDurationSelection: TimeInterval?
    @ObservationIgnored private var pendingOpenAnnouncement: MovementAnnouncement?
    @ObservationIgnored private var pendingTerminalAnnouncement: MovementAnnouncement?
    @ObservationIgnored private var nextAutomaticTimerRetryAt: TimeInterval?

    /// Creates a surface from projected durations (D-032 story 2.7): the
    /// presenter projects recommended/quick values from the coordinator-owned
    /// schedule and the surface never reads the engine itself.
    public init(
        durations: MovementDurations,
        initialDurationSeconds: TimeInterval? = nil,
        context: MovementContext = .standalone,
        accessibility: MovementAccessibility = .init(),
        seatedContentFirst: Bool = false,
        requiresLifecycleConfirmation: Bool = false,
        now: @escaping () -> TimeInterval,
        onAction: @escaping (MovementAction) -> Void = { _ in },
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        precondition(durations.recommendedSeconds.isFinite && durations.recommendedSeconds > 0)
        precondition(durations.quickSeconds.isFinite && durations.quickSeconds > 0)
        let initialDuration = initialDurationSeconds ?? durations.recommendedSeconds
        precondition(
            initialDuration == durations.recommendedSeconds
                || initialDuration == durations.quickSeconds,
        )

        recommendedDurationSeconds = durations.recommendedSeconds
        quickDurationSeconds = durations.quickSeconds
        self.context = context
        choiceOrder = seatedContentFirst
            ? [.seated, .walkOrWheel, .smallSpace]
            : [.walkOrWheel, .smallSpace, .seated]
        selectedDurationSeconds = initialDuration
        remainingSeconds = Int(ceil(initialDuration))
        self.requiresLifecycleConfirmation = requiresLifecycleConfirmation
        self.accessibility = accessibility
        self.now = now
        self.onAction = onAction
        self.onAnnouncement = onAnnouncement
    }

    public func open() {
        guard phase == .ready else { return }
        let start = now()
        nextAutomaticTimerRetryAt = nil
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

        if remainingSeconds == 0 {
            if let nextAutomaticTimerRetryAt, currentTime < nextAutomaticTimerRetryAt {
                return
            }
            nextAutomaticTimerRetryAt = nil
            finish(.timerFinished, announcement: .finished)
            return
        }
        let shouldAnnounceOneMinute = !announcedOneMinute
            && previousRemainingSeconds > 60
            && remainingSeconds <= 60
        if shouldAnnounceOneMinute {
            announcedOneMinute = true
            onAnnouncement(.oneMinuteRemaining)
        }
    }

    public func select(_ choice: MovementChoice) {
        guard phase == .running, choice != selectedChoice else { return }
        selectedChoice = choice
        onAnnouncement(.selectionChanged(choice))
    }

    /// Keyboard route for printed choices (D-032): active on the first frame.
    public func selectFromKeyboard(_ choice: MovementChoice) {
        refresh()
        guard phase == .running else { return }
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
              selectedDurationSeconds != quickDurationSeconds
              || lastExplicitDurationSelection != quickDurationSeconds,
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
    /// Keyboard route for the quick duration (D-032): active on the first frame.
    public func selectQuickDurationFromKeyboard() {
        refresh()
        guard phase == .running else { return }
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

    public func justTheVisualOne() {
        guard context == .merged else { return }
        finish(.visualOnly, announcement: .visualOnly)
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
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .visualOnly, .skipped:
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
            announcedOneMinute = false
            pendingOpenAnnouncement = nil
            pendingTerminalAnnouncement = nil
            nextAutomaticTimerRetryAt = nil
        case let .selectedDuration(duration):
            if lastExplicitDurationSelection == duration {
                lastExplicitDurationSelection = nil
            }
        case .timerFinished, .doneEarly, .alreadyMoved, .positionChanged, .visualOnly, .skipped:
            guard let terminal = action.terminal,
                  phase == .finished(terminal)
            else {
                return
            }
            phase = .running
            pendingTerminalAnnouncement = nil
            nextAutomaticTimerRetryAt = terminal == .timerFinished
                ? now() + Self.automaticTimerRetryDelay
                : nil
        }
    }

    public func updateAccessibility(_ accessibility: MovementAccessibility) {
        self.accessibility = accessibility
        refresh()
    }
}

public extension MovementModel {
    convenience init(
        durations: MovementDurations,
        initialDurationSeconds: TimeInterval? = nil,
        context: MovementContext = .standalone,
        accessibility: MovementAccessibility = .init(),
        seatedContentFirst: Bool = false,
        requiresLifecycleConfirmation: Bool = false,
        onAction: @escaping (MovementAction) -> Void = { _ in },
        onAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
    ) {
        let clock = MovementMonotonicClock()
        self.init(
            durations: durations,
            initialDurationSeconds: initialDurationSeconds,
            context: context,
            accessibility: accessibility,
            seatedContentFirst: seatedContentFirst,
            requiresLifecycleConfirmation: requiresLifecycleConfirmation,
            now: { clock.seconds },
            onAction: onAction,
            onAnnouncement: onAnnouncement,
        )
    }

    static func preview(
        _ phase: Phase = .running,
        selectedChoice: MovementChoice = .walkOrWheel,
        selectedDurationSeconds: TimeInterval = 300,
        remainingSeconds: Int = 225,
        accessibility: MovementAccessibility = .init(),
        context: MovementContext = .standalone,
        seatedContentFirst: Bool = false,
    ) -> MovementModel {
        // Preview fixtures mirror the normative recommended and quick durations.
        let durations = MovementDurations(recommendedSeconds: 300, quickSeconds: 120)
        let duration = [durations.recommendedSeconds, durations.quickSeconds].contains(
            selectedDurationSeconds,
        )
            ? selectedDurationSeconds
            : durations.recommendedSeconds
        let elapsed = duration - min(max(TimeInterval(remainingSeconds), 0), duration)
        let model = MovementModel(
            durations: durations,
            context: context,
            accessibility: accessibility,
            seatedContentFirst: seatedContentFirst,
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
        }
        return model
    }
}

private extension MovementModel {
    /// Keyboard route for terminal declarations (D-032): active on the first frame.
    func finishFromKeyboard(
        _ terminal: MovementTerminalAction,
        announcement: MovementAnnouncement,
    ) {
        refresh()
        guard phase == .running else { return }
        finish(terminal, announcement: announcement)
    }

    func finish(
        _ terminal: MovementTerminalAction,
        announcement: MovementAnnouncement,
    ) {
        guard phase == .running else { return }
        if terminal != .timerFinished {
            nextAutomaticTimerRetryAt = nil
        }
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

private final class MovementMonotonicClock {
    private let origin = ContinuousClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
