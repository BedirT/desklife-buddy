# Factory trust boundary

`Packages/Factory` is the dependency-free trusted-root kernel. The source in a
pull request has no production authority: it can validate public contracts and
exercise synthetic fixtures, but it cannot launch a live model writer, access a
delivery credential, mutate Git/GitHub, activate itself, or read a private
evaluation corpus.

## Root establishment

Post-merge activation begins only after the owner audits and merges the exact trusted-root
commit. Installation creates a dedicated, non-root broker service account that
is distinct from the interactive operator account. The broker must run with
matching real and effective broker UIDs; a setuid-root executable is explicitly
not a supported design.

The only production anchor location is:

```text
/Library/Application Support/SwiftMacFactory/trust-anchor.json
```

The anchor is a root-owned, single-link regular file with root-controlled,
non-group/world-writable ancestry. It contains no credential. It binds the
repository, exact merged trusted root SHA, activation-key digest, broker executable
identity, broker and operator UIDs, exact broker-state root, exact evaluator
scaffold root and complete empty-manifest digest, frozen Evolution acceptance
digest, and signing-key ID. None of those roots, identities, times, or paths can
be supplied through a model or PR-head request.

`broker_identity_sha256` is the SHA-256 of the actual installed
`FactoryBroker` executable, not descriptive policy metadata. Before every
authority-bearing command the process obtains its own executable path from the
kernel, walks the installed ancestry with no-follow descriptors, requires a
root-owned single-link executable at exact mode `0555` with no set-ID bits,
hashes it through the held descriptor, and verifies stable path/inode metadata
against both the anchor and the kernel-reported vnode backing the current
process image. Extended ACLs are forbidden on every traversed ancestor and the
executable. Activation additionally requires a Developer ID hardened-runtime
signature, an empty entitlement set, assessment by macOS policy, and a clean
service launch environment so hashing the main Mach-O cannot be bypassed with
injected runtime code.

Both evaluator identities share one second root-installed fact:

```text
/Library/Application Support/SwiftMacFactory/evaluator-anchor.json
```

It is a root-owned, no-ACL mode-`0444` document that binds the exact trusted root and
acceptance-policy digests, evaluator executable digest, two distinct non-root
OS UIDs, two distinct aggregate-signing-key digests, and two separate private-
executor public keys. All four key identities must differ. Each evaluator
verifies the document, its partition UID, mapped executable vnode, and policy
before initialization. Before aggregate evaluation it additionally verifies
its real aggregate key and the candidate execution receipt signature. GitHub
Environment variables are not the root of trust for partition or key
separation.

The broker-state leaf is owned by the broker account at mode `0700`; every
ancestor is root- or broker-owned and not group/world writable. State and
evaluator roots must be canonical, disjoint absolute paths and may not contain
the anchor. Descriptor walks reject links, ownership/mode drift, alternate
roots, path swaps, multiply linked files, and mutation while bytes are read.

## Activation

Initialization creates only an unactivated genesis document. Live mutating
authority requires one owner-signed activation receipt bound to the exact:

- trusted root SHA, repository policy, broker identity, and activation key;
- run, issue, contract, lease, generation, broker state, head, and tree;
- isolation and evaluator proofs plus frozen selection and sealed epochs; and
- audit public key, receipt identity, signing-key identity, and bounded lifetime.

Activation uses trusted process time, advances the durable generation exactly
once, and is installed under the same descriptor-backed lock as broker state.
Every later accepted request is nonce-bound and compare-and-swap guarded. Its
signed audit transition binds both the transition identity and the exact next
state digest. The nonce cache must equal the complete signed audit nonce set, so
selective deletion, replacement, replay, state substitution, or sequence
overflow fails closed. Atomic files and self-hashes do not by themselves detect
restoration of an older valid whole document; activation therefore remains locked
until an external monotonic witness binds the accepted broker and evaluator
ledger heads before authority is enabled.

## Process separation

The immutable broker is the sole future Git/GitHub actor. A model writer runs
without `.git`, owner home/config, Keychain access, delivery credentials, or
network access inside an invocation-specific scratch projection. It returns a
bounded `PatchEnvelope`; package-only authority validates and imports the exact
regular-file delta into a leased authoritative worktree. Candidate or PR-head
code never executes in the broker or evaluator process.

The private evaluator receives data-only candidate outputs and emits bounded
aggregate attestations. The delivery identity may dispatch an evaluation and
consume its signed aggregate, but cannot read or write the private corpus. The
curator and evaluation identities remain separate from the delivery broker.

Selection and sealed each use a different protected `workflow_dispatch` job,
self-hosted runner label, environment, local inbox, state root, and signing key.
The workflow runs only from the owner-created immutable
`factory-v1-root` tag when its exact SHA and installed `FactoryEvaluator`
digest match activation environment variables. It performs no checkout and
executes no candidate or PR-head working-tree code. The immutable tagged
workflow script is itself trusted-root code. Each runner is a fixed non-root
partition UID, and the shared
root evaluator anchor proves those UIDs and keys are distinct even when GitHub
configuration is wrong. The first protected dispatch descriptor-loads a mode-
`0600` reservation request and atomically consumes the nonce and target ordinal
in a locked durable CAS document, then emits a short-lived evaluator-signed
authorization bound to the reservation digest. Only after that success may the
activated private-executor service run the candidate, and its signed receipt must
bind the exact authorization digest plus trusted start/completion times inside
the capability lifetime. The ledger persists exactly one authorization and
returns identical bytes on reserve retry. The private executor must consume the
authorization digest in the kernel's separate durable one-shot replay ledger
and receive an external monotonic-witness acknowledgement for the returned
committed ledger head before corpus or model access. A second explicit dispatch
descriptor-loads its signed mode-`0600` execution bundle and aggregate key,
then completes the
reservation with the aggregate and execution-receipt digest, then persists the
short-lived signed attestation before releasing it. A crash leaves the
reservation consumed and blocks the target; retry either finishes signing the
stored aggregate or returns the exact stored attestation. Controller-side
attestation consumption uses a separate durable replay CAS keyed to the private
query identity, so process restart or re-signing cannot reapply a result. If an
unconsumed attestation expires during delivery outage, the same completed query
may issue a later bound signature; a controller that consumed either signature
rejects the other through the shared query replay identity.

These workflows are the protected local execution primitive. Activation must
install the authenticated, content-addressed delivery handoff that stages the
reservation before invoking the private executor, stages the resulting signed
authorization, stages the resulting signed mode-`0600` execution bundle,
records the returned aggregate, and witnesses each resulting ledger head. The
build candidate does not claim that transport or
the live private corpus exists in this unmerged branch. The execution bundle's
candidate receipt must be signed by the separately anchored partition-specific
private executor, must bind the evaluator-signed reservation authorization, and
the private-executor service may run only after that authorization exists.
Activation installs and proves that ordering plus durable one-time executor-side
consumption of every authorization digest, including fresh-process replay
denial and rollback-probe denial, plus witness acknowledgement before private
execution and the authenticated staging transport; caller-supplied output hashes
alone cannot qualify a candidate.

## Build input boundary

Every harness entry point verifies the complete reviewed SwiftPM, Xcode, mise,
npm, lint, format, and ignore-file input set before invoking dependency-
controlled tooling. Alternate manifests, plugins, macros, binary targets,
unsafe flags, Xcode actions, user schemes, test plans, configs, lifecycle
scripts, and digest drift fail closed.

Xcode may leave an empty `.swiftpm/xcode` cache directory under `Domain`,
`Features`, `DesignSystem`, or `TestSupport`. Those four exact owner-controlled
empty cache roots are ignored because they contain no input. A file, link,
alternate entry, different cache root, or any `.swiftpm` state under
`Packages/Factory` is rejected. Thus a completed App test does not poison the
next verified command, while executable or dependency-bearing state remains
outside the trusted input set.

## Post-merge owner ceremony

The merged trusted root remains fixture-only until all of these external facts are proven:

1. install the dedicated broker account and root-owned anchor from the reviewed
   merged SHA;
2. install the least-privilege delivery GitHub App and provider accounts outside
   every model projection;
3. run the full Codex, Claude Code, and Pi denial suite for client and spawned
   tool processes;
4. create the private companion repository from the exact empty scaffold, then
   have a separate curator open and the owner merge/protect epoch zero; and
5. prove the delivery App cannot merge, push `main`, administer, bypass branch
   protection, or read the corpus before it creates the Evolution transaction.

These are one-time owner/root establishment actions. They are deliberately not
automated by an unmerged branch.

The ceremony also installs Developer ID-signed, hardened-runtime, library-
validated root-owned mode-`0555` `FactoryBroker` and `FactoryEvaluator`
binaries; launches them with a clean fixed environment; initializes physically
separate mode-`0700` selection and sealed ledger roots; installs distinct mode-
`0600` signing keys and inboxes; installs the shared mode-`0444` evaluator
anchor with two distinct non-root UIDs and signing-key digests; proves private
execution-receipt provenance with two separately anchored executor keys and a
durable one-shot authorization ledger; and
creates the external monotonic witness for broker, query, execution-
authorization-replay, and attestation-replay heads. It creates/protects the exact
merged-SHA `factory-v1-root` tag and configures the protected workflow
environments and runner labels. Those live facts are absent from the unmerged
trusted root branch.
