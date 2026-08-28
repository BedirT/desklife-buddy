import AppKit
import SettingsFeature
import SwiftUI
import UniformTypeIdentifiers

struct SettingsExcludedApplicationsAppAdapter {
    func presentations(
        for bundleIDs: [String],
    ) -> [SettingsExcludedApplicationPresentation] {
        bundleIDs.compactMap(presentation(for:))
    }

    func chooseApplication() async -> SettingsExcludedApplicationPresentation? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return presentation(at: url)
    }

    private func presentation(
        for bundleID: String,
    ) -> SettingsExcludedApplicationPresentation? {
        guard let url = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID,
        ) else {
            return nil
        }
        return presentation(at: url)
    }

    private func presentation(at url: URL) -> SettingsExcludedApplicationPresentation? {
        guard let bundle = Bundle(url: url), let bundleID = bundle.bundleIdentifier else {
            return nil
        }
        let name = FileManager.default.displayName(atPath: url.path)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return SettingsExcludedApplicationPresentation(
            bundleID: bundleID,
            displayName: name,
            icon: Image(nsImage: icon),
        )
    }
}
