# Domain — local conventions

Pure logic: models, stores, protocols. Never imports SwiftUI/AppKit.

- This is the fastest rung of the ladder (`scripts/test.sh Domain`, seconds on
  the host) — push as much behavior down here as possible.
- Red first: behavior tests are written before the implementation and observed
  failing; bug fixes start from the failing repro test, no exceptions. The
  seconds-fast loop is what makes this cheap — use it.
- Protocol-first stores (`ItemStore` pattern): features depend on the protocol,
  `InMemory*` implementations serve previews/tests, real persistence slots in
  later without touching features.
- Determinism: time, randomness, and IDs enter through parameters or injected
  closures — `SampleData.referenceDate` exists so fixtures never read the clock.
- Every public type/function gets a doc comment saying what it's FOR, not what
  it does.
