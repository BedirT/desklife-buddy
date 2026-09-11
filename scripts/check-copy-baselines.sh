#!/bin/bash -p
# Copy/baseline staleness reminder. Runs inside scripts/lint.sh.
#
# Context: landedWaiting baselines kept an old em-dash caption after the
# approved copy moved to a comma; the staleness surfaced only as a pixel
# mismatch. Copy sources and their owning snapshot suites:
#
#   Packages/Features/Sources/<Module>/*L10n.swift
#     -> Packages/Features/Tests/<Module>Tests (*SnapshotTests suites)
#   Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings
#     -> shared copy home for every Features suite; changed keys are
#        attributed by key prefix (headsUp.*, settings.*, movement.*, ...)
#   Packages/Features/Sources/WeeklyRhythm/Resources/Localizable.xcstrings
#     -> WeeklyRhythmTests
#   Packages/DesignSystem copy (DesignSystemL10n.swift, *.xcstrings)
#     -> Packages/DesignSystem/Tests/DesignSystemTests
#   App copy (AppL10n.swift, App/Resources/*.xcstrings)
#     -> attributed by key prefix (app.settings.*, app.weekly.*, ...),
#        unmapped keys remind across all Features suites.
#
# Policy: a changed copy source without an updated baseline under the
# owning suite's __Snapshots__/ directory prints a reminder naming the
# owning suites. The reminder is advisory, never a failure, and never
# records: inspect the render first, then record explicitly with
# scripts/record-snapshots.sh --confirm. A copy change that ends up with
# no visual impact still reminds; a baseline-only change stays silent.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

/usr/bin/python3 -I - "$ROOT" <<'PY'
import json
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])

FEATURES_TESTS = "Packages/Features/Tests/"
DS_TESTS = "Packages/DesignSystem/Tests/"

# Shared-catalog key prefix -> owning Features test dirs.
PREFIX_TO_TESTS = {
    "settings": ["SettingsFeatureTests"],
    "headsUp": ["HeadsUpTests"],
    "movement": ["MovementTests"],
    "onboarding": ["OnboardingTests"],
    "status_menu": ["StatusMenuTests"],
    "breakFlow": ["BreakFlowTests"],
    "visualReset": ["VisualResetTests"],
    "item_list": ["ItemListTests"],
    "item_detail": ["ItemListTests"],
}

# App-catalog key prefix -> owning Features test dirs.
APP_PREFIX_TO_TESTS = {
    "app.settings": ["SettingsFeatureTests"],
    "app.weekly": ["WeeklyRhythmTests"],
    "app.onboarding": ["OnboardingTests"],
}


def run(*args):
    try:
        proc = subprocess.run(
            args,
            cwd=root,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            timeout=30,
        )
        return proc.stdout if proc.returncode == 0 else ""
    except Exception:
        return ""


def changed_paths():
    paths = set()
    porcelain = run("git", "status", "--porcelain=v1", "-z", "--untracked-files=all")
    for entry in porcelain.split("\0"):
        if len(entry) < 4:
            continue
        path = entry[3:]
        if " -> " in path:
            path = path.rsplit(" -> ", 1)[1]
        path = path.strip().strip('"')
        if path:
            paths.add(path)
    base = ""
    for candidate in ("origin/main", "main"):
        candidate_base = run("git", "merge-base", "HEAD", candidate).strip()
        if candidate_base:
            base = candidate_base
            break
    if base:
        for path in run("git", "diff", "--name-only", "-z", base, "HEAD").split("\0"):
            path = path.strip()
            if path:
                paths.add(path)
    return paths, base


def file_text_now(rel):
    path = root / rel
    try:
        return path.read_text() if path.is_file() else ""
    except Exception:
        return ""


def catalog_values(text):
    try:
        data = json.loads(text)
    except Exception:
        return None
    values = {}
    strings = data.get("strings") or {}
    for key, entry in strings.items():
        try:
            values[key] = entry["localizations"]["en"]["stringUnit"]["value"]
        except Exception:
            values[key] = json.dumps(entry, sort_keys=True)
    return values


def changed_keys(old_text, new_text):
    old = catalog_values(old_text) if old_text else {}
    new = catalog_values(new_text) if new_text else {}
    if old is None or new is None:
        return None
    keys = set()
    for key in set(old) | set(new):
        if old.get(key) != new.get(key):
            keys.add(key)
    return keys


def all_features_tests():
    tests = root / "Packages" / "Features" / "Tests"
    try:
        names = sorted(p.name for p in tests.iterdir() if p.is_dir() and p.name.endswith("Tests"))
    except Exception:
        names = []
    return names or ["HeadsUpTests"]


def suites_for(features_test):
    tests_dir = root / FEATURES_TESTS / features_test
    try:
        stems = sorted(p.stem for p in tests_dir.glob("*SnapshotTests.swift"))
    except Exception:
        stems = []
    return [f"{features_test}/{stem}" for stem in stems] or [features_test]


def ds_suites():
    tests_dir = root / "Packages" / "DesignSystem" / "Tests"
    try:
        files = sorted(tests_dir.rglob("*SnapshotTests.swift"))
    except Exception:
        files = []
    suites = []
    for path in files:
        try:
            rel = path.relative_to(root)
        except ValueError:
            continue
        suites.append(f"{rel.parent.name}/{path.stem}")
    return sorted(suites) or ["DesignSystemTests"]


def owners_for_keys(keys, prefix_map, fallback):
    owners = set()
    unmapped = False
    for key in keys:
        match = ""
        for prefix in prefix_map:
            if key == prefix or key.startswith(prefix + "."):
                if len(prefix) > len(match):
                    match = prefix
        if match:
            owners.update(prefix_map[match])
        else:
            unmapped = True
    if unmapped or not owners:
        owners.update(fallback)
    return owners


changed, base = changed_paths()

copy_sources = []  # (path, kind): kind in {"module-l10n", "catalog"}
baselines_by_owner = {}  # owner label -> [paths]

for path in sorted(changed):
    if "__Snapshots__/" in path:
        if path.startswith(FEATURES_TESTS):
            rest = path[len(FEATURES_TESTS):]
            owner = "Features/" + rest.split("/", 1)[0]
            baselines_by_owner.setdefault(owner, []).append(path)
        elif path.startswith(DS_TESTS):
            baselines_by_owner.setdefault("DesignSystem", []).append(path)
        continue
    is_module_l10n = (
        path.startswith("Packages/Features/Sources/")
        and path.endswith("L10n.swift")
        and "/FeatureLocalization/" not in path
    )
    is_catalog = path.endswith(".xcstrings") and (
        path.startswith("Packages/Features/")
        or path.startswith("Packages/DesignSystem/")
        or path.startswith("App/Resources/")
    )
    is_ds_l10n = path.startswith("Packages/DesignSystem/") and path.endswith("L10n.swift")
    is_app_l10n = path == "App/AppL10n.swift"
    is_shared_swift = path.startswith("Packages/Features/Sources/FeatureLocalization/") and path.endswith(".swift")
    if is_module_l10n or is_ds_l10n or is_app_l10n or is_shared_swift:
        copy_sources.append((path, "swift"))
    elif is_catalog:
        copy_sources.append((path, "catalog"))

# owner label -> {"suites": [...], "record": str, "sources": [...]}
owners = {}


def ensure_features_owner(test_dir):
    label = f"Features/{test_dir}"
    if label not in owners:
        owners[label] = {
            "suites": suites_for(test_dir),
            "record": f"scripts/record-snapshots.sh --confirm Features {suites_for(test_dir)[0].split('/')[-1]}",
            "sources": [],
        }
    return label


def ensure_ds_owner():
    if "DesignSystem" not in owners:
        suites = ds_suites()
        owners["DesignSystem"] = {
            "suites": suites,
            "record": f"scripts/record-snapshots.sh --confirm DesignSystem {suites[0].split('/')[-1]}",
            "sources": [],
        }
    return "DesignSystem"


head_rev = "HEAD"
for path, kind in copy_sources:
    if path.startswith("Packages/Features/Sources/") and kind == "swift":
        module = path[len("Packages/Features/Sources/"):].split("/", 1)[0]
        if module == "FeatureLocalization":
            for test_dir in all_features_tests():
                owners[ensure_features_owner(test_dir)]["sources"].append(path)
        else:
            owners[ensure_features_owner(f"{module}Tests")]["sources"].append(path)
    elif path.startswith("Packages/Features/Sources/") and kind == "catalog":
        module = path[len("Packages/Features/Sources/"):].split("/", 1)[0]
        if module == "FeatureLocalization":
            keys = changed_keys(run("git", "show", f"{head_rev}:{path}"), file_text_now(path))
            if base:
                base_keys = changed_keys(run("git", "show", f"{base}:{path}"), run("git", "show", f"{head_rev}:{path}"))
                if keys is not None and base_keys is not None:
                    keys = keys | base_keys
                elif base_keys is not None:
                    keys = base_keys
            if keys is None:
                targets = all_features_tests()
            elif not keys:
                continue
            else:
                targets = sorted(owners_for_keys(keys, PREFIX_TO_TESTS, all_features_tests()))
            for test_dir in targets:
                owners[ensure_features_owner(test_dir)]["sources"].append(path)
        else:
            owners[ensure_features_owner(f"{module}Tests")]["sources"].append(path)
    elif path.startswith("Packages/DesignSystem/"):
        owners[ensure_ds_owner()]["sources"].append(path)
    elif path.startswith("App/"):
        if kind == "catalog":
            keys = changed_keys(run("git", "show", f"{head_rev}:{path}"), file_text_now(path))
            if base:
                base_keys = changed_keys(run("git", "show", f"{base}:{path}"), run("git", "show", f"{head_rev}:{path}"))
                if keys is not None and base_keys is not None:
                    keys = keys | base_keys
                elif base_keys is not None:
                    keys = base_keys
            if keys is None:
                targets = all_features_tests()
            elif not keys:
                continue
            else:
                targets = sorted(owners_for_keys(keys, APP_PREFIX_TO_TESTS, all_features_tests()))
            for test_dir in targets:
                owners[ensure_features_owner(test_dir)]["sources"].append(path)
        else:
            for test_dir in all_features_tests():
                owners[ensure_features_owner(test_dir)]["sources"].append(path)

reminders = []
for label in sorted(owners):
    if label in baselines_by_owner:
        continue
    info = owners[label]
    reminders.append((label, info))

if not reminders:
    print("check-copy-baselines: OK")
    sys.exit(0)

print("check-copy-baselines: REMINDER - copy sources changed without a baseline update:")
for label, info in reminders:
    for source in sorted(set(info["sources"])):
        print(f"  {source}")
    print(f"    owning suites: {', '.join(sorted(set(info['suites'])))}")
    print(f"    after inspecting the render: {info['record']}")
print("Inspect the rendered change before replacing a committed baseline; this check never records.")
PY
