# Fusion model + policy card (EvidenceFusion)

Collector anchor: trust-fusion-card v1.
Sources: `Packages/Domain/Sources/Domain/EvidenceFusion.swift`,
`Packages/Domain/Sources/Domain/EvidenceBus.swift`,
`Packages/Domain/Sources/Domain/EvidenceAtom.swift`.
Status: baseline, releasable without release-scope selection.

## Model

Fusion accepts a bus, never caller-built atoms: candidates are the bus's
live atoms whose stamped provenance still validates against the bus-held
authority at the fusion ticks, so post-admit revocation, expiry,
revision advance, or epoch fencing un-votes immediately.

The bus holds its own `SensingLeaseAuthority`: admission validates
against the held copy, and the bus mints sequential atom IDs on
admission (no caller UUIDs, no randomness) and stamps admission
provenance on every atom, which fusion re-validates.

## Policy (determinism rule)

For each `(kind, independence group)` at most one live provenanced
representative fuses, chosen by the total order: quality class
ascending (full, then denied, then degraded), confidence rank
descending, coverage rank descending, expiry tick descending, then
bus-minted sequence ascending. Inputs are canonically sorted before
combining, so arrival order and the number of atoms inside one group
never change the verdict.

- Opposing qualified independent groups produce explicit
  `.unknown(.contradictory)`.
- Confidence caps at the best representative: a second same-group
  signal adds nothing. Confidence dominates; freshness breaks ties
  among equals.
- Missing, stale, denied, and degraded inputs read as Unknown with a
  reason — never as a negative verdict, never averaged, never inflated.
- Cross-bus equality is verdict-level (reading, confidence, groups,
  representative content), never ID-level: per-bus sequences differ.

## Limits

- The fused result (`FusedAssessment`) is a pure non-`Codable` value:
  Class 0, derived in memory from bus contents, never persisted.
- `supportingGroups` counts the qualified independent groups behind the
  verdict; `representative` is the winning atom when the verdict is
  binary and `nil` for every Unknown.
- No accuracy, coverage, or outcome claim is made for fusion here;
  measurement evidence waits on the owner hardware run, and no
  health-outcome language is used anywhere in this card.
