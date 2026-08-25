# Factory - local conventions

This package is the dependency-free Swift 6.2 trust kernel for the software
factory. It is not app product code and is never linked into `App.xcodeproj`.

- `FactoryCore` owns typed contracts and deterministic validation. It does not
  invoke models, Git, GitHub, shells, or network clients.
- `FactoryBroker` is the narrow trusted-base executable. It can initialize a
  new state root, install one owner-signed activation receipt, and create the
  empty private-evaluation scaffold; it does not invoke Git, GitHub, models, or
  credential transports. PR-head tests use only synthetic roots, identities,
  keys, and requests.
- `FactoryEvaluator` is the separately installed private-evaluation executable.
  It verifies the shared root evaluator anchor, its mapped executable, partition
  UID, aggregate key, and private-executor receipt before reserving a durable
  query, then returns only a signed aggregate. Selection and sealed use separate
  protected environments, roots, runner labels, identities, keys, and replay
  ledgers.
- `FactoryCLI` is credential-free and read-only. Checkpoint 3 exposes typed
  contract validation only; production orchestration belongs to later
  checkpoints.
- All external bytes are untrusted until decoded and semantically validated.
  Reject unknown operations, stale CAS values, unsafe paths, replayed nonces,
  and incomplete evidence instead of guessing.
- Filesystem mutation uses structured APIs, descriptor-backed regular-file
  checks, complete preflight, and rollback. Never shell out to mutate source.
- Tests are Swift Testing and red first. Every denial rule needs a seeded attack
  fixture; every attestation binds the exact request, policy, epoch, and result.
- Public types and functions have purpose-oriented documentation. Time, IDs,
  nonces, hashes, roots, and keys are injected in behavior that tests assert on.
- `PublicAPI.json` is the reviewed trusted root public/package symbol surface. Run
  `scripts/check-factory-api.sh` after intentional public API work; never refresh
  it merely to silence an unexpected diff.
