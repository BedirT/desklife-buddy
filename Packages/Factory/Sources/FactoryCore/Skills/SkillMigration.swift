public enum SkillMigrationDisposition: String, Codable, CaseIterable, Sendable {
    case introduce
    case replace
    case retain
    case retire
}

public enum SkillMigrationActivationStatus: String, Codable, Sendable {
    case pendingPostMerge = "pending-post-merge"
}

public enum SkillQualificationLaneID: String, Codable, CaseIterable, Comparable, Sendable {
    case ablation
    case budget
    case crossClient = "cross-client"
    case provenance
    case publicOutcome = "public-outcome"
    case sealedInstruction = "sealed-instruction"
    case toolResource = "tool-resource"
    case trigger

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public struct SkillMigrationEntry: Codable, Equatable, Sendable {
    public let activationStatus: SkillMigrationActivationStatus
    public let disposition: SkillMigrationDisposition
    public let qualificationLanes: [SkillQualificationLaneID]
    public let rationale: String
    @RequiredNullable public var replacementSkillID: String?
    public let skillID: String
    public let sourceSHA256: SHA256Digest

    public init(
        activationStatus: SkillMigrationActivationStatus,
        disposition: SkillMigrationDisposition,
        qualificationLanes: [SkillQualificationLaneID],
        rationale: String,
        replacementSkillID: String?,
        skillID: String,
        sourceSHA256: SHA256Digest,
    ) {
        self.activationStatus = activationStatus
        self.disposition = disposition
        self.qualificationLanes = qualificationLanes
        self.rationale = rationale
        self.replacementSkillID = replacementSkillID
        self.skillID = skillID
        self.sourceSHA256 = sourceSHA256
    }
}

public enum SkillMigrationPortfolioStatus: String, Codable, Sendable {
    case inertPendingActivation = "inert-pending-activation"
}

/// Explicit one-for-one disposition of the curated skill inventory before autonomous routing can activate.
public struct SkillMigrationPortfolio: Codable, Equatable, Sendable {
    public let entries: [SkillMigrationEntry]
    public let registrySHA256: SHA256Digest
    public let schemaVersion: Int
    public let status: SkillMigrationPortfolioStatus
    public let unclassifiedSkillIDs: [String]

    public init(
        entries: [SkillMigrationEntry],
        registrySHA256: SHA256Digest,
        schemaVersion: Int = FactoryCore.schemaVersion,
        status: SkillMigrationPortfolioStatus,
        unclassifiedSkillIDs: [String],
    ) {
        self.entries = entries
        self.registrySHA256 = registrySHA256
        self.schemaVersion = schemaVersion
        self.status = status
        self.unclassifiedSkillIDs = unclassifiedSkillIDs
    }

    public func validate(registry: SkillRegistry) throws {
        try registry.validate()
        let registryByID = Dictionary(uniqueKeysWithValues: registry.skills.map { ($0.id, $0) })
        let entryIDs = entries.map(\.skillID)
        let expectedLanes = SkillQualificationLaneID.allCases.sorted()
        guard schemaVersion == FactoryCore.schemaVersion,
              status == .inertPendingActivation,
              registrySHA256 == CanonicalJSON.digest(registry),
              unclassifiedSkillIDs.isEmpty,
              entryIDs == entryIDs.sorted(),
              Set(entryIDs).count == entryIDs.count,
              entryIDs == registry.skills.map(\.id)
        else {
            throw FactoryValidationError(
                code: "invalid-skill-migration-portfolio",
                message: "Skill migration must classify the exact frozen registry once, with no omissions.",
            )
        }

        for entry in entries {
            guard let skill = registryByID[entry.skillID],
                  entry.sourceSHA256 == skill.sourceSHA256,
                  entry.qualificationLanes == expectedLanes,
                  FactoryTextRules.isBoundedText(entry.rationale, maximumScalars: 1000),
                  !entry.rationale.isEmpty,
                  (entry.disposition == .replace) == (entry.replacementSkillID != nil),
                  entry.replacementSkillID.map(FactoryTextRules.isStableID) ?? true,
                  dispositionMatchesProvenance(entry.disposition, skill: skill)
            else {
                throw FactoryValidationError(
                    code: "invalid-skill-migration-entry",
                    message: "Each migration entry must bind source bytes, disposition, replacement, and all qualification lanes.",
                )
            }
        }
    }

    private func dispositionMatchesProvenance(
        _ disposition: SkillMigrationDisposition,
        skill: SkillManifest,
    ) -> Bool {
        switch disposition {
        case .introduce:
            skill.provenance.introduction == .introducedInCurrentChange
        case .retain:
            skill.provenance.introduction == .inheritedAtBase
        case .replace, .retire:
            true
        }
    }
}

public struct SkillMigrationAuditInput: Codable, Equatable, Sendable {
    public let migration: SkillMigrationPortfolio
    public let registry: SkillRegistry

    public init(migration: SkillMigrationPortfolio, registry: SkillRegistry) {
        self.migration = migration
        self.registry = registry
    }
}
