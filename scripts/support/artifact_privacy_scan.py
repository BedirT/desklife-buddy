#!/usr/bin/python3 -I
"""Scan one descriptor-captured artifact set, including exact PNG bytes."""

from __future__ import annotations

import argparse
import ctypes
import errno
import hashlib
import importlib.util
import os
import pathlib
import secrets
import stat
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from typing import BinaryIO

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
VISUAL_BATCH_FILES = 32
VISUAL_BATCH_BYTES = 256 * 1024 * 1024
VISUAL_FILE_BYTES = 256 * 1024 * 1024
MAX_ARTIFACT_ENTRIES = 100_000
CLONE_FALLBACK_ERRORS = {
    errno.EINVAL,
    errno.ENOSYS,
    errno.ENOTSUP,
    errno.EOPNOTSUPP,
    errno.EXDEV,
}

LIBC = ctypes.CDLL(None, use_errno=True)
FCLONEFILEAT = getattr(LIBC, "fclonefileat", None)
if FCLONEFILEAT is not None:
    FCLONEFILEAT.argtypes = [ctypes.c_int, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint32]
    FCLONEFILEAT.restype = ctypes.c_int


@dataclass
class CapturedImage:
    label: str
    size: int
    stream: BinaryIO


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scanner", required=True, type=pathlib.Path)
    parser.add_argument("--work", required=True, type=pathlib.Path)
    parser.add_argument("--visual-only", action="store_true")
    parser.add_argument("--original-only", action="store_true")
    parser.add_argument("inputs", nargs="+")
    return parser.parse_args()


def load_secret_scan() -> object:
    sys.dont_write_bytecode = True
    path = pathlib.Path(__file__).with_name("secret_scan.py")
    specification = importlib.util.spec_from_file_location("artifact_secret_scan", path)
    if specification is None or specification.loader is None:
        raise RuntimeError("secret scanner could not be loaded")
    module = importlib.util.module_from_spec(specification)
    sys.modules[specification.name] = module
    specification.loader.exec_module(module)
    return module


def validate_scanner(path: pathlib.Path) -> None:
    metadata = path.lstat()
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or path.is_symlink()
        or not os.access(path, os.X_OK)
    ):
        raise RuntimeError("visual scanner is unsafe")


def validate_work_directory(path: pathlib.Path) -> int:
    metadata = path.lstat()
    if (
        not stat.S_ISDIR(metadata.st_mode)
        or path.is_symlink()
        or metadata.st_uid != os.getuid()
        or stat.S_IMODE(metadata.st_mode) != 0o700
    ):
        raise RuntimeError("artifact scan work directory is unsafe")
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def topology_for_root(
    root: pathlib.Path,
    max_entries: int,
) -> tuple[set[tuple[str, str]], str | None]:
    topology: set[tuple[str, str]] = set()
    if max_entries < 1:
        return topology, "limit"
    try:
        metadata = root.lstat()
    except OSError:
        return topology, "unsafe"
    absolute = str(root.absolute())
    if stat.S_ISREG(metadata.st_mode):
        topology.add((absolute, "file-root"))
        return topology, None
    if not stat.S_ISDIR(metadata.st_mode):
        return topology, "unsafe"
    entry_count = 1
    directories = [root]
    while directories:
        directory_path = directories.pop()
        topology.add((str(directory_path.absolute()), "directory"))
        try:
            entries = os.scandir(directory_path)
        except OSError:
            return topology, "unsafe"
        with entries:
            for entry in entries:
                entry_count += 1
                if entry_count > max_entries:
                    return topology, "limit"
                try:
                    child = pathlib.Path(entry.path).lstat()
                except OSError:
                    return topology, "unsafe"
                if stat.S_ISDIR(child.st_mode):
                    directories.append(pathlib.Path(entry.path))
                elif not stat.S_ISREG(child.st_mode):
                    return topology, "unsafe"
    return topology, None


def listed_files(
    module: object,
    arguments: list[str],
) -> tuple[list[tuple[pathlib.Path, str]], list[tuple[str, str]], list[str]]:
    listed: dict[str, tuple[pathlib.Path, int]] = {}
    topology: set[tuple[str, str]] = set()
    findings: list[str] = []
    for input_index, argument in enumerate(arguments, start=1):
        unique_paths = set(listed)
        unique_paths.update(path for path, _ in topology)
        remaining = MAX_ARTIFACT_ENTRIES - len(unique_paths)
        if remaining < 1:
            findings.append("artifact entry-count limit exceeded")
            break
        root = pathlib.Path(argument)
        files, errors = module.regular_files(root, remaining)
        root_topology, topology_error = topology_for_root(root, remaining)
        topology.update(root_topology)
        if "artifact entry-count limit exceeded" in errors or topology_error == "limit":
            findings.append("artifact entry-count limit exceeded")
        elif errors or topology_error is not None:
            findings.append(f"unsafe artifact input {input_index}")
        for path in files:
            absolute = str(path.absolute())
            listed.setdefault(absolute, (path, input_index))
        unique_paths = set(listed)
        unique_paths.update(path for path, _ in topology)
        if len(unique_paths) > MAX_ARTIFACT_ENTRIES:
            findings.append("artifact entry-count limit exceeded")
            break

    entries: list[tuple[pathlib.Path, str]] = []
    per_input: dict[int, int] = {}
    for key in sorted(listed, key=os.fsencode):
        path, input_index = listed[key]
        ordinal = per_input.get(input_index, 0) + 1
        per_input[input_index] = ordinal
        entries.append((path, f"input {input_index} entry {ordinal}"))
    return entries, sorted(topology), findings


def artifact_path_findings(
    module: object,
    files: list[tuple[pathlib.Path, str]],
    topology: list[tuple[str, str]],
    needles: object,
) -> list[str]:
    paths = {os.fsencode(str(path.absolute())) for path, _ in files}
    paths.update(os.fsencode(path) for path, _ in topology)
    findings: set[str] = set()
    for path in paths:
        for needle in needles:
            if any(path.find(variant) >= 0 for variant in needle.variants):
                findings.add(f"{needle.label} in artifact path")
        for label in module.known_pattern_labels(path):
            findings.add(f"pattern:{label} in artifact path")
        for label in module.decoded_known_pattern_labels(path):
            findings.add(f"encoded-pattern:{label} in artifact path")
    return sorted(findings)


def file_identity(metadata: os.stat_result) -> tuple[int, int, int, int, int, int]:
    return (
        metadata.st_dev,
        metadata.st_ino,
        metadata.st_mode,
        metadata.st_size,
        metadata.st_mtime_ns,
        metadata.st_ctime_ns,
    )


def captured_stream(source: int, work_directory: int, work_path: pathlib.Path) -> BinaryIO:
    os.lseek(source, 0, os.SEEK_SET)
    if FCLONEFILEAT is not None:
        name = f"capture-{secrets.token_hex(16)}".encode("ascii")
        if FCLONEFILEAT(source, work_directory, name, 0) == 0:
            descriptor = os.open(
                name,
                os.O_RDONLY | os.O_NOFOLLOW,
                dir_fd=work_directory,
            )
            os.unlink(name, dir_fd=work_directory)
            return os.fdopen(descriptor, "rb")
        clone_error = ctypes.get_errno()
        if clone_error not in CLONE_FALLBACK_ERRORS:
            raise OSError(clone_error, "artifact clone failed")

    os.lseek(source, 0, os.SEEK_SET)
    staged = tempfile.TemporaryFile(mode="w+b", dir=work_path)
    while chunk := os.read(source, 1024 * 1024):
        staged.write(chunk)
    staged.seek(0)
    return staged


def capture_file(
    module: object,
    path: pathlib.Path,
    label: str,
    needles: object,
    scan_bytes: bool,
    work_directory: int,
    work_path: pathlib.Path,
) -> tuple[dict[str, int | str], CapturedImage | None, list[str]]:
    before = path.lstat()
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    staged: BinaryIO | None = None
    digest = hashlib.sha256()
    prefix = b""
    findings: list[str] = []
    try:
        opened = os.fstat(descriptor)
        if (
            not stat.S_ISREG(opened.st_mode)
            or before.st_nlink != 1
            or opened.st_nlink != 1
            or file_identity(opened) != file_identity(before)
        ):
            raise OSError("artifact identity changed before capture")
        staged = captured_stream(descriptor, work_directory, work_path)
        while chunk := staged.read(1024 * 1024):
            if len(prefix) < len(PNG_SIGNATURE):
                prefix += chunk[: len(PNG_SIGNATURE) - len(prefix)]
            digest.update(chunk)
        after = os.fstat(descriptor)
        current = path.lstat()
        if (
            current.st_nlink != 1
            or file_identity(opened) != file_identity(after)
            or file_identity(opened) != file_identity(current)
        ):
            raise OSError("artifact identity changed during capture")
    except BaseException:
        if staged is not None:
            staged.close()
        raise
    finally:
        os.close(descriptor)

    if staged is None:
        raise OSError("artifact capture was not created")
    staged.seek(0)
    is_png = prefix == PNG_SIGNATURE
    if path.suffix.lower() == ".png" and not is_png:
        findings.append(f"invalid PNG: {label}")
    if scan_bytes:
        findings.extend(module.scan_descriptor(staged.fileno(), label, needles))
    entry: dict[str, int | str] = {
        "device": before.st_dev,
        "inode": before.st_ino,
        "mode": before.st_mode,
        "mtime_ns": before.st_mtime_ns,
        "ctime_ns": before.st_ctime_ns,
        "path": str(path.absolute()),
        "sha256": digest.hexdigest(),
        "size": before.st_size,
    }
    if is_png and before.st_size <= VISUAL_FILE_BYTES:
        staged.seek(0)
        return entry, CapturedImage(label=label, size=before.st_size, stream=staged), findings
    if is_png:
        findings.append(f"oversized PNG: {label}")
    staged.close()
    return entry, None, findings


def inventory_file(path: pathlib.Path) -> dict[str, int | str]:
    before = path.lstat()
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    digest = hashlib.sha256()
    try:
        opened = os.fstat(descriptor)
        if (
            not stat.S_ISREG(opened.st_mode)
            or before.st_nlink != 1
            or opened.st_nlink != 1
            or file_identity(opened) != file_identity(before)
        ):
            raise OSError("artifact identity changed before inventory")
        while chunk := os.read(descriptor, 1024 * 1024):
            digest.update(chunk)
        after = os.fstat(descriptor)
        current = path.lstat()
        if (
            current.st_nlink != 1
            or file_identity(opened) != file_identity(after)
            or file_identity(opened) != file_identity(current)
        ):
            raise OSError("artifact identity changed during inventory")
    finally:
        os.close(descriptor)
    return {
        "device": before.st_dev,
        "inode": before.st_ino,
        "mode": before.st_mode,
        "mtime_ns": before.st_mtime_ns,
        "ctime_ns": before.st_ctime_ns,
        "path": str(path.absolute()),
        "sha256": digest.hexdigest(),
        "size": before.st_size,
    }


def run_visual_batch(scanner: pathlib.Path, images: list[CapturedImage], original_only: bool) -> int:
    if not images:
        return 0
    command = [str(scanner)]
    if original_only:
        command.append("--original-only")
    descriptors: list[int] = []
    for index, image in enumerate(images, start=1):
        image.stream.seek(0)
        descriptor = image.stream.fileno()
        descriptors.append(descriptor)
        command.extend(("--input-fd", str(descriptor), f"input-{index}"))
    try:
        result = subprocess.run(
            command,
            check=False,
            capture_output=True,
            pass_fds=tuple(descriptors),
        )
        sys.stdout.buffer.write(result.stdout)
        sys.stdout.buffer.flush()
        sys.stderr.buffer.write(result.stderr)
        sys.stderr.buffer.flush()
        return result.returncode
    finally:
        for image in images:
            image.stream.close()


def capture_inventory(
    module: object,
    arguments: list[str],
) -> tuple[list[dict[str, int | str]], list[tuple[str, str]], list[str]]:
    files, topology, findings = listed_files(module, arguments)
    if findings:
        return [], topology, findings
    inventory: list[dict[str, int | str]] = []
    for path, label in files:
        try:
            inventory.append(inventory_file(path))
        except OSError:
            findings.append(f"artifact changed during inventory: {label}")
    after_files, after_topology, after_findings = listed_files(module, arguments)
    findings.extend(after_findings)
    if (
        [str(path.absolute()) for path, _ in files]
        != [str(path.absolute()) for path, _ in after_files]
        or topology != after_topology
    ):
        findings.append("artifact inventory changed during privacy scan")
    for entry in inventory:
        try:
            metadata = pathlib.Path(str(entry["path"])).lstat()
        except OSError:
            findings.append("artifact inventory changed during privacy scan")
            break
        if (
            metadata.st_nlink != 1
            or file_identity(metadata)
            != (
                entry["device"],
                entry["inode"],
                entry["mode"],
                entry["size"],
                entry["mtime_ns"],
                entry["ctime_ns"],
            )
        ):
            findings.append("artifact inventory changed during privacy scan")
            break
    return inventory, topology, findings


def report_findings(findings: list[str]) -> int:
    if findings:
        for finding in sorted(set(findings)):
            print(f"Artifact secret scan blocked retention: {finding}", file=sys.stderr)
        return 1
    print("artifact privacy scan: clean")
    return 0


def scan_captured_set(module: object, args: argparse.Namespace, work_descriptor: int) -> int:
    files, topology, findings = listed_files(module, args.inputs)
    if findings:
        return report_findings(findings)
    needles = module.environment_needles()
    findings.extend(artifact_path_findings(module, files, topology, needles))
    if findings:
        return report_findings(findings)
    inventory: list[dict[str, int | str]] = []
    images: list[CapturedImage] = []
    image_bytes = 0
    for path, label in files:
        try:
            entry, image, capture_findings = capture_file(
                module,
                path,
                label,
                needles,
                not args.visual_only,
                work_descriptor,
                args.work,
            )
        except OSError:
            capture_findings = [f"artifact changed during capture: {label}"]
            entry = {}
            image = None
        inventory.append(entry)
        findings.extend(capture_findings)
        if args.visual_only and image is None and not capture_findings:
            findings.append(f"visual input is not a PNG: {label}")
        if findings:
            for captured in images:
                captured.stream.close()
            if image is not None:
                image.stream.close()
            return report_findings(findings)
        if image is None:
            continue
        if images and (
            len(images) == VISUAL_BATCH_FILES
            or image_bytes + image.size > VISUAL_BATCH_BYTES
        ):
            if run_visual_batch(args.scanner, images, args.original_only) != 0:
                image.stream.close()
                return 1
            images = []
            image_bytes = 0
        images.append(image)
        image_bytes += image.size
    if run_visual_batch(args.scanner, images, args.original_only) != 0:
        return 1

    final_inventory, final_topology, final_findings = capture_inventory(module, args.inputs)
    findings.extend(final_findings)
    if inventory != final_inventory or topology != final_topology:
        findings.append("artifact inventory changed during privacy scan")
    return report_findings(findings)


def main() -> int:
    os.umask(0o077)
    try:
        args = parse_args()
        validate_scanner(args.scanner)
        work_descriptor = validate_work_directory(args.work)
        module = load_secret_scan()
        try:
            return scan_captured_set(module, args, work_descriptor)
        finally:
            os.close(work_descriptor)
    except (OSError, RuntimeError, ValueError):
        print("Artifact privacy scan failed closed.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
