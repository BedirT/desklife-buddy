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
   reconnect** and **Close**; terminal-action-pending exposes **Close** because a submitted action
   cannot be cancelled.
2. **Initial focus** — Live uses the exact phase/segment registry: Take with me when present,
   otherwise that row's first terminal control. Neutral offline/expired/transfer-failed focus Retry;
   offline-terminal-ack-unknown focuses Check status. Transfer-pending focuses Cancel transfer;
   both revalidating states focus Cancel reconnect; terminal-pending, rejected, and already-ended
   focus Close. No absent or disabled trigger receives focus. `Just the visual one` exists only in
   merged movement offered.
3. **Focus order** — exactly the enabled control IDs registered for that state. Status is read but
   not a fake focus stop. Unavailable phase-specific controls are absent, not disabled.
4. **Escape** — returns to the authoritative timer without applying a companion action.
5. **VoiceOver names** — semantic action names, never device appearance or sensor language.
6. **VoiceOver values** — exactly one registered announcement for live, neutral offline,
   offline-terminal-ack-unknown, expired, transfer-pending, terminal-action-pending, neutral
   revalidating, revalidating-terminal-ack-unknown, rejected-no-op, already-ended, or
   transfer-failed. Terminal pending names the selected action, never “Sending timer.” Unknown ACK
   states preserve and name that action: “Checking whether [action] was received. Do not repeat.”
   Check status/reconnect never resends it. Neutral states explicitly say no companion operation is
   pending. No silent no-op.
7. **Text scaling** — state and recovery copy wrap above a vertical action group.
8. **Increase Contrast** — labels, traits, focus rings, and boundaries distinguish every state.
9. **Reduce Motion** — immediate state replacement; no spinner or transfer animation required.
10. **Meaning without color** — each state has explicit text and enabled action labels; no pending
    or failure meaning depends on color or a disabled trigger.
11. **Alternative movement** — sensor-free manual controls remain on the authoritative device;
    Watch/iPhone ownership, motion, location, HealthKit, walking, and standing are not required.
12. **Multi-display** — the Mac key panel remains reachable until acknowledged handoff; failure
    returns focus without stranding a panel.

### ED-19 — Timer recovery unavailable

1. **Keyboard path** — Close works with Return, Escape, and Command-period; Retry is shown only
   when a failed fence/storage transaction can be attempted again.
2. **Initial focus** — Close, or Retry when it is the only recovery action.
3. **Focus order** — recovery status → Retry when present → Close.
4. **Escape** — closes the unusable ritual without recording skip, completion, or timer finish.
5. **VoiceOver names** — due: “Timer could not be restored. No finish was recorded. The schedule
   is still due.” Not due/manual early: “Timer could not be restored. No finish was recorded. This
   schedule was not reset.” The retained phase selects the string before Close receives focus.
6. **VoiceOver values** — active due says “Still due · timer not restored.” Paused always says
   “Paused: [selected reason] · timer not restored,” and Held always says “Held: [fresh,
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
