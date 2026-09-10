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

> **2026-08-25 reconciliation note.** The blocks below predate the Horizon round-2 design;
> the **current, per-screen blocks are `SCREEN_INVENTORY.md` §K**, which govern where the two
> disagree. Known deltas: (a) BR-01's "offered" state is superseded by the self-running
> surface (D-021) — "initial focus = the primary action" now resolves to **Done early**, the
> least destructive declaration, which honors this block's reasoning; (b) the `⌥⌘V` global
> shortcut is dropped — **no default global hotkeys** ship (D-029; it also shadowed Finder's
> move-paste); (c) BR-05's "Start 5 minutes" initial focus no longer exists (self-running);
> (d) BR-05's rule that the four options are VoiceOver **siblings with parallel names is
> kept** — round 2 places "Change position" at a tertiary *visual* tier (D-024), but its
> semantic rank, hit target (44px), and printed key (`P`) stay equal (D-027). The visual-tier
> vs sibling-tree tension was reviewed and resolved in that direction, not silently;
> (e) "Increase Contrast: dimming layer becomes opaque" predates D-026 — the default surface
> is already a full opaque field; IC instead raises ink tiers, borders, and the horizon track
> (D-028).

The three below are the load-bearing ones. Design directions should be evaluated against these
before anything else.

### BR-01/02 — Visual reset

1. **Keyboard path** — appears unprompted; also MB-09. *(A proposed `⌥⌘V` global shortcut
   was removed — D-029.)*
2. **Initial focus** — the primary action. Not the exit: focusing the exit first implies the
   product expects to be dismissed.
3. **Focus order** — primary action → skip → (optional "why this?") → exit.
4. **Escape** — dismisses immediately, records `skipped`, no confirmation, no re-prompt for
   this opportunity (`D-009`).
5. **VoiceOver names** — surface announces once: purpose, duration, actions available.
6. **VoiceOver values** — the timer is announced at **start** and at **completion** only.
   Optionally once near the end for the blink cue. Never per second (A6).
7. **Text scaling** — the instruction line reflows; it never truncates and never scrolls. If
   it cannot fit at the largest size, the layout is wrong, not the copy.
8. **Increase Contrast** — dimming layer becomes opaque enough for AA text contrast; the
   surface gains a defined edge.
9. **Reduce Motion** — no fade of the content, no moving focal element. Dimming still
   transitions, but as a slow opacity change only (A5). Static mode replaces any animated
   focal cue with text.
10. **Meaning without color** — the state is carried by the copy and the timer, never by hue.
11. **Alternative movement** — n/a (visual). But `[V04]` "eyes closed" must be reachable for
    users for whom looking into the distance is not practical `[04 §4]`.
12. **Multi-display** — see DQ-03. Content appears once; the dimming is consistent everywhere.

### BR-05/06 — Movement offer and activity choice

1. **Keyboard path** — MB-10, HU-02, or the break surface.
2. **Initial focus** — "Start 5 minutes."
3. **Focus order** — 5 min → 2 min → choose activity → I already moved → not now → exit.
4. **Escape** — dismisses, records `skipped`.
5. **VoiceOver names** — the four activity options must be siblings in the same group with
   parallel names ("Walk or wheel", "Seated movement", "Small space", "Change position") —
   **not** "Walk" plus "Accessibility alternatives" (A2). The VoiceOver tree is where unequal
   status becomes undeniable.
6. **VoiceOver values** — remaining time announced at start, at the halfway point at most, and
   at completion.
7. **Text scaling** — four options stack vertically; they never become a horizontal scroller.
8. **Increase Contrast** — option boundaries become explicit.
9. **Reduce Motion** — no animated demonstrations. Instructions are text `[04 §2]`.
10. **Meaning without color** — the selected activity is indicated by more than a tint.
11. **Alternative movement** — this screen *is* the commitment. Seated and small-space options
    carry the same type size, same target size, same position class as walking.
12. **Multi-display** — as BR-01.

### MB-01…MB-05 — Menu bar glyph

1. **Keyboard path** — reachable via the system menu bar keyboard shortcut (`⌃F2` /
   Keyboard Navigation), plus a global shortcut to open the menu directly.
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
