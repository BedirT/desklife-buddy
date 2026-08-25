# Full harness bootstrap

Status: in progress

## Objective

Install and adapt the complete `swiftmac-base` harness in this combined design and
implementation repository before any product code is written. Preserve the design and
research package as the implementation authority, and keep product identity neutral.

## Non-goals

- Do not implement the clock engine, event log, menu bar, break surfaces, or any other
  product behavior.
- Do not rename the template target, scheme, module, display name, or bundle identifier.
- Do not change the immutable research package or reinterpret product decisions.
- Do not activate the factory trust root, configure production credentials, create a remote,
  or begin distribution.

## Steps

- [x] 1. Read `design/HANDOFF.md`, repository law, and the `swiftmac-base` greenfield and
  harness contracts.
- [x] 2. Import the complete tracked harness, including scripts, skills, factory contracts,
  CI, tool pins, snapshot kernel, macOS app proof fixture, and exact-head lifecycle.
- [x] 3. Merge the existing design, claims, and accessibility review skills into the shared
  `.agents/skills/` portfolio and restore the `.claude/skills` parity adapter.
- [x] 4. Initialize fresh Git metadata on `main` without a remote or production identity.
- [x] 5. Bind the durable product contracts and repository instructions to
  `design/HANDOFF.md`, the canonical design package, and the normative protocol YAML.
- [x] 6. Install locked tools and run `scripts/doctor.sh`.
- [ ] 7. Run the full bootstrap verification: lint, product/package tests, snapshots, app
  build/run proof where the environment permits, `scripts/test-template.sh`, and
  `scripts/test-harness.sh`.
- [ ] 8. Record exact command evidence and leave the repository ready for its first clean
  baseline commit. Product implementation remains explicitly not started.

## Decisions

- 2026-08-25: The owner chose to install the app harness in this repository despite the
  earlier design-only boundary, making it a combined design and implementation repository.
- 2026-08-25: Product identity is deferred. Neutral template identity remains intentionally.
- 2026-08-25: `design/HANDOFF.md` is the implementation entry point; existing research and
  design authority order remains unchanged.
