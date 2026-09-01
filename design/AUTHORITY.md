# Product Authority and Traceability

Status: canonical authority map

Baseline audited: `e6e9ca094cfbbee50f1d554be6640653f85caf2d`

Established: 2026-09-01

This file defines how to resolve conflicts between evidence, product decisions,
machine-readable values, implementation, and proof. It does not change a timing,
action, claim, permission, retention rule, or other product semantic. The audited
implementation inventory is in [CURRENT_STATE_CONFORMANCE.md](CURRENT_STATE_CONFORMANCE.md).

## The governing rule

No artifact wins merely because it is newer, executable, or more detailed. A change
becomes normative only in the artifact that owns that kind of decision, with an
explicit status and supersession record. Code proves current behavior; it cannot
silently amend product intent. Research explains evidence; it cannot silently select
an interaction. An exploration, plan, issue, test, or render cannot silently promote
itself to product authority.

When two canonical artifacts genuinely disagree:

1. stop the affected behavior change;
2. record both readings in `OPEN_QUESTIONS.md`;
3. keep the safer existing behavior or disable only the disputed new capability;
4. resolve the conflict in the owning canonical artifacts; and
5. land prose, machine values, migration, and verification in the dependency order
   declared by the resolving story.

## Precedence by concern

Precedence is concern-specific rather than one universal file list.

| Concern | Normative authority, highest first | What lower layers may not do |
|---|---|---|
| Owner intent and accepted product decisions | Explicit owner decision recorded with normative status `Active` or `Accepted` in `DECISIONS.md`; unresolved items in `OPEN_QUESTIONS.md` | Issues, plans, explorations, or code may not infer acceptance |
| Health evidence and protocol meaning | The research order in `../CLAUDE.md` section 5, led by `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` | Product prose may not turn uncertainty into an outcome claim |
| Claims and intended-purpose language | `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`, `claims_register.csv`, then registered strings in `COPY_INVENTORY.md` | A view, model, App Store draft, or generated explanation may not invent stronger copy |
| Timing, threshold, preset, and closed machine values | `../research/health/machine-readable/product_protocol.yaml`, after any required canonical research amendment | Generated Swift and UI labels may project values but may not fork them |
| Product state and action semantics | Normative `Active` or `Accepted` entries in `DECISIONS.md`, then `PRODUCT_MODEL.md` and `INTERACTION_SPEC.md` | A feature model, App coordinator, or persistence codec may not create a parallel semantic |
| Screen scope and accessibility | `SCREEN_INVENTORY.md`, `ACCESSIBILITY.md`, then accepted rendered states and design-system rules | A render is not scope authority; a snapshot is not accessibility acceptance |
| Privacy, permission, data class, and retention | `07_PRIVACY_AND_DATA_SPEC.md`, normative `Active` or `Accepted` decisions, then the canonical machine contract created by the owning story | Entitlements, adapters, and storage do not authorize collection by existing |
| Implementation ownership and delivery | `../AGENTS.md`, this map, module `AGENTS.md`, then `HANDOFF.md` | A plan may sequence work but may not move ownership across layers silently |
| Current behavior | Shipped source and persisted schema at the exact audited commit | Current behavior is evidence to reconcile, not authority to overwrite intent |
| Verification | Repository scripts and retained exact-head evidence | A passing test proves its assertion only; it does not approve semantics or claims |

Within a row, `Active` means the decision currently governs and `Accepted` means an
owner-approved decision that also governs unless its text narrows its effect. Either may
supersede an earlier decision only when it names what it supersedes and the affected
canonical files are reconciled. A qualified status such as D-029's partial `Active` applies
only to the clauses not explicitly superseded. `Superseded` and non-normative statuses do
not govern new work. Append-only history remains visible. Historical research provenance
is never rewritten.

## Artifact statuses

- **Canonical**: owns a named concern now.
- **Generated**: must be reproducible from a named canonical source and must not be
  hand-edited.
- **Implementation evidence**: describes what the exact commit does; it is not a
  product-intent shortcut.
- **Historical intake**: owner-approved direction that still requires promotion into
  each owning canonical artifact before behavior ships.
- **Exploration or Labs**: may be prototyped only within its declared gate; it is not
  production authority.
- **Superseded**: retained for provenance and explicitly points to its replacement.

The owner-approved Calm Ensemble review is **historical intake**. Its approval allows
issue-driven canonicalization work; it does not override the current research YAML,
claims register, privacy spec, decision log, or shipped behavior by itself.

## Required traceability record

Every story that changes product semantics must leave one reviewable record containing
all applicable fields below. `None` is acceptable only with a reason; omission is not.

| Field | Required content |
|---|---|
| Decision | Stable decision ID, status, owner approval, and IDs explicitly superseded |
| Intended purpose and claim | Intended-purpose sentence plus claim-register IDs/classes and prohibited boundary |
| Normative prose | Exact canonical path and section that owns the behavior |
| Machine contract | Exact YAML/key or other versioned machine path; stable identifier and value owner |
| Behavior owner | Existing Domain type/reducer/store and App composition point extended or explicitly replaced |
| Action and identity | Stable action ID, opportunity/cycle identity, terminal/idempotency rule, and stale-action behavior |
| Permission | System permission, entitlement, request moment, denial/revocation behavior, and unrelated-capability guarantee |
| Data lifecycle | Raw/derived classification, process boundary, persistence, retention, export, deletion, and egress |
| Fallback | Permission-free or sensor-unavailable behavior, uncertainty state, correction, and kill switch |
| Accessibility | Keyboard, Escape, VoiceOver, reduced motion/transparency, contrast, text size, parity, and multi-display impact |
| Verification | RED proof when behavior changes; focused tests; fixtures/migrations; Preview/snapshot; real-app/device; performance/security gate |
| Compatibility | Schema version, migration/reconciliation rule, exact old fixture, and rollback or safe-disable behavior |

A pull request must link the record and name any deliberately deferred field. A
follow-up issue is not permission to ship through an unresolved safety, privacy,
claims, migration, or accessibility field.

## Stable identifier compatibility

Persisted and exchanged identifiers are a compatibility surface, not refactoring
detail.

1. Never rename, recycle, or change the meaning of a shipped raw value.
2. Additive identifiers require a documented owner, version, decoder behavior, and
   tests using a retained older fixture.
3. A semantic replacement receives a new identifier. The old identifier remains
   decodable and is migrated or projected explicitly.
4. Unknown, stale, duplicated, or incompatible actions must fail closed or become an
   auditable no-op; they may not choose a new outcome by arrival order.
5. Persisted schema changes require an explicit version transition. A default value
   may fill a new field only when it cannot invent a historical observation, decision,
   permission, completion, or health outcome.
6. Exported identifiers keep their historical meaning even when display copy changes.
7. Cross-device identifiers require the same rules plus origin, revision, and
   reconciliation semantics before transport ships.

The minimum known current compatibility inventory is:

- opportunity event kinds: `promptPresented`, `breakStarted`, `timerFinished`,
  `userDeclaredCompleted`, `userDeclaredAlreadyMoved`, `positionChanged`, `snoozed`,
  `skipped`, `notAppropriate`, `likelyNaturalInterruption`;
- opportunity types: `visual`, `movement`, `positionChange`, `recovery`;
- event sources: `localTimer`, `user`, `systemContext`, `calendarBusyFree`,
  `focusFilter`, `companionFuture`;
- built-in profile IDs: `gentle`, `balanced`, `frequent_movement`,
  `research_informed_high_frequency`, plus `custom`;
- persisted heads-up identity and action vocabulary: `HeadsUpDeliveryID` UUID;
  `HeadsUpClock` values `visual` and `movement`; `HeadsUpOpportunityID` cases `visual`,
  `movement`, and `merged` with their cycle IDs; `HeadsUpActiveDeliveryPhase` cases
  `reserved` and `presented`; `HeadsUpDeliveryChannel` values `notification` and
  `capsule`; `HeadsUpPromptFactStatus` values `pending` and `acknowledged`;
  `HeadsUpPendingActionKind` values `openBreak` and `openMoreOptions`; positive integer
  `HeadsUpCountdownMark` values; and the stored visual/movement clock ledgers;
- OS-facing notification identifiers: category `heads-up.opportunity.v1`; actions
  `heads-up.action.start-now.v1`, `heads-up.action.snooze-five.v1`, and
  `heads-up.action.more-options.v1`; user-info key `heads-up.delivery-id`; request ID
  prefix `heads-up.delivery.` followed by the lowercase delivery UUID; and Apple's fixed
  `com.apple.UNNotificationDefaultActionIdentifier` and
  `com.apple.UNNotificationDismissActionIdentifier` response identifiers;
- local notification-authorization keys: `heads-up.authorization.has-presented-explainer`,
  `heads-up.authorization.has-requested`, `heads-up.authorization.uses-in-app`, and
  `heads-up.authorization.has-been-authorized`;
- SwiftData protocol/event schema version `1`, settings row schema version `1`,
  `AppPreferences` format version `1`, configuration payload format version `1`,
  and heads-up delivery payload schema version `1`.

These names describe the current baseline, not the final Calm Ensemble vocabulary.
They are a minimum, not a claim that a hand-written document has discovered every
serialized or OS-facing identifier. Before any action, persistence, notification, or
cross-device migration story edits code, it must generate or otherwise mechanically audit
the complete identifier set from source and retained fixtures, attach that receipt to the
traceability record, and test every affected old value. An omission here is never permission
to rename or reinterpret a value. Future canonicalization may add or replace concepts only
through the compatibility rules above.

## Generated and executable consistency

`GeneratedProtocolProfiles.swift` is generated from `product_protocol.yaml` by
`scripts/generate-protocol-configuration.sh`. A timing or preset story must change the
owning machine source, regenerate, and prove no hand-authored duplicate remains.

For every behavior story, review in this order:

1. accepted decision and owning prose;
2. machine contract and stable IDs;
3. Domain reducer/store contract;
4. App adapters, persistence, and composition;
5. feature projection and localized copy;
6. retained fixtures and verification evidence.

That order prevents executable drift while preserving the rule that only exact-head,
user-path evidence can prove the implementation matches the contract.
