import Foundation
import StatusMenu
import VisualReset

extension AppDelegate {
    static func verificationHeadsUpPolicy(
        arguments: [String],
    ) -> HeadsUpRuntimePolicy? {
        #if DEBUG
            guard let mode = HeadsUpVerificationMode(arguments: arguments),
                  mode.enablesRuntime
            else {
                return nil
            }
            return HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)
        #else
            return nil
        #endif
    }

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static var isVerificationRun: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("--verify-") }
    }

    func configureVerification(arguments: [String]) {
        #if DEBUG
            if arguments.contains("--verify-status-menu") {
                addVerificationTimer(delay: 1, selector: #selector(openVerificationMenu))
                for delay in [2.0, 2.4, 2.8, 3.2] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationMenu))
                }
            }
            if arguments.contains("--verify-visual-reset") {
                let coordinator = VisualResetOverlayCoordinator(
                    durationSeconds: configuration?.visual.durationOptionsSeconds[0] ?? 20,
                    onLifecycle: { _, completion in completion(.success(())) },
                    onAnnouncement: VisualResetAccessibilityAnnouncer.post,
                )
                verificationOverlayCoordinator = coordinator
                coordinator.present()
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(
                        delay: delay,
                        selector: #selector(captureVerificationVisualReset),
                    )
                }
            }
            if arguments.contains("--verify-movement") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationMovement))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(
                        delay: delay,
                        selector: #selector(captureVerificationMovement),
                    )
                }
            }
            if arguments.contains("--verify-merged") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationMerged))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationMerged))
                }
            }
            if arguments.contains("--verify-snooze") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationSnooze))
                for delay in [1.0, 2.0, 3.0] {
                    addVerificationTimer(delay: delay, selector: #selector(captureVerificationSnooze))
                }
            }
            configureHeadsUpPermissionVerification(arguments: arguments)
        #endif
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
