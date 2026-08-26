#!/bin/bash -p
# Validate motion asset manifests and catch runtime assets without metadata.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

/usr/bin/python3 -I - "$ROOT" <<'PY'
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

root = Path(sys.argv[1])
violations: list[str] = []
warnings: list[str] = []

ignored_parts = {".build", "artifacts", "__Snapshots__", ".git"}
manifest_paths = [
    path for path in root.rglob("*.motion.json")
    if not ignored_parts.intersection(path.relative_to(root).parts)
]

required_top = {
    "id",
    "kind",
    "intent",
    "status",
    "files",
    "playback",
    "layout",
    "accessibility",
    "provenance",
    "verification",
}

manifest_text = ""
for path in manifest_paths:
    rel = path.relative_to(root)
    try:
        data = json.loads(path.read_text())
    except Exception as exc:
        violations.append(f"{rel}: invalid JSON ({exc})")
        continue

    missing = sorted(required_top - set(data))
    if missing:
        violations.append(f"{rel}: missing required keys: {', '.join(missing)}")

    manifest_text += json.dumps(data)
    status = str(data.get("status", "")).lower()
    kind = str(data.get("kind", ""))
    files = data.get("files", {}) if isinstance(data.get("files"), dict) else {}
    playback = data.get("playback", {}) if isinstance(data.get("playback"), dict) else {}
    accessibility = data.get("accessibility", {}) if isinstance(data.get("accessibility"), dict) else {}
    provenance = data.get("provenance", {}) if isinstance(data.get("provenance"), dict) else {}

    for field, value in files.items():
        if not isinstance(value, str) or not value:
            continue
        if value.startswith(("http://", "https://")):
            violations.append(f"{rel}: files.{field} must be local, not remote: {value}")
            continue
        candidate = (path.parent / value).resolve()
        root_candidate = (root / value).resolve()
        if status != "placeholder" and not candidate.exists() and not root_candidate.exists():
            violations.append(f"{rel}: files.{field} does not exist: {value}")

    if status != "placeholder":
        if not files.get("fallbackStatic"):
            violations.append(f"{rel}: production motion needs files.fallbackStatic")
        if not playback.get("reducedMotion"):
            violations.append(f"{rel}: production motion needs playback.reducedMotion")
        if not accessibility.get("reduceMotionBehavior"):
            violations.append(f"{rel}: production motion needs accessibility.reduceMotionBehavior")
        if not provenance.get("license"):
            violations.append(f"{rel}: production motion needs provenance.license")

    if kind in {"rive", "lottie", "dotLottie", "spriteSheet", "rasterFrames"}:
        if status == "placeholder":
            warnings.append(f"{rel}: {kind} manifest is still a placeholder")
        if not data.get("verification", {}).get("previewStates"):
            violations.append(f"{rel}: {kind} needs verification.previewStates")

asset_exts = {".riv", ".lottie", ".gif", ".mp4", ".mov"}
json_asset_names = {".json"}
asset_paths: list[Path] = []
for base in [root / "App", root / "Packages"]:
    if not base.exists():
        continue
    for path in base.rglob("*"):
        if not path.is_file():
            continue
        rel_parts = path.relative_to(root).parts
        if ignored_parts.intersection(rel_parts):
            continue
        suffix = path.suffix
        if suffix in asset_exts:
            asset_paths.append(path)
        elif suffix in json_asset_names and not path.name.endswith(".motion.json"):
            relative = path.relative_to(root).as_posix()
            non_asset_json = {
                "Package.resolved",
                "Contents.json",
            }
            if path.name not in non_asset_json and relative not in non_asset_json and ".xcassets" not in rel_parts:
                asset_paths.append(path)

for path in asset_paths:
    rel = path.relative_to(root)
    if str(rel) not in manifest_text and path.name not in manifest_text:
        violations.append(f"{rel}: motion/runtime asset has no .motion.json manifest reference")
    size = path.stat().st_size
    if size > 1_500_000:
        warnings.append(f"{rel}: compressed size is {size} bytes; consider perf proof")

for base in [root / "App", root / "Packages"]:
    if not base.exists():
        continue
    for directory, _dirs, files in os.walk(base):
        dir_path = Path(directory)
        rel_parts = dir_path.relative_to(root).parts
        if ignored_parts.intersection(rel_parts):
            continue
        pngs = [name for name in files if name.lower().endswith(".png")]
        if len(pngs) >= 12 and "snapshot" not in str(dir_path).lower():
            warnings.append(
                f"{dir_path.relative_to(root)}: {len(pngs)} PNGs may be a frame sequence; add .motion.json if animated"
            )

for warning in warnings:
    print(f"motion-assets warning: {warning}")

if violations:
    print("Motion asset violations:")
    for violation in violations:
        print(f"  {violation}")
    sys.exit(1)

print(f"check-motion-assets: OK ({len(manifest_paths)} manifests, {len(asset_paths)} runtime assets)")
PY
