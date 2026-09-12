import Foundation
import Testing

/// Epic 3 story 1 fix-pass guards: evasion shapes, dynamic lookup,
/// exemption discipline, allowlist proof, and config-surface coverage.
///
/// Same overlay technique as RawImportGuardTests: each case builds a scratch
/// tree, points `scripts/check-raw-imports.sh` at it via
/// `RAW_IMPORTS_SCAN_ROOT`, and asserts the exit code.
@Suite("Raw import guard bypasses")
struct RawImportGuardBypassTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 5 { url.deleteLastPathComponent() }
        return url
    }

    private struct GuardResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    @discardableResult
    private static func runGuard(scanRoot: URL) throws -> GuardResult {
        let script = repositoryRoot.appending(path: "scripts/check-raw-imports.sh")
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
            output: String(data: data, encoding: .utf8) ?? ""
        )
    }

    private static func writeFile(_ contents: String, at relativePath: String, under scanRoot: URL) throws {
        let file = scanRoot.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: file, atomically: true, encoding: .utf8)
    }

    private static func freshScanRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "RawImportGuardBypassTests")
            .appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    // MARK: - F8 derived bypass shapes (re-export, selector, dynamic) x 9 classes

    @Test("Evasion shapes trip per raw class", arguments: RawBypassCase.all)
    func evasionShapesTrip(bypassCase: RawBypassCase) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let body = bypassCase.shape.probeBody(
            token: bypassCase.rawClass.probeToken,
            prefix: bypassCase.rawClass.probeFragments.prefix,
            suffix: bypassCase.rawClass.probeFragments.suffix
        )
        try Self.writeFile(
            body,
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(
            result.exitCode != 0,
            "\(bypassCase.shape.rawValue) evasion for \(bypassCase.rawClass.displayName) did not trip the guard"
        )
    }

    @Test("Generated-code files are not excluded")
    func generatedFilesNotExcluded() throws {
        for rawClass in [RawSmuggleClass.camera, RawSmuggleClass.health] {
            let scanRoot = try Self.freshScanRoot()
            defer { try? FileManager.default.removeItem(at: scanRoot) }
            try Self.writeFile(
                """
                // Generated file — do not edit. Regenerate with the asset pipeline.
                import Foundation

                struct RawSmuggleProbe {
                    let witness = "\(rawClass.probeToken)"
                }
                """,
                at: RawSmuggleSurface.domain.probePath,
                under: scanRoot
            )
            let result = try Self.runGuard(scanRoot: scanRoot)
            #expect(
                result.exitCode != 0,
                "Generated-file probe for \(rawClass.displayName) did not trip the guard"
            )
        }
    }

    // MARK: - F5 dynamic-lookup category (findings 7-11 shapes)

    @Test("Dynamic lookup primitives trip", arguments: RawDynamicPrimitive.allCases)
    func dynamicPrimitivesTrip(primitive: RawDynamicPrimitive) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            primitive.probeBody,
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(
            result.exitCode != 0,
            "Dynamic primitive \(primitive.rawValue) did not trip the guard"
        )
        #expect(result.output.contains("dynamic-lookup"))
    }

    // MARK: - F2/F3/F4 hardened symbols

    @Test("Pixel-sibling symbols trip", arguments: [
        RawHardenedToken.pixelWindowImage,
        .pixelDisplayImage,
        .pixelDisplayStream,
        .pixelCaptureRequest,
    ])
    func pixelSiblingsTrip(token: RawHardenedToken) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            "import Foundation\n\nlet witness = \"\(token.assembled)\"\n",
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "\(token.rawValue) did not trip the guard")
    }

    @Test("Cloud and web egress symbols trip", arguments: [
        RawHardenedToken.cloudContainer,
        .cloudRecord,
        .webView,
        .cloudImport,
    ])
    func cloudWebTrip(token: RawHardenedToken) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            "\(token.assembled)\nlet witness = 1\n",
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "\(token.rawValue) did not trip the guard")
    }

    @Test("Low-level audio symbols trip", arguments: [
        RawHardenedToken.audioImport,
        .audioComponent,
        .audioRender,
        .audioHALUnit,
    ])
    func lowLevelAudioTrip(token: RawHardenedToken) throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            "\(token.assembled)\nlet witness = 1\n",
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "\(token.rawValue) did not trip the guard")
    }

    // MARK: - F7 exemption discipline

    @Test("Exemption marker needs a reason on the same line")
    func exemptionDiscipline() throws {
        let token = RawSmuggleClass.network.probeToken
        let marker = "RAWGUARD-ALLOW:"
        // Honored: reason on the same line.
        do {
            let scanRoot = try Self.freshScanRoot()
            defer { try? FileManager.default.removeItem(at: scanRoot) }
            try Self.writeFile(
                "import Foundation\n\nlet witness = \"\(token)\" // \(marker) test-harness probe\n",
                at: RawSmuggleSurface.domain.probePath,
                under: scanRoot
            )
            let result = try Self.runGuard(scanRoot: scanRoot)
            #expect(result.exitCode == 0, "Reasoned same-line exemption tripped:\n\(result.output)")
            #expect(result.output.contains("exemption"))
        }
        // Bare marker without a reason still trips.
        do {
            let scanRoot = try Self.freshScanRoot()
            defer { try? FileManager.default.removeItem(at: scanRoot) }
            try Self.writeFile(
                "import Foundation\n\nlet witness = \"\(token)\" // \(marker)\n",
                at: RawSmuggleSurface.domain.probePath,
                under: scanRoot
            )
            let result = try Self.runGuard(scanRoot: scanRoot)
            #expect(result.exitCode != 0, "Bare exemption marker did not trip the guard")
        }
        // Marker on another line does not exempt.
        do {
            let scanRoot = try Self.freshScanRoot()
            defer { try? FileManager.default.removeItem(at: scanRoot) }
            try Self.writeFile(
                "import Foundation\n// \(marker) test-harness probe\nlet witness = \"\(token)\"\n",
                at: RawSmuggleSurface.domain.probePath,
                under: scanRoot
            )
            let result = try Self.runGuard(scanRoot: scanRoot)
            #expect(result.exitCode != 0, "Other-line exemption marker did not trip the guard")
        }
    }

    @Test("Lookalike tokens pass")
    func lookalikesPass() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            """
            import Foundation

            /// Key-derivation label, not a HealthKit type.
            let keyDerivation = "\("HK" + "DF")-SHA256"
            let check = "CHECK"
            """,
            at: RawSmuggleSurface.domain.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode == 0, "Lookalike tokens tripped the guard:\n\(result.output)")
    }

    // MARK: - F6 behavioral allowlist proof

    @Test("Tooling-path reference in product trips")
    func toolingRefInProductTrips() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            "import Foundation\n\nlet helper = \"" + "scripts" + "/" + "support" + "/dump_ax\"\n",
            at: RawSmuggleSurface.persistence.probePath,
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Product reference to tooling did not trip the guard")
    }

    @Test("Banned symbols under the tooling path pass")
    func toolingPathPasses() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        try Self.writeFile(
            "#!/usr/bin/swift\nlet witness = \"\(RawSmuggleClass.screenCaptureAX.probeToken)\"\n",
            at: "scripts" + "/" + "support" + "/probe_tool.swift",
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode == 0, "Allowlisted tooling tripped the guard:\n\(result.output)")
    }

    // MARK: - F1 config surfaces

    @Test("INFOPLIST_KEY smuggling in the Xcode project trips")
    func infoplistKeySmugglingTrips() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let key = "INFOPLIST_KEY_" + "NS" + "CameraUsageDescription"
        try Self.writeFile(
            "/* Begin PBXProject section */\n\t\t\t\t\(key) = \"smuggle\";\n/* End PBXProject section */\n",
            at: "App.xcodeproj/project.pbxproj",
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "INFOPLIST_KEY smuggling did not trip the guard")
    }

    @Test("xcconfig smuggling trips")
    func xcconfigSmugglingTrips() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let key = "INFOPLIST_KEY_" + "NS" + "CameraUsageDescription"
        try Self.writeFile(
            "// Build settings\n\(key) = smuggle\n",
            at: "App/Config/Smuggle.xcconfig",
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "xcconfig smuggling did not trip the guard")
    }

    @Test("Binary plist smuggling trips")
    func binaryPlistSmugglingTrips() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let key = "NS" + "CameraUsageDescription"
        let plist = scanRoot.appending(path: "App/SmuggleInfo.plist")
        try FileManager.default.createDirectory(
            at: plist.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict>
        <key>\(key)</key><string>smuggle</string>
        </dict></plist>
        """.write(to: plist, atomically: true, encoding: .utf8)
        let convert = Process()
        convert.executableURL = URL(fileURLWithPath: "/usr/bin/plutil")
        convert.arguments = ["-convert", "binary1", plist.path]
        try convert.run()
        convert.waitUntilExit()
        #expect(convert.terminationStatus == 0, "plutil binary conversion failed")
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Binary plist smuggling did not trip the guard")
    }

    @Test("Entity-encoded plist smuggling trips")
    func entityPlistSmugglingTrips() throws {
        let scanRoot = try Self.freshScanRoot()
        defer { try? FileManager.default.removeItem(at: scanRoot) }
        let evasive = "NSCameraUsage" + "&#68;escription"
        try Self.writeFile(
            """
            <?xml version="1.0" encoding="UTF-8"?>
            <plist version="1.0"><dict>
            <key>\(evasive)</key><string>smuggle</string>
            </dict></plist>
            """,
            at: "App/SmuggleInfo.plist",
            under: scanRoot
        )
        let result = try Self.runGuard(scanRoot: scanRoot)
        #expect(result.exitCode != 0, "Entity-encoded plist smuggling did not trip the guard")
    }

    // MARK: - Scope

    @Test("Guard scope covers the Xcode project")
    func scopeCoversXcodeProject() throws {
        let script = try String(
            contentsOf: Self.repositoryRoot.appending(path: "scripts/check-raw-imports.sh"),
            encoding: .utf8
        )
        #expect(script.contains("App.xcodeproj"), "Guard must scan the Xcode project")
        #expect(script.contains("xcconfig"), "Guard must scan build-config files")
    }
}
