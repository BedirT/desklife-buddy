# Motion Production

This folder is the harness contract for advanced animation. It lets an agent
move from "make this feel premium" to a concrete SwiftUI implementation, an
asset request when needed, and evidence the owner can review.

## The rule

Final motion is always consumed by the app as SwiftUI: a `View`, modifier, or
composition driven by Swift model state, with Previews, accessibility,
reduced-motion behavior, and evidence. The pixels can come from SwiftUI, PDF,
PNG, sprite frames, Rive, Lottie, or dotLottie when the selected lane justifies
it.

The default harness links no Rive/Lottie runtime. A real app can opt into one
runtime after owner approval and a documented product need.

## Lanes

| Lane | Use when | Default status |
|---|---|---|
| Native SwiftUI | Controls, transitions, keyframes, phases, symbols, values, scroll polish, window/split-view continuity, Liquid Glass chrome | Built in |
| Layered PDF/PNG | Custom illustration can be split into independently animated parts | Built in |
| Sprite sheet | Short raster burst or generated effect that cannot be vectorized | Built in, budgeted |
| Rive | Interactive character, mascot, or control with state-machine inputs | Optional runtime |
| Lottie/dotLottie | Adobe After Effects timeline, success/empty-state clip, loader | Optional runtime |
| Canvas/Metal | Particles, distortion, procedural visual effect | Perf-gated |

## Agent workflow

1. Classify the intent before coding:
   - `interactionFeedback`
   - `stateContinuity`
   - `choreographedMoment`
   - `illustratedObject`
   - `designerTimeline`
   - `realtimeInteractiveCharacter`
   - `proceduralVisual`
   - `ambientMedia`
2. Pick the cheapest lane that can produce the right result.
3. If production art is missing, create a motion brief from
   `templates/motion-brief.md` and continue with a clearly marked placeholder.
4. Add or update a `.motion.json` manifest for every non-trivial asset.
5. Wire the final surface through SwiftUI; app/domain logic stays in Swift.
6. Add start/end/trigger/reduced-motion Preview states.
7. Run the evidence ladder:
   - endpoint snapshots/contact sheet for UI state,
   - `scripts/motion-review.sh` for real-window movement,
   - `scripts/perf.sh` for jank risk,
   - `scripts/check-motion-assets.sh` for asset metadata/provenance.

## Human loop

Ask the owner for:

- adding Rive, Lottie, dotLottie, or any other runtime dependency,
- brand-defining art direction,
- final Adobe/Rive/AI production exports,
- licensing/provenance decisions,
- animation that changes product meaning,
- bulk snapshot baseline re-recording (not exact bytes from a colored review),
- final feel on target Mac hardware.

Do not ask for:

- file placement,
- manifest shape,
- placeholder creation,
- wrapper API internals,
- choosing a lane when the intent is obvious,
- running the verification scripts.

## Manifest

Use `templates/motion-asset.motion.json` as the starting point. The manifest is
the reviewable contract around an asset that may otherwise be a binary file or
generated artifact.

Required concepts:

- identity: stable `id`, `kind`, and `intent`,
- files: runtime export, fallback static poster, editable source if available,
- playback: duration, fps, loop/autoplay, markers, speed,
- interactivity: artboard/state-machine/input names for Rive-like assets,
- layout: intrinsic size, safe bounds, light/dark variants,
- accessibility: decorative vs meaningful, labels, reduced-motion substitute,
- provenance: creator, tool chain, license, source URL, AI model/prompt hash,
- verification: preview states, perf budget, tested runtime.

## Runtime policy

The default app should use no third-party animation runtime. If an app needs
one, add a `docs/motion/runtime-approvals/<engine>.approval.md` file from
`runtime-approval-template.md` and choose exactly one by default:

- choose Rive for interactive authored state machines,
- choose Lottie/dotLottie for passive Adobe-authored timelines.

Using both runtimes requires a feature plan that names the screens needing each
engine and the evidence that justifies the extra complexity.
