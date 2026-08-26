import AppKit
import CoreGraphics
import Domain
import Foundation

struct WorkspaceActivityNotifications {
    let willSleep: Notification.Name
    let didWake: Notification.Name
    let sessionDidResignActive: Notification.Name
    let sessionDidBecomeActive: Notification.Name

    static let workspace = WorkspaceActivityNotifications(
        willSleep: NSWorkspace.willSleepNotification,
        didWake: NSWorkspace.didWakeNotification,
        sessionDidResignActive: NSWorkspace.sessionDidResignActiveNotification,
        sessionDidBecomeActive: NSWorkspace.sessionDidBecomeActiveNotification,
    )
}

private struct MonotonicSeconds {
    private let origin: SuspendingClock.Instant

    nonisolated init() {
        origin = SuspendingClock.now
    }

    nonisolated func read() -> TimeInterval {
        let components = origin.duration(to: .now).components
        return TimeInterval(components.seconds)
            + TimeInterval(components.attoseconds) / 1_000_000_000_000_000_000
    }
}

final class SystemActivitySource: NSObject {
    private let uptimeSeconds: () -> TimeInterval
    private let secondsSinceInput: () -> TimeInterval
    private let notificationCenter: NotificationCenter
    private let onAvailabilityChange: (ActivitySample) -> Void
    private var systemAwake = true
    private var sessionActive = true
    private let screenLocked = false

    init(
        uptimeSeconds: @escaping () -> TimeInterval = MonotonicSeconds().read,
        secondsSinceInput: @escaping () -> TimeInterval = {
            guard let anyInput = CGEventType(rawValue: UInt32.max) else { return .infinity }
            return CGEventSource.secondsSinceLastEventType(
                .combinedSessionState,
                eventType: anyInput,
            )
        },
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        notifications: WorkspaceActivityNotifications = .workspace,
        onAvailabilityChange: @escaping (ActivitySample) -> Void = { _ in },
    ) {
        self.uptimeSeconds = uptimeSeconds
        self.secondsSinceInput = secondsSinceInput
        self.notificationCenter = notificationCenter
        self.onAvailabilityChange = onAvailabilityChange
        super.init()
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWillSleep),
            name: notifications.willSleep,
            object: nil,
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleDidWake),
            name: notifications.didWake,
            object: nil,
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionDidResignActive),
            name: notifications.sessionDidResignActive,
            object: nil,
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSessionDidBecomeActive),
            name: notifications.sessionDidBecomeActive,
            object: nil,
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func sample() -> ActivitySample {
        ActivitySample(
            uptimeSeconds: uptimeSeconds(),
            secondsSinceInput: secondsSinceInput(),
            systemAwake: systemAwake,
            sessionActive: sessionActive,
            screenLocked: screenLocked,
        )
    }

    @objc private func handleWillSleep() {
        systemAwake = false
        onAvailabilityChange(sample())
    }

    @objc private func handleDidWake() {
        systemAwake = true
        onAvailabilityChange(sample())
    }

    @objc private func handleSessionDidResignActive() {
        sessionActive = false
        onAvailabilityChange(sample())
    }

    @objc private func handleSessionDidBecomeActive() {
        sessionActive = true
        onAvailabilityChange(sample())
    }
}
