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

- **One escalation maximum per opportunity** `[protocol: max_repeated_escalations_per_opportunity: 1]`.
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
  ├ visual timer / Done early → retain fresh visual effect → movement offered
  │   ├ accept 5 / 2 min → movement running
  │   │   ├ timer / Done early → fresh movement; visual remains fresh ✕
  │   │   ├ I already moved → declared movement fact; visual remains fresh ✕
  │   │   ├ Change position → position fact/cycle; visual remains fresh ✕
  │   │   ├ content changes → selected duration is unchanged
  │   │   └ Skip / Escape → skipped movement schedule; visual remains fresh ✕
  │   ├ Change position → position fact/cycle; base participants remain visual+movement ✕
  │   ├ Just the visual one (V) → BR-10 → visual fresh, movement remains due ✕
  │   └ Skip / Escape → skipped movement schedule; visual remains fresh ✕
  └ Escape during visual → skipped facts; fresh schedules prevent rapid re-offer ✕
     Escape during movement → retain finished visual effect; skipped movement starts fresh ✕
```

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
```

Core function requires **zero** permissions `[protocol: required_for_core: []]`.

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
    → preserve every v1 field, unit, ordering, and value; change only contract version,
      identifier to custom_v2, and migration state
  Adaptive starts at the current Balanced v2 contract and initially changes only delivery within the due window
    and bounded automatic holds, never reminder frequency or a health conclusion
  Very frequent (SE-03) or effectively disabled (SE-04):
    → one neutral note about what that means. No warning icon, no block, no shame [03 §5].
Default changed by an app update (ED-18): first launch after → say what changed and why,
  offer to keep the old value. Never silently re-tune someone's schedule.
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
  → Mac sends OpportunityID + independent ClockCycleIDs + absolute deadline + ActionID
  ├ companion acknowledges bounded monotonic handoff + ≤90 s projection lease → Synced
  │   ├ terminal action on any device → local projection closes immediately
  │   └ action set reconciles by deterministic key, never arrival order
  │       → winner materializes one terminal product fact and clock effect
  │       → other devices show Ended elsewhere; losing actions stay companion-ledger only
  └ no acknowledgement → Transfer failed; Mac deadline remains valid
```

Sleep, lock, relaunch, and connectivity loss never extend the accepted duration. If the monotonic
epoch/anchor cannot be resumed, the ritual closes operationally with no `timerFinished` or fresh
schedule and the due need is re-offered after grace. Offline intent cannot affect state until a
coordinator renews its lease and revalidates phase/revision. Duplicate, unknown, settled,
post-lease, or mismatched-cycle actions are auditable no-ops. A sensed movement observation
may support a separate user-approved schedule restart; it cannot masquerade as the timer or a
user declaration.

---

## Flow-level invariants

1. Every interrupting surface can be exited with **Escape**, with no confirmation.
2. No flow ever queues two interruptions. Merge or drop.
3. No flow escalates in size, color, or tone on repetition.
4. No flow asks the user to justify a decline.
5. No flow claims verification of anything the Mac cannot observe.
6. Every flow that a permission could enable also has a full no-permission path.
