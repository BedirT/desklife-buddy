import Foundation
import Testing
@testable import FactoryCore

@Suite("Factory identities and repository paths")
struct IdentityAndPathTests {
    @Test("SHA-256 digests validate and round-trip")
    func digestRoundTrip() throws {
        let digest = SHA256Digest.hashing(Data("factory".utf8))
        let decoded = try JSONDecoder().decode(
            SHA256Digest.self,
            from: JSONEncoder().encode(digest),
        )

        #expect(decoded == digest)
        #expect(digest.rawValue.count == 64)
        #expect(throws: FactoryValidationError.self) {
            try SHA256Digest(validating: "ABC")
        }
    }

    @Test("Git object IDs accept current and future hash widths")
    func gitObjectIDs() throws {
        #expect(try GitObjectID(validating: String(repeating: "a", count: 40)).rawValue.count == 40)
        #expect(try GitObjectID(validating: String(repeating: "b", count: 64)).rawValue.count == 64)
        #expect(throws: FactoryValidationError.self) {
            try GitObjectID(validating: String(repeating: "g", count: 40))
        }
    }

    @Test(
        "Unsafe repository paths are rejected",
        arguments: [
            "",
            "/tmp/escape",
            "../escape",
            "Sources/../escape",
            "Sources//File.swift",
            "Sources\\File.swift",
            ".git/config",
            "Sources/.GIT/config",
            "./Sources/File.swift",
        ],
    )
    func unsafePaths(raw: String) {
        #expect(throws: FactoryValidationError.self) {
            try RepositoryPath(validating: raw)
        }
    }

    @Test("Canonical paths classify the complete control plane")
    func controlPlaneClassification() throws {
        let protected = [
            "AGENTS.md",
            "App/AGENTS.override.md",
            "App/CLAUDE.md",
            "App/CLAUDE.local.md",
            ".mcp.json",
            ".agents/skills/factory-run/SKILL.md",
            ".factory/policy.json",
            ".github/workflows/ci.yml",
            ".xcodebuildmcp/config.json",
            "docs/factory/constitution.md",
            "docs/product/BRIEF.md",
            "docs/preferences.md",
            "Packages/Domain/AGENTS.md",
            "Packages/Factory/Package.swift",
            "Tools/XcodeBuildMCP/package-lock.json",
            "mise.lock",
            "App/App.entitlements",
            "App/PrivacyInfo.xcprivacy",
            "config/ExportOptions.plist",
            "scripts/test.sh",
            "script/legacy.sh",
            "sub/agents.md",
            ".Factory/policy.json",
            "Packages/factory/Package.swift",
        ]
        for raw in protected {
            #expect(try RepositoryPath(validating: raw).isControlPlane)
        }
        #expect(try !RepositoryPath(validating: "Packages/Domain/Sources/Domain/Item.swift").isControlPlane)
    }

    @Test("Dependency and build inputs are control-plane paths")
    func dependencyControlPlaneClassification() throws {
        let protected = [
            ".gitignore",
            ".swiftformat",
            ".swiftlint.yml",
            "Packages/Domain/Package.swift",
            "Packages/Features/Package.resolved",
            "Packages/Legacy/Package.pins",
            "Packages/Domain/Package@swift-6.2.swift",
            "Packages/Domain/.swiftpm/configuration/registries.json",
            "Packages/Domain/Plugins/Generate/Plugin.swift",
            "App.xcodeproj/project.pbxproj",
            "App.xcworkspace/contents.xcworkspacedata",
            "Config/Debug.xcconfig",
            "AppTests/Regression.xctestplan",
            "Web/package.json",
            "Web/package-lock.json",
            "Web/npm-shrinkwrap.json",
            "Web/pnpm-lock.yaml",
            "Web/yarn.lock",
            "Web/.npmrc",
            "packages/domain/PACKAGE.SWIFT",
            "app.XCODEPROJ/project.pbxproj",
        ]
        for raw in protected {
            #expect(try RepositoryPath(validating: raw).isControlPlane)
        }
    }
}
