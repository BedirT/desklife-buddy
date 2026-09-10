# Timing Model Research and Redesign

Status: product direction proposal, not canonical protocol

Date: 2026-08-31

## Why this exploration exists

The current implementation estimates active computer use from recent keyboard,
mouse, and scroll input. That is intentionally private, but it has two product
problems:

1. Passive screen use is invisible. Reading, reviewing a design, or watching a
   static presentation may stop the clock even though the person is still using
   the screen.
2. The presentation gate is not wired to a live low-friction signal. The App
   feeds `false` during normal sampling, while tests can inject `true`. A due
   break therefore tends to wait for the hard latest boundary rather than a
   real pause in activity.

There is also a reliability issue to resolve independently of the redesign:
`ProtocolEngine.resumeAfterSuppressionGrace()` exists, but no App caller was
found. A long idle or suppression can place clocks in
`gracedAfterSuppression` without a live path that ends the grace. That is a
plausible cause of automatic breaks failing to return after the user steps
away.

## What comparable apps do

These products do not solve passive reading from keyboard and mouse activity
alone. They choose a policy, add more context signals, or let the user choose.

| Product | Due-time model | Idle policy | Presentation policy |
| --- | --- | --- | --- |
| Time Out | Configurable interval | Continue, pause, count backwards, or reset after a natural break | Can wait for a short idle period after due, then starts within a bound |
| Stretchly | Fixed interval | Pauses after five minutes idle until return | Heads-up followed by break overlay |
| BreakTimer | Fixed interval | Smart restart based on when idle began | Subtle notice, then a delayed countdown before the break |
| LookAway | Focused-screen interval plus planned wall-clock breaks | Planned breaks can use away time; focused breaks have smart pause | Holds for meetings, video, games, screen sharing, and configured focus apps |
| Pausebar | Interval plus many local context signals | Waits while away | Holds while typing or in detected busy contexts, then presents at a natural pause |
| Repose | Fixed interval | Pauses after five minutes and resets on return | Holds for active camera or microphone use |
| Step Away | Work-session interval | Pauses while idle and resumes on return | Adds Focus, meeting, screen-sharing, and flow-state delays |
| Viraam | Configurable interval | Not clearly documented | Offers subtle, gentle, and immersive delivery; groups nearby reminders |

### Sources

- [Time Out schedule and natural-break policies](https://dejal.com/help/timeout/en/schedule.html)
- [Stretchly behavior and configuration](https://github.com/hovancik/stretchly)
- [BreakTimer product](https://breaktimer.app/)
- [BreakTimer releases](https://github.com/tom-james-watson/breaktimer-app/releases)
- [LookAway Smart Pause](https://lookaway.com/docs/high-engagement/)
- [LookAway Planned Breaks](https://lookaway.com/docs/planned-breaks/)
- [Pausebar product behavior](https://pausebar.app/)
- [Pausebar privacy and local signals](https://pausebar.app/privacy/)
- [Repose behavior](https://github.com/fikrikarim/repose)
- [Step Away App Store listing](https://apps.apple.com/us/app/step-away-break-reminder/id6754695723)
- [Viraam support](https://www.viraam.app/support)

## Research conclusion

The core mistake is treating one inferred clock as both:

- evidence that the person has been looking at the screen, and
- evidence that now is a good time to interrupt.

Those are different questions. The first cannot be answered reliably without
more invasive sensing. The second can be improved with small, ephemeral signals
and a firm maximum delay.

The product should explicitly separate:

1. **Due calculation:** when another opportunity should be offered.
2. **Presentation timing:** when the offer should appear without an ambush.
3. **Suppression:** when the app is forbidden from presenting anything.
4. **Completion evidence:** what the app may honestly say happened.

## Candidate models

### Model A: fixed elapsed schedule

The visual timer advances while the Mac is awake and the session is active,
regardless of input. Movement can remain active-use based.

Strengths:

- Reading and static screen use are covered.
- Easy to explain.
- Reliable and easy to test.

Weaknesses:

- Short away periods count as screen time.
- Requires explicit away handling to avoid reminders immediately after return.

### Model B: hybrid screen-session schedule

The visual timer advances while the screen session is available, regardless of
recent input. Input is used only to find a presentation seam. Movement remains
based on estimated active use. A sufficiently long idle clears the pending
visual presentation burden without recording a completed break, then starts a
short return grace.

Strengths:

- Covers passive reading.
- Preserves the existing privacy boundary.
- Uses uncertainty honestly.
- Keeps visual and movement semantics distinct.

Weaknesses:

- Still cannot know whether an idle person looked away.
- Needs careful copy and deterministic return behavior.

### Model C: context-aware focused-use schedule

Add camera, microphone, video playback, fullscreen, screen-sharing, Focus, and
application signals to infer busy contexts and passive use.

Strengths:

- Can avoid more bad interruptions.
- Can recognize some passive media sessions.

Weaknesses:

- Adds permission, privacy, compatibility, and maintenance costs.
- Signals remain probabilistic.
- Conflicts with the current promise that core behavior needs no invasive
  permissions.

## Recommended direction

Choose **Model B** as the core and keep Model C as optional future integration
work. Treat the visual clock as an estimate of eligible screen-session
exposure, not proof that the user is present, reading, or looking at the screen.

### 1. Visual clock

- Advance elapsed visual-session time whenever the display session is awake,
  active, unlocked, and has not crossed the long-idle cutoff.
- Do not require recent keyboard or pointer input.
- This means reading is treated as possible screen use, not inactivity.
- Copy must never narrow this estimate to "you have been looking at the screen."

### 2. Movement clock

- Continue using coarse estimated active use.
- Never infer standing, walking, posture, or completed movement from idle time.
- Keep movement independent from visual resets.

### 3. Away handling

- Short no-input periods remain ambiguous and do not stop the visual clock.
- After a configurable long-idle threshold, clear any pending visual
  presentation burden and restart visual timing on return after a short grace.
- Record only `likelyNaturalInterruption`, never `breakCompleted`.
- Do not reset the movement opportunity as if movement was completed.

### 4. Due and presentation timing

- At the target, mark the opportunity due.
- If the user has paused input briefly, present after the normal heads-up.
- If they are continuously typing or scrolling, wait for the first short pause.
- If no pause occurs, present by a firm latest boundary. A target-to-latest
  window around 60 to 120 seconds is a better starting point than five minutes.
- Reading naturally qualifies as a presentation seam because there is no active
  input, while the visual clock still advances.

Candidate low-friction signals that do not require content capture:

- a short input pause, such as 3 to 8 seconds
- an application switch
- exit from fullscreen or presentation mode, if available through a sanctioned
  public signal
- the end of an explicit app-owned pause or snooze
- the hard latest boundary

An application switch is a hint, not proof. It should release an already due
opportunity, not create or complete one.

### 5. Suppression

Suppression should be reserved for facts that clearly mean "do not show now":

- manual pause or snooze
- asleep, screen off, inactive user session, or unavailable system
- an explicitly excluded application
- an optional, user-enabled integration such as Focus

The current `workingHoursOnly` control should not remain user-visible until real
working hours exist and feed the suppression resolver.

### 6. User-facing explanation

Do not use "low-friction moment" in product copy. Suggested language:

- **Wait for a short pause**
- "When a break is due, wait until you briefly stop typing or scrolling. It
  will still appear within about a minute."

The menu-bar status should explain states rather than expose sensor language:

- `Visual reset in about 8 min`
- `Ready at your next pause`
- `Held while paused`
- `Restarting after time away`
- `Movement in about 42 min`

Advanced details can state:

> Visual timing follows your available screen session, so reading still counts.
> Movement timing uses a coarse estimate of active computer use. The app does
> not record keystrokes or determine whether you are looking at the screen.

## Product defaults

Recommended Balanced behavior for an initial prototype:

| Decision | Starting value |
| --- | --- |
| Visual target | 25 minutes of available screen session |
| Visual duration | 20 seconds |
| Heads-up | 30 to 45 seconds |
| Input pause that may release a due opportunity | 5 seconds |
| Maximum wait after target | 90 seconds |
| Long idle that clears pending visual presentation | 5 minutes |
| Grace after returning from long idle | 60 seconds |
| Movement target | 60 minutes of estimated active use |

These are prototype values, not health claims. They need real-use testing before
becoming canonical.

## Required implementation work after approval

1. Add separate visual-session elapsed time instead of feeding both clocks from
   one `ActivityEstimator.accumulatedSeconds` value.
2. Add a real low-friction reducer input derived from ephemeral input timing.
3. Make post-suppression grace time-bounded and self-resuming.
4. Remove or disable the false working-hours promise until it is implemented.
5. Persist enough monotonic state to survive sleep, wake, and app relaunch
   without treating wall-clock drift as activity.
6. Add deterministic tests for reading, continuous typing, short idle, long
   idle, sleep/wake, snooze, and relaunch.
7. Prove the actual automatic path in a short verification profile, not only a
   manually launched break.

## Claude Opus review status

Three review prompts were prepared for competitor synthesis, privacy-conscious
architecture, and product strategy using:

```sh
claude -p "<sanitized prompt>" --model opus --effort medium
```

The owner authenticated the installed CLI. Three sanitized discussions were
then run with `--model opus --effort medium`: competitor synthesis, runtime and
privacy architecture, and adversarial product strategy. The external reviewer
received only the abstract behavior problem and public URLs. Private repository
files were not sent.

The consolidated review is in [CLAUDE-OPUS-REVIEW.md](CLAUDE-OPUS-REVIEW.md).

The Apple-ecosystem extension is in
[APPLE-ECOSYSTEM-EXTENSION.md](APPLE-ECOSYSTEM-EXTENSION.md).

## Decision needed before implementation

Confirm whether the core visual timer should follow **available screen-session
time** rather than **recent-input-estimated active use**. This is the material
protocol change that fixes the passive-reading case while preserving the
no-invasive-permissions promise.
