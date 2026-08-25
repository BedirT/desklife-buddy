import enum CryptoKit.Curve25519
import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("Runner isolation contract")
struct IsolationTests {
    @Test("A complete synthetic denial proof is fixture-only until trust activation")
    func completeProof() throws {
        let isolation = makeIsolation()
        let evidence = makeEvidence()
        let result = try RunnerIsolationDoctor.validate(
            isolation,
            trustPolicy: makeTrustPolicy(for: isolation, evidence: evidence),
            evidence: evidence,
            requestedUse: .bootstrapFixture,
            now: "2026-07-11T00:30:00Z",
        )
        #expect(result == .fixtureQualified)
        #expect(throws: FactoryValidationError.self) {
            try RunnerIsolationDoctor.validate(
                isolation,
                trustPolicy: makeTrustPolicy(for: isolation, evidence: evidence),
                evidence: evidence,
                requestedUse: .liveModelWriting,
                now: "2026-07-11T00:30:00Z",
            )
        }
    }

    @Test("Live qualification requires a signed activation receipt bound to the complete proof")
    func signedActivation() throws {
        let isolation = makeIsolation(backendQualifying: true)
        let evidence = makeEvidence()
        let key = Curve25519.Signing.PrivateKey()
        let brokerIdentity = SHA256Digest.hashing(Data("installed-broker".utf8))
        let receipt = try IsolationActivationAuthority.sign(
            isolation: isolation,
            evidence: evidence,
            trustedRootSHA: TestValues.head,
            brokerIdentitySHA256: brokerIdentity,
            receiptID: "isolation-activation-1",
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T01:00:00Z",
            privateKey: key,
        )
        let policy = try IsolationActivationAuthority.verify(
            receipt,
            isolation: isolation,
            evidence: evidence,
            expectedTrustedRootSHA: TestValues.head,
            expectedBrokerIdentitySHA256: brokerIdentity,
            now: "2026-07-11T00:30:00Z",
            publicKey: key.publicKey,
        )
        #expect(try RunnerIsolationDoctor.validate(
            isolation,
            trustPolicy: policy,
            evidence: evidence,
            requestedUse: .liveModelWriting,
            now: "2026-07-11T00:30:00Z",
        ) == .liveWritingQualified)

        let wrongKey = Curve25519.Signing.PrivateKey()
        #expect(throws: FactoryValidationError.self) {
            try IsolationActivationAuthority.verify(
                receipt,
                isolation: isolation,
                evidence: evidence,
                expectedTrustedRootSHA: TestValues.head,
                expectedBrokerIdentitySHA256: brokerIdentity,
                now: "2026-07-11T00:30:00Z",
                publicKey: wrongKey.publicKey,
            )
        }
    }

    @Test("Allowed canaries, credentials, stale hashes, and provisional backends fail")
    func denialFailures() throws {
        var allowedEvidence = makeEvidence()
        allowedEvidence.probes[0].outcome = .allowed

        let credential = makeIsolation(credentialInventory: ["OPENAI_API_KEY"])
        let stale = makeIsolation(proofOverride: SHA256Digest.hashing(Data("stale".utf8)))
        let provisional = makeIsolation(backendVersion: "2.0.0")
        let uppercaseID = makeIsolation(invocationID: "Invocation-1")
        let baseline = makeIsolation()
        let wrongPolicy = makeTrustPolicy(for: baseline, evidence: makeEvidence())

        let cases = [
            (makeIsolation(), allowedEvidence, makeTrustPolicy(for: makeIsolation(), evidence: makeEvidence())),
            (credential, makeEvidence(), makeTrustPolicy(for: credential, evidence: makeEvidence())),
            (stale, makeEvidence(), makeTrustPolicy(for: stale, evidence: makeEvidence())),
            (uppercaseID, makeEvidence(), makeTrustPolicy(for: uppercaseID, evidence: makeEvidence())),
        ]
        for (isolation, evidence, policy) in cases {
            #expect(throws: FactoryValidationError.self) {
                try RunnerIsolationDoctor.validate(
                    isolation,
                    trustPolicy: policy,
                    evidence: evidence,
                    requestedUse: .bootstrapFixture,
                    now: "2026-07-11T00:30:00Z",
                )
            }
        }
        #expect(throws: FactoryValidationError.self) {
            try RunnerIsolationDoctor.validate(
                provisional,
                trustPolicy: wrongPolicy,
                evidence: makeEvidence(),
                requestedUse: .bootstrapFixture,
                now: "2026-07-11T00:30:00Z",
            )
        }
    }

    @Test("Scratch projection copies only descriptor-validated allowlisted files")
    func scratchProjection() throws {
        try withTemporaryRoots { source, destination in
            let allowed = source.appending(path: "Sources/Allowed.swift")
            let denied = source.appending(path: "Secrets/Denied.txt")
            try FileManager.default.createDirectory(
                at: allowed.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try FileManager.default.createDirectory(
                at: denied.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try Data("let value = 1\n".utf8).write(to: allowed)
            try Data("must not project".utf8).write(to: denied)
            #expect(Darwin.chmod(allowed.path, 0o644) == 0)
            #expect(Darwin.chmod(denied.path, 0o644) == 0)

            let inventory = try ScratchProjectionBuilder.build(
                ScratchProjectionPlan(
                    invocationID: "x",
                    sourceRoot: source,
                    destinationRoot: destination,
                    sourcePaths: [RepositoryPath(validating: "Sources/Allowed.swift")],
                    sourceIdentity: ScratchProjectionBuilder.sourceIdentity(at: source),
                    deniedRoots: [source.deletingLastPathComponent().appending(path: "owner-home")],
                ),
            )

            let projected = destination.appending(path: "workspace/Sources/Allowed.swift")
            #expect(try String(contentsOf: projected, encoding: .utf8) == "let value = 1\n")
            #expect(!FileManager.default
                .fileExists(atPath: destination.appending(path: "workspace/Secrets/Denied.txt").path))
            #expect(inventory.files.map(\.path.rawValue) == ["Sources/Allowed.swift"])
            #expect(inventory.files[0].sha256 == SHA256Digest.hashing(Data("let value = 1\n".utf8)))
            #expect(lstatLinkCount(projected) == 1)
            #expect(lstatMode(destination.appending(path: "context")) == 0o500)
            #expect(lstatMode(destination.appending(path: "skills")) == 0o500)
            #expect(lstatMode(destination.appending(path: "dependencies")) == 0o500)
            #expect(lstatMode(destination.appending(path: "output")) == 0o700)
        }
    }
}

extension IsolationTests {
    private func makeIsolation(
        backendQualifying: Bool = false,
        backendVersion: String = "1.0.0",
        credentialInventory: [String] = [],
        invocationID: String = "invocation-1",
        proofOverride: SHA256Digest? = nil,
    ) -> RunnerIsolation {
        let projection = SHA256Digest.hashing(Data("projection".utf8))
        let policy = SHA256Digest.hashing(Data("policy".utf8))
        let client = SHA256Digest.hashing(Data("client".utf8))
        let canaries = SHA256Digest.hashing(Data("canaries".utf8))
        let evidence = makeEvidence()
        let provisional = RunnerIsolation(
            allowedRoots: ["dependencies", "projection", "workspace"],
            backend: IsolationBackend(id: "fixture-native", qualifying: backendQualifying, version: backendVersion),
            credentialInventory: credentialInventory,
            deniedRootClasses: DeniedRootClass.allCases.sorted(by: { $0.rawValue < $1.rawValue }),
            doctorProof: IsolationDoctorProof(
                canarySetSHA256: canaries,
                clientID: .codex,
                clientVersion: "1.0.0",
                expiresAt: "2026-07-11T01:00:00Z",
                osBuild: "25F80",
                passedAt: "2026-07-11T00:00:00Z",
                proofSHA256: TestValues.evidence,
            ),
            environmentKeys: ["DEVELOPER_DIR", "HOME", "LANG", "PATH", "TMPDIR"],
            invocationID: invocationID,
            network: NetworkPolicy(exceptions: [], mode: .denyAll),
            policySHA256: policy,
            process: RunnerProcessIdentity(
                launchIdentitySHA256: TestValues.context,
                pid: 1234,
                processGroupID: 1234,
            ),
            projectionSHA256: projection,
            resources: ResourceCeilings(
                cpuSeconds: 60,
                diskBytes: 1_073_741_824,
                memoryBytes: 1_073_741_824,
                openFiles: 256,
                outputBytes: 1_048_576,
                processes: 64,
                tokens: 8192,
                wallSeconds: 120,
            ),
            runner: RunnerIdentity(account: "factory-runner", executableSHA256: client, gid: 501, uid: 501),
        )
        let proofSHA256 = proofOverride ?? RunnerIsolationDoctor.proofSHA256(for: provisional, evidence: evidence)
        return RunnerIsolation(
            allowedRoots: provisional.allowedRoots,
            backend: provisional.backend,
            credentialInventory: provisional.credentialInventory,
            deniedRootClasses: provisional.deniedRootClasses,
            doctorProof: IsolationDoctorProof(
                canarySetSHA256: provisional.doctorProof.canarySetSHA256,
                clientID: provisional.doctorProof.clientID,
                clientVersion: provisional.doctorProof.clientVersion,
                expiresAt: provisional.doctorProof.expiresAt,
                osBuild: provisional.doctorProof.osBuild,
                passedAt: provisional.doctorProof.passedAt,
                proofSHA256: proofSHA256,
            ),
            environmentKeys: provisional.environmentKeys,
            invocationID: provisional.invocationID,
            network: provisional.network,
            policySHA256: provisional.policySHA256,
            process: provisional.process,
            projectionSHA256: provisional.projectionSHA256,
            resources: provisional.resources,
            runner: provisional.runner,
        )
    }

    private func makeTrustPolicy(
        for isolation: RunnerIsolation,
        evidence: IsolationDoctorEvidence,
    ) -> IsolationTrustPolicy {
        IsolationTrustPolicy.buildCandidateFixture(for: isolation, evidence: evidence)
    }

    private func makeEvidence() -> IsolationDoctorEvidence {
        let probes = IsolationProbeKind.allCases.flatMap { kind in
            IsolationProbeSubject.allCases.map { subject in
                IsolationProbeResult(
                    kind: kind,
                    subject: subject,
                    outcome: kind == .processCleanup ? .terminated : .denied,
                )
            }
        }
        .sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            return lhs.subject.rawValue < rhs.subject.rawValue
        }
        return IsolationDoctorEvidence(probes: probes)
    }

    func withTemporaryRoots(_ body: (URL, URL) throws -> Void) throws {
        let base = FileManager.default.temporaryDirectory
            .appending(path: "factory-isolation-\(UUID().uuidString)", directoryHint: .isDirectory)
        let source = base.appending(path: "source", directoryHint: .isDirectory)
        let destination = base.appending(path: "projection", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        try body(source, destination)
    }

    private func lstatLinkCount(_ url: URL) -> UInt16 {
        var metadata = stat()
        guard Darwin.lstat(url.path, &metadata) == 0 else { return 0 }
        return metadata.st_nlink
    }

    private func lstatMode(_ url: URL) -> mode_t {
        var metadata = stat()
        guard Darwin.lstat(url.path, &metadata) == 0 else { return 0 }
        return metadata.st_mode & 0o777
    }
}
