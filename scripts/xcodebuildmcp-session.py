#!/usr/bin/python3 -I
"""Own one XcodeBuildMCP child and reap it when MCP stdio closes."""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import threading
import time
from typing import BinaryIO


def _seconds(name: str, default: float) -> float:
    try:
        return max(0.0, float(os.environ.get(name, default)))
    except ValueError:
        return default


def _relay(source: BinaryIO, target: BinaryIO) -> None:
    read_available = getattr(source, "read1", source.read)
    try:
        while data := read_available(64 * 1024):
            target.write(data)
            target.flush()
    except (BrokenPipeError, OSError):
        pass
    finally:
        try:
            target.close()
        except OSError:
            pass


def _stop_group(process: subprocess.Popen[bytes], grace_seconds: float) -> None:
    """Stop only the process group created for this wrapper invocation."""
    if process.poll() is not None:
        return

    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        return

    deadline = time.monotonic() + grace_seconds
    while process.poll() is None and time.monotonic() < deadline:
        time.sleep(0.02)

    if process.poll() is None:
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass


def main() -> int:
    arguments = sys.argv[1:]
    if arguments[:1] == ["--"]:
        arguments = arguments[1:]
    if not arguments:
        print("usage: xcodebuildmcp-session.py -- <reviewed-launcher> [arguments...]", file=sys.stderr)
        return 2
    command = arguments
    grace_seconds = _seconds("XCODEBUILDMCP_SHUTDOWN_GRACE_SECONDS", 1.0)

    try:
        process = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            start_new_session=True,
        )
    except OSError as error:
        print(f"failed to start XcodeBuildMCP: {error}", file=sys.stderr)
        return 127

    assert process.stdin is not None
    assert process.stdout is not None
    assert process.stderr is not None

    stdin_closed = threading.Event()
    stop_requested = threading.Event()

    def relay_stdin() -> None:
        try:
            _relay(sys.stdin.buffer, process.stdin)
        finally:
            stdin_closed.set()

    def request_stop(_signum: int, _frame: object) -> None:
        stop_requested.set()

    signal.signal(signal.SIGINT, request_stop)
    signal.signal(signal.SIGTERM, request_stop)

    threads = [
        threading.Thread(target=relay_stdin, daemon=True),
        threading.Thread(
            target=_relay,
            args=(process.stdout, sys.stdout.buffer),
            daemon=True,
        ),
        threading.Thread(
            target=_relay,
            args=(process.stderr, sys.stderr.buffer),
            daemon=True,
        ),
    ]
    for thread in threads:
        thread.start()

    ended_by_client = False
    try:
        while process.poll() is None:
            if stop_requested.is_set():
                break
            if stdin_closed.wait(0.1):
                ended_by_client = True
                break
    finally:
        _stop_group(process, grace_seconds)
        try:
            process.wait(timeout=max(grace_seconds, 0.1))
        except subprocess.TimeoutExpired:
            _stop_group(process, 0.0)
            process.wait()
        for thread in threads[1:]:
            thread.join(timeout=grace_seconds)
        for stream in (process.stdin, process.stdout, process.stderr):
            try:
                stream.close()
            except OSError:
                pass

    if ended_by_client:
        return 0
    if stop_requested.is_set():
        return 128 + signal.SIGTERM
    return process.returncode or 0


if __name__ == "__main__":
    raise SystemExit(main())
