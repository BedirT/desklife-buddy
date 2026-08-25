#!/bin/bash -p
# Mutual exclusion for anything that mutates the shared worktree list.
#
# integrate.sh, worktree-start.sh, and worktree-clean.sh --prune all decide
# from a `git worktree list` snapshot and act on it later. Unserialized, one
# of them can act on a state another has already changed - the observed case
# (#38) is --prune deciding a path is safe to delete, worktree-start reusing
# that path mid-pass, and the fallback rm -rf taking out the live checkout.
#
# mkdir-based because macOS has no flock. A crashed holder leaves a pid whose
# process is gone - cleared, one reaper at a time; a live holder is waited on.
# The lock dir keeps its historical name so a mixed-version fleet still
# excludes correctly.
#
# Source from sibling scripts (after ROOT is set), then:
#   acquire_worktree_lock <operation> [max-wait-seconds]   # returns 1 on timeout
#   release_worktree_lock                                  # safe in an EXIT trap
#
# Default wait is WORKTREE_LOCK_WAIT (900s). The operation name lands in the
# lock's `op` file so waiters and refusals can say who is holding it.

WORKTREE_LOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && git rev-parse --path-format=absolute --git-common-dir)/agent-integrate.lock"
WORKTREE_LOCK_HELD=0

worktree_lock_holder() {
  local pid op
  pid="$(cat "$WORKTREE_LOCK_DIR/pid" 2>/dev/null || echo "")"
  op="$(cat "$WORKTREE_LOCK_DIR/op" 2>/dev/null || echo "?")"
  echo "$op (pid ${pid:-?})"
}

# Liveness, not signalability: `kill -0` fails with EPERM for a live process
# under another uid, and reading that as "gone" clears a lock whose holder is
# mid-mutation. `ps -p` answers existence regardless of ownership.
worktree_lock_pid_alive() { ps -p "$1" >/dev/null 2>&1; }

acquire_worktree_lock() {
  local op="$1"
  local max_wait="${2:-${WORKTREE_LOCK_WAIT:-900}}"
  local waited=0 owner current
  while ! mkdir "$WORKTREE_LOCK_DIR" 2>/dev/null; do
    # A lock with no pid yet is a holder mid-acquire, not a stale lock: the
    # `-n` guard makes that read as live, which waits - the safe direction.
    owner="$(cat "$WORKTREE_LOCK_DIR/pid" 2>/dev/null || echo "")"
    if [[ -n "$owner" ]] && ! worktree_lock_pid_alive "$owner"; then
      # Clearing a stale lock must itself be serialized: two waiters that both
      # read the dead pid would otherwise take turns at rm -rf - the second
      # deleting the lock the first has just legitimately re-acquired, and
      # mutual exclusion is gone exactly where it matters. One reaper at a
      # time, and it re-reads the pid inside: unchanged-and-dead authorises
      # the clear; changed or empty means someone re-acquired - leave it.
      if mkdir "$WORKTREE_LOCK_DIR.reap" 2>/dev/null; then
        current="$(cat "$WORKTREE_LOCK_DIR/pid" 2>/dev/null || echo "")"
        if [[ "$current" == "$owner" ]] && ! worktree_lock_pid_alive "$current"; then
          echo "$op: clearing stale worktree lock (pid $owner is gone)" >&2
          rm -rf "${WORKTREE_LOCK_DIR:?}"
        fi
        rmdir "$WORKTREE_LOCK_DIR.reap" 2>/dev/null || true
        continue
      fi
      # Another waiter is reaping right now - fall through to the timed wait
      # rather than spinning, so a leaked reap dir still ends in a timeout.
    fi
    [[ "$waited" -eq 0 ]] &&
      echo "$op: waiting for the worktree lock, held by $(worktree_lock_holder)…" >&2
    sleep 5
    waited=$((waited + 5))
    if [[ "$waited" -ge "$max_wait" ]]; then
      echo "$op: timed out after ${max_wait}s waiting for the worktree lock, held by $(worktree_lock_holder)" >&2
      echo "$op: if that holder is really gone, clear it by hand:" >&2
      echo "$op:   rm -rf '$WORKTREE_LOCK_DIR' '$WORKTREE_LOCK_DIR.reap'" >&2
      return 1
    fi
  done
  WORKTREE_LOCK_HELD=1
  echo "$$" >"$WORKTREE_LOCK_DIR/pid"
  printf '%s\n' "$op" >"$WORKTREE_LOCK_DIR/op"
}

release_worktree_lock() {
  [[ "$WORKTREE_LOCK_HELD" -eq 1 ]] || return 0
  WORKTREE_LOCK_HELD=0
  rm -rf "${WORKTREE_LOCK_DIR:?}"
}
