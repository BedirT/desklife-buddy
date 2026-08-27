extension MovementTerminalAction {
    var action: MovementAction {
        switch self {
        case .timerFinished: .timerFinished
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
}
