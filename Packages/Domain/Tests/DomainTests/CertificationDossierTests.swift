import Foundation
import Testing

/// Epic 3 story 9 RED discipline: the certification dossier's status
/// vocabulary and check inventory stay machine-readable and closed.
///
/// These tests point `scripts/check-certification-dossier.sh --check-dossier`
/// at the checked-in dossier (or a one-field mutation of it) and require the
/// documented verdict. Written before the script existed, so every test below
/// failed on the unguarded base.
@Suite("Certification dossier discipline")
struct CertificationDossierTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        // Packages/Domain/Tests/DomainTests/<this file> -> repository root.
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static var dossierScript: URL {
        repositoryRoot.appending(path: "scripts/check-certification-dossier.sh")
    }

    private static var dossierFile: URL {
        repositoryRoot.appending(path: "docs/certification/dossier.v1.json")
    }

    private struct DossierResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    @discardableResult
    private static func runCheck(dossier: URL) throws -> DossierResult {
        let script = dossierScript
        #expect(
            FileManager.default.isExecutableFile(atPath: script.path),
            "Dossier script missing: \(script.path)",
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, "--check-dossier", dossier.path]
        process.environment = ProcessInfo.processInfo.environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return DossierResult(
            exitCode: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? "",
        )
    }

    private static func mutatedDossier(_ mutate: (String) -> String?) throws -> URL {
        let original = try String(contentsOf: dossierFile, encoding: .utf8)
        guard let mutated = mutate(original) else {
            Issue.record("Checked-in dossier lacks the fixture anchor under test")
            throw CancellationError()
        }
        let file = FileManager.default.temporaryDirectory
            .appending(path: "CertificationDossierTests")
            .appending(path: UUID().uuidString)
            .appending(path: "dossier.mutated.json")
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try mutated.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    /// Replaces the value of the first `"key": "<value>"` string field.
    private static func replaceFirstValue(
        _ text: String,
        key: String,
        with replacement: String,
    ) -> String? {
        let anchor = "\"\(key)\": \""
        guard let anchorRange = text.range(of: anchor) else { return nil }
        let valueStart = anchorRange.upperBound
        guard let valueEnd = text[valueStart...].firstIndex(of: "\"") else { return nil }
        var copy = text
        copy.replaceSubrange(valueStart ..< valueEnd, with: replacement)
        return copy
    }

    @Test("Checked-in dossier validates")
    func checkedInDossierValidates() throws {
        #expect(
            FileManager.default.isReadableFile(atPath: Self.dossierFile.path),
            "Dossier status file missing: \(Self.dossierFile.path)",
        )
        let result = try Self.runCheck(dossier: Self.dossierFile)
        #expect(
            result.exitCode == 0,
            "Checked-in dossier failed validation:\n\(result.output)",
        )
    }

    @Test("Status vocabulary is locked")
    func statusVocabularyLocked() throws {
        let file = try Self.mutatedDossier {
            Self.replaceFirstValue($0, key: "status", with: "awaiting-owner")
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try Self.runCheck(dossier: file)
        #expect(
            result.exitCode != 0,
            "Unknown dossier status was accepted",
        )
    }

    @Test("Pending-owner requires its missing input")
    func pendingOwnerRequiresMissingInput() throws {
        let file = try Self.mutatedDossier {
            Self.replaceFirstValue($0, key: "missingInput", with: "")
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try Self.runCheck(dossier: file)
        #expect(
            result.exitCode != 0,
            "Pending-owner check without missingInput was accepted",
        )
    }

    @Test("Check inventory rejects unknown ids")
    func checkInventoryRejectsUnknownIds() throws {
        let file = try Self.mutatedDossier {
            Self.replaceFirstValue(
                $0,
                key: "id",
                with: "no-egress-raw-import-guard-extra",
            )
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try Self.runCheck(dossier: file)
        #expect(
            result.exitCode != 0,
            "Unknown dossier check id was accepted",
        )
    }

    @Test("Every check names its evidence")
    func everyCheckNamesEvidence() throws {
        let file = try Self.mutatedDossier {
            Self.replaceFirstValue($0, key: "evidence", with: "")
        }
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try Self.runCheck(dossier: file)
        #expect(
            result.exitCode != 0,
            "Dossier check without evidence was accepted",
        )
    }
    @Test("Unreadable probe inputs fail gracefully with a summary")
    func unreadableProbeInputsFailGracefully() throws {
        let scratch = FileManager.default.temporaryDirectory
            .appending(path: "CertificationDossierTests")
            .appending(path: UUID().uuidString)
        let scanRoot = scratch.appending(path: "scan-root")
        let dossierOut = scratch.appending(path: "dossier")
        let sbomOut = scratch.appending(path: "sbom")
        for directory in [scanRoot, dossierOut, sbomOut] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
            )
        }
        defer { try? FileManager.default.removeItem(at: scratch) }
        let script = Self.dossierScript
        #expect(
            FileManager.default.isExecutableFile(atPath: script.path),
            "Dossier script missing: \(script.path)",
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["CERTIFICATION_SCAN_ROOT"] = scanRoot.path
        environment["DOSSIER_OUT"] = dossierOut.path
        environment["SBOM_OUT"] = sbomOut.path
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        #expect(
            process.terminationStatus != 0,
            "Empty scan root should fail the dossier run",
        )
        #expect(
            output.contains("certification dossier failures:"),
            "Failing run must print a failure summary instead of aborting:\n\(output)",
        )
        #expect(
            output.contains("no-egress-entitlement-inventory"),
            "Summary must name the unreadable entitlement probe:\n\(output)",
        )
        #expect(
            output.contains("tcc-placeholder-capability-inventory"),
            "Summary must name the unreadable capability probe:\n\(output)",
        )
        #expect(
            FileManager.default.isReadableFile(
                atPath: dossierOut.appending(path: "evidence.json").path,
            ),
            "Failing run must still write its machine-readable run record",
        )
    }
}
