---
name: motion
description: Animation and movement work - native SwiftUI choreography, asset-backed motion, Rive/Lottie handoff, reduced-motion behavior, and macOS video/perf proof.
---

# Motion Production

Build premium macOS motion without making the owner
manage implementation details. Escalation is limited to dependencies, unclear
asset rights, changed product meaning, baseline action, or contradictory intent.

Read first:
- `docs/motion/README.md`
- `docs/decisions/006-motion-production-workflow.md`
- `docs/apis/liquid-glass.md` when the motion touches glass/chrome

## Core rule

Final motion must be consumed by the app as SwiftUI: a `View`, modifier, or
composition driven by Swift model state, with Previews, accessibility,
reduced-motion behavior, and evidence. The rendered pixels may come from
SwiftUI, layered PDF/PNG, sprite frames, Rive, Lottie, or dotLottie when the
lane justifies it.

Do not add Rive, Lottie, dotLottie, or another runtime dependency by default.
Optional runtimes are app-specific owner decisions.

## Classify before coding

Pick one intent, then choose the cheapest lane that can produce the result:

| Intent | Default lane |
|---|---|
| `interactionFeedback` - taps, toggles, selection | Native SwiftUI recipe |
| `stateContinuity` - sidebar/detail, window, source/destination | `matchedGeometryEffect`, layout transition, or native split/window continuity |
| `choreographedMoment` - success, celebration, onboarding beat | SwiftUI phases/keyframes, or authored asset |
| `illustratedObject` - mascot, scene, floating parts | Layered PDF/PNG or Rive |
| `designerTimeline` - AE-authored clip, loader, empty state | Lottie/dotLottie |
| `realtimeInteractiveCharacter` - state machine, inputs, events | Rive |
| `proceduralVisual` - particles, shader, distortion | Canvas/Metal, perf-gated |
| `ambientMedia` - non-interactive video/loop | Rare; only when the accepted experience contract justifies it |

## Native SwiftUI lane

Use native SwiftUI for app interaction whenever it is expressive enough:
- `withAnimation(DSMotion.x)` / `.animation(DSMotion.x, value:)` for ordinary
  transitions.
- `PhaseAnimator` for short phase chains and attention moments.
- `KeyframeAnimator` / `KeyframeTimeline` for deterministic multi-track clips.
- `matchedGeometryEffect` for continuity.
- `symbolEffect` and `contentTransition` for system-owned microinteractions.
- `scrollTransition` / `visualEffect` for scroll-position effects.
- Liquid Glass APIs only for custom floating chrome, not content cards.

Inline curves still drift. Existing `DSMotion` tokens remain the shared timing
vocabulary; new tokens or a changed feel are design decisions.

## Asset-backed lanes

When the visual quality depends on authored material:

1. Create or update a `.motion.json` manifest from
   `docs/motion/templates/motion-asset.motion.json`.
2. If production art is missing, create a brief from
   `docs/motion/templates/motion-brief.md`.
3. Continue with a clearly marked placeholder when layout/product meaning is
   not blocked.
4. Integrate the asset through SwiftUI. The animation file renders state; it
   does not own product logic.

Lane rules:
- Layered PDF/PNG is the default for separable illustrations.
- Sprite sheets are allowed for short raster bursts; budget size and decoded
  pixels.
- Rive is for interactive authored state machines.
- Lottie/dotLottie is for Adobe-authored passive timelines.
- Prefer one optional runtime per app. Using both needs a feature plan and
  evidence.
- No remote motion assets in the default harness.
- Avoid embedded text in animation files; app copy stays localized in Swift.

## Escalation boundary

Ask the owner for:
- new runtime dependencies,
- unclear licensing/provenance or final-art rights,
- motion that would change accepted product meaning,
- bulk baseline re-recording (exact bytes from a colored review are agent-owned),
- a contradiction the accepted experience contract cannot resolve.

Do not ask for:
- lane choice when intent is clear,
- reversible timing, choreography, or feel variants,
- placeholders,
- manifest/brief structure,
- wrapper internals,
- verification commands.

## Reduced motion

Every advanced motion needs a reduced-motion behavior. Do not simply remove all
meaningful motion; replace context-carrying movement with safer cues such as
dissolve, highlight fade, color shift, or a static poster.

Red flags that need a fallback: depth/parallax, zoom/scale as the main effect,
spinning/vortex, animated blur/depth of field, multi-axis/multi-speed movement,
peripheral motion, auto-advancing carousels, and ongoing loops.

## Verification

Use the cheapest sufficient proof:
1. Endpoint proof: Preview states and `scripts/snapshot.sh <Package> [filter]`.
2. Movement proof: exercise the real app and inspect a focused local screen
   recording when endpoint snapshots cannot show the behavior.
3. Asset proof: `scripts/check-motion-assets.sh` for manifests, fallbacks,
   provenance, size, and remote-asset rejection.
4. High-risk/jank proof: reproduce the exact action in Instruments and record
   before/after measurements.
5. Accessibility proof: reduced-motion Preview plus a11y identifiers for the
   real trigger/target when it is a user flow.

Never claim "feels good" as agent proof. Report correctness, continuity,
fallbacks, independent visual judgment, and measured cost; the owner accepts or
rejects the final direction through the PR.
