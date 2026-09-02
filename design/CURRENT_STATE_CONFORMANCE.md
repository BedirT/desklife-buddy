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
| Activity estimate | `ActivitySample`, `ActivityEstimator`, `ActivityAssessment`; `SystemActivitySource`; five-second App sampling | **Retain, then amend** | Keep the pure `screenLocked`/system-availability contract and coarse content-free input timing. The production adapter currently reports `screenLocked = false` under DQ-21; amend that App seam if a sanctioned signal becomes available, not the Domain estimator contract. |
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
  grace has elapsed. That is the pure Domain contract. Production
  `SystemActivitySource` deliberately hard-codes `screenLocked = false`; it observes only
  public sleep/wake and session-active notifications, so a simple lock falls back to idle
  behavior and may not arm unlock grace under DQ-21.
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

## Implemented-versus-declared gaps

These are explicit baseline gaps, not silent interpretations of intended behavior. A stored
preference or a pure injectable contract is not evidence that the production App enforces it.
Epic 2 must preserve each distinction until the named collision owner closes it with tests and
real-path proof.

| Contract or surface | What is implemented now | What is not implemented now | Epic 2 collision ownership |
|---|---|---|---|
| Screen lock | `ActivitySample.screenLocked` and `ActivityEstimator.systemAvailable` correctly stop accumulation for an injected locked sample. | Production `SystemActivitySource` reports `screenLocked = false`; DQ-21 documents why public sleep/session signals are not relabeled as lock. | The **Availability/context adapters** zone owns characterization and any sanctioned App signal. Do not weaken or duplicate the pure Domain contract. |
| Manual pause | `ProtocolRuntime.pauseUntil` and `indefiniteSuppression` drive timed, until-resume, and presenting pauses while the process lives; heads-up suppression effects can be persisted separately. | The pause deadline/reason itself is absent from `ProtocolState`, `StoredProtocolState`, and settings payloads, so manual pause does not restore as a durable relaunch contract. | The **Clock/pause persistence** zone owns the canonical pause state, codec migration, restore tests, and status projection before any surface promises persistence. |
| Live context suppressions | `ProtocolRuntime.observe` accepts `activeSuppressions` and `isLowFrictionMoment`; Domain suppression precedence and low-friction handling are injectable and tested. | `AppDelegate.observe` calls `runtime.observe(sample)` with the defaults: empty context suppressions and `false` low-friction evidence. | The **Availability/context adapters** zone owns App adapters and typed evidence into the one runtime/coordinator. Features must not infer suppression independently. |
| Stored context and integration choices | Settings persists and displays `workingHoursOnly`, excluded bundle IDs, presentation-mode suppression, Calendar busy suppression, and Focus filter selections. `waitsForLowFrictionMoment` configures the delivery policy. | The live observer does not fully enforce working-hour boundaries or excluded-app, presentation, Calendar, or Focus signals, and supplies no affirmative low-friction moment. A checked control is therefore not proof of active detection. | The **Availability/context adapters** zone owns capability truth, permission/fallback behavior, and the adapter-to-coordinator path; it must land before stronger Settings/status copy. |
| Accepted/open break time | `VisualResetModel` and `MovementModel` derive countdown progress from monotonic `SuspendingClock` elapsed time after the lifecycle opens, and refresh reconciles directly to that deadline. | Activity, suppression, walking away, overlay occlusion, and ordinary awake inactivity do not pause an accepted countdown. System sleep suspends this clock by definition; there is no separate persisted active-break deadline contract across relaunch. | The **Active-break timebase** zone owns the accepted action/deadline/pause policy and lifecycle tests. Visual, Movement, and Merged surfaces must project that one decision rather than adding local pause rules. |
| D-032 entrance, exit, and keyboard arming | Visual Reset keyboard Done early is immediate from its first active frame and has a focused test; Movement pointer actions and Escape are immediate. The standard Visual, Movement, and Merged panels also inherit `BreakFieldAnimatedPanel`'s `frostDissolve`: a 2.69-second entrance and 0.94-second settled exit from `DSMotion`, both retained by `BreakFieldPanelMotionTests`. Visual Reset disables countdown-on-open and starts its countdown only after entrance settlement, which `VisualResetOverlayCoordinatorTests` requires. | The standard panel motion and delayed Visual countdown start conflict with D-032's immediate entrance/exit baseline; accessibility and pre-settlement fallbacks being immediate does not align the standard path. Movement Return/A/P/Q/1/2/3 remain guarded for 0.8 seconds and focused tests require that conflict too. Canonical `INTERACTION_SPEC.md` and `SCREEN_INVENTORY.md` retain superseded transitions/guards, while the immediate motion table mis-cites D-031. These shipped behaviors/tests are quarantined as implementation evidence, not intended authority: D-032 is only partially implemented and no hybrid may be selected. | Story #19 first reconciles the canonical D-032 clauses and invalid citations. Then one **Break surfaces** owner spans `BreakFieldAnimatedPanel`/shared panel motion, `DSMotion` and its DesignSystem seam, `VisualResetModel.startCountdown`, `MovementModel`, all three panels and overlay coordinators, and affected Feature/App tests. It must characterize and align entrance, exit, countdown start, and key arming as one contract; no token-, test-, feature-, or overlay-local hybrid is permitted. |

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
| Clock/pause persistence | `ProtocolRuntime.pauseUntil`, `indefiniteSuppression`, `ProtocolState`, stored state/codecs | Characterize process-only pause, then add only the canonically approved durable representation and restore behavior | One owner spans Domain state and App migration; status/settings remain projections until it lands |
| Availability/context adapters | `SystemActivitySource`, `AppDelegate.observe`, runtime observation arguments, context/integration preferences | Characterize the hard-coded lock fallback and empty live context, then supply sanctioned typed evidence | App adapters feed one coordinator; no feature-local app, meeting, Focus, Calendar, or lock heuristic |
| Active-break timebase | Visual and Movement models plus Visual/Movement/Merged overlay coordinators and lifecycle reducers | Freeze current `SuspendingClock` deadline behavior, then apply the accepted deadline/pause matrix once | Domain action policy lands before any surface timer changes; no parallel per-overlay policy |
| Persistence migration | `StoredProtocolState`, `StoredOpportunityEvent`, `StoredAppPreferences`, codecs and SwiftData stores | Capture v1 fixture, then versioned migration and deadline metadata | Exclusive App/Persistence ownership; must land before new state is emitted |
| App composition | `AppDelegate+RuntimeInstallation.swift`, `ProtocolRuntime`, `AppOverlayRoute` | Install exactly one coordinator and adapt current routes | Begins only after Domain identity and persistence migration are green |
| Menu/Why-now | `StatusMenu*`, status coordinator, localized copy | Project coordinator Paused/Held/decision state | Feature is projection-only; no policy or clock mutation in view/model |
| Break surfaces | `BreakFieldAnimatedPanel` and shared panel motion; `DSMotion`/DesignSystem motion tokens; `VisualResetModel.startCountdown`, `MovementModel`; Visual/Movement/Merged panels and overlay coordinators; BreakFlow and Completion feature/App coordinators; panel, overlay-coordinator, and Feature model tests | After Story #19 reconciles D-032, freeze the shipped standard frost entrance/settled exit, Visual countdown-settlement gate, and key-arming split in characterization proof; then align all four under the canonical contract before adapting typed actions or removing duplicate lifecycle decisions | One owner spans DesignSystem, Features, and App for this contract; no token-only, test-only, feature-local, or overlay-local transition/countdown/declaration-guard policy; retain shared multi-display and focus seams |
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
