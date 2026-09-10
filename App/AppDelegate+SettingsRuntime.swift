import AppKit
import Domain
import Foundation
import Onboarding

extension AppDelegate {
    #if DEBUG
        static func runtimeIDFactory(
            for verificationMode: HeadsUpVerificationMode?,
        ) -> () -> UUID {
            guard verificationMode?.usesInjectedSnapshot == true else { return UUID.init }
            return { HeadsUpVerificationRoute.deliveryID }
        }
    #endif

    typealias OnboardingRuntimeStarter = (
        SwiftDataProtocolStore,
        [String],
    ) async throws -> Void

    func startApplication(
        arguments: [String],
        baseStore injectedStore: SwiftDataProtocolStore? = nil,
        onboardingPersistence injectedOnboardingPersistence: OnboardingPersistenceClient? = nil,
        onboardingPolicy: OnboardingLaunchPolicy = .automatic,
        onboardingPresenter injectedPresenter: OnboardingWindowPresenter? = nil,
        onboardingRuntimeStarter injectedRuntimeStarter: OnboardingRuntimeStarter? = nil,
        now: @escaping () -> Date = Date.init,
    ) async throws {
        let baseStore: SwiftDataProtocolStore = if let injectedStore {
            injectedStore
        } else {
            try SwiftDataProtocolStore(
                inMemory: Self.isRunningTests || Self.isVerificationRun,
            )
        }
        settingsStore = baseStore

        let persistence = try injectedOnboardingPersistence
            ?? OnboardingPersistenceClient(container: baseStore.container)
        let evaluatesOnboarding = shouldEvaluateOnboarding(
            policy: onboardingPolicy,
            arguments: arguments,
        )
        let needsOnboarding = try evaluatesOnboarding && persistence.prepareForLaunch(at: now())
        let rhythmCatalog = try makeOnboardingRhythmCatalog()
        let runtimeStarter: OnboardingRuntimeStarter = injectedRuntimeStarter ?? { [weak self] store, arguments in
            guard let self else { return }
            try await startOperatingRuntime(baseStore: store, arguments: arguments)
        }
        if needsOnboarding {
            presentOnboarding(
                persistence: persistence,
                baseStore: baseStore,
                arguments: arguments,
                presenter: injectedPresenter,
                rhythmCatalog: rhythmCatalog,
                runtimeStarter: runtimeStarter,
                now: now,
            )
            return
        }

        do {
            try await runtimeStarter(baseStore, arguments)
        } catch {
            guard evaluatesOnboarding, let committed = try persistence.committedState() else {
                throw error
            }
            presentOnboardingRecovery(
                committed: committed,
                baseStore: baseStore,
                arguments: arguments,
                presenter: injectedPresenter,
                rhythmCatalog: rhythmCatalog,
                runtimeStarter: runtimeStarter,
            )
        }
    }

    func startOperatingRuntime(
        baseStore: SwiftDataProtocolStore,
        arguments: [String],
    ) async throws {
        guard runtime == nil else { return }
        let store = runtimeStore(base: baseStore, arguments: arguments)
        let headsUpPolicy = Self.verificationHeadsUpPolicy(arguments: arguments)
        let configurationOverride: ProtocolConfiguration? = if arguments.contains(
            "--verify-automatic-visual",
        ) {
            try await Self.automaticVisualVerificationConfiguration(
                from: (baseStore.loadResolvedPreferences()).configuration,
            )
        } else {
            nil
        }
        let prepared = try await prepareRuntime(
            baseStore: baseStore,
            runtimeStore: store,
            headsUpPolicy: headsUpPolicy,
            configurationOverride: configurationOverride,
        )
        settingsStore = baseStore
        install(
            configuration: prepared.runtime.configuration,
            runtime: prepared.runtime,
            headsUpPolicy: headsUpPolicy,
        )
        do {
            try await restore(prepared.runtime)
            lastRuntimeError = nil
            publishOperatingSurfaces(arguments: arguments)
        } catch {
            lastRuntimeError = error
            discardFailedRuntimeInstallation()
            throw error
        }
    }

    private func shouldEvaluateOnboarding(
        policy: OnboardingLaunchPolicy,
        arguments: [String],
    ) -> Bool {
        switch policy {
        case .requireWhenIncomplete:
            true
        case .bypass:
            false
        case .automatic:
            !Self.isRunningTests
                && (!Self.isVerificationRun || arguments.contains(where: {
                    $0.hasPrefix("--verify-onboarding")
                }))
        }
    }

    private func presentOnboarding(
        persistence: OnboardingPersistenceClient,
        baseStore: SwiftDataProtocolStore,
        arguments: [String],
        presenter injectedPresenter: OnboardingWindowPresenter?,
        rhythmCatalog: OnboardingRhythmCatalog,
        runtimeStarter: @escaping OnboardingRuntimeStarter,
        now: @escaping () -> Date,
    ) {
        let presenter = injectedPresenter ?? makeOnboardingWindowPresenter()
        let accessibility = NSWorkspace.shared
        let client = OnboardingClient(
            commitCompletion: { payload in
                try persistence.complete(
                    selection: OnboardingPreferenceSelection(
                        scheduleProfile: payload.scheduleProfile,
                        preferredMovement: payload.preferredMovement,
                        presentation: payload.presentation,
                        staticOverlayBrightness: payload.staticOverlayBrightness,
                        timerAnnouncements: payload.timerAnnouncements,
                        seatedContentFirst: payload.seatedContentFirst,
                    ),
                    at: now(),
                )
            },
            commitSkip: {
                try persistence.skip(at: now())
            },
            activate: { [weak self] _ in
                guard let self else { return }
                let operatingStore = try SwiftDataProtocolStore(container: baseStore.container)
                try await runtimeStarter(operatingStore, arguments)
                finishOnboarding(using: presenter)
            },
        )
        let model = OnboardingModel(
            client: client,
            rhythmCatalog: rhythmCatalog,
            systemAccessibility: OnboardingSystemAccessibility(
                reduceMotion: accessibility.accessibilityDisplayShouldReduceMotion,
                reduceTransparency: accessibility.accessibilityDisplayShouldReduceTransparency,
                increaseContrast: accessibility.accessibilityDisplayShouldIncreaseContrast,
            ),
        )
        onboardingModel = model
        onboardingWindowPresenter = presenter
        presenter.present(model)
        configureOnboardingVerification(arguments: arguments)
    }

    private func presentOnboardingRecovery(
        committed: OnboardingCommittedState,
        baseStore: SwiftDataProtocolStore,
        arguments: [String],
        presenter injectedPresenter: OnboardingWindowPresenter?,
        rhythmCatalog: OnboardingRhythmCatalog,
        runtimeStarter: @escaping OnboardingRuntimeStarter,
    ) {
        let presenter = injectedPresenter ?? makeOnboardingWindowPresenter()
        let accessibility = NSWorkspace.shared
        let client = OnboardingClient(
            commitCompletion: { _ in committed },
            commitSkip: { committed },
            activate: { [weak self] _ in
                guard let self else { return }
                let operatingStore = try SwiftDataProtocolStore(container: baseStore.container)
                try await runtimeStarter(operatingStore, arguments)
                finishOnboarding(using: presenter)
            },
        )
        let model = OnboardingModel.recovery(
            committed: committed,
            client: client,
            rhythmCatalog: rhythmCatalog,
            systemAccessibility: OnboardingSystemAccessibility(
                reduceMotion: accessibility.accessibilityDisplayShouldReduceMotion,
                reduceTransparency: accessibility.accessibilityDisplayShouldReduceTransparency,
                increaseContrast: accessibility.accessibilityDisplayShouldIncreaseContrast,
            ),
        )
        onboardingModel = model
        onboardingWindowPresenter = presenter
        presenter.present(model)
        configureOnboardingVerification(arguments: arguments)
    }

    private func makeOnboardingRhythmCatalog() throws -> OnboardingRhythmCatalog {
        func timing(_ profile: ProtocolProfileID) throws -> OnboardingRhythmTiming {
            let configuration = try ProtocolProfiles.configuration(for: profile)
            return OnboardingRhythmTiming(
                visualTargetSeconds: configuration.visual.targetSeconds,
                movementTargetSeconds: configuration.movement.targetSeconds,
            )
        }
        return try OnboardingRhythmCatalog(
            gentle: timing(.gentle),
            balanced: timing(.balanced),
            frequentMovement: timing(.frequentMovement),
        )
    }

    private func makeOnboardingWindowPresenter() -> OnboardingWindowPresenter {
        let controller = onboardingWindowController
            ?? OnboardingWindowController(activationController: appWindowActivationController)
        onboardingWindowController = controller
        return OnboardingWindowPresenter(
            present: { [weak controller] model in controller?.present(model: model) },
            dismiss: { [weak controller] in controller?.close() },
        )
    }

    private func finishOnboarding(using presenter: OnboardingWindowPresenter) {
        presenter.dismiss()
        onboardingModel = nil
        onboardingWindowPresenter = nil
        onboardingWindowController = nil
    }

    func prepareRuntime(
        baseStore: SwiftDataSettingsStore,
        runtimeStore: any ProtocolRuntimeStore,
        headsUpPolicy: HeadsUpRuntimePolicy?,
        configurationOverride: ProtocolConfiguration? = nil,
    ) async throws -> (resolved: ResolvedAppPreferences, runtime: ProtocolRuntime) {
        let resolved = try await baseStore.loadResolvedPreferences()
        return (
            resolved,
            makeRuntime(
                resolved: resolved,
                store: runtimeStore,
                headsUpPolicy: headsUpPolicy,
                configuration: configurationOverride ?? resolved.configuration,
            ),
        )
    }

    private func runtimeStore(
        base: SwiftDataProtocolStore,
        arguments: [String],
    ) -> any ProtocolRuntimeStore {
        #if DEBUG
            let verificationMode = HeadsUpVerificationMode(arguments: arguments)
            headsUpVerificationMode = verificationMode
            if verificationMode?.enablesRuntime == true {
                let tracingStore = HeadsUpVerificationRuntimeStore(base: base)
                headsUpVerificationStore = tracingStore
                return tracingStore
            }
        #endif
        return base
    }

    private func makeRuntime(
        resolved: ResolvedAppPreferences,
        store: any ProtocolRuntimeStore,
        headsUpPolicy: HeadsUpRuntimePolicy?,
        configuration: ProtocolConfiguration,
    ) -> ProtocolRuntime {
        guard let headsUpPolicy else {
            return ProtocolRuntime(
                configuration: configuration,
                store: store,
                profileID: resolved.profileID,
                initialPreferences: resolved.preferences,
            )
        }
        return ProtocolRuntime(
            configuration: configuration,
            store: store,
            headsUpRuntimePolicy: headsUpPolicy,
            profileID: resolved.profileID,
            initialPreferences: resolved.preferences,
            makeID: {
                #if DEBUG
                    Self.runtimeIDFactory(for: self.headsUpVerificationMode)()
                #else
                    UUID()
                #endif
            },
        )
    }
}
