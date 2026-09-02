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
becomes normative only in the artifact that owns that kind of decision, with the status
and supersession rules below. The legacy-unstatused dispositions below preserve earlier
governing decisions without inventing a historical status. Code proves current behavior; it cannot
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
| Owner intent and accepted product decisions | Decisions recorded as `Active` or `Accepted` in `DECISIONS.md`, plus the legacy-unstatused dispositions below; unresolved items in `OPEN_QUESTIONS.md` | Issues, plans, explorations, or code may not infer acceptance or assign a missing historical status |
| Health evidence and protocol meaning | The research order in `../CLAUDE.md` section 5, led by `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` | Product prose may not turn uncertainty into an outcome claim |
| Claims and intended-purpose language | `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`, `claims_register.csv`, then registered strings in `COPY_INVENTORY.md` | A view, model, App Store draft, or generated explanation may not invent stronger copy |
| Timing, threshold, preset, and closed machine values | `../research/health/machine-readable/product_protocol.yaml`, after any required canonical research amendment; v2 runtime structure in `machine-readable/timing_runtime_v2.yaml` | Generated Swift and UI labels may project values but may not fork them; canonical-not-activated values may not be presented as shipped |
| Product state and action semantics | Governing `Active` or `Accepted` entries and the legacy-unstatused dispositions below, then `machine-readable/timing_runtime_v2.yaml`, `PRODUCT_MODEL.md`, and `INTERACTION_SPEC.md` | A feature model, App coordinator, or persistence codec may not create a parallel semantic |
| Screen scope and accessibility | `SCREEN_INVENTORY.md`, `ACCESSIBILITY.md`, then accepted rendered states and design-system rules | A render is not scope authority; a snapshot is not accessibility acceptance |
| Privacy, permission, data class, and retention | `07_PRIVACY_AND_DATA_SPEC.md`, normative `Active` or `Accepted` decisions, then the canonical machine contract created by the owning story | Entitlements, adapters, and storage do not authorize collection by existing |
| Implementation ownership and delivery | The closest applicable nested/module `AGENTS.md`, then `../AGENTS.md`; this map and `HANDOFF.md` retain product ownership | A plan may sequence work but may not move ownership across layers silently; implementation instructions may not redefine product semantics |
| Current behavior | Shipped source and persisted schema at the exact audited commit | Current behavior is evidence to reconcile, not authority to overwrite intent |
| Verification | Repository scripts and retained exact-head evidence | A passing test proves its assertion only; it does not approve semantics or claims |

Within a row, `Active` means the decision currently governs and `Accepted` means an
owner-approved decision that also governs unless its text narrows its effect. Either may
supersede an earlier decision only when it names what it supersedes and the affected
canonical files are reconciled. A qualified status such as D-029's partial `Active` applies
only to the clauses not explicitly superseded. `Superseded` and non-normative statuses do
not govern new work. Append-only history remains visible. Historical research provenance
is never rewritten.

The status field is absent from legacy D-012 through D-019 and D-028. Those entries govern
only to the extent their own text has not been superseded or amended by a later governing
decision. A later `Active` or `Accepted` clause wins only on the overlap it names; unrelated
legacy clauses remain in force. This rule neither blanket-promotes the entries nor writes a
status back into history. The complete legacy audit is:

| Legacy decision | Current disposition |
|---|---|
| D-012 | Governs the visible, usable menu bar behind break surfaces. D-026 reuses that obligation after superseding D-005's default dimming, while Active D-012a separately governs Dock suppression. |
| D-013 | Governs position change as a separate event and lower visual tier. D-024 and D-027 amend its current movement-surface presentation. It does not govern opaque full-field presentation. |
| D-014 | Its round-1 footprint directions are explicitly superseded by D-016. It is historical rationale, not current composition authority. |
| D-015 | Governs the prohibition on health numbers, grades, and streaks; no later decision supersedes it. |
| D-016 | Governs the selected landscape/horizon composition and the two atmosphere roles. Later D-025 through D-029 and D-032 refine named motion, layout, contrast, and input clauses without displacing the composition. |
| D-017 | Governs the two-beat horizon mark and its locations; D-028 refines its contrast/state rendering without replacing the mark. |
| D-018 | Governs gradient glyph tiles in Settings and monochrome menu glyphs. It does not govern the heads-up capsule or its keyboard route. |
| D-019 | Governs the sun-not-eye character identity, ephemeral pointer handling, and non-looping behavior except where amended. D-020a supersedes the no-eyes rule and surveillance-first rationale: closed eyes and bounded expression are allowed on aesthetic grounds. D-023 governs the later pointer-glint treatment. |
| D-028 | Governs the measured contrast floors and re-scoped low-ink tiers; no later decision supersedes it. |

A citation label is only a pointer. It never overrides the cited decision's actual text,
recorded status, or supersession chain. Story #19 closed the known quarantine on 2026-09-01:

| Repaired source | Canonical decision now cited | Closure |
|---|---|---|
| `DESIGN_SYSTEM.md` organizing idea and atmospheres | D-016 | D-013/D-014 mislabels removed |
| D-026 full opaque field | D-021 | D-013 mislabel removed; static exception retained |
| D-020a opening | D-019 amended by D-020a | Nonexistent D-020 reference removed |
| `SCREEN_INVENTORY.md` Horizon, capsule, and keyboard routes | D-016; D-022/D-023; D-029 | D-013…D-025 range and D-018 capsule mislabels removed |
| `COPY_INVENTORY.md` eye-character rejection | D-019 amended by D-020a | Closed resting eyes distinguished from prohibited gaze-like motion |
| `INTERACTION_SPEC.md` entrance, exit, countdown start, and key arming | D-032 clarified by D-033 | Superseded sky transition/guard removed; D-031 mis-citation removed |
| `SCREEN_INVENTORY.md` break accessibility blocks | D-032 clarified by D-033 | First-frame inputs and immediate reduced-motion equivalent reconciled |

The protocol consistency check fails if a quarantined citation pattern is reintroduced. The
historical decision text remains append-only; corrected source references do not rewrite why a
decision was made.

### D-032 reconciliation boundary

Accepted D-032 names only D-029's break entrance, break exit, and keyboard-arming clauses as
superseded. D-033 completed that canonical reconciliation without erasing unrelated D-029
capsule, coarse-countdown, focus, or accessibility clauses. The final field, accepted deadline,
focus, every printed declaration shortcut and pointer control appear together; exit is immediate
with no compositor transition or global tint.

The current source is only partially aligned. `VisualResetModel.doneEarlyFromKeyboard()` is
immediate and its “Keyboard Done early is immediate from the first active frame” test proves that
input seam. Movement pointer declarations and Escape are also immediate. In contrast,
`MovementModel` still guards Return, A, P, Q, and 1/2/3 for 0.8 seconds, as proven by “Keyboard
choices remain inert until the declaration guard arms” and “Return A and P are guarded while
pointer declarations remain immediate.”

Presentation is also a shipped conflict, not an aligned seam. Under standard accessibility
preferences, `VisualResetPanel`, `MovementPanel`, and `MergedPanel` resolve their shared
`BreakFieldAnimatedPanel` profile to `frostDissolve`. `DSMotion` makes that entrance 2.69 seconds
and a settled exit 0.94 seconds. `BreakFieldPanelMotionTests` explicitly retains both behaviors.
`VisualResetOverlayCoordinator` constructs its model with countdown-on-open disabled and calls
`VisualResetModel.startCountdown()` only from the panel's entrance-settled callback;
`VisualResetOverlayCoordinatorTests` explicitly requires the countdown to wait for that
settlement. Reduced Motion, Reduce Transparency, static-presentation, and pre-settlement-exit
fallbacks can be immediate, but those exceptions do not make the standard path conform to
D-032's immediate entrance and exit. Therefore D-032 is neither fully shipped nor absent. No
implementation may claim otherwise or choose a convenient hybrid.

These standard frost timings, the visual countdown-settlement gate, and the Movement keyboard
guard are quarantined as **implementation evidence**, not product authority. They must not be
copied into new work as the intended contract. Conversely, D-032 must not be claimed as fully
implemented while these source paths and their retaining tests remain. The canonical source
repair is complete; runtime alignment remains open.

After that canonical repair, the **Break surfaces** collision owner is the single writer across
`BreakFieldAnimatedPanel` and shared panel motion, the `DSMotion`/DesignSystem token seam,
`VisualResetModel`, `MovementModel`, Visual/Movement/Merged panels and overlay coordinators,
Visual Reset countdown start, and the affected Feature and App tests. That owner characterizes
the shipped split before aligning entrance, exit, countdown start, and key arming to one
contract. A feature, overlay, test, or motion-token change may not independently retain or
remove part of this behavior.

The closest applicable `AGENTS.md` wins for scoped implementation and process concerns such
as file placement, package boundaries, test style, concurrency, and required verification.
That local precedence does not authorize any `AGENTS.md` to override the canonical product
semantics, health evidence, claim boundaries, privacy rules, accessibility obligations, or
machine values owned above. A conflict across those concern boundaries follows the
stop-and-reconcile rule rather than whichever file is closest.

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

The owner-approved Calm Ensemble review remains **historical intake** except for the exact
permission-free timing/action/identity/ledger clauses promoted by D-033 and protocol §17. Its
other sensing, permission, privacy, companion, learning, and Labs directions do not override the
claims register, privacy spec, decision log, machine contracts, or shipped behavior by themselves.

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

### D-033 traceability record

| Field | D-033 record |
|---|---|
| Decision | D-033, Accepted from the owner's 2026-09-01 approval of the complete historical review and explicit implementation direction. It clarifies D-032's supersession of D-029's break entrance/exit/key-arming clauses and supersedes only D-022's visible `On hold` label with `Held`; D-022's capsule placement, behavior, and sanctioned sources remain active. No unrelated decision is superseded. |
| Intended purpose and claim | Private general-wellness scheduling for visual resets, movement opportunities, position variety, and optional recovery. `[C033]` estimated use only; `[C034]` no movement verification; no diagnosis, treatment, prevention, posture, gaze, symptom-improvement, or outcome claim. |
| Normative prose | `research/health/03_PRODUCT_HEALTH_PROTOCOL_SPEC.md` §17; `PRODUCT_MODEL.md` §§3, 5–8; `INTERACTION_SPEC.md` §§1–9; `USER_FLOWS.md` F-01–F-14. |
| Machine contract | `machine-readable/timing_runtime_v2.yaml` version 2.0; `product_protocol.yaml.preset_contract_v2`; legacy-read-only mapping in `event_schema.json.x_contract_status`. |
| Behavior owner | Existing `ActivityEstimator`, `ProtocolEngine`, lifecycle reducers, `ProtocolRuntime`, `ProtocolStateStore`, `SwiftDataProtocolStore`, App composition, and existing Features. This story changes none; `CURRENT_STATE_CONFORMANCE.md` assigns each runtime gap. |
| Action and identity | `ClockCycleID`, `OpportunityID`, `ActionID`, `DecisionID`, device/session identity, persistent device counters and causal parents, the canonical phase graph/guards, deterministic nonterminal rank, valid-late terminal rule, total logical terminal order, retained pre-terminal snapshot, and idempotent rebase are defined in the v2 machine contract. |
| Permission | None for this permission-free contract. No entitlement or permission is added. Optional sensor restart remains disabled until its separate permission/claims/privacy/validation story; refusal cannot alter the core. |
| Data lifecycle | No runtime data change in this story. Ten product facts remain distinct. Operational, observation, assessment, decision, correction, and companion ledgers are separate future stores; raw protected buffers are never product facts. |
| Fallback | Honest schedules based on estimated active computer use; awake/active/unlocked coarse sampling, recent input only as movement-clock accrual eligibility, passive-reading visual accrual, zero gap catch-up, exact `elapsed >= deadline` 300-second long-idle and 90-second wake edges, conservative accepted-deadline expiry on monotonic discontinuity, and no gaze/body/position/sensor-completion inference. |
| Accessibility | D-032/D-033 first-frame Escape/⌘./Return/5/2/1–3/Q/A/P and pointer controls; movement offered/running distinction, initial focus/order, VoiceOver timer-not-started/selected-duration states, immediate static equivalent, and existing focus restore, contrast, text-size, equal movement, and multi-display obligations remain. Runtime conflict stays declared. |
| Verification | Machine parity/citation/link checks plus lint, Domain, and Features in Story #19. Runtime stories require RED characterization, retained v1 fixtures, focused reducers, snapshots, real app/device proof, and exact-head gates. |
| Compatibility | V2 presets use new IDs including `custom_v2`; all shipped raw values decode unchanged, with exact payload compatibility for legacy `custom`. No historical identity is invented. Schedule clocks never wall-catch-up. Actions originated after known closure and unknown/duplicate/mismatched actions fail closed; already-originated valid late candidates still reconcile. `event_schema.json` v1 remains decode-only. |

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
- canonical v2 preset IDs, not runtime-activated yet: `calm`, `balanced_v2`,
  `frequent_reset`, `adaptive`, and `custom_v2`. The first four legacy IDs remain decodable at
  exact v1 values; explicit migration successors are owned by
  `product_protocol.yaml.preset_contract_v2.legacy_identifier_disposition`;
- persisted preference tags: `AppPreferences` root keys `formatVersion`, `schedule`,
  `historyRetention`, `content`, `context`, `accessibility`, and `integrations`;
  `SchedulePreferences` keys `profile`, `headsUpEnabled`, and `workingHoursOnly`; explicit
  profile coding keys `kind` and `customTiming` with kind values `gentle`, `balanced`,
  `frequent_movement`, `research_informed_high_frequency`, and `custom`; custom-timing keys
  `visual`, `movement`, `softDueSeconds`, `targetSeconds`, `latestPreferredSeconds`, and
  `durationOptionsSeconds`;
- persisted preference raw values and nested tags: retention integers `0`, `30`, and `90`;
  movement-content values `walkOrEquivalent`, `seatedActive`, `mixed`, and
  `positionChangeOnly`; idle value `resetPresentationTimingOnly`; presentation values
  `standard`, `staticPresentation`, and `textOnly`; timer-announcement values
  `coarseMilestones` and `none`; content keys `preferredMovement`,
  `showsQuickMovementOption`, `includesBreathingContent`, and `standingDeskModeEnabled`;
  context keys `excludedApplicationBundleIDs`, `waitsForLowFrictionMoment`,
  `presentationModeSuppressionEnabled`, and `idleBehavior`; accessibility keys
  `presentation`, `staticOverlayBrightness`, `timerAnnouncements`, and
  `seatedContentFirst`; integration keys `notificationsEnabled`,
  `calendarBusySuppressionEnabled`, `focusFilterEnabled`, and `launchAtLoginEnabled`;
- history-export tags: formats `csv` and `json`; fields `id`, `recordedAt`, `kind`,
  `source`, `opportunity`, and `selectedDurationSeconds`; envelope keys `formatVersion`,
  `fields`, and `records`;
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

`GeneratedProtocolProfiles.swift` is generated from the legacy-compatible `profiles` section of
`product_protocol.yaml` by `scripts/generate-protocol-configuration.sh`. D-033 deliberately adds
the canonical-not-runtime-activated `preset_contract_v2`; Story #19 must prove that this addition
does **not** change generated Swift. The later runtime migration story must add v2 decoding,
retained v1 fixtures, explicit user migration, and regenerated executable values together before
any v2 preset is selectable or shown as active.

For every behavior story, review in this order:

1. accepted decision and owning prose;
2. machine contract and stable IDs;
3. Domain reducer/store contract;
4. App adapters, persistence, and composition;
5. feature projection and localized copy;
6. retained fixtures and verification evidence.

That order prevents executable drift while preserving the rule that only exact-head,
user-path evidence can prove the implementation matches the contract.
