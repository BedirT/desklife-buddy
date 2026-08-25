public struct TraceValue: Codable, Equatable, Sendable {
    public let contentSHA256: SHA256Digest
    public let summary: String

    public init(contentSHA256: SHA256Digest, summary: String) {
        self.contentSHA256 = contentSHA256
        self.summary = summary
    }
}

public enum ProductRetentionClass: String, Codable, Sendable {
    case ephemeral
    case localRestricted = "local-restricted"
    case sanitizedDurable = "sanitized-durable"
}

public enum ProductTraceConsent: String, Codable, Sendable {
    case contractApproved = "contract-approved"
    case ownerImported = "owner-imported"
}

public enum ProductTraceSourceKind: String, Codable, Sendable {
    case localOutcome = "local-outcome"
    case manualImport = "manual-import"
    case structuredCorrection = "structured-correction"
}

public struct ProductTraceSource: Codable, Equatable, Sendable {
    public let consent: ProductTraceConsent
    public let contentSHA256: SHA256Digest
    public let kind: ProductTraceSourceKind
    public let provenance: String
    public let retentionClass: ProductRetentionClass

    public init(
        consent: ProductTraceConsent,
        contentSHA256: SHA256Digest,
        kind: ProductTraceSourceKind,
        provenance: String,
        retentionClass: ProductRetentionClass,
    ) {
        self.consent = consent
        self.contentSHA256 = contentSHA256
        self.kind = kind
        self.provenance = provenance
        self.retentionClass = retentionClass
    }
}

public struct ProductTraceRedaction: Codable, Equatable, Sendable {
    public let contentRemoved: Bool
    public let policyID: String

    public init(contentRemoved: Bool, policyID: String) {
        self.contentRemoved = contentRemoved
        self.policyID = policyID
    }
}

public struct ProductTrace: Codable, Equatable, Sendable {
    @RequiredNullable public var acceptedOutcome: TraceValue?
    public let collectedAt: String
    public let observedAction: String
    public let path: [TraceValue]
    public let proposedResult: TraceValue
    public let redaction: ProductTraceRedaction
    public let schemaVersion: Int
    public let source: ProductTraceSource
    public let traceID: String

    public init(
        acceptedOutcome: TraceValue?,
        collectedAt: String,
        observedAction: String,
        path: [TraceValue],
        proposedResult: TraceValue,
        redaction: ProductTraceRedaction,
        schemaVersion: Int,
        source: ProductTraceSource,
        traceID: String,
    ) {
        self.acceptedOutcome = acceptedOutcome
        self.collectedAt = collectedAt
        self.observedAction = observedAction
        self.path = path
        self.proposedResult = proposedResult
        self.redaction = redaction
        self.schemaVersion = schemaVersion
        self.source = source
        self.traceID = traceID
    }

    public func validate() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(traceID),
              FactoryTextRules.isStableID(redaction.policyID),
              redaction.contentRemoved,
              !path.isEmpty,
              FactoryTextRules.isBoundedText(collectedAt, maximumScalars: 64),
              FactoryTextRules.isBoundedText(observedAction, maximumScalars: 2048),
              FactoryTextRules.isBoundedText(source.provenance, maximumScalars: 512),
              valuesAreBounded(path + [proposedResult] + [acceptedOutcome].compactMap(\.self))
        else {
            throw FactoryValidationError(
                code: "invalid-product-trace",
                message: "Product traces require explicit consent, redaction, provenance, and bounded sanitized values.",
            )
        }
    }

    private func valuesAreBounded(_ values: [TraceValue]) -> Bool {
        values.allSatisfy { FactoryTextRules.isBoundedText($0.summary, maximumScalars: 2048) }
    }
}

public enum ProductCorrectionActor: String, Codable, Sendable {
    case domainExpert = "domain_expert"
    case owner
    case user
}

public struct ProductCorrection: Codable, Equatable, Sendable {
    public let acceptedSHA256: SHA256Digest
    public let actor: ProductCorrectionActor
    public let capturedAt: String
    public let correctionID: String
    public let proposedSHA256: SHA256Digest
    public let schemaVersion: Int
    public let summary: String
    public let traceID: String

    public init(
        acceptedSHA256: SHA256Digest,
        actor: ProductCorrectionActor,
        capturedAt: String,
        correctionID: String,
        proposedSHA256: SHA256Digest,
        schemaVersion: Int,
        summary: String,
        traceID: String,
    ) {
        self.acceptedSHA256 = acceptedSHA256
        self.actor = actor
        self.capturedAt = capturedAt
        self.correctionID = correctionID
        self.proposedSHA256 = proposedSHA256
        self.schemaVersion = schemaVersion
        self.summary = summary
        self.traceID = traceID
    }

    public func validate() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(correctionID),
              FactoryTextRules.isStableID(traceID),
              FactoryTextRules.isBoundedText(capturedAt, maximumScalars: 64),
              FactoryTextRules.isBoundedText(summary, maximumScalars: 2048)
        else {
            throw FactoryValidationError(
                code: "invalid-product-correction",
                message: "Correction is not bounded or trace-bound.",
            )
        }
    }
}

public enum ExpertConfidence: String, Codable, Sendable {
    case confirmed
    case probable
    case uncertain
}

public enum ExpertDecisionActor: String, Codable, Sendable {
    case domainExpert = "domain_expert"
    case owner
}

public enum ExpertDispositionKind: String, Codable, Sendable {
    case actionableDefect = "actionable-defect"
    case expectedNoise = "expected-noise"
    case instrumentationError = "instrumentation-error"
    case stablePreference = "stable-preference"
    case uncertain
    case unsupportedCapability = "unsupported-capability"
}

public struct ExpertDisposition: Codable, Equatable, Sendable {
    public let confidence: ExpertConfidence
    public let correctionIDs: [String]
    public let decidedAt: String
    public let decidedBy: ExpertDecisionActor
    public let disposition: ExpertDispositionKind
    public let dispositionID: String
    public let rationale: String
    public let schemaVersion: Int

    public init(
        confidence: ExpertConfidence,
        correctionIDs: [String],
        decidedAt: String,
        decidedBy: ExpertDecisionActor,
        disposition: ExpertDispositionKind,
        dispositionID: String,
        rationale: String,
        schemaVersion: Int,
    ) {
        self.confidence = confidence
        self.correctionIDs = correctionIDs
        self.decidedAt = decidedAt
        self.decidedBy = decidedBy
        self.disposition = disposition
        self.dispositionID = dispositionID
        self.rationale = rationale
        self.schemaVersion = schemaVersion
    }

    public func validate() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              FactoryTextRules.isStableID(dispositionID),
              !correctionIDs.isEmpty,
              correctionIDs == correctionIDs.sorted(),
              Set(correctionIDs).count == correctionIDs.count,
              correctionIDs.allSatisfy(FactoryTextRules.isStableID),
              FactoryTextRules.isBoundedText(decidedAt, maximumScalars: 64),
              FactoryTextRules.isBoundedText(rationale, maximumScalars: 4096)
        else {
            throw FactoryValidationError(
                code: "invalid-expert-disposition",
                message: "Expert disposition is incomplete or ambiguous.",
            )
        }
    }
}

public enum ProductFindingStatus: String, Codable, Sendable {
    case evalTargetReady = "eval-target-ready"
    case noise
    case triageOpen = "triage-open"
    case uncertain
}

public struct ProductFinding: Codable, Equatable, Sendable {
    public let affectedSurface: String
    public let dispositionID: String
    public let evalTargetRequired: Bool
    public let evidenceRefs: [String]
    public let findingID: String
    public let recurrenceCount: Int
    public let schemaVersion: Int
    public let severity: FactoryFindingSeverity
    public let status: ProductFindingStatus

    public init(
        affectedSurface: String,
        dispositionID: String,
        evalTargetRequired: Bool,
        evidenceRefs: [String],
        findingID: String,
        recurrenceCount: Int,
        schemaVersion: Int,
        severity: FactoryFindingSeverity,
        status: ProductFindingStatus,
    ) {
        self.affectedSurface = affectedSurface
        self.dispositionID = dispositionID
        self.evalTargetRequired = evalTargetRequired
        self.evidenceRefs = evidenceRefs
        self.findingID = findingID
        self.recurrenceCount = recurrenceCount
        self.schemaVersion = schemaVersion
        self.severity = severity
        self.status = status
    }
}

public enum ProductEvalTargetStatus: String, Codable, Sendable {
    case draft
    case merged
    case rejected
}

public struct ProductEvalTarget: Codable, Equatable, Sendable {
    public let criterion: String
    public let evalTargetID: String
    public let findingID: String
    public let metric: String
    public let publicRegressionID: String
    public let schemaVersion: Int
    public let status: ProductEvalTargetStatus
    public let threshold: String

    public init(
        criterion: String,
        evalTargetID: String,
        findingID: String,
        metric: String,
        publicRegressionID: String,
        schemaVersion: Int,
        status: ProductEvalTargetStatus,
        threshold: String,
    ) {
        self.criterion = criterion
        self.evalTargetID = evalTargetID
        self.findingID = findingID
        self.metric = metric
        self.publicRegressionID = publicRegressionID
        self.schemaVersion = schemaVersion
        self.status = status
        self.threshold = threshold
    }
}

public enum ProductAdapterAuthority: String, Codable, Sendable {
    case disabledByDefault = "disabled-by-default"
    case ownerApprovedPostMerge = "owner-approved-post-merge"
}

public struct ProductAdapterPolicy: Codable, Equatable, Sendable {
    public let automaticMutation: Bool
    public let authority: ProductAdapterAuthority
    public let enabled: Bool
    public let minimumActionableRecurrence: Int
    public let retention: ProductRetentionClass
    public let schemaVersion: Int

    public init(
        automaticMutation: Bool,
        authority: ProductAdapterAuthority,
        enabled: Bool,
        minimumActionableRecurrence: Int,
        retention: ProductRetentionClass,
        schemaVersion: Int,
    ) {
        self.automaticMutation = automaticMutation
        self.authority = authority
        self.enabled = enabled
        self.minimumActionableRecurrence = minimumActionableRecurrence
        self.retention = retention
        self.schemaVersion = schemaVersion
    }

    public static func factoryV1() -> ProductAdapterPolicy {
        ProductAdapterPolicy(
            automaticMutation: false,
            authority: .disabledByDefault,
            enabled: false,
            minimumActionableRecurrence: 3,
            retention: .sanitizedDurable,
            schemaVersion: FactoryCore.schemaVersion,
        )
    }

    public func validate() throws {
        guard schemaVersion == FactoryCore.schemaVersion,
              !automaticMutation,
              (2 ... 100).contains(minimumActionableRecurrence),
              enabled == (authority == .ownerApprovedPostMerge)
        else {
            throw FactoryValidationError(
                code: "invalid-product-adapter-policy",
                message: "Product learning is owner-gated, post-merge, sanitized, and never automatically mutating.",
            )
        }
    }
}

public struct ProductClassificationInput: Codable, Equatable, Sendable {
    public let affectedSurface: String
    public let corrections: [ProductCorrection]
    public let disposition: ExpertDisposition
    public let evidenceRefs: [String]
    public let findingID: String
    public let recurrenceCount: Int
    public let severity: FactoryFindingSeverity
    public let trace: ProductTrace

    public init(
        affectedSurface: String,
        corrections: [ProductCorrection],
        disposition: ExpertDisposition,
        evidenceRefs: [String],
        findingID: String,
        recurrenceCount: Int,
        severity: FactoryFindingSeverity,
        trace: ProductTrace,
    ) {
        self.affectedSurface = affectedSurface
        self.corrections = corrections
        self.disposition = disposition
        self.evidenceRefs = evidenceRefs
        self.findingID = findingID
        self.recurrenceCount = recurrenceCount
        self.severity = severity
        self.trace = trace
    }
}

public struct ProductClassificationRequest: Codable, Equatable, Sendable {
    public let input: ProductClassificationInput
    public let policy: ProductAdapterPolicy

    public init(input: ProductClassificationInput, policy: ProductAdapterPolicy) {
        self.input = input
        self.policy = policy
    }
}

public enum ProductLearningClassifier {
    public static func classify(
        _ input: ProductClassificationInput,
        policy: ProductAdapterPolicy,
    ) throws -> ProductFinding {
        try policy.validate()
        guard policy.enabled else {
            throw FactoryValidationError(
                code: "product-adapter-disabled",
                message: "Product learning remains disabled until explicit owner-approved post-merge activation.",
            )
        }
        try input.trace.validate()
        try input.disposition.validate()
        for correction in input.corrections {
            try correction.validate()
        }

        let correctionIDs = input.corrections.map(\.correctionID)
        let inputIsBounded = FactoryTextRules.isStableID(input.findingID)
            && FactoryTextRules.isBoundedText(input.affectedSurface, maximumScalars: 256)
            && input.recurrenceCount > 0
            && input.evidenceRefs == input.evidenceRefs.sorted()
            && Set(input.evidenceRefs).count == input.evidenceRefs.count
            && !input.evidenceRefs.isEmpty
            && correctionIDs == correctionIDs.sorted()
            && Set(correctionIDs).count == correctionIDs.count
            && Set(input.disposition.correctionIDs).isSubset(of: Set(correctionIDs))
            && input.corrections.allSatisfy { $0.traceID == input.trace.traceID }
            && input.trace.source.retentionClass == policy.retention
        guard inputIsBounded else {
            throw FactoryValidationError(
                code: "invalid-product-classification",
                message: "Product classification requires sorted trace-bound corrections and sanitized evidence.",
            )
        }

        let status: ProductFindingStatus
        let requiresEval: Bool
        switch input.disposition.disposition {
        case .actionableDefect, .stablePreference:
            let actionable = input.disposition.confidence == .confirmed
                && input.recurrenceCount >= policy.minimumActionableRecurrence
            status = actionable ? .evalTargetReady : .triageOpen
            requiresEval = actionable
        case .expectedNoise, .instrumentationError:
            status = .noise
            requiresEval = false
        case .uncertain:
            status = .uncertain
            requiresEval = false
        case .unsupportedCapability:
            status = .triageOpen
            requiresEval = false
        }

        return ProductFinding(
            affectedSurface: input.affectedSurface,
            dispositionID: input.disposition.dispositionID,
            evalTargetRequired: requiresEval,
            evidenceRefs: input.evidenceRefs,
            findingID: input.findingID,
            recurrenceCount: input.recurrenceCount,
            schemaVersion: FactoryCore.schemaVersion,
            severity: input.severity,
            status: status,
        )
    }
}
