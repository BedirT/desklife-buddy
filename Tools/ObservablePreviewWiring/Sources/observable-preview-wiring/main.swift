import Foundation
import ObservablePreviewWiring

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: observable-preview-wiring <repo-root>\n".utf8))
    exit(2)
}

let root = URL(fileURLWithPath: arguments[1]).standardizedFileURL
let findings = Driver.run(root: root)
exit(findings.isEmpty ? 0 : 1)
