import Foundation

/// Contract class deciding whether control-plane paths can be considered at all.
public enum ChangePurpose: String, Codable, Sendable {
    case factoryChange = "factory_change"
    case product
}

/// Structured regular-file mutation supported by the patch importer.
public enum PatchFileOperationKind: String, Codable, Sendable {
    case create
    case delete
    case update
}

/// Exact content and mode expected for a regular file.
public struct FileExpectation: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case bytes
        case executable
        case sha256
        case state
    }

    public let bytes: Int
    public let executable: Bool
    public let sha256: SHA256Digest

    public init(sha256: SHA256Digest, bytes: Int, executable: Bool) {
        self.bytes = bytes
        self.executable = executable
        self.sha256 = sha256
    }

    /// Convenience for building a digest-bound expectation from fixture bytes.
    public init(data: Data, executable: Bool) {
        bytes = data.count
        self.executable = executable
        sha256 = SHA256Digest.hashing(data)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(String.self, forKey: .state) == "regular" else {
            throw DecodingError.dataCorruptedError(
                forKey: .state,
                in: container,
                debugDescription: "File state must be regular.",
            )
        }
        bytes = try container.decode(Int.self, forKey: .bytes)
        executable = try container.decode(Bool.self, forKey: .executable)
        sha256 = try container.decode(SHA256Digest.self, forKey: .sha256)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bytes, forKey: .bytes)
        try container.encode(executable, forKey: .executable)
        try container.encode(sha256, forKey: .sha256)
        try container.encode("regular", forKey: .state)
    }
}

/// Rights and generation facts required before a binary asset can enter source.
public struct AssetProvenance: Codable, Equatable, Sendable {
    private enum CodingKeys: String, CodingKey {
        case generator
        case license
        case model
        case ownerApproval
        case promptSHA256
        case sourceClass
        case sourceSHA256
    }

    public enum OwnerApproval: String, Codable, Sendable {
        case approved
        case notRequired = "not_required"
        case required
    }

    public enum SourceClass: String, Codable, Sendable {
        case generated
        case licensed
        case ownerProvided = "owner_provided"
        case placeholder
        case repositoryDerived = "repository_derived"
    }

    @RequiredNullable public var generator: String?
    @RequiredNullable public var license: String?
    @RequiredNullable public var model: String?
    public let ownerApproval: OwnerApproval
    @RequiredNullable public var promptSHA256: SHA256Digest?
    public let sourceClass: SourceClass
    @RequiredNullable public var sourceSHA256: SHA256Digest?

    public init(
        generator: String?,
        license: String?,
        model: String?,
        ownerApproval: OwnerApproval,
        promptSHA256: SHA256Digest?,
        sourceClass: SourceClass,
        sourceSHA256: SHA256Digest?,
    ) {
        self.generator = generator
        self.license = license
        self.model = model
        self.ownerApproval = ownerApproval
        self.promptSHA256 = promptSHA256
        self.sourceClass = sourceClass
        self.sourceSHA256 = sourceSHA256
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let generator = try container.decode(RequiredNullable<String>.self, forKey: .generator).wrappedValue
        let license = try container.decode(RequiredNullable<String>.self, forKey: .license).wrappedValue
        let model = try container.decode(RequiredNullable<String>.self, forKey: .model).wrappedValue
        let ownerApproval = try container.decode(OwnerApproval.self, forKey: .ownerApproval)
        let promptSHA256 = try container
            .decode(RequiredNullable<SHA256Digest>.self, forKey: .promptSHA256).wrappedValue
        let sourceClass = try container.decode(SourceClass.self, forKey: .sourceClass)
        let sourceSHA256 = try container
            .decode(RequiredNullable<SHA256Digest>.self, forKey: .sourceSHA256).wrappedValue
        let optionalText = [generator, license, model].compactMap(\.self)
        guard optionalText.allSatisfy({ (1 ... 256).contains($0.unicodeScalars.count) }),
              ownerApproval != .notRequired
              || sourceClass == .placeholder
              || sourceClass == .repositoryDerived
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .ownerApproval,
                in: container,
                debugDescription: "Not-required approval is limited to placeholder or repository-derived assets.",
            )
        }
        self.init(
            generator: generator,
            license: license,
            model: model,
            ownerApproval: ownerApproval,
            promptSHA256: promptSHA256,
            sourceClass: sourceClass,
            sourceSHA256: sourceSHA256,
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(RequiredNullable(wrappedValue: generator), forKey: .generator)
        try container.encode(RequiredNullable(wrappedValue: license), forKey: .license)
        try container.encode(RequiredNullable(wrappedValue: model), forKey: .model)
        try container.encode(ownerApproval, forKey: .ownerApproval)
        try container.encode(RequiredNullable(wrappedValue: promptSHA256), forKey: .promptSHA256)
        try container.encode(sourceClass, forKey: .sourceClass)
        try container.encode(RequiredNullable(wrappedValue: sourceSHA256), forKey: .sourceSHA256)
    }

    var isComplete: Bool {
        let optionalText = [generator, license, model].compactMap(\.self)
        guard optionalText.allSatisfy({ (1 ... 256).contains($0.unicodeScalars.count) }) else { return false }
        guard ownerApproval != .required else { return false }
        switch sourceClass {
        case .generated:
            return generator != nil && model != nil && promptSHA256 != nil && license != nil
        case .licensed:
            return license != nil && sourceSHA256 != nil
        case .ownerProvided, .repositoryDerived:
            return sourceSHA256 != nil
        case .placeholder:
            return true
        }
    }
}

/// Whether returned bytes are source text or a provenance-bearing binary asset.
public enum PatchContentKind: String, Codable, Sendable {
    case asset
    case text
}

/// Validated output object referenced by a create or update operation.
public struct PatchFilePayload: Equatable, Sendable {
    public let expectation: FileExpectation
    public let contentRef: RepositoryPath
    public let contentKind: PatchContentKind
    public let assetProvenance: AssetProvenance?

    public init(
        expectation: FileExpectation,
        contentRef: RepositoryPath,
        contentKind: PatchContentKind,
        assetProvenance: AssetProvenance?,
    ) {
        self.expectation = expectation
        self.contentRef = contentRef
        self.contentKind = contentKind
        self.assetProvenance = assetProvenance
    }
}

/// Required before state: either absent for create or an exact regular file.
public enum PatchBefore: Equatable, Sendable {
    case absent
    case regular(FileExpectation)

    var expectation: FileExpectation? {
        if case let .regular(value) = self { return value }
        return nil
    }
}

extension PatchBefore: Codable {
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer()
        if let object = try? raw.decode([String: String].self), object == ["state": "absent"] {
            self = .absent
        } else {
            self = try .regular(raw.decode(FileExpectation.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .absent: try container.encode(["state": "absent"])
        case let .regular(expectation): try container.encode(expectation)
        }
    }
}

/// Required after state: deleted or one exact scratch content object.
public enum PatchAfter: Equatable, Sendable {
    case deleted
    case regular(PatchFilePayload)

    var payload: PatchFilePayload? {
        if case let .regular(value) = self { return value }
        return nil
    }
}

extension PatchAfter: Codable {
    private enum CodingKeys: String, CodingKey {
        case assetProvenance
        case bytes
        case contentKind
        case contentRef
        case executable
        case sha256
        case state
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(String.self, forKey: .state) {
        case "deleted":
            self = .deleted
        case "regular":
            let expectation = try FileExpectation(
                sha256: container.decode(SHA256Digest.self, forKey: .sha256),
                bytes: container.decode(Int.self, forKey: .bytes),
                executable: container.decode(Bool.self, forKey: .executable),
            )
            self = try .regular(
                PatchFilePayload(
                    expectation: expectation,
                    contentRef: container.decode(RepositoryPath.self, forKey: .contentRef),
                    contentKind: container.decode(PatchContentKind.self, forKey: .contentKind),
                    assetProvenance: container.decodeIfPresent(AssetProvenance.self, forKey: .assetProvenance),
                ),
            )
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .state,
                in: container,
                debugDescription: "Unknown patch after state.",
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .deleted:
            try container.encode("deleted", forKey: .state)
        case let .regular(payload):
            try container.encode(payload.assetProvenance, forKey: .assetProvenance)
            try container.encode(payload.expectation.bytes, forKey: .bytes)
            try container.encode(payload.contentKind, forKey: .contentKind)
            try container.encode(payload.contentRef, forKey: .contentRef)
            try container.encode(payload.expectation.executable, forKey: .executable)
            try container.encode(payload.expectation.sha256, forKey: .sha256)
            try container.encode("regular", forKey: .state)
        }
    }
}

/// One digest-bound regular-file change in a patch envelope.
public struct PatchFileOperation: Codable, Equatable, Sendable {
    public let after: PatchAfter
    public let before: PatchBefore
    public let kind: PatchFileOperationKind
    public let operationID: String
    public let path: RepositoryPath

    public init(
        operationID: String,
        path: RepositoryPath,
        kind: PatchFileOperationKind,
        before: PatchBefore,
        after: PatchAfter,
    ) {
        self.after = after
        self.before = before
        self.kind = kind
        self.operationID = operationID
        self.path = path
    }
}

/// Writer output that can cross from scratch into an authoritative worktree.
public struct PatchEnvelope: Codable, Equatable, Sendable {
    public let contractSHA256: SHA256Digest
    public let envelopeID: String
    public let expectedBaseSHA: GitObjectID
    public let expectedTreeSHA: GitObjectID
    public let invocationID: String
    public var operations: [PatchFileOperation]
    public let policySHA256: SHA256Digest
    public let projectionSHA256: SHA256Digest
    public let runID: String
    public let schemaVersion: Int

    public init(
        contractSHA256: SHA256Digest,
        envelopeID: String,
        expectedBaseSHA: GitObjectID,
        expectedTreeSHA: GitObjectID,
        invocationID: String,
        operations: [PatchFileOperation],
        policySHA256: SHA256Digest,
        projectionSHA256: SHA256Digest,
        runID: String,
        schemaVersion: Int = FactoryCore.schemaVersion,
    ) {
        self.contractSHA256 = contractSHA256
        self.envelopeID = envelopeID
        self.expectedBaseSHA = expectedBaseSHA
        self.expectedTreeSHA = expectedTreeSHA
        self.invocationID = invocationID
        self.operations = operations
        self.policySHA256 = policySHA256
        self.projectionSHA256 = projectionSHA256
        self.runID = runID
        self.schemaVersion = schemaVersion
    }
}

extension PatchEnvelope {
    /// Validates every envelope invariant that does not depend on live repository or installed policy state.
    func validateStructure(
        maximumOperations: Int = PatchImportPolicy.maximumKernelOperations,
        maximumTotalBytes: Int = PatchRecoveryJournal.maximumRecoveryBytes,
    ) throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(envelopeID),
              FactoryTextRules.isStableID(runID),
              FactoryTextRules.isStableID(invocationID),
              maximumOperations > 0,
              maximumOperations <= PatchImportPolicy.maximumKernelOperations,
              maximumTotalBytes > 0,
              maximumTotalBytes <= PatchRecoveryJournal.maximumRecoveryBytes,
              !operations.isEmpty,
              operations.count <= maximumOperations
        else {
            throw FactoryValidationError(
                code: "patch_envelope_mismatch",
                message: "Patch envelope metadata or fixed ceilings are invalid.",
            )
        }

        let paths = operations.map(\.path)
        let operationIDs = operations.map(\.operationID)
        guard paths == paths.sorted(),
              Set(paths.map(\.collisionKey)).count == paths.count,
              Set(operationIDs).count == operationIDs.count,
              operationIDs.allSatisfy(FactoryTextRules.isStableID)
        else {
            throw FactoryValidationError(
                code: "noncanonical_patch_operations",
                message: "Patch operations must be sorted and unique.",
            )
        }
        try validateNoPathAncestryOverlap(paths)

        var totalBytes = 0
        let outputRoot = try RepositoryPath(validating: "output/files")
        for operation in operations {
            if let before = operation.before.expectation {
                try addToBudget(before.bytes, totalBytes: &totalBytes, maximumTotalBytes: maximumTotalBytes)
            }
            if let payload = operation.after.payload {
                try addToBudget(
                    payload.expectation.bytes,
                    totalBytes: &totalBytes,
                    maximumTotalBytes: maximumTotalBytes,
                )
                guard payload.contentRef.isWithin(outputRoot) else {
                    throw FactoryValidationError(
                        code: "unsafe_content_reference",
                        message: "Patch content must live beneath the output files root.",
                    )
                }
                switch payload.contentKind {
                case .text:
                    guard payload.assetProvenance == nil else {
                        throw FactoryValidationError(
                            code: "invalid_text_patch",
                            message: "Text patch metadata cannot claim binary asset provenance.",
                        )
                    }
                case .asset:
                    guard payload.assetProvenance?.isComplete == true else {
                        throw FactoryValidationError(
                            code: "unapproved_binary_asset",
                            message: "Binary asset metadata needs complete provenance before policy approval.",
                        )
                    }
                }
            }
            switch operation.kind {
            case .create where operation.before == .absent && operation.after.payload != nil:
                break
            case .update where operation.before.expectation != nil && operation.after.payload != nil:
                guard operation.before.expectation != operation.after.payload?.expectation else {
                    throw FactoryValidationError(
                        code: "invalid_patch_operation",
                        message: "An update must change content or executable mode.",
                    )
                }
            case .delete where operation.before.expectation != nil && operation.after == .deleted:
                break
            default:
                throw FactoryValidationError(
                    code: "invalid_patch_operation",
                    message: "Patch before/after states do not match the operation kind.",
                )
            }
        }
    }

    private func validateNoPathAncestryOverlap(_ paths: [RepositoryPath]) throws {
        let ancestryOrder = paths
            .map { $0.collisionKey.split(separator: "/").map(String.init) }
            .sorted(by: componentOrder)
        for (left, right) in zip(ancestryOrder, ancestryOrder.dropFirst()) where right.starts(with: left) {
            throw FactoryValidationError(
                code: "patch_path_alias",
                message: "Patch operations may not overlap by ancestry.",
            )
        }
    }

    private func componentOrder(_ lhs: [String], _ rhs: [String]) -> Bool {
        for (left, right) in zip(lhs, rhs) where left != right {
            return left < right
        }
        return lhs.count < rhs.count
    }

    private func addToBudget(
        _ bytes: Int,
        totalBytes: inout Int,
        maximumTotalBytes: Int,
    ) throws {
        let (nextTotal, overflow) = totalBytes.addingReportingOverflow(bytes)
        guard bytes >= 0,
              bytes <= SecureRepositoryFileSystem.maximumRegularFileBytes,
              !overflow,
              nextTotal <= maximumTotalBytes
        else {
            throw FactoryValidationError(
                code: "patch_budget_exceeded",
                message: "Patch transaction and recovery data exceeds its byte ceiling.",
            )
        }
        totalBytes = nextTotal
    }
}

/// Trusted policy ceiling intersected with one patch envelope.
public struct PatchImportPolicy: Codable, Equatable, Sendable {
    static let maximumKernelOperations = 4096

    public let purpose: ChangePurpose
    public let contractSHA256: SHA256Digest
    public let expectedInvocationID: String
    public let expectedRunID: String
    public let projectionSHA256: SHA256Digest
    public let allowedRoots: [RepositoryPath]
    public let approvedAssetBindingsSHA256: [SHA256Digest]
    public let approvedAssetExtensions: [String]
    public let maximumOperations: Int
    public let maximumTotalBytes: Int

    public init(
        purpose: ChangePurpose,
        contractSHA256: SHA256Digest,
        expectedInvocationID: String,
        expectedRunID: String,
        projectionSHA256: SHA256Digest,
        allowedRoots: [RepositoryPath],
        approvedAssetExtensions: [String],
        maximumOperations: Int,
        maximumTotalBytes: Int,
        approvedAssetBindingsSHA256: [SHA256Digest] = [],
    ) throws {
        let identifier = /^[a-z0-9][a-z0-9._:-]{0,127}$/
        guard expectedInvocationID.wholeMatch(of: identifier) != nil,
              expectedRunID.wholeMatch(of: identifier) != nil,
              !allowedRoots.isEmpty,
              (1 ... Self.maximumKernelOperations).contains(maximumOperations),
              maximumTotalBytes > 0,
              Set(allowedRoots.map(\.collisionKey)).count == allowedRoots.count,
              allowedRoots == allowedRoots.sorted(),
              approvedAssetBindingsSHA256 == approvedAssetBindingsSHA256.sorted(by: {
                  $0.rawValue < $1.rawValue
              }),
              Set(approvedAssetBindingsSHA256).count == approvedAssetBindingsSHA256.count,
              approvedAssetBindingsSHA256.count <= maximumOperations,
              approvedAssetExtensions == Array(Set(approvedAssetExtensions)).sorted(),
              approvedAssetExtensions.allSatisfy({ !$0.isEmpty && $0 == $0.lowercased() })
        else {
            throw FactoryValidationError(
                code: "invalid_patch_policy",
                message: "Patch policy must be bounded and canonical.",
            )
        }
        self.purpose = purpose
        self.contractSHA256 = contractSHA256
        self.expectedInvocationID = expectedInvocationID
        self.expectedRunID = expectedRunID
        self.projectionSHA256 = projectionSHA256
        self.allowedRoots = allowedRoots
        self.approvedAssetBindingsSHA256 = approvedAssetBindingsSHA256
        self.approvedAssetExtensions = approvedAssetExtensions
        self.maximumOperations = maximumOperations
        self.maximumTotalBytes = maximumTotalBytes
    }

    public init(from decoder: Decoder) throws {
        let value = try StoredPolicy(from: decoder)
        try self.init(
            purpose: value.purpose,
            contractSHA256: value.contractSHA256,
            expectedInvocationID: value.expectedInvocationID,
            expectedRunID: value.expectedRunID,
            projectionSHA256: value.projectionSHA256,
            allowedRoots: value.allowedRoots,
            approvedAssetExtensions: value.approvedAssetExtensions,
            maximumOperations: value.maximumOperations,
            maximumTotalBytes: value.maximumTotalBytes,
            approvedAssetBindingsSHA256: value.approvedAssetBindingsSHA256,
        )
    }

    public func encode(to encoder: Encoder) throws {
        try StoredPolicy(
            purpose: purpose,
            contractSHA256: contractSHA256,
            expectedInvocationID: expectedInvocationID,
            expectedRunID: expectedRunID,
            projectionSHA256: projectionSHA256,
            allowedRoots: allowedRoots,
            approvedAssetBindingsSHA256: approvedAssetBindingsSHA256,
            approvedAssetExtensions: approvedAssetExtensions,
            maximumOperations: maximumOperations,
            maximumTotalBytes: maximumTotalBytes,
        ).encode(to: encoder)
    }

    /// Digest of one exact owner-approved asset destination, payload, and provenance record.
    package static func assetApprovalBindingSHA256(
        path: RepositoryPath,
        contentSHA256: SHA256Digest,
        bytes: Int,
        provenance: AssetProvenance,
    ) -> SHA256Digest {
        CanonicalJSON.digest(
            AssetApprovalBinding(
                bytes: bytes,
                contentSHA256: contentSHA256,
                path: path,
                provenanceSHA256: CanonicalJSON.digest(provenance),
                schemaVersion: FactoryCore.schemaVersion,
            ),
        )
    }

    /// Canonical policy identity bound into every accepted patch envelope.
    public var digest: SHA256Digest {
        CanonicalJSON.digest(self)
    }

    private struct AssetApprovalBinding: Codable {
        let bytes: Int
        let contentSHA256: SHA256Digest
        let path: RepositoryPath
        let provenanceSHA256: SHA256Digest
        let schemaVersion: Int
    }

    private struct StoredPolicy: Codable {
        let purpose: ChangePurpose
        let contractSHA256: SHA256Digest
        let expectedInvocationID: String
        let expectedRunID: String
        let projectionSHA256: SHA256Digest
        let allowedRoots: [RepositoryPath]
        let approvedAssetBindingsSHA256: [SHA256Digest]
        let approvedAssetExtensions: [String]
        let maximumOperations: Int
        let maximumTotalBytes: Int
    }
}

/// Deterministic interruption used only by rollback and recovery fixtures.
public struct PatchImportFault: Equatable, Sendable {
    public let failAfterAppliedOperation: Int?
    public let simulateProcessDeathAfterAppliedOperation: Int?

    public init(
        failAfterAppliedOperation: Int? = nil,
        simulateProcessDeathAfterAppliedOperation: Int? = nil,
    ) {
        self.failAfterAppliedOperation = failAfterAppliedOperation
        self.simulateProcessDeathAfterAppliedOperation = simulateProcessDeathAfterAppliedOperation
    }
}

/// Content-addressed result of a completed patch transaction.
public struct PatchImportReceipt: Codable, Equatable, Sendable {
    public let envelopeID: String
    public let beforeTree: SHA256Digest
    public let afterTree: SHA256Digest
    public let operationIDs: [String]
    public let receiptDigest: SHA256Digest

    public init(
        envelopeID: String,
        beforeTree: SHA256Digest,
        afterTree: SHA256Digest,
        operationIDs: [String],
        receiptDigest: SHA256Digest,
    ) {
        self.envelopeID = envelopeID
        self.beforeTree = beforeTree
        self.afterTree = afterTree
        self.operationIDs = operationIDs
        self.receiptDigest = receiptDigest
    }
}
