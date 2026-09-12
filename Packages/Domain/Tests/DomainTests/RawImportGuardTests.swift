import Foundation
import Testing

/// Epic 3 story 1 RED guards: each raw class smuggled into each product
/// surface must trip `scripts/check-raw-imports.sh`.
///
/// The guard script scans a whole product tree. These tests build a scratch
/// tree per case (one probe file under the surface path), point the script at
/// it via `RAW_IMPORTS_SCAN_ROOT`, and require a nonzero exit. Written before
/// the script existed, so every test below failed on the unguarded base.
@Suite("Raw import guards")
struct RawImportGuardTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        // Packages/Domain/Tests/DomainTests/<this file> -> repository root.
        for _ in 0 ..< 5 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static var guardScript: URL {
        repositoryRoot.appending(path: "scripts/check-raw-imports.sh")
    }

    private struct GuardResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    @discardableResult
    private static func runGuard(scanRoot: URL) throws -> GuardResult {
        let script = guardScript
        #expect(
            FileManager.default.isExecutableFile(atPath: script.path),
            "Guard script missing: \(script.path)",
        )
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["RAW_IMPORTS_SCAN_ROOT"] = scanRoot.path
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return GuardResult(
            exitCode: process.terminationStatus,
            output: String(data: data, encoding: .utf8) ?? "",
        )
    }

    private static func writeProbe(
        token: String,
        sentinel: String,
        at relativePath: String,
        under scanRoot: URL,
    ) throws {
        let file = scanRoot.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let contents = """
        import Foundation

        // Story 1 smuggle probe: type-name sentinel only, never sampled bytes.
        struct RawSmuggleProbe {
            static let sentinelTypeName = "\(sentinel)"
            let witness = "\(token)"
        }
        """
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    private static func freshScanRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "RawImportGuardTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Guard trips per raw class per product surface", arguments: RawSmuggleCase.all)
    func tripsPerClassPerSurface(smuggleCase: RawSmuggleCase) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeProbe(
            token: smuggleCase.rawClass.probeToken,
            sentinel: smuggleCase.rawClass.sentinelTypeName,
            at: smuggleCase.surface.probePath,
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(
            result.exitCode != 0,
            "\(smuggleCase.rawClass.displayName) smuggled into \(smuggleCase.surface.rawValue) did not trip the guard",
        )
        #expect(
            result.output.contains(smuggleCase.surface.probePath),
            "Guard output names the violating surface file:\n\(result.output)",
        )
    }

    @Test("Guard trips on a camera entitlement key")
    func tripsOnEntitlementKey() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let entitlements = scanRoot.appending(path: "App/App.entitlements")
        try FileManager.default.createDirectory(
            at: entitlements.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let key = "com.apple.security.device." + "camera"
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>\(key)</key><true/>
        </dict></plist>
        """.write(to: entitlements, atomically: true, encoding: .utf8)
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Camera entitlement key did not trip the guard")
    }

    @Test("Guard trips on a camera privacy key")
    func tripsOnPrivacyKey() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let plist = scanRoot.appending(path: "App/SmuggleInfo.plist")
        try FileManager.default.createDirectory(
            at: plist.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        let key = "NS" + "CameraUsageDescription"
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>\(key)</key><string>smuggle probe</string>
        </dict></plist>
        """.write(to: plist, atomically: true, encoding: .utf8)
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Camera privacy key did not trip the guard")
    }

    @Test("Clean tree passes the guard")
    func cleanTreePasses() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeProbe(
            token: "OpportunityEventKind",
            sentinel: "BenignSentinel",
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot,
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode == 0, "Clean tree tripped the guard:\n\(result.output)")
    }

    @Test("Guard scope covers product targets and allowlists only tooling")
    func scopeCoversProductAllowlistingOnlyTooling() throws {
        let script = try String(contentsOf: Self.guardScript, encoding: .utf8)
        #expect(script.contains("App"), "Guard must scan the App target")
        #expect(script.contains("Packages"), "Guard must scan Packages")
        #expect(script.contains("ALLOWLIST"), "Guard must document its tooling allowlist")
        // Tooling path referenced without ever spelling it contiguously here.
        #expect(
            script.contains("scripts" + "/" + "support"),
            "Guard must name the allowlisted tooling path",
        )
    }
}
