# Claude Opus Medium Review

Status: completed external critique of the abstract timing proposal

The discussions used `claude -p` with `--model opus --effort medium`. They were
sanitized product discussions. Claude did not receive private repository files
or source code.

## Review scopes

1. Competitor behavior and the permission cost of context-aware timing.
2. Runtime architecture, state exits, monotonic time, and failure direction.
3. Product strategy for passive reading and the meaning of a natural pause.

## Consensus

All three reviews supported the same foundation:

- Separate due calculation from presentation timing.
- Use different accrual semantics for visual resets and movement.
- Keep input as an ephemeral presentation-seam signal rather than proof of
  gaze, attention, reading, or presence.
- Clear a pending visual presentation after long idle without recording a
  completed break.
- Add a return grace so the app does not greet a returning user with an
  immediate overlay.
- Keep a firm latest boundary so continuous typing cannot defer a reminder
  forever.
- Keep richer camera, microphone, Accessibility, Input Monitoring, and Screen
  Recording signals outside the permission-free core.

## Strongest correction to the proposal

"Awake and unlocked" is not the same as "the user is present." The redesigned
visual clock exchanges the current undercount of passive reading for a bounded
overcount when someone walks away without locking the Mac.

The honest interpretation is:

> The visual clock estimates eligible screen-session exposure until a long-idle
> cutoff. It does not know whether the user is looking at the display.

The long-idle cutoff bounds the error. It does not eliminate it. Product copy
must not say the app detected reading, gaze, presence, strain, or a completed
break.

## Competitor conclusions

Verified public behavior clustered into three patterns:

1. Fixed or interval clocks with an idle correction, such as Time Out,
   Stretchly, and Repose.
2. Due reminders held for a short pause, with return grace or a latest boundary,
   such as Time Out, LookAway, and Pausebar.
3. Rich busy-context suppression bought with more signals or permissions, such
   as camera, microphone, fullscreen, video, screen sharing, Focus, calendar,
   or app identity.

No reviewed competitor demonstrated a reliable, permission-free way to
distinguish passive reading from walking away. The app must choose and disclose
which error it prefers.

## Recommended core state model

Two independent due engines feed one presentation controller.

### Visual due engine

- Accrues while the screen session is eligible and has not crossed long idle.
- Continues through short input gaps so passive reading is not immediately
  discarded.
- Stops after long idle.
- Clears a pending visual presentation after long idle without positive credit.

### Movement due engine

- Accrues only during coarse estimated active computer use.
- Does not infer movement, standing, posture, or completion from idle.
- Remains independent from visual-reset completion.

### Presentation controller

```text
idle
  -> pending at target
  -> heads-up at a short input pause
  -> heads-up at the firm latest boundary if no pause occurs
  -> deferred only for a real suppression
  -> cleared after long idle, with no completion event
  -> return grace
  -> idle
```

Every enterable suppression or grace state must have a tested, time-bounded
exit. A state that can be entered but not left is a runtime failure, not a calm
delay.

## Architecture cautions

### Signal truthfulness

- Documented `NSWorkspace` sleep, wake, screen sleep, session active, and
  session inactive notifications are useful eligibility inputs.
- Lock state is not backed by a fully documented, permission-free public API.
  Unknown lock state needs a defined failure direction.
- Any app-switch signal is only a presentation hint. It proves neither a task
  boundary nor a good health moment.

### Timekeeping

- Measure elapsed intervals with a monotonic clock.
- Do not add an unbounded delta after sleep, App Nap, timer coalescing, or a
  stalled process.
- Treat a sample gap beyond tolerance as ineligible time and re-anchor.
- Persist accumulated values and stable states, not a monotonic timestamp that
  is expected to survive reboot.
- Every restored state must have a deterministic exit.

### Current runtime gaps confirmed from the sanitized summary

- Passing `lowFriction = false` during every live sample makes the intended
  seam-release path dead outside tests.
- A `gracedAfterSuppression` state with no live exit caller can become sticky.
- A visible `workingHoursOnly` preference without a working-hours provider is a
  false capability promise.

These must be wired or removed before the redesigned behavior can be called
reliable.

## Product language

Preferred mental model:

> Visual resets follow an estimate of your available screen session. Movement
> follows an estimate of active computer use. When a reminder is due, the app
> waits briefly for you to stop typing or scrolling, but never waits long.

Suggested status language:

- `Visual reset in about 12 min`
- `Movement in about 34 min`
- `Ready at your next pause`
- `Paused while you are away`
- `Restarting after time away`

Avoid:

- `You have been reading`
- `You have been looking at the screen`
- `Break completed` after idle
- `Movement verified`
- `Low-friction moment`

## Disagreements and owner decisions

The reviews agreed on the model but not every default.

1. **Latest boundary:** recommendations ranged from 60 to 120 seconds after the
   target. Prototype at 90 seconds.
2. **Long-idle cutoff:** five minutes matches several competitors, but can still
   misclassify a slow reader. Test five minutes first and keep it a documented
   heuristic.
3. **Return behavior:** restarting visual timing after long idle is calmer and
   avoids an immediate reminder. Resuming preserves more accumulated exposure.
   The current proposal recommends restart plus a 60-second grace.
4. **Unknown lock state:** fail closed for presentation. Whether visual accrual
   also fails closed requires testing because it may cause systematic
   undercounting on systems where lock state is unavailable.
5. **Movement after long idle:** never claim movement. Whether to retain or
   clear the pending movement opportunity remains a product decision; the
   existing protocol says idle does not complete movement.

## What not to build

- No reading detector.
- No gaze or attention language.
- No indefinitely deferred reminder.
- No primary three-way timing policy that asks ordinary users to understand the
  sensing ambiguity.
- No permission expansion merely to imitate competitors.
- No health score derived from ambiguous idle behavior.
