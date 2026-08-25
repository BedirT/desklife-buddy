import Darwin
import Foundation

/// One regular file contributing to an authoritative tree digest.
public struct RepositoryTreeFile: Codable, Equatable, Sendable {
    public let path: RepositoryPath
    public let digest: SHA256Digest
    public let bytes: Int
    public let executable: Bool

    public init(path: RepositoryPath, digest: SHA256Digest, bytes: Int, executable: Bool) {
        self.path = path
        self.digest = digest
        self.bytes = bytes
        self.executable = executable
    }
}

/// Deterministic regular-file snapshot excluding only the top-level Git metadata entry.
public struct RepositoryTree: Codable, Equatable, Sendable {
    public let files: [RepositoryTreeFile]
    public let digest: SHA256Digest

    public init(files: [RepositoryTreeFile], digest: SHA256Digest) {
        self.files = files
        self.digest = digest
    }

    /// Captures a descriptor-validated tree and rejects links, special files, and unsafe modes.
    public static func capture(at root: URL) throws -> RepositoryTree {
        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        let files = try SecureRepositoryFileSystem.listTree(rootFD: rootFD)
        return RepositoryTree(files: files, digest: CanonicalJSON.digest(files))
    }

    /// Captures only transaction-owned paths so ignored artifacts and unrelated links cannot perturb rollback.
    public static func capture(at root: URL, paths: [RepositoryPath]) throws -> RepositoryTree {
        let rootFD = try SecureRepositoryFileSystem.openDirectory(root)
        defer { Darwin.close(rootFD) }
        return try capture(rootFD: rootFD, paths: paths)
    }

    static func capture(rootFD: Int32, paths: [RepositoryPath]) throws -> RepositoryTree {
        guard paths == paths.sorted(), Set(paths.map(\.collisionKey)).count == paths.count else {
            throw FactoryValidationError(
                code: "invalid_tree_scope",
                message: "Repository snapshot paths must be canonical and unique.",
            )
        }
        var files: [RepositoryTreeFile] = []
        for path in paths {
            guard try SecureRepositoryFileSystem.entryExists(rootFD: rootFD, path: path) else { continue }
            let file = try SecureRepositoryFileSystem.readRegularFile(
                rootFD: rootFD,
                path: path,
                allowedModes: [0o644, 0o755],
                maximumBytes: SecureRepositoryFileSystem.maximumRegularFileBytes,
            )
            files.append(
                RepositoryTreeFile(
                    path: path,
                    digest: SHA256Digest.hashing(file.data),
                    bytes: file.data.count,
                    executable: file.executable,
                ),
            )
        }
        return RepositoryTree(files: files, digest: CanonicalJSON.digest(files))
    }
}
