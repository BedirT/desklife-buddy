# Ledger model + policy card (story-5 ledgers)

Collector anchor: trust-ledger-card v1.
Sources: `Packages/Domain/Sources/Domain/LedgerIdentity.swift`,
`LedgerObservation.swift`, `LedgerAssessment.swift`,
`LedgerConsentReceipt.swift`, `LedgerPolicyDecision.swift`,
`LedgerCompanionAction.swift`, `LedgerCorrection.swift`,
`LedgerExport.swift`, `HistoryExport.swift`, `HistoryPolicy.swift`.
Status: baseline, releasable without release-scope selection.

## Model

Six versioned ledger contracts, each a separate additive-only store
holding sanitized rows only: window facts, digests, receipts, lease
windows, and effect classes. In-memory sensing content never enters a
ledger row. Encoding is deterministic (sorted keys); each envelope
carries a row schema version so a future version is refused by identity
before its row is decoded.

| Ledger | Row | Admits only |
|---|---|---|
| Observation | window fact under a live provider lease | providers fake-presence/fake-motion/fake-ambient; kinds presence/motion/ambient; closed quality/confidence/coverage codes; no payload, no bus sequence, no atom identity |
| Assessment | verdict over one window | binary-or-unknown reading code, capped confidence, group count, sanitized representative content, opaque digest; atom ids and bus sequences never enter |
| Consent receipt | grant, revocation, or expiry | placeholder scopes (sensing-presence/motion/ambient, effect-hold/restart), statuses granted/revoked/expired; never a real entitlement or privacy key |
| Policy decision | audit behind one automatic behavior change | closed kinds holdBegin/holdRelease/holdCorrectionRelease/sensorStrongMovementRestart; effects quiet/shift/restart/resume; no reading, confidence, provider, or group content |
| Companion action | audit behind one companion-routed action | closed companion kind/scope, lease window, settlement receipt; titles, content ids, and payloads never enter |
| Correction | replayable settlement record | closed outcomes (committed, duplicate replay, named rejection), causal generation, global revision, superseded ids; corrections never re-apply effects |

Identical replays are idempotent; reused identifiers with different
facts are refused; retention prunes on every write and read.

## Policy

- Closed vocabularies by construction: each record type validates its
  codes at init and refuses anything outside the admitted sets.
- Export is projection-only: `HistoryExport` carries only explicitly
  selected fields from its closed vocabulary (id, recordedAt, kind,
  source, opportunity, selectedDurationSeconds) in csv/json;
  `LedgerExport` keeps selected keys per ledger in csv/json.
- Retention is explicit and bounded (`HistoryPolicy`): raw local
  opportunity events have stated retention choices; ledger pruning runs
  on every write and read.
- The consent ledger records what was decided, at which revision, and
  when it lapsed; the permission surface itself belongs to
  `PermissionBroker` (placeholder capabilities only, kill switch,
  5-tick revocation deadline — see the dossier's tcc checks).

## Limits

- Ledgers audit that an action settled, never what it carried; the
  assessment digest audits the verdict without revealing content.
- No completeness, correctness-rate, or outcome claim is made here;
  coverage, abstention, subgroup errors, corrections, and null/failure
  reporting wait on the owner-selected release scope and hardware runs
  (dossier: trust-release-scope-selection).
- Exact signed-candidate retention and export paths (bundle id,
  container) likewise wait on release-scope selection.
