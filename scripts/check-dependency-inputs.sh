#!/bin/bash -p
# Verify every dependency, build-system, and tool configuration input before tools run.
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"
MANIFEST="$ROOT/scripts/dependency-inputs.sha256"

MODE=check
if [[ "$#" -gt 0 && "$1" == "--write" ]]; then
  MODE=write
  shift
elif [[ "$#" -ne 0 ]]; then
  echo "usage: scripts/check-dependency-inputs.sh [--write [relative-path ...]]" >&2
  exit 2
fi

/usr/bin/python3 -I - "$ROOT" "$MANIFEST" "$MODE" "$@" <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import pathlib
import re
import stat
import sys
import tempfile
import xml.etree.ElementTree as ET

root = pathlib.Path(sys.argv[1])
manifest_path = pathlib.Path(sys.argv[2])
mode = sys.argv[3]
refresh_paths = set(sys.argv[4:])
current_uid = os.getuid()
violations: list[str] = []
contents: dict[str, bytes] = {}

MAX_INPUT_BYTES = 2 * 1024 * 1024
EXCLUDED_DIRECTORY_NAMES = {
    ".build",
    ".git",
    "DerivedData",
    "artifacts",
    "node_modules",
    "xcuserdata",
}
ROOT_INPUTS = {".gitignore", ".swiftformat", ".swiftlint.yml", "mise.lock", "mise.toml"}
NPM_INPUT_NAMES = {
    ".npmrc",
    "npm-shrinkwrap.json",
    "package-lock.json",
    "package.json",
    "pnpm-lock.yaml",
    "yarn.lock",
}
SWIFTPM_INPUT_NAMES = {"Package.pins", "Package.resolved", "Package.swift"}
REVIEWED_REMOTE_PACKAGES = {
    "https://github.com/pointfreeco/swift-custom-dump",
    "https://github.com/pointfreeco/swift-snapshot-testing",
    "https://github.com/pointfreeco/xctest-dynamic-overlay",
    "https://github.com/swiftlang/swift-syntax",
}
REVIEWED_REMOTE_MANIFESTS = {
    "Packages/TestSupport/Package.swift",
    "Tools/ObservablePreviewWiring/Package.swift",
}
GENERATED_SWIFTPM_CACHE_ROOTS = {
    "Packages/DesignSystem/.swiftpm",
    "Packages/Domain/.swiftpm",
    "Packages/Features/.swiftpm",
    "Packages/TestSupport/.swiftpm",
}


def report(message: str) -> None:
    violations.append(message)


def relative_path(path: pathlib.Path) -> str:
    return path.relative_to(root).as_posix()


def is_excluded(relative: str) -> bool:
    parts = pathlib.PurePosixPath(relative).parts
    return any(part in EXCLUDED_DIRECTORY_NAMES or part.endswith(".xcresult") for part in parts)


def is_mise_input(relative: str) -> bool:
    path = pathlib.PurePosixPath(relative)
    name = path.name
    return (
        name == ".tool-versions"
        or name in {".mise", "mise", "mise-tasks"}
        or re.fullmatch(r"\.?(?:mise|rtx)(?:\.[^/]+)*\.toml", name) is not None
        or re.fullmatch(r"\.?mise(?:\.[^/]+)*\.lock", name) is not None
        or any(part in {".mise", "mise", "mise-tasks"} for part in path.parts[:-1])
        or tuple(path.parts[:2]) == (".config", "mise")
    )


def is_xcode_container(relative: str) -> bool:
    return any(
        part.endswith(".xcodeproj") or part.endswith(".xcworkspace")
        for part in pathlib.PurePosixPath(relative).parts[:-1]
    )


def is_reviewed_input(relative: str) -> bool:
    path = pathlib.PurePosixPath(relative)
    return (
        relative in ROOT_INPUTS
        or path.name in SWIFTPM_INPUT_NAMES
        or path.name in NPM_INPUT_NAMES
        or is_mise_input(relative)
        or is_xcode_container(relative)
        or path.suffix in {".xcconfig", ".xctestplan"}
    )


def inspect_xcode_user_data(path: pathlib.Path, relative: str) -> None:
    try:
        metadata = path.lstat()
    except OSError as error:
        report(f"{relative}: Xcode user data could not be inspected: {error}")
        return
    if stat.S_ISLNK(metadata.st_mode):
        report(f"{relative}: Xcode user data may not be a symbolic link")
        return
    if not stat.S_ISDIR(metadata.st_mode):
        report(f"{relative}: Xcode user data must be a directory")
        return

    def user_data_error(error: OSError) -> None:
        report(f"{relative}: Xcode user data traversal failed closed: {error}")

    executable_suffixes = {".xcconfig", ".xcscheme", ".xctestplan"}
    inspected_entries = 0
    for current, directories, files in os.walk(
        path, topdown=True, followlinks=False, onerror=user_data_error
    ):
        current_path = pathlib.Path(current)
        inspected_entries += len(directories) + len(files)
        if inspected_entries > 10000:
            report(f"{relative}: Xcode user data exceeds its fixed entry ceiling")
            directories[:] = []
            break
        retained: list[str] = []
        for name in directories:
            candidate = current_path / name
            candidate_relative = relative_path(candidate)
            try:
                candidate_metadata = candidate.lstat()
            except OSError as error:
                report(f"{candidate_relative}: Xcode user data entry could not be inspected: {error}")
                continue
            if stat.S_ISLNK(candidate_metadata.st_mode):
                report(f"{candidate_relative}: Xcode user data may not contain symbolic links")
                continue
            retained.append(name)
        directories[:] = retained
        for name in files:
            candidate = current_path / name
            candidate_relative = relative_path(candidate)
            try:
                candidate_metadata = candidate.lstat()
            except OSError as error:
                report(f"{candidate_relative}: Xcode user data entry could not be inspected: {error}")
                continue
            if stat.S_ISLNK(candidate_metadata.st_mode):
                report(f"{candidate_relative}: Xcode user data may not contain symbolic links")
            elif candidate.suffix in executable_suffixes:
                report(f"{candidate_relative}: executable Xcode user build inputs are forbidden")


def inspect_generated_swiftpm_cache(path: pathlib.Path, relative: str) -> None:
    try:
        metadata = path.lstat()
    except OSError as error:
        report(f"{relative}: generated SwiftPM cache could not be inspected: {error}")
        return
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or stat.S_ISLNK(metadata.st_mode)
        or metadata.st_uid != current_uid
    ):
        report(f"{relative}: generated SwiftPM cache must be an owner-controlled directory")
        return
    try:
        entries = tuple(path.iterdir())
    except OSError as error:
        report(f"{relative}: generated SwiftPM cache traversal failed closed: {error}")
        return
    for entry in entries:
        entry_relative = relative_path(entry)
        try:
            entry_metadata = entry.lstat()
        except OSError as error:
            report(f"{entry_relative}: generated SwiftPM cache entry could not be inspected: {error}")
            continue
        if (
            entry.name != "xcode"
            or not stat.S_ISDIR(entry_metadata.st_mode)
            or stat.S_ISLNK(entry_metadata.st_mode)
            or entry_metadata.st_uid != current_uid
        ):
            report(f"{entry_relative}: generated SwiftPM cache contains an unreviewed entry")
            continue
        try:
            nested_entries = tuple(entry.iterdir())
        except OSError as error:
            report(f"{entry_relative}: generated SwiftPM cache traversal failed closed: {error}")
            continue
        for nested in nested_entries:
            report(f"{relative_path(nested)}: generated SwiftPM cache contains an unreviewed entry")


try:
    root_metadata = root.lstat()
except OSError as error:
    raise SystemExit(f"dependency input violation: repository root is unavailable: {error}")
if (
    not stat.S_ISDIR(root_metadata.st_mode)
    or root.is_symlink()
    or root_metadata.st_uid != current_uid
    or root_metadata.st_mode & 0o022
):
    report("repository root has unsafe ownership, mode, or path type")


def traversal_error(error: OSError) -> None:
    report(f"repository dependency-input traversal failed closed: {error}")


discovered: set[str] = set()
for current, directories, files in os.walk(
    root, topdown=True, followlinks=False, onerror=traversal_error
):
    current_path = pathlib.Path(current)
    retained: list[str] = []
    for name in directories:
        candidate = current_path / name
        relative = relative_path(candidate)
        if name == ".swiftpm":
            if relative in GENERATED_SWIFTPM_CACHE_ROOTS:
                inspect_generated_swiftpm_cache(candidate, relative)
            else:
                report(f"{relative}: SwiftPM state directories are forbidden")
            continue
        if name == "xcuserdata":
            inspect_xcode_user_data(candidate, relative)
        if is_excluded(relative):
            continue
        try:
            metadata = candidate.lstat()
        except OSError as error:
            report(f"{relative}: dependency input directory could not be inspected: {error}")
            continue
        if name == "Plugins":
            report(f"{relative}: SwiftPM Plugins directories are forbidden")
        if is_mise_input(relative) and relative not in {"mise.lock", "mise.toml"}:
            report(f"{relative}: unreviewed mise configuration input exists")
        if stat.S_ISLNK(metadata.st_mode):
            if name in {".swiftpm", "Plugins"} or name.endswith((".xcodeproj", ".xcworkspace")) or is_mise_input(relative):
                report(f"{relative}: dependency input directory may not be a symbolic link")
            continue
        retained.append(name)
    directories[:] = retained

    for name in files:
        candidate = current_path / name
        relative = relative_path(candidate)
        if is_excluded(relative):
            continue
        if ".swiftpm" in pathlib.PurePosixPath(relative).parts:
            report(f"{relative}: files in SwiftPM state directories are forbidden")
        if relative in {"Packages/Factory/Package.pins", "Packages/Factory/Package.resolved"}:
            report(f"{relative}: Factory dependency resolution inputs are forbidden")
        if re.fullmatch(r"Package@swift-.*\.swift", name):
            report(f"{relative}: alternate SwiftPM manifest is forbidden")
        if is_mise_input(relative) and relative not in {"mise.lock", "mise.toml"}:
            report(f"{relative}: unreviewed mise configuration input exists")
        if is_reviewed_input(relative):
            discovered.add(relative)


def validate_ancestors(relative: str) -> bool:
    cursor = root
    for component in pathlib.PurePosixPath(relative).parts[:-1]:
        cursor /= component
        try:
            metadata = cursor.lstat()
        except OSError:
            report(f"{relative}: dependency input ancestor is missing")
            return False
        if (
            not stat.S_ISDIR(metadata.st_mode)
            or stat.S_ISLNK(metadata.st_mode)
            or metadata.st_uid != current_uid
            or metadata.st_mode & 0o022
        ):
            report(f"{relative}: dependency input ancestor is unsafe")
            return False
    return True


def read_input(relative: str) -> None:
    if not validate_ancestors(relative):
        return
    path = root / relative
    flags = os.O_RDONLY | os.O_CLOEXEC
    if hasattr(os, "O_NOFOLLOW"):
        flags |= os.O_NOFOLLOW
    try:
        descriptor = os.open(path, flags)
    except OSError:
        report(f"{relative}: reviewed dependency input is missing or unsafe")
        return
    try:
        before = os.fstat(descriptor)
        if (
            not stat.S_ISREG(before.st_mode)
            or before.st_nlink != 1
            or before.st_uid != current_uid
            or before.st_mode & 0o022
            or before.st_size > MAX_INPUT_BYTES
        ):
            report(f"{relative}: reviewed dependency input is not a bounded private regular file")
            return
        chunks: list[bytes] = []
        remaining = before.st_size
        while remaining:
            chunk = os.read(descriptor, min(remaining, 64 * 1024))
            if not chunk:
                report(f"{relative}: reviewed dependency input changed during verification")
                return
            chunks.append(chunk)
            remaining -= len(chunk)
        if os.read(descriptor, 1):
            report(f"{relative}: reviewed dependency input grew during verification")
            return
        after = os.fstat(descriptor)
        if (
            before.st_dev,
            before.st_ino,
            before.st_size,
            before.st_mtime_ns,
            before.st_ctime_ns,
        ) != (
            after.st_dev,
            after.st_ino,
            after.st_size,
            after.st_mtime_ns,
            after.st_ctime_ns,
        ):
            report(f"{relative}: reviewed dependency input changed during verification")
            return
        contents[relative] = b"".join(chunks)
    finally:
        os.close(descriptor)


for relative in sorted(discovered):
    read_input(relative)


def decoded(relative: str) -> str:
    try:
        return contents[relative].decode("utf-8")
    except UnicodeDecodeError:
        report(f"{relative}: dependency input must be UTF-8")
        return ""


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).name == "Package.swift"):
    text = decoded(relative)
    forbidden_forms = (
        (r"\.\s*plugin\s*\(", "SwiftPM build-tool plugins are forbidden"),
        (r"\.\s*macro\s*\(", "SwiftPM macros are forbidden"),
        (r"\.\s*binaryTarget\s*\(", "SwiftPM binary targets are forbidden"),
        (r"\.\s*unsafeFlags\s*\(", "SwiftPM unsafe compiler or linker flags are forbidden"),
    )
    for pattern, message in forbidden_forms:
        if re.search(pattern, text):
            report(f"{relative}: {message}")
    imports = set(re.findall(r"(?m)^\s*import\s+([A-Za-z_][A-Za-z0-9_]*)\b", text))
    if imports - {"PackageDescription"}:
        report(f"{relative}: SwiftPM manifests may import only PackageDescription")
    if re.search(r"\b(?:CommandLine|FileManager|Process|dlopen|getenv|popen|system)\b|@_silgen_name", text):
        report(f"{relative}: executable SwiftPM manifest APIs are forbidden")
    remote_declarations = re.findall(r"\.\s*package\s*\(\s*url\s*:\s*\"([^\"]+)\"", text)
    for location in remote_declarations:
        if relative not in REVIEWED_REMOTE_MANIFESTS or location not in REVIEWED_REMOTE_PACKAGES:
            report(f"{relative}: unreviewed remote SwiftPM dependency declaration")
    if relative == "Packages/Factory/Package.swift" and re.search(r"\.\s*package\s*\(", text):
        report(f"{relative}: Factory must remain dependency-free")


def collect_locations(value: object) -> list[str]:
    locations: list[str] = []
    if isinstance(value, dict):
        for key, child in value.items():
            if key in {"location", "repositoryURL"} and isinstance(child, str):
                locations.append(child)
            locations.extend(collect_locations(child))
    elif isinstance(value, list):
        for child in value:
            locations.extend(collect_locations(child))
    return locations


for relative in sorted(
    path for path in contents if pathlib.PurePosixPath(path).name in {"Package.resolved", "Package.pins"}
):
    try:
        payload = json.loads(decoded(relative))
    except ValueError as error:
        report(f"{relative}: invalid SwiftPM resolution JSON: {error}")
        continue
    for location in collect_locations(payload):
        if location not in REVIEWED_REMOTE_PACKAGES:
            report(f"{relative}: unreviewed resolved SwiftPM location: {location}")
    if pathlib.PurePosixPath(relative).name == "Package.resolved":
        pins = payload.get("pins") if isinstance(payload, dict) else None
        if not isinstance(pins, list):
            report(f"{relative}: Package.resolved must contain a pins array")
            continue
        for pin in pins:
            state = pin.get("state") if isinstance(pin, dict) else None
            revision = state.get("revision") if isinstance(state, dict) else None
            if not isinstance(revision, str) or re.fullmatch(r"[0-9a-f]{40}", revision) is None:
                report(f"{relative}: every resolved SwiftPM pin needs a full revision")


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).suffix == ".pbxproj"):
    text = decoded(relative)
    if "PBXShellScriptBuildPhase" in text or re.search(r"(?m)^\s*shellScript\s*=", text):
        report(f"{relative}: Xcode shell build phases are forbidden")
    if "XCRemoteSwiftPackageReference" in text:
        report(f"{relative}: Xcode remote package declarations are forbidden; use reviewed SwiftPM manifests")


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).suffix == ".xcscheme"):
    try:
        document = ET.fromstring(contents[relative])
    except ET.ParseError as error:
        report(f"{relative}: invalid Xcode scheme XML: {error}")
        continue
    tags = {element.tag.rsplit("}", 1)[-1] for element in document.iter()}
    if "PreActions" in tags:
        report(f"{relative}: Xcode scheme pre-actions are forbidden")
    if "PostActions" in tags:
        report(f"{relative}: Xcode scheme post-actions are forbidden")
    if "ExecutionAction" in tags:
        report(f"{relative}: Xcode scheme execution actions are forbidden")


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).suffix == ".xcconfig"):
    text = decoded(relative)
    if re.search(r"(?mi)^\s*#\s*include\??\b", text):
        report(f"{relative}: xcconfig includes are forbidden")
    if re.search(
        r"(?mi)^\s*(?:CC|CPLUSPLUS|LD|LDPLUSPLUS|LIBTOOL|SWIFT_EXEC|OTHER_(?:CFLAGS|CPLUSPLUSFLAGS|LDFLAGS|SWIFT_FLAGS))\s*=",
        text,
    ):
        report(f"{relative}: xcconfig executable or unsafe flag overrides are forbidden")


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).suffix == ".xctestplan"):
    report(f"{relative}: xctestplan inputs require explicit reviewed support")


for relative in sorted(path for path in contents if pathlib.PurePosixPath(path).name == "package.json"):
    try:
        payload = json.loads(decoded(relative))
    except ValueError as error:
        report(f"{relative}: invalid npm package JSON: {error}")
        continue
    if relative != "Tools/XcodeBuildMCP/package.json":
        report(f"{relative}: unreviewed npm package manifest location")
    if payload.get("scripts"):
        report(f"{relative}: npm lifecycle scripts are forbidden")


for relative in sorted(
    path for path in contents if pathlib.PurePosixPath(path).name in {"package-lock.json", "npm-shrinkwrap.json"}
):
    try:
        payload = json.loads(decoded(relative))
    except ValueError as error:
        report(f"{relative}: invalid npm lock JSON: {error}")
        continue
    packages = payload.get("packages") if isinstance(payload, dict) else None
    if not isinstance(packages, dict):
        report(f"{relative}: npm lock must contain a packages object")
        continue
    if any(isinstance(package, dict) and package.get("hasInstallScript") for package in packages.values()):
        report(f"{relative}: npm install scripts are forbidden")


reviewed: dict[str, str] = {}
if mode == "check" or refresh_paths:
    try:
        manifest_metadata = manifest_path.lstat()
        manifest_text = manifest_path.read_text()
    except OSError:
        report("scripts/dependency-inputs.sha256: reviewed dependency manifest is missing or unsafe")
    else:
        if (
            not stat.S_ISREG(manifest_metadata.st_mode)
            or manifest_metadata.st_nlink != 1
            or manifest_metadata.st_uid != current_uid
            or manifest_metadata.st_mode & 0o022
            or manifest_metadata.st_size > MAX_INPUT_BYTES
        ):
            report("scripts/dependency-inputs.sha256: reviewed dependency manifest is not a bounded private regular file")
        previous = ""
        for line_number, line in enumerate(manifest_text.splitlines(), start=1):
            match = re.fullmatch(r"([0-9a-f]{64})  ([^\0\r\n]+)", line)
            if match is None:
                report(f"scripts/dependency-inputs.sha256:{line_number}: malformed manifest entry")
                continue
            digest, relative = match.groups()
            if relative <= previous:
                report("scripts/dependency-inputs.sha256: entries must be unique and sorted")
            previous = relative
            reviewed[relative] = digest
        missing = sorted(discovered - reviewed.keys())
        stale = sorted(reviewed.keys() - discovered)
        for relative in missing:
            report(f"{relative}: unreviewed dependency input exists")
        for relative in stale:
            report(f"{relative}: reviewed dependency input is missing")
        for relative in sorted(discovered & reviewed.keys()):
            content = contents.get(relative)
            if (
                content is not None
                and hashlib.sha256(content).hexdigest() != reviewed[relative]
                and not (mode == "write" and relative in refresh_paths)
            ):
                report(f"{relative}: reviewed dependency input digest changed")

for relative in sorted(refresh_paths):
    candidate = pathlib.PurePosixPath(relative)
    if (
        not relative
        or candidate.is_absolute()
        or str(candidate) != relative
        or any(part in {"", ".", ".."} for part in candidate.parts)
    ):
        report(f"{relative}: refresh path must be a normalized repository-relative input")
    elif relative not in discovered:
        report(f"{relative}: refresh path is not a discovered dependency input")


if violations:
    for violation in violations:
        print(f"dependency input violation: {violation}", file=sys.stderr)
    raise SystemExit(1)

if mode == "write":
    if refresh_paths:
        output_digests = dict(reviewed)
        for path in refresh_paths:
            output_digests[path] = hashlib.sha256(contents[path]).hexdigest()
    else:
        output_digests = {path: hashlib.sha256(contents[path]).hexdigest() for path in discovered}
    lines = [f"{output_digests[path]}  {path}\n" for path in sorted(output_digests)]
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=manifest_path.parent, delete=False) as temporary:
        temporary.writelines(lines)
        temporary.flush()
        os.fsync(temporary.fileno())
        temporary_path = pathlib.Path(temporary.name)
    os.chmod(temporary_path, 0o644)
    os.replace(temporary_path, manifest_path)
PY

if [[ "$MODE" == write ]]; then
  echo "check-dependency-inputs: refreshed scripts/dependency-inputs.sha256"
else
  echo "check-dependency-inputs: OK"
fi
