# External design sources

External design is a first-class factory input, not informal inspiration. A
source enters the same route whether it is a Figma file, React component,
standalone HTML export, screenshot, image set, video, or asset package. Before
implementation the owner selects its authority:

- `canonical`: reproduce observable appearance, states, interaction, and motion;
- `native-adaptation`: preserve product intent while adapting to macOS behavior;
- `directional`: use the source as a visual direction, not a pixel contract.

Screenshots and videos support all three modes. The mode belongs to each source,
so one brief may combine a canonical reference video with directional stills and
native-adaptation HTML.

## Safe ingestion

The design ingestor creates a content-addressed `DesignSourceManifest` before a
builder sees the source. It records provenance and rights, source kind, authority,
viewports, states, interactions, motion, assets, missing behavior, and confidence.
Unknown ownership, missing source bytes, or an undeclared authority stops intake.

| Source | Ingestion rule |
|---|---|
| Figma | Prefer owner-authorized inspect/export data. Freeze node, component, variant, variable, font, asset, and viewport identities. |
| React | Treat source and a trusted render as design evidence. Never execute owner-provided package scripts or inherit dependencies. |
| Standalone HTML / Claude Design export | Parse inert HTML/CSS/assets and compare trusted renders. Scripts, remote fetches, and embedded executable content are not run. |
| Screenshot / image | Preserve original bytes, scale, crop, color profile, viewport, and state. Record which behavior is not observable. |
| Video | Preserve original bytes and owner-provided metadata/renders. Local decoder execution remains disabled until a separately reviewed no-secret media executor exists. |
| Asset package | Inventory every file, digest, format, dimensions, color profile, license/provenance, and intended use before import. |

`scripts/factory design inspect` validates the manifest and repository bytes.
For one `asset_paths` entry, `content_sha256` is the SHA-256 of that file. For
multiple entries, it is the SHA-256 of the canonical sorted JSON array of each
`{path, sha256}` identity in `asset_paths` order. The
`$design-ingest` skill contains source-specific progressive-disclosure guidance;
unselected source guides do not enter the model context.

## Video and motion understanding

Video is not reduced to a few arbitrary screenshots, but ingestion also does not
execute an ambient decoder. Preserve the original clip digest and bind every
owner-provided metadata file, frame set, contact sheet, audio timeline, or
render in `evidence_artifacts` by stable ID, kind, repository path, SHA-256, and
provenance. A launcher digest is insufficient because it
does not authenticate dynamic libraries, plugins, codecs, or finite resource
behavior. Missing technical or temporal evidence remains an acceptance gap until
a separately reviewed, no-secret media executor can produce bounded evidence.
Partial intake is valid when it carries static artifacts and typed
`video_evidence_gaps`, but translation validation fails closed until every gap
is resolved; no synthetic `video_analysis` is required merely to preserve the
owner's source. Complete analysis and gaps are mutually exclusive. Complete
analysis references metadata, contact-sheet or frame-set evidence, and an audio
timeline whenever it asserts audio is present. `scripts/factory design inspect`
and `design translate` descriptor-read every declared source asset and evidence
artifact beneath the repository root, reject links, aliases, special files, and
directory replacement, and compare the bytes with the manifest SHA-256 before
accepting the record. Manifests allow at most 64 source paths and 64 evidence
artifacts. Source files are capped at 256 MiB each, evidence derivatives at
64 MiB each, and aggregate remaining capacity is enforced before every read at
512 MiB total. Reads check a 30-second deadline between chunks; the CLI also
installs a 35-second process watchdog for blocking filesystem calls. Verification
is repository-read-only: the shell entrypoint incrementally builds the trusted
CLI in an owner-private, locked cache outside the checkout, keyed by the
canonical package path and Swift toolchain. Cache nodes reject extended ACLs,
write-granting ancestor ACLs, links, and foreign ownership before the verified
executable runs, and cache overrides inside the checkout are rejected. SwiftPM
revalidates the exact source dependencies on every invocation. The three most
recent generations are retained; pruning skips any generation whose lock is
held, and each invocation holds its own generation lock continuously from build
through verified execution. The locked child must recompute the same scratch,
lock path, and lock inode before building. Disposable test fixtures use a
separately cleaned cache. The verifier
then captures file and directory
identities before each source read and revalidates the metadata-only records
immediately before acceptance without creating a repository lock or retaining
payload bytes. The caller must keep the repository quiescent for the duration
of inspection; the checks reject changes they observe but do not claim an
atomic snapshot against non-cooperating editors or Git processes. Translation
readiness is checked before filesystem work, so unresolved gaps fail
immediately. Translation targets must also be disjoint from every source and
evidence path, including case-folded aliases.

Available technical artifacts are inputs to semantic motion review, not the final
interpretation. The design ingestor and motion witness identify state changes,
durations, easing intent, spatial relationships, continuity, interruption,
input coupling, audio synchronization, confidence, and a reduced-motion
alternative. Missing or ambiguous transitions remain explicit acceptance gaps.

## Native translation

The design translator converts the frozen source into a
`DesignTranslationContract` without changing its authority. Translation must:

1. map source values onto existing DesignSystem tokens and components;
2. define macOS window, toolbar, menu, keyboard, pointer, focus, and accessibility behavior;
3. enumerate every reachable Preview state and responsive viewport;
4. preserve canonical observations or list bounded, owner-approved deviations;
5. hand motion intent to `$motion`, still-state proof to `$snapshot-verify`, and
   implementation vocabulary to `$design-system`.

New tokens, dependencies, public assets, final art, copy/tone changes, or visible
layout choices remain owner decisions. Invisible mapping and file placement are
implementation details and proceed without interruption.

## Comparison and handoff

The product witness compares source and result at matching viewport and state.
Canonical sources require source/result evidence and explicit deviation IDs;
native adaptations require proof of both preserved intent and macOS conventions;
directional sources require the accepted direction and the concrete choices
derived from it. Video-backed work additionally requires motion-witness evidence.

The owner report links each source to its authority, source evidence, result
evidence, deviations, criterion status, and remaining risk. A design change is
not `READY_FOR_OWNER` while any reachable source state, interaction, motion
segment, accessibility state, or required comparison lacks evidence.
