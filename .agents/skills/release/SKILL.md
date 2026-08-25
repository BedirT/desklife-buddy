---
name: release
description: Ship a macOS version — release preflight, version bump, Release archive/export, release notes, and distribution handoff. Use for "release", "ship", "App Store", "Developer ID", notarization, or version-bump requests.
---

# Release

Produce a verified, signed macOS archive/export plus everything the human needs
to press the final distribution buttons. Uploading, notarization account setup,
and store metadata stay human-owned unless explicitly configured.

## Sequence
1. `scripts/release.sh preflight` — runs the verification gate (host tests,
   both snapshot suites, app build, lint). Anything red stops the release.
2. Draft release notes from `git log --oneline <last-tag>..HEAD`: user-visible
   changes in user language, grouped fixed/added/changed. Internal refactors do
   not appear.
3. `scripts/release.sh bump X.Y.Z` — semantic version against the notes
   (user-visible feature → minor; fixes only → patch). The build number
   auto-increments. Commit the bump with the notes.
4. `scripts/release.sh archive <TEAM_ID>` — Release-configuration macOS
   archive and export into `artifacts/release/`. `EXPORT_METHOD` selects the
   distribution path (`app-store-connect`, `developer-id`, etc.) and is an
   owner/signing decision.
5. Hand off an evidence pack: preflight output, notes draft, archive/export
   paths, and the human checklist printed by preflight.

## Rules
- Never ship around a red gate. Intended snapshot diffs get re-recorded by the
  human first.
- Version/build numbers change only through `release.sh bump` — no hand edits.
- Signing identities, team IDs, export method, notarization credentials,
  screenshots, review notes, and upload are human-owned release decisions.
- If the user wants fully agentic upload/notarization, propose the credential
  setup as a separate ask-first task rather than improvising with local secrets.
