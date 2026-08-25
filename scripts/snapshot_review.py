#!/usr/bin/python3 -I
"""Build the baseline diff review page from a snapshot run's candidates.

The output is meant to be looked at exactly once, top to bottom, and abandoned
as soon as it stops being interesting  -  so entries are ordered by how much
actually moved, and light/dark of the same state sit together for comparison.

Writes into <out>:
    review.html    the page
    proposal.json  pending changes, consumed by accept_snapshots.py
"""

from __future__ import annotations

import argparse
import atexit
import base64
import datetime as dt
import html
import json
import os
import pathlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import snapshot_lib as lib  # noqa: E402

THUMB_WIDTH = 340
MAX_INPUT_BYTES = 32 * 1024 * 1024
MAX_TOTAL_INPUT_BYTES = 256 * 1024 * 1024
MAX_PIXELS = 16_000_000
MAX_CANDIDATES = 256
_COMPARE_CACHE: dict[tuple[pathlib.Path, pathlib.Path], dict] = {}
_RENDERER: pathlib.Path
_RENDERER_IDENTITY: tuple[int, int, int]
_RENDERER_SHA256: str
_RENDER_DIR: pathlib.Path


def _validate_renderer() -> None:
    descriptor = os.open(_RENDERER, os.O_RDONLY | os.O_NOFOLLOW)
    try:
        metadata = os.fstat(descriptor)
        content = bytearray()
        while len(content) <= 64 * 1024 * 1024:
            chunk = os.read(descriptor, min(1024 * 1024, 64 * 1024 * 1024 + 1 - len(content)))
            if not chunk:
                break
            content.extend(chunk)
        after = os.fstat(descriptor)
        identity = (metadata.st_dev, metadata.st_ino, metadata.st_size)
        if identity != _RENDERER_IDENTITY or identity != (after.st_dev, after.st_ino, after.st_size) \
          or __import__("hashlib").sha256(content).hexdigest() != _RENDERER_SHA256:
            raise SystemExit("Snapshot diff renderer changed after validation.")
    finally:
        os.close(descriptor)


def measure(Image, np, before: pathlib.Path, after: pathlib.Path) -> dict:
    """What moved between two renders, in numbers a human can rank by."""
    return _comparison(Image, before, after)


def heatmap(Image, np, before: pathlib.Path, after: pathlib.Path):
    """The `after` render bleached out, with everything that moved lit up."""
    return _comparison(Image, before, after)["heatmap"]


def _comparison(Image, before: pathlib.Path, after: pathlib.Path):
    key = (before, after)
    if key not in _COMPARE_CACHE:
        index = len(_COMPARE_CACHE)
        prefix = _RENDER_DIR / f"{index:04d}"
        paths = {
            "beforeThumb": prefix.with_suffix(".before.png"),
            "afterThumb": prefix.with_suffix(".after.png"),
            "heatmap": prefix.with_suffix(".heatmap.png"),
            "beforeCrop": prefix.with_suffix(".before-crop.png"),
            "afterCrop": prefix.with_suffix(".after-crop.png"),
        }
        _validate_renderer()
        completed = subprocess.run(
            [
                str(_RENDERER), str(before), str(after),
                str(paths["beforeThumb"]), str(paths["afterThumb"]),
                str(paths["heatmap"]), str(paths["beforeCrop"]),
                str(paths["afterCrop"]), str(THUMB_WIDTH),
            ],
            check=True,
            capture_output=True,
        )
        result = json.loads(completed.stdout)
        result.update(paths)
        _COMPARE_CACHE[key] = result
    return _COMPARE_CACHE[key]


def file_uri(path: pathlib.Path) -> str:
    return "data:image/png;base64," + base64.b64encode(path.read_bytes()).decode()


def variant_of(image_name: str) -> tuple[str, str]:
    """`active.dark.png` -> ("active", "dark"). Unsuffixed names keep one pane."""
    stem = image_name[:-4] if image_name.endswith(".png") else image_name
    head, _, tail = stem.partition(".")
    return head, (tail or "default")


def _png_dimensions(content: bytes, label: pathlib.Path) -> None:
    if len(content) < 24 or content[:8] != b"\x89PNG\r\n\x1a\n" or content[12:16] != b"IHDR":
        raise SystemExit(f"Invalid snapshot PNG: {label}")
    width = int.from_bytes(content[16:20], "big")
    height = int.from_bytes(content[20:24], "big")
    if width < 1 or height < 1 or width > 8_192 or height > 8_192 or width * height > MAX_PIXELS:
        raise SystemExit(f"Snapshot PNG dimensions exceed review limits: {label}")


def _bounded_bytes(path: pathlib.Path, allowed_root: pathlib.Path, maximum: int) -> bytes:
    allowed_root = allowed_root.resolve()
    try:
        relative = path.relative_to(allowed_root)
    except ValueError:
        raise SystemExit(f"Snapshot input escaped its expected root: {path}") from None
    parent = os.open(allowed_root, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    descriptor = -1
    try:
        parent_metadata = os.fstat(parent)
        if parent_metadata.st_uid != os.geteuid() or parent_metadata.st_mode & 0o022:
            raise SystemExit(f"Unsafe snapshot input root: {allowed_root}")
        for component in relative.parts[:-1]:
            next_parent = os.open(
                component,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                dir_fd=parent,
            )
            os.close(parent)
            parent = next_parent
            parent_metadata = os.fstat(parent)
            if parent_metadata.st_uid != os.geteuid() or parent_metadata.st_mode & 0o022:
                raise SystemExit(f"Unsafe snapshot input ancestor: {path.parent}")
        descriptor = os.open(relative.parts[-1], os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != os.geteuid() or metadata.st_nlink != 1:
            raise SystemExit(f"Unsafe snapshot input file: {path}")
        if metadata.st_size < 0 or metadata.st_size > maximum:
            raise SystemExit(f"Snapshot input size exceeds review limits: {path}")
        content = b""
        while len(content) <= maximum:
            chunk = os.read(descriptor, min(1024 * 1024, maximum + 1 - len(content)))
            if not chunk:
                break
            content += chunk
        if len(content) != metadata.st_size:
            raise SystemExit(f"Snapshot input changed while being read: {path}")
    finally:
        if descriptor >= 0:
            os.close(descriptor)
        os.close(parent)
    return content


def _validated_bytes(path: pathlib.Path, allowed_root: pathlib.Path) -> bytes:
    content = _bounded_bytes(path, allowed_root, MAX_INPUT_BYTES)
    _png_dimensions(content, path)
    return content


def _private_copy(path: pathlib.Path, allowed_root: pathlib.Path, destination: pathlib.Path) -> pathlib.Path:
    content = _validated_bytes(path, allowed_root)
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent, delete=False) as staged:
        os.fchmod(staged.fileno(), 0o600)
        staged.write(content)
        staged.flush()
        os.fsync(staged.fileno())
    os.replace(staged.name, destination)
    return destination


def _preview_baselines(root: pathlib.Path, package: str, preview_export: pathlib.Path | None) -> dict[tuple[str, str], pathlib.Path]:
    result: dict[tuple[str, str], pathlib.Path] = {}
    ambiguous: set[tuple[str, str]] = set()
    if preview_export is None or not preview_export.is_dir():
        return result
    preview_export = preview_export.resolve()
    for sidecar in preview_export.glob("*.json"):
        if sidecar.name == "run.json" or sidecar.is_symlink():
            continue
        try:
            identity = json.loads(
                _bounded_bytes(sidecar, preview_export.resolve(), 1024 * 1024)
            )["baseline_identity"]
            parts = pathlib.PurePosixPath(identity).parts
            if len(parts) < 3:
                continue
            target, source, image = parts[0], parts[-2], parts[-1]
            middle = parts[1:-2]
            baseline = root / "Packages" / package / "Tests" / target
            for component in middle:
                baseline /= component
            baseline = baseline / "__Snapshots__" / source / f"{image}.png"
            key = (source, f"{image}.png")
            if key in result and result[key] != baseline:
                ambiguous.add(key)
            else:
                result[key] = baseline
        except (KeyError, OSError, TypeError, ValueError, json.JSONDecodeError):
            continue
    for key in ambiguous:
        result.pop(key, None)
    return result


def collect(
    root: pathlib.Path,
    package: str,
    candidates: pathlib.Path,
    inputs: pathlib.Path,
    preview_export: pathlib.Path | None,
) -> tuple[list, list, list, list]:
    """Pair every failed-assertion candidate render with its tracked baseline."""
    changed, orphans = [], []
    total_bytes = 0

    candidates = candidates.resolve()
    candidate_root = candidates
    package_root = (root / "Packages" / package).resolve()
    identities = _preview_baselines(root, package, preview_export)
    if candidates.is_dir() and not candidates.is_symlink():
        candidate_paths = []
        for candidate in candidates.rglob("*.png"):
            candidate_paths.append(candidate)
            if len(candidate_paths) > MAX_CANDIDATES:
                raise SystemExit(f"Snapshot review exceeds {MAX_CANDIDATES} candidates.")
        for index, candidate in enumerate(sorted(candidate_paths)):
            suite_file = candidate.parent.name
            baseline = identities.get((suite_file, candidate.name))
            if baseline is None or not baseline.is_file():
                baseline = lib.find_baseline(root, package, suite_file, candidate.name)
            safe_candidate = _private_copy(
                candidate, candidate_root, inputs / f"{index:04d}.candidate.png"
            )
            total_bytes += safe_candidate.stat().st_size
            if total_bytes > MAX_TOTAL_INPUT_BYTES:
                raise SystemExit("Snapshot review exceeds its aggregate byte budget.")
            if baseline is None:
                orphans.append(str(candidate))
                continue
            safe_baseline = _private_copy(
                baseline, package_root, inputs / f"{index:04d}.baseline.png"
            )
            total_bytes += safe_baseline.stat().st_size
            if total_bytes > MAX_TOTAL_INPUT_BYTES:
                raise SystemExit("Snapshot review exceeds its aggregate byte budget.")
            changed.append({
                "baseline": baseline,
                "candidate": candidate,
                "renderBaseline": safe_baseline,
                "renderCandidate": safe_candidate,
                "suite": suite_file,
            })

    # Missing baselines bootstrap in place and appear in the preview contact
    # sheet. This page is specifically for existing baselines that moved.
    return changed, orphans, [], []


def build_entries(Image, np, changed: list) -> list[dict]:
    entries = []
    for item in changed:
        baseline, candidate = item["baseline"], item["candidate"]
        render_baseline, render_candidate = item["renderBaseline"], item["renderCandidate"]
        stats = measure(Image, np, render_baseline, render_candidate)
        state, variant = variant_of(candidate.name)
        entries.append(
            {
                "suite": item["suite"],
                "state": state,
                "variant": variant,
                "image": candidate.name,
                "baselinePath": str(baseline),
                "candidatePath": str(candidate),
                "renderBaseline": str(render_baseline),
                "renderCandidate": str(render_candidate),
                "baselineSHA256": lib.digest(render_baseline),
                "candidateSHA256": lib.digest(render_candidate),
                **stats,
            }
        )
    return entries


def group(entries: list[dict]) -> list[dict]:
    """One group per state, so light and dark are judged side by side."""
    groups: dict[tuple[str, str], dict] = {}
    for entry in entries:
        key = (entry["suite"], entry["state"])
        groups.setdefault(key, {"suite": key[0], "state": key[1], "variants": []})
        groups[key]["variants"].append(entry)
    ordered = list(groups.values())
    for item in ordered:
        item["variants"].sort(key=lambda e: e.get("variant", ""))
        item["peak"] = max((e.get("visibleFraction") or 0) for e in item["variants"])
    ordered.sort(key=lambda g: -g["peak"])
    return ordered


def percent(value: float | None) -> str:
    if value is None:
        return " - "
    if value == 0:
        return "0%"
    if value < 0.001:
        return "<0.1%"
    return f"{value * 100:.1f}%"


def render_html(
    Image, np, package, run_id, groups, new, unseeded, orphans, accept_cmd,
    proposal_digest, degraded,
) -> str:
    moved = sum(len(g["variants"]) for g in groups)
    parts = [
        "<!doctype html>",
        '<meta charset="utf-8">',
        f'<meta name="snapshot-proposal-sha256" content="{proposal_digest}">',
        f"<title>Baseline diff  -  {html.escape(package)}</title>",
        _STYLE,
        '<header class="top">',
        f"<h1>{html.escape(package)} baselines</h1>",
        '<p class="counts">'
        f'<b>{moved}</b> moved  |  <b>{len(new)}</b> new  |  '
        f'run <code>{html.escape(run_id)}</code></p>',
    ]
    if moved:
        parts.append(
            '<p class="how">Ordered by how much moved  -  the top of this page is '
            "where the risk is. Stop when it stops being interesting. Hover any "
            "<b>after</b> render to flip back to <b>before</b>.</p>"
        )
    if orphans:
        parts.append(
            '<p class="warn">Acceptance is blocked because one or more candidates '
            "could not be paired with a target-qualified baseline.</p>"
        )
    elif moved or new:
        parts.append(f'<p class="accept">Accept these renders:<code>{html.escape(accept_cmd)}</code></p>')
    parts.append(
        '<p class="binding">Bound proposal: '
        f'<code>{proposal_digest}</code></p>'
    )
    if degraded:
        parts.append(
            '<p class="warn">Pillow/numpy unavailable  -  this page lists what '
            "changed but cannot show it. <code>pip3 install pillow numpy</code></p>"
        )
    parts.append("</header>")

    if not moved and not new and not orphans:
        parts.append('<p class="empty">Every baseline matched. Nothing to review.</p>')

    for item in groups:
        parts.append("<section>")
        parts.append(
            f'<h2>{html.escape(item["state"])}'
            f'<span class="suite">{html.escape(item["suite"])}</span></h2>'
        )
        for entry in item["variants"]:
            parts.append(_render_variant(Image, entry, degraded))
        parts.append("</section>")

    if new:
        parts.append('<section class="minor"><h2>New baselines<span class="suite">'
                     "recorded by this run</span></h2><ul>")
        for entry in new:
            path = pathlib.Path(entry["baseline"])
            label = f'{entry["suite"]}/{path.name}'
            thumb = (
                f'<img src="{file_uri(path)}" alt="">' if Image else ""
            )
            parts.append(f"<li>{thumb}<code>{html.escape(label)}</code></li>")
        parts.append("</ul></section>")

    if unseeded:
        names = ", ".join(html.escape(str(p.parent.name)) for p in unseeded)
        parts.append(
            f'<section class="minor"><h2>Un-seeded suites</h2><p>No manifest yet in: '
            f"{names}. Run the accept command to seed them.</p></section>"
        )

    if orphans:
        parts.append('<section class="minor"><h2>Unmatched candidates</h2><ul>')
        for path in orphans:
            parts.append(f"<li><code>{html.escape(path)}</code></li>")
        parts.append("</ul><p>No baseline matched these renders  -  usually a renamed "
                     "test file. They will not be accepted.</p></section>")

    return "\n".join(parts)


def _render_variant(Image, entry: dict, degraded: bool) -> str:
    baseline = pathlib.Path(entry["renderBaseline"])
    candidate = pathlib.Path(entry["renderCandidate"])
    stat = (
        f'{percent(entry.get("visibleFraction"))} of pixels moved  |  '
        f'peak delta {percent(entry.get("maxDelta"))}'
    )
    if entry.get("resized"):
        stat = f'size changed {entry.get("beforeDims")} -> {entry.get("afterDims")}'

    rows = [f'<div class="variant"><div class="vhead"><b>{html.escape(entry["variant"])}</b>'
            f'<span>{stat}</span></div>']

    if degraded:
        rows.append(f'<p class="paths"><code>{html.escape(str(baseline))}</code></p></div>')
        return "".join(rows)

    rendered = _comparison(Image, baseline, candidate)
    before = file_uri(rendered["beforeThumb"])
    after = file_uri(rendered["afterThumb"])
    hot = file_uri(rendered["heatmap"])

    rows.append('<div class="panes">')
    rows.append(f'<figure><img src="{before}" alt="before"><figcaption>before</figcaption></figure>')
    rows.append(
        f'<figure class="swap"><img class="a" src="{after}" alt="after">'
        f'<img class="b" src="{before}" alt="before">'
        "<figcaption>after  -  hover to flip</figcaption></figure>"
    )
    rows.append(f'<figure><img src="{hot}" alt="what moved"><figcaption>what moved</figcaption></figure>')

    if rendered["beforeCrop"].is_file() and rendered["afterCrop"].is_file():
        crop_before = file_uri(rendered["beforeCrop"])
        crop_after = file_uri(rendered["afterCrop"])
        rows.append(
            f'<figure class="swap zoom"><img class="a" src="{crop_after}" alt="zoom after">'
            f'<img class="b" src="{crop_before}" alt="zoom before">'
            "<figcaption>changed region - hover to flip</figcaption></figure>"
        )

    rows.append("</div></div>")
    return "".join(rows)


# A fixed neutral surround, in both themes: judging colour against a background
# that shifts with the OS theme is how you talk yourself into a bad render.
_STYLE = """<style>
:root{color-scheme:light dark}
body{margin:0;padding:0 0 64px;background:#8e8e93;color:#111;
  font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
.top{position:sticky;top:0;z-index:10;background:#fff;padding:18px 24px;
  border-bottom:1px solid #c7c7cc;box-shadow:0 1px 12px rgba(0,0,0,.18)}
h1{margin:0;font-size:19px}
.counts{margin:4px 0 0;color:#3a3a3c}
.counts b{font-size:16px}
.how{margin:8px 0 0;max-width:62ch;color:#3a3a3c}
.accept{margin:10px 0 0;color:#3a3a3c}
.accept code,.counts code{background:#f2f2f7;border:1px solid #d1d1d6;border-radius:6px;
  padding:2px 7px;margin-left:8px;font-size:12.5px;user-select:all}
.warn{margin:10px 0 0;color:#8a3b00;background:#fff3e0;border-radius:6px;padding:8px 12px}
.empty{margin:48px;text-align:center;font-size:17px;color:#f2f2f7}
section{margin:28px 24px;background:#fff;border-radius:12px;padding:18px 20px;
  box-shadow:0 2px 10px rgba(0,0,0,.16)}
section.minor{background:#f2f2f7;box-shadow:none}
h2{margin:0 0 12px;font-size:17px;display:flex;align-items:baseline;gap:10px}
h2 .suite{font-size:12px;font-weight:400;color:#6e6e73}
.variant{border-top:1px solid #e5e5ea;padding-top:12px;margin-top:12px}
.variant:first-of-type{border-top:0;margin-top:0}
.vhead{display:flex;gap:12px;align-items:baseline;margin-bottom:10px}
.vhead span{color:#6e6e73;font-variant-numeric:tabular-nums}
.panes{display:flex;flex-wrap:wrap;gap:16px}
figure{margin:0}
figure img{display:block;border:1px solid #d1d1d6;border-radius:8px;background:#8e8e93}
figcaption{margin-top:6px;font-size:12px;color:#6e6e73;text-align:center}
.swap{position:relative}
.swap .b{position:absolute;inset:0;opacity:0}
.swap:hover .b{opacity:1}
.zoom img{border-style:dashed}
ul{margin:0;padding:0;list-style:none;display:flex;flex-wrap:wrap;gap:14px}
li{display:flex;flex-direction:column;gap:6px;font-size:12px}
li img{border:1px solid #d1d1d6;border-radius:6px}
code{font-family:ui-monospace,SFMono-Regular,Menlo,monospace}
</style>"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", required=True)
    parser.add_argument("--package", required=True)
    parser.add_argument("--candidates", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--renderer", required=True)
    parser.add_argument("--renderer-sha256", required=True)
    parser.add_argument("--head", required=True)
    parser.add_argument("--source-state", required=True)
    parser.add_argument("--preview-export")
    args = parser.parse_args()

    root = pathlib.Path(args.root).resolve()
    out = pathlib.Path(args.out).resolve()
    renderer = pathlib.Path(args.renderer)
    renderer_fd = os.open(renderer, os.O_RDONLY | os.O_NOFOLLOW)
    renderer_metadata = os.fstat(renderer_fd)
    renderer_content = bytearray()
    while len(renderer_content) <= 64 * 1024 * 1024:
        chunk = os.read(renderer_fd, min(1024 * 1024, 64 * 1024 * 1024 + 1 - len(renderer_content)))
        if not chunk:
            break
        renderer_content.extend(chunk)
    renderer_after = os.fstat(renderer_fd)
    renderer_bytes = bytes(renderer_content)
    if not stat.S_ISREG(renderer_metadata.st_mode) \
      or renderer_metadata.st_uid != os.geteuid() \
      or renderer_metadata.st_nlink != 1 \
      or renderer_metadata.st_mode & 0o022 \
      or not renderer_metadata.st_mode & 0o100 \
      or (renderer_metadata.st_dev, renderer_metadata.st_ino, renderer_metadata.st_size) \
        != (renderer_after.st_dev, renderer_after.st_ino, renderer_after.st_size) \
      or len(renderer_bytes) != renderer_metadata.st_size \
      or len(renderer_bytes) > 64 * 1024 * 1024 \
      or __import__("hashlib").sha256(renderer_bytes).hexdigest() != args.renderer_sha256:
        os.close(renderer_fd)
        raise SystemExit("Snapshot diff renderer failed identity validation.")
    os.lseek(renderer_fd, 0, os.SEEK_SET)
    if not re.fullmatch(r"[0-9a-f]{40,64}", args.head):
        raise SystemExit("Snapshot review requires a valid Git head.")
    if not re.fullmatch(r"[0-9a-f]{64}", args.source_state):
        raise SystemExit("Snapshot review requires a valid source-state digest.")
    out.parent.mkdir(parents=True, exist_ok=True)
    staging = pathlib.Path(tempfile.mkdtemp(prefix=f".{out.name}.", dir=out.parent))
    os.chmod(staging, 0o700)
    atexit.register(lambda: shutil.rmtree(staging) if staging.exists() else None)
    inputs = staging / "inputs"
    render_dir = staging / "rendered"
    inputs.mkdir(mode=0o700)
    render_dir.mkdir(mode=0o700)
    global _RENDERER, _RENDERER_IDENTITY, _RENDERER_SHA256, _RENDER_DIR
    _RENDERER = renderer
    _RENDERER_IDENTITY = (
        renderer_metadata.st_dev,
        renderer_metadata.st_ino,
        renderer_metadata.st_size,
    )
    _RENDERER_SHA256 = args.renderer_sha256
    _RENDER_DIR = render_dir
    os.close(renderer_fd)
    Image, np = True, None
    degraded = False

    changed, orphans, new, unseeded = collect(
        root,
        args.package,
        pathlib.Path(args.candidates),
        inputs,
        pathlib.Path(args.preview_export) if args.preview_export else None,
    )
    baseline_counts: dict[pathlib.Path, int] = {}
    for item in changed:
        baseline_counts[item["baseline"]] = baseline_counts.get(item["baseline"], 0) + 1
    duplicates = {path for path, count in baseline_counts.items() if count > 1}
    if duplicates:
        orphans.extend(str(item["candidate"]) for item in changed if item["baseline"] in duplicates)
        changed = [item for item in changed if item["baseline"] not in duplicates]

    # A package-wide redesign can move 80+ baselines. Native rendering keeps
    # the full ranking quick, while smaller thumbnails bound the HTML size.
    global THUMB_WIDTH
    if len(changed) > 40:
        THUMB_WIDTH = 200
    elif len(changed) > 16:
        THUMB_WIDTH = 260
    entries = build_entries(Image, np, changed)
    groups = group(entries)

    proposal_path = staging / "proposal.json"
    proposal = {
        "schemaVersion": 2,
        "package": args.package,
        "runId": args.run_id,
        "generated": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "head": args.head,
        "sourceStateSHA256": args.source_state,
        "changed": [
            {
                key: entry[key]
                for key in (
                    "suite", "state", "variant", "image", "baselinePath",
                    "candidatePath", "baselineSHA256", "candidateSHA256",
                    "visibleFraction", "anyFraction", "maxDelta", "resized",
                )
                if key in entry
            }
            for entry in entries
        ],
        "new": [{"suite": e["suite"], "baselinePath": str(e["baseline"])} for e in new],
        "unmatched": orphans,
    }
    proposal_bytes = (json.dumps(proposal, indent=2, sort_keys=True) + "\n").encode()
    proposal_digest = __import__("hashlib").sha256(proposal_bytes).hexdigest()
    proposal_path.write_bytes(proposal_bytes)

    accept_cmd = (
        f"scripts/accept-snapshots.sh {args.run_id}-{args.package} "
        f"--proposal-sha256 {proposal_digest}"
    )
    review_path = staging / "review.html"
    review_path.write_text(
        render_html(Image, np, args.package, args.run_id, groups, new, unseeded,
                    orphans, accept_cmd, proposal_digest, degraded)
    )
    completion = {
        "schemaVersion": 1,
        "proposalSHA256": proposal_digest,
        "reviewSHA256": lib.digest(review_path),
    }
    (staging / "complete.json").write_text(json.dumps(completion, indent=2, sort_keys=True) + "\n")
    for path in staging.rglob("*"):
        if path.is_file():
            path.chmod(0o600)
    if out.exists():
        raise SystemExit(f"Snapshot review output already exists: {out}")
    os.replace(staging, out)
    proposal_path = out / "proposal.json"
    review_path = out / "review.html"

    moved = len(entries)
    print(f"SNAPSHOT_REVIEW_PAGE={review_path}")
    print(f"SNAPSHOT_REVIEW_PROPOSAL={proposal_path}")
    print(f"SNAPSHOT_REVIEW_MOVED={moved}")
    print(f"SNAPSHOT_REVIEW_NEW={len(new)}")
    if orphans:
        print(f"SNAPSHOT_REVIEW_UNMATCHED={len(orphans)}")
        print("SNAPSHOT_REVIEW_BLOCKED=unmatched candidates")
    if (moved or new) and not orphans:
        print(f"SNAPSHOT_REVIEW_ACCEPT={accept_cmd}")
        top = groups[0] if groups else None
        if top:
            print(
                f"SNAPSHOT_REVIEW_LARGEST={top['suite']}/{top['state']} "
                f"({percent(top['peak'])} of pixels)"
            )
    elif not orphans:
        print("SNAPSHOT_REVIEW_RESULT=every baseline matched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
