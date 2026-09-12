import AppKit
import SettingsFeature
import SwiftUI

struct SettingsView: View {
    @State private var sceneModel: SettingsSceneModel

    init(appDelegate: AppDelegate) {
        _sceneModel = State(initialValue: appDelegate.settingsSceneModel)
    }

    init(sceneModel: SettingsSceneModel) {
        _sceneModel = State(initialValue: sceneModel)
    }

    var body: some View {
        SettingsFeatureView(
            model: sceneModel.featureModel,
            loadsAutomatically: false,
            excludedApplicationPresentations: sceneModel.excludedApplicationPresentations,
            excludedApplicationPicker: sceneModel.excludedApplicationPicker,
            integrationsRuntime: sceneModel.integrationsRuntime,
            integrationsActions: sceneModel.integrationsActions,
            trustCenterSnapshot: sceneModel.trustCenterSnapshot,
            trustCenterActions: sceneModel.trustCenterActions,
        )
        .task {
            await sceneModel.load()
        }
        .onChange(of: sceneModel.featureModel.selectedSection) { _, section in
            Task { await sceneModel.selectedSectionDidChange(section) }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await sceneModel.refreshIntegrations() }
            Task { await sceneModel.refreshTrustCenter() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            Task { await sceneModel.refreshIntegrations() }
            Task { await sceneModel.refreshTrustCenter() }
        }
    }
}

#Preview("Settings") {
    SettingsView(
        sceneModel: SettingsSceneModel(
            previewModel: .preview(.balanced),
            integrationsRuntime: SettingsIntegrationsRuntime(
                notifications: .available(authorization: .notDetermined),
                launchAtLogin: .enabled,
            ),
        ),
    )
    .frame(width: 1000, height: 700)
}
