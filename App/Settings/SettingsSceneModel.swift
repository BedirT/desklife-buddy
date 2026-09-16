import Domain
import Foundation
import Observation
import SettingsFeature

@Observable
final class SettingsSceneModel {
    let featureModel: SettingsFeatureModel
    /// Live pairing sheet model: ceremony transitions persist the QR-shared
    /// key to the Keychain. Nil wherever the seam is unwired (previews).
    let companionPairingModel: CompanionPairingSheetModel?
    private(set) var integrationsRuntime: SettingsIntegrationsRuntime
    private(set) var trustCenterSnapshot: TrustCenterSnapshot
    /// Trust Center rules rows over the R1 proposal store. Nil (not empty)
    /// means the seam is unwired and the R2 section stays hidden.
    private(set) var trustCenterRulesSnapshot: TrustCenterRulesSnapshot?

    private let integrations: SettingsIntegrationsAppRuntime?
    private let trustCenter: SettingsTrustCenterAppRuntime?
    private let ruleManagement: RuleManagementModel?
    private let excludedApplications: SettingsExcludedApplicationsAppAdapter
    private let loadsFeatureModel: Bool
    init(
        featureModel: SettingsFeatureModel,
        integrations: SettingsIntegrationsAppRuntime,
        trustCenter: SettingsTrustCenterAppRuntime,
        excludedApplications: SettingsExcludedApplicationsAppAdapter = .init(),
        ruleManagement: RuleManagementModel? = nil,
        companionPairing: CompanionPairingSheetModel? = nil,
    ) {
        self.featureModel = featureModel
        companionPairingModel = companionPairing
        self.integrations = integrations
        self.trustCenter = trustCenter
        self.ruleManagement = ruleManagement
        self.excludedApplications = excludedApplications
        loadsFeatureModel = true
        integrationsRuntime = .unavailable
        trustCenterSnapshot = .preview(.empty)
        trustCenterRulesSnapshot = nil
    }

    init(
        previewModel: SettingsFeatureModel,
        integrationsRuntime: SettingsIntegrationsRuntime = .unavailable,
        trustCenterSnapshot: TrustCenterSnapshot = .preview(.empty),
        companionPairing: CompanionPairingSheetModel? = nil,
    ) {
        featureModel = previewModel
        companionPairingModel = companionPairing
        integrations = nil
        trustCenter = nil
        ruleManagement = nil
        excludedApplications = .init()
        loadsFeatureModel = false
        self.integrationsRuntime = integrationsRuntime
        self.trustCenterSnapshot = trustCenterSnapshot
        trustCenterRulesSnapshot = nil
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
                await applyTrustCenter { await trustCenter.grant(capability) }
            },
            revoke: { [weak self] capability in
                guard let self else { return }
                await applyTrustCenter { await trustCenter.revoke(capability) }
            },
            engageKillSwitch: { [weak self] in
                guard let self else { return }
                await applyTrustCenter { await trustCenter.engageKillSwitch() }
            },
            disengageKillSwitch: { [weak self] in
                guard let self else { return }
                await applyTrustCenter { await trustCenter.disengageKillSwitch() }
            },
            exportTrustData: { [weak self] in
                guard let self, let trustCenter = self.trustCenter else { return .unavailable }
                return await trustCenter.exportTrustData()
            },
            deleteTrustData: { [weak self] in
                guard let self, let trustCenter = self.trustCenter else { return .unavailable }
                let result = await trustCenter.deleteTrustData()
                await applyTrustCenter { await trustCenter.load() }
                return result
            },
            refresh: { [weak self] in
                guard let self else { return }
                await refreshTrustCenter()
            },
        )
    }

    var trustCenterRulesActions: TrustCenterRulesActions {
        guard ruleManagement != nil else { return .none }
        return TrustCenterRulesActions(
            decide: { [weak self] ruleKey, decision in
                guard let self, let model = ruleManagement else { return }
                _ = try? await model.decide(ruleKey: ruleKey, decision: decision)
                await publishTrustCenterRules()
            },
            undo: { [weak self] ruleKey in
                guard let self, let model = ruleManagement else { return }
                _ = try? await model.undo(ruleKey: ruleKey)
                await publishTrustCenterRules()
            },
            reset: { [weak self] ruleKey in
                guard let self, let model = ruleManagement else { return }
                try? await model.reset(ruleKey: ruleKey)
                await publishTrustCenterRules()
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
        if let trustCenter {
            await publishTrustCenter(trustCenter.load())
        }
        if trustCenterRulesSnapshot == nil {
            await loadTrustCenterRules()
        }
    }

    /// Loads stored proposals into the rule-management model and publishes
    /// the rules snapshot. A failed load leaves the previous snapshot (or
    /// the hidden nil seam) in place; owner actions re-publish without a
    /// reload so a just-made transition keeps its undo.
    func loadTrustCenterRules() async {
        guard let ruleManagement else { return }
        _ = try? await ruleManagement.load()
        await publishTrustCenterRules()
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

    private func publishTrustCenterRules() async {
        guard let ruleManagement else { return }
        trustCenterRulesSnapshot = TrustCenterRulesSnapshot(rows: ruleManagement.rows)
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
            let ruleManagement: RuleManagementModel? = if let ruleStore = ruleProposalStoreForWiring() {
                RuleManagementModel(store: ruleStore, ticks: { ProcessInfo.processInfo.systemUptime })
            } else {
                nil
            }
            // Live ceremony backing for the pairing QR-sheet: transitions mint
            // keys via the Keychain store and persist them there. No new
            // identity strings: the service string lives in
            // CompanionKeychainStore from wave 1.
            let companionPairing = CompanionPairingSheetModel(
                keyGenerator: { try CompanionKeychainStore.makeKey() },
                now: { Date() },
                pairingIDGenerator: { UUID() },
                onPersist: { state in
                    try CompanionKeychainStore.saveKey(state.key, pairingID: state.pairingID)
                },
                onRevoke: { state in
                    try CompanionKeychainStore.deleteKey(pairingID: state.pairingID)
                },
            )
            return SettingsSceneModel(
                featureModel: featureModel,
                integrations: settingsIntegrationsRuntime,
                trustCenter: settingsTrustCenterRuntime,
                ruleManagement: ruleManagement,
                companionPairing: companionPairing,
            )
        } catch {
            preconditionFailure("Generated Settings schedule catalog is invalid: \(error)")
        }
    }
}
