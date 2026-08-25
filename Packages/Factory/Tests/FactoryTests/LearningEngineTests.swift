import Foundation
import Testing
@testable import FactoryCore

@Suite("Controlled factory learning")
struct LearningEngineTests {
    @Test("SkillOpt is pinned for mock proof but provider calls and auto-adopt remain disabled")
    func skillOptPolicy() throws {
        let policy = try SkillOptAdapterPolicy.factoryV1()
        try policy.validate()
        #expect(policy.packageVersion == "0.2.0")
        #expect(policy.maximumEdits == 4)
        #expect(!policy.allowProviderBackends)
        #expect(!policy.automaticAdoption)
        #expect(policy.status == .buildCandidateMockOnly)

        let wrongCommit = try SkillOptAdapterPolicy(
            allowProviderBackends: false,
            automaticAdoption: false,
            maximumEdits: 4,
            package: "skillopt",
            packageVersion: "0.2.0",
            status: .buildCandidateMockOnly,
            upstreamCommit: GitObjectID(validating: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
            upstreamRepository: "https://github.com/microsoft/SkillOpt",
            uvVersion: "0.7.13",
        )
        #expect(throws: FactoryValidationError.self) {
            try wrongCommit.validate()
        }
    }

    @Test("Episodes preserve every outcome and deduplicate by immutable identity")
    func allOutcomeHarvest() throws {
        let episodes = [
            episode(id: "episode-success", outcome: .success),
            episode(id: "episode-failure", outcome: .failure),
            episode(id: "episode-blocked", outcome: .blockedOwner),
            episode(id: "episode-aborted", outcome: .abortedOperator),
        ]
        let ledger = try FactoryEpisodeLedger.harvest(episodes + [episodes[0]])
        let reorderedLedger = try FactoryEpisodeLedger.harvest(episodes.reversed())
        #expect(ledger.episodes.count == 4)
        #expect(Set(ledger.episodes.map(\.outcome)) == Set(FactoryEpisodeOutcome.allCases))
        #expect(ledger.digest == reorderedLedger.digest)
    }

    @Test("Bounded SkillOpt reflection needs attributed failures and an earlier regression")
    func boundedOptimizer() throws {
        let samples = [
            SkillOptimizationSample(
                sampleID: "sample-success",
                episodeID: "episode-success",
                targetComponentID: "skill-design-ingest-v1",
                outcome: .success,
                failureFingerprint: nil,
                proposedEdits: [],
            ),
            SkillOptimizationSample(
                sampleID: "sample-failure",
                episodeID: "episode-failure",
                targetComponentID: "skill-design-ingest-v1",
                outcome: .failure,
                failureFingerprint: "missed-video-trigger",
                proposedEdits: [
                    SkillAtomicEdit(
                        operation: .add,
                        target: "trigger-video-replication",
                        replacement: "Match supplied reference video.",
                    ),
                ],
            ),
        ]
        let candidate = try BoundedSkillOptimizer.freeze(
            candidateID: "candidate-design-ingest-v2",
            targetComponentID: "skill-design-ingest-v1",
            baselineSHA256: TestValues.contract,
            priorRegressionID: "regression-missed-video-trigger",
            samples: samples,
        )
        #expect(candidate.edits.count == 1)
        #expect(candidate.status == .frozenForEvaluation)
        #expect(candidate.maximumRevisionRounds == 1)

        #expect(throws: FactoryValidationError.self) {
            try BoundedSkillOptimizer.freeze(
                candidateID: "candidate-no-regression",
                targetComponentID: "skill-design-ingest-v1",
                baselineSHA256: TestValues.contract,
                priorRegressionID: nil,
                samples: samples,
            )
        }
    }

    @Test("Optimizer clips at four atomic edits and cannot modify its ruler")
    func optimizerScope() throws {
        let edits = (1 ... 5).map {
            SkillAtomicEdit(operation: .replace, target: "target-\($0)", replacement: "replacement-\($0)")
        }
        let samples = [
            SkillOptimizationSample(
                sampleID: "sample-success",
                episodeID: "episode-success",
                targetComponentID: "skill-one",
                outcome: .success,
                failureFingerprint: nil,
                proposedEdits: [],
            ),
            SkillOptimizationSample(
                sampleID: "sample-failure",
                episodeID: "episode-failure",
                targetComponentID: "skill-one",
                outcome: .failure,
                failureFingerprint: "failure-one",
                proposedEdits: edits,
            ),
        ]
        let candidate = try BoundedSkillOptimizer.freeze(
            candidateID: "candidate-one",
            targetComponentID: "skill-one",
            baselineSHA256: TestValues.contract,
            priorRegressionID: "regression-one",
            samples: samples,
        )
        #expect(candidate.edits.count == 4)
        #expect(!candidate.allowedPaths.contains { $0.isControlPlane })
    }

    private func episode(id: String, outcome: FactoryEpisodeOutcome) -> FactoryEpisode {
        FactoryEpisode(
            episodeID: id,
            runID: "run-42",
            headSHA: TestValues.head,
            contractSHA256: TestValues.contract,
            routeID: "route-logic",
            outcome: outcome,
            componentExposureIDs: ["prompt-builder-v1"],
            skillExposureIDs: ["design-system-v1"],
            incidentIDs: outcome == .failure ? ["incident-one"] : [],
        )
    }
}
