---
name: accessibility-review
description: Systematic accessibility audit of a Cadence screen, state, or flow. Use before calling any screen done, when adding a new interaction, and before handoff. Checks keyboard operation, focus order and Escape, VoiceOver names/values/announcements, contrast, text scaling, reduced motion, meaning without color, equal-status movement alternatives, and multi-display reachability.
---

# Accessibility review

Accessibility here is a product requirement with a research basis `[S045, S046, S080]`, and
movement parity is a defining product claim `[C047, C048]`. Audit accordingly.

Sources: `.claude/rules/accessibility.md`, `design/ACCESSIBILITY.md`,
`research/health/05_DESIGNER_AGENT_BRIEF.md` §7, `research/health/04_…CONTENT_LIBRARY.md` §11.

## Procedure

### 1. Keyboard only
Put the pointer away. Can the screen be reached, understood, operated, and dismissed?
- Is initial focus sensible and stated?
- Walk the full tab ring. Write it down. Is the order the reading order?
- Is the focus ring visible in light, dark, and Increase Contrast?
- **Does Escape work?** Immediately, with no confirmation.
- Is any action pointer-only, hover-only, or drag-only?
- Are shortcuts visible where the user is interrupted (break surfaces)?

### 2. VoiceOver
- Every control has a purpose-describing name, not an appearance-describing one.
- The surface announces itself once, calmly, with the instruction.
- Timer announcements use a coarse cadence and a polite live region — **per-second
  announcements are a defect**.
- State changes (paused, snoozed, suppressed, started, ended) are announced.
- No focus trap. Focus returns somewhere sensible on dismiss.
- Reading order matches visual order.

### 3. Low vision
- Body text ≥ 4.5:1; large text and meaningful non-text ≥ 3:1. Check over translucent
  materials at worst-case backdrop.
- Increase Contrast appearance defined.
- Reduce Transparency appearance defined and legible without the blur.
- Text at largest supported size: no clipping, truncation, overlap, or horizontal scroll.

### 4. Color independence
View in grayscale. Does every state still read? Each state needs a second cue — label, shape,
weight, or position.

### 5. Motion and photosensitivity
- List every animation. For each: duration, trigger, and its Reduce Motion equivalent.
- Nothing pulses, flashes, shimmers, zooms rapidly, bounces, parallaxes, or loops.
- Static mode carries the same information.
- No animation the user must wait out.

### 6. Movement parity (product-critical)
- Is a seated / wheeling / limited-mobility option present **in the same view**?
- Is it at the same visual weight, type size, and position tier as walking?
- Is it worded as a choice, never as "if you can't…" or "alternative" or "fallback"?
- Does choosing it produce an identical completion experience?
- Does anything equate wellness with standing or steps?

### 7. Cognitive load under interruption
The user is mid-task and did not ask for this screen.
- How many words must be read to act? (Target: very few.)
- How many decisions are demanded? (Target: zero or one.)
- Is the exit obvious without reading?

### 8. Multi-display and system context
- Controls reachable with 1 display, 2 displays, mirrored, and after a disconnect.
- Behavior when the menu bar is hidden by a full-screen app.
- Behavior across Spaces and Stage Manager.

### 9. Permission degradation
Notifications denied, Calendar denied or revoked: the flow degrades to something usable and
non-nagging, never to something broken.

## Output

```
## Accessibility review — <screen> (<state>)

### Blockers
### Defects
### Notes
### Annotation completeness
| Field | Present | Note |
(keyboard path, initial focus, focus order, Escape, VO names, VO values,
 text scaling, high contrast, reduced motion, meaning w/o color,
 alternative movement, multi-display)

Verdict: pass / fix required
```

A screen with an incomplete annotation block fails, regardless of how it looks.
