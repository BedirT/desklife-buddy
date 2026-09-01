# Current-State Conformance

Status: audited implementation inventory

Exact clean baseline: `e6e9ca094cfbbee50f1d554be6640653f85caf2d`

Audit date: 2026-09-01

Authority rules: [AUTHORITY.md](AUTHORITY.md)

This inventory is the clean-baseline handoff for the Calm Ensemble campaign. It
describes the code that exists at the exact commit above, not the protected owner
checkout and not a proposed architecture. It changes no product semantic.

Classification terms:

- **Retain**: use the existing type or surface as the implementation seam.
- **Amend**: extend the existing owner without creating a parallel engine or screen.
- **Migrate**: preserve existing facts while moving to a versioned replacement.
- **Replace**: remove the old implementation only after the replacement is proven at
  its callers and persistence boundary.
- **Unrelated**: harness/example residue; do not use it as product architecture.

## Implemented product baseline

| Area | Existing production seam | Classification | Campaign rule |
|---|---|---|---|
| Activity estimate | `ActivitySample`, `ActivityEstimator`, `ActivityAssessment`; `SystemActivitySource`; five-second App sampling | **Retain, then amend** | Keep coarse content-free input/system availability and injected monotonic elapsed time. Add evidence inputs through typed seams, not a second activity loop. |
| Scheduling clocks | `ProtocolEngine`, `OpportunityClockState`, `ProtocolState`; independent visual and movement counters plus recovery debt | **Amend** | The future Opportunity Coordinator must be a behavior-preserving evolution around these reducers. Do not build another scheduler beside them. |
| Suppression | `SuppressionResolver`, `SuppressionReason`, `ProtocolRuntime.currentSuppression` | **Amend** | Reconcile Paused versus Held and richer context in this precedence path. Preserve a single resolved delivery decision. |
| Opportunity selection | `ProtocolEngine.recommendedPresentation()` and `OpportunityPresentation` | **Replace through seam** | Move arbitration into the one coordinator only after characterization tests. Remove the old selector when all App callers use the new output. |
| Event facts | `OpportunityEventKind`, `OpportunityEventSource`, `OpportunityType`, `OpportunityEvent`, `OpportunityEventStore` | **Migrate** | Preserve all ten facts and raw values. Add separate identities/decision facts without recasting old rows as outcomes. |
| Lifecycle reducers | `ProtocolEngine.record`, event-effect extensions, `MovementLifecycleEvent`, `MergedLifecycleEvent`, `BreakFlowAction` | **Amend, then consolidate** | Freeze current mappings with tests, introduce stable typed actions, and route standalone/merged behavior through one canonical reducer. |
| Runtime transaction boundary | `ProtocolRuntime`, `ProtocolLifecycleGate`, `persistProtocolMutation`, `SwiftDataProtocolStore.commit` | **Retain, then amend** | Keep injected wall clock/ID generation and atomic event/state commits. Coordinator mutations must pass this boundary. |
| Protocol persistence | `StoredProtocolState`, `StoredOpportunityEvent`, `StoredEstimatedActiveUseRun`, `SwiftDataProtocolStore` | **Migrate** | Capture version-1 fixtures first. Version identity/deadline/ledger changes without inventing historical facts. |
| Preferences | `AppPreferences`, `SchedulePreferences`, `SettingsPayloadCodec`, `StoredAppPreferences`, `SwiftDataSettingsStore` | **Retain, then migrate** | Extend the versioned preferences contract and atomic state/profile commit. Do not fork sensor or schedule settings into an unrelated store. |
| Machine profiles | `product_protocol.yaml` -> generator -> `GeneratedProtocolProfiles.swift` -> `ProtocolProfiles` | **Retain** | YAML owns current closed values. Later preset changes start in the canonical machine contract and regenerate Swift. |
| Heads-up delivery | `HeadsUpDeliveryReducer`, persisted `HeadsUpDeliveryState` identity/action vocabulary, `HeadsUpLifecycleCoordinator`, capsule/notification adapters and their OS identifiers | **Amend** | Reuse and preserve delivery identity, reservation, cancellation, response, and recovery seams; adapt them to coordinator opportunity/action identity rather than duplicating delivery. Audit every serialized and OS-facing identifier before migration. |
| Menu-bar and Dock | `StatusMenuModel`, `StatusMenuAction`, `StatusItemCoordinator`, `DockMenuController` | **Amend** | Project Paused/Held/Why-now from coordinator state. Features return typed actions and do not own scheduling. |
| Visual reset | `VisualResetModel/View`, `VisualResetOverlayCoordinator`, `VisualResetPanel` | **Amend** | Preserve the proven multi-display/AppKit boundary; replace only its lifecycle input/output with canonical opportunity actions. |
| Movement | `MovementModel/View`, `MovementOverlayCoordinator`, `MovementPanel` | **Amend** | Preserve equal-status choices and presentation proof. Duration choice and terminal semantics must be reconciled in the Domain reducer. |
| Merged break | `MergedOverlayCoordinator`, `MergedPanel`, merged lifecycle queue | **Amend, then simplify** | Characterize current visual-to-movement choreography; remove duplicate action semantics after the canonical reducer owns both. |
| Snooze/recovery flow | `BreakFlowModel/View`, `BreakFlowOverlayCoordinator` | **Amend** | Reuse the existing sheet/field boundary; bind it to stable opportunity/action identity and coordinator policy. |
| Completion acknowledgement | `CompletionCapsuleCoordinator` and `CompletionCapsuleView` | **Amend** | Keep as presentation only. It must never choose terminal outcome or reset clocks independently. |
| Settings | `SettingsFeatureModel/View`; Schedule, Break content, Context & exclusions, Accessibility, Privacy & data, Integrations, Why these defaults, and Safety & support; `SettingsSceneModel`; App adapters | **Amend** | Extend the existing Settings navigation and permission-at-value pattern. New sensing controls require the canonical permission/data contract first. |
| Onboarding | `OnboardingModel/View`, persistence and window composition | **Amend when needed** | Keep the existing optional local setup; do not bundle future protected permissions into first launch. |
| Weekly | `WeeklyRhythmProjection`, `WeeklyRhythmModel/View`, `WeeklyRhythmStore` | **Amend** | Extend the projection from distinct factual ledgers. Preserve provenance and patterns-not-grades. |
| History/data controls | `HistoryRetentionPolicy`, `HistoryExport`, Settings Privacy flows, delete/reset/export store APIs | **Amend, then migrate** | New ledgers must join retention/export/deletion deliberately; raw sensor buffers remain outside persisted history unless separately authorized. |
| App composition | `AppDelegate.startApplication/install/restore`, `AppOverlayRoute`, settings/weekly/onboarding presentation | **Retain, then amend** | App remains the only construction root for real stores and Apple adapters. One coordinator instance is installed here. |
| Verification | Domain and App seam tests; feature Previews/snapshots; `build.sh`, `run.sh --verify`, `ui.sh`, `shot.sh`, `verify.sh` | **Retain and extend** | Each new state gets deterministic tests and exact user-path proof at the repository's required rung. |
| `Item`, `ItemStore`, `ItemList`, `StoredItem`, `SwiftDataItemStore` | Template worked example and legacy cleanup path | **Unrelated** | Do not extend these for health-companion behavior. Remove only in a separately scoped cleanup after no harness consumer needs them. |

## Current behavior facts future stories must preserve or supersede explicitly

- The estimator accumulates only while the system is awake, the session is active,
  the screen is unlocked, recent input is inside the configured window, and wake
  grace has elapsed.
- Long idle emits `likelyNaturalInterruption`; it does not record movement. Current
  reducer behavior changes presentation phase but does not erase either accumulated
  counter.
- Visual and movement clocks persist separately. Recovery eligibility and deferral
  debt are separate fields, not a combined score.
- Protocol restoration never catches up unobserved wall-clock activity; restored
  clocks return in a non-interrupting grace or snoozed phase.
- Lifecycle mutations build event drafts, assign injected wall time and UUIDs in the
  runtime, then commit events, state, and estimated-use run through one SwiftData
  transaction boundary.
- The closed ten-event vocabulary records facts without a generic success/outcome
  field. Position change remains distinct from movement completion.
- Current cycle IDs exist for visual and movement clocks and heads-up deliveries have
  UUID identity. There is not yet a durable, general `OpportunityID` or `ActionID`.
- Settings persist the resolved configuration beside preferences so custom and
  built-in schedule state can restore consistently.
- The App already presents status/Dock menus, heads-up capsule and notification,
  visual, movement, merged, snooze/recovery, completion, Settings, onboarding, and
  Weekly surfaces. These are implemented product surfaces, not mock screens.

## Epic 2 collision map

Epic 2 is intentionally serialized until the coordinator contracts land. The paths
below are collision zones: one story owns a zone at a time, and every later story
branches from the merged predecessor.

| Collision zone | Existing paths/types | First permitted change | Serialization boundary |
|---|---|---|---|
| Trust regression characterization | `Packages/Domain/Tests/DomainTests/ProtocolEngine*`, `MovementProtocolSemanticsTests`, App runtime tests | RED reproduction of away/movement followed by stale visual delivery | Tests only until the failure is observed; no reducer edit in the repro commit |
| Coordinator seam | `ProtocolEngine*.swift`, `ProtocolStateStore.swift`, `ProtocolRuntime*.swift` | Behavior-preserving command/output facade over current engine | One Domain/runtime writer; no persistence or UI rewrite in the same story |
| Stable identity/action reducer | `OpportunityEvent.swift`, lifecycle reducers, heads-up delivery types | Add versioned cycle/opportunity/action identity and idempotent terminal reduction | Lands before persisted schema, companion transport, or Why-now UI |
| Clocks, presets, Pause/Held | `ProtocolConfiguration.swift`, `SchedulePreferences.swift`, `SuppressionResolver.swift`, YAML/generator | Canonical action/reset matrix and approved preset/hold contract | Machine/prose canonicalization precedes executable values; no duplicate clock |
| Persistence migration | `StoredProtocolState`, `StoredOpportunityEvent`, `StoredAppPreferences`, codecs and SwiftData stores | Capture v1 fixture, then versioned migration and deadline metadata | Exclusive App/Persistence ownership; must land before new state is emitted |
| App composition | `AppDelegate+RuntimeInstallation.swift`, `ProtocolRuntime`, `AppOverlayRoute` | Install exactly one coordinator and adapt current routes | Begins only after Domain identity and persistence migration are green |
| Menu/Why-now | `StatusMenu*`, status coordinator, localized copy | Project coordinator Paused/Held/decision state | Feature is projection-only; no policy or clock mutation in view/model |
| Break surfaces | Visual, Movement, Merged, BreakFlow and Completion feature/App coordinators | Adapt typed actions and remove duplicate lifecycle decisions | One surface family at a time; retain shared multi-display and focus seams |
| Weekly/history | Domain Weekly/history projection, `WeeklyRhythm*`, Settings Privacy/export | Project distinct old and new facts with provenance | Starts after ledger/schema compatibility; never reinterpret v1 rows |
| Full verification | App tests, feature snapshots, runtime probes and scripts | Add deterministic identity/relaunch/clock-gap/user-path proof | Exact-head final gate after all collision zones; no baseline weakening |

### Epic 2 import and replacement rules

1. Begin from the merged commit containing this audit, never from an uncommitted
   checkout.
2. Name the current type/store/runtime being extended or replaced in every claim.
3. A replacement must include characterization proof, caller migration, persisted
   compatibility, and removal of the displaced production path. Keeping both engines
   active is a blocking defect.
4. Preserve the version-1 disk fixture before writing migration code.
5. Do not combine coordinator replacement, schema migration, and surface redesign in
   one story.
6. Treat `Item`/`ItemList` changes as unrelated cleanup, not an Epic 2 dependency.
7. Root/integration serializes exact-head review, merge, and cleanup even when
   non-colliding research or visual work runs in parallel.

## Audit evidence map

| Contract | Source proof | Verification seam |
|---|---|---|
| Independent clocks and deterministic reductions | `ProtocolEngine.swift`, `ProtocolEngine+EventEffects.swift`, `ProtocolEngine+Movement.swift` | Domain engine invariant, timing, movement, and suppression tests |
| Ten distinct facts and raw IDs | `OpportunityEvent.swift`, `SwiftDataProtocolStore.swift` | opportunity-event and SwiftData event-store tests |
| Restart-safe state and no wall catch-up | `ProtocolStateStore.swift`, `ProtocolRuntime.restore`, persisted state codec | protocol-state fixture, runtime restore, and legacy store tests |
| Atomic runtime/store mutation | `ProtocolRuntime.persist`, `SwiftDataProtocolStore.commit` | runtime failure/rollback and persistence seam tests |
| Implemented operating surfaces | Feature package targets plus App coordinators/panels/windows | Preview/snapshot suites, App route/coordinator tests, real-app probes |
| Settings/data controls | `AppPreferences`, Settings feature/App adapters, SwiftData settings store | settings model/store/history/privacy tests and snapshots |
| Weekly factual projection | `WeeklyRhythmProjection`, App weekly store, Weekly feature | Domain projection, App store/route, feature model/snapshot tests |
| Retained repository gate | `scripts/verify.sh` and direct build/run/UI/snapshot scripts | exact command receipts at the story's required verification rung |
