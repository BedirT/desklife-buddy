# Remaining core UI - onboarding, Weekly rhythm, and final break art

Status: complete with remaining live-interaction and multi-display proof gaps
Intake/escalation status: clear; the owner selected Weekly R1/R3 and final break-art family B2

## Outcome

The remaining non-Settings product surfaces become a coherent, native macOS experience. First
launch presents a centered, standalone six-step walkthrough that can be skipped at any point,
uses the already approved rhythm, movement, and accessibility treatments, asks for no
permissions, and leaves the app operating from the menu bar with honest defaults.

Weekly rhythm becomes a user-opened, descriptive reflection only after the owner selects its
dedicated visual direction. The working break fields retain their current behavior while final
visual-reset and movement artwork remains explicitly pending an owner selection; after selection,
one verified art family replaces the working-reference fields across standalone and merged flows.

## Non-goals

- No Settings implementation, redesign, or routing work beyond extracting already approved,
  stateless preference-presentation components without changing their pixels or behavior.
- No production name, logo, wordmark, bundle identity, signing, distribution, account, cloud,
  analytics, network, or new permission.
- No onboarding permission prompts. Notifications remain an in-context request when a heads-up
  first becomes useful; Calendar and Focus remain outside this plan.
- No Weekly score, streak, grade, target line, red/green judgment, week-over-week comparison,
  trend arrow, "best day," fabricated sparse-data insight, or unsolicited Weekly presentation.
- No subjective check-in or WK-05 UI while check-ins remain unauthorized and disabled.
- No change to the exhaustive event vocabulary, clock-reset semantics, suppression policy,
  movement parity, recovery eligibility, or break lifecycle.
- No invented final break-art direction, transparent cutout requirement, asset upscaling passed
  off as a master, or canonical baseline recorded before the owner's selection.
- No custom SVG work for full-field artwork. Owner-provided SVG conversion remains appropriate
  only for a later selected small icon or mark, not an opaque 2880x1800 atmospheric field.

## Open escalations - clear before step 1

- None. The accepted product package and the owner's centered standalone onboarding direction
  are sufficient for onboarding behavior, composition, copy, and verification.

## Staged owner selection gates

These gates do not block onboarding. They stop only the production adoption steps named below.

### Weekly visual direction - further exploration required

- The rendered pending set is W1 editorial bands, W2 heatmap, and W3 quiet timeline. Present those
  three code-native directions using the same deterministic populated, sparse, and
  history-disabled fixtures; do not add another direction unless the owner asks.
- The owner has not selected W1, W2, or W3. Heatmap structure has useful visual qualities, but the
  current set does not yet communicate the intended reflective message clearly enough. Rework the
  information story before asking for a production choice.
- Two Ask User Question attempts returned empty answer payloads, so no selection is inferred from
  either attempt. The rendered set remains pending.
- Do not use generated imagery to make an otherwise judgmental chart feel friendly. The selected
  direction must carry meaning through structure, labels, and native rendering.

### Final break-art family - B2 selected

- The old five break directions are rejected and must not be presented as candidates again.
- The rendered pending set is B1 coastal, B2 interior-valley, B3 paper landscape, B4 botanical
  architecture, and B5 atmospheric ribbons. This plan does not choose among them.
- The owner selected B2 interior-valley on 2026-08-28. Use the generated source
  `exec-d7250cb1-179a-4ce7-8752-f3f00759e07b.png` as the accepted family direction before final
  visual-reset or movement masters are generated, ingested, or recorded as baseline truth. B1,
  B3, B4, and B5 are rejected for production.
- BR-04 is approved independently of the art-family gate: static mode is a softened desktop with
  the same controls in the same positions, no image, and no app motion, at the user-selected
  brightness. It is not a fallback illustration.
- Final field images are opaque/full-bleed. Record generation or source provenance, final-art
  rights, source prompt/tool mode when generated, master dimensions, crop decisions, and every
  derived appearance variant.

## Module boundaries

| Module | Responsibility in this plan |
|---|---|
| `Packages/Domain` | Weekly read models and deterministic aggregation only. No SwiftUI/AppKit, formatting, color, or visual judgment. Existing `AppPreferences` and event semantics remain authoritative for onboarding selections. |
| `Packages/Features/PreferencePresentation` | One product-specific, presentation-only target extracted from the approved Settings UI. Owns the ceramic rhythm-stage resources and stateless rhythm, equal-rank movement, static-presentation, and brightness controls shared by Settings and Onboarding. Depends on Domain, DesignSystem, and FeatureLocalization; owns no store or navigation. |
| `Packages/Features/Onboarding` | `@Observable` walkthrough model, page state, validation, injected commit/activation client, localized copy, centered walkthrough composition, and `#Preview` states for ON-01...ON-07. The client owns no permission capability and keeps durable persistence distinct from runtime activation. |
| `Packages/Features/WeeklyRhythm` | Added only after the owner selects a Weekly direction. Owns the `@Observable` read model, user-initiated window composition, localized formatting, and WK-01...WK-04 Preview states. |
| `Packages/Features/BreakPresentation` | Added only after the owner selects the final art family. Owns the approved visual/movement field resources, their presentation-only renderers, the no-image static field, and the shared variant catalog used by VisualReset, Movement, and BreakFlow. Owns no timer, action, or event logic. |
| `Packages/DesignSystem` | Existing semantic tokens and domain-neutral controls only. It does not own product-specific onboarding cards or final break artwork. |
| `Packages/Features/VisualReset` | Existing visual-reset model and control layout. Consumes the selected DesignSystem field without changing lifecycle, timing, or keyboard behavior. |
| `Packages/Features/Movement` | Existing movement model, equal-rank choices, and control layout. Consumes the selected movement field without changing movement or position semantics. |
| `Packages/Features/BreakFlow` | Existing merged, snooze, acknowledgement, and recovery composition. Uses the same selected fields as the standalone surfaces; it must not copy or independently reinterpret artwork. |
| `App/` | SwiftData/on-disk composition, first-launch decision, atomic onboarding preference commit, standalone centered onboarding window, Weekly query adapter/window route, menu command routing, and real break-field injection. No product logic in scene bodies. |
| `Packages/TestSupport` | Existing deterministic snapshot and Preview-review export helpers only. |

`PreferencePresentation` is deliberately product-specific rather than being pushed into
DesignSystem: its cards contain schedule, movement, and accessibility product nouns. It becomes
a real shared module because Settings and Onboarding both use the same accepted pixels and assets;
duplicate resource copies or a dependency from Onboarding onto the full Settings flow are not
acceptable substitutes.

## Sequence and steps

### Onboarding - executable now

- [x] 1. First-launch and atomic preference contract: write failing App tests first for a fresh
      store opening onboarding, a completed store not reopening it, completion retaining the
      selected rhythm/movement/accessibility preferences atomically, Skip applying Balanced plus
      the ordinary accessible content defaults, cancellation/relaunch resuming safely, and both
      completion paths requesting zero permissions and emitting zero opportunity events. Add only
      the minimal App-owned persisted completion flag and injected client after RED. Done =
      focused rebuilt App tests and `scripts/test.sh Domain` green; gating suites:
      `OnboardingPersistenceTests`, `OnboardingPreferenceApplicationTests`, existing
      `AppPreferencesTests`, and event-store regressions.

- [x] 2. Extract approved reusable preference presentation: create
      `Packages/Features/PreferencePresentation` and move one source copy of the retained ceramic
      stages plus the stateless rhythm-profile, equal-rank movement, static-presentation,
      brightness, and selection treatments it actually needs. Recompose Settings from the shared
      components without changing its model ownership, accessibility identifiers, localization,
      or retained pixels. Add catalog/Preview coverage inside the new target. Done = existing
      Schedule, Break content, and Accessibility snapshot suites compare exactly with no baseline
      recording, `scripts/test.sh Features` green, and focused new component renders inspected.

- [x] 3. Onboarding model first: scaffold the `Onboarding` feature target, then write and observe
      RED tests for the six-page order, Back/Continue boundaries, Skip from every page, Balanced
      initial rhythm, equal-rank movement choices, comfort choices derived from current system
      accessibility values without claiming to change macOS settings, exact completion payload,
      once-only completion, client failure/retry, and no permission capability in the client.
      Implement the `@Observable` model after RED. Done = `scripts/test.sh Features --filter
      OnboardingModelTests` green.

- [x] 4. Preview-first centered walkthrough: declare ON-01...ON-07 `#Preview` states before view
      internals, then build one standalone, centered, ordinary macOS window rather than embedding
      onboarding in Settings or a sidebar. Keep Skip visible on every page and keep the flow under
      six screens/90 seconds. Reuse the approved ceramic stages on ON-03, the same-size and
      same-trait movement choices on ON-04, and the approved presentation/brightness controls on
      ON-05. ON-01/02/06 remain calm code-native copy surfaces; no new illustration is required.
      Cover light/dark, largest text, Increase Contrast, Reduce Motion, Reduce Transparency,
      keyboard focus, completion failure, and skipped/default states. Done = `scripts/snapshot.sh
      --render-only Features OnboardingSnapshotTests` green, every exported PNG inspected and
      presented to the owner, then the narrow intended baselines recorded only after visual
      acceptance.

- [x] 5. App scene and real first-launch proof: compose the real store/client in `App/`, center the
      dedicated onboarding window on the active display, and delay the operating status item and
      clock runtime until completion or Skip exactly as F-01 specifies. The walkthrough remains an
      ordinary closable window rather than a modal lockout; relaunch returns safely to first-launch
      setup until it is completed or skipped. Route both terminal paths into the normal operating
      menu without a permission prompt. Verify Tab/Shift-Tab, arrow-key selection where
      appropriate, Back/Continue, immediate Skip, Command-W/relaunch recovery, successful
      first-launch-to-menu transition, selected-preference persistence, and no second launch.
      Done = `scripts/build.sh`, focused direct App tests, `scripts/run.sh --verify`, a focused
      real-window capture, and `scripts/ui.sh` when host Accessibility permission permits.

### Weekly rhythm - selected direction implemented

- [x] 6. Weekly read contract without pixels: build deterministic representative event fixtures
      spanning populated, sparse/first-week, keep-nothing, suppressed-context, and adjusted-
      schedule cases. Write Domain tests first for descriptive daypart/run/choice/context facts,
      retention boundaries, empty/history-disabled distinction, no app names, no inferred outcomes,
      and no comparison/score fields. Implement value models and an App-owned read adapter only
      after RED. Done = `scripts/test.sh Domain` and focused App query tests green; gating suites:
      `WeeklyRhythmProjectionTests` and `WeeklyRhythmStoreTests`.

- [x] 7. **OWNER SELECTED R1 - named mosaic.** The second visual pass presented five persistent,
      image-backed directions against the same frozen WK-01 through WK-04 fixtures. The owner
      selected R1 named mosaic as the primary rhythm surface and required R3's strict separation
      of retained active-use facts, explicit user choice, and available context.

- [x] 8. Implement the selected Weekly surface: scaffold `WeeklyRhythm`, build only the selected
      direction from Domain read values, keep adjustment framed as fit rather than failure, and
      omit unreachable WK-05. Add light/dark, sparse, history-disabled, largest-text, Increase
      Contrast, no-data-load, and query-failure Previews. Wire a user-initiated ordinary window
      from the status menu; it never appears automatically. Done = focused Feature/Domain/App
      tests, `scripts/snapshot.sh Features WeeklyRhythmSnapshotTests` green with inspected and
      owner-accepted baselines, `scripts/build.sh`, `scripts/run.sh --verify`, focused real-window
      proof, and `scripts/ui.sh` where permitted.

### Final break fields - B2 implementation authorized

- [x] 9. **OWNER SELECTED B2 - final break-art family.** Present the rendered B1 coastal,
      B2 interior-valley, B3 paper landscape, B4 botanical architecture, and B5 atmospheric
      ribbons directions without selecting for the owner. Do not revive the rejected old five.
      Review visual-reset and movement distinctness, light/dark behavior, text-safe bands,
      mobility neutrality, and repetition at the 500th appearance. BR-04 is already approved as
      a softened desktop with the same controls, no image, and no app motion; it is not part of
      this remaining choice. Generate no final master and record no baseline until the owner
      selects. Done = the owner selection and asset-rights status are recorded below. The B2
      source was generated for this private product exploration through the available image
      generation tool; it contains no imported third-party artwork or owner-supplied restricted
      asset. Production provenance and derived-master metadata remain required in Step 10.

- [x] 10. Produce and ingest selected masters: generate or ingest the selected opaque visual and
      movement fields at the required final master size, preserve source/provenance, derive the
      approved light/dark, Increase Contrast, and Reduce Transparency variants, and implement the
      no-image/no-motion static field at brightness endpoints. Create one presentation-only
      `BreakPresentation` target as the source of shared field resources/rendering and reuse it
      from VisualReset, Movement, and BreakFlow. Add component Previews before adoption. Done =
      metadata/dimensions/provenance checks pass, `scripts/snapshot.sh --render-only Features
      BreakPresentationSnapshotTests` and focused VisualReset/Movement/BreakFlow render-only suites
      pass, and original-resolution PNG inspection confirms the 4.5:1 local contrast floor,
      brightest bloom-band safety, warm movement-field heat check, horizon/control alignment, and
      no unintended crop.

- [x] 11. Adopt the selected fields across runtime states: prove BR-02/03/04/09/10/12/13/14...18
      with the same retained control geometry, progress, keyboard, and event behavior. Cover
      standalone visual, every equal-rank movement selection, merged segment transition,
      visual-only acknowledgement, snooze, recovery, bright/dark desktop, all-display and
      secondary-display composition, largest text, Increase Contrast, Reduce Transparency,
      Reduce Motion, and static brightness endpoints. Done = owner inspects the complete matrix,
      the narrow intended baselines are recorded, focused Feature/App tests remain green,
      `scripts/build.sh`, `scripts/run.sh --verify`, and focused `scripts/shot.sh` captures pass;
      external AX/Screen Recording/multi-display gaps are stated rather than inferred.

### Closeout

- [x] 12. Core-UI closeout: run built-UI design, claims, accessibility, privacy, localization,
      static-mode, and prohibited-pattern reviews over Onboarding, Weekly, and the final break
      fields; repair every P0-P2 finding; reconcile ON-01...07, WK-01...04, BR-02...18, and the
      related edge states against real evidence; update their owning plans/inventory only after
      proof exists; run the cheapest sufficient focused checks followed by `scripts/verify.sh`;
      and assemble the required evidence pack with owner selections, exact retained baselines,
      asset provenance, commands, real-window captures, and explicit host-permission gaps.

## Preview and snapshot matrix

| Surface | Required deterministic states before retention |
|---|---|
| Onboarding | ON-01 promise, ON-02 honesty, ON-03 each rhythm selection, ON-04 each equal-rank movement selection, ON-05 standard/static plus brightness endpoints and current Reduce Motion state, ON-06 ready, ON-07 Complete/Skip terminals, completion/Skip persistence submission and failure, completion/Skip activation and recovery, light/dark, largest text including a compact display, Increase Contrast, Reduce Motion, Reduce Transparency |
| Weekly exploration | Each candidate direction renders the identical populated, sparse, history-disabled, and adjust-schedule fixtures; render-only and no baselines before selection |
| Weekly production | Selected populated/sparse/history-disabled/adjust-schedule direction, load/failure, light/dark, largest text, Increase Contrast |
| Final break fields | Visual running/final seconds/static, movement 5/2 minute and every equal-rank path, merged visual/movement/visual-only, snooze, recovery, acknowledgement, bright/dark desktop, light/dark appearance, IC/RT/RM, largest text, static brightness endpoints, secondary/all-display composition |

## Real-flow proof matrix

| Flow | Required proof |
|---|---|
| Fresh launch | Centered standalone walkthrough appears; no permission sheet, operating status item, or advancing clock appears before completion/Skip |
| Complete onboarding | Chosen rhythm/movement/comfort preferences persist atomically; normal menu operation begins; relaunch does not reopen onboarding |
| Skip onboarding | Works from every page; Balanced and ordinary accessible defaults apply; no penalty, follow-up nag, permission request, or event |
| Weekly | Opens only from the user's menu action; populated/sparse/history-off state matches retained data; adjustment routes to Settings without failure framing |
| Break fields | Menu/capsule/notification routes open the selected field; Escape and declared actions retain the same facts; merged/snooze/recovery transitions use one art family; static mode uses no image/motion; focus restores correctly |

## Decision log

- 2026-08-28: Onboarding is a centered standalone walkthrough, not a Settings section, popover,
  sidebar, or full-screen takeover. This owner direction is executable without another shell
  exploration.
- 2026-08-28: Onboarding reuses the approved ceramic rhythm stages, equal-rank movement choices,
  and accepted accessibility treatments. It does not commission a separate illustration set or
  reinterpret those controls.
- 2026-08-28: The feature model has six ordered pages and one unranked type containing all four
  movement choices. Balanced is the initial rhythm. Reduce Motion derives Static as the initial
  app presentation; Reduce Transparency and Increase Contrast remain read-only injected system
  facts for the future comfort screen. The user can change app presentation without changing any
  macOS setting.
- 2026-08-28: The isolated onboarding client exposes only completion with the exact selected
  preference payload and Skip. It has no permission, integration, event, network, or system-
  setting mutation capability; App composition remains deferred to the real-flow step.
- 2026-08-28: Product-specific shared preference cards live in a narrow Feature-package target,
  not Domain or DesignSystem, and retain one copy of the approved assets. Settings keeps model
  ownership; Onboarding owns its flow.
- 2026-08-28: `PreferencePresentation` now owns the single reusable copy of the three approved
  ceramic rhythm stages and the stateless rhythm, equal-rank movement, presentation, brightness,
  and selection treatments. Settings was recomposed through those components without changing
  its model or copy ownership. Schedule produced 44 exact retained renders, the retained Schedule
  explorations produced 20 exact renders, Break content produced 20 exact retained renders, the
  complete Features logic suite passed 185 tests, and the new component catalog's two render-only
  appearances were inspected without recording a baseline.
- 2026-08-28: The narrow `staticMaximumBrightnessDark` baseline repair was authorized after the
  original Accessibility design was confirmed visually unchanged. Recording with the exact test
  filter reproduced the retained `ddf03174...` image and passed its immediate verification; an
  ordinary process can instead render the byte-stable `2a5db376...` variant. The helper now asks
  for dark appearance only. The two variants differ by exactly 1,006 pixels inside the native
  slider-thumb box at `(1661, 827)`, size `70 x 57`, with a maximum channel delta of `4/255` and
  no pixels outside that box. Post-extraction verification emitted the same `2a5db376...` hash and
  exact box, so this remains a documented native-control/process-rendering exception rather than
  product pixel drift; no tolerance was weakened and every other retained Settings render
  compared exactly.
- 2026-08-28: Selected break-field resources likewise live in a presentation-only Feature target,
  not DesignSystem. The three break flows share one art implementation without moving lifecycle
  behavior out of their owning features.
- 2026-08-28: Weekly W1 editorial bands, W2 heatmap, and W3 quiet timeline were rendered, but the
  owner withheld selection. Heatmap has promising visual structure, while the current concepts do
  not yet convey the intended reflective message. The next pass must improve the information
  story and present its images directly inside a persistent visual-review board.
- 2026-08-28: The old five break directions remain rejected. From the new set, the owner selected
  B2 interior-valley for production and rejected B1 coastal, B3 paper landscape, B4 botanical
  architecture, and B5 atmospheric ribbons. The accepted generated source is
  `exec-d7250cb1-179a-4ce7-8752-f3f00759e07b.png`.
- 2026-08-28: BR-04 static is approved as a softened desktop with the same controls in the same
  positions, no image, and no app motion. It is no longer coupled to the final-art selection gate.
  Existing working gradients remain valid behavior/snapshot fixtures but cannot become canonical
  final art.
- 2026-08-28: Final break fields are opaque/full-bleed. Transparent-background generation is not
  required for a surface that replaces the entire field.
- 2026-08-28: B2 production uses four distinct, opaque interior-to-valley fields: a distant
  outlook for Visual Reset, an accessible promenade for Walk or Wheel, a circular floor bay for
  Small Space, and an integrated curved ledge for Seated. The generated sources, exact prompts,
  hashes, dimensions, centered 8:5 delivery crops, and 2880 x 1800 RGB delivery resources are
  retained in `design/assets/break-fields/`. The generator returned sources below delivery size,
  so provenance identifies the 2880 x 1800 files truthfully as resampled delivery derivatives
  rather than freshly generated masters. `BreakPresentation` owns image/accessibility derivation
  and the no-image Static field; no motion manifest is needed for these static assets. Light and
  dark now derive visibly different hours from the same composition while retaining white,
  contrast-safe break chrome. Largest text keeps all three movement choices in one equal-rank
  row. Standard panels rise one screen height with a 60%-to-100% brightness ramp in 0.28 seconds
  and depart downward in 0.24 seconds; Reduce Motion crossfades without travel in 0.40 seconds;
  Static has no app motion. The repo-native component suite exported 9 renders, the focused
  VisualReset/Movement/BreakFlow suite exported 99 renders across 56 passing tests, asset metadata
  tests passed, 12 focused App motion/overlay tests passed, and the app build and lint passed.
  Original-resolution inspection covered each semantic field, light/dark, Increase Contrast,
  Reduce Transparency, Static, largest text, acknowledgement, and recovery. A two-layer standard
  veil gives a theoretical worst-case white-copy contrast floor of 5.27:1 even over a white source
  pixel. A later `scripts/run.sh --verify` attempt was blocked outside this work by
  the concurrently added WeeklyRhythm target referencing a missing `Resources` directory; Step 11
  retains real-process and owner matrix acceptance.
- 2026-08-28: Onboarding Step 4 declared ON-01 through ON-07 Previews before view internals, then
  implemented one centered six-page Feature-owned walkthrough with visible Skip, shared ceramic
  rhythm stages/equal-rank movement/Standard-Static-brightness components, read-only system
  accessibility facts, deterministic completion failure/retry, and no permission capability.
  The render-only matrix exports 30 distinct images across light/dark, largest text, Increase
  Contrast, Reduce Motion, Reduce Transparency, keyboard focus, every selection, completion
  failure, and Skip/default. All were inspected locally and then at original resolution by the
  owner, who accepted the centered walkthrough and shared control language. The exact
  `OnboardingSnapshotTests` filter recorded 30 intended baselines and its immediate ordinary
  comparison passed all 30 with no tolerance change. App scene centering, close/relaunch, and
  real focus proof remain Step 5.
- 2026-08-28: Weekly read input keeps already-estimated active-use runs separate from exhaustive
  opportunity events so no run or outcome is inferred from prompt history. Frozen populated,
  sparse, empty, history-disabled, and adjusted-schedule fixtures project descriptive daypart,
  longest-run, exact event, explicit user-choice, and privacy-minimized context facts only; the
  report exposes no application-name, comparison, score, grade, streak, or outcome field. The
  context facts retain exact deferral reason plus local daypart. Wall-clock `DateComponents`
  boundaries pass Vancouver spring-forward nonexistent-time and fall-back repeated-time cases,
  while overlapping or duplicate active-use runs are normalized before totals. The full Domain
  suite passed 127 tests including all 10 `WeeklyRhythmProjectionTests`, and the isolated App-
  owned persisted-read adapter passed all 4 `WeeklyRhythmStoreTests`.
- 2026-08-28: Onboarding Step 5 adds the completion model to the production SwiftData schema and
  gates only genuinely fresh installs. Stores with pre-onboarding preferences, state, or events
  receive one durable `existingInstall` marker without changing those facts. A fresh launch owns
  a centered 1000 x 700 ordinary closable window on the active display; Settings, status item,
  clock runtime, Heads-Up lifecycle, permission-capable delivery, protocol state, and events stay
  absent until Complete or Skip persists atomically. Both terminal paths then create normal
  operation from a fresh context over the same container. Reset All preserves the terminal marker.
  The App test target builds for testing; direct hosted-independent execution passed all 8
  persistence and all 3 preference-application tests. The normal Xcode App test launcher remained
  stuck before test execution on this host, while standalone `xctest` cannot execute tests that
  install an AppKit status item, so that host limitation is not represented as green. Real signed
  routes compensate at the user boundary: fresh, exact selected completion, and Skip captures all
  passed. Fresh state proved frame `[256, 156, 1000, 700]` centered in visible frame
  `[0, 64, 1512, 885]`, zero completion/state/events, and no runtime, status item, or Heads-Up
  lifecycle. Complete and Skip each proved the expected marker/preferences, cleared window,
  installed runtime/status item, and no onboarding event. The one subsequent
  `likelyNaturalInterruption` / `systemContext` fact is generated only after normal runtime starts.
  `scripts/build.sh`, `scripts/run.sh --verify`, and `scripts/lint.sh` passed. `scripts/ui.sh`
  remained blocked by missing host Accessibility permission; no permission prompt was requested.
- 2026-08-28: Post-review onboarding recovery now treats durable commit and runtime activation as
  separate phases. A successful commit reloads authoritative stored choices, locks every setup
  mutation and navigation path, and activation retry never rewrites those choices. Relaunch after
  a completed or skipped marker reconstructs the same locked recovery state when runtime startup
  fails; an `existingInstall` startup failure remains an ordinary App error. Rhythm timing copy is
  injected from the generated YAML-backed configurations and preserves fractional minutes.
  Movement arrow navigation follows the visible 2 x 2 grid (or the largest-text vertical list).
  Titled-window layout now accounts for chrome, clamps both content and its minimum to the active
  display, and the walkthrough card responds to compact content sizes. Eight new dynamic states
  render in light/dark plus one compact largest-text state; 17 narrowly filtered baselines were
  inspected before recording, and all 47 onboarding renders then compared without tolerance
  changes.
- 2026-08-28: Step 1 is complete after the final atomic-commit repair. Completion and Skip now
  return the authoritative resolved onboarding value from the same save operation instead of
  reconstructing it afterward. A reload-trap App test corrupts only the isolated test payload
  after the acknowledged save: a second decode demonstrably fails while onboarding still reaches
  the exact committed terminal state and activates once, proving no post-save reconstruction is
  involved. Direct App execution passed 12 onboarding persistence/recovery/composition tests;
  `scripts/test.sh Domain` passed 127 tests in 16 suites; full Features passed 199 tests in 31
  suites; build-for-testing, the signed build, `scripts/run.sh --verify`, lint/localization, and
  `git diff --check` passed. The hosted App test worker limitation remains documented and no
  permission, entitlement, event, or network scope was added.
- 2026-08-28: The owner selected Weekly R1 named mosaic and R3's strict fact separation for
  production. The Feature renders one uniform-accent, named daypart mosaic from retained estimated
  active-use runs, one exact longest-run fact, and separate groups for recorded opportunities,
  explicit user choices, and privacy-minimized available context. Open cells explicitly deny any
  movement or break inference. The ordinary Weekly window opens only from the explicit status-menu
  action, Schedule and history actions select their exact Settings destinations, and WK-05 remains
  absent. The generated ceramic-paper background is retained at
  `Packages/Features/Sources/WeeklyRhythm/Resources/weekly-rhythm-field.png`; its source hash,
  prompt, rights status, crop, and decorative accessibility treatment are recorded in the adjacent
  provenance plist. The focused Feature model suite passed 6 tests, the App Weekly suites passed
  10 tests, the full Domain suite passed 128 tests, and all 9 intended Weekly baselines passed an
  immediate exact comparison. Build, launch verification, localization, preview, reduced-motion,
  motion-asset, and lint gates passed. Real menu activation and AX-tree inspection remain
  host-blocked because `scripts/ui.sh` lacks macOS Accessibility permission.
- 2026-08-28: Steps 11 and 12 are complete with the host gaps stated explicitly.
  Domain passed 128 tests in 16 suites, Features passed 208 tests in 33 suites, and the directly
  executed built App test bundle passed 447 tests in 60 suites. The signed build and
  `scripts/run.sh --verify` passed, and lint completed with `LINT OK`. Onboarding, Weekly,
  Privacy, and the B2 break matrix have inspected retained renders and focused interaction proof.
  After the owner granted Accessibility permission, `scripts/ui.sh` passed and retained the live
  status item, due-state description, Weekly rhythm action, Settings action, and menu geometry in
  `artifacts/ui.txt`. Focused real-app captures then passed for Visual Reset, Movement, merged
  flow, snooze, and the both-due status menu. After the owner also granted Screen Recording,
  surrounding desktop captures revealed that the auto-hidden Dock could cover the lowest controls.
  A shared 96-point foreground exclusion now keeps Visual Reset, Movement, and Recovery content
  above system chrome while their atmospheric fields remain full-screen. The owner then clarified
  that the Dock must not be visible during a break at all. Native Dock suppression now begins
  before the first break panel appears, spans every display, and restores the exact prior
  application presentation options after the final panel closes. Focused
  regression tests were observed red against the old fractions, then the full Features suite
  passed 211 tests in 33 suites. Native save-panel selection, automated Weekly menu activation,
  focus restoration, and multi-display automation are not claimed as verified. The normal hosted
  App test launcher also stalls before execution on this host;
  three host-only AppKit scene suites are excluded from the direct `xctest` result.
  The evidence handoff is retained at
  `artifacts/reviews/core-ui-closeout-2026-08-28.md`.
- 2026-08-28: Owner motion review rejected the cross-dissolve, hard iris, and radial frost
  directions. The accepted implementation now frosts the whole live desktop over 1150 ms, holds
  without break content for 200 ms, cross-fades to a materially blurred B2 field over 750 ms, then
  sharpens the field over 1100 ms. Instructions and controls animate independently during the
  sharpening stage, and the lighter single-scrim presentation keeps the approved art visible.
  Reduce Motion keeps an 800 ms travel-free dissolve, Reduce Transparency uses an opaque tokenized
  cover, and exit dissolves back over 450 ms. Focused motion, menu-launch, keyboard, and Dock
  lifecycle tests passed. The real native status-menu route produced
  `artifacts/manual-status-break-entry.mov`; its contact sheet at
  `artifacts/manual-status-break-entry-sheet.png` proves progressive whole-screen frost, the
  blurred field, sharpening, independent foreground arrival, and a hidden Dock with no radial
  geometry or black frame.
