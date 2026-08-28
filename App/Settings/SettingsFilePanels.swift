import AppKit
import Domain
import UniformTypeIdentifiers

enum SettingsFilePanels {
    static func chooseExportDestination(
        request: HistoryExportRequest,
        suggestedName: String,
    ) async throws -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [contentType(for: request.format)]
        return panel.runModal() == .OK ? panel.url : nil
    }

    nonisolated static func writeExportData(
        _ data: Data,
        to url: URL,
        options: Data.WritingOptions,
    ) throws {
        try data.write(to: url, options: options)
    }

    private static func contentType(
        for format: HistoryExportFormat,
    ) -> UTType {
        switch format {
        case .csv:
            .commaSeparatedText
        case .json:
            .json
        }
    }
}
