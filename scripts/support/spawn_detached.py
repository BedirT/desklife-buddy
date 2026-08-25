#!/usr/bin/python3 -I
"""Spawn one detached process and print its exact, exec-stable PID."""

from __future__ import annotations

import os
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: spawn_detached.py <command> [arguments...]", file=sys.stderr)
        return 2

    read_fd, write_fd = os.pipe()
    os.set_inheritable(write_fd, False)
    pid = os.fork()
    if pid == 0:
        os.close(read_fd)
        try:
            os.setsid()
            null_fd = os.open(os.devnull, os.O_RDWR)
            for descriptor in (0, 1, 2):
                os.dup2(null_fd, descriptor)
            if null_fd > 2:
                os.close(null_fd)
            os.execv(sys.argv[1], sys.argv[1:])
        except BaseException as error:
            message = f"{type(error).__name__}: {error}".encode("utf-8", errors="replace")
            try:
                os.write(write_fd, message[:4096])
            finally:
                os._exit(127)

    os.close(write_fd)
    error = os.read(read_fd, 4096)
    os.close(read_fd)
    if error:
        os.waitpid(pid, 0)
        print("Detached process failed before exec: " + error.decode("utf-8", errors="replace"), file=sys.stderr)
        return 1
    print(pid)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
