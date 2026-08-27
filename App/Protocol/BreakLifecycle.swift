import Foundation

enum ProtocolLifecycleError: Error, Equatable {
    case invalidMovementDuration
    case invalidSnoozeDuration
    case noActiveSession
    case invalidTransition
}

enum MovementLifecycleEvent: Equatable, Sendable {
    case opened
    case selectedDuration(TimeInterval)
    case timerFinished
    case doneEarly
    case alreadyMoved
    case positionChanged
    case skipped
}

enum MergedLifecycleEvent: Equatable, Sendable {
    case opened
    case visualTimerFinished
    case selectedDuration(TimeInterval)
    case movementTimerFinished
    case doneEarly
    case alreadyMoved
    case positionChanged
    case visualOnly
    case skipped
}

enum MergedSegment: Equatable {
    case visual
    case movement
}

enum LifecycleSession: Equatable {
    case movement(selectedDuration: TimeInterval?)
    case merged(segment: MergedSegment, selectedDuration: TimeInterval?)
}

actor ProtocolLifecycleGate {
    private var isLocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isLocked else {
            isLocked = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isLocked = false
            return
        }
        waiters.removeFirst().resume()
    }
}
