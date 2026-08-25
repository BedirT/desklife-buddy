#!/bin/bash -p
# Create an isolated task worktree for write-capable agent work.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIMARY_ROOT="$(git -C "$ROOT" worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }')"
REPO_NAME="$(basename "$PRIMARY_ROOT")"
SLUG=""
BASE=""
BRANCH_PREFIX="${AGENT_BRANCH_PREFIX:-agent}"
WORKTREE_PARENT="${AGENT_WORKTREE_ROOT:-$(dirname "$PRIMARY_ROOT")/${REPO_NAME}.worktrees}"

usage() {
  cat >&2 <<'USAGE'
usage: scripts/worktree-start.sh <slug> [base]

Creates ../<repo>.worktrees/<slug> on branch agent/<slug>, branched from
origin/main by default.

Set AGENT_BRANCH_PREFIX or AGENT_WORKTREE_ROOT to override placement.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --no-sim) ;; # Backward-compatible no-op: macOS tasks never provision one.
    -h|--help) usage; exit 0 ;;
    -*) echo "worktree-start: unknown option '$arg'" >&2; exit 2 ;;
    *)
      if [[ -z "$SLUG" ]]; then SLUG="$arg"
      elif [[ -z "$BASE" ]]; then BASE="$arg"
      else echo "worktree-start: unexpected argument '$arg'" >&2; exit 2
      fi
      ;;
  esac
done

if [[ -z "$SLUG" ]]; then
  usage
  exit 2
fi

if [[ ! "$SLUG" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  echo "worktree-start: slug must use letters, numbers, dot, dash, or underscore" >&2
  exit 2
fi

# Branch from the integration tip, not from whatever this checkout happens to be
# sitting on - HEAD would silently inherit another task's unmerged commits and
# hand the reviewer a diff containing someone else's work.
BASE_IS_HEAD=0
if [[ -z "$BASE" ]]; then
  git -C "$ROOT" fetch --quiet origin main 2>/dev/null || true
  for candidate in origin/main main HEAD; do
    if git -C "$ROOT" rev-parse --verify "$candidate^{commit}" >/dev/null 2>&1; then
      BASE="$candidate"
      [[ "$candidate" == "HEAD" ]] && BASE_IS_HEAD=1
      break
    fi
  done
elif [[ "$BASE" == "HEAD" ]]; then
  BASE_IS_HEAD=1
fi

# Only a HEAD-based branch inherits this checkout's state, so only that case
# needs it committed. Branching from origin/main is unaffected by stray edits
# here, and blocking on them just stalls one agent behind another's mess.
if [[ "$BASE_IS_HEAD" -eq 1 ]] &&
   { ! git -C "$ROOT" diff --quiet || ! git -C "$ROOT" diff --cached --quiet; }; then
  echo "worktree-start: base is HEAD and this checkout has uncommitted changes" >&2
  echo "                commit/stash them, or pass an explicit base (e.g. origin/main)" >&2
  git -C "$ROOT" status --short >&2
  exit 1
fi

BRANCH="$BRANCH_PREFIX/$SLUG"
WORKTREE="$WORKTREE_PARENT/$SLUG"

if ! git -C "$ROOT" rev-parse --verify "$BASE^{commit}" >/dev/null 2>&1; then
  echo "worktree-start: base '$BASE' is not a commit" >&2
  exit 2
fi

# The existence checks below and the `worktree add` they authorise must see
# the same worktree list. Unserialized, a concurrent `worktree-clean.sh
# --prune` pass can decide this path is safe to delete from a scan taken
# before it existed, then remove the live checkout (#38). Held until the
# worktree and its session marker are fully registered; released by the trap.
. "$ROOT/scripts/worktree-lock.sh"
trap 'release_worktree_lock' EXIT
acquire_worktree_lock "worktree-start $SLUG" || exit 1

if git -C "$ROOT" show-ref --verify --quiet "refs/heads/$BRANCH"; then
  echo "worktree-start: branch '$BRANCH' already exists" >&2
  exit 1
fi

if [[ -e "$WORKTREE" ]]; then
  echo "worktree-start: path already exists: $WORKTREE" >&2
  exit 1
fi

mkdir -p "$WORKTREE_PARENT"
git -C "$ROOT" worktree add -b "$BRANCH" "$WORKTREE" "$BASE"

# A new worktree's mise.toml is untrusted, so every pinned tool (xcbeautify,
# swiftlint, swiftformat) fails to launch and the build reports a mise config
# error instead of the real result. Trust it here, once, rather than letting
# each agent rediscover it.
if command -v mise >/dev/null 2>&1; then
  mise trust --quiet "$WORKTREE/mise.toml" 2>/dev/null || true
fi

# Check the session in immediately, so the worktree is covered from its first
# second rather than from whenever the agent first runs a script (#41). This is
# not only about the tail of a task: a worktree branched from an already-landed
# main has no commits of its own, so it reads LANDED from creation.
# Guarded, like lib.sh: an unguarded `.` under `set -e` would abort a worktree
# creation that has already happened, over a marker that only adds protection.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
  touch_worktree_session "$WORKTREE"
fi

cat <<EOF
Worktree ready.
  path:   $WORKTREE
  branch: $BRANCH
  base:   $BASE

Next:
  cd "$WORKTREE"
  scripts/doctor.sh
EOF

# Parallel work is normal here; silent parallel work is what bites. Show who
# else is live so this agent knows whose tree and resources to leave alone.
OTHERS="$(git -C "$ROOT" worktree list --porcelain |
  awk '/^worktree /   { path = substr($0, 10) }
       /^branch /     { sub(/^branch refs\/heads\//, ""); if (path) print path "\t" $0; path = "" }' |
  grep -v -e "^$PRIMARY_ROOT	" -e "^$WORKTREE	" -e "^$ROOT	" || true)"
if [[ -n "$OTHERS" ]]; then
  echo
  echo "Other agents are active - do not touch their worktrees or resources:"
  printf '%s\n' "$OTHERS" | awk -F'\t' '{ printf "  %-28s %s\n", $2, $1 }'
fi
