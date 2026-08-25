#!/bin/bash -p
# Build a compact review bundle from rendered preview/snapshot PNGs.
#
# Usage:
#   scripts/preview-review.sh Features "" --baselines
#   scripts/preview-review.sh Features "" artifacts/preview-exports/run-Features
#
# Agents: open the printed contact sheet with view_image and present the
# relevant image(s) to the owner. Do not hand off a raw directory hunt.
. "$(dirname "$0")/lib.sh"
secure_artifact_storage

PKG="${1:?package name (Features|DesignSystem)}"
FILTER="${2:-}"
EXPORT_DIR="${3:-}"
PACKAGE_DIR="$ROOT/Packages/$PKG"

case "$PKG" in
  Features|DesignSystem) ;;
  *) echo "package must be Features or DesignSystem: $PKG" >&2; exit 2 ;;
esac

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

SLUG="$PKG"
if [[ -n "$FILTER" ]]; then
  SLUG="$SLUG-$(slugify "$FILTER")"
fi
mkdir -p "$ARTIFACTS/preview-review"
OUT="$(mktemp -d "$ARTIFACTS/preview-review/$(timestamp)-$SLUG.XXXXXX")"
CURRENT_SOURCE_STATE="$(source_state_hash)"
CURRENT_HEAD="$(current_git_head)"
PREVIEW_RETAINED=0
PREVIEW_OUTPUT=""
cleanup_preview_review() {
  local status=$?
  trap - EXIT
  if [[ "$PREVIEW_RETAINED" -ne 1 && -d "$OUT" ]]; then
    rm -rf "$OUT"
  fi
  exit "$status"
}
trap cleanup_preview_review EXIT

PREVIEW_OUTPUT="$(/usr/bin/python3 -I - \
  "$ROOT" "$PKG" "$FILTER" "$OUT" "$EXPORT_DIR" "$CURRENT_SOURCE_STATE" "$CURRENT_HEAD" <<'PY'
from __future__ import annotations

import datetime as dt
import hashlib
import html
import json
import math
import os
import pathlib
import stat
import struct
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
pkg = sys.argv[2]
filter_arg = sys.argv[3]
out = pathlib.Path(sys.argv[4])
export_dir_arg = sys.argv[5]
current_source_state = sys.argv[6]
current_head = sys.argv[7]
package_dir = root / "Packages" / pkg
images_dir = out / "images"
baseline_mode = export_dir_arg == "--baselines"
export_dir = pathlib.Path(export_dir_arg) if export_dir_arg and not baseline_mode else None
validity = "reference" if baseline_mode else "invalid"
verification_mode = "reference"
verification_scope = "reference"
baselines_verified = False


def require_directory(path: pathlib.Path, label: str) -> None:
    try:
        metadata = os.lstat(path)
    except OSError as error:
        raise SystemExit(f"{label} is unavailable: {error}")
    if not stat.S_ISDIR(metadata.st_mode):
        raise SystemExit(f"{label} is not a real directory")


def require_regular_file(path: pathlib.Path, label: str) -> None:
    try:
        metadata = os.lstat(path)
    except OSError as error:
        raise SystemExit(f"{label} is unavailable: {error}")
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise SystemExit(f"{label} is not a single-link regular file: {path.name}")


def read_regular_file(path: pathlib.Path, label: str) -> bytes:
    try:
        descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError as error:
        raise SystemExit(f"{label} could not be opened safely: {error}")
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
            raise SystemExit(f"{label} is not a single-link regular file: {path.name}")
        with os.fdopen(descriptor, "rb") as stream:
            descriptor = -1
            return stream.read()
    finally:
        if descriptor >= 0:
            os.close(descriptor)


def create_exclusive_file(directory_descriptor: int, name: str, flags: int = os.O_WRONLY) -> int:
    if pathlib.PurePath(name).name != name:
        raise SystemExit(f"unsafe staged evidence name: {name}")
    try:
        return os.open(
            name,
            flags | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW,
            0o600,
            dir_fd=directory_descriptor,
        )
    except OSError as error:
        raise SystemExit(f"staged evidence could not be created safely: {name}: {error}")


def write_open_file(descriptor: int, content: bytes) -> None:
    view = memoryview(content)
    while view:
        written = os.write(descriptor, view)
        if written < 1:
            raise SystemExit("staged evidence write made no progress")
        view = view[written:]
    os.fsync(descriptor)


def write_exclusive_file(directory_descriptor: int, name: str, content: bytes) -> None:
    descriptor = create_exclusive_file(directory_descriptor, name)
    try:
        write_open_file(descriptor, content)
    finally:
        os.close(descriptor)


def finite_number(value: object, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise SystemExit(f"fresh export has invalid {field}")
    number = float(value)
    if not math.isfinite(number) or number <= 0:
        raise SystemExit(f"fresh export has invalid {field}")
    return number

if not export_dir and not baseline_mode:
    raise SystemExit("preview review requires a fresh SnapshotSupport export directory or explicit --baselines")
if baseline_mode and filter_arg:
    raise SystemExit("filtered baseline review is ambiguous; use an unfiltered --baselines review")
if export_dir:
    export_root = (root / "artifacts" / "preview-exports").resolve()
    require_directory(export_dir, "fresh export")
    export_dir = export_dir.resolve()
    if export_root not in export_dir.parents:
        raise SystemExit(f"fresh export must be beneath '{export_root}'")
    manifest_path = export_dir / "run.json"
    require_regular_file(manifest_path, "fresh export run manifest")
    try:
        manifest_content = read_regular_file(manifest_path, "fresh export run manifest")
        manifest = json.loads(manifest_content)
    except (OSError, ValueError) as error:
        raise SystemExit(f"fresh export manifest is invalid: {error}")
    if manifest.get("package") != pkg or manifest.get("filter", "") != filter_arg:
        raise SystemExit("fresh export manifest does not match the requested package/filter")
    if manifest.get("source_state_sha256") != current_source_state:
        raise SystemExit("fresh export source state no longer matches the current checkout")
    if manifest.get("head_commit") != current_head:
        raise SystemExit("fresh export Git HEAD no longer matches the current checkout")
    verification_mode = manifest.get("verification_mode")
    verification_scope = manifest.get("verification_scope")
    baselines_verified = manifest.get("baselines_verified")
    status = manifest.get("status")
    if verification_mode not in {"baseline", "render-only"}:
        raise SystemExit("fresh export has an invalid verification mode")
    expected_scope = "filtered" if filter_arg else "complete"
    if verification_scope != expected_scope \
            or (verification_mode == "render-only" and verification_scope != "complete"):
        raise SystemExit("fresh export has an invalid verification scope")
    expected_baseline_state = (
        verification_mode == "baseline"
        and verification_scope == "complete"
        and status == 0
    )
    if not isinstance(baselines_verified, bool) or baselines_verified != expected_baseline_state:
        raise SystemExit("fresh export has an invalid baseline-verification claim")
    renderer = manifest.get("renderer")
    if manifest.get("schema_version") != 2 or not isinstance(renderer, dict):
        raise SystemExit("fresh export has an invalid renderer provenance schema")
    required_renderer_strings = (
        renderer.get("macos_product_version"),
        renderer.get("macos_build_version"),
        renderer.get("architecture"),
        renderer.get("xcode_version"),
        renderer.get("sdk_version"),
        renderer.get("sdk_build_version"),
        renderer.get("swift_version"),
        renderer.get("snapshot_testing_resolution_sha256"),
    )
    if not all(isinstance(value, str) and value for value in required_renderer_strings) \
            or renderer.get("backing_scale_factor") != 2 \
            or renderer.get("color_space") != "kCGColorSpaceDisplayP3":
        raise SystemExit("fresh export has incomplete renderer provenance")


def is_snapshot_png(path: pathlib.Path) -> bool:
    parts = set(path.parts)
    return "__Snapshots__" in parts and ".build" not in parts and path.suffix == ".png"


def is_export_png(path: pathlib.Path) -> bool:
    return path.suffix == ".png" and ".build" not in path.parts


def filter_token(value: str) -> str:
    if not value:
        return ""
    token = value.split("/")[-1]
    if token.endswith("()"):
        token = token[:-2]
    if "(" in token:
        token = token.split("(", 1)[0]
    return token


def matches_filter(path: pathlib.Path, token: str) -> bool:
    if not token:
        return True
    stem = path.stem
    return stem == token or stem.startswith(f"{token}.") or stem.startswith(f"{token}-")


export_metadata: dict[pathlib.Path, dict[str, object]] = {}
export_image_content: dict[pathlib.Path, bytes] = {}
export_sidecar_content: dict[pathlib.Path, bytes] = {}


def png_metadata(content: bytes) -> tuple[int, int, str | None]:
    if content[:8] != b"\x89PNG\r\n\x1a\n" or len(content) < 24:
        raise SystemExit("fresh SnapshotSupport export is not a valid PNG")
    width, height = struct.unpack(">II", content[16:24])
    profile = None
    offset = 8
    while offset + 12 <= len(content):
        length = struct.unpack(">I", content[offset : offset + 4])[0]
        chunk_type = content[offset + 4 : offset + 8]
        chunk = content[offset + 8 : offset + 8 + length]
        if chunk_type == b"iCCP":
            profile = chunk.split(b"\0", 1)[0].decode("ascii", errors="replace")
        offset += length + 12
    return width, height, profile


def exported_label(path: pathlib.Path) -> str:
    data = export_metadata.get(path)
    if data:
        display_name = str(data["display_name"])
        group = str(data["group"])
        if group not in display_name:
            return f"{group} / {display_name}"
        return display_name
    try:
        return str(path.relative_to(export_dir or root))
    except ValueError:
        return str(path)


export_images = []
if export_dir and export_dir.exists():
    export_entries = sorted(export_dir.iterdir())
    for path in export_entries:
        require_regular_file(path, "fresh export entry")
        if path.name != "run.json" and path.suffix not in {".png", ".json"}:
            raise SystemExit(f"fresh export has an unexpected entry: {path.name}")
    export_images = [path for path in export_entries if is_export_png(path)]

if export_dir:
    if not export_images:
        raise SystemExit(f"no fresh SnapshotSupport PNGs found in '{export_dir}'")
    expected_exports = manifest.get("exports")
    if not isinstance(expected_exports, list):
        raise SystemExit("fresh export manifest has no export inventory")
    expected_by_path = {}
    expected_entry_names = {"run.json"}
    for item in expected_exports:
        if not isinstance(item, dict):
            raise SystemExit("fresh export manifest has an invalid export entry")
        image_path = item.get("path")
        metadata_path = item.get("metadata_path")
        baseline_identity = item.get("baseline_identity")
        if not isinstance(image_path, str) or not isinstance(metadata_path, str) \
                or not isinstance(baseline_identity, str) or not baseline_identity \
                or len(pathlib.PurePosixPath(image_path).parts) != 1 \
                or len(pathlib.PurePosixPath(metadata_path).parts) != 1 \
                or pathlib.PurePosixPath(image_path).suffix != ".png" \
                or pathlib.PurePosixPath(metadata_path).suffix != ".json" \
                or pathlib.PurePosixPath(image_path).with_suffix(".json").name != metadata_path \
                or image_path in expected_by_path:
            raise SystemExit("fresh export manifest has an unsafe export path")
        expected_by_path[image_path] = item
        expected_entry_names.update({image_path, metadata_path})
    actual_paths = {str(path.relative_to(export_dir)) for path in export_images}
    if actual_paths != set(expected_by_path):
        raise SystemExit("fresh export files do not match the run manifest inventory")
    if {path.name for path in export_entries} != expected_entry_names:
        raise SystemExit("fresh export entries do not match the run manifest inventory")
    for image in export_images:
        relative = str(image.relative_to(export_dir))
        item = expected_by_path[relative]
        sidecar = image.with_suffix(".json")
        require_regular_file(sidecar, "fresh SnapshotSupport metadata")
        content = read_regular_file(image, "fresh SnapshotSupport image")
        width, height, profile = png_metadata(content)
        if hashlib.sha256(content).hexdigest() != item.get("sha256"):
            raise SystemExit(f"fresh SnapshotSupport image hash mismatch: {image}")
        point_width = finite_number(item.get("point_width"), "point width")
        point_height = finite_number(item.get("point_height"), "point height")
        backing_scale = finite_number(item.get("backing_scale_factor"), "backing scale")
        if not math.isclose(backing_scale, 2, rel_tol=0, abs_tol=1e-9) \
                or abs(width - point_width * backing_scale) > 1 \
                or abs(height - point_height * backing_scale) > 1 \
                or item.get("pixel_width") != width or item.get("pixel_height") != height \
                or item.get("color_profile") != profile \
                or profile != "kCGColorSpaceDisplayP3":
            raise SystemExit(f"fresh SnapshotSupport render metadata mismatch: {image}")
        sidecar_content = read_regular_file(sidecar, "fresh SnapshotSupport metadata")
        if hashlib.sha256(sidecar_content).hexdigest() != item.get("metadata_sha256"):
            raise SystemExit(f"fresh SnapshotSupport metadata hash mismatch: {sidecar}")
        try:
            metadata = json.loads(sidecar_content)
        except (OSError, ValueError) as error:
            raise SystemExit(f"fresh SnapshotSupport metadata is invalid: {sidecar}: {error}")
        context = metadata.get("context")
        render = metadata.get("render")
        required_strings = (metadata.get("display_name"), metadata.get("group"))
        if not all(isinstance(value, str) and value for value in required_strings) \
                or not isinstance(context, dict) \
                or not isinstance(context.get("file_id"), str) \
                or not context["file_id"] \
                or not isinstance(context.get("test_name"), str) \
                or not context["test_name"] \
                or not isinstance(metadata.get("baseline_identity"), str) \
                or not metadata["baseline_identity"] \
                or metadata["baseline_identity"] != item.get("baseline_identity") \
                or metadata.get("verification_mode") != verification_mode \
                or not isinstance(render, dict) \
                or render.get("pixel_width") != width \
                or render.get("pixel_height") != height \
                or finite_number(render.get("point_width"), "sidecar point width") != point_width \
                or finite_number(render.get("point_height"), "sidecar point height") != point_height \
                or not math.isclose(
                    finite_number(render.get("backing_scale_factor"), "sidecar backing scale"),
                    backing_scale,
                    rel_tol=0,
                    abs_tol=1e-9,
                ):
            raise SystemExit(f"fresh SnapshotSupport metadata has an invalid schema: {sidecar}")
        export_metadata[image] = metadata
        export_image_content[image] = content
        export_sidecar_content[image] = sidecar_content
    validity = "valid" if manifest.get("valid") is True and manifest.get("status") == 0 else "invalid"

source_kind = "SnapshotSupport export" if export_dir else "snapshot baselines (explicit)"
all_images = export_images if export_dir else sorted(
    path for path in package_dir.rglob("*.png") if is_snapshot_png(path)
)
token = filter_token(filter_arg)
selected = all_images if export_dir else [path for path in all_images if matches_filter(path, token)]
if not selected:
    raise SystemExit(f"no {source_kind} PNGs found for {pkg}")

require_directory(out, "Preview review directory")
out_descriptor = os.open(out, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
if os.listdir(out_descriptor):
    raise SystemExit("Preview review directory was populated before staging")
try:
    os.mkdir("images", mode=0o700, dir_fd=out_descriptor)
except OSError as error:
    raise SystemExit(f"Preview review image directory could not be created safely: {error}")
images_descriptor = os.open(
    "images",
    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
    dir_fd=out_descriptor,
)
if export_dir:
    write_exclusive_file(out_descriptor, "source-run.json", manifest_content)

copied: list[tuple[str, pathlib.Path, pathlib.Path]] = []
contact_inputs: list[tuple[int, str]] = []
for index, source in enumerate(selected, start=1):
    if export_images:
        label = exported_label(source)
        rel = pathlib.Path(label.replace("/", "__"))
    else:
        rel = source.relative_to(root)
        label = str(rel)
    safe_name = f"{index:02d}-" + str(rel).replace(os.sep, "__")
    if not safe_name.endswith(".png"):
        safe_name += ".png"
    dest = images_dir / safe_name
    sidecar = source.with_suffix(".json")
    staged_image_content = (
        export_image_content[source]
        if export_images
        else read_regular_file(source, "snapshot baseline")
    )
    staged_image_descriptor = create_exclusive_file(
        images_descriptor,
        safe_name,
        os.O_RDWR,
    )
    write_open_file(staged_image_descriptor, staged_image_content)
    os.lseek(staged_image_descriptor, 0, os.SEEK_SET)
    contact_inputs.append((staged_image_descriptor, safe_name))
    if export_images:
        write_exclusive_file(
            images_descriptor,
            pathlib.PurePath(safe_name).with_suffix(".json").name,
            export_sidecar_content[source],
        )
    else:
        if sidecar.exists():
            write_exclusive_file(
                images_descriptor,
                pathlib.PurePath(safe_name).with_suffix(".json").name,
                read_regular_file(sidecar, "snapshot baseline metadata"),
            )
    copied.append((label, source, dest))

sheet_path = out / "preview-review.png"
sheet_created = False
sheet_descriptor = None
try:
    if copied:
        contact_arguments = []
        for descriptor, label in contact_inputs:
            contact_arguments.extend(("--input-fd", str(descriptor), label))
        sheet_descriptor = create_exclusive_file(
            out_descriptor,
            sheet_path.name,
            os.O_RDWR,
        )
        subprocess.run(
            [
                str(root / "scripts" / "support" / "run_sanitized.sh"),
                "/usr/bin/xcrun",
                "swift",
                str(root / "scripts" / "support" / "contact_sheet.swift"),
                "--output-fd",
                str(sheet_descriptor),
                *contact_arguments,
            ],
            check=True,
            capture_output=True,
            pass_fds=tuple([sheet_descriptor, *(descriptor for descriptor, _label in contact_inputs)]),
            text=True,
        )
        for descriptor, label in contact_inputs:
            descriptor_metadata = os.fstat(descriptor)
            path_metadata = os.lstat(images_dir / label)
            if (descriptor_metadata.st_dev, descriptor_metadata.st_ino) != (
                    path_metadata.st_dev, path_metadata.st_ino
            ) or not stat.S_ISREG(path_metadata.st_mode) or path_metadata.st_nlink != 1:
                raise RuntimeError(f"contact sheet input identity changed during generation: {label}")
        os.fsync(sheet_descriptor)
        descriptor_metadata = os.fstat(sheet_descriptor)
        path_metadata = os.lstat(sheet_path)
        if (descriptor_metadata.st_dev, descriptor_metadata.st_ino) != (
                path_metadata.st_dev, path_metadata.st_ino
        ) or not stat.S_ISREG(path_metadata.st_mode) or path_metadata.st_nlink != 1:
            raise RuntimeError("contact sheet output identity changed during generation")
        os.lseek(sheet_descriptor, 0, os.SEEK_SET)
        sheet_content = b""
        while True:
            chunk = os.read(sheet_descriptor, 1024 * 1024)
            if not chunk:
                break
            sheet_content += chunk
        png_metadata(sheet_content)
        subprocess.run(
            [
                str(root / "scripts" / "support" / "run_sanitized.sh"),
                "/usr/bin/sips",
                "-g", "pixelWidth", "-g", "pixelHeight", str(sheet_path),
            ],
            check=True,
            capture_output=True,
            text=True,
        )
        sheet_created = True
except Exception as exc:
    write_exclusive_file(
        out_descriptor,
        "contact-sheet-error.txt",
        (str(exc) + "\n").encode(),
    )
    raise SystemExit(f"contact sheet generation failed: {exc}")
finally:
    if sheet_descriptor is not None:
        os.close(sheet_descriptor)
    for descriptor, _label in contact_inputs:
        os.close(descriptor)

index_path = out / "index.md"
html_path = out / "index.html"
created = dt.datetime.now().astimezone().isoformat(timespec="seconds")

lines = [
    f"# Preview Review: {pkg}",
    "",
    f"- Generated: `{created}`",
    f"- Filter: `{filter_arg or 'all'}`",
    f"- Source: `{source_kind}`",
    f"- Valid for execution evidence: `{'yes' if validity == 'valid' else 'no'}`",
    f"- Verification mode: `{verification_mode}`",
    f"- Verification scope: `{verification_scope}`",
    f"- Pixel baselines verified: `{'yes' if baselines_verified else 'no'}`",
    f"- Source package: `{package_dir}`",
]
if export_dir:
    lines.append(f"- SnapshotSupport export: `{export_dir}`")
if sheet_created:
    lines.append(f"- Contact sheet: `{sheet_path}`")
lines.extend(["", "## Images", ""])

for label, _source, dest in copied:
    lines.append(f"### {label}")
    lines.append(f"![{label}]({dest})")
    lines.append("")

if not copied:
    lines.append("No snapshot PNGs were found for this package/filter.")

write_exclusive_file(out_descriptor, index_path.name, "\n".join(lines).encode())

html_lines = [
    "<!doctype html>",
    "<meta charset=\"utf-8\">",
    "<title>Preview Review</title>",
    "<style>body{font:14px -apple-system,BlinkMacSystemFont,sans-serif;margin:24px;background:#f6f7f9;color:#15171a}"
    ".grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:20px}"
    "figure{margin:0;background:white;border:1px solid #ddd;border-radius:8px;padding:12px}"
    "img{max-width:100%;height:auto;display:block;margin:auto}figcaption{margin-top:8px;word-break:break-word}</style>",
    f"<h1>Preview Review: {html.escape(pkg)}</h1>",
    f"<p>Filter: <code>{html.escape(filter_arg or 'all')}</code></p>",
]
if sheet_created:
    html_lines.append(f"<p>Contact sheet: <code>{html.escape(str(sheet_path))}</code></p>")
html_lines.append("<div class=\"grid\">")
for label, _source, dest in copied:
    html_lines.append("<figure>")
    html_lines.append(f"<img src=\"{html.escape(dest.name if dest.parent == html_path.parent else str(dest))}\" alt=\"{html.escape(label)}\">")
    html_lines.append(f"<figcaption>{html.escape(label)}</figcaption>")
    html_lines.append("</figure>")
html_lines.append("</div>")
write_exclusive_file(out_descriptor, html_path.name, "\n".join(html_lines).encode())
os.close(images_descriptor)
os.close(out_descriptor)

print(f"PREVIEW_REVIEW_DIR={out}")
print(f"PREVIEW_REVIEW_INDEX={index_path}")
if sheet_created:
    print(f"PREVIEW_REVIEW_CONTACT_SHEET={sheet_path}")
print("PREVIEW_REVIEW_IMAGES=" + str(len(copied)))
print(f"PREVIEW_REVIEW_SOURCE={source_kind}")
print(f"PREVIEW_REVIEW_VALID={validity}")
print(f"PREVIEW_REVIEW_MODE={verification_mode}")
print(f"PREVIEW_REVIEW_SCOPE={verification_scope}")
print(f"PREVIEW_REVIEW_BASELINES_VERIFIED={'true' if baselines_verified else 'false'}")
PY
)"

if ! secure_artifact_tree "$OUT"; then
  echo "Preview evidence failed its secret scan and was discarded." >&2
  exit 1
fi
if [[ "$(source_state_hash)" != "$CURRENT_SOURCE_STATE" \
  || "$(current_git_head)" != "$CURRENT_HEAD" ]]; then
  echo "Checkout state changed during Preview review; stale evidence was discarded." >&2
  exit 1
fi
printf '%s\n' "$PREVIEW_OUTPUT"
PREVIEW_RETAINED=1
