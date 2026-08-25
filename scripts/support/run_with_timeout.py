#!/usr/bin/python3 -I
"""Run one process group with streamed output, a log, and a hard timeout."""

from __future__ import annotations

import argparse
import os
import selectors
import signal
import stat
import subprocess
import sys
import time
from pathlib import Path


class ForwardedSignal(Exception):
    def __init__(self, signum: int) -> None:
        self.signum = signum


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--timeout", required=True, type=int)
    parser.add_argument("--log", required=True, type=Path)
    parser.add_argument("--inherit-process-group", action="store_true")
    parser.add_argument("--pass-fd", action="append", default=[], type=int)
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.command[:1] == ["--"]:
        args.command = args.command[1:]
    if args.timeout < 1 or not args.command:
        parser.error("timeout must be positive and a command is required")
    if len(set(args.pass_fd)) != len(args.pass_fd) or any(fd < 3 for fd in args.pass_fd):
        parser.error("pass-fd values must be unique open descriptors above 2")
    for fd in args.pass_fd:
        try:
            metadata = os.fstat(fd)
        except OSError as error:
            parser.error(f"pass-fd {fd} is not open: {error}")
        if not stat.S_ISREG(metadata.st_mode):
            parser.error(f"pass-fd {fd} must reference a regular file")
    return args


def group_exists(group_id: int) -> bool:
    try:
        os.killpg(group_id, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def signal_group(group_id: int, sent_signal: signal.Signals) -> None:
    try:
        os.killpg(group_id, sent_signal)
    except (PermissionError, ProcessLookupError):
        pass


def terminate_group(process: subprocess.Popen[bytes]) -> None:
    # The process-group leader may already have exited while a child still owns
    # stdout. Signal the group ID regardless of the leader's current state.
    signal_group(process.pid, signal.SIGTERM)
    deadline = time.monotonic() + 3
    while time.monotonic() < deadline:
        process.poll()
        if not group_exists(process.pid):
            break
        time.sleep(0.05)
    if group_exists(process.pid):
        signal_group(process.pid, signal.SIGKILL)
    try:
        process.wait(timeout=1)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def terminate_process(process: subprocess.Popen[bytes]) -> None:
    if process.poll() is not None:
        return
    process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()


def terminate_inherited_group(process: subprocess.Popen[bytes]) -> None:
    """Ask our caller-owned group to stop without killing this supervisor."""
    group_id = os.getpgrp()
    if group_id != os.getpid():
        raise RuntimeError("inherit-process-group requires this supervisor to lead its group")
    previous = signal.getsignal(signal.SIGTERM)
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    try:
        signal_group(group_id, signal.SIGTERM)
    finally:
        signal.signal(signal.SIGTERM, previous)
    terminate_process(process)


def main() -> int:
    args = parse_args()
    args.log.parent.mkdir(parents=True, exist_ok=True)
    started = time.monotonic()
    process: subprocess.Popen[bytes] | None = None
    selector = selectors.DefaultSelector()
    timed_out = False
    watched_signals = (signal.SIGHUP, signal.SIGINT, signal.SIGTERM)
    previous_handlers = {sent_signal: signal.getsignal(sent_signal) for sent_signal in watched_signals}

    def forward_signal(signum: int, _frame: object) -> None:
        raise ForwardedSignal(signum)

    for sent_signal in watched_signals:
        signal.signal(sent_signal, forward_signal)

    if args.inherit_process_group and os.getpgrp() != os.getpid():
        raise RuntimeError("inherit-process-group requires a dedicated process-group leader")

    try:
        with args.log.open("wb") as log:
            previous_mask = signal.pthread_sigmask(signal.SIG_BLOCK, watched_signals)

            def restore_child_signal_mask() -> None:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)

            try:
                process = subprocess.Popen(
                    args.command,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    start_new_session=not args.inherit_process_group,
                    pass_fds=tuple(args.pass_fd),
                    preexec_fn=restore_child_signal_mask,
                )
            finally:
                signal.pthread_sigmask(signal.SIG_SETMASK, previous_mask)
            assert process.stdout is not None
            selector.register(process.stdout, selectors.EVENT_READ)
            stdout_open = True
            while (
                stdout_open
                or process.poll() is None
                or (not args.inherit_process_group and group_exists(process.pid))
            ):
                remaining = args.timeout - (time.monotonic() - started)
                if remaining <= 0:
                    timed_out = True
                    message = f"Command timed out after {args.timeout} seconds.\n".encode()
                    sys.stdout.buffer.write(message)
                    sys.stdout.buffer.flush()
                    log.write(message)
                    log.flush()
                    if args.inherit_process_group:
                        terminate_inherited_group(process)
                    else:
                        terminate_group(process)
                    break

                for key, _ in selector.select(timeout=min(0.25, remaining)):
                    chunk = os.read(key.fd, 65536)
                    if chunk:
                        sys.stdout.buffer.write(chunk)
                        sys.stdout.buffer.flush()
                        log.write(chunk)
                        log.flush()
                    else:
                        selector.unregister(key.fileobj)
                        stdout_open = False

    except ForwardedSignal as interruption:
        if process is not None:
            if args.inherit_process_group:
                terminate_inherited_group(process)
            else:
                terminate_group(process)
        return 128 + interruption.signum
    except BaseException:
        if process is not None:
            if args.inherit_process_group:
                terminate_inherited_group(process)
            else:
                terminate_group(process)
        raise
    finally:
        selector.close()
        for sent_signal, previous in previous_handlers.items():
            signal.signal(sent_signal, previous)

    if timed_out:
        return 124
    assert process is not None
    returncode = process.returncode or 0
    return 128 + abs(returncode) if returncode < 0 else returncode


if __name__ == "__main__":
    raise SystemExit(main())
