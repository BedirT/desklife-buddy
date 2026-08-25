import Foundation

/// Canonical repository-relative path safe for structured filesystem APIs.
public struct RepositoryPath: Hashable, Sendable, Comparable {
    public let rawValue: String

    public init(validating rawValue: String) throws {
        let components = rawValue.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        guard !rawValue.isEmpty,
              rawValue.utf8.count <= 1024,
              !rawValue.hasPrefix("/"),
              !rawValue.hasSuffix("/"),
              !rawValue.hasPrefix("~"),
              !rawValue.contains("\\"),
              rawValue.precomposedStringWithCanonicalMapping == rawValue,
              rawValue.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.utf8.count <= 255 }),
              !components.contains(where: {
                  let value = $0.lowercased()
                  return value == ".git" || value == ".gitmodules" || value == "..namedfork"
              })
        else {
            throw FactoryValidationError(
                code: "invalid_repository_path",
                message: "Repository paths must be normalized relative POSIX paths without traversal or Git metadata.",
            )
        }
        self.rawValue = rawValue
    }

    public static func < (lhs: RepositoryPath, rhs: RepositoryPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Components used for ancestry and collision checks without string-prefix ambiguity.
    public var components: [String] {
        rawValue.split(separator: "/").map(String.init)
    }

    /// Whether product work must treat this path as immutable factory policy.
    public var isControlPlane: Bool {
        let folded = components.map(Self.folded)
        let first = folded.first ?? ""
        let name = folded.last ?? ""
        let dependencyInputNames = [
            ".npmrc", "npm-shrinkwrap.json", "package-lock.json", "package.json", "package.pins",
            "package.resolved", "package.swift", "pnpm-lock.yaml", "yarn.lock",
        ]
        if ["agents.md", "agents.override.md", "claude.md", "claude.local.md", ".mcp.json"].contains(name) {
            return true
        }
        if dependencyInputNames.contains(name)
            || (name.hasPrefix("package@swift-") && name.hasSuffix(".swift"))
            || folded.contains(".swiftpm")
            || folded.contains("plugins")
            || folded.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })
            || name.hasSuffix(".xcconfig")
            || name.hasSuffix(".xctestplan")
        {
            return true
        }
        if [
            ".agents", ".claude", ".codex", ".factory", ".github", ".pi", ".xcodebuildmcp", "script", "scripts",
        ].contains(first) {
            return true
        }
        if folded.starts(with: ["docs", "factory"])
            || folded.starts(with: ["docs", "product"])
            || folded == ["docs", "preferences.md"]
            || folded.starts(with: ["packages", "factory"])
            || folded.starts(with: ["tools", "xcodebuildmcp"])
        {
            return true
        }
        let isRootConfiguration = folded.count == 1
            && [".gitignore", ".swiftformat", ".swiftlint.yml", "mise.lock", "mise.toml"].contains(name)
        return name.hasSuffix(".entitlements")
            || name == "privacyinfo.xcprivacy"
            || name == "exportoptions.plist"
            || isRootConfiguration
    }

    /// True when this path is equal to or nested beneath the supplied root.
    public func isWithin(_ root: RepositoryPath) -> Bool {
        components.starts(with: root.components)
    }

    /// Case-folded key used to reject aliases on default macOS filesystems.
    public var collisionKey: String {
        Self.folded(rawValue)
    }

    private static func folded(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

extension RepositoryPath: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        do {
            try self.init(validating: container.decode(String.self))
        } catch let error as FactoryValidationError {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
