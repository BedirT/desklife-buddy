#!/bin/bash -p
# Epic 3 story 9: certification dossier collector and gate.
#
# Collects, on THIS Mac, the evidence behind docs/certification/dossier.v1.json:
# (a) no-egress evidence — raw-import guard verdict, transport-token rescan,
#     ServiceManagement import inventory, entitlement inventory, privacy-manifest
#     absence; (b) TCC/revocation posture — placeholder-capability inventory,
#     broker deadline, kill-switch presence; (c) resource numbers — governor
#     budget table plus per-run suite timings honestly labeled as CI timings,
#     never energy claims; (d) SBOM generation from the dependency-free SPM
#     packages; (e) benchmark scaffolding entry for future owner hardware runs.
#
# Fails closed (nonzero exit) on any owned check failing or on any drift
# between the dossier status file and what was collected. Owner-gated
# (pending-owner) items are reported, never failed: the exact missing input
# lives in each dossier entry's missingInput field.
#
# Outputs (gitignored, never committed): artifacts/dossier/evidence.json,
# artifacts/dossier/suite-timings.json (when an xcresult exists),
# artifacts/sbom/sbom.spdx-lite.json.
#
# Modes: no args (full run) | --check-dossier <file> (validate one dossier
# file against the closed vocabulary and check inventory only) | --help.
#
# Tests point the collectors at a scratch tree via CERTIFICATION_SCAN_ROOT
# and override paths via DOSSIER_PATH / DOSSIER_SCHEMA / DOSSIER_OUT / SBOM_OUT.
set -euo pipefail

. "$(dirname "$0")/lib.sh"
cd "$ROOT"

scan_root="${CERTIFICATION_SCAN_ROOT:-$ROOT}"
dossier_path="${DOSSIER_PATH:-$ROOT/docs/certification/dossier.v1.json}"
schema_path="${DOSSIER_SCHEMA:-$ROOT/docs/certification/dossier.schema.json}"
dossier_out="${DOSSIER_OUT:-$ARTIFACTS/dossier}"
sbom_out="${SBOM_OUT:-$ARTIFACTS/sbom}"

# Closed check inventory. The first block is owned: every id here MUST be
# collected below and MUST read "pass" in the dossier. The second block is
# owner-gated: every id here MUST read "pending-owner" with a missingInput.
owned_ids=(
  no-egress-raw-import-guard
  no-egress-transport-absence
  no-egress-servicemanagement-inventory
  no-egress-entitlement-inventory
  no-egress-privacy-manifest-absence
  tcc-placeholder-capability-inventory
  tcc-broker-deadline
  tcc-kill-switch
  resource-governor-budgets
  sbom-generated
  benchmark-harness
)
pending_ids=(
  tcc-physical-prompt-evidence
  tcc-revocation-device-timing
  resource-suite-timings
  resource-energy-thermal
  benchmark-owner-hardware-run
)

usage() {
  echo "usage: scripts/check-certification-dossier.sh [--check-dossier <file>|--help]" >&2
}

# Validates one dossier file: shape, closed status vocabulary, evidence and
# missingInput discipline, and the closed check inventory (no unknown ids,
# no missing owned or pending ids, no duplicate ids, dossier/schema version
# agreement). Exits nonzero with a reason on stderr.
validate_dossier() {
  local file="$1"
  /usr/bin/python3 -I - "$file" "$schema_path" "${owned_ids[*]}" "${pending_ids[*]}" <<'PY'
from __future__ import annotations

import json
import re
import sys

dossier_path, schema_path, owned_raw, pending_raw = sys.argv[1:5]
owned = owned_raw.split()
pending = pending_raw.split()

try:
    with open(dossier_path, encoding="utf-8") as handle:
        dossier = json.load(handle)
except (OSError, json.JSONDecodeError) as error:
    print(f"dossier: unreadable JSON: {error}", file=sys.stderr)
    sys.exit(1)

try:
    with open(schema_path, encoding="utf-8") as handle:
        schema = json.load(handle)
except (OSError, json.JSONDecodeError) as error:
    print(f"dossier: schema unreadable: {error}", file=sys.stderr)
    sys.exit(1)

failures: list[str] = []

if dossier.get("schemaVersion") != schema.get("dossierSchemaVersion"):
    failures.append("schemaVersion disagrees with the schema file's dossierSchemaVersion")
if dossier.get("dossierVersion") != "v1":
    failures.append("dossierVersion must be v1")
if not isinstance(dossier.get("generatedNote"), str) or not dossier["generatedNote"].strip():
    failures.append("generatedNote must be a non-empty string")

checks = dossier.get("checks")
if not isinstance(checks, list) or not checks:
    failures.append("checks must be a non-empty array")
    checks = []

seen: set[str] = set()
for index, check in enumerate(checks):
    where = f"checks[{index}]"
    if not isinstance(check, dict):
        failures.append(f"{where} must be an object")
        continue
    allowed = {"id", "title", "status", "evidence", "missingInput", "notes"}
    for key in check:
        if key not in allowed:
            failures.append(f"{where}: unknown field {key!r}")
    check_id = check.get("id")
    if not isinstance(check_id, str) or not re.fullmatch(r"[a-z0-9-]+", check_id):
        failures.append(f"{where}: id must match ^[a-z0-9-]+$")
        continue
    if check_id in seen:
        failures.append(f"{where}: duplicate check id {check_id!r}")
    seen.add(check_id)
    if not isinstance(check.get("title"), str) or not check["title"].strip():
        failures.append(f"{where} ({check_id}): title must be a non-empty string")
    status = check.get("status")
    if status not in ("pass", "pending-owner"):
        failures.append(f"{where} ({check_id}): unknown status {status!r}")
        continue
    if not isinstance(check.get("evidence"), str) or not check["evidence"].strip():
        failures.append(f"{where} ({check_id}): evidence must be a non-empty string")
    missing = check.get("missingInput", "")
    if status == "pending-owner":
        if not isinstance(missing, str) or not missing.strip():
            failures.append(f"{where} ({check_id}): pending-owner requires a non-empty missingInput")

known = set(owned) | set(pending)
for check_id in sorted(seen - known):
    failures.append(f"unknown check id {check_id!r}")
for check_id in owned:
    if check_id not in seen:
        failures.append(f"missing owned check {check_id!r}")
for check_id in pending:
    if check_id not in seen:
        failures.append(f"missing pending-owner check {check_id!r}")

by_id = {c["id"]: c for c in checks if isinstance(c, dict) and isinstance(c.get("id"), str)}
for check_id in owned:
    if by_id.get(check_id, {}).get("status") != "pass":
        failures.append(f"owned check {check_id!r} must read pass")
for check_id in pending:
    if check_id in by_id and by_id[check_id].get("status") != "pending-owner":
        failures.append(f"owner-gated check {check_id!r} must read pending-owner")

if failures:
    print("dossier validation failures:", file=sys.stderr)
    for failure in failures:
        print(f"  {failure}", file=sys.stderr)
    sys.exit(1)
print(f"dossier: OK ({len(checks)} checks)")
PY
}

swift_roots() {
  for dir in App Packages AppTests; do
    [[ -d "$scan_root/$dir" ]] && printf '%s\n' "$scan_root/$dir"
  done
}
mode="${1:-}"
if [[ "$mode" == "--help" ]]; then
  usage
  exit 0
fi
if [[ "$mode" == "--check-dossier" ]]; then
  [[ "$#" -eq 2 ]] || { usage; exit 2; }
  validate_dossier "$2"
  exit "$?"
fi
[[ "$#" -eq 0 ]] || { usage; exit 2; }


failures=()
pass_count=0
record_pass() {
  pass_count=$((pass_count + 1))
  echo "  pass: $1"
}

# 1. Raw-import guard verdict (the fail-closed authority; adjacent locks in
# its header: protocol configuration, motion assets, HistoryExport vocab).
if RAW_IMPORTS_SCAN_ROOT="$scan_root" "$ROOT/scripts/check-raw-imports.sh" >/dev/null; then
  record_pass "no-egress-raw-import-guard (check-raw-imports.sh green)"
else
  failures+=("no-egress-raw-import-guard: check-raw-imports.sh failed")
fi

# 2. Transport-token rescan. Full-line comments are stripped so
# deliberate-absence prose (HelperXPCFeasibilitySeams doc comment) cannot
# false-positive; real code tokens still trip. The unstripped guard above
# stays the fail-closed authority.
build_exclude='/\.build/|/DerivedData/|/checkouts/'
transport_pattern='URLSession|URLRequest|import[[:space:]]+(Network|CloudKit|WebKit)|NWConnection|NWPathMonitor|NWListener|CK(Container|Record|Database|Query|Asset|Subscription)|WKWebView|import[[:space:]]+MetricKit|MXMetric|NSXPCConnection|XPCService'
transport_hits="$(grep -rn -E "$transport_pattern" $(swift_roots) --include='*.swift' 2>/dev/null | grep -vE "$build_exclude" | grep -v '^[^(]*:[0-9]*:[[:space:]]*//' || true)"
if [[ -z "$transport_hits" ]]; then
  record_pass "no-egress-transport-absence (zero transport tokens in product Swift)"
else
  failures+=("no-egress-transport-absence: transport tokens found: $transport_hits")
fi

# 3. ServiceManagement inventory: SMAppService login-item registration only,
# in exactly these two files. Any new importer fails the run.
sm_files="$(grep -rln 'import ServiceManagement' $(swift_roots) --include='*.swift' 2>/dev/null | grep -vE "$build_exclude" | sed "s|^$scan_root/||" | sort | tr '\n' ' ' || true)"
expected_sm="App/Settings/LaunchAtLoginService.swift App/Settings/SettingsIntegrationsAppRuntime.swift "
if [[ "$sm_files" == "$expected_sm" ]]; then
  record_pass "no-egress-servicemanagement-inventory (login-item only, 2 files)"
else
  failures+=("no-egress-servicemanagement-inventory: unexpected importers: ${sm_files:-<none>}")
fi

# 4. Entitlement inventory: exactly sandbox + user-selected read-write.
entitlement_keys="$(/usr/bin/python3 -I - "$scan_root/App/App.entitlements" <<'PY'
from __future__ import annotations

import plistlib
import sys

try:
    with open(sys.argv[1], "rb") as handle:
        entitlements = plistlib.load(handle)
except OSError as error:
    print(f"unreadable: {error}", file=sys.stderr)
    sys.exit(1)
print(" ".join(sorted(entitlements)))
PY
)" || true
expected_keys="com.apple.security.app-sandbox com.apple.security.files.user-selected.read-write"
if [[ "$entitlement_keys" == "$expected_keys" ]]; then
  record_pass "no-egress-entitlement-inventory (sandbox + user-selected read-write only)"
else
  failures+=("no-egress-entitlement-inventory: unexpected keys: ${entitlement_keys:-<unreadable>}")
fi

# 5. Privacy-manifest absence: no protected-API use is declared anywhere.
manifests="$(find "$scan_root" -name '*.xcprivacy' -not -path '*/.build/*' -not -path '*/DerivedData/*' 2>/dev/null || true)"
if [[ -z "$manifests" ]]; then
  record_pass "no-egress-privacy-manifest-absence (no PrivacyInfo.xcprivacy)"
else
  failures+=("no-egress-privacy-manifest-absence: manifests found: $manifests")
fi

# 6. Placeholder-capability inventory: exactly the five placeholder cases.
broker_file="$scan_root/Packages/Domain/Sources/Domain/PermissionBroker.swift"
capability_cases="$(/usr/bin/python3 -I - "$broker_file" <<'PY'
from __future__ import annotations

import re
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        source = handle.read()
except OSError as error:
    print(f"unreadable: {error}", file=sys.stderr)
    sys.exit(1)
match = re.search(r"public enum PermissionCapability.*?^}", source, re.MULTILINE | re.DOTALL)
if match is None:
    print("missing-enum", file=sys.stderr)
    sys.exit(1)
cases = sorted(re.findall(r"^\s*case\s+([A-Za-z]+)", match.group(0), re.MULTILINE))
print(" ".join(cases))
PY
)" || true
if [[ "$capability_cases" == "effectHold effectRestart sensingAmbient sensingMotion sensingPresence" ]]; then
  record_pass "tcc-placeholder-capability-inventory (5 placeholder capabilities)"
else
  failures+=("tcc-placeholder-capability-inventory: unexpected cases: ${capability_cases:-<unreadable>}")
fi

# 7. Revocation deadline pinned at 5 ticks.
if grep -q 'public static let revocationDeadlineTicks: TimeInterval = 5' "$broker_file" 2>/dev/null; then
  record_pass "tcc-broker-deadline (revocationDeadlineTicks == 5)"
else
  failures+=("tcc-broker-deadline: revocationDeadlineTicks drifted from 5 ticks")
fi

# 8. Kill switch present with fail-closed engage.
if grep -q 'func engageKillSwitch' "$broker_file" 2>/dev/null \
  && grep -q 'func disengageKillSwitch' "$broker_file" 2>/dev/null \
  && grep -q 'isKillSwitchEngaged' "$broker_file" 2>/dev/null; then
  record_pass "tcc-kill-switch (engage/disengage/state present)"
else
  failures+=("tcc-kill-switch: kill-switch surface missing from PermissionBroker.swift")
fi

# 9. Governor budget table pinned (capacity/refill/cadenceTicks per class).
governor_file="$scan_root/Packages/Domain/Sources/Domain/ResourceGovernor.swift"
budgets_ok=true
for spec in \
  '.leaseIssuance: GovernorBudget(capacity: 4, refillAmount: 4, refillCadenceTicks: 60)' \
  '.busAdmission: GovernorBudget(capacity: 16, refillAmount: 16, refillCadenceTicks: 60)' \
  '.fusion: GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30)' \
  '.firewallEvaluation: GovernorBudget(capacity: 8, refillAmount: 8, refillCadenceTicks: 30)'; do
  grep -q -F "$spec" "$governor_file" 2>/dev/null || budgets_ok=false
done
if $budgets_ok; then
  record_pass "resource-governor-budgets (4 classes pinned)"
else
  failures+=("resource-governor-budgets: defaultBudgets drifted from the dossier table")
fi

# 10. SBOM generation (SPDX-lite): the 4 dep-free packages, local path deps
# only, no remote .package(url:) dependency, no invented hashes (local-path
# sources have no registry artifacts to hash; no Package.resolved exists
# because there is nothing to resolve).
mkdir -p "$sbom_out"
if /usr/bin/python3 -I - "$scan_root" "$sbom_out/sbom.spdx-lite.json" <<'PY'
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
out_path = Path(sys.argv[2])
package_names = ["Domain", "Features", "DesignSystem", "TestSupport"]

packages: list[dict[str, object]] = []
remote: list[str] = []
for name in package_names:
    manifest = root / "Packages" / name / "Package.swift"
    try:
        text = manifest.read_text(encoding="utf-8")
    except OSError as error:
        print(f"sbom: unreadable {manifest}: {error}", file=sys.stderr)
        sys.exit(1)
    tools = re.search(r"^// swift-tools-version:\s*(\S+)", text, re.MULTILINE)
    local_deps = sorted(set(re.findall(r"\.package\(\s*path:\s*\"([^\"]+)\"", text)))
    remote_deps = re.findall(r"\.package\(\s*url:\s*\"([^\"]+)\"", text)
    remote.extend(f"{name}: {url}" for url in remote_deps)
    packages.append(
        {
            "name": name,
            "manifest": f"Packages/{name}/Package.swift",
            "toolsVersion": tools.group(1) if tools else "unknown",
            "localPathDependencies": local_deps,
            "remoteDependencies": [],
            "hashes": [],
            "hashNote": "No hashes: local-path sources only; no registry artifacts exist to hash.",
        }
    )

if remote:
    print("sbom: remote dependencies found (dossier claims zero):", file=sys.stderr)
    for entry in remote:
        print(f"  {entry}", file=sys.stderr)
    sys.exit(1)

document = {
    "spdxVersion": "SPDX-2.3",
    "dataLicense": "CC0-1.0",
    "name": "desklife-sbom",
    "documentNote": "SPDX-lite inventory of the 4 dependency-free SPM packages. "
    "Honest empty-dependency statement: zero remote dependencies; local path "
    "references only; no Package.resolved exists because there is nothing to resolve.",
    "packages": packages,
}
out_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
print(f"sbom: wrote {out_path} ({len(packages)} packages, 0 remote dependencies)")
PY
then
  record_pass "sbom-generated ($sbom_out/sbom.spdx-lite.json)"
else
  failures+=("sbom-generated: SBOM generation failed")
fi

# 11. Benchmark scaffolding: the dossier schema exists at version 1 and this
# script owns every check id the dossier inventories (validated below).
if [[ -f "$schema_path" ]] \
  && /usr/bin/python3 -I -c 'import json,sys; sys.exit(0 if json.load(open(sys.argv[1]))["dossierSchemaVersion"] == 1 else 1)' "$schema_path"; then
  record_pass "benchmark-harness (schema v1 + collector ownership verified below)"
else
  failures+=("benchmark-harness: dossier schema missing or version drift")
fi

# 12. Suite timings (per-run, honestly labeled): when an xcresult exists,
# summarize it as CI wall-clock timings — never energy claims. Absence is a
# pending-owner report, never a failure.
mkdir -p "$dossier_out"
xcresult="$ARTIFACTS/AppTests.xcresult"
if [[ -d "$xcresult" ]] && command -v xcrun >/dev/null 2>&1; then
  if /usr/bin/xcrun xcresulttool get --format json --path "$xcresult" >"$dossier_out/suite-timings.json" 2>/dev/null; then
    echo "  collected: resource-suite-timings ($dossier_out/suite-timings.json; CI wall-clock timings, NOT energy claims)"
  else
    echo "  pending-owner: resource-suite-timings (xcresult present but unreadable; see missingInput)"
  fi
else
  echo "  pending-owner: resource-suite-timings (no $xcresult; run scripts/test.sh App, then re-run)"
fi

# Machine-readable run record beside the dossier.
{
  printf '{\n  "dossier": "%s",\n' "$dossier_path"
  printf '  "passes": %s,\n' "$pass_count"
  printf '  "collected": ['
  sep=""
  for id in "${owned_ids[@]}"; do
    printf '%s"%s"' "$sep" "$id"
    sep=", "
  done
  printf '],\n  "pendingOwner": ['
  sep=""
  for id in "${pending_ids[@]}"; do
    printf '%s"%s"' "$sep" "$id"
    sep=", "
  done
  printf ']\n}\n'
} >"$dossier_out/evidence.json"

# Dossier-vs-collection cross-check: fails closed on any drift.
if ! validate_dossier "$dossier_path"; then
  failures+=("dossier status file failed validation")
fi

if ((${#failures[@]})); then
  printf 'certification dossier failures:\n' >&2
  for failure in "${failures[@]}"; do
    printf '  %s\n' "$failure" >&2
  done
  exit 1
fi

printf 'dossier: %s passes collected; %s pending-owner reported (see missingInput):\n' \
  "$pass_count" "${#pending_ids[@]}"
for id in "${pending_ids[@]}"; do
  printf '  pending-owner: %s\n' "$id"
done
echo "CERTIFICATION DOSSIER OK"
