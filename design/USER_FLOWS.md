# User Flows

Flows are written as **decision paths**, not happy paths. Every flow states its exit, its
suppression behavior, and what the product records. Screen IDs refer to `SCREEN_INVENTORY.md`.

Legend: `→` next step · `⤳` background/no UI · `✕` flow ends

---

## F-01 · First launch

```
Install → launch → ON-01 What this is
  → ON-02 What it can and cannot know          (the honesty screen; not skippable content,
                                                but the whole flow is skippable)
  → ON-03 Choose a rhythm  [Gentle | Balanced✓ | Frequent]
  → ON-04 How you move     [Walk/wheel | Seated active | Small space | Position change]
  → ON-05 Comfort          [Reduce motion ✓auto | Static mode | Dimming level]
  → ON-06 Ready            ("Working now." Integrations named, not requested.)
  ✕ Menu bar item appears (MB-01). Clocks start.
```

- **Skip at any point** → ON-07: Balanced profile, all four movement options offered
  equally, no permissions requested, no reminder to finish setup.
- **No permission is requested during onboarding** `[09 §7 permission-first onboarding]`.
  Notifications are requested at F-03 step 1; Calendar at SE-12.
- Target: under 90 seconds, six screens, no account.

---

## F-02 · Steady state (the flow that runs 40× a day)

```
⤳ activity estimator running (CGEventSource; 60 s window)
⤳ four clocks advancing: visual · movement · position · recovery
  → visual clock reaches soft-due (20 min, Balanced)
    → MB-02 glyph changes            ← Level 0. This is the whole interaction 
                                        most of the time.
    → suppression check (PRODUCT_MODEL §6)
        suppressed → ⤳ hold, accumulate per policy, do not queue duplicates
        clear      → wait for a low-friction moment (max: latest_preferred 30 min)
    → F-03
```

**Design consequence:** the default outcome of a due clock is a *glyph change*, not a screen.
If a direction cannot make MB-01→MB-02 legible and calm, the direction fails.

---

## F-03 · Visual reset

```
HU-01 heads-up (45 s before target)
  ├ Start now          → BR-01 → BR-02 (≈20 s) → BR-03 blink cue → timerFinished
  │                      → AK-02 (nothing shown) ✕  clock resets
  ├ In 5 minutes       → snoozed(300) → return to F-02 ✕
  ├ More options       → HU-05 → BR-13 [5·10·15 min | after meeting | pause 1 hr |
  │                                     not appropriate]
  └ ignored            → at target: BR-01 appears
                          ├ Escape / click away → skipped ✕   (never blocked, never re-shown
                          │                                    for this opportunity)
                          ├ "I already looked away" → userDeclaredCompleted ✕
                          └ run to completion → as above
```

- **One escalation maximum per opportunity** `[protocol: max_repeated_escalations_per_opportunity: 1]`.
- Escape always exits. There is no confirmation on exit.
- Nothing is verified. `timerFinished` and `userDeclaredCompleted` are recorded distinctly.

---

## F-04 · Movement opportunity

```
HU-02 heads-up
  → BR-05 offered  [Start 5 minutes (primary) | 2 minutes | Choose activity | Not now]
      ├ Choose activity → BR-06  four equal options:
      │     walk/wheel [L01] · seated active [M02] · small space [L03] · position change [P01]
      │     └ position change chosen → F-05 (does NOT reset the movement clock)
      ├ Start 5 min / 2 min → BR-07 running → BR-08 "Done" → userDeclaredCompleted ✕
      │     └ user leaves the Mac entirely → timer continues → on return, BR-08
      ├ "I already moved" → userDeclaredAlreadyMoved ✕  (no follow-up question)
      └ Not now → BR-13 snooze sheet
```

- The movement clock resets **only** on `userDeclaredCompleted` /
  `userDeclaredAlreadyMoved` for a movement activity.
- Idle never resets it. A `likelyNaturalInterruption` is recorded and **does not count**
  `[protocol: likely_natural_interruption.counts_as_movement: false]`.
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
  ├ complete both → both clocks reset ✕
  ├ "Just the visual one" → BR-10 → visual resets, movement remains due,
  │                          screen says so plainly, returns to F-02
  └ Escape at any point → whatever completed is recorded; the rest stays due ✕
```

---

## F-07 · Snooze and repeated deferral

```
snoozed(n) → suppression active for n → opportunity returns once
Second deferral of the same opportunity → no immediate re-offer; wait for the next normal cycle
Further deferrals → NO escalation: no bigger surface, no color change, no counter, no guilt copy
Session pattern (ED-15): after the session, at most one neutral note in the
  weekly rhythm or a settings suggestion — "Balanced may be too frequent for how you
  work. Try Gentle?" — never mid-session, never as an interruption.
```

This flow is where most competitors fail. It is a first-class design target, not an edge case.

---

## F-08 · Pause and presentation

```
MB-12 → [30 min | 1 hour | Until… | Until tomorrow | While presenting]
  → MB-04 glyph + MB-08 menu state showing what is paused and until when
  → resume is always one click
Presentation mode left on (ED-14): once, quietly, at the next natural moment —
  "Still paused for presenting. Resume?" Dismissible. Never repeated in the same session.
```

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
recoveryDebtSeconds eligible (90 min, Balanced) and typically by 120 min
  → BR-12: a longer break, 5–10 min, offered once
  → declined → not re-offered as a longer break this session
Tone: an offer between peers. Never an alarm, never "you have not taken a real break."
```

---

## F-12 · Changing the schedule

```
SE-02 → profile or custom
  Very frequent (SE-03) or effectively disabled (SE-04):
    → one neutral note about what that means. No warning icon, no block, no shame [03 §5].
Default changed by an app update (ED-18): first launch after → say what changed and why,
  offer to keep the old value. Never silently re-tune someone's schedule.
```

---

## F-13 · Privacy and data

```
SE-09 → what is stored (plain list) · retention · export · delete
  → SE-11 export: describes each field before writing the file
  → SE-10 delete: states exactly what will be removed and what remains
Nothing here is buried, and nothing requires an account to reach.
```

---

## Flow-level invariants

1. Every interrupting surface can be exited with **Escape**, with no confirmation.
2. No flow ever queues two interruptions. Merge or drop.
3. No flow escalates in size, color, or tone on repetition.
4. No flow asks the user to justify a decline.
5. No flow claims verification of anything the Mac cannot observe.
6. Every flow that a permission could enable also has a full no-permission path.
