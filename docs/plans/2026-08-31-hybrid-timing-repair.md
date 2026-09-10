# Hybrid timing repair - plan

Status: complete with retained environment limitations
Intake/escalation status: clear

## Outcome

The Mac app automatically offers visual resets during passive screen use as
well as hands-on use, keeps movement timing tied to estimated active computer
use, waits briefly for a real input pause without waiting indefinitely, and
recovers deterministically after idle, sleep, suppression, and relaunch. The
real app proves an automatic break from sampled activity through heads-up and
overlay completion without using a manual-start route.

## Non-goals

- No iPhone, watchOS, HealthKit, AirPods, CloudKit, or Handoff target in this
  plan. Those follow only after the Mac timing foundation is proven.
- No camera, microphone, Screen Recording, Accessibility, Input Monitoring, or
  private API.
- No claim that awake screen time proves gaze, reading, presence, strain, or a
  completed break.
- No redesign of settings, break art, overlay appearance, or movement content.
- No CI or GitHub workflow changes.

## Open escalations - clear before step 1

- None. The owner approved the hybrid screen-session model and the staged Apple
  ecosystem direction on 2026-08-31. The permission-free Mac core remains
  complete and authoritative.

## Steps

- [x] 1. Canonical product contract: update the protocol, decisions, interaction
      semantics, privacy language, and owner preferences for separate visual
      screen-session and movement active-use timing - done = protocol generator
      check plus `scripts/lint.sh` green.
- [x] 2. Domain red tests: add deterministic reproductions for passive reading,
      short idle, long idle, continuous typing, short-pause release, firm latest
      release, and self-ending return grace; observe failures before production
      edits - done = named tests fail for the intended missing behavior.
- [x] 3. Domain implementation: separate visual and movement accrual inputs,
      preserve honest event semantics, and make every grace/suppression state
      exit deterministically - done = `scripts/test.sh Domain` green; gating
      suites: `ActivityEstimatorTests`, `ProtocolEngineTests`,
      `ProtocolEngineInvariantTests`, `ProtocolEngineRecoveryTests`, and
      heads-up delivery tests.
- [x] 4. App wiring: derive an ephemeral short-input-pause signal, feed separate
      visual/movement eligibility, persist restart-safe state, remove or hide the
      unenforced working-hours capability, and add App seam tests - done =
      `scripts/test.sh App` green.
- [x] 5. Real automatic flow: add a short verification profile that uses the
      normal sampler and scheduler, then prove heads-up, automatic overlay,
      keyboard exit, timer start, idle recovery, and no manual-start shortcut -
      done = `scripts/build.sh`, `scripts/run.sh --verify`, `scripts/ui.sh`, and
      focused `scripts/shot.sh` evidence.
- [x] 6. Closeout: run retained verification, inspect evidence, update canonical
      open questions and this plan, then assemble the evidence pack - done =
      `scripts/lint.sh` green and every product suite green. Retained exceptions
      are documented below rather than hidden or worked around.

## Decision log

- 2026-08-31: Visual timing will estimate eligible screen-session exposure while
  the display session is available and before long idle. It will not require
  recent input. Copy must not claim gaze, reading, presence, or strain.
- 2026-08-31: Movement timing remains estimated active computer use based on
  coarse recent input. Idle never verifies movement or completion.
- 2026-08-31: A due opportunity may release after about five seconds without
  typing, pointer, or scroll input. A firm latest boundary remains independent
  of that seam so continuous input cannot defer forever.
- 2026-08-31: Prototype values are a 90-second target-to-latest presentation
  window, five-minute long-idle cutoff, and 60-second return grace. Canonical
  profile target values remain research-authored until the protocol step updates
  them explicitly.
- 2026-08-31: Long idle clears pending visual presentation burden without
  recording completion. It does not complete or reset movement as if movement
  was observed.
- 2026-08-31: The Apple ecosystem direction is Mac authority plus explicit
  movement continuation to iPhone, Dynamic Island, and Apple Watch. Companion
  implementation starts in a separate plan only after this plan is complete.
- 2026-08-31: Opportunity accrual excludes system sleep, while an already-open
  break keeps a continuous elapsed deadline. Wake reconciles an expired break
  instead of resuming stale remaining time. Timer expiry never verifies that
  movement occurred.

## Closeout evidence

- `scripts/test.sh Domain`: 136 tests in 16 suites passed.
- `scripts/test.sh Features`: 215 tests in 33 suites passed, including delayed
  refresh after a simulated 20-minute system suspension for both visual and
  movement breaks.
- The complete App suite passed every timing, delivery, overlay, keyboard,
  persistence, and status-menu test. Two legacy migration seeders remain blocked
  because an App Sandbox test process cannot invoke `xcrun`.
- `HeadsUpLifecycleCoordinatorTests` passed three consecutive focused runs after
  its test drain was made stable across acknowledgement-enqueued mutations.
- `scripts/run.sh --verify` launched the ordinary menu-bar app and `scripts/ui.sh`
  found its status item in the real accessibility tree.
- The ordinary persisted due state opened a real merged overlay after repairing
  Debug runtime UUID generation. The retained automatic action recovered
  without deleting user data, and new `breakStarted` events used unique IDs.
- Focused App overlay tests passed for standalone visual, standalone movement,
  and merged sequencing with continuous elapsed break clocks.
- Automatic verification traces retained under the app container show a real
  sampled session entering heads-up, opening the visual overlay, hiding the
  Dock, accepting Escape, persisting Skip, closing the overlay, and restoring
  the Dock without a manual-start route.
- Current Schedule states rendered at wide, compact, light, dark, and largest
  text sizes and were inspected under `artifacts/preview-review/Features/`.
  Baselines were not rewritten because the worktree contains a broader
  owner-directed Settings redesign whose 58 visual diffs are not accepted by
  this timing plan.
- `scripts/lint.sh` passed. `scripts/verify.sh` reaches the App suite and then
  stops only on the two sandbox-blocked legacy migration fixtures above.
