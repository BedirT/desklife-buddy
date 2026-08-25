# Round-2 review notes — three-skill pass, 2026-08-25

Reviews run: `design-review`, `claims-review`, `accessibility-review` (adversarial
subagents; principal synthesis below and in `design/DECISIONS.md` D-026–D-029).

## 12-criterion rubric (design-quality §4), round-2 Horizon set

| # | Criterion | Score /5 | One sentence |
|---|---|---|---|
| 1 | Product clarity | 4 | The eyebrow + field metaphor say "break" instantly; what the *app* is only fully lands in the menu/settings surfaces. |
| 2 | Interruption quality | 4 | Self-running + equal quiet exits is respectful; the status line was narrating every visit (fixed by D-027). |
| 3 | Mac nativeness | 3 | Break surfaces are confidently their own thing, but the menu carried fake hotkeys and a non-system highlight (fixed); Settings must ship on system controls to earn a 4. |
| 4 | Distinctiveness | 5 | Two-atmosphere landscape + horizon-as-progress + the dozing sun are recognizable with no gimmick. |
| 5 | Simplicity | 4 | Movement's text diet (D-024) works; the capsule's option tree is the remaining complexity, kept behind hover. |
| 6 | Scientific honesty | 5 | No claim slips in round-2 strings; events stay unmerged; "estimated" survives compression. |
| 7 | Autonomy | 4 | Esc-immediate everywhere; the arming delay (D-029) closes the accidental-declaration hole without softening exits. |
| 8 | Accessibility | 2 → revisit | Measured contrast failures (safety footer 2.6:1, chips over bright sky) and a missing capsule keyboard route; all addressed by D-028/D-029 — re-score at render time. |
| 9 | Privacy | 5 | Pointer station-keeping is ephemeral and in-memory (DQ-15 logged); nothing displayed implies collection. |
| 10 | Emotional tone | 4 | Calm and warm; the safety footer wording is the one clinical note, and it is deliberately fixed text. |
| 11 | Visual quality | 4 | The fields and type are authored; light appearance and IC/RT variants are still owed (DQ-18). |
| 12 | Long-term tolerance | 4 | One fixed ground stack (D-027) and coarse capsule numerals (D-029) are the 500th-viewing changes this round needed. |

Verdict: **revise** — all findings fixable without touching the concept. Fixes applied
2026-08-25 (this pass); items deliberately logged instead of fixed: field-vs-instruction
tension over the bloom band (per-render verification, DQ-18), movement-field heat
(DQ-18), cognitive-load recheck of the movement surface at render time.

## Where the findings went

- **Design review** → D-026 (D-005/D-021 contradiction), D-027 (shared ground stack,
  status line), menu/settings nativeness fixes in the artboards.
- **Claims review** → no blockers; CP renumbering (duplicate CP-BR10–12, CP-SE03–05),
  CP-ST11 rationale correction, CP-BR34 supersession, new registrations CP-MB14–18,
  CP-HU21, CP-SE25–33, CP-MV15–16 in `COPY_INVENTORY.md`.
- **Accessibility review** → D-028 (contrast floors), D-029 (capsule keyboard route,
  M6/M9 motion safety, arming delay), ACCESSIBILITY.md reconciliation note,
  SCREEN_INVENTORY §K updates + K.5, DQ-18 additions (static mode owed), DQ-19.
