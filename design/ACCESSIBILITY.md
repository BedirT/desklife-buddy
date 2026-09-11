# Accessibility

Accessibility here is not a compliance pass at the end. Two of this product's core claims —
equal-status movement alternatives `[C003]` `[C047]` and "move in a way that works for you" —
are **accessibility claims**. If the design fails them, the product's positioning is false,
not just imperfect.

Rules live in `.claude/rules/accessibility.md`. This file holds the per-screen annotations and
the product-level commitments.

---

## 1. Product-level commitments

| # | Commitment | Fails if |
|---|---|---|
| A1 | Every interrupting surface is fully keyboard-operable, including exit | Escape doesn't dismiss, or the primary action needs a pointer |
| A2 | Movement alternatives are equal in placement, size, and weight | Walking is primary and the rest are "alternatives" (`D-010`) |
| A3 | Nothing conveys state by color alone | Due/paused readable only by hue |
| A4 | Respects Reduce Motion, Increase Contrast, Reduce Transparency, and Display text size, live | Requires a restart to take effect (ED-08) |
| A5 | No flashing, strobing, or rapid luminance change; dimming fades slowly | Any transition faster than ~250 ms into a large luminance change |
| A6 | VoiceOver announces state changes once, not continuously | Per-second timer announcement — an explicit defect |
| A7 | Every feature works at the largest system text size without clipping or scroll traps | Break copy truncates at large text |
| A8 | Denied permissions degrade to a working path, never a dead end | Notification denial removes the heads-up entirely |
| A9 | No time limit forces an action; timers describe, they don't gate | The user is dropped out of a break by a timeout |
| A10 | Static mode: a full text-only presentation of every break | A break requires perceiving animation or an image |

**Target:** WCAG 2.2 AA as a floor for contrast, focus visibility, and target size; Apple
platform behavior where it is stricter.

---

## 2. Required per-screen annotation block

Every screen at `designed` or beyond carries this block, filled in — no blanks, no "TBD".
An unanswerable field means the design is incomplete.

```
### <SCREEN-ID> — <name>

1.  Keyboard path        — how it is reached and operated without a pointer
2.  Initial focus        — what is focused when it appears, and why
3.  Focus order          — the complete tab ring
4.  Escape               — what Escape does (must always do something sensible)
5.  VoiceOver names      — accessible name for every element
6.  VoiceOver values     — dynamic values and when they are announced
7.  Text scaling         — behavior from default to largest; reflow rules
8.  Increase Contrast    — what changes
9.  Reduce Motion        — what is removed or replaced; static equivalent
10. Meaning without color— how each state reads in grayscale
11. Alternative movement — the non-ambulatory equivalent (break screens only)
12. Multi-display        — behavior across displays
```

---

## 3. Reference annotations (to be completed during design)

> **2026-09-01 reconciliation note.** `SCREEN_INVENTORY.md` §K and the blocks below describe
> one contract. Visual and merged-visual fields run immediately and focus **Done early**.
> Movement is different: `Now` opens a distinct **offered** field with no timer, `breakStarted`,
> or Done early; focus starts at **Start 5 minutes**. Accepting 5 or 2 minutes enters the running
> field and only then records `breakStarted`. No default global hotkeys ship (D-029). Change
> position keeps an equal semantic rank and 44px target while being visually tertiary and logged
> separately. Increase Contrast raises ink, borders, and the horizon track rather than adding a
> dim layer. These clauses supersede only older artwork/runtime behavior, not one another.

The three below are the load-bearing ones. Design directions should be evaluated against these
before anything else.

### BR-01/02 — Visual reset

1. **Keyboard path** — appears unprompted; also MB-09. *(A proposed `⌥⌘V` global shortcut
   was removed — D-029.)*
2. **Initial focus** — "Done early," the least-destructive declaration.
3. **Focus order** — Done early → Skip → wraps. Two stops.
4. **Escape** — dismisses immediately, records `skipped`, no confirmation, no re-prompt for
   this opportunity (`D-009`).
5. **VoiceOver names** — surface announces once: purpose, duration, actions available.
6. **VoiceOver values** — the timer is announced at **start** and at **completion** only.
   Optionally once near the end for the blink cue. Never per second (A6).
7. **Text scaling** — the instruction line reflows; it never truncates and never scrolls. If
   it cannot fit at the largest size, the layout is wrong, not the copy.
8. **Increase Contrast** — the already-opaque field raises ink, border, and horizon-track
   contrast; it does not add a dimming layer.
9. **Reduce Motion** — no fade of the content, no moving focal element. Dimming still
   transitions, but as a slow opacity change only (A5). Static mode replaces any animated
   focal cue with text.
10. **Meaning without color** — the state is carried by the copy and the timer, never by hue.
11. **Alternative movement** — n/a (visual). But `[V04]` "eyes closed" must be reachable for
    users for whom looking into the distance is not practical `[04 §4]`.
12. **Multi-display** — see DQ-03. Content appears once; the dimming is consistent everywhere.

### BR-05/06 — Movement offer and activity choice

1. **Keyboard path** — MB-10, HU-02, or the break surface. `Now` opens offered; Return/5 and
   Q/2 accept durations. A/P/Escape/Command-period and every pointer control work first-frame.
2. **Initial focus** — offered: "Start 5 minutes"; running: "Done early."
3. **Focus order** — offered: 5 min → 2 min → I already moved → Change position → [merged only:
   Just the visual one] → Skip. Running: Walk or wheel → Small space → Seated → Done early →
   I already moved → Change position → Skip.
4. **Escape** — dismisses immediately and records `skipped` from offered or running.
5. **VoiceOver names** — offered duration controls are "Start five minutes, Return or 5" and
   "Start two minutes, Q or 2". Running activity options are siblings with parallel names
   ("Walk or wheel", "Seated movement", "Small space") — never "Walk" plus "Accessibility
   alternatives". "Change position instead, P, logged separately" has equal semantics without
   pretending it completes movement. Merged offered additionally names "Just the visual one, V."
6. **VoiceOver values** — offered announces "Timer not started." Running announces the selected
   duration at start and completion, with at most one halfway announcement.
7. **Text scaling** — the three equal-rank content choices stack vertically; separate
   duration/declaration/position/exit controls follow in reading order and never become a
   horizontal scroller.
8. **Increase Contrast** — option boundaries become explicit.
9. **Reduce Motion** — no animated demonstrations. Instructions are text `[04 §2]`.
10. **Meaning without color** — the selected activity is indicated by more than a tint.
11. **Alternative movement** — this screen *is* the commitment. Seated and small-space options
    carry the same type size, same target size, same position class as walking. Change position
    remains reachable when position reminders are off; it rotates the manual cycle without
    enabling prompts and remains explicitly separate from movement completion.
12. **Multi-display** — as BR-01.

### ED-20/21 — Companion timer projection

1. **Keyboard path** — Return/Space activates the focused enabled control. Offline, expired, and
   transfer-failed expose **Retry** and **Close**. Transfer-pending exposes **Cancel transfer**;
   neutral revalidating exposes **Cancel reconnect** and **Close**; offline-terminal-ack-unknown
   exposes **Check status** and **Close**; revalidating-terminal-ack-unknown exposes **Cancel
   reconnect** and **Close**; terminal-action-pending and nonterminal-action-pending expose **Close**
   because a submitted action cannot be cancelled. Offline-nonterminal-ack-unknown exposes **Check
   status** and **Close**; revalidating-nonterminal-ack-unknown exposes **Cancel reconnect** and
   **Close**.
2. **Initial focus** — Live uses the exact phase/segment row's registered focus target. Running
   transferable rows focus Take with me; merged movement offered instead focuses **Start 5 minutes**;
   Neutral offline/expired/transfer-failed focus Retry;
   both offline terminal/nonterminal-ack-unknown states focus Check status. Transfer-pending focuses Cancel transfer;
   all three revalidating states focus Cancel reconnect; terminal/nonterminal pending, rejected,
   and already-ended focus Close. No absent or disabled trigger receives focus. `Just the visual one` exists only in
   merged movement offered.
3. **Focus order** — exactly the enabled control IDs registered for that state. Status is read but
   not a fake focus stop. Unavailable phase-specific controls are absent, not disabled. Merged
   movement offered is Start 5 → Start 2 → I already moved → Change position → Just the visual one
   → Skip, with Return/5, Q/2, A, P, V, and S respectively.
4. **Escape** — Escape or Command-period dismisses the status projection only in every companion
   state. It never sends Skip/terminal action or cancels a transfer/revalidation; those cancellations
   require their named enabled controls.
5. **VoiceOver names** — semantic action names, never device appearance or sensor language.
6. **VoiceOver values** — exactly one registered announcement for live, neutral offline,
   offline-terminal-ack-unknown, offline-nonterminal-ack-unknown, expired, transfer-pending,
   terminal-action-pending, nonterminal-action-pending, neutral revalidating,
   revalidating-terminal-ack-unknown, revalidating-nonterminal-ack-unknown, rejected-no-op, already-ended, or
   transfer-failed. Terminal pending names the selected action, never “Sending timer.” Unknown ACK
   states preserve and name that action: terminal actions say “received”; Start actions say
   “started.” Both say “Do not repeat.”
   Check status/reconnect never resends it. Neutral states explicitly say no companion operation is
   pending. Epoch/age uncertainty announces CP-VO39 exactly once: “That action is too old to
   verify. Showing the current timer. Close.” It never reuses the rejected-no-op announcement or
   claims whether the action was applied. No silent no-op.
7. **Text scaling** — state and recovery copy wrap above a vertical action group.
8. **Increase Contrast** — labels, traits, focus rings, and boundaries distinguish every state.
9. **Reduce Motion** — immediate state replacement; no spinner or transfer animation required.
10. **Meaning without color** — each state has explicit text and enabled action labels; no pending
    or failure meaning depends on color or a disabled trigger.
11. **Alternative movement** — sensor-free manual controls remain on the authoritative device;
    Watch/iPhone ownership, motion, location, HealthKit, walking, and standing are not required.
12. **Multi-display** — the Mac key panel remains reachable until acknowledged handoff; failure
    returns focus without stranding a panel. Take with me exposes “Send to [paired name]” and its
    VoiceOver name before activation; that label binds the exact receiver, not device appearance.

### ED-19 — Timer recovery unavailable

1. **Keyboard path** — Close works with Return, Escape, and Command-period; Retry is shown only
   when a failed fence/storage transaction can be attempted again.
2. **Initial focus** — Close, or Retry when it is the only recovery action.
3. **Focus order** — recovery status → Retry when present → Close.
4. **Escape** — closes the unusable ritual without recording skip, completion, or timer finish.
5. **VoiceOver names** — due: “Timer could not be restored. No finish was recorded. The schedule
   is still due.” Not due/manual early: “Timer could not be restored. No finish was recorded. This
   schedule was not reset.” The retained phase selects the string before Close receives focus.
6. **VoiceOver values** — active due says “Still due · timer not restored.” Manual Pause says
   “Paused: [selected reason] · timer not restored.” Outside-hours, inactive, lock, sleep,
   unavailable, qualified-away, and accepted-ritual pauses use their registered evidence-qualified
   reason without requiring a selected reason; intentionally hidden system detail says “Paused ·
   timer not restored.” When reasons overlap, manual, locked, inactive, sleeping, unavailable,
   accepted-ritual, confirmed-away, outside-hours, then hidden-system precedence selects one stable
   qualified projection. Held always says “Held: [fresh,
   provenance-qualified reason] · timer not restored,” whether due or not due. Other not-due state
   reads the ordinary retained schedule status plus “timer not restored”; no countdown chatter.
7. **Text scaling** — title, body, and actions wrap in one vertical group.
8. **Increase Contrast** — explicit boundary and focus ring.
9. **Reduce Motion** — immediate quiet transition, no entrance/exit gate.
10. **Meaning without color** — “still due” appears only when true; otherwise “schedule was not
    reset” plus the actual menu phase carries the state. Paused/Held wording and qualified reason
    remain visible independent of due body copy. “Not restored” is always explicit.
11. **Alternative movement** — no body state or completion is inferred.
12. **Multi-display** — one key recovery status, one focus restoration, actual menu phase reachable.

### Restart Undo — stale receipt

1. **Keyboard path** — Close works with Return, Escape, and Command-period; no stale Undo control remains.
2. **Initial focus** — Close.
3. **Focus order** — message → Close.
4. **Escape** — dismisses only this receipt and does not change the schedule.
5. **VoiceOver names** — “Close, button.”
6. **VoiceOver values** — announces CP-VO37 exactly once: “That restart can no longer be undone.
   Your current schedule was not changed. Close.”
7. **Text scaling** — message and Close stack and wrap without clipping.
8. **Increase Contrast** — explicit boundary and focus ring.
9. **Reduce Motion** — immediate replacement with no travel or spinner.
10. **Meaning without color** — the rejection and unchanged-current-schedule result are written.
11. **Alternative movement** — no movement, completion, or sensor claim appears.
12. **Multi-display** — one receipt and one stable Close focus on the active key panel.

### Settings Custom v2 — partial edit

1. **Keyboard path** — Tab reaches every editable field/group, its inline error, Save, and Cancel.
2. **Initial focus** — the first user-selected field, otherwise the first field.
3. **Focus order** — timing fields in visual then movement order → duration groups → Save → Cancel.
4. **Escape** — cancels the edit without changing stored values.
5. **VoiceOver names** — each field names its unit and clock; arrays are one named editable group.
6. **VoiceOver values** — untouched migrated values are read exactly; validation names only the dirty
   field/group or necessary ordering peer, then focuses the first invalid dirty control.
7. **Text scaling** — labels, values, and inline errors stack without horizontal scrolling.
8. **Increase Contrast** — focus and invalid state use outline, icon, and text, not color alone.
9. **Reduce Motion** — error/focus changes are immediate.
10. **Meaning without color** — invalid state is written and associated with the control.
11. **Alternative movement** — movement duration choices remain user-authored, not capability claims.
12. **Multi-display** — one Settings window owns the edit and restores focus after validation.

### MB-01…MB-05 — Menu bar glyph

1. **Keyboard path** — reachable via the system menu bar keyboard shortcut (`⌃F2` /
   Keyboard Navigation). No default global shortcut is installed.
2. **Initial focus** — first menu item.
3. **Focus order** — status region (if focusable) → items in visual order.
4. **Escape** — closes the menu.
5. **VoiceOver names** — the extra announces the product and its current state in one phrase,
   e.g. "Cadence, movement due" — not "Cadence, image."
6. **VoiceOver values** — state changes are **not** announced spontaneously. A menu bar item
   that speaks unprompted every 20 minutes is an interruption by another route.
7. **Text scaling** — the glyph scales with the menu bar; the menu uses system metrics.
8. **Increase Contrast** — template rendering handles this; verify against a busy wallpaper.
9. **Reduce Motion** — no animated glyph, ever. Not on due, not on completion (`D-004`).
10. **Meaning without color** — mandatory: the glyph is monochrome by construction (`D-004`).
11. **Alternative movement** — n/a.
12. **Multi-display** — the extra appears on the active display's menu bar; behavior when the
    menu bar is hidden in full-screen is ED-16.

### SE-05/06 — Content library browser and card detail

1. **Keyboard path** — Back to Break content → category menu or category rail → card rows →
   detail actions; every card is a native button.
2. **Initial focus** — the category control in compact mode; the selected category in wide mode.
3. **Focus order** — visual reading order, with the card list before detail content.
4. **Escape** — exits the Settings window through the existing Settings command behavior.
5. **VoiceOver names** — categories and cards expose their localized names and stable identifiers;
   the read-only nature is stated in the page copy.
6. **VoiceOver values** — card duration, instructions, alternative, and source are read in detail
   order without decorative symbols.
7. **Text scaling** — largest text uses the compact category/list and full-width detail paths;
   no horizontal scrolling is required.
8. **Increase Contrast** — selected category and card gain an explicit violet outline in addition
   to the selected surface tint.
9. **Reduce Motion** — no authored motion is required; navigation remains an immediate state change.
10. **Meaning without color** — selected states use position, labels, and outline in addition to
    violet.
11. **Alternative movement** — not applicable; this is a read-only settings reference surface.
12. **Multi-display** — the Settings window remains a standard movable macOS window.

---

## 4. The six personas every screen is walked against

From `.claude/rules/accessibility.md`. A screen is not `reviewed` until all six pass.

1. **VoiceOver user, no pointer** — can they know what happened, act, and leave?
2. **Wheelchair user** — is the movement offer theirs, or is it someone else's with a
   substitute?
3. **Low-vision user at largest text with Increase Contrast** — does anything clip, overlap,
   or lose contrast?
4. **User with migraine or photosensitivity** — does anything flash, or brighten suddenly, or
   force motion? Is static mode complete?
5. **Keyboard-only user, no VoiceOver** — is focus always visible and never trapped?
6. **User with a cognitive/attention difference** — is there exactly one obvious thing to do,
   and one obvious way out?

---

## 5. Known accessibility risks in this design

| Risk | Where | Mitigation |
|---|---|---|
| Equal-status alternatives that are equal in code but not in feel | BR-06, ON-04 | `OQ-12`: co-design with disabled users. Do not self-certify `[C003]`. |
| Dimming that reduces contrast for low-vision users | All break surfaces | Contrast is measured against the dimmed composite, not against the surface color |
| A calm, low-contrast aesthetic drifting below AA | Everywhere | Contrast is a hard gate in `/design-review`, checked before aesthetics |
| A silent product being unnoticeable | HU-04, ED-16 | DQ-05 |
| Timer announcements becoming chatter | BR-02, BR-07 | A6, fixed announcement points |

## 6. iPhone and Apple Watch companion requirements

Companions preserve the Mac product's autonomy and declaration model while adapting to touch,
Lock Screen, Dynamic Island, Smart Stack, and Watch constraints.

### IP-02 and LA-01/03 - active iPhone movement

```text
Input path           - Touch and Voice Control reach every action. No keyboard keycap is shown
                       on a touch-only surface. Hardware keyboard Escape dismisses only where
                       the platform delivers it without shadowing a system command.
Initial focus        - Instruction heading, then remaining-time value. Focus does not jump on
                       each timer update.
Focus order          - Instruction -> remaining time -> Done early -> More actions -> status.
                       Expanded alternatives read I already moved, Skip, then movement choices.
VoiceOver names      - Break type and selected instruction are separate headings. Buttons use
                       their exact visible labels. More actions announces menu state.
VoiceOver values     - One start announcement, optional coarse milestones, and one resolution
                       announcement. Never announce every second.
Text scaling         - System text styles only. At accessibility sizes the layout becomes one
                       vertical reading column, actions remain at least 44 by 44 points, and
                       no instruction, status, or declaration clips.
High contrast        - Semantic edges and text rise independently of peach/violet accents.
Reduced motion       - No traveling landscape, pulsing timer, or interpolated elapsed line.
                       State changes use a static replacement or system crossfade.
Meaning without color - Selected content is named and checked. Waiting, offline, and ended
                       states use text and symbols, never hue alone.
```

Live Activity regions may expose fewer controls, but they must never merge `Done early`,
`I already moved`, and `Skip` into one ambiguous action. If a region cannot fit the secondary
actions accessibly, it opens the foreground iPhone surface.

### WA-01 - active Watch movement

```text
Input path           - Digital Crown scrolling, touch, AssistiveTouch, and VoiceOver can reach
                       the full instruction and every declaration.
Initial focus        - Instruction heading. The timer is next and never steals focus.
Focus order          - Instruction -> remaining time -> Done early -> More actions -> status.
VoiceOver names      - Exact visible action labels with no fitness, goal, ring, or score terms.
VoiceOver values     - Start, coarse timer milestones if enabled, Waiting to sync when true,
                       and final resolution. No per-second speech.
Text scaling         - One-column reflow. Never place declarations in tiny side-by-side targets.
Haptics              - At most one gentle haptic for an already accepted break. Haptics never
                       indicate success, verification, urgency, or escalating refusal.
Reduced motion       - Static hierarchy and system transitions only.
Meaning without color - Checkmarks, labels, and status text accompany every accent.
```

### Companion failure and reconciliation states

- `Waiting to sync` is a status, not a blocking alert. It is announced once when it changes.
- `Ended on another device` removes stale actions and moves focus to the status heading.
- Handoff failure keeps `Retry` and `Close` reachable and states that the Mac break remains.
- Watch absence or unreachability is never announced as user failure. iPhone remains complete.
- Live Activities disabled, iCloud signed out, or private sync declined never reduce access to
  local companion actions.
- Continuous deadlines reconcile after suspension. A reopened app announces the current state
  once rather than replaying missed countdown announcements.

### SE-16 companion settings results

- Enabling sync, turning it off, deleting synced data, and an operation failure each produce one
  persistence-confirmed result message.
- Accessibility focus moves to that result once when the operation enters its terminal state. It
  does not move during loading, retry, or each view update.
- Successful results provide Dismiss. Failed results provide Retry. Both remain in normal keyboard
  order after the focused message.
- Confirmation cancellation returns to the invoking control and announces no success or failure.

## 7. Optional-capability accessibility contract

Sensing is an enhancement, never the privileged path. The same user goal and
schedule consequence must remain available without camera visibility, a
particular face/body presentation, walking, standing, speech, sound, touch,
iPhone, Watch, HealthKit, accessory hardware, self-report, or Foundation Models.

### 7.1 Platform matrix

| Requirement | Mac | iPhone | Watch |
|---|---|---|---|
| Reach source state | Menu extra, Dock fallback, Settings, SI-01; never menu-bar-only | Foreground companion Settings/status; never Live-Activity-only | Foreground app status; iPhone retains the complete control path |
| Stop acquisition | `Stop all sensing` and per-source stop, keyboard/VoiceOver reachable without disclosure | Per-source Stop; Voice Control/Switch Control reachable | Stop bounded Motion session; Watch never owns the only global stop |
| Understand effect | Text decision chain in SI-03; no graph required | Condensed source/effect/expiry plus open-on-iPhone detail | One source/effect/status; full detail on paired iPhone, not hidden entirely |
| Correct | Full source-specific choices with Undo and Close | Same consequential correction for companion observations | Frequent correction actions locally; uncommon choices open exact iPhone opportunity |
| Denied/revoked | Core/manual action receives initial focus; System Settings link secondary | Local timer/manual declarations remain; authorization route secondary | Timer/manual declarations remain; no repeated permission prompt |
| Offline | Mac clocks and accepted local deadline remain authoritative | Local deadline/action persists with one status announcement | Local deadline/action persists; iPhone relay delay is not failure |
| Largest text | Vertical reflow; no horizontal scrolling or clipped lifecycle copy | System text styles and 44x44-point targets; one column | Crown-scroll one column; no tiny side-by-side controls |
| Nonvisual/nonsound | Full VoiceOver names/values and keyboard path; sensing state is not just menu glyph | VoiceOver/Voice Control and visible text; haptic optional | VoiceOver/AssistiveTouch and visible text; haptic optional |
| Motion/contrast | Static replacement, solid fallback, labeled state | System transitions; labeled state | System transitions; labeled state |

### 7.2 Sensor-free and manual parity

| Capability | Sensor path | Equal-status path | Identical consequence required |
|---|---|---|---|
| Context Sense | likely call/selected timer hold | `Hold while presenting` / timed focus | Same delivery hold and release corridor |
| Camera presence | confirmed-away eligibility adjustment | permission-free active/available-session estimate and Pause | Same schedule bounds; no added pressure when unknown |
| Distance | personal-relative estimate and cue | larger text/setup guide, Recalibrate, or no cue | No penalty, missing insight, or health warning |
| Position | visible-variation suggestion | `I shifted position` / choose another comfortable shape | Same position-clock effect only |
| Blink | sample modifies due visual content | standard visual reset with optional comfortable blink instruction | Same visual opportunity and completion semantics |
| Motion | supported movement observation restarts future timing | `I already moved` or manual timer/declaration | Same future schedule effect; neither is labeled medically verified |
| HealthKit | dated step/workout context | manual declaration or no rule | No lost core action, status rank, or weekly grade |
| Environment | accessory fact and setup experiment | manual value or no module | Same user-authored action, no symptom attribution |
| Subjective | controlled check-in | `Prefer not to answer` / no experiment | Core, schedule, and capability controls remain identical |
| Companion | iPhone/Watch continuation | Mac timer and declarations | Same terminal action mapping; iPhone complete without Watch |
| Foundation Models | generated explanation/rule draft | deterministic facts/template | Same source facts and final rule confirmation |

The manual control appears in the same view and action tier whenever the sensor
action is time-sensitive. It is never called an alternative, accommodation, or
fallback in user-facing copy. Completion animation, acknowledgement, weekly
representation, and correction rights are identical.

### 7.3 Movement diversity and non-detection

Representative validation includes wheelchair propulsion and assisted wheeling,
seated upper/lower-body movement, slow and shuffling gait, mobility aids,
prostheses, tremor/involuntary motion, limited range, one-handed device use,
standing desk use, Watch on either wrist or absent, phone carried or left at the
desk, and movement outside camera framing. Each supported movement class earns
its own measurement dossier. Evidence for walking cannot be generalized to
wheeling or seated activity.

Non-detection, missing device, low-quality frame, or classifier disagreement is
always `Unknown`. It cannot preserve debt more aggressively, remove a manual
declaration, display a negative state, reduce acknowledgement, or change the
person's weekly representation.

### 7.4 Bystanders and protected context

- A second persistent face immediately suspends person-derived camera
  observations. The app does not identify, count historically, label, compare,
  or ask the primary person to dismiss the bystander.
- Protected apps, selected windows, Calendar, Focus, meetings, screen sharing,
  full-screen work, private notifications, and assistive-technology overlays
  never expose content in SI-02, VoiceOver, logs, screenshots, exports, or
  generated-model prompts.
- Camera, selected-window, and audio/device-use indicators are never hidden by a
  full-screen break. The Mac Dock/Settings path remains reachable if the menu
  bar is hidden.
- VoiceOver descriptions expose derived facts only. They do not read app names,
  event names, OCR text, faces, or sensitive source content aloud.
- A person can stop sensing before closing a screen, with no confirmation,
  explanation, pointer precision, timed gesture, or speech required.

### 7.5 Representative validation gate

Accessibility review for each capability retains the platform/OS/device,
assistive technology and version, input method, display/text/contrast/motion
settings, movement/body/setup condition when relevant, task, result, defect,
and participant interpretation. Synthetic fixtures and able-bodied internal
testing may find defects but cannot establish representative parity.

Automatic mode is blocked by any critical assistive-technology failure,
inferior manual consequence, hidden indicator/stop, material unmitigated error
gap, shame/medical interpretation, or unsupported movement generalization.
Suggest mode is blocked when correction is not independently operable. Shadow
may continue only when it collects no unconsented retained data and remains out
of the person's normal interruption path.
