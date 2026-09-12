# Epic 5: Context Sense + Conversation Shield — plan

Status: draft (plan only — zero implementation).
Base: `d04e076f` (= origin/main). Main checkout clean except untracked `WATCHDOG.yml` (ignored).
Spec: `gh issue view 6` (full body = frozen spec; labels: epic, health-companion,
owner-approval-gate, privacy-gate, research-gate). Parent: #1 (review order only).
Blocked by: #4. Delivery after #5 is review order, not a technical dependency.
Intake/escalation status: spikes + owner approvals pending (see gaps below).

## Outcome

A call/presentation/focus-aware Mac core that protects likely calls, presentations, and
timed focus without inspecting their contents and without claiming universal meeting
detection. When done: explicit manual meeting/presenting/timed-focus modes (with App
Intents/Shortcuts) work permission-free; selected Calendar busy/free, live
frontmost-app rules, and Focus-filter state feed sanitized adapters that retain no
titles, attendees, IDs, window titles, or history; layered fusion with declared
independence groups runs in shadow then suggest before any separately-consented bounded
auto-hold; every hold carries cap, expiry, visible sources, one-action release,
source-disable, and a landing corridor; `Not a call` releases promptly; correction,
back-to-back protection, one merged post-context opportunity, and Why-now explanations
close the loop; compatibility, fairness, accessibility, and copy gates are proven on
hardware. The permission-free Mac core (Epics 1–2) and the Epic 3 trust platform keep
working with every permission denied and every source off.

## Non-goals

- No audio/video capture, transcription, titles, attendees, content, private API,
  process-memory inspection, or Control Center scraping — ever, in any story including
  spikes.
- No second pause/hold reducer: all context assessments flow through the Epic 3 trust
  seams into the one `SuppressionResolver` / coordinator path. Manual state from #3
  always wins and works permission-free.
- No health-outcome inference from a product or sensor fact, ever; no communication,
  disability, attention, or productivity inference, ever.
- No production Calendar access before the owner approves it (family 2 gate); no
  entitlement strings, privacy-manifest text, bundle-ID or signing changes in-story
  (owner stops, same rule as Epic 3 stories 6/8/9).
- No new product-fact vocabulary: context produces assessments/decisions in the Epic 3
  ledgers, never `OpportunityEvent` facts; no completion marking, no reminder-frequency
  or loudness increase beyond the chosen schedule.
- No universal-meeting-detection copy or behavior anywhere.

## Epic 3 seams this epic builds on (read first)

Landed at `d04e076f` per `docs/plans/2026-09-12-epic3-trust-platform-plan.md`:

- Capability registry + revocable leases (story 2): every context source registers as a
  compile-time provider; leases bind scope revision + epoch; revocation invalidates live
  evidence immediately.
- Evidence bus + deterministic fusion (story 3): typed, bounded, expiring in-memory bus
  (source, quality, freshness, confidence, coverage, independence group, failure
  reason). Correlated signals cannot inflate confidence. Unknown-never-negative is
  pinned (`EvidenceFusionTests.unknownNeverNegative`).
- Closed policy firewall (story 4): the sole evidence-to-behavior bridge; emits only
  closed Coordinator commands. Weak-evidence bounds pinned; no-provider-mutation pinned.
- Ledgers (story 5): separate versioned observation / assessment / scheduling-decision /
  correction / consent-receipt / companion-action stores (SwiftData, additive-only,
  fail-closed). Corrections replayable with undo.
- Permission broker + consent + kill switch (story 6): JIT education, separate
  sensing/effect consent, receipts, revocation within a measured deadline.
- Trust center + inspector (story 7): Sensing & Intelligence center, live inspector,
  receipts, Stop/revoke guidance, export/delete. F-20–F-23 flows live here.
- Raw-import guards (story 1): build fails if raw classes reach Domain/persistence/
  logs/export/transport/prompts. Epic 5 extends the guard list (titles, attendee data,
  window titles), never weakens it.

## Domain seams this epic extends (characterize first, then amend)

- `SuppressionReason` / `SuppressionResolver` (`Packages/Domain/Sources/Domain/`):
  current cases are `manualPause, systemInactiveOrLocked, explicitPresentationMode,
  focusFilter, calendarBusy, excludedApplication, outsideWorkingHours, snooze,
  lowFrictionWait` with Pause policy only for pause/locked/outside-hours. Missing:
  user-declared meeting/call, user-declared presenting/sharing, user-selected timed
  task, inferred-likely-call — the INTERACTION_SPEC §7 precedence names them and story
  1 adds them as additive cases (stable-identifier rules: never rename existing raws).
- `ProtocolRuntime` observation path (`AppDelegate.observe` currently passes empty
  context suppressions by default) + `SystemActivitySource` (public sleep/wake/session
  signals only) + `SettingsExcludedApplicationsAppAdapter` /
  `SettingsIntegrationsAppRuntime` (existing adapter pattern to copy).
- Status menu MB-12 (F-08: 30 min / 1 hr / Until… / Until tomorrow / While presenting)
  and MB-04 Paused/Held projection; Why-now (F-19); correction flows (F-21).
- No App Intents exist yet (`AppIntent`/`AppShortcuts`: zero matches) — story 1
  introduces the first intents; no prior surface to migrate.

## Stories (one branch/PR/worktree each; serialize on shared Domain/schema seams)

Suggested direction only — orchestrator may re-cut, but this order is load-bearing:
manual modes first (permission-free value, no owner gate), spikes before adapters
(public-API limits proven before production code), fusion in shadow/suggest before any
automatic effect, separately-consented bounded auto-hold last.

### Story 1 — Permission-free manual modes + App Intents (family 1)

Branch: `agent/epic5-manual-modes`. Seam: `SuppressionReason` (+ additive
user-declared cases) → `SuppressionResolver` precedence → `ProtocolRuntime` observe
path → MB-12/MB-04 menu projection → first App Intent definitions.
Work: explicit manual meeting / presenting-or-sharing / timed-focus modes with explicit
expiry (manual hold has explicit expiry per blocking amendment); one-click resume +
90 s quiet corridor (F-08); first App Intents + Shortcuts (start/end each mode;
no sensor input, pure user declaration); selected Focus-filter intent plumbing only
where the public API permits, otherwise manual declaration covers it; honest copy
from birth ("You marked…", never "detected"). RED first:
`ManualContextHoldTests.manualMeetingModeHoldsWithoutFreezingClocks` — manual meeting
mode resolves to a Held reason with `.continue` accumulation (need clocks keep
accruing), explicit expiry present, manualPause still outranks it, clearing it
restores presentation. Snapshot rung for the MB-12 additions + menu Held copy.
Acceptance: manual modes work permission-free end to end (declare → Held with reason +
expiry → resume → corridor); App Intents invoke the same Domain path (no parallel
reducer); no entitlement, no owner gate needed — immediately dispatchable.

### Story 2 — Permission/API feasibility spikes + owner approval for production Calendar (family 2)

Branch: `agent/epic5-context-spikes`. Seam: spike-only targets outside Domain
(throwaway probes + guard tests; no production adapter lands here).
Work: four time-boxed public-API-only spikes — (a) selected Calendar busy/free state
+ known end (EventKit); (b) live frontmost-app rules (NSWorkspace active-app only);
(c) media-device-busy signal; (d) FaceTime eligibility. Each spike reports: what the
public API can/can't see, sampling cost, denial/revocation behavior, and the exact
sanitized boolean it could supply. Under the G4 prohibition by charter (spikes prove
the boundary; any private-API need is recorded as a gap, never adopted). Exit: owner
approves or refuses production Calendar access — refusal leaves stories 3–5 on manual
+ frontmost-app + Focus + device-busy only, with Calendar rows honestly absent per
INTERACTION_SPEC §11. RED first: spike-boundary tests pinning what each API does NOT
return (no titles/attendees/content/window-titles), e.g.
`ContextSpikeBoundaryTests.calendarProbeExposesNoTitles`.
Acceptance: four spike reports + owner decision on production Calendar recorded in the
decision log; no production adapter, no entitlement, no retained data from this story.

### Story 3 — Sanitized source adapters (family 3)

Branch: `agent/epic5-context-adapters`. Seam: Epic 3 provider registry + leases +
evidence bus (each adapter registers as a provider with its independence group);
`AppDelegate.observe` context-suppression path; Settings SE-12 permission-at-value.
Depends on: story 2 (only approved sources get adapters; refused sources stay absent).
Work: one adapter per approved source, each emitting only its sanitized boolean +
freshness into the bus: Calendar = selected-busy-interval + known end (never
titles/IDs/attendees/locations — F-10, 07 §4.6); frontmost-app = selected-bundle-ID
active boolean (never window titles, never history); Focus = selected filter active
(never deep-work claims); presentation-mode = user-enabled signal only. Each adapter
declares its independence group (bundle/app, calendar, media-device, derivatives per
blocking amendment); stale/missing/denied/conflicting evidence emits Unknown, never a
negative; F-10/F-24 denial paths (feature off, explained once, core untouched).
RED first: `SanitizedContextAdapterTests.calendarAdapterRetainsNoTitles` (adapter fed a
busy interval with titles/attendees → bus evidence contains busy/free + end only) +
raw-guard extension failing on title/attendee/window-title types in Domain imports.
Acceptance: G4 gate proven here (guards green, adapters retain nothing beyond the
sanitized booleans); "After this busy time" appears only for a selected busy interval
with a fresh known end.

### Story 4 — Layered fusion in shadow + suggest (family 4)

Branch: `agent/epic5-context-fusion`. Seam: Epic 3 fusion + closed firewall (new
deterministic context rule set behind it) + assessment ledger + Why-now (F-19) +
landing corridor / back-to-back / merged post-context opportunity logic.
Work: layered confidence fusion over story-3 evidence with declared independence
groups — correlated weak signals cannot self-promote; explicit user (manual) state
always wins; exactly-one-weak-signal stays ambient/menu-only (G1 core); shadow mode
(counterfactual "would have held" in inspector/audit only, F-22) graduates to suggest
mode (one bounded proposal with evidence summary; Accept applies once; Not now/Never
suggest changes nothing); correction path (F-21: assessment expires, correction
recorded separately, product facts untouched); landing corridor (90 s quiet after
release, `post_hold_landing_corridor_seconds`), back-to-back protection, one merged
post-context opportunity, Why-now explanations with provenance/qualification/freshness.
RED first: `ContextFusionTests.singleWeakSignalStaysAmbient` + `.manualStateOutranksInference`
+ `.correlatedSignalsCannotSelfPromote`.
Acceptance: G1 gate proven here (explicit state wins; one weak signal ambient-only);
shadow-then-suggest graduation demonstrated with ledger receipts; no automatic hold
exists yet by construction (firewall rule present but effect authority unwired).

### Story 5 — Separately consented bounded auto-hold (family 5)

Branch: `agent/epic5-bounded-auto-hold`. Seam: Epic 3 permission broker (separate
effect consent + receipt) + firewall effect wiring + scheduling-decision ledger +
MB-04/Why-now/correction surfaces.
Depends on: story 4 (fusion + shadow/suggest proven) and story 3 (adapters).
Work: the LAST automation: separately-consented bounded auto-hold. Separate effect
choice per source (Off/Shadow/Suggest/one enumerated automatic effect, F-20 — sensing
consent ≠ effect consent); every auto-hold carries cap, expiry, visible sources,
one-action release, source-disable, landing corridor; Held never freezes need clocks
and never discards accumulated need (G2 — `AccumulationPolicy.continue` pinned for
all context reasons); `Not a call` releases promptly AND offers source-disable (G3 —
release latency measured); mid-heads-up hold retracts capsule to Held with qualified
reason; release flows through the landing corridor without marking completion or
discarding need (F-19). RED first: `BoundedAutoHoldTests.notACallReleasesAndDisablesSource`
+ `.autoHoldNeverFreezesNeedClocks`.
Acceptance: G2 + G3 gates proven here; revocation/kill-switch (F-23) drains context
effects within the Epic 3 measured deadline; all-permissions-denied run still
delivers the manual-mode core (story 1 path).

### Story 6 — Compatibility, fairness, accessibility, physical certification (family 6)

Branch: `agent/epic5-context-certification`. Seam: matrix harness + fairness fixtures +
a11y snapshots + copy inventory; read-only over stories 1–5 behavior.
Work: compatibility matrix (Zoom, FaceTime, Teams, recording, music, dictation,
camera tools + false-positive controls — G5); fairness matrix (Voice Control,
Dictation, Live Captions, screen readers, AAC/video relay, hearing access, assistive
camera use — device activity never silently becomes a call); no-inference tests (no
communication/disability/attention/productivity conclusion in copy or behavior);
metrics separation (classification validity vs false/missed holds vs release latency
vs corrections vs trust vs decision value); keyboard/VoiceOver parity for manual
release, `Not a call`, source-disable, Why-now; copy audit (likely/contextual facts
only, never universal meeting detection — G6); physical-device certification where
this Mac permits, remainder pending-owner like Epic 3 story 9.
RED first: `ContextFairnessTests.assistiveDeviceActivityNeverAutoHolds` (Voice
Control/Dictation fixtures produce Unknown, never a hold) +
`ContextCopyTests.noUniversalMeetingClaims`.
Acceptance: G5 + G6 gates proven here; full #6 gate table below green.

## Acceptance — issue #6 gates, each traced to exactly one proving story

| Gate (issue #6 wording) | Proves in | Proving tests |
|---|---|---|
| G1. Explicit user state wins; one weak signal remains ambient/menu-only | Story 4 | `ContextFusionTests.manualStateOutranksInference`, `.singleWeakSignalStaysAmbient` |
| G2. Holds never freeze need clocks and never discard accumulated need | Story 5 | `BoundedAutoHoldTests.autoHoldNeverFreezesNeedClocks` (+ story-1 manual Held RED as precedent) |
| G3. `Not a call` releases promptly and can disable the offending source | Story 5 | `BoundedAutoHoldTests.notACallReleasesAndDisablesSource` (+ release-latency metric, story 6) |
| G4. No audio/video capture, transcription, title, attendee, content, private API, process memory, or Control Center scraping | Story 3 | extended raw-import guards green + `SanitizedContextAdapterTests.calendarAdapterRetainsNoTitles` (spikes run under the same prohibition in story 2) |
| G5. Compatibility matrix covers Zoom, FaceTime, Teams, recording, music, dictation, camera tools, and false-positive controls | Story 6 | matrix harness green with false-positive controls |
| G6. Copy says likely/contextual facts, never universal meeting detection | Story 6 | `ContextCopyTests.noUniversalMeetingClaims` + claims-register check |

Blocking-amendment trace (same single-owner rule): independence groups → story 4;
auto-hold cap/expiry/visible-sources/one-action-release/source-disable/landing
corridor → story 5; manual-hold explicit expiry → story 1; no-retention list
(Calendar titles/IDs/attendees, window titles, activity history) → story 3; fairness
matrix → story 6; no communication/disability/attention/productivity inference → story
6; metrics separation → story 6; keyboard/VoiceOver for release/`Not a call`/
source-disable/Why-now → story 6; manual state from #3 wins permission-free → story 1.

## Intake / escalation gaps (spikes first, owner decides, never private API)

1. Production Calendar access: needs owner approval after story-2 spike (permission +
   privacy-gate labels). Refusal is a complete plan — stories 3–5 proceed without it.
2. Public-API ceiling for media-device-busy / FaceTime eligibility: if the spike shows
   the public API cannot answer honestly, the source stays out; private API is never
   the fallback (STOP list).
3. Focus integration depth: only where public APIs permit; manual declaration is the
   guaranteed fallback (story 1).
4. Entitlement / privacy-manifest / signing text for any adopted protected API: owner
   stop, same as Epic 3.
5. Physical-device certification (cameras/mics on hardware, energy/thermal of live
   adapters): story 6 lands harness + whatever passes on this Mac; hardware runs wait
   for the owner.
6. Copy final sign-off for likely/call language against the claims register: story 6,
   owner-readable diff.

## STOP list (blocking — stop the affected work, record, keep the safer behavior)

- Private API, process-memory inspection, Control Center scraping: never, including
  spikes. A refused public-API answer ends the source, not the rule.
- Audio/video capture, transcription, window-title / Calendar-title / attendee /
  content / activity-history retention or logging: never.
- A second pause/hold reducer or feature-local meeting heuristic: all context flows
  through registry → bus → fusion → firewall → `SuppressionResolver`/coordinator.
- Health-outcome inference; communication / disability / attention / productivity
  inference: never, in behavior or copy.
- Universal-meeting-detection claims ("in a meeting", "on a call" as fact): only
  qualified copy ("likely", "selected busy time", "selected app is active").
- Production Calendar adapter, entitlement/privacy-manifest/signing changes, or
  helper/XPC adoption without the named owner approval.
- Auto-hold before story 5: stories 1–4 ship manual, spike, adapter, and
  shadow/suggest only; no effect authority is wired early.
- Weak/stale/ambiguous evidence holding anything; single weak signal beyond
  ambient/menu-only; correlated signals inflating confidence.

## Pipeline (same as Epics 2–3 — it worked)

RED tests first (seen failing) → implement to green → independent review, blocking
(spec-fidelity + reliability/security; adversarial for fusion/firewall/adapter stories
3–5) → orchestrator re-verifies gates + reads the diff → commit/push/PR/merge under
standing owner authority → worktree removed. Writer cap ONE per story; stories
serialize on shared Domain/schema seams. `scripts/verify.sh` green at every merge;
formatter drift fixed in-story, never banked. All workers skip gates/formatters/lint/
tests/verify mid-flight; orchestrator runs those once at the end.

## Decision log

- 2026-09-12: plan created from frozen issue #6 + AUTHORITY / CONFORMANCE /
  Epic 3 plan / USER_FLOWS (F-08, F-19–F-24) / INTERACTION_SPEC (§§1, 7, 11).
  Suggested order: manual → spikes → adapters → shadow/suggest fusion → bounded
  auto-hold → certification. Story 1 dispatchable immediately (no owner gate).
