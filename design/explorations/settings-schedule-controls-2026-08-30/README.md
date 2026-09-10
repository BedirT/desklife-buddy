# Schedule controls and scroll edges

Non-canonical visual exploration grounded in the real compact Schedule window
captured at `artifacts/settings-sidebar-concentric.png`.

## Brief

### Keep

- D-033 solid two-tone Settings shell.
- D-034 rhythm comparison and continuous Timing and Delivery form.
- Fixed sidebar and fixed Schedule title.
- Existing localized copy, behavior, accessibility, and native keyboard model.

### Change

- Give Delivery toggles a more deliberate visual treatment.
- Replace the sharp top and bottom scroll clipping with a short tonal opacity
  fade into the content-well surface.
- Preserve a quiet native macOS density and one aligned trailing control rail.

### Remove

- Hard-looking scroll viewport edges.
- Toggle placement that feels incidental rather than aligned.
- Any unnecessary glass, shadow stripe, extra card, or dashboard treatment.

## Directions

### A: Refined native switches

`direction-a-native-switches.png`

Compact Apple-like switches remain the only state indicator. A short tonal fade
softens the top and bottom scroll edges. This is the quietest, most native, and
least explanatory direction. Generated row content is illustrative only and
does not change the accepted Timing behavior.

### B: Labeled two-state pill

`direction-b-labeled-pill.png`

Each Delivery row ends in a compact Off and On selector. State is explicit
without relying on track position or color, but the control is visually heavier
and less conventionally macOS than a switch. The generated split-card form is
illustrative only; production would retain D-034's single continuous form.

### C: State label plus switch

`direction-c-state-plus-switch.png`

A small On or Off label precedes the native switch in one trailing rail. It is
more explicit than A while remaining recognizably native, but repeats state that
VoiceOver and the switch already communicate.

## Shared scroll treatment

All directions use a solid-surface opacity mask rather than blur or glass.
Scrolling content should progressively lose opacity for roughly 32 to 40 points
beneath the fixed title and above the bottom edge. The fade must disappear when
there is no obscured content at that edge, preserve Increase Contrast clarity,
and reduce to a clean semantic boundary under Reduce Transparency.

These images are concept evidence only. Native controls, exact geometry,
localized text, focus, and accessibility remain implementation requirements.
