---
name: perf-audit
description: Performance investigation — hangs, hitches, slow scrolling, animation jank, CPU spikes, memory growth. Records an Instruments trace via xctrace and reads it as structured data. Use when anything feels slow or the user reports jank.
---

# Performance audit

Find a named cause with numbers, not "seems faster".

## Loop
1. Reproduce first: `scripts/run.sh`, drive the slow flow, note the exact
   gesture and screen. No repro → no audit; say so.
2. Record while reproducing:
   `PERF_REPRO="swipe the review card left twice" scripts/perf.sh review-swipe 8 "Animation Hitches"`.
   Template by symptom: scroll/animation jank → `Animation Hitches`;
   SwiftUI update storms → `SwiftUI`; CPU/main-thread cost → `Time Profiler`;
   memory growth → `Allocations`.
3. Read structured, never raw. Start with `artifacts/perf-review/.../summary.md`,
   then inspect the frame contact sheet, `toc.xml`, and exported table XML under
   `tables/`. Main-thread samples correlated with hitch intervals are the money
   table. If xctrace is unsupported or non-exportable on this machine, say so
   explicitly and use the video/code evidence as a fallback, not as measured
   proof.
4. Fix the single top cause, re-record the same repro, compare numbers.
   One cause per iteration; resist shotgun optimization.

## SwiftUI usual suspects, in checking order
1. `body` doing work — formatting/sorting/filtering per render → precompute in
   the model.
2. Whole-list invalidation — missing stable identity in `ForEach`.
3. Wide views observing hot `@Observable` properties they don't display.
4. Images decoded on the main thread at full size.
5. `@Observable` state mutated mid-animation, restarting it every frame.

Evidence pack additions: `scripts/perf.sh` summary path, video/contact sheet,
trace/template used, before/after numbers (hang ms, hitch ratio, %
main-thread), and any unsupported-template fallback. "Feels smoother" is not
evidence.
