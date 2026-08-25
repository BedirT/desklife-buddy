import Testing
@testable import FactoryCore

@Suite("Factory lifecycle CAS")
struct LifecycleTests {
    @Test("Every happy-path transition has an explicit predicate")
    func happyPath() throws {
        var state = FactoryState(
            runID: "run-1",
            phase: .new,
            resumePhase: nil,
            issueNumber: 42,
            pullRequestNumber: nil,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            generation: 0,
        )
        let steps: [(FactoryPhase, [TransitionPredicate])] = [
            (.intakeRequired, [.issueAndOutcomeExist]),
            (.planning, [.intakeRecorded]),
            (.contractNegotiation, [.productContextComplete]),
            (.readyToBuild, [.contractAcceptedByBuilderAndSkeptic]),
            (.building, [.authoritativeBuildBoundaryReady]),
            (.verifying, [.boundedSliceCommitted]),
            (.witnessing, [.deterministicEvidenceFresh]),
            (.reviewing, [.independentWitnessComplete]),
            (.prChecks, [.independentReviewClear]),
            (.readyForOwner, [.latestSHAHandoffComplete]),
            (.merged, [.ownerMerged]),
            (.retrospective, [.mergeReconciled]),
            (.complete, [.retrospectiveRecordedAndLeasesReleased]),
        ]

        for (target, predicates) in steps {
            let nextHead = target == .verifying ? TestValues.nextHead : state.head
            let nextPullRequestNumber = target == .building ? 2 : state.pullRequestNumber
            state = try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: target,
                    predicates: predicates,
                    nextContractDigest: state.contractDigest,
                    nextHead: nextHead,
                    nextPullRequestNumber: nextPullRequestNumber,
                ),
                to: state,
            )
        }

        #expect(state.phase == .complete)
        #expect(state.generation == steps.count)
    }

    @Test("Missing predicates and stale CAS fail closed")
    func failures() throws {
        let state = FactoryState.fixture()
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .intakeRequired,
                    predicates: [],
                    nextContractDigest: state.contractDigest,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }

        var stale = StateCAS(expected: state)
        stale.generation += 1
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: stale,
                    target: .intakeRequired,
                    predicates: [.issueAndOutcomeExist],
                    nextContractDigest: state.contractDigest,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }

    @Test("A commit invalidates downstream evidence")
    func commitInvalidatesEvidence() throws {
        let state = FactoryState.fixture(phase: .building, pullRequestNumber: 2)
        let next = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: state),
                target: .verifying,
                predicates: [.boundedSliceCommitted],
                nextContractDigest: state.contractDigest,
                nextHead: TestValues.nextHead,
                nextPullRequestNumber: state.pullRequestNumber,
            ),
            to: state,
        )

        #expect(next.head == TestValues.nextHead)
        #expect(next.evidenceInvalidatedAtGeneration == next.generation)
    }

    @Test("An accepted contract revision becomes the authoritative contract")
    func contractRevision() throws {
        let state = FactoryState.fixture(phase: .building, pullRequestNumber: 2)
        let next = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: state),
                target: .verifying,
                predicates: [.boundedSliceCommitted, .contractAcceptedByBuilderAndSkeptic],
                nextContractDigest: TestValues.context,
                nextHead: TestValues.nextHead,
                nextPullRequestNumber: state.pullRequestNumber,
            ),
            to: state,
        )

        #expect(next.contractDigest == TestValues.context)
        #expect(next.evidenceInvalidatedAtGeneration == next.generation)

        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .verifying,
                    predicates: [.boundedSliceCommitted],
                    nextContractDigest: TestValues.context,
                    nextHead: TestValues.nextHead,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }

    @Test("Initial contract acceptance binds the negotiated digest")
    func initialContractAcceptance() throws {
        let state = FactoryState.fixture(phase: .contractNegotiation)
        let next = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: state),
                target: .readyToBuild,
                predicates: [.contractAcceptedByBuilderAndSkeptic],
                nextContractDigest: TestValues.context,
                nextHead: TestValues.nextHead,
                nextPullRequestNumber: state.pullRequestNumber,
            ),
            to: state,
        )

        #expect(next.contractDigest == TestValues.context)
        #expect(next.head == TestValues.nextHead)
        #expect(next.evidenceInvalidatedAtGeneration == next.generation)
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .readyToBuild,
                    predicates: [.contractAcceptedByBuilderAndSkeptic],
                    nextContractDigest: TestValues.context,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }

    @Test("A repair boundary preserves the accepted contract and head")
    func repairBoundary() throws {
        let state = FactoryState.fixture(phase: .repairing, pullRequestNumber: 2)
        let next = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: state),
                target: .building,
                predicates: [.repairContractRecordedAndLeaseAvailable],
                nextContractDigest: state.contractDigest,
                nextHead: state.head,
                nextPullRequestNumber: state.pullRequestNumber,
            ),
            to: state,
        )

        #expect(next.contractDigest == state.contractDigest)
        #expect(next.head == state.head)
        #expect(next.evidenceInvalidatedAtGeneration == nil)
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .building,
                    predicates: [.repairContractRecordedAndLeaseAvailable],
                    nextContractDigest: TestValues.context,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }
}

extension LifecycleTests {
    @Test("Recovery can atomically adopt a committed bounded slice")
    func recoveredCheckpoint() throws {
        let building = FactoryState.fixture(phase: .building, pullRequestNumber: 2)
        let recovering = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: building),
                target: .recovering,
                predicates: [.liveStateDiverged],
                nextContractDigest: building.contractDigest,
                nextHead: building.head,
                nextPullRequestNumber: building.pullRequestNumber,
            ),
            to: building,
        )
        let verifying = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: recovering),
                target: .verifying,
                predicates: [.boundedSliceCommitted, .stateReconciled],
                nextContractDigest: recovering.contractDigest,
                nextHead: TestValues.nextHead,
                nextPullRequestNumber: recovering.pullRequestNumber,
            ),
            to: recovering,
        )

        #expect(verifying.phase == .verifying)
        #expect(verifying.resumePhase == nil)
        #expect(verifying.head == TestValues.nextHead)
        #expect(verifying.evidenceInvalidatedAtGeneration == verifying.generation)
    }

    @Test("Current-SHA gates reject a changed head")
    func currentSHAGatesRejectChangedHead() throws {
        let cases: [LifecycleTransitionCase] = [
            .init(.verifying, .witnessing, .deterministicEvidenceFresh),
            .init(.witnessing, .reviewing, .independentWitnessComplete),
            .init(.reviewing, .prChecks, .independentReviewClear),
            .init(.prChecks, .readyForOwner, .latestSHAHandoffComplete),
            .init(.readyForOwner, .merged, .ownerMerged),
            .init(.verifying, .repairing, .reproducibleFailureAndBudgetRemain),
            .init(.building, .recovering, .liveStateDiverged),
            .init(.building, .blockedOwner, .ownerEscalationRecorded),
            .init(.building, .pausedOperator, .operatorPauseRecorded),
            .init(.building, .abortedOperator, .operatorAbortComplete),
            .init(.building, .quarantined, .circuitBreakerFired),
            .init(.abortedOperator, .retrospective, .partialEvidenceAndLeasesReleased),
        ]

        for value in cases {
            let state = FactoryState.fixture(phase: value.phase, pullRequestNumber: 2)
            #expect(throws: FactoryValidationError.self) {
                try FactoryStateMachine.apply(
                    TransitionRequest(
                        cas: StateCAS(expected: state),
                        target: value.target,
                        predicates: [value.predicate],
                        nextContractDigest: state.contractDigest,
                        nextHead: TestValues.nextHead,
                        nextPullRequestNumber: state.pullRequestNumber,
                    ),
                    to: state,
                )
            }
        }
    }

    @Test("Only declared repository-writing edges may advance the head")
    func commitBearingEdges() throws {
        let cases: [LifecycleTransitionCase] = [
            .init(.intakeRequired, .planning, .intakeRecorded),
            .init(.planning, .contractNegotiation, .productContextComplete),
            .init(.contractNegotiation, .readyToBuild, .contractAcceptedByBuilderAndSkeptic),
            .init(.readyToBuild, .building, .authoritativeBuildBoundaryReady, nextPullRequestNumber: 2),
        ]

        for value in cases {
            let currentPullRequestNumber = value.phase == .repairing ? 2 : nil
            let state = FactoryState.fixture(
                phase: value.phase,
                pullRequestNumber: currentPullRequestNumber,
            )
            let next = try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: value.target,
                    predicates: [value.predicate],
                    nextContractDigest: state.contractDigest,
                    nextHead: TestValues.nextHead,
                    nextPullRequestNumber: value.nextPullRequestNumber,
                ),
                to: state,
            )
            #expect(next.head == TestValues.nextHead)
            #expect(next.evidenceInvalidatedAtGeneration == next.generation)
        }
    }

    @Test("Building requires a CAS-bound draft pull request")
    func buildingRequiresPullRequest() throws {
        let state = FactoryState.fixture(phase: .readyToBuild)

        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .building,
                    predicates: [.authoritativeBuildBoundaryReady],
                    nextContractDigest: state.contractDigest,
                    nextHead: state.head,
                    nextPullRequestNumber: nil,
                ),
                to: state,
            )
        }

        let building = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: state),
                target: .building,
                predicates: [.authoritativeBuildBoundaryReady],
                nextContractDigest: state.contractDigest,
                nextHead: state.head,
                nextPullRequestNumber: 2,
            ),
            to: state,
        )
        #expect(building.pullRequestNumber == 2)
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: building),
                    target: .recovering,
                    predicates: [.liveStateDiverged],
                    nextContractDigest: building.contractDigest,
                    nextHead: building.head,
                    nextPullRequestNumber: 3,
                ),
                to: building,
            )
        }
    }

    @Test("An exhausted lifecycle generation fails closed")
    func generationOverflow() {
        let state = FactoryState(
            runID: "run-1",
            phase: .new,
            resumePhase: nil,
            issueNumber: 42,
            pullRequestNumber: nil,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            generation: .max,
        )

        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .intakeRequired,
                    predicates: [.issueAndOutcomeExist],
                    nextContractDigest: state.contractDigest,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }

    @Test("Malformed durable lifecycle state fails before CAS mutation")
    func malformedState() throws {
        let state = FactoryState(
            runID: "NOT VALID",
            phase: .new,
            resumePhase: nil,
            issueNumber: 0,
            pullRequestNumber: -1,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            generation: -1,
            evidenceInvalidatedAtGeneration: 1,
        )

        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: state),
                    target: .intakeRequired,
                    predicates: [.issueAndOutcomeExist],
                    nextContractDigest: state.contractDigest,
                    nextHead: state.head,
                    nextPullRequestNumber: state.pullRequestNumber,
                ),
                to: state,
            )
        }
    }

    @Test("Suspension phases cannot overwrite the single durable resume target")
    func nestedSuspension() throws {
        let building = FactoryState.fixture(phase: .building, pullRequestNumber: 2)
        let recovering = try FactoryStateMachine.apply(
            TransitionRequest(
                cas: StateCAS(expected: building),
                target: .recovering,
                predicates: [.liveStateDiverged],
                nextContractDigest: building.contractDigest,
                nextHead: building.head,
                nextPullRequestNumber: building.pullRequestNumber,
            ),
            to: building,
        )

        #expect(recovering.resumePhase == .building)
        #expect(throws: FactoryValidationError.self) {
            try FactoryStateMachine.apply(
                TransitionRequest(
                    cas: StateCAS(expected: recovering),
                    target: .blockedOwner,
                    predicates: [.ownerEscalationRecorded],
                    nextContractDigest: recovering.contractDigest,
                    nextHead: recovering.head,
                    nextPullRequestNumber: recovering.pullRequestNumber,
                ),
                to: recovering,
            )
        }
    }

    @Test("Lifecycle CAS covers recovery and evidence invalidation fields")
    func casCoversRecoveryFields() {
        let state = FactoryState(
            runID: "run-1",
            phase: .recovering,
            resumePhase: .building,
            issueNumber: 42,
            pullRequestNumber: 2,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            generation: 2,
            evidenceInvalidatedAtGeneration: 1,
        )
        let cas = StateCAS(expected: state)
        let changedResume = FactoryState(
            runID: state.runID,
            phase: state.phase,
            resumePhase: .verifying,
            issueNumber: state.issueNumber,
            pullRequestNumber: state.pullRequestNumber,
            contractDigest: state.contractDigest,
            head: state.head,
            generation: state.generation,
            evidenceInvalidatedAtGeneration: state.evidenceInvalidatedAtGeneration,
        )
        let changedEvidence = FactoryState(
            runID: state.runID,
            phase: state.phase,
            resumePhase: state.resumePhase,
            issueNumber: state.issueNumber,
            pullRequestNumber: state.pullRequestNumber,
            contractDigest: state.contractDigest,
            head: state.head,
            generation: state.generation,
            evidenceInvalidatedAtGeneration: 2,
        )

        #expect(!cas.matches(changedResume))
        #expect(!cas.matches(changedEvidence))
    }

    @Test("Post-build durable phases reject missing pull request identity")
    func postBuildStateRequiresPullRequest() {
        let state = FactoryState.fixture(phase: .verifying)
        #expect(throws: FactoryValidationError.self) {
            try state.validateStructure()
        }
    }

    @Test("Pre-build durable phases reject a prematurely bound pull request")
    func preBuildStateRejectsPullRequest() {
        let state = FactoryState.fixture(phase: .readyToBuild, pullRequestNumber: 2)
        #expect(throws: FactoryValidationError.self) {
            try state.validateStructure()
        }
    }
}

private struct LifecycleTransitionCase {
    let phase: FactoryPhase
    let target: FactoryPhase
    let predicate: TransitionPredicate
    let nextPullRequestNumber: Int?

    init(
        _ phase: FactoryPhase,
        _ target: FactoryPhase,
        _ predicate: TransitionPredicate,
        nextPullRequestNumber: Int? = nil,
    ) {
        self.phase = phase
        self.target = target
        self.predicate = predicate
        self.nextPullRequestNumber = nextPullRequestNumber
    }
}

private extension FactoryState {
    static func fixture(
        phase: FactoryPhase = .new,
        pullRequestNumber: Int? = nil,
    ) -> FactoryState {
        FactoryState(
            runID: "run-1",
            phase: phase,
            resumePhase: nil,
            issueNumber: 42,
            pullRequestNumber: pullRequestNumber,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            generation: 0,
        )
    }
}
