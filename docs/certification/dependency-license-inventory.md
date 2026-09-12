# Dependency / license inventory (trust baseline)

Collector anchor: trust-dependency-inventory v1.
Status: baseline, releasable without release-scope selection.
Machine source of truth: `artifacts/sbom/sbom.spdx-lite.json`, generated
on every `scripts/check-certification-dossier.sh` run from the four
`Package.swift` manifests (dossier: `sbom-generated`).

## Result: zero remote dependencies

| Package | Manifest | Tools | Remote deps | Local path deps only |
|---|---|---|---|---|
| Domain | `Packages/Domain/Package.swift` | 6.2 | 0 | yes |
| Features | `Packages/Features/Package.swift` | 6.2 | 0 | yes |
| DesignSystem | `Packages/DesignSystem/Package.swift` | 6.2 | 0 | yes |
| TestSupport | `Packages/TestSupport/Package.swift` | 6.2 | 0 | yes |

- Total remote dependencies: **0**. No `Package.resolved` exists because
  there is nothing to resolve. Local-path sources have no registry
  artifacts, so there are no hashes to record (honestly empty, not omitted).
- The SBOM generator fails closed on any remote `.package(url:)`
  dependency; the dossier collector re-verifies this file against the
  manifests on every run (see below).

## Licenses

- Third-party licenses: none apply — there are no third-party
  dependencies to license, attribute, or audit.
- First-party license for publication: **not selected**. Choosing the
  public license (and making the repo public) is explicit owner approval
  and waits on release-scope selection (dossier:
  `trust-release-scope-selection`). No license text is invented here.
- SBOM document license: `CC0-1.0` (the SBOM envelope's data license,
  not a product license).

## Collector cross-check

The `trust-dependency-inventory` dossier collector verifies, on this Mac:
(1) this file exists and carries its collector anchor; (2) all four
manifests still declare zero `.package(url:)` remotes; (3) this file's
remote-dependency total still reads 0. Any drift fails the run.
