#!/bin/bash -p
# Rehearse Claude's background-first handoff for gates that may cross 600s.
# The fake bridge models the external Bash tool and client completion event; it
# is not a Claude service test. The production contract lives in
# docs/claude-long-gates.md.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/claude-long-gate-rehearsal-XXXXXX")"

cleanup() {
  local pid_file pid
  for pid_file in "$SANDBOX"/tasks/*/worker-pid "$SANDBOX"/tasks/*/child-pid; do
    [[ -f "$pid_file" ]] || continue
    pid="$(sed -n '1p' "$pid_file" 2>/dev/null || true)"
    [[ "$pid" =~ ^[0-9]+$ ]] || continue
    kill -KILL "$pid" 2>/dev/null || true
  done
  rm -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

fail() {
  echo "claude long-gate rehearsal: $*" >&2
  exit 1
}

DOC="$ROOT/docs/claude-long-gates.md"
[[ -f "$DOC" ]] || fail "canonical Claude long-gate runbook is missing"
grep -Fq 'run_in_background' "$DOC" ||
  fail "runbook does not require background-first launch"
grep -Fq 'client completion notification' "$DOC" ||
  fail "runbook does not require the client completion notification"
grep -Fq '`TaskOutput` has a bounded client wait timeout' "$DOC" ||
  fail "runbook does not document the bounded TaskOutput limitation"
grep -Fq '600-second' "$DOC" ||
  fail "runbook does not name the foreground boundary"
grep -Fq 'no `sleep`, `monitor`, `tail`, or `pgrep`' "$DOC" ||
  fail "runbook does not prohibit polling helpers"

mkdir -p "$SANDBOX/bin" "$SANDBOX/tasks"

cat >"$SANDBOX/bin/fake-claude-bridge.py" <<'PY'
#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import time
import uuid
from pathlib import Path


ROOT = Path(os.environ["FAKE_BRIDGE_ROOT"])
CALLS = ROOT / "calls"
NOTIFICATIONS = ROOT / "notifications"


def record(line: str) -> None:
    with CALLS.open("a", encoding="utf-8") as handle:
        handle.write(line + "\n")


def task_dir(task_id: str) -> Path:
    path = ROOT / "tasks" / task_id
    path.mkdir(parents=True, exist_ok=False)
    return path


def worker(path: Path, command: list[str]) -> int:
    output = path / "raw-output"
    with output.open("wb") as output_handle:
        child = subprocess.Popen(
            command,
            stdout=output_handle,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        (path / "child-pid").write_text(str(child.pid) + "\n", encoding="utf-8")
        (path / "child-process-group").write_text(
            str(os.getpgid(child.pid)) + "\n", encoding="utf-8"
        )
        status = child.wait()
    (path / "status").write_text(str(status) + "\n", encoding="utf-8")
    # The named pipe is the fake TaskOutput completion event. The worker stays
    # owned by this task until the one waiter consumes the event.
    with (path / "completion").open("w", encoding="utf-8") as completion:
        completion.write("complete\n")
    return status


def launch(background: bool, command: list[str]) -> int:
    task_id = "task-" + uuid.uuid4().hex[:12]
    path = task_dir(task_id)
    os.mkfifo(path / "completion")
    (path / "ownership").write_text(
        "one-task\nstart_new_session=true\n", encoding="utf-8"
    )
    worker_process = subprocess.Popen(
        [sys.executable, __file__, "worker", str(path), "--", *command],
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
    (path / "worker-pid").write_text(str(worker_process.pid) + "\n", encoding="utf-8")
    if background:
        record("BASH run_in_background=true task=" + task_id)
        print(task_id)
        return 0

    # The real client would hold this foreground call until its outer boundary.
    # The rehearsal uses a short substitute so it never waits ten minutes.
    transition_at = time.monotonic() + 0.05
    while time.monotonic() < transition_at:
        time.sleep(0.005)
    record("BASH run_in_background=false transitioned_after=600s task=" + task_id)
    print(task_id)
    return 0


def deliver_completion(task_id: str, record_task_output: bool) -> int:
    path = ROOT / "tasks" / task_id
    if record_task_output:
        record("TASK_OUTPUT block=true task=" + task_id)
    with (path / "completion").open("r", encoding="utf-8") as completion:
        if completion.readline().strip() != "complete":
            return 1
    raw_output = (path / "raw-output").read_bytes()
    sys.stdout.buffer.write(raw_output)
    sys.stdout.buffer.flush()
    status = int((path / "status").read_text(encoding="utf-8").strip())
    if not record_task_output:
        with NOTIFICATIONS.open("a", encoding="utf-8") as handle:
            handle.write(f"CLAUDE_TASK_COMPLETE task={task_id} status={status}\n")
    return status


def wait_for_task(task_id: str) -> int:
    return deliver_completion(task_id, record_task_output=True)


def client_notification(task_id: str) -> int:
    # This blocking FIFO read models the hosted client's asynchronous event.
    # It is not another Claude tool call and performs no polling.
    return deliver_completion(task_id, record_task_output=False)


def legacy_helper(name: str) -> int:
    record("LEGACY_HELPER " + name)
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        return 2
    mode = sys.argv[1]
    if mode == "worker":
        separator = sys.argv.index("--")
        return worker(Path(sys.argv[2]), sys.argv[separator + 1 :])
    if mode == "launch":
        separator = sys.argv.index("--")
        background = sys.argv[2] == "background"
        return launch(background, sys.argv[separator + 1 :])
    if mode == "wait":
        return wait_for_task(sys.argv[2])
    if mode == "notification":
        return client_notification(sys.argv[2])
    if mode == "legacy-helper":
        return legacy_helper(sys.argv[2])
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
PY
chmod +x "$SANDBOX/bin/fake-claude-bridge.py"

cat >"$SANDBOX/bin/fake-long-gate" <<'EOF'
#!/bin/bash -p
set -euo pipefail
printf 'raw stdout: gate started\n'
printf 'raw stderr: diagnostic preserved\n' >&2
/usr/bin/python3 -c 'import time; time.sleep(0.15)'
printf 'raw stdout: gate finished\n'
exit 23
EOF
chmod +x "$SANDBOX/bin/fake-long-gate"

export FAKE_BRIDGE_ROOT="$SANDBOX"
BRIDGE=(/usr/bin/python3 "$SANDBOX/bin/fake-claude-bridge.py")

# This is the canonical path: one Bash launch with background ownership and
# one client completion event for that exact task ID. The fixture returns the
# event's status unchanged and writes only one completion notification. The
# event receiver is a blocking FIFO read, not another Claude tool call.
BACKGROUND_TASK="$("${BRIDGE[@]}" launch background -- "$SANDBOX/bin/fake-long-gate")"
BACKGROUND_OUTPUT="$SANDBOX/background-output"
BACKGROUND_STATUS=0
if "${BRIDGE[@]}" notification "$BACKGROUND_TASK" >"$BACKGROUND_OUTPUT" 2>"$SANDBOX/background-notification"; then
  BACKGROUND_STATUS=0
else
  BACKGROUND_STATUS=$?
fi
[[ "$BACKGROUND_STATUS" -eq 23 ]] ||
  fail "background completion notification changed gate status 23 to $BACKGROUND_STATUS"
cmp -s "$SANDBOX/tasks/$BACKGROUND_TASK/raw-output" "$BACKGROUND_OUTPUT" ||
  fail "background completion notification did not preserve raw gate bytes"
grep -Fqx 'raw stdout: gate started' "$BACKGROUND_OUTPUT" ||
  fail "background output lost stdout"
grep -Fqx 'raw stderr: diagnostic preserved' "$BACKGROUND_OUTPUT" ||
  fail "background output lost stderr"
grep -Fqx 'raw stdout: gate finished' "$BACKGROUND_OUTPUT" ||
  fail "background output lost the final line"
grep -Fxq "CLAUDE_TASK_COMPLETE task=$BACKGROUND_TASK status=23" "$SANDBOX/notifications" ||
  fail "background path did not produce its one completion notification"
[[ "$(wc -l <"$SANDBOX/notifications" | tr -d ' ')" -eq 1 ]] ||
  fail "background path produced more than one completion notification"
grep -Fxq "BASH run_in_background=true task=$BACKGROUND_TASK" "$SANDBOX/calls" ||
  fail "background path did not use the background Bash call"
if grep -Fxq "TASK_OUTPUT block=true task=$BACKGROUND_TASK" "$SANDBOX/calls"; then
  fail "background path used the bounded TaskOutput wait"
fi
grep -Fq 'one-task' "$SANDBOX/tasks/$BACKGROUND_TASK/ownership" ||
  fail "background task ownership was not recorded"
if grep -Eq '^LEGACY_HELPER ' "$SANDBOX/calls"; then
  fail "background path created a legacy polling helper"
fi

# Model one 600-second foreground transition with a short fixture boundary.
# These helper records are deliberately confined to the legacy comparison and
# are never used by the canonical path above.
LEGACY_TASK="$("${BRIDGE[@]}" launch foreground -- "$SANDBOX/bin/fake-long-gate")"
for helper in sleep monitor tail pgrep; do
  "${BRIDGE[@]}" legacy-helper "$helper"
done
LEGACY_OUTPUT="$SANDBOX/legacy-output"
LEGACY_STATUS=0
if "${BRIDGE[@]}" wait "$LEGACY_TASK" >"$LEGACY_OUTPUT" 2>/dev/null; then
  LEGACY_STATUS=0
else
  LEGACY_STATUS=$?
fi
[[ "$LEGACY_STATUS" -eq 23 ]] ||
  fail "foreground comparison changed gate status 23 to $LEGACY_STATUS"
cmp -s "$SANDBOX/tasks/$LEGACY_TASK/raw-output" "$LEGACY_OUTPUT" ||
  fail "foreground comparison did not preserve raw gate bytes"

BACKGROUND_TOOL_CALLS="$(grep -E "^BASH run_in_background=true task=$BACKGROUND_TASK$" "$SANDBOX/calls" | wc -l | tr -d ' ')"
FOREGROUND_TOOL_CALLS="$(grep -E "^(BASH run_in_background=false|TASK_OUTPUT block=true task=$LEGACY_TASK|LEGACY_HELPER )" "$SANDBOX/calls" | wc -l | tr -d ' ')"
[[ "$BACKGROUND_TOOL_CALLS" -eq 1 ]] ||
  fail "background path used $BACKGROUND_TOOL_CALLS tool calls instead of 1"
[[ "$FOREGROUND_TOOL_CALLS" -eq 6 ]] ||
  fail "foreground transition comparison used $FOREGROUND_TOOL_CALLS calls instead of 6"
[[ "$(wc -l <"$SANDBOX/notifications" | tr -d ' ')" -eq 1 ]] ||
  fail "background path produced more than one client completion notification"

echo "CLAUDE_BACKGROUND_TOOL_CALLS=$BACKGROUND_TOOL_CALLS"
echo "CLAUDE_FOREGROUND_TRANSITION_TOOL_CALLS=$FOREGROUND_TOOL_CALLS"
echo "CLAUDE_TOOL_CALLS_SAVED=$((FOREGROUND_TOOL_CALLS - BACKGROUND_TOOL_CALLS))"
echo "CLAUDE_POLLING_HELPER_CALLS_SAVED=4"
echo "CLAUDE_COMPLETION_NOTIFICATIONS=1"
echo "claude long-gate rehearsal: passed"
