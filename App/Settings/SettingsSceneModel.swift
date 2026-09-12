import Domain
import Observation
import SettingsFeature

@Observable
final class SettingsSceneModel {
    let featureModel: SettingsFeatureModel
    private(set) var integrationsRuntime: SettingsIntegrationsRuntime
    private(set) var trustCenterSnapshot: TrustCenterSnapshot

    private let integrations: SettingsIntegrationsAppRuntime?
    private let trustCenter: SettingsTrustCenterAppRuntime?
    private let excludedApplications: SettingsExcludedApplicationsAppAdapter
    private let loadsFeatureModel: Bool

    init(
        featureModel: SettingsFeatureModel,
        integrations: SettingsIntegrationsAppRuntime,
        trustCenter: SettingsTrustCenterAppRuntime,
        excludedApplications: SettingsExcludedApplicationsAppAdapter = .init(),
    ) {
        self.featureModel = featureModel
        self.integrations = integrations
        self.trustCenter = trustCenter
        self.excludedApplications = excludedApplications
        loadsFeatureModel = true
        integrationsRuntime = .unavailable
        trustCenterSnapshot = .preview(.empty)
    }

    init(
        previewModel: SettingsFeatureModel,
        integrationsRuntime: SettingsIntegrationsRuntime = .unavailable,
        trustCenterSnapshot: TrustCenterSnapshot = .preview(.empty),
    ) {
        featureModel = previewModel
        integrations = nil
        trustCenter = nil
        excludedApplications = .init()
        loadsFeatureModel = false
        self.integrationsRuntime = integrationsRuntime
        self.trustCenterSnapshot = trustCenterSnapshot
    }

    var excludedApplicationPresentations: [SettingsExcludedApplicationPresentation] {
        excludedApplications.presentations(for: featureModel.excludedApplicationBundleIDs)
    }

    var excludedApplicationPicker: SettingsExcludedApplicationPicker? {
        guard loadsFeatureModel else { return nil }
        return { [excludedApplications] in
            await excludedApplications.chooseApplication()
        }
    }
    var integrationsActions: SettingsIntegrationsActions {
        guard let integrations else { return .none }
        return integrations.actions { [weak self] runtime in
            await self?.publishIntegrations(runtime)
        }
    }

    var trustCenterActions: TrustCenterActions {
        guard let trustCenter else { return .none }
        return TrustCenterActions(
            beginEducation: { [weak self] capability in
                guard let self else { return }
                Task { await self.applyTrustCenter { await trustCenter.beginEducation(capability) } }
            },
            grant: { [weak self] capability in
                guard let self else { return }
                await self.applyTrustCenter { await trustCenter.grant(capability) }
            },
            revoke: { [weak self] capability in
                guard let self else { return }
                await self.applyTrustCenter { await trustCenter.revoke(capability) }
            },
            engageKillSwitch: { [weak self] in
                guard let self else { return }
                await self.applyTrustCenter { await trustCenter.engageKillSwitch() }
            },
            disengageKillSwitch: { [weak self] in
                guard let self else { return }
                await self.applyTrustCenter { await trustCenter.disengageKillSwitch() }
            },
            exportTrustData: { [weak self] in
                guard let self, let trustCenter = self.trustCenter else { return .unavailable }
                return await trustCenter.exportTrustData()
            },
            deleteTrustData: { [weak self] in
                guard let self, let trustCenter = self.trustCenter else { return .unavailable }
                let result = await trustCenter.deleteTrustData()
                await self.applyTrustCenter { await trustCenter.load() }
                return result
            },
            refresh: { [weak self] in
                guard let self else { return }
                await self.refreshTrustCenter()
            },
        )
    }

    func load() async {
        if loadsFeatureModel, featureModel.phase == .loading {
            await featureModel.load()
        }
        await loadIntegrations()
        await loadTrustCenter()
    }

    func loadIntegrations() async {
        await refreshIntegrations()
    }

    func refreshIntegrations() async {
        guard let integrations else { return }
        await publishIntegrations(integrations.load())
    }

    func loadTrustCenter() async {
        await refreshTrustCenter()
    }

    func refreshTrustCenter() async {
        guard let trustCenter else { return }
        await publishTrustCenter(trustCenter.load())
    }

    func selectedSectionDidChange(_ section: SettingsSection) async {
        switch section {
        case .integrations:
            await refreshIntegrations()
        case .sensingAndIntelligence:
            await refreshTrustCenter()
        default:
            break
        }
    }

    private func publishIntegrations(_ runtime: SettingsIntegrationsRuntime) async {
        integrationsRuntime = runtime
        await featureModel.reconcileLaunchAtLoginEnabled(runtime.launchAtLogin.isEffectivelyEnabled)
    }

    private func publishTrustCenter(_ snapshot: TrustCenterSnapshot) async {
        trustCenterSnapshot = snapshot
    }

    private func applyTrustCenter(
        _ produce: @escaping @MainActor @Sendable () async -> TrustCenterSnapshot,
    ) async {
        await publishTrustCenter(produce())
    }

}

extension AppDelegate {
    func makeSettingsSceneModel() -> SettingsSceneModel {
        settingsSceneModel
    }

    func buildSettingsSceneModel() -> SettingsSceneModel {
        do {
            let catalog = try SettingsScheduleCatalog(
                gentle: ProtocolProfiles.configuration(for: .gentle),
                balanced: ProtocolProfiles.configuration(for: .balanced),
                frequentMovement: ProtocolProfiles.configuration(for: .frequentMovement),
                researchInformedHighFrequency: ProtocolProfiles.configuration(
                    for: .researchInformedHighFrequency,
                ),
                effectivelyDisabledAfterActiveUseSeconds: 86400,
            )
            let featureModel = SettingsFeatureModel(
                client: makeSettingsFeatureClient(
                    chooseExportDestination: { request, suggestedName in
                        try await SettingsFilePanels.chooseExportDestination(
                            request: request,
                            suggestedName: suggestedName,
                        )
                    },
                    writeExportData: { data, url, options in
                        try SettingsFilePanels.writeExportData(data, to: url, options: options)
                    },
                ),
                catalog: catalog,
            )
            return SettingsSceneModel(
                featureModel: featureModel,
                integrations: settingsIntegrationsRuntime,
                trustCenter: settingsTrustCenterRuntime,
            )
        } catch {
            preconditionFailure("Generated Settings schedule catalog is invalid: \(error)")
        }
    }
}
