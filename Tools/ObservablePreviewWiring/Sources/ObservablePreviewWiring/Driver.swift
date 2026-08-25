import Foundation

/// Walks the repository's shipping source trees and reports violations on
/// stdout. `App/` and every `Packages/*/Sources` are scanned together, because
/// the property is declared in a package and its real writer usually lives in
/// `App/` - a per-package scan would report every wired property as unwired.
public enum Driver {
    public static func run(root: URL, output: (String) -> Void = { print($0) }) -> [Finding] {
        let files = sources(root: root)
        let findings = Analyzer.analyze(files)

        guard !findings.isEmpty else {
            output("check-observable-preview-wiring: OK (\(files.count) sources)")
            return []
        }
        output("Observable preview-wiring violations:")
        for finding in findings {
            output("  \(finding.message)")
        }
        return findings
    }

    static func sources(root: URL) -> [SourceFile] {
        var directories = [root.appending(path: "App")]
        let packages = root.appending(path: "Packages")
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: packages,
            includingPropertiesForKeys: nil,
        )) ?? []
        directories += contents
            .map { $0.appending(path: "Sources") }
            .sorted { $0.path < $1.path }

        var files: [SourceFile] = []
        for directory in directories {
            guard let walker = FileManager.default.enumerator(
                at: directory,
                includingPropertiesForKeys: nil,
            ) else { continue }
            var paths: [URL] = []
            for case let url as URL in walker where url.pathExtension == "swift" {
                paths.append(url)
            }
            for url in paths.sorted(by: { $0.path < $1.path }) {
                guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
                let path = url.path.replacingOccurrences(of: root.path + "/", with: "")
                files.append(SourceFile(path: path, text: text))
            }
        }
        return files
    }
}
