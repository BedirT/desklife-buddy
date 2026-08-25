#!/bin/bash -p
# Prove the factory contract gate rejects representative semantic corruption.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/scripts/check-factory-contract.sh"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/swiftmac-factory-contract.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

copy_contract_root() {
  local destination="$1"
  mkdir -p "$destination"
  cp -R "$ROOT/.agents" "$destination/.agents"
  cp -R "$ROOT/.factory" "$destination/.factory"
  cp "$ROOT/AGENTS.md" "$destination/AGENTS.md"
  cp "$ROOT/CLAUDE.md" "$destination/CLAUDE.md"
  mkdir -p "$destination/docs/factory" "$destination/docs/plans"
  cp "$ROOT/docs/factory/constitution.md" "$destination/docs/factory/constitution.md"
  cp "$ROOT/docs/factory/design-sources.md" "$destination/docs/factory/design-sources.md"
  cp "$ROOT/docs/plans/2026-07-09-macos-software-factory.md" \
    "$destination/docs/plans/2026-07-09-macos-software-factory.md"
  cp "$ROOT/docs/plans/TEMPLATE.md" "$destination/docs/plans/TEMPLATE.md"
  cp "$ROOT/docs/preferences.md" "$destination/docs/preferences.md"
  mkdir -p "$destination/scripts"
  cp "$ROOT/scripts/factory" "$destination/scripts/factory"
  mkdir -p "$destination/Packages/Factory"
  cp -R "$ROOT/Packages/Factory/Sources" "$destination/Packages/Factory/Sources"
}

expect_rejection() {
  local label="$1"
  local expected="$2"
  shift 2
  local output="$TMP_ROOT/$label.log"

  if "$@" >"$output" 2>&1; then
    echo "factory-contract test: expected rejection for $label" >&2
    cat "$output" >&2
    exit 1
  fi

  if ! grep -q "factory-contract: ERROR:" "$output"; then
    echo "factory-contract test: $label did not produce a contract diagnostic" >&2
    cat "$output" >&2
    exit 1
  fi
  if ! grep -Fq "$expected" "$output"; then
    echo "factory-contract test: $label did not report expected reason: $expected" >&2
    cat "$output" >&2
    exit 1
  fi
}

"$CHECK"
"$CHECK" --skill grill-me
expect_rejection unknown-skill "unknown skill 'does-not-exist'" "$CHECK" --skill does-not-exist

owner_boundary_root="$TMP_ROOT/owner-boundary"
copy_contract_root "$owner_boundary_root"
/usr/bin/python3 -I - "$owner_boundary_root/AGENTS.md" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "The normal owner gates are one batched $grill-me product intake and the final"
assert text.count(needle) == 1
path.write_text(
    text.replace(needle, "Every visible choice requires owner approval before the final", 1),
    encoding="utf-8",
)
PY
expect_rejection \
  owner-boundary \
  "AGENTS.md: one-intake owner boundary is missing" \
  "$CHECK" --root "$owner_boundary_root"

design_boundary_root="$TMP_ROOT/design-boundary"
copy_contract_root "$design_boundary_root"
/usr/bin/python3 -I - \
  "$design_boundary_root/docs/plans/2026-07-09-macos-software-factory.md" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "React/HTML is untrusted static data and is never executed during ingestion."
assert text.count(needle) == 1
path.write_text(text.replace(needle, "React/HTML may be rendered when permission is present.", 1), encoding="utf-8")
PY
expect_rejection \
  design-boundary \
  "docs/plans/2026-07-09-macos-software-factory.md: static-only design ingestion boundary is missing" \
  "$CHECK" --root "$design_boundary_root"

budget_root="$TMP_ROOT/budget"
copy_contract_root "$budget_root"
/usr/bin/python3 -I - "$budget_root/.factory/skills/registry.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
skill = next(item for item in document["skills"] if item["id"] == "grill-me")
skill["context_budget"]["total_bytes"] += 1
path.write_text(
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  context-budget \
  "grill-me: context budget total differs" \
  "$CHECK" --root "$budget_root" --skill grill-me

undeclared_resource_root="$TMP_ROOT/undeclared-skill-resource"
copy_contract_root "$undeclared_resource_root"
printf '#!/bin/bash\nexit 0\n' \
  >"$undeclared_resource_root/.agents/skills/design-ingest/undeclared.sh"
expect_rejection \
  undeclared-skill-resource \
  "design-ingest: provenance root contains undeclared components" \
  "$CHECK" --root "$undeclared_resource_root" --skill design-ingest

control_plane_root="$TMP_ROOT/control-plane"
copy_contract_root "$control_plane_root"
/usr/bin/python3 -I - "$control_plane_root" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
case_path = root / ".factory/evals/public/cases/factory-regressions.json"
document = json.loads(case_path.read_text(encoding="utf-8"))
case = next(
    item
    for item in document["cases"]
    if item["fixture_id"] == "factory-product-builder-control-plane-write"
)
case["input"]["requested_path"] = "App/AllowedProductFile.swift"
canonical = json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
case_path.write_text(canonical, encoding="utf-8")

# Keep the corpus hash correct so only the product/control-plane semantic check
# can reject the weakened fixture.
catalog_path = root / ".factory/evals/public/catalog.json"
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog_case = next(
    item for item in catalog["cases"] if item["fixture_id"] == "public-factory-regressions"
)
catalog_case["input_sha256"] = hashlib.sha256(canonical.encode("utf-8")).hexdigest()
catalog_path.write_text(
    json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  product-control-plane \
  "product/control-plane denial does not request a protected path" \
  "$CHECK" --root "$control_plane_root"

control_surface_root="$TMP_ROOT/control-surface"
copy_contract_root "$control_surface_root"
/usr/bin/python3 -I - "$control_surface_root/.factory/policy.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["control_plane_paths"].remove("Packages/Factory/**")
path.write_text(
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  control-surface \
  "policy control_plane_paths do not match the protected root surface" \
  "$CHECK" --root "$control_surface_root"

authority_root="$TMP_ROOT/public-activation"
copy_contract_root "$authority_root"
/usr/bin/python3 -I - \
  "$authority_root/Packages/Factory/Sources/FactoryCore/Isolation/RunnerIsolation.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
needle = "enum IsolationActivationAuthority {"
assert text.count(needle) == 1
path.write_text(text.replace(needle, "public " + needle, 1), encoding="utf-8")
PY
expect_rejection \
  public-activation \
  "unmerged build candidate exposes activation or source authority" \
  "$CHECK" --root "$authority_root"

duplicate_root="$TMP_ROOT/duplicate-key"
copy_contract_root "$duplicate_root"
duplicate_path="$duplicate_root/.factory/features.json"
/usr/bin/sed -i '' 's/"schema_version": 1/"schema_version": 1, "schema_version": 1/' "$duplicate_path"
expect_rejection duplicate-key "duplicate object key 'schema_version'" "$CHECK" --root "$duplicate_root"

noncanonical_root="$TMP_ROOT/noncanonical"
copy_contract_root "$noncanonical_root"
/usr/bin/python3 -I - "$noncanonical_root/.factory/features.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
path.write_text(json.dumps(document), encoding="utf-8")
PY
expect_rejection noncanonical-json "JSON is not canonical pretty form" "$CHECK" --root "$noncanonical_root"

role_root="$TMP_ROOT/role-authority"
copy_contract_root "$role_root"
/usr/bin/python3 -I - "$role_root/.factory/prompts/registry.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
role = next(item for item in document["roles"] if item["id"] == "code-auditor")
role["mutation_mode"] = "scratch-write"
path.write_text(
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  role-authority \
  "code-auditor: role authority differs" \
  "$CHECK" --root "$role_root"

active_root="$TMP_ROOT/active-placeholder"
copy_contract_root "$active_root"
/usr/bin/python3 -I - "$active_root/.factory/skills/registry.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
skill = next(item for item in document["skills"] if item["id"] == "adopt-app")
skill["status"] = "active"
path.write_text(
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  active-placeholder \
  "adopt-app: active report must be qualified" \
  "$CHECK" --root "$active_root" --skill adopt-app

progressive_root="$TMP_ROOT/progressive-escape"
copy_contract_root "$progressive_root"
/usr/bin/python3 -I - "$progressive_root" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
registry_path = root / ".factory/skills/registry.json"
registry = json.loads(registry_path.read_text(encoding="utf-8"))
skill = next(item for item in registry["skills"] if item["id"] == "adopt-app")
escaped_path = ".factory/policy.json"
escaped_bytes = (root / escaped_path).read_bytes()
skill["progressive_disclosure_paths"] = [escaped_path]
skill["context_budget"]["reference_bytes"] = len(escaped_bytes)
skill["context_budget"]["total_bytes"] = sum(
    skill["context_budget"][key]
    for key in ("body_bytes", "metadata_bytes", "reference_bytes", "resource_bytes")
)
skill["declared_cost_ceiling"]["max_context_tokens"] = (
    skill["context_budget"]["total_bytes"] + 3
) // 4

qualification_path = root / skill["qualification_path"]
qualification = json.loads(qualification_path.read_text(encoding="utf-8"))
qualification["component_hashes"].append(
    {
        "path": escaped_path,
        "sha256": hashlib.sha256(escaped_bytes).hexdigest(),
        "size_bytes": len(escaped_bytes),
    }
)
qualification["component_hashes"].sort(key=lambda item: item["path"])
qualification_bytes = (
    json.dumps(qualification, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
).encode("utf-8")
qualification_path.write_bytes(qualification_bytes)
skill["qualification_sha256"] = hashlib.sha256(qualification_bytes).hexdigest()
registry_path.write_text(
    json.dumps(registry, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  progressive-escape \
  "adopt-app: progressive disclosure is outside its provenance root" \
  "$CHECK" --root "$progressive_root" --skill adopt-app

alias_root="$TMP_ROOT/path-alias"
copy_contract_root "$alias_root"
/usr/bin/python3 -I - "$alias_root" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
registry_path = root / ".factory/skills/registry.json"
registry = json.loads(registry_path.read_text(encoding="utf-8"))
skill = next(item for item in registry["skills"] if item["id"] == "adopt-app")
aliased_source = "./.agents/skills/adopt-app/SKILL.md"
skill["provenance"]["repository_path"] = "."
skill["source_path"] = aliased_source

qualification_path = root / skill["qualification_path"]
qualification = json.loads(qualification_path.read_text(encoding="utf-8"))
qualification["component_hashes"][0]["path"] = aliased_source
qualification_bytes = (
    json.dumps(qualification, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
).encode("utf-8")
qualification_path.write_bytes(qualification_bytes)
skill["qualification_sha256"] = hashlib.sha256(qualification_bytes).hexdigest()
registry_path.write_text(
    json.dumps(registry, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  path-alias \
  "repository path is not in canonical POSIX form" \
  "$CHECK" --root "$alias_root" --skill adopt-app

ceiling_root="$TMP_ROOT/policy-ceiling"
copy_contract_root "$ceiling_root"
/usr/bin/python3 -I - "$ceiling_root/.factory/policy.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
document = json.loads(path.read_text(encoding="utf-8"))
document["execution"]["agent_depth"] = 10**30
path.write_text(
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  policy-ceiling \
  "policy execution contract differs from the frozen trusted root ceiling" \
  "$CHECK" --root "$ceiling_root"

corpus_root="$TMP_ROOT/corpus-deletion"
copy_contract_root "$corpus_root"
/usr/bin/python3 -I - "$corpus_root" <<'PY'
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
case_path = root / ".factory/evals/public/cases/kernel-denials.json"
document = {
    "cases": [
        {
            "expected_decision": "accept",
            "expected_reason_code": "anything",
            "fixture_id": "replacement-case",
            "input": {},
        }
    ],
    "schema_version": 1,
}
case_bytes = (
    json.dumps(document, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
).encode("utf-8")
case_path.write_bytes(case_bytes)
catalog_path = root / ".factory/evals/public/catalog.json"
catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
catalog_case = next(
    item for item in catalog["cases"] if item["fixture_id"] == "public-kernel-denials"
)
catalog_case["input_sha256"] = hashlib.sha256(case_bytes).hexdigest()
catalog_path.write_text(
    json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY
expect_rejection \
  corpus-deletion \
  "public denial fixture kernel-arbitrary-main-push is missing" \
  "$CHECK" --root "$corpus_root"

echo "factory-contract mutation tests passed"
