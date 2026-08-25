import enum CryptoKit.Curve25519
import Darwin
import Foundation
import Testing
@testable import FactoryCore

@Suite("Durable broker CAS store")
struct BrokerCASStoreTests {
    @Test("Genesis rejects a pull request number above the signed policy ceiling")
    func genesisPullRequestBound() throws {
        try withRoot { root in
            let policy = brokerPolicy()
            let initial = brokerState(
                policy: policy,
                pullRequestNumber: policy.maximumPullRequestNumber + 1,
            )

            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.initialize(at: root, state: initial, policy: policy)
            }
        }
    }

    @Test("One same-generation request wins and replay remains rejected after reload")
    func durableCASAndReplay() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            let initial = brokerState()
            try BrokerCASStore.initialize(at: root, state: initial, policy: brokerPolicy())

            let winner = request(
                state: initial,
                requestID: "request-winner",
                nonce: "nonce-winner-0123456789abcdef0123",
            )
            let winnerTransition = try audit(request: winner, state: initial, key: key)
            let winnerAudit = winnerTransition.entry
            let advanced = winnerTransition.nextState
            let response = try BrokerCASStore.compareAndSwap(
                at: root,
                request: winner,
                policy: brokerPolicy(),
                nextState: advanced,
                auditEntry: winnerAudit,
                auditPublicKey: key.publicKey,
                now: "2026-07-11T00:00:30Z",
            )
            #expect(response.auditSHA256 == winnerAudit.entrySHA256)

            let competing = request(
                state: initial,
                requestID: "request-competing",
                nonce: "nonce-competing-0123456789abcdef",
            )
            let competingTransition = try audit(request: competing, state: initial, key: key)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: competing,
                    policy: brokerPolicy(),
                    nextState: competingTransition.nextState,
                    auditEntry: competingTransition.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }

            let replay = request(
                state: advanced,
                requestID: "request-replay",
                nonce: winner.nonce,
            )
            let replayTransition = try audit(request: replay, state: advanced, key: key)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: replay,
                    policy: brokerPolicy(),
                    nextState: replayTransition.nextState,
                    auditEntry: replayTransition.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }

            let snapshot = try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            #expect(snapshot.state == advanced)
            #expect(snapshot.consumedNonceCount == 1)
            #expect(snapshot.auditEntries == [winnerAudit])
        }
    }

    @Test("Consumed broker nonces cannot be deleted or replaced outside the signed audit chain")
    func nonceLedgerTampering() throws {
        for replacement in [[], [TestValues.context.rawValue]] {
            try withRoot { root in
                let key = Curve25519.Signing.PrivateKey()
                let initial = brokerState()
                try BrokerCASStore.initialize(at: root, state: initial, policy: brokerPolicy())
                let value = request(
                    state: initial,
                    requestID: "request-nonce-binding",
                    nonce: "nonce-binding-0123456789abcdef012",
                )
                let transition = try audit(request: value, state: initial, key: key)
                _ = try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: value,
                    policy: brokerPolicy(),
                    nextState: transition.nextState,
                    auditEntry: transition.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )

                let stateURL = root.appending(path: "broker-state.json")
                let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: stateURL))
                var document = try #require(raw as? [String: Any])
                document["consumed_nonce_sha256"] = replacement
                try JSONSerialization.data(
                    withJSONObject: document,
                    options: [.sortedKeys, .withoutEscapingSlashes],
                ).write(to: stateURL)
                #expect(Darwin.chmod(stateURL.path, 0o600) == 0)

                do {
                    _ = try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
                    Issue.record("Expected the unsigned nonce cache to match the signed audit chain")
                } catch let error as FactoryValidationError {
                    #expect(error.code == "invalid_broker_state")
                }
            }
        }
    }

    @Test("Only an owner-signed trusted root receipt activates durable mutating authority")
    func signedActivation() throws {
        try withRoot { root in
            let auditKey = Curve25519.Signing.PrivateKey()
            let policy = brokerPolicy(allowedOperationKinds: [.doctor, .pushAgentBranch])
            let initial = brokerState(policy: policy)
            try BrokerCASStore.initialize(at: root, state: initial, policy: policy)

            let pushBeforeActivation = BrokerRequest(
                requestID: "push-before-activation",
                nonce: "nonce-before-activation-0123456789",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T00:01:00Z",
                trustedBaseSHA: TestValues.head,
                runID: initial.runID,
                operation: .pushAgentBranch(branch: "agent/42-evolution"),
                precondition: BrokerPrecondition(expected: initial),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerRequestValidator.validate(
                    pushBeforeActivation,
                    policy: policy,
                    state: initial,
                    replayLedger: BrokerReplayLedger(),
                    now: "2026-07-11T00:00:30Z",
                )
            }

            let callerRootedReceipt = try BrokerActivationAuthority.sign(
                policy: policy,
                state: initial,
                input: activationSigningInput(
                    auditPublicKey: auditKey.publicKey,
                    receiptID: "caller-rooted-activation",
                    signingKeyID: "caller-key",
                ),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.activate(
                    at: root,
                    anchor: trustAnchor(root: root),
                    receipt: callerRootedReceipt,
                    now: "2026-07-11T00:30:00Z",
                )
            }

            let receipt = try BrokerActivationAuthority.sign(
                policy: policy,
                state: initial,
                input: activationSigningInput(
                    auditPublicKey: auditKey.publicKey,
                    receiptID: "broker-activation-1",
                    signingKeyID: "owner-trusted-root-key",
                ),
            )
            let activated = try BrokerCASStore.activate(
                at: root,
                anchor: trustAnchor(root: root),
                receipt: receipt,
                now: "2026-07-11T00:30:00Z",
            )
            #expect(activated.isActivated)
            #expect(activated.activationReceiptSHA256 == receipt.digest)
            #expect(activated.state.generation == initial.generation + 1)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.activate(
                    at: root,
                    anchor: trustAnchor(root: root),
                    receipt: receipt,
                    now: "2026-07-11T00:30:00Z",
                )
            }

            let push = BrokerRequest(
                requestID: "push-after-activation",
                nonce: "nonce-after-activation-01234567890",
                issuedAt: "2026-07-11T00:30:00Z",
                expiresAt: "2026-07-11T00:31:00Z",
                trustedBaseSHA: TestValues.head,
                runID: activated.state.runID,
                operation: .pushAgentBranch(branch: "agent/42-evolution"),
                precondition: BrokerPrecondition(expected: activated.state),
            )
            let signedTransition = try audit(request: push, state: activated.state, key: auditKey)
            _ = try BrokerCASStore.compareAndSwap(
                at: root,
                request: push,
                policy: policy,
                nextState: signedTransition.nextState,
                auditEntry: signedTransition.entry,
                auditPublicKey: auditKey.publicKey,
                now: "2026-07-11T00:30:30Z",
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: Curve25519.Signing.PrivateKey().publicKey)
            }
        }
    }
}

extension BrokerCASStoreTests {
    private func activationSigningInput(
        auditPublicKey: Curve25519.Signing.PublicKey,
        receiptID: String,
        signingKeyID: String,
    ) -> BrokerActivationSigningInput {
        BrokerActivationSigningInput(
            auditPublicKey: auditPublicKey,
            isolationProofSHA256: TestValues.evidence,
            evaluatorProofSHA256: TestValues.context,
            selectionEpochSHA256: TestValues.tree,
            sealedEpochSHA256: TestValues.contract,
            receiptID: receiptID,
            signingKeyID: signingKeyID,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T01:00:00Z",
            privateKey: TestValues.activationPrivateKey,
        )
    }

    @Test("An activation anchor cannot authorize an alternate state root")
    func alternateActivationRoot() throws {
        let first = TestValues.temporaryDirectory
            .appending(path: "factory-broker-primary-\(UUID().uuidString)", directoryHint: .isDirectory)
        let alternate = TestValues.temporaryDirectory
            .appending(path: "factory-broker-alternate-\(UUID().uuidString)", directoryHint: .isDirectory)
        for root in [first, alternate] {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
            #expect(Darwin.chmod(root.path, 0o700) == 0)
        }
        defer {
            try? FileManager.default.removeItem(at: first)
            try? FileManager.default.removeItem(at: alternate)
        }
        let policy = brokerPolicy(allowedOperationKinds: [.doctor, .pushAgentBranch])
        let initial = brokerState(policy: policy)
        try BrokerCASStore.initialize(at: alternate, state: initial, policy: policy)
        let receipt = try BrokerActivationAuthority.sign(
            policy: policy,
            state: initial,
            input: BrokerActivationSigningInput(
                auditPublicKey: TestValues.auditPrivateKey.publicKey,
                isolationProofSHA256: TestValues.evidence,
                evaluatorProofSHA256: TestValues.context,
                selectionEpochSHA256: TestValues.tree,
                sealedEpochSHA256: TestValues.contract,
                receiptID: "alternate-root-activation",
                signingKeyID: "owner-trusted-root-key",
                issuedAt: "2026-07-11T00:00:00Z",
                expiresAt: "2026-07-11T01:00:00Z",
                privateKey: TestValues.activationPrivateKey,
            ),
        )

        #expect(throws: FactoryValidationError.self) {
            try BrokerCASStore.activate(
                at: alternate,
                anchor: trustAnchor(root: first),
                receipt: receipt,
                now: "2026-07-11T00:30:00Z",
            )
        }
    }

    @Test("An installed receipt cannot authenticate caller-edited broker state")
    func forgedActivatedState() throws {
        try withRoot { root in
            let policy = brokerPolicy(allowedOperationKinds: [.doctor, .pushAgentBranch])
            let initial = brokerState(policy: policy)
            try BrokerCASStore.initialize(at: root, state: initial, policy: policy)
            let receipt = try BrokerActivationAuthority.sign(
                policy: policy,
                state: initial,
                input: BrokerActivationSigningInput(
                    auditPublicKey: TestValues.auditPrivateKey.publicKey,
                    isolationProofSHA256: TestValues.evidence,
                    evaluatorProofSHA256: TestValues.context,
                    selectionEpochSHA256: TestValues.tree,
                    sealedEpochSHA256: TestValues.contract,
                    receiptID: "broker-activation-forgery",
                    signingKeyID: "owner-trusted-root-key",
                    issuedAt: "2026-07-11T00:00:00Z",
                    expiresAt: "2026-07-11T01:00:00Z",
                    privateKey: TestValues.activationPrivateKey,
                ),
            )
            _ = try BrokerCASStore.activate(
                at: root,
                anchor: trustAnchor(root: root),
                receipt: receipt,
                now: "2026-07-11T00:30:00Z",
            )

            let stateURL = root.appending(path: "broker-state.json")
            let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: stateURL))
            var document = try #require(raw as? [String: Any])
            var state = try #require(document["state"] as? [String: Any])
            state["generation"] = 99
            state["head"] = TestValues.nextHead.rawValue
            state["tree"] = TestValues.nextHead.rawValue
            document["state"] = state
            try JSONSerialization.data(
                withJSONObject: document,
                options: [.sortedKeys, .withoutEscapingSlashes],
            ).write(to: stateURL)
            #expect(Darwin.chmod(stateURL.path, 0o600) == 0)

            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: TestValues.auditPrivateKey.publicKey)
            }
        }
    }

    @Test("Activation generation overflow leaves durable state unchanged")
    func activationGenerationOverflow() throws {
        try withRoot { root in
            let auditKey = Curve25519.Signing.PrivateKey()
            let policy = brokerPolicy(allowedOperationKinds: [.doctor, .pushAgentBranch])
            let initial = brokerState(policy: policy, generation: Int.max)
            try BrokerCASStore.initialize(at: root, state: initial, policy: policy)
            let stateURL = root.appending(path: "broker-state.json")
            let original = try Data(contentsOf: stateURL)
            let receipt = try BrokerActivationAuthority.sign(
                policy: policy,
                state: initial,
                input: BrokerActivationSigningInput(
                    auditPublicKey: auditKey.publicKey,
                    isolationProofSHA256: TestValues.evidence,
                    evaluatorProofSHA256: TestValues.context,
                    selectionEpochSHA256: TestValues.tree,
                    sealedEpochSHA256: TestValues.contract,
                    receiptID: "broker-activation-overflow",
                    signingKeyID: "owner-trusted-root-key",
                    issuedAt: "2026-07-11T00:00:00Z",
                    expiresAt: "2026-07-11T01:00:00Z",
                    privateKey: TestValues.activationPrivateKey,
                ),
            )

            do {
                _ = try BrokerCASStore.activate(
                    at: root,
                    anchor: trustAnchor(root: root),
                    receipt: receipt,
                    now: "2026-07-11T00:30:00Z",
                )
                Issue.record("Expected exhausted broker generation to reject activation")
            } catch let error as FactoryValidationError {
                #expect(error.code == "broker_generation_overflow")
            }
            #expect(try Data(contentsOf: stateURL) == original)
        }
    }

    @Test("Durable state reads reject files above the fixed byte ceiling")
    func oversizedStateRead() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            let stateURL = root.appending(path: "broker-state.json")
            let handle = try FileHandle(forWritingTo: stateURL)
            try handle.truncate(atOffset: UInt64(16 * 1024 * 1024 + 1))
            try handle.close()

            do {
                _ = try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
                Issue.record("Expected oversized broker state to reject before decoding")
            } catch let error as FactoryValidationError {
                #expect(error.code == "broker_state_budget")
            }
        }
    }

    @Test("Create-PR binds one policy-bounded PR identity exactly once")
    func createPRBinding() throws {
        let policy = brokerPolicy(allowedOperationKinds: [.doctor, .githubTransaction])
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            let initial = brokerState(policy: policy, pullRequestNumber: nil)
            let current = try activate(root: root, initial: initial, policy: policy, auditKey: key)
            let create = request(
                state: current,
                requestID: "request-create-pr",
                nonce: "nonce-create-pr-0123456789abcdef012",
                operation: .githubTransaction(
                    BrokerGitHubTransaction(
                        transaction: .createPR,
                        bodySHA256: TestValues.context,
                        issueNumber: current.issueNumber,
                        prNumber: nil,
                    ),
                ),
            )
            let binding = try audit(
                request: create,
                state: current,
                key: key,
                pullRequestNumber: .some(2),
            )
            _ = try BrokerCASStore.compareAndSwap(
                at: root,
                request: create,
                policy: policy,
                nextState: binding.nextState,
                auditEntry: binding.entry,
                auditPublicKey: key.publicKey,
                now: "2026-07-11T00:00:30Z",
            )
            #expect(try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey).state.pullRequestNumber == 2)

            let rebind = request(
                state: binding.nextState,
                requestID: "request-rebind-pr",
                nonce: "nonce-rebind-pr-0123456789abcdef01",
                operation: create.operation,
            )
            let rebound = try audit(
                request: rebind,
                state: binding.nextState,
                key: key,
                pullRequestNumber: .some(3),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: rebind,
                    policy: policy,
                    nextState: rebound.nextState,
                    auditEntry: rebound.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }

            let clear = request(
                state: binding.nextState,
                requestID: "request-clear-pr",
                nonce: "nonce-clear-pr-0123456789abcdef012",
            )
            let cleared = try audit(
                request: clear,
                state: binding.nextState,
                key: key,
                pullRequestNumber: .some(nil),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: clear,
                    policy: policy,
                    nextState: cleared.nextState,
                    auditEntry: cleared.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }
    }

    @Test("Create-PR rejects a pull request number above the signed policy ceiling")
    func createPRBindingPolicyBound() throws {
        let policy = brokerPolicy(allowedOperationKinds: [.doctor, .githubTransaction])
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            let initial = brokerState(policy: policy, pullRequestNumber: nil)
            let current = try activate(root: root, initial: initial, policy: policy, auditKey: key)
            let create = request(
                state: current,
                requestID: "request-create-pr-overflow",
                nonce: "nonce-create-pr-overflow-012345678901",
                operation: .githubTransaction(
                    BrokerGitHubTransaction(
                        transaction: .createPR,
                        bodySHA256: TestValues.context,
                        issueNumber: current.issueNumber,
                        prNumber: nil,
                    ),
                ),
            )
            let oversized = try audit(
                request: create,
                state: current,
                key: key,
                pullRequestNumber: .some(policy.maximumPullRequestNumber + 1),
            )
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: create,
                    policy: policy,
                    nextState: oversized.nextState,
                    auditEntry: oversized.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }
        }
    }

    @Test("Patch import and checkpoint commit have disjoint Git identity effects")
    func gitIdentityTransitions() throws {
        let policy = brokerPolicy(allowedOperationKinds: [.commitCheckpoint, .importPatch])

        func verify(
            id: String,
            operation: BrokerOperation,
            head: GitObjectID?,
            tree: GitObjectID?,
            accepted: Bool,
        ) throws {
            try withRoot { root in
                let key = Curve25519.Signing.PrivateKey()
                let initial = brokerState(policy: policy)
                let current = try activate(root: root, initial: initial, policy: policy, auditKey: key)
                let value = request(
                    state: current,
                    requestID: "request-\(id)",
                    nonce: "nonce-\(id)-0123456789abcdef012345",
                    operation: operation,
                )
                let transition = try audit(
                    request: value,
                    state: current,
                    key: key,
                    head: head,
                    tree: tree,
                )
                if accepted {
                    _ = try BrokerCASStore.compareAndSwap(
                        at: root,
                        request: value,
                        policy: policy,
                        nextState: transition.nextState,
                        auditEntry: transition.entry,
                        auditPublicKey: key.publicKey,
                        now: "2026-07-11T00:00:30Z",
                    )
                } else {
                    #expect(throws: FactoryValidationError.self) {
                        try BrokerCASStore.compareAndSwap(
                            at: root,
                            request: value,
                            policy: policy,
                            nextState: transition.nextState,
                            auditEntry: transition.entry,
                            auditPublicKey: key.publicKey,
                            now: "2026-07-11T00:00:30Z",
                        )
                    }
                }
            }
        }

        try verify(
            id: "import-same-tree",
            operation: .importPatch(envelopeSHA256: TestValues.evidence),
            head: nil,
            tree: nil,
            accepted: false,
        )
        try verify(
            id: "import-new-tree",
            operation: .importPatch(envelopeSHA256: TestValues.evidence),
            head: nil,
            tree: TestValues.nextHead,
            accepted: true,
        )
        try verify(
            id: "checkpoint-new-tree",
            operation: .commitCheckpoint(messageSHA256: TestValues.context),
            head: TestValues.nextHead,
            tree: TestValues.nextHead,
            accepted: false,
        )
        try verify(
            id: "checkpoint-preserved-tree",
            operation: .commitCheckpoint(messageSHA256: TestValues.context),
            head: TestValues.nextHead,
            tree: nil,
            accepted: true,
        )
    }

    @Test("Broker lock identity remains installed for the full protected operation")
    func lockReplacementDuringOperation() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            let lock = root.appending(path: "broker.lock")
            let displaced = root.appending(path: "broker.lock.displaced")

            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(
                    at: root,
                    publicKey: key.publicKey,
                    afterLockAcquisition: {
                        #expect(Darwin.rename(lock.path, displaced.path) == 0)
                        try Data().write(to: lock, options: .withoutOverwriting)
                        #expect(Darwin.chmod(lock.path, 0o600) == 0)
                    },
                )
            }
        }
    }

    @Test("Invalid transitions and signatures leave durable bytes unchanged")
    func rejectedMutationIsAtomic() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            let otherKey = Curve25519.Signing.PrivateKey()
            let initial = brokerState()
            try BrokerCASStore.initialize(at: root, state: initial, policy: brokerPolicy())
            let stateURL = root.appending(path: "broker-state.json")
            let original = try Data(contentsOf: stateURL)
            let value = request(
                state: initial,
                requestID: "request-atomic",
                nonce: "nonce-atomic-0123456789abcdef012",
            )
            let invalidTransition = try audit(
                request: value,
                state: initial,
                key: key,
                head: TestValues.nextHead,
            )

            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: value,
                    policy: brokerPolicy(),
                    nextState: invalidTransition.nextState,
                    auditEntry: invalidTransition.entry,
                    auditPublicKey: key.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }
            #expect(try Data(contentsOf: stateURL) == original)

            let validTransition = try audit(request: value, state: initial, key: key)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.compareAndSwap(
                    at: root,
                    request: value,
                    policy: brokerPolicy(),
                    nextState: validTransition.nextState,
                    auditEntry: validTransition.entry,
                    auditPublicKey: otherKey.publicKey,
                    now: "2026-07-11T00:00:30Z",
                )
            }
            #expect(try Data(contentsOf: stateURL) == original)
        }
    }

    @Test("State roots, links, and modes fail closed")
    func filesystemDenials() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            let state = root.appending(path: "broker-state.json")
            let linked = root.appending(path: "broker-state-linked.json")
            #expect(Darwin.link(state.path, linked.path) == 0)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            }
            #expect(Darwin.unlink(linked.path) == 0)
            #expect(Darwin.chmod(state.path, 0o644) == 0)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            }
        }

        let parent = FileManager.default.temporaryDirectory
            .appending(path: "factory-broker-link-\(UUID().uuidString)", directoryHint: .isDirectory)
        let target = parent.appending(path: "target", directoryHint: .isDirectory)
        let linkedRoot = parent.appending(path: "linked", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        #expect(Darwin.chmod(target.path, 0o700) == 0)
        try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: target)
        defer { try? FileManager.default.removeItem(at: parent) }
        #expect(throws: FactoryValidationError.self) {
            try BrokerCASStore.initialize(at: linkedRoot, state: brokerState(), policy: brokerPolicy())
        }
    }

    @Test("Broker roots, state, and lock files reject extended ACL authority")
    func accessControlDenials() throws {
        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            try addBrokerAccessControl("everyone allow add_file,delete_child", to: root)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            }
        }

        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            try addBrokerAccessControl("everyone allow write", to: root.appending(path: "broker-state.json"))
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            }
        }

        try withRoot { root in
            let key = Curve25519.Signing.PrivateKey()
            try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            try addBrokerAccessControl("everyone allow write", to: root.appending(path: "broker.lock"))
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.snapshot(at: root, publicKey: key.publicKey)
            }
        }

        try withRoot { root in
            let temporary = root.appending(path: ".broker-state.tmp")
            try Data("untrusted temporary\n".utf8).write(to: temporary)
            #expect(Darwin.chmod(temporary.path, 0o600) == 0)
            try addBrokerAccessControl("everyone allow write", to: temporary)
            #expect(throws: FactoryValidationError.self) {
                try BrokerCASStore.initialize(at: root, state: brokerState(), policy: brokerPolicy())
            }
        }
    }

    private func withRoot(_ body: (URL) throws -> Void) throws {
        let root = TestValues.temporaryDirectory
            .appending(path: "factory-broker-cas-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        #expect(Darwin.chmod(root.path, 0o700) == 0)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(root)
    }

    private func addBrokerAccessControl(_ rule: String, to url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+a", rule, url.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw FactoryValidationError(
                code: "test_fixture_acl",
                message: "Could not install the broker ACL denial fixture.",
            )
        }
    }

    private func brokerState(
        policy: BrokerPolicy? = nil,
        generation: Int = 1,
        pullRequestNumber: Int? = 2,
        tree: GitObjectID = TestValues.head,
    ) -> BrokerState {
        let policy = policy ?? brokerPolicy()
        return BrokerState(
            runID: "run-1",
            issueNumber: 42,
            pullRequestNumber: pullRequestNumber,
            contractDigest: TestValues.contract,
            head: TestValues.head,
            tree: tree,
            generation: generation,
            leaseID: "lease-0123456789abcdef",
            policyDigest: policy.digest,
            priorAuditSequence: 0,
            priorAuditDigest: TestValues.zero,
        )
    }

    private func trustAnchor(root: URL) -> BrokerTrustAnchor {
        TestValues.trustAnchor(
            brokerStateRoot: root,
            evaluationScaffoldRoot: root.deletingLastPathComponent()
                .appending(path: root.lastPathComponent + "-private-eval", directoryHint: .isDirectory),
            manifest: TestValues.evaluationManifest(),
        )
    }

    private func brokerPolicy(
        allowedOperationKinds: [BrokerOperationKind] = [.doctor],
    ) -> BrokerPolicy {
        BrokerPolicy(
            activationPublicKeySHA256: TestValues.activationPublicKeySHA256,
            trustedBase: TestValues.head,
            repository: "BedirT/swiftmac-base",
            branchPrefix: "agent/",
            brokerIdentitySHA256: TestValues.brokerIdentity,
            maximumPullRequestNumber: 1_000_000_000,
            maximumRequestLifetimeSeconds: 300,
            maximumReplayEntries: 10000,
            allowedOperationKinds: allowedOperationKinds,
            allowedProjectionRoots: [TestValues.packages],
            allowedClients: [.codex],
            allowedRoleIDs: ["builder"],
            allowedGateIDs: ["test-domain"],
            allowedDoctorIDs: ["isolation"],
        )
    }

    private func request(
        state: BrokerState,
        requestID: String,
        nonce: String,
        operation: BrokerOperation = .doctor(doctorID: "isolation"),
    ) -> BrokerRequest {
        BrokerRequest(
            requestID: requestID,
            nonce: nonce,
            issuedAt: "2026-07-11T00:00:00Z",
            expiresAt: "2026-07-11T00:01:00Z",
            trustedBaseSHA: TestValues.head,
            runID: state.runID,
            operation: operation,
            precondition: BrokerPrecondition(expected: state),
        )
    }

    private func activate(
        root: URL,
        initial: BrokerState,
        policy: BrokerPolicy,
        auditKey: Curve25519.Signing.PrivateKey,
    ) throws -> BrokerState {
        try BrokerCASStore.initialize(at: root, state: initial, policy: policy)
        let receipt = try BrokerActivationAuthority.sign(
            policy: policy,
            state: initial,
            input: activationSigningInput(
                auditPublicKey: auditKey.publicKey,
                receiptID: "broker-cas-test-activation",
                signingKeyID: "owner-trusted-root-key",
            ),
        )
        return try BrokerCASStore.activate(
            at: root,
            anchor: trustAnchor(root: root),
            receipt: receipt,
            now: "2026-07-11T00:00:15Z",
        ).state
    }

    private func audit(
        request: BrokerRequest,
        state: BrokerState,
        key: Curve25519.Signing.PrivateKey,
        head: GitObjectID? = nil,
        tree: GitObjectID? = nil,
        pullRequestNumber: Int?? = nil,
    ) throws -> BrokerSignedAuditTransition {
        try BrokerAuditChain.sign(
            timestamp: "2026-07-11T00:00:30Z",
            brokerIdentitySHA256: TestValues.brokerIdentity,
            request: request,
            decision: .accepted,
            reasonCode: "policy-valid",
            resultSHA256: TestValues.evidence,
            nextState: { sequence, digest in
                self.nextState(
                    from: state,
                    sequence: sequence,
                    auditSHA256: digest,
                    head: head,
                    tree: tree,
                    pullRequestNumber: pullRequestNumber,
                )
            },
            privateKey: key,
        )
    }

    private func nextState(
        from state: BrokerState,
        sequence: Int,
        auditSHA256: SHA256Digest,
        head: GitObjectID? = nil,
        tree: GitObjectID? = nil,
        pullRequestNumber: Int?? = nil,
    ) -> BrokerState {
        BrokerState(
            runID: state.runID,
            issueNumber: state.issueNumber,
            pullRequestNumber: pullRequestNumber ?? state.pullRequestNumber,
            contractDigest: state.contractDigest,
            head: head ?? state.head,
            tree: tree ?? state.tree,
            generation: state.generation + 1,
            leaseID: state.leaseID,
            policyDigest: state.policyDigest,
            priorAuditSequence: sequence,
            priorAuditDigest: auditSHA256,
        )
    }
}
