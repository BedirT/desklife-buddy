import AppKit
import Foundation
import StatusMenu
import VisualReset

extension AppDelegate {
    static func verificationHeadsUpPolicy(
        arguments: [String],
    ) -> HeadsUpRuntimePolicy? {
        #if DEBUG
            let isVerification = arguments.contains { $0.hasPrefix("--verify-") }
            guard isVerification else {
                return HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)
            }
            guard let mode = HeadsUpVerificationMode(arguments: arguments),
                  mode.enablesRuntime
            else {
                return nil
            }
            return HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)
        #else
            return HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)
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
            if arguments.contains("--verify-settings") {
                addVerificationTimer(delay: 0.5, selector: #selector(openVerificationSettings))
                addVerificationTimer(delay: 2.5, selector: #selector(captureVerificationSettings))
            }
            configureCompletionCapsuleVerification(arguments: arguments)
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

    @objc func openVerificationSettings() {
        settingsVerificationRouteAccepted = openSettingsWindow()
    }

    @objc func captureVerificationSettings() {
        let window = NSApp.windows.first(where: { window in
            window.isVisible && window.level == .normal && window.styleMask.contains(.titled)
        })
        guard let caches = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask,
        ).first else { return }

        let captured = window.map { window in
            OverlayVerificationCapture.write(view: window.contentView, prefix: "settings")
        } ?? false
        let model = settingsSceneModel.featureModel
        let state: [String: Any] = [
            "captured": captured,
            "featureReady": model.phase == .ready,
            "preferencesLoaded": model.preferences != nil,
            "routeAccepted": settingsVerificationRouteAccepted ?? false,
            "selectedSection": model.selectedSection.rawValue,
            "windowVisible": window?.isVisible == true,
        ]
        guard let data = try? JSONSerialization.data(
            withJSONObject: state,
            options: [.prettyPrinted, .sortedKeys],
        ) else {
            return
        }
        let filename = "settings-state-\(ProcessInfo.processInfo.processIdentifier).json"
        try? data.write(to: caches.appendingPathComponent(filename), options: .atomic)
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
