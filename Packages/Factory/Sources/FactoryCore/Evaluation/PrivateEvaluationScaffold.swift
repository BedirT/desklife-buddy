import Darwin
import Foundation

/// Empty companion-root declaration generated from an immutable trusted root SHA.
public struct PrivateEvaluationRootManifest: Codable, Equatable, Sendable {
    public let acceptanceSHA256: SHA256Digest
    public let casesPresent: Bool
    public let epochZeroFrozen: Bool
    public let evaluatorCodePresent: Bool
    public let schemaDigests: [SchemaDigest]
    public let schemaVersion: Int
    public let trustedRootSHA: GitObjectID

    public init(
        acceptanceSHA256: SHA256Digest,
        casesPresent: Bool,
        epochZeroFrozen: Bool,
        evaluatorCodePresent: Bool,
        schemaDigests: [SchemaDigest],
        schemaVersion: Int = FactoryCore.schemaVersion,
        trustedRootSHA: GitObjectID,
    ) throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              !casesPresent,
              !epochZeroFrozen,
              !evaluatorCodePresent,
              !schemaDigests.isEmpty,
              schemaDigests.map(\.schemaID) == schemaDigests.map(\.schemaID).sorted(),
              Set(schemaDigests.map(\.schemaID)).count == schemaDigests.count,
              schemaDigests.allSatisfy({ FactoryTextRules.isStableID($0.schemaID) })
        else {
            throw FactoryValidationError(
                code: "invalid_private_eval_root",
                message: "The empty private root must be canonical, data-only, and pre-epoch.",
            )
        }
        self.acceptanceSHA256 = acceptanceSHA256
        self.casesPresent = casesPresent
        self.epochZeroFrozen = epochZeroFrozen
        self.evaluatorCodePresent = evaluatorCodePresent
        self.schemaDigests = schemaDigests
        self.schemaVersion = schemaVersion
        self.trustedRootSHA = trustedRootSHA
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredManifest(from: decoder)
        try self.init(
            acceptanceSHA256: value.acceptanceSHA256,
            casesPresent: value.casesPresent,
            epochZeroFrozen: value.epochZeroFrozen,
            evaluatorCodePresent: value.evaluatorCodePresent,
            schemaDigests: value.schemaDigests,
            schemaVersion: value.schemaVersion,
            trustedRootSHA: value.trustedRootSHA,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredManifest(
            acceptanceSHA256: acceptanceSHA256,
            casesPresent: casesPresent,
            epochZeroFrozen: epochZeroFrozen,
            evaluatorCodePresent: evaluatorCodePresent,
            schemaDigests: schemaDigests,
            schemaVersion: schemaVersion,
            trustedRootSHA: trustedRootSHA,
        ).encode(to: encoder)
    }

    private struct StoredManifest: Codable {
        let acceptanceSHA256: SHA256Digest
        let casesPresent: Bool
        let epochZeroFrozen: Bool
        let evaluatorCodePresent: Bool
        let schemaDigests: [SchemaDigest]
        let schemaVersion: Int
        let trustedRootSHA: GitObjectID
    }
}

/// Mechanical generator for the owner-private data-only repository base.
package enum PrivateEvaluationScaffold {
    package static func generate(
        at root: URL,
        manifest: PrivateEvaluationRootManifest,
    ) throws -> PrivateEvaluationRootManifest {
        try generate(at: root, manifest: manifest, afterMetadataCreated: {})
    }

    static func generate(
        at root: URL,
        manifest: PrivateEvaluationRootManifest,
        afterMetadataCreated: () throws -> Void,
    ) throws -> PrivateEvaluationRootManifest {
        let manifestBytes = try CanonicalJSON.encode(manifest)
        let (parentFD, name) = try openSecureParent(of: root)
        defer { Darwin.close(parentFD) }
        var existing = stat()
        guard Darwin.fstatat(parentFD, name, &existing, AT_SYMLINK_NOFOLLOW) != 0,
              errno == ENOENT
        else {
            throw FactoryValidationError(
                code: "eval_scaffold_exists",
                message: "The private scaffold destination must be new.",
            )
        }
        guard Darwin.mkdirat(parentFD, name, 0o700) == 0 else {
            throw FactoryValidationError(
                code: "create_eval_scaffold",
                message: "The private scaffold root could not be created.",
            )
        }
        let rootFD = Darwin.openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard rootFD >= 0 else {
            _ = Darwin.unlinkat(parentFD, name, AT_REMOVEDIR)
            throw FactoryValidationError(code: "open_eval_scaffold", message: "The scaffold root could not be opened.")
        }
        defer { Darwin.close(rootFD) }
        try validateDirectory(fd: rootFD, mode: 0o700)
        var retained = false
        var factoryFD: Int32 = -1
        defer {
            if !retained {
                if factoryFD >= 0 {
                    _ = Darwin.unlinkat(factoryFD, "evaluation-root.json", 0)
                }
                _ = Darwin.unlinkat(rootFD, "README.md", 0)
                _ = Darwin.unlinkat(rootFD, ".gitignore", 0)
                removeKnownEntry(parentFD: rootFD, name: ".factory")
                _ = Darwin.unlinkat(parentFD, name, AT_REMOVEDIR)
            }
            if factoryFD >= 0 { Darwin.close(factoryFD) }
        }

        guard Darwin.mkdirat(rootFD, ".factory", 0o700) == 0 else {
            throw FactoryValidationError(
                code: "create_eval_metadata",
                message: "The private metadata root could not be created.",
            )
        }
        factoryFD = Darwin.openat(rootFD, ".factory", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard factoryFD >= 0 else {
            throw FactoryValidationError(code: "open_eval_scaffold", message: "Private metadata could not be opened.")
        }
        try validateDirectory(fd: factoryFD, mode: 0o700)
        try afterMetadataCreated()

        try writePrivate(manifestBytes, parentFD: factoryFD, name: "evaluation-root.json")
        try writePrivate(
            Data(
                "# Private Evaluation Data Root\n\nThis repository contains data only. Evaluator code and workflows execute from the pinned trusted root SHA. Every corpus or epoch change requires a reviewed pull request.\n"
                    .utf8,
            ),
            parentFD: rootFD,
            name: "README.md",
        )
        try writePrivate(Data(".DS_Store\n".utf8), parentFD: rootFD, name: ".gitignore")
        try verifyEntry(parentFD: rootFD, name: ".factory", openedFD: factoryFD)
        try verifyEntry(parentFD: parentFD, name: name, openedFD: rootFD)
        try validateSecureParent(fd: parentFD)
        guard Darwin.fsync(factoryFD) == 0, Darwin.fsync(rootFD) == 0, Darwin.fsync(parentFD) == 0 else {
            throw FactoryValidationError(
                code: "finish_eval_scaffold",
                message: "The private scaffold directory was not durably written.",
            )
        }
        retained = true
        return manifest
    }

    private static func writePrivate(_ data: Data, parentFD: Int32, name: String) throws {
        let fd = Darwin.openat(parentFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else {
            throw FactoryValidationError(
                code: "write_eval_scaffold",
                message: "A private scaffold file could not be created.",
            )
        }
        defer { Darwin.close(fd) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        var metadata = stat()
        guard Darwin.fchmod(fd, 0o600) == 0,
              Darwin.fsync(fd) == 0,
              Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == geteuid(),
              metadata.st_nlink == 1,
              metadata.st_mode & 0o777 == 0o600,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "finish_eval_scaffold",
                message: "A private scaffold file was not durably written.",
            )
        }
    }

    private static func openSecureParent(of root: URL) throws -> (Int32, String) {
        guard root.isFileURL,
              root.path.hasPrefix("/"),
              root.path != "/",
              !root.path.hasSuffix("/"),
              !root.path.contains("//"),
              root.path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." }),
              URL(fileURLWithPath: root.path).path == root.path,
              let name = root.pathComponents.last,
              name != "/"
        else {
            throw FactoryValidationError(
                code: "unsafe_eval_scaffold_root",
                message: "The private scaffold path must be canonical and absolute.",
            )
        }
        let components = root.pathComponents.filter { $0 != "/" }.dropLast()
        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0 else {
            throw FactoryValidationError(
                code: "open_eval_scaffold",
                message: "The scaffold parent could not be opened.",
            )
        }
        do {
            for component in components {
                let nextFD = Darwin.openat(
                    directoryFD,
                    String(component),
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
                )
                guard nextFD >= 0 else {
                    throw FactoryValidationError(
                        code: "unsafe_eval_scaffold_root",
                        message: "The scaffold ancestry cannot contain links.",
                    )
                }
                var metadata = stat()
                let valid = Darwin.fstat(nextFD, &metadata) == 0
                    && metadata.st_mode & S_IFMT == S_IFDIR
                    && [uid_t(0), geteuid()].contains(metadata.st_uid)
                    && metadata.st_mode & 0o022 == 0
                    && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
                guard valid else {
                    Darwin.close(nextFD)
                    throw FactoryValidationError(
                        code: "unsafe_eval_scaffold_root",
                        message: "Scaffold ancestry must be root- or broker-owned and non-writable by other users.",
                    )
                }
                Darwin.close(directoryFD)
                directoryFD = nextFD
            }
            return (directoryFD, name)
        } catch {
            Darwin.close(directoryFD)
            throw error
        }
    }

    private static func validateDirectory(fd: Int32, mode: mode_t) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == geteuid(),
              metadata.st_mode & 0o777 == mode,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_eval_scaffold_root",
                message: "Private scaffold directories require exact broker ownership and mode.",
            )
        }
    }

    private static func verifyEntry(parentFD: Int32, name: String, openedFD: Int32) throws {
        var entry = stat()
        var opened = stat()
        guard Darwin.fstatat(parentFD, name, &entry, AT_SYMLINK_NOFOLLOW) == 0,
              Darwin.fstat(openedFD, &opened) == 0,
              entry.st_mode & S_IFMT == S_IFDIR,
              entry.st_dev == opened.st_dev,
              entry.st_ino == opened.st_ino,
              opened.st_uid == geteuid(),
              opened.st_mode & 0o777 == 0o700,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: openedFD)
        else {
            throw FactoryValidationError(
                code: "eval_scaffold_changed",
                message: "A scaffold directory changed while it was created.",
            )
        }
    }

    private static func validateSecureParent(fd: Int32) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              [uid_t(0), geteuid()].contains(metadata.st_uid),
              metadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_eval_scaffold_root",
                message: "Scaffold ancestry must reject ambient ACL authority.",
            )
        }
    }

    private static func removeKnownEntry(parentFD: Int32, name: String) {
        var metadata = stat()
        guard Darwin.fstatat(parentFD, name, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else { return }
        let flags = metadata.st_mode & S_IFMT == S_IFDIR ? AT_REMOVEDIR : 0
        _ = Darwin.unlinkat(parentFD, name, flags)
    }
}
