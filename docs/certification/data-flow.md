# Public data-flow diagram (trust baseline)

Status: baseline, releasable without release-scope selection.
Collector anchor: trust-data-flow-doc v1.
Scope: the permission-free Mac core. Every stage below names its Domain
source; nothing in this diagram requires an entitlement, a privacy key,
a network, or a permission prompt.
Inventoried exception outside this diagram: the owner-approved calendars
entitlement plus its usage description (Epic 5 Calendar adapter, issue #6,
owner approval 2026-09-12 — fail-closed, busy/free plus known end only, no
content) is pinned by the dossier's no-egress-entitlement-inventory check.

## Diagram

```
fake providers (fake-presence / fake-motion / fake-ambient)
  │  sanitized scalar proposals only (EvidenceAtom: closed kind/source
  │  vocabularies; no payload content, no sensing frameworks)
  ▼
SensingLeaseAuthority.issue — lease-issuance path, gated by
PermissionBroker sensing grants (placeholder capabilities only)
  │
  ▼
EvidenceBus.admit — bounded expiring FIFO; over-capacity drops the
oldest atom and counts it (droppedCount); expired atoms purged before
append-or-evict, so dead atoms never evict live ones
  │  Class 0: memory-only. No store protocol, no snapshot, nothing Codable.
  │  Bus contents never enter ProtocolState, CoordinatorFenceState,
  │  OpportunityEventStore, HistoryExport, logs, or analytics.
  ▼
EvidenceFusion.fuse — deterministic verdict per evidence kind from bus
contents only (never caller-built atoms); reads Unknown on missing,
stale, denied, degraded, contradictory, revoked, fenced, rotated-out
  │  Class 0: derived in memory, never persisted.
  ▼
ClosedPolicyFirewall.evaluate — deny by default; at most one closed
command per evaluation through the fenced coordinator entry point;
public result is a sanitized FirewallReceipt (identities, closed kind,
effect class, lease window, opaque assessment digest, ticks)
  │
  ├─► OpportunityCoordinator (fenced path only) — commits identity,
  │   rank, and fence; no fact and no clock delta
  │
  └─► Ledgers (append-only, sanitized rows only — see ledger-card.md):
      LedgerObservation, LedgerAssessment, LedgerConsentReceipt,
      LedgerPolicyDecision, LedgerCompanionAction, LedgerCorrection
```

## The only egress: user-initiated local files

- HistoryExport: closed field vocabulary (id, recordedAt, kind, source,
  opportunity, selectedDurationSeconds), csv/json, only explicitly
  selected fields. Source: `Packages/Domain/Sources/Domain/HistoryExport.swift`.
- LedgerExport: per-ledger closed export vocabularies, csv/json.
  Source: `Packages/Domain/Sources/Domain/LedgerExport.swift`.
- Both write a local file the user chose. There is no network, XPC, or
  analytics egress: the dossier's no-egress collectors
  (no-egress-raw-import-guard, no-egress-transport-absence,
  no-egress-servicemanagement-inventory, no-egress-entitlement-inventory,
  no-egress-privacy-manifest-absence) re-verify this on every run.

## What this diagram does not show

- No wall-clock performance, energy, or thermal numbers appear here;
  measured numbers wait on the owner hardware run (see the dossier's
  pending-owner checks). Suite timings, where collected, are labeled CI
  wall-clock timings, never energy claims.
- No health outcome is inferred from any product or sensor fact
  (see `docs/product/BRIEF.md` problem statement and the claims
  register `research/health/machine-readable/claims_register.csv`).
- Exact signed-candidate paths (bundle id, container, license text)
  wait on the owner release-scope selection
  (dossier: trust-release-scope-selection).
