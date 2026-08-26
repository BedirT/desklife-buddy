import Foundation
import Observation

public enum VisualResetAction: Equatable, Sendable {
    case opened
    case timerFinished
    case doneEarly
    case skipped
}

public enum VisualResetAnnouncement: Equatable, Sendable {
    case opened(durationSeconds: Int)
    case tenSecondsRemaining
    case finished
    case doneEarly
    case skipped
}

public struct VisualResetAccessibility: Equatable, Sendable {
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

@Observable
public final class VisualResetModel {
    public enum Phase: Equatable {
        case ready
        case running
        case finalSeconds
        case finished(VisualResetAction)
    }

    public private(set) var phase: Phase = .ready
    public private(set) var remainingSeconds: Int
    public private(set) var progress: Double = 0
    public private(set) var isDeclarationArmed = false
    public private(set) var accessibility: VisualResetAccessibility

    @ObservationIgnored private let durationSeconds: TimeInterval
    @ObservationIgnored private let finalSecondsThreshold: TimeInterval
    @ObservationIgnored private let declarationArmDelay: TimeInterval
    @ObservationIgnored private let now: () -> TimeInterval
    @ObservationIgnored private let onAction: (VisualResetAction) -> Void
    @ObservationIgnored private let onAnnouncement: (VisualResetAnnouncement) -> Void
    @ObservationIgnored private var openedAt: TimeInterval?
    @ObservationIgnored private var announcedTenSeconds = false

    public init(
        durationSeconds: TimeInterval,
        finalSecondsThreshold: TimeInterval = 3,
        declarationArmDelay: TimeInterval = 0.8,
        accessibility: VisualResetAccessibility = .init(),
        now: @escaping () -> TimeInterval,
        onAction: @escaping (VisualResetAction) -> Void = { _ in },
        onAnnouncement: @escaping (VisualResetAnnouncement) -> Void = { _ in },
    ) {
        precondition(durationSeconds.isFinite && durationSeconds > 0)
        precondition(finalSecondsThreshold.isFinite && finalSecondsThreshold >= 0)
        precondition(declarationArmDelay.isFinite && declarationArmDelay >= 0)
        self.durationSeconds = durationSeconds
        self.finalSecondsThreshold = min(finalSecondsThreshold, durationSeconds)
        self.declarationArmDelay = declarationArmDelay
        self.accessibility = accessibility
        self.now = now
        self.onAction = onAction
        self.onAnnouncement = onAnnouncement
        remainingSeconds = Int(ceil(durationSeconds))
    }

    public convenience init(
        durationSeconds: TimeInterval = 20,
        accessibility: VisualResetAccessibility = .init(),
        onAction: @escaping (VisualResetAction) -> Void = { _ in },
        onAnnouncement: @escaping (VisualResetAnnouncement) -> Void = { _ in },
    ) {
        let clock = VisualResetMonotonicClock()
        self.init(
            durationSeconds: durationSeconds,
            accessibility: accessibility,
            now: { clock.seconds },
            onAction: onAction,
            onAnnouncement: onAnnouncement,
        )
    }

    public func open() {
        guard phase == .ready else { return }
        openedAt = now()
        phase = .running
        onAction(.opened)
        onAnnouncement(.opened(durationSeconds: Int(ceil(durationSeconds))))
    }

    public func refresh() {
        guard let openedAt, isActive else { return }
        let elapsed = max(0, now() - openedAt)
        let rawProgress = min(1, elapsed / durationSeconds)
        let previousRemainingSeconds = remainingSeconds
        remainingSeconds = Int(ceil(max(0, durationSeconds - elapsed)))
        isDeclarationArmed = elapsed >= declarationArmDelay
        progress = displayedProgress(rawProgress)

        if remainingSeconds == 0 {
            finish(.timerFinished, announcement: .finished)
            return
        }
        phase = remainingSeconds <= Int(ceil(finalSecondsThreshold))
            ? .finalSeconds
            : .running
        let reachedTenSecondMilestone = previousRemainingSeconds > 10 && remainingSeconds <= 10
        if !announcedTenSeconds, reachedTenSecondMilestone {
            announcedTenSeconds = true
            onAnnouncement(.tenSecondsRemaining)
        }
    }

    public func doneEarly() {
        guard isActive else { return }
        finish(.doneEarly, announcement: .doneEarly)
    }

    public func doneEarlyFromKeyboard() {
        refresh()
        guard isActive, isDeclarationArmed else { return }
        finish(.doneEarly, announcement: .doneEarly)
    }

    public func skip() {
        guard isActive else { return }
        finish(.skipped, announcement: .skipped)
    }

    public func updateAccessibility(_ accessibility: VisualResetAccessibility) {
        self.accessibility = accessibility
        refresh()
    }
}

public extension VisualResetModel {
    static func preview(
        _ phase: Phase = .running,
        remainingSeconds: Int? = nil,
        accessibility: VisualResetAccessibility = .init(),
    ) -> VisualResetModel {
        let previewRemaining = remainingSeconds ?? (phase == .finalSeconds ? 3 : 12)
        let elapsed = TimeInterval(20 - min(max(previewRemaining, 0), 20))
        let model = VisualResetModel(durationSeconds: 20, accessibility: accessibility, now: { elapsed })
        switch phase {
        case .ready:
            return model
        case .running:
            model.phase = .running
            model.openedAt = 0
            model.refresh()
        case .finalSeconds:
            model.phase = .running
            model.openedAt = 0
            model.refresh()
        case .finished:
            model.phase = phase
            model.openedAt = 0
            model.remainingSeconds = 0
            model.progress = 1
            model.isDeclarationArmed = true
        }
        return model
    }
}

private extension VisualResetModel {
    var isActive: Bool {
        phase == .running || phase == .finalSeconds
    }

    func displayedProgress(_ rawProgress: Double) -> Double {
        guard accessibility.reduceMotion || accessibility.staticPresentation else {
            return rawProgress
        }
        if rawProgress >= 1 { return 1 }
        if rawProgress >= 0.5 { return 0.5 }
        return 0
    }

    func finish(
        _ action: VisualResetAction,
        announcement: VisualResetAnnouncement,
    ) {
        guard isActive else { return }
        phase = .finished(action)
        onAction(action)
        onAnnouncement(announcement)
    }
}

private final class VisualResetMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
