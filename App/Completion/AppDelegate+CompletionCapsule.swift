import AppKit
import Domain

extension AppDelegate {
    func installCompletionCapsule() {
        completionCapsuleCoordinator?.tearDown()
        completionCapsuleCoordinator = CompletionCapsuleCoordinator { [weak self] in
            let presentation = self?.runtime?.preferences?.accessibility.presentation ?? .standard
            return CompletionCapsulePolicy.allowsPresentation(
                systemReduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
                presentation: presentation,
            )
        }
    }

    func presentCompletionAcknowledgement() {
        completionCapsuleCoordinator?.present()
    }
}

enum CompletionCapsulePolicy {
    static func allowsPresentation(
        systemReduceMotion: Bool,
        presentation: AccessibleBreakPresentation,
    ) -> Bool {
        !systemReduceMotion && presentation == .standard
    }
}
