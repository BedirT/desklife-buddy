# 006 - Motion production workflow

## Context

Animation quality is now a product-quality signal, but a token-only motion rule
does not let agents produce high-end movement by itself. Native SwiftUI covers
many advanced interaction cases on macOS: phase/keyframe choreography, matched
geometry continuity, symbol and content transitions, scroll effects, window
state polish, and Liquid Glass chrome when appropriate. It still cannot replace
authored visual material for mascots, illustrated scenes, Adobe After Effects
timelines, or pixel-perfect raster effects.

At the same time, shipping Rive, Lottie, or dotLottie in every template clone
would add dependency, binary, accessibility, CI, bundle-size, and review costs
before a real app needs them.

## Decision

The harness adopts a Motion Production System:

1. Native SwiftUI is the default runtime and composition layer for app motion.
2. Advanced motion starts with intent classification, not curve selection.
3. DSMotion remains the shared timing vocabulary for native SwiftUI animation.
4. Layered PDF/PNG assets and sprite sheets are supported without new package
   dependencies.
5. Rive is the optional lane for interactive authored state-machine motion.
6. Lottie/dotLottie is the optional lane for Adobe-authored passive timelines.
7. Optional runtime engines are app-specific decisions; the default harness
   ships templates, manifests, checks, and docs but no Rive/Lottie packages.
8. Every non-trivial motion asset has a manifest with playback, fallback,
   accessibility, provenance, and verification metadata.
9. Missing production assets should produce a precise motion brief plus a
   clearly marked placeholder, not vague human hand-holding.
10. Motion proof includes Preview endpoint evidence, reduced-motion behavior,
    video/frame review of the real macOS window, and perf evidence when motion
    is high-risk.

Final animation in SwiftUI means the app consumes the result as a SwiftUI view
or modifier driven by Swift model state. It does not mean every rendered pixel
must be drawn from SwiftUI shapes.

## Consequences

Agents can now build motion autonomously up to the point where real creative
production is required. The human loop is explicit: approve new runtime
dependencies, final art direction, production exports, licensing/provenance,
baseline re-recording, and final target-device feel.

The template stays light. Apps opt into Rive or Lottie only when a real screen
needs that lane, and one runtime engine is the default maximum unless a plan
justifies both. Asset manifests make binary or generated motion artifacts
reviewable even when the asset itself is not meaningfully diffable.
