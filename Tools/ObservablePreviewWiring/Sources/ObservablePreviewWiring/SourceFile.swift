import Foundation

/// One Swift source handed to the analyzer, already classified as shipping or
/// preview-only. Classification is by file name so it stays reviewable: a
/// reader can tell which bucket a file is in without running anything.
public struct SourceFile: Sendable {
    public let path: String
    public let text: String
    public let isPreviewOnly: Bool

    public init(path: String, text: String, isPreviewOnly: Bool) {
        self.path = path
        self.text = text
        self.isPreviewOnly = isPreviewOnly
    }

    public init(path: String, text: String) {
        self.init(path: path, text: text, isPreviewOnly: Self.isPreviewOnly(path: path))
    }

    /// Preview-only sources are the ones SnapshotPreviews and Xcode canvas
    /// build fixtures in. Nothing they assign ever runs in the shipping app.
    public static func isPreviewOnly(path: String) -> Bool {
        let name = (path as NSString).lastPathComponent
        if name.hasSuffix("+Previews.swift") { return true }
        let stem = (name as NSString).deletingPathExtension
        return ["PreviewData", "PreviewLibrary", "PreviewFixture"].contains { stem.contains($0) }
    }
}
