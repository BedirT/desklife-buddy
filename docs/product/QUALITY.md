# Product quality contract

Status: `accepted`
Intake revision: 1

Calibrate each relevant dimension as `critical`, `required`, `target`, or
`not-applicable`, and attach an owner example when taste or product meaning is
not captured by a deterministic predicate.

| Dimension | Level | Testable acceptance | Calibration example |
|---|---|---|---|
| Product depth and completeness | required | Handoff build order and inventory scope without parallel states | `design/HANDOFF.md` |
| Functional correctness and end-to-end usability | critical | Two clocks, suppression, merge, and ten events preserve every invariant | `design/PRODUCT_MODEL.md` |
| Native macOS fit | required | Menu/Dock, panels, focus, shortcuts, and multi-display pass real-app proof | interaction spec |
| Visual identity, craft, and coherence | required | Tokens, stable geometry, appearance parity, and visual review pass | Horizon direction |
| Accessibility and reduced motion | critical | Every applicable §K line passes; no color-only meaning or subordinate path | screen inventory |
| Data integrity, recovery, and offline behavior | critical | Events stay distinct; no idle/body inference; core works offline | protocol YAML |
| Privacy, dependencies, entitlements, and secrets | critical | No account/network/invasive core permission; optional access stays isolated | privacy spec |
| Performance, responsiveness, memory, and energy | required | Quiet low-energy utility; overlays restore focus and release resources | runtime/perf proof |
| Architecture, concurrency, tests, and maintainability | required | Domain-first tests, injected clocks, Swift isolation, previews, lint | `AGENTS.md` |
| Release, provenance, signing, and distribution readiness | target | Owner-gated after identity/channel are settled | `scripts/release.sh` |

## Hard blockers

- Safety/privacy/data-loss blocker: any claim beyond observation, movement inferred from idle,
  invasive required permission, inaccessible exit, subordinate mobility path, or collection.
- Product-defining blocker: clocks merged semantically, event vocabulary changed, escalation
  introduced, or shipped strings diverge from the copy inventory.
- Release blocker: unsettled identity/signing/channel, required owed assets, or any failed
  design/claims/accessibility/research gate.

## Evidence expectations

- Required real-app journeys: the full verification ladder plus keyboard, Escape, focus,
  VoiceOver, multi-display, suppression, and no-permission paths for each surface.
- Required visual states and owner calibration: previews and inspected snapshots for every
  reachable state; canonical comparison only after inventory marks a render designed.
- Required performance or data-integrity repros: deterministic domain tests; runtime capture
  and xctrace for overlay/motion regressions; no proxy claims instead of visible proof.
- Known acceptable limitations: passive-reading undercount, provisional mappings, and owed
  art remain explicitly documented in the handoff.
- Unresolved owner escalations: identity, distribution/signing, paid/hosted dependencies,
  privacy expansion, final-art rights, and research/design contradictions.
