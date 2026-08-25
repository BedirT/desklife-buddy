# Screenshots, video, and asset packages

## Screenshots

Record image digest, pixel dimensions, scale assumption, crop, color profile,
visible state, viewport/window context, and known provenance. Separate measured
facts from inference. Inventory geometry, hierarchy, type roles, color roles,
materials, assets, and state cues. One screenshot cannot prove hidden states,
responsive behavior, keyboard behavior, or motion.

Screenshot sources support `canonical`, `native-adaptation`, and `directional`.
Canonical means match the observable state and explicitly define the missing
state contract before implementation, not invent hidden behavior silently.

## Video

Preserve the original clip and its raw-file digest, but do not launch a local decoder or
media tool during ingestion. A launcher hash alone does not authenticate its
dynamic libraries, plugins, codecs, or bounded resource behavior. Until a
separately reviewed no-secret media executor exists, use only owner-provided,
content-addressed metadata, frames, contact sheets, audio timelines, or renders.
Record each derivative in `evidence_artifacts` with a stable ID, kind, repository
path, SHA-256, and provenance. A partial source remains valid intake when it has
at least one such artifact and typed `video_evidence_gaps`, but it cannot enter
translation until those gaps are cleared. Do not invent a `video_analysis` to
make incomplete evidence look ready.
Complete analysis and gaps are mutually exclusive. It must reference metadata,
contact-sheet or frame-set coverage, and an audio timeline when it asserts that
audio is present. Both inspection and translation descriptor-read the original
clip and every derivative inside the repository, compare their bytes with the
declared SHA-256 values, and reject aliases or concurrent directory replacement.
Record missing technical evidence explicitly, including:

- duration, frame rate, resolution, streams, and audio presence;
- fixed-interval, scene-change, and visual-change frames;
- contact sheets and timestamps;
- audio cue timing; and
- a machine-readable extraction manifest.

Interpret available evidence into semantic motion segments: trigger, start/end
states, duration, sequencing, trajectory, opacity/position/scale/rotation/color/
mask changes, approximate easing, camera behavior, interaction/audio cues,
confidence, and reduced-motion replacement. Never claim an exact curve or unseen
timing when the supplied evidence does not support it.

Video sources support all authority modes. In canonical mode, timing and
observable endpoints are invariants unless documented otherwise. In native-
adaptation mode, preserve rhythm and meaning using native macOS motion. In
directional mode, retain only the accepted motion language.

## Asset packages

Inventory every regular file by digest, type, dimensions/duration, color space,
license/provenance, intended state, and expected output location. Reject links,
executables, archives with path escapes, remote dependencies, unknown rights,
and embedded user-facing text that bypasses localization. Production art and
rights remain owner decisions; placeholders must be labeled as such.
