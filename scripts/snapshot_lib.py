"""Shared bookkeeping for owner-facing snapshot diff review."""

from __future__ import annotations

import hashlib
import pathlib


VISIBLE_DELTA = 6


def suite_roots(root: pathlib.Path, package: str) -> list[pathlib.Path]:
    tests = root / "Packages" / package / "Tests"
    if not tests.is_dir():
        return []
    return sorted(
        path
        for path in tests.rglob("__Snapshots__")
        if path.is_dir() and ".build" not in path.parts
    )


def find_baseline(
    root: pathlib.Path, package: str, suite_file: str, image_name: str
) -> pathlib.Path | None:
    """Match SnapshotTesting's <suite>/<image> candidate to one baseline."""
    matches = [
        suite_root / suite_file / image_name
        for suite_root in suite_roots(root, package)
        if (suite_root / suite_file / image_name).is_file()
    ]
    return matches[0] if len(matches) == 1 else None


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dimensions(path: pathlib.Path) -> str:
    """Read WxH from the PNG IHDR without an imaging dependency."""
    try:
        header = path.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            return "?"
        width = int.from_bytes(header[16:20], "big")
        height = int.from_bytes(header[20:24], "big")
        return f"{width}x{height}"
    except OSError:
        return "?"
