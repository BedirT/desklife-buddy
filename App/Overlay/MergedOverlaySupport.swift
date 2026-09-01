import AppKit
import Domain
import Foundation
import Movement
import VisualReset

typealias MergedLifecycleCallback = (
    MergedLifecycleEvent,
    @escaping (Result<Void, any Error>) -> Void,
) -> Void

extension MergedOverlayCoordinator {
    convenience init(
        policy: OverlayDisplayPolicy = .allDisplays,
        visualDurationSeconds: TimeInterval = 20,
        movementSchedule: OpportunitySchedule,
        acknowledgementDurationSeconds: TimeInterval = 2,
        accessibilityPreferences: AccessibilityPreferences = .defaults,
        onLifecycle: @escaping MergedLifecycleCallback,
        onVisualAnnouncement: @escaping (VisualResetAnnouncement) -> Void = { _ in },
        onMovementAnnouncement: @escaping (MovementAnnouncement) -> Void = { _ in },
        onCompletion: @escaping () -> Void = {},
    ) {
        let clock = MergedOverlayMonotonicClock()
        self.init(
            policy: policy,
            visualDurationSeconds: visualDurationSeconds,
            movementSchedule: movementSchedule,
            acknowledgementDurationSeconds: acknowledgementDurationSeconds,
            accessibilityPreferences: accessibilityPreferences,
            now: { clock.seconds },
            displays: AppKitOverlayDisplays.current,
            makePanel: {
                display,
                    role,
                    content,
                    accessibilityPreferences,
                    onEntranceSettled,
                    onCancel in
                MergedPanel(
                    displayID: display.id,
                    frame: display.frame,
                    content: content,
                    role: role,
                    accessibilityPreferences: accessibilityPreferences,
                    onEntranceSettled: onEntranceSettled,
                    onCancel: onCancel,
                )
            },
            captureFrontmostProcessIdentifier: {
                NSWorkspace.shared.frontmostApplication?.processIdentifier
            },
            activate: { NSApp.activate() },
            isAppFrontmost: { NSApp.isActive },
            restore: VisualResetOverlayCoordinator.restoreApplication,
            scheduleRefresh: VisualResetOverlayCoordinator.liveRefreshScheduler,
            observeScreenChanges: VisualResetOverlayCoordinator.observeScreenChanges,
            onLifecycle: onLifecycle,
            onVisualAnnouncement: onVisualAnnouncement,
            onMovementAnnouncement: onMovementAnnouncement,
            onCompletion: onCompletion,
        )
    }

    static func lifecycleEvent(for action: VisualResetAction) -> MergedLifecycleEvent {
        switch action {
        case .opened: .opened
        case .timerFinished: .visualTimerFinished
        case .doneEarly: .doneEarly
        case .skipped: .skipped
        }
    }

    static func lifecycleEvent(for action: MovementAction) -> MergedLifecycleEvent? {
        switch action {
        case .opened: nil
        case let .selectedDuration(duration): .selectedDuration(duration)
        case .timerFinished: .movementTimerFinished
        case .doneEarly: .doneEarly
        case .alreadyMoved: .alreadyMoved
        case .positionChanged: .positionChanged
        case .visualOnly: .visualOnly
        case .skipped: .skipped
        }
    }
}

extension MovementAction {
    var terminal: MovementTerminalAction? {
        switch self {
        case .timerFinished: .timerFinished
        case .doneEarly: .doneEarly
        case .alreadyMoved: .alreadyMoved
        case .positionChanged: .positionChanged
        case .visualOnly: .visualOnly
        case .skipped: .skipped
        case .opened, .selectedDuration: nil
        }
    }

    var showsMergedCompletion: Bool {
        switch self {
        case .timerFinished, .doneEarly, .alreadyMoved: true
        case .opened, .selectedDuration, .positionChanged, .visualOnly, .skipped: false
        }
    }
}

final class MergedOverlayMonotonicClock {
    private let origin = SuspendingClock.now

    var seconds: TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}
