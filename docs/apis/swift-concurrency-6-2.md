---
read_when: touching async code, isolation diagnostics, @concurrent, Sendable errors, "data race" anything
verified: 2026-06-12, Xcode 26.5 / Swift 6.3 toolchain (language mode 6, 6.2 semantics)
---

# Swift 6.2+ approachable concurrency, as configured HERE

Every target sets MainActor default isolation
(`.defaultIsolation(MainActor.self)` in Package.swift;
`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY
= YES` in the app target). Mental model: **the whole codebase is
single-threaded unless a declaration explicitly opts out.** Data races are
compile errors, not runtime bugs.

## What this means in practice
- Plain types, plain functions, plain closures: all MainActor. UI, models,
  stores — write them as ordinary single-threaded code.
- `async` functions here still run on the MainActor; `await` is a suspension
  point, not a thread hop. I/O-bound work (network, file reads) is fine as
  plain `async` — suspension already frees the main thread.
- `Task { ... }` inherits MainActor isolation. That's the right default.

## Opting out — the ladder, in order
1. Don't. Most "should this be off-main?" code is I/O-bound; plain async on
   MainActor is correct and simplest.
2. CPU-heavy, measured hot (profiler says so): mark the leaf function
   `@concurrent func crunch(_ input: In) async -> Out` — it runs on the
   concurrent executor; its inputs/outputs must be Sendable. Add the one-line
   justification comment.
3. Mutable state that must live off-main: a dedicated `actor`. Rare here.
4. Anything beyond that → ask the user.

## Diagnostics → fixes
- "Main actor-isolated X can not be referenced from a nonisolated context"
  → you're inside `@concurrent`/nonisolated code touching MainActor state.
  Pass values in as Sendable parameters instead of reaching out.
- "Sending value of non-Sendable type ... risks data races"
  → the value crosses an isolation boundary. Prefer making it a value type /
  `Sendable`; do NOT write `@unchecked Sendable` (ask-first item).
- "Call to @concurrent function in a context that may not suspend" /
  missing-await errors → add `await`; crossing executors always suspends.

## Don'ts (lint enforces most)
`DispatchQueue` (error) · `Task.detached` (warning + justification) ·
`@unchecked Sendable` (error, ask-first) · redundant `@MainActor` annotations
(it's the default — noise) · "fixing" an isolation error by changing target
build settings or language mode.
