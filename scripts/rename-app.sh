#!/bin/bash -p
# Turn the template into a real app (run once after cloning).
# Usage: scripts/rename-app.sh "My App Name" com.yourname.myapp
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NAME="${1:?display name, e.g. \"My App\"}"
BUNDLE="${2:?bundle identifier, e.g. com.yourname.myapp}"

PBXPROJ="$ROOT/App.xcodeproj/project.pbxproj"

"$ROOT/scripts/check-dependency-inputs.sh"

/usr/bin/python3 -I - "$ROOT" "$PBXPROJ" "$NAME" "$BUNDLE" <<'PY'
import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

root = pathlib.Path(sys.argv[1])
path = pathlib.Path(sys.argv[2])
name = sys.argv[3]
bundle = sys.argv[4]

if not name or any(ord(character) < 32 or ord(character) == 127 for character in name):
    raise SystemExit("display name must be nonempty and contain no control characters")
if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9-]*(\.[A-Za-z0-9][A-Za-z0-9-]*)+", bundle):
    raise SystemExit("bundle identifier must use reverse-DNS segments with letters, numbers, or hyphens")

catalog_specs = [
    ("App/Resources/Localizable.xcstrings", "app.name"),
    ("App/Resources/InfoPlist.xcstrings", "CFBundleDisplayName"),
]
catalogs = []
for relative, key in catalog_specs:
    catalog_path = root / relative
    if not catalog_path.exists():
        raise SystemExit(f"required string catalog is missing: {relative}")
    catalog = json.loads(catalog_path.read_text())
    catalog.setdefault("strings", {}).setdefault(key, {}).setdefault(
        "localizations",
        {},
    ).setdefault(
        "en",
        {},
    )["stringUnit"] = {
        "state": "translated",
        "value": name,
    }
    catalogs.append((catalog_path, json.dumps(catalog, indent=2, sort_keys=True) + "\n", relative, key))

result = subprocess.run(
    ["plutil", "-convert", "json", "-o", "-", str(path)],
    check=True,
    capture_output=True,
    text=True,
)
objects = json.loads(result.stdout)["objects"]

def target_named(target_name):
    matches = [
        value for value in objects.values()
        if value.get("isa") == "PBXNativeTarget" and value.get("name") == target_name
    ]
    if len(matches) != 1:
        raise SystemExit(f"expected one {target_name} target, found {len(matches)}")
    return matches[0]

def configuration_ids(target):
    configuration_list = objects[target["buildConfigurationList"]]
    return configuration_list["buildConfigurations"]

def replace_configuration(source, config_id, target_bundle, display_name=None):
    pattern = re.compile(rf"(?ms)^\t\t{re.escape(config_id)} /\*.*?^\t\t\}};")
    match = pattern.search(source)
    if not match:
        raise SystemExit(f"build configuration block not found: {config_id}")
    block = match.group(0)
    block, bundle_count = re.subn(
        r"(?m)^(\s*PRODUCT_BUNDLE_IDENTIFIER = )[^;]+;",
        rf"\g<1>{target_bundle};",
        block,
    )
    if bundle_count != 1:
        raise SystemExit(f"expected one bundle identifier in {config_id}, found {bundle_count}")
    if display_name is not None:
        escaped_name = display_name.replace("\\", "\\\\").replace('"', '\\"')
        block, display_count = re.subn(
            r"(?m)^(\s*INFOPLIST_KEY_CFBundleDisplayName = ).*?;",
            rf'\g<1>"{escaped_name}";',
            block,
        )
        if display_count != 1:
            raise SystemExit(f"expected one display name in {config_id}, found {display_count}")
    return source[: match.start()] + block + source[match.end() :]

text = path.read_text()
for config_id in configuration_ids(target_named("App")):
    text = replace_configuration(text, config_id, bundle, name)
for config_id in configuration_ids(target_named("AppTests")):
    text = replace_configuration(text, config_id, f"{bundle}Tests")

def atomic_write(destination, content):
    with tempfile.NamedTemporaryFile("w", dir=destination.parent, delete=False) as temporary:
        temporary.write(content)
        temporary_path = pathlib.Path(temporary.name)
    os.replace(temporary_path, destination)

originals = {destination: destination.read_bytes() for destination in [path, *(item[0] for item in catalogs)]}

with tempfile.NamedTemporaryFile("w", dir=path.parent, delete=False) as temporary:
    temporary.write(text)
    project_candidate = pathlib.Path(temporary.name)
try:
    subprocess.run(["plutil", "-lint", str(project_candidate)], check=True, capture_output=True)
    try:
        os.replace(project_candidate, path)
        for catalog_path, content, _relative, _key in catalogs:
            atomic_write(catalog_path, content)
    except Exception:
        for destination, content in originals.items():
            with tempfile.NamedTemporaryFile("wb", dir=destination.parent, delete=False) as temporary:
                temporary.write(content)
                temporary_path = pathlib.Path(temporary.name)
            os.replace(temporary_path, destination)
        raise
finally:
    project_candidate.unlink(missing_ok=True)

print(f"pbxproj updated: display name -> {name!r}, bundle id -> {bundle}")
for _catalog_path, _content, relative, key in catalogs:
    print(f"{relative}: {key} -> {name!r}")
PY

"$ROOT/scripts/check-dependency-inputs.sh" --write App.xcodeproj/project.pbxproj

echo "Done. The target/scheme/module stay named 'App' on purpose — scripts and"
echo "session defaults never drift. Update the one-liner in AGENTS.md and"
echo "README.md to describe your app, then commit."
