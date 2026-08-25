#!/bin/bash -p
# Mechanical Preview/SnapshotSupport coverage law. Runs inside scripts/lint.sh.
#
#  1. Any file declaring a `struct ...: View` (App/, Features, DesignSystem
#     sources) must contain a #Preview — Previews are the visual spec.
#  2. Every Features target with public views must have SnapshotSupport tests,
#     so high-value declared #Preview states are executable in rung 2.
#
# If a view genuinely cannot be previewed (rare), exempt the file with a
# `// preview-exempt: <reason>` comment — the reason is the review artifact.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

/usr/bin/python3 -I - "$ROOT" <<'PY'
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
violations = []

view_decl = re.compile(r"\bstruct\s+(\w+)\s*:\s*[^={\n]*\bView\b")
public_view_decl = re.compile(r"\bpublic\s+struct\s+(\w+)\s*:\s*[^={\n]*\bView\b")
snapshot_assertion = re.compile(r"\bassert(?:Screen|DynamicType)Snapshot\s*\(")

source_dirs = [root / "App"]
source_dirs += sorted((root / "Packages" / "Features" / "Sources").glob("*"))
source_dirs += sorted((root / "Packages" / "DesignSystem" / "Sources").glob("*"))

# Rule 1: view file => #Preview present.
for directory in source_dirs:
    for file in sorted(directory.rglob("*.swift")):
        text = file.read_text()
        if "preview-exempt:" in text:
            continue
        if view_decl.search(text) and "#Preview" not in text:
            rel = file.relative_to(root)
            violations.append(f"{rel}: declares a View but has no #Preview")

# Rule 2: public Features views => module is covered by SnapshotSupport tests.
features = root / "Packages" / "Features"
for target_dir in sorted((features / "Sources").glob("*")):
    if target_dir.name == "FeatureLocalization":
        continue
    names = []
    for file in sorted(target_dir.rglob("*.swift")):
        names += public_view_decl.findall(file.read_text())
    if not names:
        continue
    tests_dir = features / "Tests" / f"{target_dir.name}Tests"
    snapshot_text = "".join(
        f.read_text() for f in sorted(tests_dir.glob("*.swift"))
    ) if tests_dir.exists() else ""
    if not snapshot_text:
        violations.append(
            f"Packages/Features/Sources/{target_dir.name}: missing "
            f"Tests/{target_dir.name}Tests coverage"
        )
        continue
    if "SnapshotSupport" not in snapshot_text or "assertScreenSnapshot" not in snapshot_text:
        violations.append(
            f"Packages/Features/Tests/{target_dir.name}Tests: must include "
            f"SnapshotSupport screen coverage for {target_dir.name}"
        )

# Rule 3: every record-mode-capable assertion lives in a mechanically named
# SnapshotTests file/suite, which is the exact scope shown by the human recorder.
for package in ("Features", "DesignSystem"):
    tests_root = root / "Packages" / package / "Tests"
    for file in sorted(tests_root.rglob("*.swift")):
        text = file.read_text()
        if not snapshot_assertion.search(text):
            continue
        if not file.name.endswith("SnapshotTests.swift"):
            violations.append(f"{file.relative_to(root)}: snapshot assertions require a *SnapshotTests.swift file")
        if not re.search(r"\bstruct\s+\w*SnapshotTests\b", text):
            violations.append(f"{file.relative_to(root)}: snapshot assertions require a *SnapshotTests suite")

if violations:
    print("Preview/snapshot coverage violations:")
    for violation in violations:
        print(f"  {violation}")
    sys.exit(1)
print(f"check-previews: OK ({len(source_dirs)} source dirs)")
PY
