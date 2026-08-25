# Rule: Accessibility

Accessibility is a design input, not a QA pass. A screen without its accessibility
annotation is unfinished. Authority: `research/health/05_DESIGNER_AGENT_BRIEF.md` §7,
`research/health/04_BREAK_AND_MOVEMENT_CONTENT_LIBRARY.md` §11, `[S045, S046, S080]`.

## 1. Required annotation block

Every screen and every non-trivial state in `design/SCREEN_INVENTORY.md` carries:

```
Keyboard path        — how it is reached and operated with no pointer
Initial focus        — what is focused on appearance, and why
Focus order          — the full tab ring, in order
Escape               — what Escape does (it must always do something sensible)
VoiceOver names      — the accessibility label of every control
VoiceOver values     — timer/state announcements, and their politeness level
Text scaling         — behavior at largest supported size, no clipping/truncation
High contrast        — Increase Contrast appearance changes
Reduced motion       — the static equivalent of every animation
Meaning w/o color    — how each state reads in grayscale
Alternative movement — the equal-status seated/limited-mobility path
Multi-display        — where controls land with 1, 2, mirrored, and disconnected displays
```

## 2. Hard requirements

- **Escape always works.** Every overlay, sheet, popover, and panel. No exceptions, no
  confirmation step, no "hold to dismiss".
- **No keyboard trap.** VoiceOver focus must never be captured by the break overlay.
- **Every control is reachable by keyboard**, in a predictable order, with a visible focus
  ring that meets contrast requirements in both appearances.
- **Visible keyboard affordances on the break overlay** — the primary actions show their
  shortcuts, because the user is being interrupted mid-task.
- **No drag-only operation.** Anything draggable has a keyboard and click equivalent.
- **Sound is never required** for meaning, timing, or completion.
- **Text scales** without clipping, truncation, overlap, or a horizontal scrollbar.
- **No color-only meaning.** Every state also carries a label, shape, weight, or position
  difference. Check every screen in grayscale.
- **Contrast**: body text ≥ 4.5:1, large text and meaningful non-text ≥ 3:1, in light, dark,
  and Increase Contrast, and over any translucent material at its worst-case backdrop.

## 3. Motion and photosensitivity

Honor Reduce Motion automatically; also expose an in-app static mode.

Never build: pulsing countdowns · flashing · shimmer · rapid zoom · bouncing · confetti ·
continuous parallax · animated backgrounds that run for the whole break.

Permitted motion is short, single-shot, easing-based, and purposeful — an appearance
transition, a progress change, a state crossfade. Anything animated must have a static
equivalent that carries the same information, and the design must state what it is.

Migraine-friendly presentation is a first-class mode: static background, low visual density,
no pulse, brightness under user control, immediate dismissal `[04 §11]`. Never claim it
prevents or treats migraine.

## 4. Movement parity

This is a product-defining requirement, not a courtesy.

- Seated, wheeling, and limited-mobility options appear at the **same visual weight, same
  type size, same position tier** as walking. Not below a divider. Not behind "More".
- Never word an alternative as lesser: no "if you can't walk", no "alternative", no
  "fallback". Frame as choice: "Move in a way that works for you" `[C047]`.
- Never equate wellness with standing or step count `[C048]`.
- Every movement card in the UI shows its seated/low-balance option in the same view.
- A user who selects a seated path must never see a different completion status, a different
  color, or a smaller acknowledgement than a user who walked.

## 5. VoiceOver specifics

- The break overlay announces itself once, calmly, with the instruction — not with a
  decorative title.
- Timers announce on a coarse cadence (not every second) and use a polite live region.
  A per-second announcement is an accessibility defect.
- Every state change that matters (snoozed, paused, suppressed, break started) is announced.
- Names describe purpose, not appearance: "Start five-minute movement", not "Big button".
- Values carry state: a paused menu-bar item reads its reason, not just "paused".

## 6. Permissions and accessibility

Notifications may be denied. Design the heads-up so a denied notification permission degrades
to an in-app affordance, never to a broken flow, and never to a nag.

## 7. Review

Run `.claude/skills/accessibility-review/` before calling any screen done. The
Accessibility Auditor subagent reviews from multiple access-need perspectives: keyboard-only,
VoiceOver, low vision, wheelchair user, migraine/photosensitive, and cognitive load under
interruption.
