#!/usr/bin/env python3
"""Run one repository gate in a bounded, observable process group."""

from __future__ import annotations

import argparse
import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import time
from pathlib import Path


EXIT_BUSY = 75
EXIT_ORPHAN = 76
EXIT_TIMEOUT = 124
SAFE_NAME = re.compile(r"^[A-Za-z0-9_.-]+$")


def positive_integer(value: str) -> int:
    parsed = int(value)
    if parsed < 1:
        raise argparse.ArgumentTypeError("must be a positive integer")
    return parsed


def process_start(pid: int) -> str:
    completed = subprocess.run(
        ["/bin/ps", "-o", "lstart=", "-p", str(pid)],
        capture_output=True,
        check=False,
        text=True,
    )
    return completed.stdout.strip()


def group_alive(group: int) -> bool:
    try:
        os.killpg(group, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def terminate_group(group: int, grace: int) -> None:
    if not group_alive(group):
        return
    try:
        os.killpg(group, signal.SIGTERM)
    except (PermissionError, ProcessLookupError):
        return

    deadline = time.monotonic() + grace
    while time.monotonic() < deadline:
        if not group_alive(group):
            return
        time.sleep(0.05)

    try:
        os.killpg(group, signal.SIGKILL)
    except (PermissionError, ProcessLookupError):
        return


def read_metadata(handle) -> dict[str, object]:
    try:
        handle.seek(0)
        value = json.load(handle)
        return value if isinstance(value, dict) else {}
    except (json.JSONDecodeError, OSError, TypeError):
        return {}


def publish_metadata(handle, value: dict[str, object]) -> None:
    handle.seek(0)
    handle.truncate()
    json.dump(value, handle, sort_keys=True)
    handle.write("\n")
    handle.flush()
    os.fsync(handle.fileno())


def acquire_lock(path: Path, name: str):
    path.parent.mkdir(parents=True, exist_ok=True)
    handle = path.open("a+", encoding="utf-8")
    try:
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        owner = read_metadata(handle)
        print(
            f"GATE_BUSY name={name} owner_pid={owner.get('owner_pid', '?')} "
            f"child_pid={owner.get('child_pid', '?')} lock={path}",
            file=sys.stderr,
            flush=True,
        )
        handle.close()
        raise SystemExit(EXIT_BUSY)

    previous = read_metadata(handle)
    previous_group = previous.get("child_pid")
    previous_start = previous.get("child_start")
    if isinstance(previous_group, int) and previous_group > 0 and group_alive(previous_group):
        current_start = process_start(previous_group)
        if not current_start or current_start == previous_start:
            print(
                f"GATE_ORPHAN name={name} child_pid={previous_group} lock={path}",
                file=sys.stderr,
                flush=True,
            )
            handle.close()
            raise SystemExit(EXIT_ORPHAN)
    return handle


def normalized_status(returncode: int) -> int:
    return returncode if returncode >= 0 else 128 + abs(returncode)


def run(arguments: argparse.Namespace) -> int:
    command = list(arguments.command)
    if command and command[0] == "--":
        command = command[1:]
    if not command:
        print("command-supervisor: command is required", file=sys.stderr)
        return 2

    lock_handle = None
    if arguments.lock is not None:
        lock_handle = acquire_lock(arguments.lock, arguments.name)

    child: subprocess.Popen[bytes] | None = None
    received_signal: int | None = None

    def remember_signal(signum, _frame) -> None:
        nonlocal received_signal
        if received_signal is None:
            received_signal = signum

    previous_handlers = {
        signum: signal.signal(signum, remember_signal)
        for signum in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
    }

    started = time.monotonic()
    watch_pattern = (
        re.compile(arguments.watch_pattern, re.MULTILINE)
        if arguments.watch_pattern is not None
        else None
    )
    watch_offset = 0
    watch_remainder = ""
    watch_started: float | None = None
    status = 1
    try:
        child = subprocess.Popen(command, start_new_session=True)
        child_start = process_start(child.pid)
        if lock_handle is not None:
            publish_metadata(
                lock_handle,
                {
                    "child_pid": child.pid,
                    "child_start": child_start,
                    "cwd": os.getcwd(),
                    "name": arguments.name,
                    "owner_pid": os.getpid(),
                    "owner_start": process_start(os.getpid()),
                    "started_at": int(time.time()),
                },
            )

        print(
            f"GATE_START name={arguments.name} child_pid={child.pid} "
            f"timeout={arguments.timeout}s cwd={os.getcwd()}",
            flush=True,
        )
        deadline = started + arguments.timeout
        next_heartbeat = started + arguments.heartbeat

        while True:
            now = time.monotonic()
            elapsed = max(0, int(now - started))
            returncode = child.poll()
            if received_signal is not None:
                print(
                    f"GATE_SIGNAL name={arguments.name} signal={received_signal} "
                    f"elapsed={elapsed}s child_pid={child.pid}",
                    file=sys.stderr,
                    flush=True,
                )
                terminate_group(child.pid, arguments.grace)
                child.wait()
                status = 128 + received_signal
                break

            if returncode is not None:
                status = normalized_status(returncode)
                break

            if watch_pattern is not None and watch_started is None:
                try:
                    current_size = arguments.watch_file.stat().st_size
                    if current_size < watch_offset:
                        watch_offset = 0
                        watch_remainder = ""
                    if current_size > watch_offset:
                        with arguments.watch_file.open("rb") as watch_handle:
                            watch_handle.seek(watch_offset)
                            appended = watch_handle.read().decode(
                                "utf-8", errors="replace"
                            )
                            watch_offset = watch_handle.tell()
                        candidate = watch_remainder + appended
                        if watch_pattern.search(candidate):
                            watch_started = now
                            print(
                                f"GATE_WATCH_START name={arguments.name} "
                                f"timeout={arguments.watch_timeout}s "
                                f"child_pid={child.pid}",
                                file=sys.stderr,
                                flush=True,
                            )
                        watch_remainder = candidate[-4096:]
                except FileNotFoundError:
                    pass
                except OSError as error:
                    print(
                        f"command-supervisor: could not read watch file: {error}",
                        file=sys.stderr,
                        flush=True,
                    )
                    terminate_group(child.pid, arguments.grace)
                    child.wait()
                    status = 1
                    break

            if (
                watch_started is not None
                and now >= watch_started + arguments.watch_timeout
            ):
                watch_elapsed = max(0, int(now - watch_started))
                print(
                    f"GATE_WATCH_TIMEOUT name={arguments.name} "
                    f"elapsed={elapsed}s watch_elapsed={watch_elapsed}s "
                    f"child_pid={child.pid}",
                    file=sys.stderr,
                    flush=True,
                )
                terminate_group(child.pid, arguments.grace)
                child.wait()
                status = EXIT_TIMEOUT
                break

            if now >= next_heartbeat:
                print(
                    f"GATE_HEARTBEAT name={arguments.name} elapsed={elapsed}s "
                    f"child_pid={child.pid}",
                    file=sys.stderr,
                    flush=True,
                )
                while next_heartbeat <= now:
                    next_heartbeat += arguments.heartbeat

            if now >= deadline:
                print(
                    f"GATE_TIMEOUT name={arguments.name} elapsed={elapsed}s "
                    f"child_pid={child.pid}",
                    file=sys.stderr,
                    flush=True,
                )
                terminate_group(child.pid, arguments.grace)
                child.wait()
                status = EXIT_TIMEOUT
                break

            time.sleep(0.1)
    except FileNotFoundError:
        status = 127
    except OSError as error:
        print(f"command-supervisor: {error}", file=sys.stderr)
        status = 1
    finally:
        if child is not None:
            # A successful launcher can still leave xcodebuild descendants in
            # its session. Own the whole process group, not only the direct child.
            if group_alive(child.pid):
                terminate_group(child.pid, arguments.grace)
            if child.poll() is None:
                child.wait()
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
        if lock_handle is not None:
            lock_handle.close()

    elapsed = max(0, int(time.monotonic() - started))
    print(
        f"GATE_END name={arguments.name} status={status} elapsed={elapsed}s",
        flush=True,
    )
    return status


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    parser.add_argument("--timeout", required=True, type=positive_integer)
    parser.add_argument("--heartbeat", required=True, type=positive_integer)
    parser.add_argument("--grace", required=True, type=positive_integer)
    parser.add_argument("--lock", type=Path)
    parser.add_argument("--watch-file", type=Path)
    parser.add_argument("--watch-pattern")
    parser.add_argument("--watch-timeout", type=positive_integer)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    arguments = parser.parse_args()
    if not SAFE_NAME.fullmatch(arguments.name):
        parser.error("--name may contain only letters, digits, dot, underscore, and hyphen")
    watch_arguments = (
        arguments.watch_file,
        arguments.watch_pattern,
        arguments.watch_timeout,
    )
    if any(value is not None for value in watch_arguments) and not all(
        value is not None for value in watch_arguments
    ):
        parser.error(
            "--watch-file, --watch-pattern, and --watch-timeout must be provided together"
        )
    if arguments.watch_pattern is not None:
        try:
            re.compile(arguments.watch_pattern)
        except re.error as error:
            parser.error(f"--watch-pattern is not a valid regular expression: {error}")
    return arguments


if __name__ == "__main__":
    raise SystemExit(run(parse_arguments()))
