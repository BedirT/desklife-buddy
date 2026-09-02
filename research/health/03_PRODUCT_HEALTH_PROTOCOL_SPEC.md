# 03 — Product Health Protocol Specification

## 1. Purpose

This document converts the evidence review into exact launch behaviour. It is authoritative for product timing, completion logic, copy, safety, and adaptation.

The protocol is a **testable product hypothesis**, not a medical prescription. Configuration must remain visible and reversible.

## 2. Terminology

### Estimated active computer use

Time during which the Mac is awake/unlocked and the system estimates recent interaction. It is not sitting, gaze, productivity, or work intensity.

### Visual reset

A brief interruption of near-focus demand, usually about 20 seconds.

### Movement opportunity

An invitation to perform easy walking or equivalent active movement, recommended for about five minutes.

### Position change

A transition such as sitting to standing. It is useful but distinct from movement.

### Natural interruption

A period of likely time away inferred from idle, lock, or sleep. It can reset timer burden but never certifies movement.

### Confirmed event

An event explicitly recorded by the user or, in a future companion, obtained from a suitable permissioned source. “Confirmed” means recorded, not clinically verified.

### Suppression

Temporary non-presentation due to user pause, working hours, application rule, Calendar busy state, Focus Filter, presentation mode, sleep/lock, or another configured condition.

## 3. Independent clocks

The app maintains at least four independent clocks:

1. `visualExposureSeconds`
2. `movementOpportunitySeconds`
3. `positionVariationSeconds` (optional/manual in MVP)
4. `recoveryDebtSeconds` or equivalent repeated-deferral state

A visual reset does not complete movement. Standing does not complete movement. Long idle may reset presentation timing but does not create a movement-completion record.

## 4. Balanced default schedule

### 4.1 Visual reset

- `softDue`: 20 minutes
- `target`: 25 minutes
- `latestPreferred`: 30 minutes
- default duration: 20 seconds
- heads-up: optional 30–60 seconds before target, configurable
- activity: comfortably distant gaze, relaxed near focus, two or three complete blinks
- completion: timer reaches zero or user dismisses/marks done; no camera validation
- snooze options: 5, 10, or 15 minutes
- repeated snooze: after two, stop escalating and ask later whether the cadence should change

### 4.2 Movement opportunity

- `softDue`: 50 minutes
- `target`: 60 minutes
- `latestPreferred`: 70 minutes
- recommended duration: 5 minutes
- valid quick duration: 2 minutes
- recommended content: easy walking or equivalent light active movement
- snooze options: 5, 10, 15, or “after current meeting/task” when available
- completion options:
  - “Start 5 minutes”
  - “Quick 2 minutes”
  - “I moved already”
  - “Changed position only”
  - “Not appropriate now”
  - “Skip”

### 4.3 Recovery suggestion

Trigger when all apply:

- movement opportunity has been deferred or skipped repeatedly;
- estimated active use continues;
- no user-confirmed movement event exists for roughly 90–120 minutes;
- no suppression context is active.

Offer:

> “A longer reset may feel better after a long computer-use run. Try 5–10 minutes away from the desk when it works.”

Never call this an emergency or health-risk state.

## 5. Alternative modes

| Mode | Visual | Movement | Notes |
|---|---|---|---|
| Gentle | 30 min / 20 sec | 75–90 min / 2–5 min | Low burden; onboarding ramp or interruption-sensitive users |
| Balanced | 25 min / 20 sec | 60 min / 5 min | Default |
| Frequent movement | 20–25 min / 20 sec | 30–40 min / 2–5 min | More active, higher interruption burden |
| Research-informed high frequency | 20 min / 20 sec | 30 min / 5 min | Acute evidence rationale; clear high-burden label |
| Deep-work aware | 25–30 min / 20 sec | 60–75 min / 5 min | Uses opportunity windows; never suppresses indefinitely |
| Custom | User-defined | User-defined | Show neutral evidence note; no green/red health grade |

Custom settings may warn when reminders are extremely frequent or effectively disabled, but must not shame or block.

## 6. Opportunity-window algorithm

### 6.1 Low-friction moment heuristic

When soft due, look for a moment such as:

- input pause of several seconds;
- application switch;
- window/session transition;
- end of Calendar busy interval;
- exit from user-declared presentation mode;
- user opening the menu-bar item.

Do not monitor keystroke content, window titles, URLs, screen pixels, or private APIs.

### 6.2 Presentation sequence

1. **Soft due:** menu-bar state changes subtly; no interruption.
2. **Heads-up:** compact notice with “soon,” “start now,” and snooze.
3. **Break overlay:** prominent but calm, keyboard accessible, always dismissible.
4. **Overdue:** repeat at most once within a bounded window or wait for suppression to end.
5. **Adaptive review:** repeated immediate dismissal triggers a settings suggestion later, not escalating harassment.

### 6.3 Merging

When visual and movement opportunities fall within five minutes:

- show one movement break;
- begin with 20 seconds of distant gaze;
- continue with movement;
- complete both clocks only when the user begins/records the relevant actions;
- if the user chooses “visual only,” movement remains due.

## 7. Activity estimation

### 7.1 MVP proxy

Use elapsed time since recent keyboard/mouse/scroll events plus system awake/unlocked state. The proxy should be described internally and publicly as estimated active computer use.

### 7.2 Suggested thresholds

- recent interaction window: approximately 60 seconds;
- idle between 60 seconds and 5 minutes: pause accumulation;
- idle at or above 5 minutes: reset presentation timers as likely natural interruption;
- lock or sleep: pause immediately; reset after a qualifying duration;
- wake/unlock: start a short grace period before reminders.

These thresholds need usability testing. Passive reading/video can be undercounted.

### 7.3 No false completion

Never infer:

- sitting from active input;
- standing from app state;
- walking from idle;
- a visual break from no input;
- exercise intensity from duration;
- symptom improvement from completion.

## 8. Suppression hierarchy

Highest precedence first:

1. user manual pause;
2. system lock/sleep/session inactive;
3. user-configured Focus Filter or presentation mode;
4. Calendar busy interval, if enabled;
5. user-defined application exclusion;
6. outside working hours;
7. temporary snooze;
8. opportunity-window waiting.

Suppression should pause presentation, not silently delete history. On exit, use a grace period and avoid immediately stacking multiple overdue prompts.

## 9. Meeting and presentation handling

The MVP must not promise universal automatic meeting detection.

Reliable-enough options:

- optional Calendar busy/free intervals;
- user-defined meeting apps and exclusions;
- manual “Pause until…” command;
- Focus Filter;
- optional menu-bar “Presenting for 1 hour” mode.

Do not request Screen Recording, Accessibility, or camera/microphone permissions merely to inspect other apps. Do not use private APIs.

## 10. Break completion semantics

Record separately:

- `promptPresented`
- `breakStarted`
- `timerFinished`
- `userDeclaredCompleted`
- `userDeclaredAlreadyMoved`
- `positionChanged`
- `snoozed`
- `skipped`
- `notAppropriate`
- `likelyNaturalInterruption`

Never combine these into a generic “healthy break achieved.”

## 11. Adaptation rules

### 11.1 Allowed adaptation

- shift presentation within the configured opportunity window;
- suggest a gentler cadence after repeated immediate dismissals;
- suggest a more frequent cadence if the user voluntarily asks for it;
- learn preferred break content from explicit choices;
- suppress known poor contexts;
- use a gradual onboarding ramp;
- offer a recovery break after repeated deferral.

### 11.2 Prohibited adaptation

- silently make lockout stricter;
- infer a medical condition;
- increase reminders because the user reported pain without explicit consent;
- use hidden engagement optimization to maximize prompt clicks;
- penalize disability-related alternatives;
- infer productivity from app usage;
- use employer or peer comparison;
- change health claims based on marketing experiments.

## 12. Copy system

### 12.1 Visual reset

Good:

- “Let your eyes switch distances for 20 seconds.”
- “Look comfortably far away and blink slowly.”
- “A short break from near focus.”

Avoid:

- “Prevent eye damage.”
- “Your eyes need protection from blue light.”
- “Computer vision syndrome detected.”

### 12.2 Movement

Good:

- “Break up this computer-use run with five minutes of easy movement.”
- “Walk, wheel, or move in a way that works for you.”
- “Two minutes still counts as a useful quick break.”

Avoid:

- “You have been sitting too long.”
- “Lower your blood sugar now.”
- “Undo the damage of sitting.”
- “Burn X calories.”

### 12.3 Posture

Good:

- “Try a different comfortable position.”
- “Bring the task closer rather than reaching.”
- “There is no need to hold one position all day.”

Avoid:

- “Bad posture detected.”
- “Correct your spine.”
- “Slouching is damaging your neck.”

### 12.4 Skips and deferrals

Good:

- “Not a good moment. Try again in 10 minutes?”
- “You’re in control.”
- “Should the schedule be gentler during this time?”

Avoid:

- “You failed your break.”
- “Streak lost.”
- “Health score reduced.”

## 13. Onboarding

### Required

- explain estimated active computer use;
- choose balanced/gentle/frequent/custom;
- select movement capability preference without requesting diagnosis;
- explain that every break is dismissible;
- show privacy promise;
- ask for no permission until a feature requires it.

### Optional and purpose-limited

- sit-stand desk availability;
- preference for walking, seated movement, position change, or breathing;
- contact-lens comfort tip;
- recurring eye/neck/back/wrist discomfort, phrased as an optional symptom preference rather than diagnosis;
- reduced-motion or migraine-friendly default;
- work schedule.

### Do not collect in default onboarding

- medical diagnoses;
- pregnancy;
- surgery history;
- cardiovascular status;
- detailed disability data;
- medication;
- precise health-risk profile.

Only ask a sensitive question when a feature cannot be made safe through universal alternatives.

## 14. Weekly reflection

Show:

- estimated active computer-use pattern;
- longest estimated run;
- visual and movement opportunities shown;
- actions selected;
- common defer contexts;
- optional subjective usefulness trend.

Do not show:

- disease-risk reduction;
- calories;
- “healthy minutes” created by an arbitrary formula;
- posture score;
- peer ranking;
- all-or-nothing streak.

## 15. Safety behaviour

Movement cards include:

- stable-environment reminder where relevant;
- easier/seated alternative;
- immediate stop option;
- “Skip if this is not comfortable or appropriate.”

Global safety copy:

> Stop and seek appropriate help for chest discomfort, fainting, severe unusual shortness of breath, sudden weakness, sudden vision loss, severe eye pain, or another sudden serious symptom. The app cannot evaluate these.

Routine discomfort should not trigger emergency language automatically.

## 16. Acceptance criteria

The protocol implementation is acceptable only when:

- separate visual/movement/position semantics remain intact;
- no screen lockout exists;
- Escape and keyboard controls always work;
- long idle does not create a movement completion;
- Calendar content is not retained;
- accessibility alternatives are equal-status, not hidden;
- repeated skips do not create punishment;
- user can pause indefinitely;
- public copy passes the claims register;
- all defaults are configurable and explained;
- analytics cannot reconstruct personal work content.

## 17. Owner-approved timing and action amendment — 2026-09-01

**Status:** canonical amendment under D-033. This section preserves the 2026-08-24 research
snapshot above as provenance while superseding only the timing/action clauses named here. The
exact machine contract is
[`design/machine-readable/timing_runtime_v2.yaml`](../../design/machine-readable/timing_runtime_v2.yaml),
with health values and preset compatibility in
[`machine-readable/product_protocol.yaml`](machine-readable/product_protocol.yaml).

### 17.1 Clock meaning and permission-free eligibility

The four clocks are schedules based on estimated active computer use: visual-reset schedule,
movement-opportunity schedule, optional position-change schedule, and optional recovery schedule
after explicit deferrals. They are not estimates of gaze, near-screen exposure, body movement,
stillness, position, stability, posture, diagnosis, or health.

For the permission-free path, valid adjacent monotonic samples must show an awake, active,
unlocked Mac session inside enabled working hours. Manual pause, system unavailability, a
qualified confirmed-away interval, and each clock's relevant accepted ritual freeze accrual.
Position timing freezes during every accepted ritual. Input silence
below 300 seconds remains eligible for the visual clock so passive reading is not treated as a
visual reset. The movement-opportunity schedule accrues only through the 60-second recent-input
window; longer input silence freezes it without implying body movement or stillness. This
supersedes §7.2's blanket
“idle between 60 seconds and 5 minutes: pause accumulation” only for visual timing.

Non-finite or backward time and adjacent samples more than 15 seconds apart establish a new
baseline and add zero time. Sleep, lock, inactive session, process absence, relaunch, and other
unobserved gaps never catch up from wall time. Wake/unlock has a 90-second grace.

At the first 300-second idle threshold, record `likelyNaturalInterruption` once and freeze while
away. On return, begin a fresh visual cycle at the return boundary, preserve the unresolved
movement need, and apply a 60-second grace. This is presentation courtesy, not an inferred visual
break or movement completion. Visual time accrued before that likely-away interval cannot cause a
prompt after return; a new fresh or Custom visual cycle may still follow the person's configured
bounds, with no additional unsupported minimum implied.

### 17.2 Paused, Held, and accepted time

`Paused` means its named clock scope does not accrue: explicit Pause, outside selected working
hours, sleep/lock/inactive/unavailable session, and qualified confirmed away freeze all four
clocks; an accepted visual ritual freezes visual and position, while an accepted movement,
merged, or recovery ritual freezes all four. `Held` means eligible schedule time continues but
presentation is quiet. Its visible explanation preserves provenance: a user-declared meeting is
stated as selected by the person; Calendar says selected busy time, not meeting; Focus says the
selected Focus is active; a selected app says only that the selected app is active; inference
must say `likely`. Missing, stale, unavailable, or conflicting evidence is unknown and creates no
hold or body/activity claim. Snooze and low-friction waiting remain typed holds. Hold release has
a 90-second landing corridor for nonrunning state and presents at
most one merged opportunity. Manual-pause resume also uses 90 seconds; working-hours re-entry
uses 60 seconds. The visible state must use these exact terms and the actual reason.

Paused/Held evidence is orthogonal to a running ritual. Its phase, segment, deadline, snapshot,
and revision remain suspended. Clearing any pause/hold/system/working-hours record removes only
that named evidence and reduces the complete remaining set. When no higher external evidence
remains, a same-epoch future deadline resumes the same segment immediately; the ritual's own
intrinsic clock-scope freeze is not an external overlay. Proven elapsed reconciles its
timer; unknown timing follows the operational recovery below. Only nonrunning state uses a release
corridor.

An accepted visual, movement, merged, or recovery segment has one continuous-monotonic deadline.
Its epoch and anchor persist. Same-epoch restore subtracts current monotonic ticks. An unavailable
or discontinuous epoch is unknown and closes through operational-only
`timerRecoveryUnavailable`: emit no `timerFinished`, create no fresh schedule, preserve each
affected due cycle, settle only admitted candidates from the same live generation, then atomically
commit the operational disposition and signed high-water projection fence. The 60-second grace
begins after that fence; only fence + grace permits a new OpportunityID. The surface says “Timer
couldn’t be restored,” then uses the retained schedule phase: an actually due schedule says “No
finish was recorded. This schedule is still due,” while an accumulating or manually opened early
schedule says “No finish was recorded. The timer was not restored, and this schedule was not
reset.” Body due status and menu evidence status are independent: Paused always stays
“Paused: [selected reason] · timer not restored” and Held stays “Held: [qualified evidence
reason] · timer not restored,” whether due or not due. Missing/stale hold evidence is unknown, not
a meeting or deep-focus claim. Old-generation actions get an explicit current-state receipt. A
companion transfer requires a bounded monotonic handshake and subtracts its full uncertainty;
without acknowledgment the sender remains authoritative. Portable wall values are display and
audit metadata only. Sleep, lock, callback suspension, relaunch, clock changes, or handoff cannot
extend the accepted duration. Every deadline, snooze, target, and release boundary uses
`elapsed >= deadline`; exact 60-, 90-, and 300-second edges fire once.

A same-epoch sleep/lock/system-unavailable interval of `elapsed >= 300 seconds`, with no unresolved
running ritual, records one `likelyNaturalInterruption`, starts a fresh visual schedule on return,
preserves movement/position/recovery need, and applies 60 seconds of grace. Unknown elapsed time
gets no fact or courtesy. This is scheduling courtesy only, never completion or movement proof.

### 17.3 Presets and compatibility

New selection displays are Calm (`calm`), Balanced (`balanced_v2`, default), Frequent reset
(`frequent_reset`), Adaptive (`adaptive`), and Custom (`custom_v2`). Their exact soft/target/latest,
duration, and position values are the `preset_contract_v2` keys in `product_protocol.yaml`.
Adaptive begins at the current Balanced v2 contract bounds and initially adapts only delivery within the configured
window and bounded holds; it does not personalize frequency or health outcomes.

The shipped IDs `gentle`, `balanced`, `frequent_movement`, and
`research_informed_high_frequency` retain their exact v1 values. Decode and display them without
retuning. Legacy `custom` and v2 `custom_v2` are distinct persisted identifiers under an explicit
contract version and migration state. The v2 custom payload preserves v1 field names, units,
ordering, and values; acceptance changes only its version/identifier/migration tags. Offer a
successor explicitly; migrate only after acceptance. The high-frequency preset becomes an exact
`custom_v2` snapshot rather than being coerced into a different built-in. The storage domain accepts
every legal positive finite v1 value unchanged, including a 5-second visual duration and `[30]`
movement-duration option. The 10–60-second visual and 120/300 movement bounds govern only newly
created or edited v2 values; migration never clamps, rejects, or silently retunes. This
supersedes §5 for new selections without rewriting the historical modes.

### 17.4 Action effects

The v2 machine transition table is normative. In summary:

- a visual timer finish or `Done early` begins a fresh visual cycle;
- a visual or merged-visual running field records `breakStarted` in its open commit; movement
  `Now` only opens the offered state and records nothing;
- movement has a distinct offered state with no timer, `breakStarted`, or `Done early`; accepting
  the visible 5- or 2-minute action creates the running state and selected-duration deadline;
- a movement timer finish or `Done early` begins fresh movement and visual cycles, so visual time
  accrued before the movement cannot trigger the reported early-visual failure; a genuinely new
  cycle may still follow configured bounds;
- `I already moved` begins a fresh movement cycle, and refreshes visual only when the declared
  or strong fresh evidence also establishes screen-away timing;
- a position change refreshes only the position clock;
- position accrual remains frozen during accepted rituals, but a reachable explicit Change
  position action may still refresh the named position cycle; this adds no elapsed time and does
  not complete or join the movement participant set;
- a standalone position skip begins a new position cycle without completion credit, avoiding a
  rapid repeat while leaving visual, movement, and recovery unchanged;
- a 5- or 10-minute recovery acceptance freezes visual, movement, position, and recovery while its
  absolute deadline runs; finish or `Done early` starts fresh visual, movement, and recovery
  cycles. Offered Skip/Escape preserves offer-time accrual and consumes only the recovery offer;
  running Skip/Escape restores the acceptance snapshot, preserves underlying movement due, starts
  a fresh recovery cycle without completion credit, and prevents another recovery offer that session;
- visual and movement Skip/Escape close immediately, record `skipped`, and begin a fresh cycle
  for the refused standalone need without completion credit or rapid re-offer;
- snooze preserves the same due cycle and OpportunityID through one bounded re-offer;
- merged work keeps the independent cycle IDs: visual timer or `Done early` records that segment
  once and advances to the movement-duration offer; movement 5/2 acceptance starts its deadline;
  movement timer, Done early, already moved, content change, position change, Skip, visual-only,
  and Escape are phase-specific, and every movement-phase exit retains the fresh visual effect;
- a strong sensor observation may support an explained, undoable scheduling restart under a
  validated, enabled rule, but creates no completion product fact.

This amends §4.1's ambiguous “dismisses/marks done” wording: Skip/Escape is `skipped`, never
completion. It also supersedes §4.2 and §6.3 wherever starting a movement timer was described as
completing a clock. `breakStarted` records acceptance and freezes the relevant schedule clocks;
the terminal action owns the fresh-cycle effect.

### 17.5 Identity, reconciliation, and facts

Every clock cycle, coordinated opportunity, action, and automatic decision has its own stable
identity. A merged opportunity references its separate visual and movement cycle IDs. Every
action names its origin phase/revision/segment, base participant set, affected nonparticipant cycle,
persistent device counter, and causal parents. Movement/merged position actions keep movement or
visual+movement as their base participants and guard the exact affected position cycle separately.
That manual position cycle exists even while position reminders are disabled; changing it rotates
the cycle without enabling accrual, due state, or prompts. An action originated after known closure
is a rejected no-op with an explicit operational receipt. A candidate originated before provisional
closure remains eligible only while its exact coordinator generation and projection epoch are live
and unfenced. Effect-bearing nonterminal commands require a live coordinator lease and atomically
commit/ack before exposing effects. Opportunity commands use OpportunityID + revision; global
Pause/Held/system/schedule evidence commands use stable GlobalStateID + global revision. Expected
opportunity metadata is an atomic compare-and-fence only when a running ritual exists, never global
identity. Hold may begin before due without an OpportunityID. One complete conflict-key and
same-key rank registry covers every authoritative nonterminal transition. One winner per record is
chosen, then all compatible disjoint-record winners apply before full evidence reduction. This
preserves both lock and long-idle evidence at exactly 300 seconds and allows simultaneous clears.
Begin and matching clear for one Pause, Hold DecisionID, unavailable episode, long-idle episode,
working-hours record, or restart DecisionID use identical key kind and identity bytes; operation,
rank, transition, ActionID, and arrival are excluded. Restart/undo cannot rotate a cycle while a
running or Paused/Held-suspended ritual exists; it waits for neutral revalidation after resolution.
Offline intents remain operational-only until renewed and revalidated.
Terminal candidates require a causally acknowledged projection lease of at most 90 monotonic
seconds. Every closure settles admitted same-generation candidates, commits a signed high-water
projection fence, revokes leases, discards raw buffers, then allows successors. GlobalStateID,
coordinator generation, revisions, and contiguous-disposition high water persist for restart safety.
Epoch loss fences the old generation rather than waiting for an unverifiable old monotonic expiry;
later old-generation actions receive an honest current-state receipt and never a product fact. A
duplicate ActionID replays a compact known acknowledgement without applying effects again. The
receipt remains until the device returns a verified acknowledgement-of-ack for the outcome-delivery
token or 90 seconds elapse; ACK creation and projection/generation fences do not erase it. After
expiry, duplicate and unseen actions say **too old to verify** and show current state. High water
means only contiguous disposition and never proves receipt. Per-device generation is gap-free;
counter 11 waits in a Class-0 sparse window until 10 is disposed. Terminal conflicts use a fixed
fact-claim rank and stable identifiers, never wall time, remaining duration, segment duration, or
arrival order. Both reductions are commutative, associative, and idempotent.

Portable IDs use versioned canonical bytes: normalized UUIDs, NFC UTF-8 strings, big-endian
integers, typed optionals/unions/structs, and canonically byte-sorted counted sets/maps. The signed
fence registers `cadence.timing-runtime-v2.projection-fence.v1` version 1, exact uint widths, uint8
optional/union tags, uint16 enum vocabularies, explicit collection cardinalities, nested opportunity
context, ordered typed schema, SHA-256 digest bytes, Ed25519 signing input, pinned-key verification,
and previous-digest chain. Unknown or mutated domain, version, type, width, tag, cardinality, order,
digest, or signature fails closed. Wall time, locale, process hashes, and pointer addresses
are excluded. A terminal fact ID uses OpportunityID, the canonical terminal slot, and fixed
registered component scope, so it is invariant across candidate winners.

Before a terminal projection, retain all four clocks' cycle ID, accumulated time, due state,
eligibility, phase, and enablement, including the latent manual position cycle, plus recovery/session state, evidence, decisions, deadlines, and component
facts. A global evidence commit fences the old running-opportunity revision, creates a successor,
and rebases the exact phase, segment, accepted deadline or suspended remaining duration, and
snapshot without reset or wall extension. The required terminal scope is the union of every eligible candidate effect, including cross-clock
and affected-nonparticipant effects. Offered actions project from their action checkpoint after
offer-time accrual; running actions may restore only the acceptance snapshot. If a late
candidate replaces a provisional winner, restore that snapshot, apply the new winner once,
preserve already-final independent merged-segment effects, discard only causal descendants of the
losing branch, and replay retained idempotent post-terminal inputs. The same deterministic fact ID
is updated; no second fact, announcement, haptic, or notification is emitted.

Every derived merged-visual exit enters one cross-slot arbiter after companion wrappers normalize
to concrete local transitions: parent Escape, Done, timer recovery, and timer finish. Escape
preempts, then Done, operational recovery, and timer. One causal winner produces at most one fact
path and visual successor effect; recovery produces neither and preserves due schedules. Remote
Done advances to the movement offer rather than closing the parent. A component already
acknowledged at the successor revision is final, and a later movement-phase Escape retains it.

The companion live registry binds exact controls, focus, normalized remote IDs, and Escape to each
visual, movement, position, recovery, and merged phase/segment. Closed action groups include every
remote ID, including `companion.visual.skip`; `Just the visual one` exists only in merged movement
offered. Neutral offline/revalidating states say no operation is pending. If a terminal ACK is
unknown, provenance for the selected action remains attached and the exact status says the
connection was lost, it is checking whether that named action was received, and **do not repeat**.
Checking status or reconnecting never resends the action.

The ten §10 product facts remain closed. Operational records, sensor observations, fused
assessments, scheduling decisions, corrections, and retained companion continuity are separate
ledgers. Raw terminal/companion candidate envelopes, losers, duplicates, post-fence rejects,
out-of-order sparse counters, and compact lost-ack receipts are Class 0 memory-only for at most 90
seconds and never exported, analyzed, or assigned a durable record identity. A compact receipt is
erased early only after verified acknowledgement-of-ack, not merely ACK generation or a fence. It
contains no raw payload and only the ActionID digest, counter, outcome, successor revisions,
outcome ACK, and delivery token needed for exactly-once replay. The
legacy `event_schema.json` is now explicitly a read-only v1 envelope whose mappings project to
the ten facts; its broader record kinds never enlarge the product-fact vocabulary. No timer,
idle, sensor, camera, motion, HealthKit, companion, or model observation is a completion fact or
proof of a health outcome.
