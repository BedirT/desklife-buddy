import Domain
import Foundation
import Onboarding
import SwiftData

extension AppDelegate {
    func configureOnboardingVerification(arguments: [String]) {
        #if DEBUG
            guard arguments.contains(where: { $0.hasPrefix("--verify-onboarding") }) else {
                return
            }
            addVerificationTimer(
                delay: 0.75,
                selector: #selector(captureVerificationOnboarding),
            )
            if arguments.contains("--verify-onboarding-complete") {
                addVerificationTimer(
                    delay: 1.25,
                    selector: #selector(completeVerificationOnboarding),
                )
                addVerificationTimer(
                    delay: 2.5,
                    selector: #selector(captureVerificationOnboardingTerminal),
                )
            }
            if arguments.contains("--verify-onboarding-skip") {
                addVerificationTimer(
                    delay: 1.25,
                    selector: #selector(skipVerificationOnboarding),
                )
                addVerificationTimer(
                    delay: 2.5,
                    selector: #selector(captureVerificationOnboardingTerminal),
                )
            }
        #endif
    }

    #if DEBUG
        @objc func captureVerificationOnboarding() {
            guard let store = settingsStore,
                  let caches = FileManager.default.urls(
                      for: .cachesDirectory,
                      in: .userDomainMask,
                  ).first
            else { return }

            let window = onboardingWindowController?.window
            let captured = window.map {
                OverlayVerificationCapture.write(view: $0.contentView, prefix: "onboarding")
            } ?? false
            let context = ModelContext(store.container)
            let completionCount = (try? context.fetch(
                FetchDescriptor<StoredOnboardingCompletion>(),
            ).count) ?? -1
            let stateCount = (try? context.fetch(FetchDescriptor<StoredProtocolState>()).count) ?? -1
            let events = OnboardingVerificationEvents(context: context)
            let frame = window?.frame ?? .zero
            let visibleFrame = window?.screen?.visibleFrame ?? .zero
            let isCentered = abs(frame.midX - visibleFrame.midX) < 1
                && abs(frame.midY - visibleFrame.midY) < 1
            let state: [String: Any] = [
                "captured": captured,
                "centeredOnDisplay": isCentered,
                "completionCount": completionCount,
                "eventCount": events.count,
                "eventKinds": events.kinds,
                "eventSources": events.sources,
                "onboardingEventCount": events.onboardingCount,
                "frame": [frame.origin.x, frame.origin.y, frame.width, frame.height],
                "headsUpLifecycleInstalled": headsUpLifecycleCoordinator != nil,
                "protocolStateCount": stateCount,
                "runtimeInstalled": runtime != nil,
                "statusItemInstalled": hasInstalledStatusItem,
                "visibleFrame": [
                    visibleFrame.origin.x,
                    visibleFrame.origin.y,
                    visibleFrame.width,
                    visibleFrame.height,
                ],
                "windowVisible": window?.isVisible == true,
            ]
            guard let data = try? JSONSerialization.data(
                withJSONObject: state,
                options: [.prettyPrinted, .sortedKeys],
            ) else { return }
            let filename = "onboarding-state-\(ProcessInfo.processInfo.processIdentifier).json"
            try? data.write(to: caches.appendingPathComponent(filename), options: .atomic)
        }

        @objc func completeVerificationOnboarding() {
            guard let model = onboardingModel else { return }
            model.selectRhythm(.frequentMovement)
            model.selectMovement(.seatedActive)
            model.selectPresentation(.staticPresentation)
            model.setStaticOverlayBrightness(0.72)
            model.setTimerAnnouncements(.none)
            model.setSeatedContentFirst(true)
            Task {
                while model.page != .ready {
                    await model.continueForward()
                }
                await model.continueForward()
            }
        }

        @objc func skipVerificationOnboarding() {
            guard let model = onboardingModel else { return }
            Task { await model.skip() }
        }

        @objc func captureVerificationOnboardingTerminal() {
            guard let store = settingsStore,
                  let caches = FileManager.default.urls(
                      for: .cachesDirectory,
                      in: .userDomainMask,
                  ).first
            else { return }

            let arguments = ProcessInfo.processInfo.arguments
            let expectation = onboardingTerminalExpectation(arguments: arguments)
            let context = ModelContext(store.container)
            let completion = try? OnboardingPersistenceClient(
                container: store.container,
            ).completion()
            let preferences = storedOnboardingPreferences(context: context)
            let events = OnboardingVerificationEvents(context: context)
            let state: [String: Any] = [
                "completionOutcomeMatches": completion?.outcome == expectation.outcome,
                "eventCount": events.count,
                "eventKinds": events.kinds,
                "eventSources": events.sources,
                "onboardingEventCount": events.onboardingCount,
                "onboardingCleared": onboardingModel == nil,
                "preferencesMatch": preferences == expectation.preferences,
                "runtimeInstalled": runtime != nil,
                "runtimePreferencesMatch": runtime?.preferences == expectation.preferences,
                "runtimeStatus": lastRuntimeError == nil ? "ok" : "error",
                "statusItemInstalled": hasInstalledStatusItem,
                "terminalVerified": completion?.outcome == expectation.outcome
                    && preferences == expectation.preferences
                    && runtime?.preferences == expectation.preferences
                    && runtime != nil
                    && hasInstalledStatusItem
                    && onboardingModel == nil
                    && events.onboardingCount == 0
                    && lastRuntimeError == nil,
                "windowVisible": onboardingWindowController?.window?.isVisible == true,
            ]
            guard let data = try? JSONSerialization.data(
                withJSONObject: state,
                options: [.prettyPrinted, .sortedKeys],
            ) else { return }
            let filename = "onboarding-terminal-state-\(ProcessInfo.processInfo.processIdentifier).json"
            try? data.write(to: caches.appendingPathComponent(filename), options: .atomic)
        }

        private func onboardingTerminalExpectation(
            arguments: [String],
        ) -> (outcome: OnboardingCompletionOutcome, preferences: AppPreferences?) {
            guard arguments.contains("--verify-onboarding-complete") else {
                return (.skipped, try? OnboardingPreferenceSelection.defaults.preferences())
            }
            let selection = OnboardingPreferenceSelection(
                scheduleProfile: .frequentMovement,
                preferredMovement: .seatedActive,
                presentation: .staticPresentation,
                staticOverlayBrightness: 0.72,
                timerAnnouncements: .none,
                seatedContentFirst: true,
            )
            return (.completed, try? selection.preferences())
        }

        private func storedOnboardingPreferences(context: ModelContext) -> AppPreferences? {
            guard let stored = try? context.fetch(FetchDescriptor<StoredAppPreferences>()).first else {
                return nil
            }
            return try? SettingsPayloadCodec.decodePreferences(stored.preferencesPayload)
        }
    #endif
}

#if DEBUG
    private struct OnboardingVerificationEvents {
        let count: Int
        let kinds: [String]
        let sources: [String]
        let onboardingCount: Int

        init(context: ModelContext) {
            let events = (try? context.fetch(FetchDescriptor<StoredOpportunityEvent>())) ?? []
            count = events.count
            kinds = events.map(\.kind)
            sources = events.map(\.source)
            onboardingCount = events.count(where: {
                $0.kind.localizedCaseInsensitiveContains("onboarding")
                    || $0.source.localizedCaseInsensitiveContains("onboarding")
            })
        }
    }
#endif
