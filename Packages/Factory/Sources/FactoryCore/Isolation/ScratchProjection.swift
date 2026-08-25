import Darwin
import Foundation

private enum ScratchProjectionLimits {
    static let maximumFiles = 10000
    static let maximumFileBytes = 16 * 1024 * 1024
    static let maximumTotalBytes = 256 * 1024 * 1024
}

/// Descriptor-observed source identity supplied by the trusted broker, not a model request.
struct ScratchSourceIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
    let ownerUID: UInt32

    init(device: UInt64, inode: UInt64, ownerUID: UInt32) {
        self.device = device
        self.inode = inode
        self.ownerUID = ownerUID
    }
}

/// Input plan for one credential-free, invocation-specific source projection.
struct ScratchProjectionPlan: Sendable {
    let invocationID: String
    let sourceRoot: URL
    let destinationRoot: URL
    let sourcePaths: [RepositoryPath]
    let sourceIdentity: ScratchSourceIdentity
    let deniedRoots: [URL]
    let maximumFiles: Int
    let maximumFileBytes: Int
    let maximumTotalBytes: Int

    init(
        invocationID: String,
        sourceRoot: URL,
        destinationRoot: URL,
        sourcePaths: [RepositoryPath],
        sourceIdentity: ScratchSourceIdentity,
        deniedRoots: [URL],
        maximumFiles: Int = ScratchProjectionLimits.maximumFiles,
        maximumFileBytes: Int = ScratchProjectionLimits.maximumFileBytes,
        maximumTotalBytes: Int = ScratchProjectionLimits.maximumTotalBytes,
    ) {
        self.invocationID = invocationID
        self.sourceRoot = sourceRoot
        self.destinationRoot = destinationRoot
        self.sourcePaths = sourcePaths
        self.sourceIdentity = sourceIdentity
        self.deniedRoots = deniedRoots
        self.maximumFiles = maximumFiles
        self.maximumFileBytes = maximumFileBytes
        self.maximumTotalBytes = maximumTotalBytes
    }
}

/// Exact regular-file inventory copied into a scratch workspace.
public struct ProjectionFile: Codable, Equatable, Sendable {
    public let path: RepositoryPath
    public let sha256: SHA256Digest
    public let bytes: Int
    public let executable: Bool

    public init(path: RepositoryPath, sha256: SHA256Digest, bytes: Int, executable: Bool) {
        self.path = path
        self.sha256 = sha256
        self.bytes = bytes
        self.executable = executable
    }
}

/// Content-addressed projection output used by the runner isolation manifest.
public struct ScratchProjectionInventory: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let invocationID: String
    public let files: [ProjectionFile]
    public let projectionSHA256: SHA256Digest

    public init(schemaVersion: Int, invocationID: String, files: [ProjectionFile], projectionSHA256: SHA256Digest) {
        self.schemaVersion = schemaVersion
        self.invocationID = invocationID
        self.files = files
        self.projectionSHA256 = projectionSHA256
    }

    /// Validates the public inventory and its self-contained content-addressed identity.
    func validateStructure() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(invocationID),
              !files.isEmpty,
              files.count <= ScratchProjectionLimits.maximumFiles,
              files.map(\.path) == files.map(\.path).sorted(),
              Set(files.map(\.path.collisionKey)).count == files.count,
              projectionSHA256 == CanonicalJSON.digest(files)
        else {
            throw FactoryValidationError(
                code: "invalid_projection_inventory",
                message: "Projection inventory identity, ordering, or schema is invalid.",
            )
        }

        var totalBytes = 0
        for file in files {
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(file.bytes)
            guard file.bytes >= 0,
                  file.bytes <= ScratchProjectionLimits.maximumFileBytes,
                  !overflow,
                  nextTotal <= ScratchProjectionLimits.maximumTotalBytes
            else {
                throw FactoryValidationError(
                    code: "projection_budget_exceeded",
                    message: "Projection inventory bytes exceed their fixed ceiling.",
                )
            }
            totalBytes = nextTotal
        }
    }
}

/// Descriptor-backed projection builder that never exposes repository metadata.
enum ScratchProjectionBuilder {
    static func sourceIdentity(at root: URL) throws -> ScratchSourceIdentity {
        let source = try canonicalExistingPath(root)
        let fd = Darwin.open(source.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard fd >= 0 else { throw posixError("open_projection_source") }
        defer { Darwin.close(fd) }
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid(),
              metadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_projection_source",
                message: "Projection source must be an owner-controlled directory.",
            )
        }
        return ScratchSourceIdentity(
            device: UInt64(metadata.st_dev),
            inode: UInt64(metadata.st_ino),
            ownerUID: metadata.st_uid,
        )
    }

    static func build(_ plan: ScratchProjectionPlan) throws -> ScratchProjectionInventory {
        let (source, destination) = try validatedRoots(for: plan)

        let destinationParent = destination.deletingLastPathComponent()
        let destinationName = destination.lastPathComponent
        let parentFD = Darwin.open(destinationParent.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard parentFD >= 0 else { throw posixError("open_projection_parent") }
        defer { Darwin.close(parentFD) }
        var parentMetadata = stat()
        guard Darwin.fstat(parentFD, &parentMetadata) == 0,
              parentMetadata.st_mode & S_IFMT == S_IFDIR,
              parentMetadata.st_uid == getuid(),
              parentMetadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: parentFD)
        else {
            throw FactoryValidationError(
                code: "unsafe_projection_parent",
                message: "Scratch projections require a private owner-controlled parent.",
            )
        }
        var destinationMetadata = stat()
        guard Darwin.fstatat(parentFD, destinationName, &destinationMetadata, AT_SYMLINK_NOFOLLOW) != 0,
              errno == ENOENT
        else {
            throw FactoryValidationError(
                code: "projection_exists",
                message: "Scratch projection roots are invocation-specific and new.",
            )
        }
        guard Darwin.mkdirat(parentFD, destinationName, 0o700) == 0 else {
            throw posixError("create_projection_root")
        }
        var retained = false
        defer {
            if !retained {
                try? removeTree(parentFD: parentFD, name: destinationName)
            }
        }

        let sourceFD = Darwin.open(source.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard sourceFD >= 0 else { throw posixError("open_projection_source") }
        defer { Darwin.close(sourceFD) }
        var sourceMetadata = stat()
        guard Darwin.fstat(sourceFD, &sourceMetadata) == 0,
              UInt64(sourceMetadata.st_dev) == plan.sourceIdentity.device,
              UInt64(sourceMetadata.st_ino) == plan.sourceIdentity.inode,
              sourceMetadata.st_uid == plan.sourceIdentity.ownerUID,
              sourceMetadata.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: sourceFD)
        else {
            throw FactoryValidationError(
                code: "projection_source_changed",
                message: "The authoritative source root changed before projection.",
            )
        }
        let destinationFD = Darwin.openat(
            parentFD,
            destinationName,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY,
        )
        guard destinationFD >= 0 else { throw posixError("open_projection_destination") }
        defer { Darwin.close(destinationFD) }
        try validatePrivateDirectory(fd: destinationFD, mode: 0o700)

        try createProjectionLanes(destinationFD: destinationFD)
        let workspaceFD = Darwin.openat(destinationFD, "workspace", O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard workspaceFD >= 0 else { throw posixError("open_projection_workspace") }
        defer { Darwin.close(workspaceFD) }

        var inventory: [ProjectionFile] = []
        var totalBytes = 0
        for path in plan.sourcePaths.sorted() {
            let read = try readRegularFile(rootFD: sourceFD, path: path, maximumBytes: plan.maximumFileBytes)
            let (nextTotal, overflow) = totalBytes.addingReportingOverflow(read.data.count)
            guard !overflow, nextTotal <= plan.maximumTotalBytes else {
                throw FactoryValidationError(
                    code: "projection_budget_exceeded",
                    message: "Projected source bytes exceed their trusted ceiling.",
                )
            }
            totalBytes = nextTotal
            try writeRegularFile(rootFD: workspaceFD, path: path, data: read.data, executable: read.executable)
            inventory.append(
                ProjectionFile(
                    path: path,
                    sha256: SHA256Digest.hashing(read.data),
                    bytes: read.data.count,
                    executable: read.executable,
                ),
            )
        }
        let projectionSHA256 = CanonicalJSON.digest(inventory)
        let result = ScratchProjectionInventory(
            schemaVersion: FactoryCore.schemaVersion,
            invocationID: plan.invocationID,
            files: inventory,
            projectionSHA256: projectionSHA256,
        )
        try result.validateStructure()
        try verifyInstalledDirectory(parentFD: parentFD, name: destinationName, openedFD: destinationFD)
        retained = true
        return result
    }

    private static func createProjectionLanes(destinationFD: Int32) throws {
        for (mode, directories) in [
            (mode_t(0o700), ["workspace", "output", "home", "tmp"]),
            (mode_t(0o500), ["context", "skills", "dependencies"]),
        ] {
            for directory in directories {
                guard Darwin.mkdirat(destinationFD, directory, mode) == 0 else {
                    throw posixError("create_projection_lane")
                }
                let fd = Darwin.openat(
                    destinationFD,
                    directory,
                    O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY,
                )
                guard fd >= 0 else { throw posixError("open_projection_lane") }
                defer { Darwin.close(fd) }
                try validatePrivateDirectory(fd: fd, mode: mode)
            }
        }
    }

    private static func readRegularFile(
        rootFD: Int32,
        path: RepositoryPath,
        maximumBytes: Int,
    ) throws -> (data: Data, executable: Bool) {
        let fd = Darwin.openat(rootFD, path.rawValue, O_RDONLY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard fd >= 0 else { throw posixError("open_projection_input") }
        defer { Darwin.close(fd) }
        var before = stat()
        guard Darwin.fstat(fd, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == getuid(),
              before.st_nlink == 1,
              before.st_size >= 0,
              before.st_size <= maximumBytes,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_projection_input",
                message: "Projection inputs must be one-link regular files.",
            )
        }
        let permissions = before.st_mode & 0o7777
        guard permissions == 0o644 || permissions == 0o755 else {
            throw FactoryValidationError(
                code: "unsafe_projection_mode",
                message: "Projection inputs must use Git regular-file modes.",
            )
        }
        let data = try readExactly(fd: fd, byteCount: Int(before.st_size))
        var after = stat()
        guard Darwin.fstat(fd, &after) == 0,
              before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              data.count == before.st_size
        else {
            throw FactoryValidationError(
                code: "projection_input_changed",
                message: "A projection input changed while it was read.",
            )
        }
        return (data, permissions == 0o755)
    }

    private static func readExactly(fd: Int32, byteCount: Int) throws -> Data {
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        var data = Data()
        data.reserveCapacity(byteCount)
        while data.count < byteCount {
            let remaining = byteCount - data.count
            let chunk = try handle.read(upToCount: min(remaining, 64 * 1024)) ?? Data()
            guard !chunk.isEmpty else { break }
            data.append(chunk)
        }
        return data
    }

    private static func writeRegularFile(
        rootFD: Int32,
        path: RepositoryPath,
        data: Data,
        executable: Bool,
    ) throws {
        let parentComponents = Array(path.components.dropLast())
        let parentFD = try ensureDirectories(rootFD: rootFD, components: parentComponents)
        defer { Darwin.close(parentFD) }
        guard let name = path.components.last else {
            throw FactoryValidationError(code: "invalid_projection_path", message: "Projection paths need a filename.")
        }
        let mode: mode_t = executable ? 0o755 : 0o644
        let fd = Darwin.openat(parentFD, name, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, mode)
        guard fd >= 0 else { throw posixError("create_projection_file") }
        defer { Darwin.close(fd) }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        try handle.write(contentsOf: data)
        guard Darwin.fchmod(fd, mode) == 0, Darwin.fsync(fd) == 0 else {
            throw posixError("finish_projection_file")
        }
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG,
              metadata.st_uid == getuid(),
              metadata.st_nlink == 1,
              metadata.st_mode & 0o777 == mode,
              metadata.st_size == data.count,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_projected_file",
                message: "Projected output failed regular-file validation.",
            )
        }
    }

    private static func ensureDirectories(rootFD: Int32, components: [String]) throws -> Int32 {
        var current = Darwin.dup(rootFD)
        guard current >= 0 else { throw posixError("duplicate_projection_root") }
        for component in components {
            if Darwin.mkdirat(current, component, 0o700) != 0, errno != EEXIST {
                Darwin.close(current)
                throw posixError("create_projection_directory")
            }
            let next = Darwin.openat(current, component, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
            Darwin.close(current)
            guard next >= 0 else { throw posixError("open_projection_directory") }
            var metadata = stat()
            guard Darwin.fstat(next, &metadata) == 0,
                  metadata.st_mode & S_IFMT == S_IFDIR,
                  metadata.st_uid == getuid(),
                  metadata.st_mode & 0o077 == 0,
                  BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: next)
            else {
                Darwin.close(next)
                throw FactoryValidationError(
                    code: "unsafe_projection_directory",
                    message: "Projection directories must remain private.",
                )
            }
            current = next
        }
        return current
    }
}

private extension ScratchProjectionBuilder {
    private static func validatePrivateDirectory(fd: Int32, mode: mode_t) throws {
        var metadata = stat()
        guard Darwin.fstat(fd, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFDIR,
              metadata.st_uid == getuid(),
              metadata.st_mode & 0o777 == mode,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fd)
        else {
            throw FactoryValidationError(
                code: "unsafe_projection_directory",
                message: "Projection directories must remain private and reject ambient ACL authority.",
            )
        }
    }

    private static func verifyInstalledDirectory(parentFD: Int32, name: String, openedFD: Int32) throws {
        var installed = stat()
        var opened = stat()
        guard Darwin.fstatat(parentFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              Darwin.fstat(openedFD, &opened) == 0,
              installed.st_mode & S_IFMT == S_IFDIR,
              installed.st_dev == opened.st_dev,
              installed.st_ino == opened.st_ino
        else {
            throw FactoryValidationError(
                code: "projection_destination_changed",
                message: "The installed projection root changed while it was built.",
            )
        }
        try validatePrivateDirectory(fd: openedFD, mode: 0o700)
    }

    private static func removeTree(parentFD: Int32, name: String) throws {
        let directoryFD = Darwin.openat(parentFD, name, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard directoryFD >= 0 else { throw posixError("open_projection_cleanup") }
        defer { Darwin.close(directoryFD) }
        let duplicate = Darwin.dup(directoryFD)
        guard duplicate >= 0, let directory = Darwin.fdopendir(duplicate) else {
            if duplicate >= 0 { Darwin.close(duplicate) }
            throw posixError("enumerate_projection_cleanup")
        }
        var names: [String] = []
        while let entryPointer = Darwin.readdir(directory) {
            var entry = entryPointer.pointee
            let child = withUnsafePointer(to: &entry.d_name) { pointer in
                pointer.withMemoryRebound(to: CChar.self, capacity: Int(MAXNAMLEN) + 1) {
                    String(cString: $0)
                }
            }
            if child != ".", child != ".." { names.append(child) }
        }
        Darwin.closedir(directory)
        for child in names {
            var metadata = stat()
            guard Darwin.fstatat(directoryFD, child, &metadata, AT_SYMLINK_NOFOLLOW) == 0 else {
                throw posixError("inspect_projection_cleanup")
            }
            if metadata.st_mode & S_IFMT == S_IFDIR {
                try removeTree(parentFD: directoryFD, name: child)
            } else {
                guard metadata.st_mode & S_IFMT == S_IFREG,
                      Darwin.unlinkat(directoryFD, child, 0) == 0
                else {
                    throw FactoryValidationError(
                        code: "unsafe_projection_cleanup",
                        message: "Projection cleanup encountered a link or special file.",
                    )
                }
            }
        }
        guard Darwin.fsync(directoryFD) == 0 else { throw posixError("sync_projection_cleanup") }
        guard Darwin.unlinkat(parentFD, name, AT_REMOVEDIR) == 0,
              Darwin.fsync(parentFD) == 0
        else {
            throw posixError("remove_projection_root")
        }
    }

    private static func isWithin(_ candidate: URL, root: URL) -> Bool {
        let candidatePath = candidate.path
        let rootPath = root.path.hasSuffix("/") ? String(root.path.dropLast()) : root.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func canonicalPotentialPath(_ url: URL) throws -> URL {
        let standardized = url.standardizedFileURL
        if FileManager.default.fileExists(atPath: standardized.path) {
            return try canonicalExistingPath(standardized)
        }
        return try canonicalExistingPath(standardized.deletingLastPathComponent())
            .appending(path: standardized.lastPathComponent)
    }

    private static func canonicalExistingPath(_ url: URL) throws -> URL {
        guard let resolved = Darwin.realpath(url.standardizedFileURL.path, nil) else {
            throw posixError("resolve_projection_path")
        }
        defer { Darwin.free(resolved) }
        return URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
    }

    private static func posixError(_ code: String) -> FactoryValidationError {
        FactoryValidationError(code: code, message: "The secure filesystem operation failed with errno \(errno).")
    }
}

private extension ScratchProjectionBuilder {
    static func validatedRoots(for plan: ScratchProjectionPlan) throws -> (source: URL, destination: URL) {
        guard FactoryTextRules.isStableID(plan.invocationID),
              !plan.sourcePaths.isEmpty,
              plan.sourcePaths.count <= plan.maximumFiles,
              plan.maximumFiles > 0,
              plan.maximumFiles <= ScratchProjectionLimits.maximumFiles,
              plan.maximumFileBytes > 0,
              plan.maximumFileBytes <= ScratchProjectionLimits.maximumFileBytes,
              plan.maximumTotalBytes > 0,
              plan.maximumTotalBytes <= ScratchProjectionLimits.maximumTotalBytes,
              Set(plan.sourcePaths.map(\.collisionKey)).count == plan.sourcePaths.count
        else {
            throw FactoryValidationError(
                code: "invalid_projection_plan",
                message: "A projection must be uniquely identified and bounded.",
            )
        }

        let source = try canonicalExistingPath(plan.sourceRoot)
        let destination = try canonicalPotentialPath(plan.destinationRoot)
        let denied = try plan.deniedRoots.map(canonicalPotentialPath)
        guard source.isFileURL,
              destination.isFileURL,
              !isWithin(destination, root: source),
              !denied.contains(where: { isWithin(destination, root: $0) }),
              !denied.contains(where: { isWithin(source, root: $0) || isWithin($0, root: source) })
        else {
            throw FactoryValidationError(
                code: "unsafe_projection_root",
                message: "Scratch and source must not intersect authoritative or sensitive roots.",
            )
        }
        return (source, destination)
    }
}
