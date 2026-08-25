#!/usr/bin/python3 -I
"""Hash one immutable runtime tree while rejecting unsafe filesystem entries."""

from __future__ import annotations

import hashlib
import os
import stat
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise RuntimeError(message)


def validate(metadata: os.stat_result, expected_type: str, path: Path) -> None:
    if metadata.st_uid != os.getuid():
        fail(f"unexpected owner: {path}")
    if metadata.st_mode & 0o022:
        fail(f"group- or world-writable entry: {path}")
    if expected_type == "directory" and not stat.S_ISDIR(metadata.st_mode):
        fail(f"non-directory entry: {path}")
    if expected_type == "file":
        if not stat.S_ISREG(metadata.st_mode):
            fail(f"non-regular file entry: {path}")
        if metadata.st_nlink != 1:
            fail(f"multiply linked file entry: {path}")


def add_header(digest: hashlib._Hash, kind: bytes, relative: bytes, metadata: os.stat_result) -> None:
    digest.update(kind)
    digest.update(len(relative).to_bytes(8, "big"))
    digest.update(relative)
    digest.update((metadata.st_mode & 0o777).to_bytes(2, "big"))


def tree_digest(root: Path) -> str:
    root_metadata = root.lstat()
    validate(root_metadata, "directory", root)
    digest = hashlib.sha256()
    add_header(digest, b"D", b"", root_metadata)

    for current, directories, files in os.walk(root, topdown=True, followlinks=False):
        directories.sort(key=os.fsencode)
        files.sort(key=os.fsencode)
        current_path = Path(current)

        for name in directories:
            path = current_path / name
            metadata = path.lstat()
            validate(metadata, "directory", path)
            relative = os.fsencode(path.relative_to(root).as_posix())
            add_header(digest, b"D", relative, metadata)

        for name in files:
            path = current_path / name
            before = path.lstat()
            validate(before, "file", path)
            relative = os.fsencode(path.relative_to(root).as_posix())
            add_header(digest, b"F", relative, before)
            digest.update(before.st_size.to_bytes(8, "big"))

            descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
            try:
                opened = os.fstat(descriptor)
                if (opened.st_dev, opened.st_ino, opened.st_size) != (
                    before.st_dev,
                    before.st_ino,
                    before.st_size,
                ):
                    fail(f"file changed before hashing: {path}")
                while chunk := os.read(descriptor, 1024 * 1024):
                    digest.update(chunk)
                after = os.fstat(descriptor)
                if (
                    after.st_dev,
                    after.st_ino,
                    after.st_size,
                    after.st_mtime_ns,
                    after.st_mode,
                    after.st_nlink,
                ) != (
                    before.st_dev,
                    before.st_ino,
                    before.st_size,
                    before.st_mtime_ns,
                    before.st_mode,
                    before.st_nlink,
                ):
                    fail(f"file changed while hashing: {path}")
            finally:
                os.close(descriptor)

    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: tree_digest.py <directory>", file=sys.stderr)
        return 2
    try:
        print(tree_digest(Path(sys.argv[1])))
    except (OSError, RuntimeError, ValueError) as error:
        print(f"tree_digest: {error}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
