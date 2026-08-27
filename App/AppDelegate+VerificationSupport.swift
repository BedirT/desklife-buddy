import Foundation
import StatusMenu

extension AppDelegate {
    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isVerificationRun: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--verify-") }
    }

    func addVerificationTimer(delay: TimeInterval, selector: Selector) {
        let timer = Timer(
            timeInterval: delay,
            target: self,
            selector: selector,
            userInfo: nil,
            repeats: false,
        )
        RunLoop.main.add(timer, forMode: .common)
    }

    static func verificationState(from arguments: [String]) -> StatusMenuModel.PreviewState? {
        #if DEBUG
            guard let index = arguments.firstIndex(of: "--verify-status-state"),
                  arguments.indices.contains(index + 1)
            else {
                return nil
            }
            return switch arguments[index + 1] {
            case "operating": .normal
            case "visual-due": .visualDue
            case "movement-due": .movementDue
            case "both-due": .bothDue
            case "paused": .paused
            case "timed-pause": .timedPause
            default: nil
            }
        #else
            nil
        #endif
    }
}

extension Notification.Name {
    static let statusMenuRoute = Notification.Name("app.statusMenuRoute")
}
