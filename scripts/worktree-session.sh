#!/bin/bash -p
# Liveness marker for a task worktree: "an agent session is checked in here".
#
# scripts/worktree-clean.sh --prune removes a worktree that is clean and whose
# commits have landed. That is correct on the facts it has - and "landed and
# clean" is exactly the state a session is in AFTER its PR merges and BEFORE it
# finishes reporting, which is the normal end of every task in this repo, not an
# edge case. Twice (#41) --prune deleted the working directory of a session that
# was still running. INVOKED_FROM does not help: the prune is usually invoked
# from main, or from a different worktree.
#
# So the session says so out loud. It writes `.worktree-session` (gitignored)
# into its own worktree, and --prune reads a fresh marker as `session` and skips
# it the way it already skips `dirty`, `locked`, and `UNREADABLE`.
#
# Freshness is the file's mtime, not a pid: the marker is refreshed by scripts
# that exit immediately, so a recorded pid is dead within a second of being
# written and proves nothing. The pid is written for a human reading the file.
#
# Who writes it - this is the part that matters, because a marker nothing
# creates leaves --prune looking guarded while it protects nothing:
#   * scripts/worktree-start.sh - at creation, so a worktree is covered from
#     its first second
#   * scripts/lib.sh - on every source, which is every ordinary script in this
#     repo (build/test/lint/snapshot/run/ui/…). Running any of them IS the
#     heartbeat, so a working session refreshes the marker constantly without
#     anyone remembering to
#   * scripts/worktree-sim.sh - the adoption path for worktrees the repo
#     scripts did not create (the coding harness makes its own), and the first
#     thing AGENTS.md tells such a checkout to run. It does not source lib.sh
#   * scripts/worktree-finish.sh - it does not source lib.sh, and the handoff
#     is precisely when the branch becomes landable: from there the session
#     idles in a clean, landed tree while it finishes reporting and the landing
#     runs, which is the window another agent's sweep deleted twice
#
# Source from sibling scripts (after ROOT is set), then:
#   touch_worktree_session <worktree-root>      # refresh; never fails
#   worktree_session_is_live <worktree-root>    # true while the marker is fresh
#   worktree_session_age <worktree-root>        # seconds, empty when unmarked

WORKTREE_SESSION_FILE=".worktree-session"

# How long a marker counts as live, in seconds. 4h, and the asymmetry is the
# whole argument: too short and a slow session gets its directory deleted anyway
# - the bug this exists to stop - while too long only delays reclaiming disk.
# Those costs are nowhere near equal: one destroys work in progress, the other
# holds bytes for a few more hours. On the clean path the cost is genuinely
# small, because worktree-finish.sh has usually purged .build/ and artifacts/ by
# the time a session idles - tens of megabytes of source, not gigabytes. Do not
# read that as the general case: a marker only goes STALE when the session
# crashed or was killed, which means it never reached worktree-finish.sh and its
# .build/ is intact, and even the clean path keeps .build/ under --keep-builds
# and keeps artifacts/ when no PR carried the evidence. So the honest statement
# is that 4h can hold gigabytes for 4h, and that is still the cheaper error.
#
# 4h also comfortably covers the longest gap a live session puts between two
# script runs - a capture-matrix pass, a review swarm, and a round-trip to the
# owner, all in sequence - with room to spare. A crashed session's worktree
# still becomes prunable inside one working day, so cleanup is never blocked
# forever. WORKTREE_SESSION_TTL=0 disables the check for an operator who knows
# every session is stopped.
WORKTREE_SESSION_TTL="${WORKTREE_SESSION_TTL:-14400}"

# Validated, then forced to base 10, because every way bash gets this wrong
# fails OPEN - the direction that deletes live worktrees:
#   `[[ 4h -gt 0 ]]`  is not an error. It evaluates the string arithmetically,
#                     lands on 0, and silently turns the guard off.
#   `[[ 5 -lt 08 ]]`  IS an error ("value too great for base"): a leading zero
#                     makes it octal, 8 and 9 are not octal digits, and the
#                     failed test reads as "not live".
#   `[[ 5 -lt 010 ]]` is worse - no error at all, just octal: an operator
#                     writing 014400 gets 6400 seconds and never finds out.
# 0 stays legal; it is the documented off switch.
# The digit check happens BEFORE the arithmetic, and so does a length check,
# because `10#` wraps silently and wrapping fails open in three different ways:
# 18446744073709551617 comes back as 1 (a one-second TTL - the guard is off in
# practice), 36893488147419103232 comes back as 0 (the documented kill switch,
# reached by accident), and 99999999999999999999 comes back as a huge positive
# number. Only the last is caught by clamping. Nine digits is ~31 years, so
# nothing legitimate is refused - and "never expire" is exactly the intent an
# operator would express with a very long number.
if [[ ! "$WORKTREE_SESSION_TTL" =~ ^[0-9]+$ || ${#WORKTREE_SESSION_TTL} -gt 9 ]]; then
  echo "worktree-session: ignoring WORKTREE_SESSION_TTL='$WORKTREE_SESSION_TTL'" >&2
  echo "                  (whole seconds, at most 9 digits, or 0 to disable);" >&2
  echo "                  using 14400. There is no 'never expire' - a marker" >&2
  echo "                  that never goes stale blocks cleanup forever." >&2
  WORKTREE_SESSION_TTL=14400
fi
WORKTREE_SESSION_TTL=$((10#$WORKTREE_SESSION_TTL))
# …and clamped to a week, so a plausible-but-absurd value still ages out.
if [[ "$WORKTREE_SESSION_TTL" -gt 604800 ]]; then
  echo "worktree-session: WORKTREE_SESSION_TTL is out of range; clamping to 604800 (7d)." >&2
  WORKTREE_SESSION_TTL=604800
fi

# GNU first, BSD second. The other order looks natural on a macOS-first repo
# and is wrong: GNU's `-f` is --file-system, so `stat -f %m` prints filesystem
# junk and exits 0, the `||` never reaches the GNU form, and the caller does
# arithmetic on a non-number. GNU's `-c` exits non-zero on BSD, so probing that
# way round is safe. Every caller validates the result anyway.
worktree_session_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || return 1
}

# A duration a human can act on: 3h48m, 12m, 45s.
worktree_session_duration() {
  local s="${1:-0}"
  ((s < 0)) && s=0
  if ((s >= 3600)); then printf '%dh%02dm' $((s / 3600)) $((s % 3600 / 60))
  elif ((s >= 60)); then printf '%dm' $((s / 60))
  else printf '%ds' "$s"
  fi
}

# Refresh this worktree's marker. Deliberately silent and always successful:
# it is called from lib.sh, which every script sources under `set -e`, and a
# read-only checkout or a full disk must not take a build down with it.
touch_worktree_session() {
  local root="${1:-}" file
  [[ -n "$root" && -d "$root" ]] || return 0

  # Linked worktrees only, decided without forking git: a linked worktree's
  # `.git` is a regular FILE ("gitdir: …"), the integration checkout's is a
  # directory. The integration checkout is never pruned, so a marker there
  # protects nothing and only drops an untracked file under the owner's nose on
  # every script run. Doing this with `git rev-parse --path-format=…` needed
  # git 2.31, and an older git would have failed the check silently - no
  # marker, anywhere, with `--prune` still looking guarded.
  [[ -f "$root/.git" ]] || return 0

  file="$root/$WORKTREE_SESSION_FILE"

  # `printf > symlink` writes THROUGH the link. A `.worktree-session` symlink
  # planted by anything with write access to a worktree - a copied tree, an
  # extracted archive - would then be truncated by every script in this repo,
  # on every run. Replace the link with a real file instead of following it.
  if [[ -L "$file" ]]; then
    echo "worktree-session: $file is a symlink; replacing it with a regular file." >&2
    rm -f "$file" 2>/dev/null || return 0
  fi

  # Refuse to write where the marker would show up as untracked. That is not
  # cosmetic: an unignored marker makes the worktree read `dirty` forever (dirty
  # never ages out) and makes `worktree-finish.sh` refuse the handoff over a
  # file the agent never created. Reachable today - `worktree-start.sh <slug>
  # <base>` can branch from a base whose .gitignore predates this marker.
  if ! git -C "$root" check-ignore -q "$WORKTREE_SESSION_FILE" 2>/dev/null; then
    echo "worktree-session: $WORKTREE_SESSION_FILE is not gitignored in $root," >&2
    echo "                  so no marker was written and --prune cannot see this" >&2
    echo "                  session. Add it to .gitignore (see scripts/worktree-session.sh)." >&2
    return 0
  fi

  if ! printf 'pid=%s\nupdated=%s\n' "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       >"$file" 2>/dev/null; then
    # Say so, but do not fail. --prune cannot tell "the write failed" from "no
    # session", so there is no closed direction to fail in from over here: an
    # unwritable marker reads as unmarked no matter how loudly this exits. What
    # it can do is stop being silent, because a session whose heartbeat is
    # failing is one prune away from losing its directory and has no other way
    # to find out. Taking the caller's build down to deliver that news would be
    # the worse trade - every script in the repo sources this.
    echo "worktree-session: could not refresh $file -" >&2
    echo "                  worktree-clean.sh --prune cannot see this session." >&2
  fi
  return 0
}

# Seconds since the marker was last refreshed. Returns 1 - printing nothing -
# when there is no usable marker or its age cannot be established.
worktree_session_age() {
  local file="$1/$WORKTREE_SESSION_FILE" mtime now
  # A symlink is not a session's own marker, and following one to `stat` lets a
  # link pointing at something constantly touched (say `.git/index`) pin a
  # worktree "live" forever. Regular files only, both sides.
  [[ -f "$file" && ! -L "$file" ]] || return 1
  mtime="$(worktree_session_mtime "$file")" || return 1
  [[ "$mtime" =~ ^[0-9]+$ ]] || return 1
  now="$(date +%s)"
  [[ "$now" =~ ^[0-9]+$ ]] || return 1
  echo $(( now - mtime ))
}

# True while a session is checked in.
#
# The direction of each unknown is the whole design. No marker at all means "no
# session said so": that is the pre-#41 behaviour, it stays prunable, and the
# marker therefore only ever ADDS protection. But a marker that exists and
# cannot be aged is a session that DID check in, so it is treated as live -
# the same way `--prune` reads a failed `git status` as UNREADABLE rather than
# as clean.
worktree_session_is_live() {
  local file="$1/$WORKTREE_SESSION_FILE" age
  [[ "$WORKTREE_SESSION_TTL" -gt 0 ]] || return 1
  [[ -f "$file" && ! -L "$file" ]] || return 1
  if ! age="$(worktree_session_age "$1")" || [[ -z "$age" ]]; then
    echo "worktree-session: $file exists but its age cannot be read;" >&2
    echo "                  treating it as a live session and skipping it." >&2
    return 0
  fi
  # Dated in the future: mild clock skew still protects, which is the safe
  # direction. Far in the future is different - a marker from a restored or
  # copied tree would never age out, and "blocks cleanup forever" is precisely
  # what the TTL exists to prevent.
  if [[ "$age" -lt "-$WORKTREE_SESSION_TTL" ]]; then
    echo "worktree-session: $file is dated far in the future (clock skew?);" >&2
    echo "                  treating it as stale rather than blocking cleanup forever." >&2
    return 1
  fi
  [[ "$age" -lt "$WORKTREE_SESSION_TTL" ]]
}
