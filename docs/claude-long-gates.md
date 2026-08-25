# Claude Long Gates

This is the canonical handoff for a repository gate that may run longer than
Claude's 600-second foreground Bash boundary. The gate command remains a bare
repository command. Claude's client owns the background task and its completion
notification, while the repository gate owns its process group, timeout,
heartbeat, and exit status.

## Canonical Invocation

Start the gate as a background task from the first Claude Bash tool call. Do
not start it in the foreground and wait for Claude to move it later.

```text
Bash(
  command="scripts/snapshot.sh Features ReviewTests",
  run_in_background=true
)
```

Use the same shape for another long gate, replacing only the bare command:

```text
Bash(command="scripts/test.sh all", run_in_background=true)
Bash(command="scripts/build.sh", run_in_background=true)
Bash(command="scripts/ui-test.sh", run_in_background=true)
Bash(command="scripts/review.sh --output artifacts/codex-review.md --base origin/main", run_in_background=true)
```

The Bash tool returns one exact task ID. For a gate that may cross the
600-second boundary, leave that task under the client's ownership. The client completion notification arrives when the exact task exits. Do not issue a
second live-wait tool call for this path. The notification must preserve the
task ID, the gate's raw output, and its non-zero exit status. A successful gate
ends with its normal `GATE_END ... status=0` receipt. A failed or timed-out
gate keeps its original status, such as `65` or `124`; do not infer success
from a later diagnostic command.

`TaskOutput` has a bounded client wait timeout. It is not a valid completion
path for a gate that may use the repository's 20-minute ceiling: a single
wait can return while the task is still live, and repeated waits recreate the
polling churn this contract removes. Use `TaskOutput` only for a command known
to finish within its configured client timeout, never for the canonical
long-gate path.

## Hard Rules

- Pass the gate command directly as the Bash tool command. Do not use shell
  `&`, `nohup`, `disown`, a wrapper daemon, or a pipeline.
- Use the client's one exact task completion notification. The path uses no `sleep`, `monitor`, `tail`, or `pgrep` calls while waiting.
- Do not launch a replacement gate while the task is still live.
- Read raw output from the completion notification or the gate's retained
  artifact after the task completes. Do not filter the gate command through
  `tail`, `grep`, or `head` to make the output smaller.
- If the task reports a failure, keep that status and inspect the retained
  output before deciding whether a new invocation is justified.

## Call-Count Comparison

The repository rehearsal uses a short substitute boundary so it completes in
seconds, but labels the legacy transition as the real 600-second boundary.
With the client completion-notification path, the background-first sequence is
one Claude tool call: the Bash launch. The asynchronous completion notification
is not a second tool call. It produces one completion notification and creates
no polling helper.

The comparison sequence models one foreground launch that crosses the
boundary, one completion wait, and the four helpers observed in the audit
(`sleep`, `monitor`, `tail`, and `pgrep`):

| Path | Tool calls | Completion notifications | Polling helpers |
|---|---:|---:|---:|
| Background from first call | 1 | 1 | 0 |
| Foreground 600-second transition | 6 | 1 | 4 |

This is a lower-bound comparison for the observed recovery pattern, not a
benchmark of Claude internals. Run the disposable proof with:

```sh
scripts/tests/claude-long-gate-rehearsal.sh
```

The rehearsal verifies the exact task ID is completed, raw stdout and stderr
are unchanged, exit status `23` survives the client notification, one
notification is emitted, and the background path creates no legacy helper
calls. It uses a fake bridge because the repository cannot exercise Claude's
hosted Bash implementation in CI.
