import CryptoKit
import Darwin
import Foundation

/// Root-owned installation fact that cannot be supplied by a model-controlled state root.
struct BrokerTrustAnchor: Codable, Equatable, Sendable {
    let activationPublicKeySHA256: SHA256Digest
    let brokerIdentitySHA256: SHA256Digest
    let brokerStateRootPath: String
    let brokerUserID: Int
    let evaluationScaffoldManifestSHA256: SHA256Digest
    let evaluationScaffoldRootPath: String
    let operatorUserID: Int
    let repository: String
    let schemaVersion: Int
    let signingKeyID: String
    let trustedRootSHA: GitObjectID
    let evolutionAcceptanceSHA256: SHA256Digest

    init(
        activationPublicKeySHA256: SHA256Digest,
        brokerIdentitySHA256: SHA256Digest,
        brokerStateRootPath: String,
        brokerUserID: Int,
        evaluationScaffoldManifestSHA256: SHA256Digest,
        evaluationScaffoldRootPath: String,
        operatorUserID: Int,
        repository: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
        signingKeyID: String,
        trustedRootSHA: GitObjectID,
        evolutionAcceptanceSHA256: SHA256Digest,
    ) throws {
        let repositoryPattern = /^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
        guard schemaVersion == FactoryCore.schemaVersion,
              Self.isCanonicalAbsolutePath(brokerStateRootPath),
              Self.isCanonicalAbsolutePath(evaluationScaffoldRootPath),
              !Self.pathsOverlap(brokerStateRootPath, evaluationScaffoldRootPath),
              !Self.contains(
                  root: brokerStateRootPath,
                  path: BrokerTrustAnchorLoader.installationURL.path,
              ),
              !Self.contains(
                  root: evaluationScaffoldRootPath,
                  path: BrokerTrustAnchorLoader.installationURL.path,
              ),
              brokerUserID > 0,
              brokerUserID <= Int(uid_t.max),
              operatorUserID > 0,
              operatorUserID <= Int(uid_t.max),
              brokerUserID != operatorUserID,
              repository.wholeMatch(of: repositoryPattern) != nil,
              FactoryTextRules.isStableID(signingKeyID)
        else {
            throw Self.invalid()
        }
        self.activationPublicKeySHA256 = activationPublicKeySHA256
        self.brokerIdentitySHA256 = brokerIdentitySHA256
        self.brokerStateRootPath = brokerStateRootPath
        self.brokerUserID = brokerUserID
        self.evaluationScaffoldManifestSHA256 = evaluationScaffoldManifestSHA256
        self.evaluationScaffoldRootPath = evaluationScaffoldRootPath
        self.operatorUserID = operatorUserID
        self.repository = repository
        self.schemaVersion = schemaVersion
        self.signingKeyID = signingKeyID
        self.trustedRootSHA = trustedRootSHA
        self.evolutionAcceptanceSHA256 = evolutionAcceptanceSHA256
    }

    init(from decoder: Decoder) throws {
        let value = try Stored(from: decoder)
        try self.init(
            activationPublicKeySHA256: value.activationPublicKeySHA256,
            brokerIdentitySHA256: value.brokerIdentitySHA256,
            brokerStateRootPath: value.brokerStateRootPath,
            brokerUserID: value.brokerUserID,
            evaluationScaffoldManifestSHA256: value.evaluationScaffoldManifestSHA256,
            evaluationScaffoldRootPath: value.evaluationScaffoldRootPath,
            operatorUserID: value.operatorUserID,
            repository: value.repository,
            schemaVersion: value.schemaVersion,
            signingKeyID: value.signingKeyID,
            trustedRootSHA: value.trustedRootSHA,
            evolutionAcceptanceSHA256: value.evolutionAcceptanceSHA256,
        )
    }

    func encode(to encoder: Encoder) throws {
        try Stored(
            activationPublicKeySHA256: activationPublicKeySHA256,
            brokerIdentitySHA256: brokerIdentitySHA256,
            brokerStateRootPath: brokerStateRootPath,
            brokerUserID: brokerUserID,
            evaluationScaffoldManifestSHA256: evaluationScaffoldManifestSHA256,
            evaluationScaffoldRootPath: evaluationScaffoldRootPath,
            operatorUserID: operatorUserID,
            repository: repository,
            schemaVersion: schemaVersion,
            signingKeyID: signingKeyID,
            trustedRootSHA: trustedRootSHA,
            evolutionAcceptanceSHA256: evolutionAcceptanceSHA256,
        ).encode(to: encoder)
    }

    var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    func validate(policy: BrokerPolicy) throws {
        guard policy.activationPublicKeySHA256 == activationPublicKeySHA256,
              policy.brokerIdentitySHA256 == brokerIdentitySHA256,
              policy.repository == repository,
              policy.trustedBase == trustedRootSHA
        else {
            throw Self.invalid()
        }
    }

    func validateRuntime(effectiveUserID: uid_t, realUserID: uid_t) throws {
        guard Int(effectiveUserID) == brokerUserID,
              Int(realUserID) == brokerUserID
        else {
            throw Self.invalid()
        }
    }

    func validateStateRoot(_ root: URL) throws {
        guard root.isFileURL,
              root.path == brokerStateRootPath
        else {
            throw Self.invalid()
        }
    }

    func validateScaffold(root: URL, manifest: PrivateEvaluationRootManifest) throws {
        guard root.isFileURL,
              root.path == evaluationScaffoldRootPath,
              manifest.trustedRootSHA == trustedRootSHA,
              manifest.acceptanceSHA256 == evolutionAcceptanceSHA256,
              CanonicalJSON.digest(manifest) == evaluationScaffoldManifestSHA256
        else {
            throw Self.invalid()
        }
    }

    static func invalid() -> FactoryValidationError {
        FactoryValidationError(
            code: "untrusted_broker_anchor",
            message: "Broker activation requires the root-owned merged trusted-root anchor.",
        )
    }

    private struct Stored: Codable {
        let activationPublicKeySHA256: SHA256Digest
        let brokerIdentitySHA256: SHA256Digest
        let brokerStateRootPath: String
        let brokerUserID: Int
        let evaluationScaffoldManifestSHA256: SHA256Digest
        let evaluationScaffoldRootPath: String
        let operatorUserID: Int
        let repository: String
        let schemaVersion: Int
        let signingKeyID: String
        let trustedRootSHA: GitObjectID
        let evolutionAcceptanceSHA256: SHA256Digest
    }

    private static func isCanonicalAbsolutePath(_ path: String) -> Bool {
        guard path.hasPrefix("/"),
              path != "/",
              !path.hasSuffix("/"),
              !path.contains("//"),
              path.utf8.count <= 4096,
              path.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              path.split(separator: "/").allSatisfy({ $0 != "." && $0 != ".." })
        else {
            return false
        }
        let url = URL(fileURLWithPath: path)
        return url.path == path
    }

    private static func pathsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        contains(root: lhs, path: rhs) || contains(root: rhs, path: lhs)
    }

    private static func contains(root: String, path: String) -> Bool {
        path == root || path.hasPrefix(root + "/")
    }
}

enum BrokerTrustAnchorLoader {
    private static let maximumBytes = 64 * 1024
    /// checkpoint 9 installs this root-owned file and a distinct least-privilege broker account.
    static let installationURL = URL(
        fileURLWithPath: "/Library/Application Support/SwiftMacFactory/trust-anchor.json",
    )

    static func load() throws -> BrokerTrustAnchor {
        guard let brokerExecutableURL = BrokerExecutableIdentity.runningExecutableURL(),
              let brokerExecutableMappedIdentity = BrokerExecutableIdentity.runningMappedIdentity()
        else {
            throw BrokerTrustAnchor.invalid()
        }
        return try load(
            at: installationURL,
            requiredOwnerUID: 0,
            brokerExecutableURL: brokerExecutableURL,
            brokerExecutableMappedIdentity: brokerExecutableMappedIdentity,
            requiredExecutableOwnerUID: 0,
            effectiveUserID: geteuid(),
            realUserID: getuid(),
        )
    }

    static func load(
        at url: URL,
        requiredOwnerUID: uid_t,
        brokerExecutableURL: URL,
        brokerExecutableMappedIdentity: BrokerExecutableMappedIdentity,
        requiredExecutableOwnerUID: uid_t,
        effectiveUserID: uid_t,
        realUserID: uid_t,
    ) throws -> BrokerTrustAnchor {
        guard url.isFileURL,
              url.path.hasPrefix("/"),
              url.path.utf8.count <= 4096,
              url.path.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
        else {
            throw BrokerTrustAnchor.invalid()
        }
        var originalMetadata = stat()
        guard Darwin.lstat(url.path, &originalMetadata) == 0,
              originalMetadata.st_mode & S_IFMT != S_IFLNK,
              let resolved = Darwin.realpath(url.path, nil)
        else {
            throw BrokerTrustAnchor.invalid()
        }
        defer { Darwin.free(resolved) }
        let resolvedURL = URL(fileURLWithPath: String(cString: resolved))
        let components = resolvedURL.pathComponents.filter { $0 != "/" }
        guard !components.isEmpty else { throw BrokerTrustAnchor.invalid() }

        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0,
              BrokerFilesystemSecurity.isSecureDirectory(
                  fileDescriptor: directoryFD,
                  allowedOwnerUIDs: [0, requiredOwnerUID],
              )
        else {
            throw BrokerTrustAnchor.invalid()
        }
        defer { Darwin.close(directoryFD) }

        for component in components.dropLast() {
            let nextFD = Darwin.openat(
                directoryFD,
                component,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            )
            guard nextFD >= 0 else { throw BrokerTrustAnchor.invalid() }
            var metadata = stat()
            let valid = Darwin.fstat(nextFD, &metadata) == 0
                && metadata.st_mode & S_IFMT == S_IFDIR
                && (metadata.st_uid == 0 || metadata.st_uid == requiredOwnerUID)
                && metadata.st_mode & 0o022 == 0
                && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
            guard valid else {
                Darwin.close(nextFD)
                throw BrokerTrustAnchor.invalid()
            }
            Darwin.close(directoryFD)
            directoryFD = nextFD
        }

        guard let name = components.last else { throw BrokerTrustAnchor.invalid() }
        let fileFD = Darwin.openat(directoryFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fileFD >= 0 else { throw BrokerTrustAnchor.invalid() }
        defer { Darwin.close(fileFD) }
        var before = stat()
        guard Darwin.fstat(fileFD, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == requiredOwnerUID,
              before.st_nlink == 1,
              before.st_mode & 0o022 == 0,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: fileFD),
              before.st_size > 0,
              before.st_size <= maximumBytes
        else {
            throw BrokerTrustAnchor.invalid()
        }

        let bytes = try readExactly(fileFD, count: Int(before.st_size))
        var after = stat()
        guard bytes.count == before.st_size,
              Darwin.fstat(fileFD, &after) == 0,
              before.st_dev == after.st_dev,
              before.st_ino == after.st_ino,
              before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec
        else {
            throw BrokerTrustAnchor.invalid()
        }
        do {
            let anchor = try CanonicalJSON.decode(BrokerTrustAnchor.self, from: bytes)
            try anchor.validateRuntime(
                effectiveUserID: effectiveUserID,
                realUserID: realUserID,
            )
            try BrokerExecutableIdentity.validate(
                at: brokerExecutableURL,
                expectedSHA256: anchor.brokerIdentitySHA256,
                mappedIdentity: brokerExecutableMappedIdentity,
                requiredOwnerUID: requiredExecutableOwnerUID,
            )
            return anchor
        } catch {
            throw BrokerTrustAnchor.invalid()
        }
    }

    private static func readExactly(_ fileDescriptor: Int32, count: Int) throws -> Data {
        var data = Data()
        data.reserveCapacity(count)
        while data.count < count {
            let remaining = count - data.count
            var buffer = [UInt8](repeating: 0, count: min(remaining, 64 * 1024))
            let bytesRead = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(fileDescriptor, bytes.baseAddress, bytes.count)
            }
            if bytesRead < 0, errno == EINTR { continue }
            guard bytesRead > 0 else { throw BrokerTrustAnchor.invalid() }
            data.append(contentsOf: buffer.prefix(bytesRead))
        }
        var extra: UInt8 = 0
        guard Darwin.read(fileDescriptor, &extra, 1) == 0 else {
            throw BrokerTrustAnchor.invalid()
        }
        return data
    }
}

struct BrokerExecutableMappedIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
}

enum BrokerExecutableIdentity {
    private static let maximumBytes = 128 * 1024 * 1024

    static func runningExecutableURL() -> URL? {
        var path = [CChar](repeating: 0, count: Int(PATH_MAX) * 4)
        let count = Darwin.proc_pidpath(Darwin.getpid(), &path, UInt32(path.count))
        guard count > 0, count < path.count else { return nil }
        let bytes = path.prefix(Int(count)).map { UInt8(bitPattern: $0) }
        return URL(fileURLWithPath: String(decoding: bytes, as: UTF8.self))
    }

    static func runningMappedIdentity() -> BrokerExecutableMappedIdentity? {
        var information = proc_regionwithpathinfo()
        let address = UInt64(UInt(bitPattern: #dsohandle))
        let expectedBytes = MemoryLayout<proc_regionwithpathinfo>.size
        let observedBytes = withUnsafeMutablePointer(to: &information) { pointer in
            Darwin.proc_pidinfo(
                Darwin.getpid(),
                PROC_PIDREGIONPATHINFO,
                address,
                pointer,
                Int32(expectedBytes),
            )
        }
        let mapped = information.prp_vip.vip_vi.vi_stat
        guard observedBytes == expectedBytes,
              mapped.vst_dev != 0,
              mapped.vst_ino != 0
        else {
            return nil
        }
        return BrokerExecutableMappedIdentity(
            device: dev_t(mapped.vst_dev),
            inode: ino_t(mapped.vst_ino),
        )
    }

    static func fileIdentity(at url: URL) throws -> BrokerExecutableMappedIdentity {
        let descriptor = Darwin.open(url.path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard descriptor >= 0 else { throw BrokerTrustAnchor.invalid() }
        defer { Darwin.close(descriptor) }
        var metadata = stat()
        guard Darwin.fstat(descriptor, &metadata) == 0,
              metadata.st_mode & S_IFMT == S_IFREG
        else {
            throw BrokerTrustAnchor.invalid()
        }
        return BrokerExecutableMappedIdentity(device: metadata.st_dev, inode: metadata.st_ino)
    }

    static func validate(
        at url: URL,
        expectedSHA256: SHA256Digest,
        mappedIdentity: BrokerExecutableMappedIdentity,
        requiredOwnerUID: uid_t,
    ) throws {
        guard url.isFileURL,
              isCanonicalAbsolutePath(url.path)
        else {
            throw BrokerTrustAnchor.invalid()
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard !components.isEmpty else { throw BrokerTrustAnchor.invalid() }

        var directoryFD = Darwin.open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryFD >= 0,
              BrokerFilesystemSecurity.isSecureDirectory(
                  fileDescriptor: directoryFD,
                  allowedOwnerUIDs: [0, requiredOwnerUID],
              )
        else {
            throw BrokerTrustAnchor.invalid()
        }
        defer { Darwin.close(directoryFD) }

        for component in components.dropLast() {
            let nextFD = Darwin.openat(
                directoryFD,
                component,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
            )
            guard nextFD >= 0 else { throw BrokerTrustAnchor.invalid() }
            var metadata = stat()
            let valid = Darwin.fstat(nextFD, &metadata) == 0
                && metadata.st_mode & S_IFMT == S_IFDIR
                && (metadata.st_uid == 0 || metadata.st_uid == requiredOwnerUID)
                && metadata.st_mode & 0o022 == 0
                && BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: nextFD)
            guard valid else {
                Darwin.close(nextFD)
                throw BrokerTrustAnchor.invalid()
            }
            Darwin.close(directoryFD)
            directoryFD = nextFD
        }

        guard let name = components.last else { throw BrokerTrustAnchor.invalid() }
        let executableFD = Darwin.openat(directoryFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard executableFD >= 0 else { throw BrokerTrustAnchor.invalid() }
        defer { Darwin.close(executableFD) }

        var before = stat()
        guard Darwin.fstat(executableFD, &before) == 0,
              before.st_mode & S_IFMT == S_IFREG,
              before.st_uid == requiredOwnerUID,
              before.st_nlink == 1,
              before.st_mode & 0o777 == 0o555,
              before.st_mode & (S_ISUID | S_ISGID) == 0,
              before.st_mode & 0o111 == 0o111,
              BrokerFilesystemSecurity.hasNoExtendedACL(fileDescriptor: executableFD),
              before.st_dev == mappedIdentity.device,
              before.st_ino == mappedIdentity.inode,
              before.st_size > 0,
              before.st_size <= maximumBytes
        else {
            throw BrokerTrustAnchor.invalid()
        }

        var hasher = SHA256()
        var bytesRemaining = Int(before.st_size)
        while bytesRemaining > 0 {
            var buffer = [UInt8](repeating: 0, count: min(bytesRemaining, 64 * 1024))
            let bytesRead = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(executableFD, bytes.baseAddress, bytes.count)
            }
            if bytesRead < 0, errno == EINTR { continue }
            guard bytesRead > 0 else { throw BrokerTrustAnchor.invalid() }
            hasher.update(data: Data(buffer.prefix(bytesRead)))
            bytesRemaining -= bytesRead
        }
        var extra: UInt8 = 0
        guard Darwin.read(executableFD, &extra, 1) == 0 else {
            throw BrokerTrustAnchor.invalid()
        }

        var after = stat()
        var installed = stat()
        guard Darwin.fstat(executableFD, &after) == 0,
              Darwin.fstatat(directoryFD, name, &installed, AT_SYMLINK_NOFOLLOW) == 0,
              stableIdentity(before, after),
              stableIdentity(before, installed),
              try SHA256Digest(validating: hasher.finalize().map { String(format: "%02x", $0) }.joined())
              == expectedSHA256
        else {
            throw BrokerTrustAnchor.invalid()
        }
    }

    private static func isCanonicalAbsolutePath(_ path: String) -> Bool {
        path.hasPrefix("/")
            && path != "/"
            && !path.hasSuffix("/")
            && !path.contains("//")
            && path.utf8.count <= 4096
            && path.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
            && path.split(separator: "/").allSatisfy { $0 != "." && $0 != ".." }
            && URL(fileURLWithPath: path).path == path
    }

    private static func stableIdentity(_ lhs: stat, _ rhs: stat) -> Bool {
        lhs.st_dev == rhs.st_dev
            && lhs.st_ino == rhs.st_ino
            && lhs.st_mode == rhs.st_mode
            && lhs.st_nlink == rhs.st_nlink
            && lhs.st_uid == rhs.st_uid
            && lhs.st_size == rhs.st_size
            && lhs.st_mtimespec.tv_sec == rhs.st_mtimespec.tv_sec
            && lhs.st_mtimespec.tv_nsec == rhs.st_mtimespec.tv_nsec
            && lhs.st_ctimespec.tv_sec == rhs.st_ctimespec.tv_sec
            && lhs.st_ctimespec.tv_nsec == rhs.st_ctimespec.tv_nsec
    }
}

enum BrokerFilesystemSecurity {
    static func isSecureDirectory(
        fileDescriptor: Int32,
        allowedOwnerUIDs: Set<uid_t>,
    ) -> Bool {
        var metadata = stat()
        return Darwin.fstat(fileDescriptor, &metadata) == 0
            && metadata.st_mode & S_IFMT == S_IFDIR
            && allowedOwnerUIDs.contains(metadata.st_uid)
            && metadata.st_mode & 0o022 == 0
            && hasNoExtendedACL(fileDescriptor: fileDescriptor)
    }

    static func hasNoExtendedACL(fileDescriptor: Int32) -> Bool {
        errno = 0
        guard let accessControlList = Darwin.acl_get_fd_np(fileDescriptor, ACL_TYPE_EXTENDED) else {
            return errno == ENOENT
        }
        defer { Darwin.acl_free(UnsafeMutableRawPointer(accessControlList)) }
        return false
    }
}
