# User Flows

Flows are written as **decision paths**, not happy paths. Every flow states its exit, its
Paused/Held behavior, and what the product records. Screen IDs refer to `SCREEN_INVENTORY.md`.

Legend: `→` next step · `⤳` background/no UI · `✕` flow ends

---

## F-01 · First launch

```
Install → launch → ON-01 What this is
  → ON-02 What it can and cannot know          (the honesty screen; not skippable content,
                                                but the whole flow is skippable)
  → ON-03 Choose a rhythm  [Calm | Balanced✓ | Frequent reset | Adaptive | Custom]
  → ON-04 How you move     [Walk/wheel | Seated movement | Mix movement paths | Position change]
  → ON-05 Comfort          [Standard | Static + brightness; macOS choices shown read-only]
  → ON-06 Ready            (Choices summarized; integrations named, not requested.)
  ✕ Menu bar item appears (MB-01). Clocks start.
```

- **Skip at any point** → ON-07: Balanced preset, all four movement options offered
  equally, no permissions requested, no reminder to finish setup.
- **No permission is requested during onboarding** `[09 §7 permission-first onboarding]`.
  Notifications are requested at F-03 step 1; Calendar at SE-12.
- Target: under 90 seconds, six screens, no account.

---

## F-02 · Steady state (the flow that runs 40× a day)

```
⤳ permission-free estimator running (5 s expected samples; 15 s maximum covered gap)
⤳ four clocks advancing: visual · movement · position · recovery
  → visual clock reaches soft-due (20 min, Balanced v2)
    → MB-02 glyph changes            ← Level 0. This is the whole interaction 
                                        most of the time.
    → Paused/Held check (PRODUCT_MODEL §6)
        Paused → ⤳ freeze affected clocks; no catch-up
        Held   → ⤳ eligible need continues; do not present or queue duplicates
        clear  → wait for a low-friction moment (max: Balanced v2 latest 27 min)
    → F-03
```

**Design consequence:** the default outcome of a due clock is a *glyph change*, not a screen.
If a direction cannot make MB-01→MB-02 legible and calm, the direction fails.

---

## F-03 · Visual reset

```
HU-01 heads-up (45 s before target)
  ├ Start now          → BR-01 → BR-02 immediate + absolute 20 s deadline
  │                      → coarse final milestone → timerFinished
  │                      → AK-02 (nothing shown) ✕  fresh visual schedule
  ├ In 5 minutes       → snoozed(300) → return to F-02 ✕
  ├ More options       → HU-05 → BR-13 [5·10·15 min | after meeting | pause 1 hr |
  │                                     not appropriate]
  └ ignored            → at target: BR-01 appears
                          ├ Escape / click away → skipped ✕   (fresh visual schedule,
                          │                                    no completion credit)
                          ├ "Done early" → userDeclaredCompleted ✕
                          └ run to completion → as above
```

- **One escalation maximum per opportunity** `[protocol: opportunity_delivery.max_repeated_escalations_per_opportunity: 1]`.
- Escape always exits. There is no confirmation on exit.
- Nothing is verified. `timerFinished` and `userDeclaredCompleted` are recorded distinctly.

---

## F-04 · Movement opportunity

```
HU-02 heads-up
  → Now → BR-05 offered (no fact or timer) [Start 5 minutes (initial focus) | 2 minutes | I already moved |
                    Change position instead | Skip]
      ├ Start 5 min / 2 min → breakStarted + selected duration + absolute deadline
      │     → BR-07 running [three equal content choices | Done early | I already moved |
      │                      Change position instead | Skip]
      │     → timerFinished / BR-08 "Done early" → fresh movement + visual schedules ✕
      │     └ device sleeps/locks → same-epoch deadline resumes/finishes; unavailable anchor
      │                              → operational recovery, no timer fact/fresh cycle
      ├ "I already moved" → userDeclaredAlreadyMoved → fresh movement schedule;
      │     visual fresh only with an explicit or strong fresh screen-away basis ✕
      ├ "Change position instead" → positionChanged → rotate the always-present position cycle;
      │     when reminders are off they remain off with no due state or prompt ✕
      └ Skip / Escape → skipped; fresh movement schedule without completion credit ✕
```

BR-05 has no timer, `breakStarted`, or Done early. Its focus order is 5 → 2 → already moved →
position → [merged only: Just the visual one, V] → Skip;
Return/5 and Q/2 accept their durations on the first frame. BR-07 focuses Done early and exposes
1/2/3 content choices. A/P/Escape/⌘. remain first-frame actions in both states. VoiceOver says
"timer not started" while offered and names the accepted duration while running.

- Movement timer/declaration and `I already moved` create a fresh movement schedule. Skip/Escape
  also starts a new schedule to respect refusal, but records no completion credit. Acceptance
  alone never resets the schedule.
- Idle never completes movement. At five minutes, `likelyNaturalInterruption` preserves movement
  need and starts a fresh visual schedule only when the person returns.
- Safety line is present on every running movement screen `[C040]`.

---

## F-05 · Position change

```
Entry: BR-11 offer, MB-11 menu item, or chosen inside BR-06
  → user changes position → positionChanged ✕
Effects: positionVariationSeconds resets.
         movementOpportunitySeconds does NOT reset.
Copy must make this true without lecturing: standing is not movement [C048, 09 §6].
```

---

## F-06 · Merged break (visual + movement within 5 min)

```
Both due inside merge_window (300 s)
  → HU-03 one heads-up  (never two notices)
  → BR-09 single surface:
        segment 1 · look far away (≈20 s)
        segment 2 · movement (5 or 2 min, or choose activity)
  ├ visual timer / Done early → cross-slot arbiter commits visual component → movement offered
  │   ├ accept 5 / 2 min → movement running
  │   │   ├ timer / Done early → fresh movement; visual remains fresh ✕
  │   │   ├ I already moved → declared movement fact; visual remains fresh ✕
  │   │   ├ Change position → position fact/cycle; visual remains fresh ✕
  │   │   ├ content changes → selected duration is unchanged
  │   │   └ Skip / Escape → skipped movement schedule; visual remains fresh ✕
  │   ├ Change position → position fact/cycle; base participants remain visual+movement ✕
  │   ├ Just the visual one (V) → BR-10 → visual fresh, movement remains due ✕
  │   └ Skip / Escape → skipped movement schedule; visual remains fresh ✕
  └ Escape during visual → same-revision cross-slot arbiter preempts uncommitted component;
     one skipped path and one visual successor effect, never timerFinished + skipped ✕
     Escape during movement → retain finished visual effect; skipped movement starts fresh ✕
```

If visual completion was already acknowledged at the successor revision, it is final and Escape
uses the movement-phase path. Same-revision timer/Done/Escape never project independently.

---

## F-07 · Snooze and repeated deferral

```
snoozed(n) → Held for n with same OpportunityID → opportunity returns once
Second deferral of the same opportunity → no immediate re-offer; wait for the next normal cycle
Further deferrals → NO escalation: no bigger surface, no color change, no counter, no guilt copy
Session pattern (ED-15): after the session, at most one neutral note in the
  weekly rhythm or a settings suggestion — "Balanced may be too frequent for how you
  work. Try Calm?" — never mid-session, never as an interruption.
```

This flow is where most competitors fail. It is a first-class design target, not an edge case.

---

## F-08 · Paused and Held

```
MB-12 → [30 min | 1 hour | Until… | Until tomorrow | While presenting]
  → explicit Pause: clocks freeze, deadline/reason survive relaunch
  → explicit presenting/meeting/call, selected Focus, selected Calendar busy interval,
    selected app, or qualified likely-call inference: Held; eligible need continues
  → MB-04 glyph + menu state says Paused or Held and the actual reason/deadline
  → resume is always one click, followed by a 90 s quiet corridor
Working hours begin → new monotonic baseline + 60 s quiet corridor; no wall catch-up
Presentation mode left on (ED-14): once, quietly, at the next natural moment —
  "Still held for presenting. Resume?" Dismissible. Never repeated in the same session.
```

Every hold record carries source provenance, qualification, observed-at, expiry, and correction
state. UI says only what the evidence proves: Calendar is "selected busy time," Focus is "Focus
you selected," an app is "selected app is active," and inference is "likely." Stale, missing,
conflicting, or unqualified evidence is unknown, not a hold. Confirmed away additionally requires
fresh, unambiguous, authorized evidence and never becomes a movement-completion fact.

---

## F-09 · Weekly rhythm

```
User opens it (never pushed as an interruption)
  → WK-01: when you worked · how runs were broken up · what you chose ·
           what got in the way · optional self-report
  → WK-04 adjust schedule  (framed as fit, never as failure)
Empty/sparse (WK-02): says there is not much yet. No encouragement, no fabricated insight.
History off (WK-03): says so, offers to turn it on, does not nag.
```

No score. No streak. No grade. No week-over-week "improvement" language `[09 §7]`.

---

## F-10 · Permissions

```
Notifications: first time a heads-up would be useful → PM-01 explains, then requests.
  Denied (PM-02) → in-app heads-up (HU-04) forever after. Never asked again.
Calendar: only from SE-12 → PM-03 states what is read (busy/free) and what is never
  stored (titles, attendees, locations) [05 §4.6] → request.
  Denied (PM-04) / revoked (PM-05) → feature off, explained once, everything else works.
Launch at login (PM-06) and Focus Filter (PM-07): opt-in, reversible, honest about
  where the system control lives.
Core function requires **zero** permissions `[protocol: permissions.required_for_core: []]`.

---

## F-11 · Recovery suggestion

```
recoveryDebtSeconds eligible (90 min, Balanced v2) and typically by 120 min
  → BR-12: a longer break, 5–10 min, offered once
  → declined → not re-offered as a longer break this session
Tone: an offer between peers. Never an alarm, never "you have not taken a real break."
```

---

## F-12 · Changing the schedule

```
SE-02 → Calm / Balanced / Frequent reset / Adaptive / Custom (`custom_v2`)
  Legacy Gentle/Balanced/Frequent movement/High frequency value loaded:
    → Keep current schedule preserves exact v1 ID/values
    → Review new schedule shows the named successor; migrate only after acceptance
  Legacy Balanced remains 20/25/30 visual and 50/60/70 movement; migration copy names the
    successor "Balanced (current v2 schedule)" at 20/25/27 and 50/55/70. Normal display is Balanced.
  Legacy custom accepted for migration:
    → preserve every legal positive finite v1 field, unit, ordering, and value, including
      visual 5 s and movement [30]; change only contract version, identifier, and migration state
    → migrated scalar fields and duration-array groups begin untouched
    → apply safer v2 bounds only to a newly created or dirty field/group plus necessary ordering
      neighbors; unrelated edits never clamp/reject untouched visual 5 s or movement [30]
  Adaptive starts at the current Balanced v2 contract and initially changes only delivery within the due window
    and bounded automatic holds, never reminder frequency or a health conclusion
  Very frequent (SE-03) or effectively disabled (SE-04):
    → one neutral note about what that means. No warning icon, no block, no shame [03 §5].
Default changed by an app update (ED-18): first launch after → say what changed and why,
  offer to keep the old value. Never silently re-tune someone's schedule.
Optional validated schedule restart → Undo remains available across ordinary eligible accrual
  → Undo restores the predecision values plus that eligible accrual delta
  → later terminal/ritual/restart/cycle mutation makes Undo stale
  → announce “That restart can no longer be undone. Your current schedule was not changed.” once;
    focus Close and preserve every later fact/effect
```

---

## F-13 · Privacy and data

```
SE-09 → what is stored (plain list) · retention · export · delete
  → SE-11 export: choose CSV or JSON in the native Format menu
    → expand Columns and select any non-empty subset of the six disclosed typed fields
    → Choose destination… opens one user-selected save location, then writes that exact request
  → SE-10 delete: states exactly what will be removed and what remains
Nothing here is buried, and nothing requires an account to reach.
```

The export/history surface projects the ten product facts. Operational, observation,
assessment, scheduling-decision, correction, and companion-action ledgers remain separately
typed and disclosed before their owning features retain or export them.

---

## F-14 · Take an accepted timer away

```
Accepted visual or movement ritual → Take with me
  → Mac shows registered live/offline availability; Take with me is enabled only while live
  → Mac sends GlobalStateID + generation + OpportunityID + projection epoch + independent
    ClockCycleIDs + segment ID + absolute deadline + ActionID + exact selected receiver DeviceID,
    local device label, key ID, and key epoch
  ├ companion starts handoff → Transfer pending · “Sending timer…” · Cancel transfer
  │   └ acknowledges bounded monotonic handoff + ≤90 s exact-generation lease → Live
  │       ├ terminal action → normalize wrapper to exact local transition
  │       │   → Terminal action pending · “Sending ‘[selected action]’…” · Close
  │       │   → causal acknowledgement; submitted action cannot be cancelled or repeated
  │       ├ Start 5/2 → Nonterminal action pending · “Starting ‘[selected start]’…” · Close
  │       │   → signed outcome enters merged movement running and records breakStarted once
  │       │   → unknown ACK preserves duration/target → Check status; never repeat or resend Start
  │       └ same-generation concrete action set reconciles by its named resolver
  │           → winner materializes the exact local product fact/effect/successor phase
  │       → other devices show Already ended / Ended on another device
  │       → losing/duplicate raw candidates erase from memory at settlement/fence
  ├ connectivity lost with no operation pending → Offline · Retry / Close · Keep using this Mac
  ├ connectivity lost while terminal ACK unknown
  │   → “Connection lost. Checking whether [selected action] was received; do not repeat.”
  │   → Check status / Close; selected action provenance remains; never resend
  ├ lease elapsed → Expired · Retry / Close → neutral Revalidating · Cancel reconnect / Close
  ├ terminal ACK check → Revalidating terminal ACK unknown · Cancel reconnect / Close
  │   → “Checking whether [selected action] was received; do not repeat.”
  │   → Live or Rejected, no-op · Close
  ├ nonterminal Start ACK check → Revalidating nonterminal ACK unknown · Cancel reconnect / Close
  │   → merged movement running or Rejected, no-op; original breakStarted is never replayed
  ├ duplicate with compact receipt before acknowledgement-of-ack/90 s
  │   → replay recorded acknowledgement; no second effect
  │   → device returns the signed generation/device/ActionID/counter/outcome-revision/
  │     32-byte-token/outcome-binding envelope → receipt may erase
  ├ duplicate/unseen action after receipt expiry → too old to verify; show current timer
  ├ merged movement offered → Start 5 (initial focus, Return/5) / Start 2 (Q/2) /
  │   I already moved / Change position / Just the visual one / explicit Skip
  │   → Start and authoritative local Skip/Escape enter one fixed-cutoff opportunity-action frontier;
  │     handoff and terminal action do the same; arrival order never selects the winner
  │   → before settlement show pending only, with no fact/deadline/transfer/haptic exposed
  ├ Escape or Command-period on any companion status → dismiss projection only; no Skip,
  │   terminal action, transfer cancellation, or revalidation cancellation
  ├ sender crash before atomic counter+ActionID+outbox commit → no reservation
  ├ sender crash after commit/before or after send → only same local monotonic epoch and elapsed
  │   <90 s may resend the same envelope/ActionID/receiver/key; otherwise erase without resend or replacement
  ├ signed outcome received → atomically persist exact outcome ACK bytes/revision/expiry/token/
  │   binding in outcome_ack_pending, then original action outbox may erase
  ├ sender crash after outcome → same-epoch <90 s relaunch completes acknowledgement-of-ack from
  │   outcome_ack_pending without reapplying; transmission erases pending, no recursive ACK
  ├ pairing/key rotates → only exact receiver/key epoch accepts; old key lives through its bounded
  │   referenced window; a replacement pairing fences old commands with visible rejection
  ├ counter 11 arrives before 10 → hold 11 in Class-0 sparse window; high water stays 9
  │   → 10 arrives → dispose 10 then 11 in order; high water becomes 11
  └ no acknowledgement → Transfer failed · Retry / Close; Mac deadline remains valid
```

Sleep, lock, relaunch, and connectivity loss never extend the accepted duration. If the monotonic
epoch/anchor cannot be resumed, the ritual closes operationally with no `timerFinished` or fresh
schedule. Same-generation candidates settle, the old projection epoch is signed/fenced, then the
60-second grace begins; only fence + grace permits re-offer. The recovery projection says no finish
was recorded, then says **still due** only if the retained schedule is due. An accumulating/manual-
early schedule instead says the timer was not restored and the schedule was not reset, while the
menu keeps its actual phase. A manual Paused menu remains **Paused: [selected reason] · timer not
restored**; system, working-hours, qualified-away, and accepted-ritual pauses use the matching
registered qualified reason without requiring a selected reason. Intentionally hidden system
detail uses **Paused · timer not restored**. Held remains **Held: [qualified evidence reason] · timer not restored**, whether
the retained schedule is due or not due. Offline intent cannot affect state until a coordinator
renews its lease and revalidates generation/phase/revision. Duplicate, unknown,
post-lease, old-generation, or mismatched-cycle actions get explicit current-state receipts, never
silence or an inaccurate zero-change claim. Raw candidates and payload-free compact replay
receipts and sparse counter entries are memory-only for at most 90 seconds and are not history/export
data. The minimized encrypted sender crash-replay outbox is the only raw-action-envelope persistence
exception: it is excluded from backup/history/export/logs and erased after the signed outcome is
atomically moved to `outcome_ack_pending`, at same-epoch `elapsed >= 90`, or on epoch mismatch. The separate minimized outcome-ACK-pending
record contains no action payload and follows the same epoch/age limits. Only strong, fresh,
qualified movement evidence that passes validation/permission gates may support a separate
user-approved schedule restart; weak/stale/ambiguous evidence does nothing and cannot masquerade as the timer or a
user declaration.

Merged visual acceptance creates the deterministic visual segment ID before running projection;
the winning visual exit creates the movement ID before movement offered. OpportunityID + registered
slot/version yield the same IDs on every paired device and through rebase. Every exit, Start,
handoff, or terminal action consumes the already-projected current segment ID.

Keyboard/focus comes from one state registry. Return/Space activates the focused enabled control.
Live selects one exact phase/segment row; it exposes only that row's registered remote actions and
focus order, and `Just the visual one` exists only in merged movement offered. Neutral
offline/expired/transfer-failed focus Retry; offline-terminal-ACK-unknown focuses Check status;
offline-nonterminal-ACK-unknown also focuses Check status; transfer-pending focuses Cancel transfer;
terminal/nonterminal ACK revalidating focuses Cancel reconnect; terminal- and nonterminal-pending,
rejected, and already-ended focus Close. Focus order is exactly the available control IDs, never
a status placeholder or disabled trigger. Escape and Command-period always dismiss status only;
the named Cancel transfer/Cancel reconnect controls alone cancel those uncommitted operations. Every transition has visible copy
and one VoiceOver announcement. The fallback requires no HealthKit, motion, location, camera, or
other sensor data.

---

## Flow-level invariants

1. Every interrupting surface can be exited with **Escape**, with no confirmation.
2. No flow ever queues two interruptions. Merge or drop.
3. No flow escalates in size, color, or tone on repetition.
4. No flow asks the user to justify a decline.
5. No flow claims verification of anything the Mac cannot observe.
6. Every flow that a permission could enable also has a full no-permission path.

---

## F-15 · Continue a movement break on iPhone

```text
Mac movement option accepted
  -> Continue on iPhone
    -> Handoff opens the exact opportunity on iPhone
      -> one selected instruction + remaining time
      -> local Live Activity starts
      -> Dynamic Island and Lock Screen project the same opportunity
      -> paired Watch may project it through iPhone
  -> user chooses Done early, I already moved, or Skip on any active surface
     OR continuous deadline reaches zero
  -> action is persisted locally before the surface closes
  -> first valid resolution wins
  -> optional private sync reconciles the exact opportunity to Mac
```

No continuation occurs without the user's action. iPhone is complete without Watch. The Mac
break remains available if Handoff fails, and no remote response delays Mac timing.

## F-16 · Companion offline and delayed delivery

```text
Companion action occurs while offline, signed out, or counterpart unreachable
  -> write action to the local idempotent queue
  -> close the local active presentation honestly
  -> show Waiting to sync where status remains visible
  -> reconnect
  -> replay action with the same actionID and opportunityID
  -> reducer accepts it only if the opportunity is unresolved
     -> accepted: all reachable surfaces close
     -> duplicate, stale, or late: retain as reconciled no-op
```

The UI never says `Synced` before acknowledgement. A delayed companion action can update the
exact opportunity history but cannot open a break retroactively or alter the due calculation.

## F-17 · Enable or disable private companion sync

```text
Settings -> Apple companions -> Private iCloud sync
  -> plain-language disclosure of fields, private zone, offline queue, and deletion behavior
  -> explicit opt-in
  -> available: reconcile pending minimal actions
  -> unavailable or signed out: local companions keep working; show Waiting for iCloud
  -> turn off: explain local and private-cloud copies before applying
  -> delete synced companion data: confirm exact scope, then acknowledge only after deletion
```

Handoff and local Live Activities do not require this setting. Refusal, unavailability, or
later revocation affects only durable automatic reconciliation.

## F-18 · Companion resolution elsewhere

```text
Phone or Watch displays an active opportunity
  -> first resolution arrives from another device
  -> stop local deadline presentation
  -> replace actions with Ended on another device
  -> retain any later local tap as a no-op, never a second outcome
```

Timer expiry maps only to `timerFinished`; it never becomes proof of movement. Sensors cannot
enter any resolution branch.

## F-19 · Understand Paused, Held, and Why now

```text
Status says Paused
  -> open status: exact user/system pause reason + clocks stopped + end condition
  -> Resume ends the pause; Why now opens the same operational receipt

Status says Held
  -> open status: due need continues + presentation reason + expected release
  -> Why now -> noticed source + inference/uncertainty + effect + authority + correction
  -> Release hold changes delivery only; Not a call expires the assessment
```

Paused and Held never share copy even if they share a glyph. When evidence is
stale, revoked, or disputed, the hold releases through the ordinary landing
corridor without marking a break complete or discarding need.

## F-20 · Enable one optional observation and effect

```text
Sensing & Intelligence -> choose capability
  -> sample preview while source remains Off
  -> value + exact source/observations + device/process boundary
  -> raw/derived lifetime + energy + fallback + export/delete + indicator
  -> Not now: close, core unchanged
  OR Use this session / Continue
    -> choose named observations and time scope
    -> system permission only after Continue
    -> denied: PM-11, core/manual path focused, no repeat prompt
    -> granted: show live derived fact or Unknown
      -> choose Off/Shadow, Suggest, or one enumerated automatic effect
      -> separate effect receipt -> capability center
```

Returning from System Settings never restores source or automatic authority
silently. Enabling one camera observation does not enable the others. Research
export, analytics, companion exchange, private sync, and model use each remain
Off unless separately chosen.

## F-21 · Inspect and correct a capability decision

```text
Why now / Weekly decision / capability last decision
  -> Sensing inspector
  -> What it noticed: source, device, time/freshness, quality, versions
  -> What it inferred: assessment, uncertainty, contradictions
  -> What it changed: before/after delivery or schedule only
  -> Why allowed: active deterministic rule + effect receipt + expiry
  -> Undo when still valid OR source-specific correction OR Stop source
  -> correction expires assessment and records correction separately
  -> current opportunity facts remain unchanged
```

`Not a call`, `I was here`, `This distance is comfortable`, `This position is
comfortable`, and `That was not my movement` never require free text. The app
does not praise correction, blame the person, or ask them to train it.

## F-22 · Shadow, Suggest, and bounded automatic graduation in use

```text
Shadow
  -> inspector/audit shows what would have changed + counterfactual time
  -> no status, clock, delivery, notification, timer, or opportunity changes

Suggest
  -> one bounded proposal with evidence summary
  -> Accept applies exactly once OR Not now / Never suggest makes no change

Bounded automatic
  -> policy firewall validates source + freshness + consent + exact effect
  -> record decision -> apply enumerated effect -> expose Why now + Undo
  -> invalid/stale/conflicting/revoked/resource-limited -> Unknown -> fallback
```

No level can mark completion, create a health outcome, increase reminder
frequency or loudness beyond the chosen schedule, or let a model response apply
an effect.

## F-23 · Stop all sensing without pausing schedules

```text
Status menu or SI-01 -> Stop all sensing
  -> stop acquisition before navigation or confirmation
  -> flush raw buffers -> expire observations/assessments -> stop effects
  -> show source list stopped + `Schedules are still on`
  -> offer scoped Delete capability data / Delete calibration / Close
```

Escape closes the receipt and never resumes sensing. Restart/relaunch leaves the
sources Off until the person explicitly enables them again.

## F-24 · Use the calm core after denial, revocation, or failure

```text
source denied / revoked / unsupported / offline / conflicted / resource stopped
  -> capability becomes Unavailable or Unknown
  -> no negative inference and no automatic effect
  -> current manual clock, status, break, Pause/Hold, and correction paths remain
  -> one factual status with manual equivalent focused
  -> Try again or Open System Settings only on explicit action
```

This flow is required independently on Mac, iPhone, and Watch. A missing Watch,
HealthKit type, visible face, supported gait, accessory, or Foundation Model is
ordinary capability absence, not user failure.

## F-25 · Keep Nothing, export, and delete capability data

```text
Privacy & data -> Keep Nothing
  -> list data that stops persisting
  -> list settings/receipts/rules/live coordination that must remain
  -> confirm -> erase retained history -> keep live ephemeral operation

Export or Delete
  -> choose record families + local device / paired device / private cloud scope
  -> show exact included/excluded fields and destination/effect
  -> execute
    -> verified complete: scoped receipt
    -> partial: completed + remaining families/devices + reason + Retry
```

History, calibration, rules, capability stop, unpairing, private-cloud deletion,
and reset are separate actions. No success message appears before each selected
scope acknowledges completion.

## F-26 · Use whole-desk modules without a reminder pile

```text
Sensing & Intelligence -> Whole-desk modules
  -> choose one setup/environment/content/user-authored routine
  -> exact source/manual input + claim boundary + frequency/effect preview
  -> Off / run now / Suggest inside existing interruption budget
  -> raw fact or user declaration remains distinct from recommendation
  -> unavailable source -> manual/no-module route
```

Setup, light/glare, humidity/air quality, hearing, breathing, work boundary,
hydration, maintenance, and Shortcut actions do not create independent nag
clocks, symptom attribution, quotas, or condition-specific advice.

## F-27 · Audit the assistant in Weekly

```text
Weekly rhythm -> Assistant activity disclosure
  -> factual holds/restarts/suggestions/corrections/resource stops/unused modules
  -> select one row -> SI-03 decision chain
  -> Quiet rule / Turn off capability / Correct / Close
```

The disclosure is absent when Keep Nothing retained no eligible decisions. It
shows null and mixed records without rewriting them as progress. It contains no
person score, target, praise, shame, streak, outcome trend, or comparison.

## F-28 · Draft an explanation with Foundation Models

```text
user invokes Explain or Draft rule
  -> show minimized input facts before use
  -> model unavailable/offline: deterministic explanation immediately
  -> model available: label generated draft + source facts
  -> Edit / Use as proposed deterministic rule / Discard
  -> choosing Use enters normal rule confirmation; no direct schedule effect
```

Protected raw data and free-text medical history never enter the prompt. A
refusal, hallucination, unsafe claim, or empty response is discarded and cannot
replace the deterministic fallback.

## Optional-capability flow invariants

1. Source consent, system permission, effect authority, research participation,
   analytics, device exchange, and sync are separate choices.
2. Every active protected source has a persistent non-color indicator and one-
   action stop; no screen, lock, or interruption hides acquisition.
3. Every effect has `Why now?`, provenance, correction, expiry, and rollback.
4. No signal, weak signal, stale signal, conflict, or non-detection is unknown,
   never evidence against the person.
5. The sensor-free/manual Mac path is complete; iPhone is complete without
   Watch; no purchase, body motion, camera visibility, or self-report is owed.
6. A capability can become quieter or turn itself Off after errors. It cannot
   increase pressure, hide its mistakes, or infer a health outcome.
