import Domain
import Foundation

extension AppDelegate {
    func startApplication(arguments: [String]) async throws {
        let baseStore = try SwiftDataProtocolStore(
            inMemory: Self.isRunningTests || Self.isVerificationRun,
        )
        let store = runtimeStore(base: baseStore, arguments: arguments)
        let headsUpPolicy = Self.verificationHeadsUpPolicy(arguments: arguments)
        let prepared = try await prepareRuntime(
            baseStore: baseStore,
            runtimeStore: store,
            headsUpPolicy: headsUpPolicy,
        )
        install(
            configuration: prepared.resolved.configuration,
            runtime: prepared.runtime,
            headsUpPolicy: headsUpPolicy,
        )
        restore(prepared.runtime)
    }

    func prepareRuntime(
        baseStore: SwiftDataSettingsStore,
        runtimeStore: any ProtocolRuntimeStore,
        headsUpPolicy: HeadsUpRuntimePolicy?,
    ) async throws -> (resolved: ResolvedAppPreferences, runtime: ProtocolRuntime) {
        let resolved = try await baseStore.loadResolvedPreferences()
        return (
            resolved,
            makeRuntime(
                resolved: resolved,
                store: runtimeStore,
                headsUpPolicy: headsUpPolicy,
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
    ) -> ProtocolRuntime {
        guard let headsUpPolicy else {
            return ProtocolRuntime(
                configuration: resolved.configuration,
                store: store,
                profileID: resolved.profileID,
                initialPreferences: resolved.preferences,
            )
        }
        return ProtocolRuntime(
            configuration: resolved.configuration,
            store: store,
            headsUpRuntimePolicy: headsUpPolicy,
            profileID: resolved.profileID,
            initialPreferences: resolved.preferences,
            makeID: {
                #if DEBUG
                    HeadsUpVerificationRoute.deliveryID
                #else
                    UUID()
                #endif
            },
        )
    }
}
