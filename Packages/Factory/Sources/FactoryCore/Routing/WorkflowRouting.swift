import Foundation

/// Orthogonal change classes used to compose a workflow without choosing a model-specific mode.
public enum ChangeDimension: String, Codable, CaseIterable, Hashable, Sendable {
    case bugReproduction = "bug-reproduction"
    case controlPlane = "control-plane"
    case externalDesign = "external-design"
    case interactionFlow = "interaction-flow"
    case logic
    case motion
    case performance
    case persistence
    case privacy
    case release
    case ui
}

/// Stable roles that can be placed into a compiled factory route.
public enum WorkflowRole: String, Codable, CaseIterable, Hashable, Sendable {
    case acceptanceAuthor = "acceptance-author"
    case builder
    case codeAuditor = "code-auditor"
    case contractAuthor = "contract-author"
    case contractSkeptic = "contract-skeptic"
    case designIngestor = "design-ingestor"
    case designTranslator = "design-translator"
    case deterministicVerifier = "deterministic-verifier"
    case highRiskCouncil = "high-risk-council"
    case motionWitness = "motion-witness"
    case performanceAuditor = "performance-auditor"
    case privacyAuditor = "privacy-auditor"
    case productWitness = "product-witness"
    case prShepherd = "pr-shepherd"
    case releaseAuditor = "release-auditor"
    case repairer
}

/// Mutation authority assigned to one role invocation.
public enum WorkflowMutationMode: String, Codable, Sendable {
    case proposalOnly = "proposal-only"
    case readOnly = "read-only"
    case scratchWrite = "scratch-write"
    case trustedController = "trusted-controller"
}

/// Provider lane preference. It is a scheduling hint, never an authority grant.
public enum WorkflowModelLane: String, Codable, Sendable {
    case claude
    case codex
    case deterministic
    case independent
    case pi
}

/// Immutable authority and default-provider declaration for one workflow role.
public struct WorkflowRoleDefinition: Codable, Equatable, Sendable {
    public let role: WorkflowRole
    public let mutationMode: WorkflowMutationMode
    public let defaultModelLane: WorkflowModelLane

    public init(
        role: WorkflowRole,
        mutationMode: WorkflowMutationMode,
        defaultModelLane: WorkflowModelLane,
    ) {
        self.role = role
        self.mutationMode = mutationMode
        self.defaultModelLane = defaultModelLane
    }
}

/// Additive route requirements contributed by one change dimension.
public struct WorkflowDimensionRule: Codable, Equatable, Sendable {
    public let dimension: ChangeDimension
    public let minimumRisk: RiskTier
    public let requiredRoles: [WorkflowRole]
    public let requiredEvidenceIDs: [String]

    public init(
        dimension: ChangeDimension,
        minimumRisk: RiskTier,
        requiredRoles: [WorkflowRole],
        requiredEvidenceIDs: [String],
    ) {
        self.dimension = dimension
        self.minimumRisk = minimumRisk
        self.requiredRoles = requiredRoles
        self.requiredEvidenceIDs = requiredEvidenceIDs
    }
}

/// Frozen route ruler shared by Codex, Claude Code, and Pi.
public struct WorkflowRoutePolicy: Codable, Equatable, Sendable {
    public let policyID: String
    public let commonRoleOrder: [WorkflowRole]
    public let dimensionRules: [WorkflowDimensionRule]
    public let roleDefinitions: [WorkflowRoleDefinition]

    public init(
        policyID: String,
        commonRoleOrder: [WorkflowRole],
        dimensionRules: [WorkflowDimensionRule],
        roleDefinitions: [WorkflowRoleDefinition],
    ) {
        self.policyID = policyID
        self.commonRoleOrder = commonRoleOrder
        self.dimensionRules = dimensionRules
        self.roleDefinitions = roleDefinitions
    }

    /// The repository-owned v1 policy. Checked-in JSON must decode to this value.
    public static func factoryV1() throws -> WorkflowRoutePolicy {
        let policy = WorkflowRoutePolicy(
            policyID: "factory-route-v1",
            commonRoleOrder: factoryV1CommonRoleOrder(),
            dimensionRules: factoryV1DimensionRules(),
            roleDefinitions: factoryV1RoleDefinitions(),
        )
        try policy.validate()
        return policy
    }

    private static func factoryV1CommonRoleOrder() -> [WorkflowRole] {
        [
            .contractAuthor,
            .contractSkeptic,
            .acceptanceAuthor,
            .builder,
            .deterministicVerifier,
            .codeAuditor,
            .repairer,
            .prShepherd,
        ]
    }

    private static func factoryV1DimensionRules() -> [WorkflowDimensionRule] {
        factoryV1CoreRules() + factoryV1SpecialistRules()
    }

    private static func factoryV1CoreRules() -> [WorkflowDimensionRule] {
        [
            WorkflowDimensionRule(
                dimension: .bugReproduction,
                minimumRisk: .low,
                requiredRoles: [],
                requiredEvidenceIDs: ["red-reproduction", "regression-green"],
            ),
            WorkflowDimensionRule(
                dimension: .controlPlane,
                minimumRisk: .controlPlane,
                requiredRoles: [.highRiskCouncil],
                requiredEvidenceIDs: ["control-plane-denial-suite", "trusted-root-evaluation"],
            ),
            WorkflowDimensionRule(
                dimension: .externalDesign,
                minimumRisk: .medium,
                requiredRoles: [.designIngestor, .designTranslator, .productWitness],
                requiredEvidenceIDs: [
                    "design-source-provenance",
                    "design-translation-contract",
                    "source-implementation-comparison",
                ],
            ),
            WorkflowDimensionRule(
                dimension: .interactionFlow,
                minimumRisk: .medium,
                requiredRoles: [.productWitness],
                requiredEvidenceIDs: ["interaction-scenario", "real-app-accessibility"],
            ),
            WorkflowDimensionRule(
                dimension: .logic,
                minimumRisk: .low,
                requiredRoles: [],
                requiredEvidenceIDs: ["logic-tests"],
            ),
        ]
    }

    private static func factoryV1SpecialistRules() -> [WorkflowDimensionRule] {
        [
            WorkflowDimensionRule(
                dimension: .motion,
                minimumRisk: .medium,
                requiredRoles: [.motionWitness, .productWitness],
                requiredEvidenceIDs: ["motion-review", "reduced-motion-proof", "video-motion-decomposition"],
            ),
            WorkflowDimensionRule(
                dimension: .performance,
                minimumRisk: .medium,
                requiredRoles: [.performanceAuditor],
                requiredEvidenceIDs: ["performance-before-after"],
            ),
            WorkflowDimensionRule(
                dimension: .persistence,
                minimumRisk: .high,
                requiredRoles: [.highRiskCouncil],
                requiredEvidenceIDs: ["migration-recovery", "persistence-round-trip"],
            ),
            WorkflowDimensionRule(
                dimension: .privacy,
                minimumRisk: .high,
                requiredRoles: [.privacyAuditor, .highRiskCouncil],
                requiredEvidenceIDs: ["privacy-scope", "secret-scan"],
            ),
            WorkflowDimensionRule(
                dimension: .release,
                minimumRisk: .high,
                requiredRoles: [.releaseAuditor, .highRiskCouncil],
                requiredEvidenceIDs: ["release-preflight"],
            ),
            WorkflowDimensionRule(
                dimension: .ui,
                minimumRisk: .medium,
                requiredRoles: [.productWitness],
                requiredEvidenceIDs: ["preview-state-matrix", "real-app-accessibility", "snapshot-review"],
            ),
        ]
    }

    private static func factoryV1RoleDefinitions() -> [WorkflowRoleDefinition] {
        factoryV1CoreRoleDefinitions() + factoryV1SpecialistRoleDefinitions()
    }

    private static func factoryV1CoreRoleDefinitions() -> [WorkflowRoleDefinition] {
        [
            WorkflowRoleDefinition(
                role: .acceptanceAuthor,
                mutationMode: .proposalOnly,
                defaultModelLane: .independent,
            ),
            WorkflowRoleDefinition(role: .builder, mutationMode: .scratchWrite, defaultModelLane: .codex),
            WorkflowRoleDefinition(role: .codeAuditor, mutationMode: .readOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(role: .contractAuthor, mutationMode: .proposalOnly, defaultModelLane: .codex),
            WorkflowRoleDefinition(role: .contractSkeptic, mutationMode: .readOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(role: .designIngestor, mutationMode: .readOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(role: .designTranslator, mutationMode: .proposalOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(
                role: .deterministicVerifier,
                mutationMode: .readOnly,
                defaultModelLane: .deterministic,
            ),
        ]
    }

    private static func factoryV1SpecialistRoleDefinitions() -> [WorkflowRoleDefinition] {
        [
            WorkflowRoleDefinition(role: .highRiskCouncil, mutationMode: .readOnly, defaultModelLane: .pi),
            WorkflowRoleDefinition(role: .motionWitness, mutationMode: .readOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(
                role: .performanceAuditor,
                mutationMode: .readOnly,
                defaultModelLane: .independent,
            ),
            WorkflowRoleDefinition(role: .privacyAuditor, mutationMode: .readOnly, defaultModelLane: .independent),
            WorkflowRoleDefinition(role: .productWitness, mutationMode: .readOnly, defaultModelLane: .claude),
            WorkflowRoleDefinition(
                role: .prShepherd,
                mutationMode: .trustedController,
                defaultModelLane: .deterministic,
            ),
            WorkflowRoleDefinition(role: .releaseAuditor, mutationMode: .readOnly, defaultModelLane: .independent),
            WorkflowRoleDefinition(role: .repairer, mutationMode: .scratchWrite, defaultModelLane: .codex),
        ]
    }

    public func validate() throws {
        let ruleDimensions = dimensionRules.map(\.dimension)
        let roles = roleDefinitions.map(\.role)
        let common = Set(commonRoleOrder)
        let requiredCommon: Set<WorkflowRole> = [
            .contractAuthor, .contractSkeptic, .acceptanceAuthor, .builder,
            .deterministicVerifier, .codeAuditor, .repairer, .prShepherd,
        ]
        let scratchWriters = roleDefinitions
            .filter { $0.mutationMode == .scratchWrite }
            .map(\.role)
        guard FactoryTextRules.isStableID(policyID),
              ruleDimensions == ChangeDimension.allCases,
              Set(ruleDimensions).count == ruleDimensions.count,
              Set(roles).count == WorkflowRole.allCases.count,
              common == requiredCommon,
              commonRoleOrder.first == .contractAuthor,
              commonRoleOrder.last == .prShepherd,
              scratchWriters == [.builder, .repairer]
        else {
            throw FactoryValidationError(
                code: "invalid-route-policy",
                message: "The route policy weakens the common spine, role inventory, or writer boundary.",
            )
        }
        for rule in dimensionRules {
            guard Set(rule.requiredRoles).count == rule.requiredRoles.count,
                  rule.requiredEvidenceIDs == rule.requiredEvidenceIDs.sorted(),
                  Set(rule.requiredEvidenceIDs).count == rule.requiredEvidenceIDs.count,
                  rule.requiredEvidenceIDs.allSatisfy(FactoryTextRules.isStableID)
            else {
                throw FactoryValidationError(
                    code: "invalid-route-rule",
                    message: "A dimension rule is ambiguous or non-canonical.",
                )
            }
        }
    }
}

/// Owner-approved dimensions and concrete paths for one route decision.
public struct WorkflowRouteRequest: Codable, Equatable, Sendable {
    public let dimensions: [ChangeDimension]
    public let requestedRisk: RiskTier
    public let changedPaths: [RepositoryPath]
    public let designSourceIDs: [String]

    public init(
        dimensions: [ChangeDimension],
        requestedRisk: RiskTier,
        changedPaths: [RepositoryPath],
        designSourceIDs: [String],
    ) {
        self.dimensions = dimensions
        self.requestedRisk = requestedRisk
        self.changedPaths = changedPaths
        self.designSourceIDs = designSourceIDs
    }
}

/// One sequential role invocation in a compiled route.
public struct CompiledWorkflowStep: Codable, Equatable, Sendable {
    public let id: String
    public let role: WorkflowRole
    public let mutationMode: WorkflowMutationMode
    public let modelLane: WorkflowModelLane
    public let dependencyIDs: [String]

    public init(
        id: String,
        role: WorkflowRole,
        mutationMode: WorkflowMutationMode,
        modelLane: WorkflowModelLane,
        dependencyIDs: [String],
    ) {
        self.id = id
        self.role = role
        self.mutationMode = mutationMode
        self.modelLane = modelLane
        self.dependencyIDs = dependencyIDs
    }
}

/// Canonical execution route and evidence obligations for one accepted contract.
public struct CompiledWorkflowRoute: Codable, Equatable, Sendable {
    public let routeID: String
    public let policyID: String
    public let dimensions: [ChangeDimension]
    public let effectiveRisk: RiskTier
    public let steps: [CompiledWorkflowStep]
    public let requiredEvidenceIDs: [String]

    public init(
        routeID: String,
        policyID: String,
        dimensions: [ChangeDimension],
        effectiveRisk: RiskTier,
        steps: [CompiledWorkflowStep],
        requiredEvidenceIDs: [String],
    ) {
        self.routeID = routeID
        self.policyID = policyID
        self.dimensions = dimensions
        self.effectiveRisk = effectiveRisk
        self.steps = steps
        self.requiredEvidenceIDs = requiredEvidenceIDs
    }

    public func validatedExecutionOrder() throws -> [CompiledWorkflowStep] {
        guard !steps.isEmpty, steps.first?.dependencyIDs.isEmpty == true else {
            throw FactoryValidationError(code: "invalid-route", message: "The route has no executable root.")
        }
        for index in steps.indices.dropFirst() {
            guard steps[index].dependencyIDs == [steps[index - 1].id] else {
                throw FactoryValidationError(
                    code: "concurrent-route-authority",
                    message: "Factory v1 routes must be sequential so writer leases cannot overlap.",
                )
            }
        }
        return steps
    }
}

/// Compiles additive change dimensions into one provider-neutral role sequence.
public enum WorkflowRouteCompiler {
    public static func compile(
        _ request: WorkflowRouteRequest,
        policy: WorkflowRoutePolicy,
    ) throws -> CompiledWorkflowRoute {
        try policy.validate()
        guard !request.dimensions.isEmpty,
              request.dimensions == request.dimensions.sorted(by: { $0.rawValue < $1.rawValue }),
              Set(request.dimensions).count == request.dimensions.count,
              !request.changedPaths.isEmpty,
              request.changedPaths == request.changedPaths.sorted(by: { $0.rawValue < $1.rawValue }),
              request.designSourceIDs == request.designSourceIDs.sorted(),
              Set(request.designSourceIDs).count == request.designSourceIDs.count,
              request.designSourceIDs.allSatisfy(FactoryTextRules.isStableID)
        else {
            throw FactoryValidationError(code: "invalid-route-request", message: "The route request is non-canonical.")
        }
        if request.changedPaths.contains(where: \.isControlPlane),
           !request.dimensions.contains(.controlPlane)
        {
            throw FactoryValidationError(
                code: "route-dimension-downgrade",
                message: "A control-plane path requires the control-plane dimension.",
            )
        }
        if request.dimensions.contains(.externalDesign) != !request.designSourceIDs.isEmpty {
            throw FactoryValidationError(
                code: "design-route-binding",
                message: "External-design routes must bind at least one design source and other routes must not.",
            )
        }

        let rules = try request.dimensions.map { dimension in
            guard let rule = policy.dimensionRules.first(where: { $0.dimension == dimension }) else {
                throw FactoryValidationError(code: "missing-route-rule", message: "A dimension has no frozen rule.")
            }
            return rule
        }
        let effectiveRisk = rules.reduce(request.requestedRisk) { current, rule in
            riskRank(rule.minimumRisk) > riskRank(current) ? rule.minimumRisk : current
        }
        var orderedRoles: [WorkflowRole] = [.contractAuthor, .contractSkeptic, .acceptanceAuthor]
        insertUnique([.designIngestor, .designTranslator], from: rules, into: &orderedRoles)
        orderedRoles.append(.builder)
        orderedRoles.append(.deterministicVerifier)
        insertUnique(
            [.productWitness, .motionWitness, .performanceAuditor, .privacyAuditor, .releaseAuditor],
            from: rules,
            into: &orderedRoles,
        )
        orderedRoles.append(.codeAuditor)
        insertUnique([.highRiskCouncil], from: rules, into: &orderedRoles)
        orderedRoles.append(contentsOf: [.repairer, .prShepherd])

        let definitions = Dictionary(uniqueKeysWithValues: policy.roleDefinitions.map { ($0.role, $0) })
        var previousID: String?
        let steps = try orderedRoles.enumerated().map { index, role in
            guard let definition = definitions[role] else {
                throw FactoryValidationError(
                    code: "missing-role-definition",
                    message: "A route role has no authority definition.",
                )
            }
            let id = String(format: "step-%02d-%@", index + 1, role.rawValue)
            let step = CompiledWorkflowStep(
                id: id,
                role: role,
                mutationMode: definition.mutationMode,
                modelLane: definition.defaultModelLane,
                dependencyIDs: previousID.map { [$0] } ?? [],
            )
            previousID = id
            return step
        }
        let evidence = Set(rules.flatMap(\.requiredEvidenceIDs)).sorted()
        let route = CompiledWorkflowRoute(
            routeID: "route-" + request.dimensions.map(\.rawValue).joined(separator: "-"),
            policyID: policy.policyID,
            dimensions: request.dimensions,
            effectiveRisk: effectiveRisk,
            steps: steps,
            requiredEvidenceIDs: evidence,
        )
        _ = try route.validatedExecutionOrder()
        return route
    }

    private static func insertUnique(
        _ candidates: [WorkflowRole],
        from rules: [WorkflowDimensionRule],
        into roles: inout [WorkflowRole],
    ) {
        let required = Set(rules.flatMap(\.requiredRoles))
        roles.append(contentsOf: candidates.filter(required.contains))
    }

    private static func riskRank(_ risk: RiskTier) -> Int {
        switch risk {
        case .low: 0
        case .medium: 1
        case .high: 2
        case .controlPlane: 3
        }
    }
}
