#!/usr/bin/python3 -I
"""Start a command as the leader of an isolated process group."""

from __future__ import annotations

import os
import pathlib
import stat
import sys
import tempfile


def publish_owner(path: pathlib.Path) -> None:
    parent = path.parent
    metadata = parent.lstat()
    if not stat.S_ISDIR(metadata.st_mode) or parent.is_symlink() or metadata.st_uid != os.getuid():
        raise RuntimeError("owner-file parent is unsafe")
    temporary: pathlib.Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            "w", dir=parent, prefix=".owner.", delete=False, encoding="ascii"
        ) as candidate:
            temporary = pathlib.Path(candidate.name)
            candidate.write(f"{os.getpid()}\n")
            candidate.flush()
            os.fsync(candidate.fileno())
        os.chmod(temporary, 0o600)
        os.replace(temporary, path)
        published = path.lstat()
        if (
            not stat.S_ISREG(published.st_mode)
            or published.st_uid != os.getuid()
            or published.st_nlink != 1
            or stat.S_IMODE(published.st_mode) != 0o600
        ):
            raise RuntimeError("published owner file is unsafe")
    finally:
        if temporary is not None:
            try:
                temporary.unlink()
            except FileNotFoundError:
                pass


def main() -> int:
    arguments = sys.argv[1:]
    owner_file: pathlib.Path | None = None
    if arguments[:1] == ["--owner-file"]:
        if len(arguments) < 4 or arguments[2] != "--":
            print(
                "usage: start_process_group.py [--owner-file PATH --] <command> [arguments...]",
                file=sys.stderr,
            )
            return 2
        owner_file = pathlib.Path(arguments[1])
        arguments = arguments[3:]
    if not arguments:
        print(
            "usage: start_process_group.py [--owner-file PATH --] <command> [arguments...]",
            file=sys.stderr,
        )
        return 2
    try:
        os.setsid()
    except PermissionError:
        if os.getpgrp() != os.getpid():
            raise
    if os.getpgrp() != os.getpid():
        raise RuntimeError("failed to establish a private process group")
    if owner_file is not None:
        publish_owner(owner_file)
    os.execvpe(arguments[0], arguments, os.environ)
    return 127


if __name__ == "__main__":
    raise SystemExit(main())
