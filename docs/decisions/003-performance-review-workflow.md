# Performance Review Workflow

## Context

Animation lag, scroll hitches, image decode stalls, and SwiftUI update storms
cannot be proven by Preview snapshots. Video can show that a stall is visible,
but it cannot explain why. Instruments templates can be unsupported or fail to
export on a given machine, so the workflow needs an honest fallback instead of
treating traces as guaranteed.

## Decision

Performance investigations use the real app and `scripts/perf.sh`. The script
captures macOS window video, extracted frames, an xctrace recording attached to
the running app process, exported trace TOC, likely performance table XML, and a
`summary.md` under
`artifacts/perf-review/`. Agents diagnose from structured trace data when it is
available, record unsupported-template fallbacks explicitly, fix one top cause,
and rerun the same capture for before/after evidence.

The target app and xctrace commands run with a default-deny environment. Raw
bundles are private, `local-restricted` evidence: a recursive binary-safe scan
plus native Vision OCR over screenshots and high-resolution video frames must
pass before the manifest is retained or the path is printed. The human contact
sheet remains sampled, but retention scans every decoded video frame and records
that count in the bundle manifest. Each bundle contains immutable copies of its
build/runtime provenance; Git HEAD, source, PID, and window are rechecked after
the potentially long final scan. Missing or incomplete frame extraction, a
failed scan, or an interrupted capture discards the bundle, and untrusted CI
never uploads the raw artifact tree.

## Consequences

Previews remain the visual-state spec; they are not performance proof. Video is
evidence of visible stutter, while xctrace/signposts are evidence of cause. If a
trace cannot be captured or exported on the current machine, the evidence pack
must say so and avoid measured-performance claims. Repeated tuning of a high-risk
flow should add app signposts so trace tables have named anchors.
