#!/bin/bash -p
# Show every worktree, its source state, distance from main, and live-session
# protection. Check this before starting or cleaning agent work.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SELF="$ROOT"

# Keep the inventory's liveness report on the same read API as
# worktree-clean.sh. A partial checkout can still run the inventory, but it has
# no session signal to report when the helper is absent.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
else
  worktree_session_is_live()  { return 1; }
  worktree_session_age()      { return 1; }
  worktree_session_duration() { printf 'unknown'; }
fi

# Read once, then slice in the shell. Nothing here pipes into a reader that
# stops early: a reader that exits on the first record leaves the writer with a
# closed pipe, and under `pipefail` that SIGPIPE is indistinguishable from a
# real failure - it aborts an inventory whose only crime was matching quickly.
WORKTREES="$(git -C "$ROOT" worktree list --porcelain)"
PRIMARY_ROOT="${WORKTREES%%$'\n'*}"
PRIMARY_ROOT="${PRIMARY_ROOT#worktree }"

printf '%-4s %-8s %-45s %-9s %s\n' "" "STATE" "BRANCH" "VS MAIN" "PATH"
printf '%-4s %-8s %-45s %-9s %s\n' "" "-----" "------" "-------" "----"

WT_PATH=""
WT_BRANCH=""
WT_DETACHED=0
SESSION_ROWS=()

emit() {
  [[ -n "$WT_PATH" ]] || return 0

  local branch="$WT_BRANCH"
  if [[ "$WT_DETACHED" -eq 1 || -z "$branch" ]]; then
    branch="(detached)"
  fi

  local state="clean"
  [[ -n "$(git -C "$WT_PATH" status --short 2>/dev/null || true)" ]] && state="dirty"

  # Keep dirty visible as the stronger, already-established state. A clean
  # worktree with a fresh marker is the state that was previously
  # indistinguishable from an idle checkout.
  if [[ "$state" == "clean" ]] && worktree_session_is_live "$WT_PATH"; then
    local age session_prunable=0 landed_main="main"
    state="session"
    age="$(worktree_session_age "$WT_PATH" || echo '?')"
    if git -C "$PRIMARY_ROOT" rev-parse --verify origin/main >/dev/null 2>&1; then
      landed_main="origin/main"
    fi
    if [[ "$WT_DETACHED" -eq 0 && -n "$WT_BRANCH" ]] &&
       git -C "$PRIMARY_ROOT" merge-base --is-ancestor \
         "refs/heads/$WT_BRANCH" "$landed_main" >/dev/null 2>&1; then
      local branch_tip reflog_shas
      branch_tip="$(git -C "$PRIMARY_ROOT" rev-parse --verify \
        "refs/heads/$WT_BRANCH^{commit}" 2>/dev/null || true)"
      reflog_shas="$(git -C "$PRIMARY_ROOT" reflog show --format='%H' \
        "refs/heads/$WT_BRANCH" 2>/dev/null || true)"
      if [[ -n "$branch_tip" && -n "$reflog_shas" && "$reflog_shas" != "$branch_tip" ]]; then
        session_prunable=1
      fi
    fi
    SESSION_ROWS+=("$branch"$'\t'"$age"$'\t'"$session_prunable")
  fi

  # Distance from main, so a stale worktree is visible as stale.
  local delta="-"
  if [[ "$WT_DETACHED" -eq 0 && -n "$WT_BRANCH" ]] &&
     git -C "$PRIMARY_ROOT" rev-parse --verify main >/dev/null 2>&1; then
    local ahead behind
    ahead="$(git -C "$PRIMARY_ROOT" rev-list --count "main..$WT_BRANCH" 2>/dev/null || echo 0)"
    behind="$(git -C "$PRIMARY_ROOT" rev-list --count "$WT_BRANCH..main" 2>/dev/null || echo 0)"
    delta="+$ahead/-$behind"
  fi

  local marker="   "
  [[ "$WT_PATH" == "$SELF" ]] && marker="you"
  [[ "$WT_PATH" == "$PRIMARY_ROOT" ]] && marker="MAIN"

  printf '%-4s %-8s %-45s %-9s %s\n' "$marker" "$state" "$branch" "$delta" "$WT_PATH"
}

while IFS= read -r line || [[ -n "$line" ]]; do
  if [[ -z "$line" ]]; then
    emit
    WT_PATH=""
    WT_BRANCH=""
    WT_DETACHED=0
    continue
  fi

  case "$line" in
    worktree\ *)          WT_PATH="${line#worktree }" ;;
    branch\ refs/heads/*) WT_BRANCH="${line#branch refs/heads/}" ;;
    detached)             WT_DETACHED=1 ;;
  esac
done <<<"$WORKTREES"

emit

if [[ "${#SESSION_ROWS[@]}" -gt 0 ]]; then
  echo
  echo "Live agent sessions:"
  for row in "${SESSION_ROWS[@]}"; do
    row_branch="${row%%$'\t'*}"
    row_rest="${row#*$'\t'}"
    row_age="${row_rest%%$'\t'*}"
    row_prunable="${row_rest##*$'\t'}"
    if [[ "$row_age" == "?" ]]; then
      printf '  %-44s last seen unknown - held until its marker can be read\n' "$row_branch"
    elif [[ "$row_prunable" == "1" ]]; then
      printf '  %-44s last seen %s ago, prunable in %s\n' "$row_branch" \
        "$(worktree_session_duration "$row_age")" \
        "$(worktree_session_duration $((WORKTREE_SESSION_TTL - row_age)))"
    else
      printf '  %-44s last seen %s ago, marker expires in %s\n' "$row_branch" \
        "$(worktree_session_duration "$row_age")" \
        "$(worktree_session_duration $((WORKTREE_SESSION_TTL - row_age)))"
    fi
  done
fi
