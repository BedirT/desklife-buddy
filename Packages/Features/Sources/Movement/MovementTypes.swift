import Foundation

public enum MovementContext: Equatable, Sendable {
    case standalone
    case merged
}

public enum MovementChoice: CaseIterable, Equatable, Sendable {
    case walkOrWheel
    case smallSpace
    case seated
}

public enum MovementGuidance: Equatable, Sendable {
    case walkOrWheel
    case smallSpace
    case seated

    public init(choice: MovementChoice) {
        self = switch choice {
        case .walkOrWheel: .walkOrWheel
        case .smallSpace: .smallSpace
        case .seated: .seated
        }
    }
}

public enum MovementTerminalAction: Equatable, Sendable {
    case timerFinished
    case doneEarly
    case alreadyMoved
    case positionChanged
    case visualOnly
    case skipped
}

public enum MovementAction: Equatable, Sendable {
    case opened
    case selectedDuration(TimeInterval)
    case timerFinished
    case doneEarly
    case alreadyMoved
    case positionChanged
    case visualOnly
    case skipped
}

public enum MovementAnnouncement: Equatable, Sendable {
    case opened(durationSeconds: Int)
    case selectionChanged(MovementChoice)
    case oneMinuteRemaining
    case finished
    case doneEarly
    case alreadyMoved
    case positionChanged
    case visualOnly
    case skipped
}

public struct MovementAccessibility: Equatable, Sendable {
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

public enum MovementControl: CaseIterable, Equatable, Sendable {
    case walkOrWheel
    case smallSpace
    case seated
    case quickDuration
    case doneEarly
    case alreadyMoved
    case skip
    case positionChange
    case visualOnly
}

extension MovementChoice {
    var identifier: String {
        switch self {
        case .walkOrWheel: "walkOrWheel"
        case .smallSpace: "smallSpace"
        case .seated: "seated"
        }
    }

    var control: MovementControl {
        switch self {
        case .walkOrWheel: .walkOrWheel
        case .smallSpace: .smallSpace
        case .seated: .seated
        }
    }
}
