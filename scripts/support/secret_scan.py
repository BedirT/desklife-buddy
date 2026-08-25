#!/usr/bin/python3 -I
"""Fail closed when retained artifacts contain likely credentials."""

from __future__ import annotations

import base64
import binascii
import mmap
import os
import re
import stat
import sys
from dataclasses import dataclass
from pathlib import Path


SECRET_NAME = re.compile(
    r"(?:^|_)(?:API_?KEY|TOKEN|SECRET|PASS(?:WORD|PHRASE)?|CREDENTIALS?|"
    r"AUTH(?:ORIZATION)?|COOKIE|PRIVATE_?KEY|ACCESS_?KEY|CLIENT_?SECRET|PAT)(?:$|_)",
    re.IGNORECASE,
)
PRIVATE_PREFIX = re.compile(
    r"^(?:(?:CODEX|CLAUDE|GITHUB|AWS|AZURE|GOOGLE|OPENAI|ANTHROPIC|RUNWAY)(?:_|$)|"
    r"(?:PI|GH)(?:_|$))[A-Z0-9_]*$",
    re.IGNORECASE,
)
SECRET_SUFFIX = re.compile(
    r"(?:API_?KEY|APIKEY|PASSWORD|PASSWD|TOKEN|SECRET|CREDENTIALS?|"
    r"AUTH|COOKIE|PRIVATE_?KEY|PRIVATEKEY|ACCESS_?KEY|ACCESSKEY|CLIENT_?SECRET|PAT)$",
    re.IGNORECASE,
)
KNOWN_PATTERNS: tuple[tuple[str, re.Pattern[bytes]], ...] = (
    ("github-token", re.compile(rb"(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{20,})")),
    ("openai-key", re.compile(rb"sk-(?:proj-)?[A-Za-z0-9_-]{20,}")),
    ("aws-access-key", re.compile(rb"(?:AKIA|ASIA)[A-Z0-9]{16}")),
    ("google-api-key", re.compile(rb"AIza[0-9A-Za-z_-]{30,}")),
    ("slack-token", re.compile(rb"xox[baprs]-[0-9A-Za-z-]{20,}")),
    ("private-key", re.compile(rb"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")),
    ("bearer-token", re.compile(rb"(?i)authorization[\"' :=]+bearer[ \t]+[A-Za-z0-9._~+/=-]{16,}")),
    ("url-credential", re.compile(rb"[a-zA-Z][a-zA-Z0-9+.-]*://[^\s/:@]{1,128}:[^\s/@]{8,256}@")),
)
IGNORED_VALUES = {"0", "1", "false", "none", "null", "true"}
EXACT_SECRET_NAMES = {"MYSQL_PWD", "PGPASSFILE", "SSH_AUTH_SOCK"}
PUBLIC_GITHUB_METADATA_NAMES = {"GITHUB_SHA", "GITHUB_WORKFLOW_SHA", "GITHUB_WORKSPACE"}
PUBLIC_GITHUB_METADATA_VALUES = {
    "GITHUB_API_URL": "https://api.github.com",
    "GITHUB_GRAPHQL_URL": "https://api.github.com/graphql",
    "GITHUB_SERVER_URL": "https://github.com",
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BASE64_RUN = re.compile(rb"[A-Za-z0-9+/_-]{16,}={0,2}")
HEX_RUN = re.compile(rb"[0-9A-Fa-f]{32,}")
ENCODED_SCAN_CHUNK = 8 * 1024 * 1024
ENCODED_SCAN_OVERLAP = 4096


@dataclass(frozen=True)
class Needle:
    label: str
    variants: tuple[bytes, ...]


def environment_needles() -> tuple[Needle, ...]:
    needles: list[Needle] = []
    for name, value in sorted(os.environ.items()):
        upper_name = name.upper()
        if upper_name in PUBLIC_GITHUB_METADATA_NAMES or (
            PUBLIC_GITHUB_METADATA_VALUES.get(upper_name) == value
        ):
            continue
        if not (
            SECRET_NAME.search(name)
            or SECRET_SUFFIX.search(name)
            or PRIVATE_PREFIX.fullmatch(name)
            or name.upper() in EXACT_SECRET_NAMES
        ):
            continue
        if len(value) < 8 or value.lower() in IGNORED_VALUES:
            continue
        raw = value.encode("utf-8", errors="surrogateescape")
        variants = {
            raw,
            value.encode("utf-16le", errors="surrogatepass"),
            value.encode("utf-16be", errors="surrogatepass"),
            base64.b64encode(raw),
            base64.urlsafe_b64encode(raw),
            base64.b64encode(raw).rstrip(b"="),
            base64.urlsafe_b64encode(raw).rstrip(b"="),
            binascii.hexlify(raw),
            binascii.hexlify(raw).upper(),
        }
        needles.append(Needle(f"environment:{name}", tuple(sorted(variants))))
    return tuple(needles)


def regular_files(root: Path, max_entries: int | None = None) -> tuple[list[Path], list[str]]:
    files: list[Path] = []
    errors: list[str] = []
    if max_entries is not None and max_entries < 1:
        return files, ["artifact entry-count limit exceeded"]
    try:
        metadata = root.lstat()
    except OSError:
        return files, [f"unreadable input: {root.name}"]
    if stat.S_ISLNK(metadata.st_mode):
        return files, [f"symlink input: {root.name}"]
    if stat.S_ISREG(metadata.st_mode):
        if metadata.st_nlink != 1:
            return files, [f"hard-linked input: {root.name}"]
        return [root], errors
    if not stat.S_ISDIR(metadata.st_mode):
        return files, [f"unsupported input: {root.name}"]
    entry_count = 1
    directories = [root]
    while directories:
        directory = directories.pop()
        try:
            entries = os.scandir(directory)
        except OSError:
            errors.append(f"unreadable directory: {directory.relative_to(root)}")
            continue
        with entries:
            for entry in entries:
                entry_count += 1
                if max_entries is not None and entry_count > max_entries:
                    errors.append("artifact entry-count limit exceeded")
                    return sorted(files), errors
                path = Path(entry.path)
                try:
                    child = path.lstat()
                except OSError:
                    errors.append(f"unreadable entry: {path.relative_to(root)}")
                    continue
                if stat.S_ISLNK(child.st_mode):
                    errors.append(f"symlink entry: {path.relative_to(root)}")
                elif stat.S_ISDIR(child.st_mode):
                    directories.append(path)
                elif stat.S_ISREG(child.st_mode):
                    if child.st_nlink != 1:
                        errors.append(f"hard-linked entry: {path.relative_to(root)}")
                    else:
                        files.append(path)
                else:
                    errors.append(f"unsupported entry: {path.relative_to(root)}")
    return sorted(files), errors


def display_path(path: Path, root: Path) -> str:
    if root.is_dir():
        return str(path.relative_to(root))
    return root.name


def known_pattern_labels(data: bytes | mmap.mmap) -> set[str]:
    return {label for label, pattern in KNOWN_PATTERNS if pattern.search(data)}


def encoded_windows(data: bytes) -> tuple[bytes, ...]:
    if len(data) <= 16384:
        return (data,)
    windows: list[bytes] = []
    step = 16384 - 2048
    for start in range(0, len(data), step):
        windows.append(data[start : start + 16384])
        if start + 16384 >= len(data):
            break
    return tuple(windows)


def decoded_known_pattern_labels(data: bytes | mmap.mmap) -> set[str]:
    findings: set[str] = set()
    size = len(data)
    for offset in range(0, size, ENCODED_SCAN_CHUNK):
        start = max(0, offset - ENCODED_SCAN_OVERLAP)
        end = min(size, offset + ENCODED_SCAN_CHUNK + ENCODED_SCAN_OVERLAP)
        chunk = data[start:end]

        # UTF-16LE and UTF-16BE ASCII payloads occupy one of the two byte lanes.
        findings.update(known_pattern_labels(chunk[0::2]))
        findings.update(known_pattern_labels(chunk[1::2]))

        for match in BASE64_RUN.finditer(chunk):
            for window in encoded_windows(match.group(0)):
                for alignment in range(4):
                    candidate = window[alignment:]
                    if len(candidate) < 16:
                        continue
                    candidate += b"=" * (-len(candidate) % 4)
                    try:
                        decoded = base64.b64decode(candidate, altchars=b"-_", validate=False)
                    except (binascii.Error, ValueError):
                        continue
                    findings.update(known_pattern_labels(decoded))

        for match in HEX_RUN.finditer(chunk):
            for window in encoded_windows(match.group(0)):
                for alignment in range(2):
                    candidate = window[alignment:]
                    candidate = candidate[: len(candidate) - (len(candidate) % 2)]
                    if len(candidate) < 32:
                        continue
                    try:
                        decoded = binascii.unhexlify(candidate)
                    except (binascii.Error, ValueError):
                        continue
                    findings.update(known_pattern_labels(decoded))
    return findings


def scan_descriptor(descriptor: int, label: str, needles: tuple[Needle, ...]) -> list[str]:
    findings: list[str] = []
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            raise OSError("descriptor is not a regular file")
        if metadata.st_size == 0:
            return findings
        with mmap.mmap(descriptor, 0, access=mmap.ACCESS_READ) as data:
            for needle in needles:
                if any(data.find(variant) >= 0 for variant in needle.variants):
                    findings.append(f"{needle.label} in {label}")
            for pattern_label, pattern in KNOWN_PATTERNS:
                if pattern.search(data):
                    findings.append(f"pattern:{pattern_label} in {label}")
            for pattern_label in decoded_known_pattern_labels(data):
                findings.append(f"encoded-pattern:{pattern_label} in {label}")
    except (OSError, ValueError):
        findings.append(f"unreadable file: {label}")
    return findings


def scan_file(path: Path, root: Path, needles: tuple[Needle, ...]) -> list[str]:
    try:
        with path.open("rb") as stream:
            return scan_descriptor(stream.fileno(), display_path(path, root), needles)
    except OSError:
        return [f"unreadable file: {display_path(path, root)}"]


def print_images(arguments: list[str]) -> int:
    images: list[Path] = []
    findings: list[str] = []
    for argument in arguments:
        root = Path(argument)
        files, errors = regular_files(root)
        findings.extend(errors)
        for path in files:
            try:
                with path.open("rb") as stream:
                    is_png = stream.read(len(PNG_SIGNATURE)) == PNG_SIGNATURE
            except OSError:
                findings.append(f"unreadable file: {display_path(path, root)}")
                continue
            if path.suffix.lower() == ".png" and not is_png:
                findings.append(f"invalid PNG: {display_path(path, root)}")
            elif is_png:
                images.append(path)
    if findings:
        for finding in sorted(set(findings)):
            print(f"Artifact secret scan blocked retention: {finding}", file=sys.stderr)
        return 1
    for path in sorted(set(images)):
        sys.stdout.buffer.write(os.fsencode(str(path)) + b"\0")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: secret_scan.py <file-or-directory> [...]", file=sys.stderr)
        return 2
    if sys.argv[1] == "--images0":
        if len(sys.argv) < 3:
            print("usage: secret_scan.py --images0 <file-or-directory> [...]", file=sys.stderr)
            return 2
        return print_images(sys.argv[2:])
    needles = environment_needles()
    findings: list[str] = []
    for argument in sys.argv[1:]:
        root = Path(argument)
        files, errors = regular_files(root)
        findings.extend(errors)
        for path in files:
            findings.extend(scan_file(path, root, needles))
    if findings:
        for finding in sorted(set(findings)):
            print(f"Artifact secret scan blocked retention: {finding}", file=sys.stderr)
        return 1
    print("artifact secret scan: clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
