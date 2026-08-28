import AppKit
import Foundation

#if DEBUG
    extension AppDelegate {
        func configureCompletionCapsuleVerification(arguments: [String]) {
            guard arguments.contains("--verify-completion-capsule") else { return }
            addVerificationTimer(
                delay: 1,
                selector: #selector(openVerificationCompletionCapsule),
            )
            addVerificationTimer(
                delay: 1.25,
                selector: #selector(capturePresentedCompletionCapsuleState),
            )
            addVerificationTimer(
                delay: 3.25,
                selector: #selector(captureDismissedCompletionCapsuleState),
            )
        }

        @objc func openVerificationCompletionCapsule() {
            presentCompletionAcknowledgement()
        }

        @objc func capturePresentedCompletionCapsuleState() {
            writeCompletionCapsuleVerificationState(stage: "presented")
        }

        @objc func captureDismissedCompletionCapsuleState() {
            writeCompletionCapsuleVerificationState(stage: "dismissed")
        }

        private func writeCompletionCapsuleVerificationState(stage: String) {
            guard let caches = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask,
            ).first else { return }
            let state: [String: Any] = [
                "isPresenting": completionCapsuleCoordinator?.isPresenting == true,
                "stage": stage,
                "visibleCompletionPanelCount": NSApp.windows.count(where: {
                    $0 is CompletionCapsulePanel && $0.isVisible
                }),
            ]
            guard let data = try? JSONSerialization.data(
                withJSONObject: state,
                options: [.prettyPrinted, .sortedKeys],
            ) else { return }
            let filename = "completion-capsule-\(stage)-state-"
                + "\(ProcessInfo.processInfo.processIdentifier).json"
            try? data.write(to: caches.appendingPathComponent(filename), options: .atomic)
        }
    }
#endif
