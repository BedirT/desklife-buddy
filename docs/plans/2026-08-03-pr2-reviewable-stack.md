# PR #2 reviewable stack

Status: complete
Intake/escalation status: clear

## Outcome

Replace the 287-file PR #2 review surface with a bottom-up stack of semantic
PRs. Each layer states one review question, depends only on the layer below it,
and carries reproducible local verification. The frozen
`agent/software-factory-v1` branch remains unchanged as a recovery reference.

## Non-goals

- Do not rewrite or force-push the frozen PR #2 branch.
- Do not merge any PR on the owner's behalf.
- Do not restore automatic paid macOS CI.
- Do not change the intended final software-factory behavior while splitting it.

## Steps

- [x] 1. Establish local-first verification and manual-only hosted CI on the
      bottom branch; verify lint and workflow syntax.
- [x] 2. Publish the factory plan and trustworthy template baseline as focused
      stack layers; verify each exact head locally.
- [x] 3. Publish the declarative contract surface and its executable gate as
      separate layers; verify schema fixtures and contract tests.
- [x] 4. Publish the Stage A trust kernel in subsystem-oriented layers, followed
      by the historical trust-boundary repairs; run Factory tests at each
      buildable boundary.
- [x] 5. Publish the inert end-to-end expansion in subsystem-oriented layers and
      prove checkpoint `eecf7c5` matches PR #2 except for this stack plan.
- [x] 6. Run iterative review swarms over the stack, repair material findings,
      and revalidate every affected descendant at its exact SHA.
- [x] 7. Mark PR #2 superseded, leave the owner a bottom-up review order, and
      hand off an evidence pack without merging.

## Decision log

- 2026-08-03: The owner chose stacked PRs instead of the exceptional exhaustive
  audit workflow for PR #2.
- 2026-08-03: Local verification is authoritative for routine work; GitHub-hosted
  macOS verification is manual-only to avoid paid CI usage.
- 2026-08-03: Splits are semantic rather than one PR per historical commit.
- 2026-08-03: Review repairs above checkpoint `eecf7c5` intentionally diverge
  from frozen PR #2 only to close material correctness and security findings.
- 2026-08-03: Full template smoke exposed an incorrect expected output in the
  new FactoryCLI cache regression; the assertion was repaired and the final
  four-role review swarm found no material issues at code head `d5aef01`.
- 2026-08-03: PR #2 was closed as superseded while its branch and frozen head
  `b5303421` were preserved.

## Bottom-up review order

1. #5 Make verification local-first
2. #6 Define the macOS software factory contract
3. #7 Harden the macOS app template contract
4. #8 Harden template lifecycle and process safety
5. #9 Make visual evidence capture deterministic
6. #10 Pin the verification toolchain and CI trust policy
7. #11 Define the visible factory law and roles
8. #12 Add typed factory schemas and public fixtures
9. #13 Add the qualified skill registry
10. #14 Enforce the factory contract surface
11. #15 Add factory value contracts and skill routing core
12. #16 Add data-only evaluation contracts
13. #17 Add broker trust and runner isolation
14. #18 Add authoritative patch import transaction
15. #19 Add factory lifecycle state machine
16. #20 Add offline factory commands
17. #21 Enforce factory schema parity
18. #22 Integrate factory runtime verification
19. #23 Add isolated evaluator runtime
20. #24 Harden factory state transactions
21. #25 Reject filesystem ACL authority
22. #26 Seal evaluator workflow boundaries
23. #27 Add external design contracts
24. #28 Add client context routing
25. #29 Add controller repair circuit
26. #30 Add learning and reports
27. #31 Complete the factory runtime contract
28. #32 Integrate factory operator tooling
29. #33 Harden factory report rendering
30. #34 Close factory skill review gaps
31. #35 Make external design ingestion static-only
