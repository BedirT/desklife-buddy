import Foundation

public enum FactoryControllerAuthority: String, Codable, CaseIterable, Sendable {
    case activated
    case buildCandidate = "build-candidate"
    case trustedRootInstalled = "trusted-root-installed"
}

public enum FactoryExecutionMode: String, Codable, CaseIterable, Sendable {
    case bootstrapFixture = "bootstrap-fixture"
    case production
}

public enum FactoryPlanQualification: String, Codable, CaseIterable, Sendable {
    case nonqualifyingBootstrap = "nonqualifying-bootstrap"
    case qualifying
}

/// Stable user-facing controller surface shared by `scripts/factory` and all model clients.
public enum FactoryControlOperation: String, Codable, CaseIterable, Sendable {
    case abort
    case bootstrap
    case context
    case deliver
    case designIngest = "design-ingest"
    case designInspect = "design-inspect"
    case designTranslate = "design-translate"
    case learnHarvest = "learn-harvest"
    case learnStatus = "learn-status"
    case learnTriage = "learn-triage"
    case pause
    case productIngest = "product-ingest"
    case productTriage = "product-triage"
    case prompt
    case report
    case resume
    case routeExplain = "route-explain"
    case routeResolve = "route-resolve"
    case skillAudit = "skill-audit"
    case skillGap = "skill-gap"
    case skillInventory = "skill-inventory"
    case skillResolve = "skill-resolve"
    case start
    case status
    case verify
    case workClaim = "work-claim"
    case workComplete = "work-complete"
    case workFail = "work-fail"
    case workList = "work-list"
    case workReconcile = "work-reconcile"

    public var requiresActivation: Bool {
        switch self {
        case .abort, .deliver, .pause, .resume, .start, .workClaim, .workComplete, .workFail, .workReconcile:
            true
        case .bootstrap, .context, .designIngest, .designInspect, .designTranslate, .learnHarvest, .learnStatus,
             .learnTriage, .productIngest, .productTriage, .prompt, .report, .routeExplain, .routeResolve,
             .skillAudit, .skillGap, .skillInventory, .skillResolve, .status, .verify, .workList:
            false
        }
    }
}

public enum FactoryEffectKind: String, Codable, CaseIterable, Sendable {
    case brokerTransaction = "broker-transaction"
    case checkStopToken = "check-stop-token"
    case compileContext = "compile-context"
    case deleteWorktree = "delete-worktree"
    case launchRole = "launch-role"
    case preserveState = "preserve-state"
    case renderReport = "render-report"
    case runVerification = "run-verification"
}

/// One planned effect. Only a broker transaction may cross the live side-effect boundary.
public struct FactoryPlannedEffect: Codable, Equatable, Sendable {
    public let kind: FactoryEffectKind
    public let liveSideEffect: Bool

    public init(kind: FactoryEffectKind, liveSideEffect: Bool) {
        self.kind = kind
        self.liveSideEffect = liveSideEffect
    }
}

public struct FactoryControllerPlanningInput: Codable, Equatable, Sendable {
    public let authority: FactoryControllerAuthority
    public let mode: FactoryExecutionMode
    public let runID: String
    public let issueNumber: Int
    public let headSHA: GitObjectID
    public let contractSHA256: SHA256Digest
    public let routeSHA256: SHA256Digest
    public let generation: Int
    public let stopRequested: Bool

    public init(
        authority: FactoryControllerAuthority,
        mode: FactoryExecutionMode,
        runID: String,
        issueNumber: Int,
        headSHA: GitObjectID,
        contractSHA256: SHA256Digest,
        routeSHA256: SHA256Digest,
        generation: Int,
        stopRequested: Bool,
    ) {
        self.authority = authority
        self.mode = mode
        self.runID = runID
        self.issueNumber = issueNumber
        self.headSHA = headSHA
        self.contractSHA256 = contractSHA256
        self.routeSHA256 = routeSHA256
        self.generation = generation
        self.stopRequested = stopRequested
    }

    public func validate() throws {
        guard FactoryTextRules.isStableID(runID), issueNumber > 0, generation >= 0 else {
            throw FactoryValidationError(
                code: "invalid-controller-input",
                message: "Controller planning requires an immutable run, issue, SHA, route, and generation binding.",
            )
        }
    }
}

public struct FactoryControllerPlan: Codable, Equatable, Sendable {
    public let operation: FactoryControlOperation
    public let qualification: FactoryPlanQualification
    public let runID: String
    public let headSHA: GitObjectID
    public let contractSHA256: SHA256Digest
    public let routeSHA256: SHA256Digest
    public let generation: Int
    public let effects: [FactoryPlannedEffect]

    public init(
        operation: FactoryControlOperation,
        qualification: FactoryPlanQualification,
        runID: String,
        headSHA: GitObjectID,
        contractSHA256: SHA256Digest,
        routeSHA256: SHA256Digest,
        generation: Int,
        effects: [FactoryPlannedEffect],
    ) {
        self.operation = operation
        self.qualification = qualification
        self.runID = runID
        self.headSHA = headSHA
        self.contractSHA256 = contractSHA256
        self.routeSHA256 = routeSHA256
        self.generation = generation
        self.effects = effects
    }

    public func validate() throws {
        guard effects.first?.kind == .checkStopToken,
              !effects.isEmpty,
              effects.allSatisfy({ !$0.liveSideEffect || $0.kind == .brokerTransaction }),
              qualification != .nonqualifyingBootstrap || !effects.contains(where: { $0.kind == .brokerTransaction })
        else {
            throw FactoryValidationError(
                code: "invalid-controller-plan",
                message: "Plans must check cancellation first and route every live effect through the typed broker.",
            )
        }
    }
}

public protocol FactoryControllerTransport: AnyObject {
    func execute(_ effect: FactoryPlannedEffect) throws
}

public enum FactoryController {
    public static func plan(
        operation: FactoryControlOperation,
        input: FactoryControllerPlanningInput,
    ) throws -> FactoryControllerPlan {
        try input.validate()
        if input.stopRequested, operation != .abort {
            throw FactoryValidationError(
                code: "factory-stop-requested",
                message: "The durable stop token is set; only abort may preserve and release the current run.",
            )
        }
        if input.mode == .production, operation.requiresActivation, input.authority != .activated {
            throw FactoryValidationError(
                code: "factory-inert-before-activation",
                message: "Production mutations remain inert until the exact merged trusted root is activated.",
            )
        }

        let qualifying = input.mode == .production && input.authority == .activated
        let effects = effects(for: operation, qualifying: qualifying)
        let result = FactoryControllerPlan(
            operation: operation,
            qualification: qualifying ? .qualifying : .nonqualifyingBootstrap,
            runID: input.runID,
            headSHA: input.headSHA,
            contractSHA256: input.contractSHA256,
            routeSHA256: input.routeSHA256,
            generation: input.generation,
            effects: effects,
        )
        try result.validate()
        return result
    }

    public static func execute(
        _ plan: FactoryControllerPlan,
        transport: any FactoryControllerTransport,
    ) throws {
        try plan.validate()
        for effect in plan.effects {
            try transport.execute(effect)
        }
    }

    private static func effects(
        for operation: FactoryControlOperation,
        qualifying: Bool,
    ) -> [FactoryPlannedEffect] {
        let stop = FactoryPlannedEffect(kind: .checkStopToken, liveSideEffect: false)
        let local: (FactoryEffectKind)
            -> FactoryPlannedEffect = { FactoryPlannedEffect(kind: $0, liveSideEffect: false) }
        let broker = FactoryPlannedEffect(kind: .brokerTransaction, liveSideEffect: qualifying)

        switch operation {
        case .start, .bootstrap:
            return [stop, local(.compileContext), local(.launchRole), local(.runVerification), local(.renderReport)]
        case .deliver:
            return qualifying ? [stop, broker, local(.renderReport)] : [
                stop,
                local(.preserveState),
                local(.renderReport),
            ]
        case .abort:
            return qualifying ? [stop, local(.preserveState), broker, local(.renderReport)] : [
                stop,
                local(.preserveState),
                local(.renderReport),
            ]
        case .pause, .resume, .workClaim, .workComplete, .workFail, .workReconcile:
            return qualifying ? [stop, broker, local(.renderReport)] : [
                stop,
                local(.preserveState),
                local(.renderReport),
            ]
        case .verify:
            return [stop, local(.runVerification), local(.renderReport)]
        case .context, .prompt, .designIngest, .designInspect, .designTranslate, .productIngest, .productTriage,
             .routeExplain, .routeResolve, .skillAudit, .skillGap, .skillInventory, .skillResolve:
            return [stop, local(.compileContext), local(.renderReport)]
        case .learnHarvest, .learnStatus, .learnTriage, .report, .status, .workList:
            return [stop, local(.renderReport)]
        }
    }
}
