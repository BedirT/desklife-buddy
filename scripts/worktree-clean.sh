#!/bin/bash -p
# Account for what parallel agents leave behind, and reclaim it.
#
#   scripts/worktree-clean.sh                       report: size, state, what is safe to drop
#   scripts/worktree-clean.sh --purge-builds        delete this worktree's .build/ + artifacts/ + package .build/
#   scripts/worktree-clean.sh --purge-builds --all  sweep every worktree (owner-only, see below)
#   scripts/worktree-clean.sh --prune               remove landed worktrees + sims + branches
#   scripts/worktree-clean.sh --prune --branch NAME remove only one landed task
#   scripts/worktree-clean.sh --prune --dry-run     show what --prune would do
#
# Build output is the bulk of it: DerivedData, package caches, and captured
# artifacts run to gigabytes per worktree while the source is tens of megabytes.
# Purging deletes only the documented regenerable set - the root .build/,
# artifacts/, and the .build/ beside each registered Packages/*/Package.swift -
# never source or state. It defaults to THIS worktree, because deleting build
# output under an agent that is mid-build breaks that build inside someone
# else's session. --all sweeps everything.
#
# --prune is conservative on purpose. A worktree is removed only when it is
# clean, not the integration checkout, not locked, and its exact branch head is
# an ancestor of refreshed origin/main. An untargeted sweep also refuses a
# branch whose reflog has never pointed anywhere except its creation commit: a
# markerless harness-created worktree has that shape before its first task
# commit, even if main later advances, so calling it landed would be vacuous.
# Anything else is reported and left alone.
#
# The untargeted sweep also leaves alone anything hosting a live agent session
# (scripts/worktree-session.sh): a sweep cannot know who is standing where, and
# "landed and clean" is exactly the state a session sits in after its PR merges
# and before it finishes reporting (#41). A session's marker goes stale after
# WORKTREE_SESSION_TTL seconds (default 14400, i.e. 4h), so a crashed session
# cannot block cleanup forever; WORKTREE_SESSION_TTL=0 turns the check off for
# the whole pass. `--prune --branch NAME` is exempt: the caller named exactly
# one task, which is a deliberate instruction rather than a guess, and it is
# how worktree-land.sh reclaims its own worktree at the end of a landing.
set -euo pipefail

# `pwd -P`, matching INVOKED_FROM below and `git worktree list`, which always
# reports physical paths. Reached through a symlink (/tmp and /var are symlinks
# on macOS, as are many home directories) a logical ROOT matches neither, and
# the "self" and "MAIN" states that protect a checkout from --prune are decided
# by exactly these string comparisons. A worktree that cannot recognise itself
# can be pruned by itself.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# First record, sliced in the shell rather than piped into a reader that exits
# on it - that SIGPIPE reads as failure under `pipefail`, and this line runs in
# the cleanup path that reports a finished landing. (Same fix as
# scripts/worktree-list.sh.)
PRIMARY_ROOT="$(git -C "$ROOT" worktree list --porcelain)"
PRIMARY_ROOT="${PRIMARY_ROOT%%$'\n'*}"
PRIMARY_ROOT="${PRIMARY_ROOT#worktree }"
[[ -n "$PRIMARY_ROOT" ]] ||
  { echo "worktree-clean: could not determine the integration checkout" >&2; exit 1; }
PRIMARY_ROOT="$(cd "$PRIMARY_ROOT" && pwd -P)"
COMMON_DIR="$(git -C "$PRIMARY_ROOT" rev-parse --path-format=absolute --git-common-dir)"
CLEANUP_STATE_DIR="$COMMON_DIR/agent-cleanup"
INTEGRATION_PARENT_EXPECTED="$COMMON_DIR/agent-integrations"
# Where the caller is standing, which is not always where this script lives.
# Running main's copy from inside a landed worktree would otherwise delete the
# directory the invoking shell is in - observed twice, and it takes the session
# down with it.
INVOKED_FROM="$(pwd -P)"
MODE="report"
DRY_RUN=0
TARGET_BRANCH=""

ALL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-builds) MODE="purge-builds"; shift ;;
    --prune)        MODE="prune"; shift ;;
    --branch)       TARGET_BRANCH="${2:-}"; shift 2 ;;
    --all)          ALL=1; shift ;;
    --dry-run)      DRY_RUN=1; shift ;;
    -h|--help)      awk 'NR==1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)              echo "worktree-clean: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if [[ -n "$TARGET_BRANCH" ]]; then
  [[ "$MODE" == "prune" ]] ||
    { echo "worktree-clean: --branch requires --prune" >&2; exit 2; }
  [[ "$TARGET_BRANCH" != "main" ]] ||
    { echo "worktree-clean: refusing to prune main" >&2; exit 2; }
fi

# --prune acts on decisions made from the scan below, so the whole
# scan-and-delete pass holds the worktree lock: without it a concurrent
# worktree-start.sh can change or reuse a path after the scan called it safe to
# delete (#38). The dry run only reports, and stays lock-free so it can inspect
# state at any time.
. "$ROOT/scripts/worktree-lock.sh"
# A durable finalization ticket outlives the prepare command while the owner
# inspects its review receipt. Untargeted cleanup must treat that ticket like a
# live session, or a four-hour marker timeout could remove a task that still
# owns the finalization turn. Partial rehearsal fixtures may predate this
# helper, so keep the guard optional there.
if [[ -f "$ROOT/scripts/worktree-finalization-queue.sh" ]]; then
  # shellcheck source=scripts/worktree-finalization-queue.sh
  . "$ROOT/scripts/worktree-finalization-queue.sh"
fi
# Guarded, like lib.sh, and with a stand-in rather than a hard failure: a
# checkout with a partial scripts/ cannot have a marker written into it either,
# so "no session anywhere" is the truthful answer there and it is the pre-#41
# behaviour. Said out loud, because it silently removes a guard.
if [[ -f "$ROOT/scripts/worktree-session.sh" ]]; then
  # shellcheck source=scripts/worktree-session.sh
  . "$ROOT/scripts/worktree-session.sh"
else
  echo "worktree-clean: scripts/worktree-session.sh is missing; the sweep cannot" >&2
  echo "                see live sessions and will treat every landed worktree" >&2
  echo "                as prunable." >&2
  WORKTREE_SESSION_TTL=0
  worktree_session_is_live()  { return 1; }
  worktree_session_age()      { return 1; }
  worktree_session_duration() { printf 'unknown'; }
fi
if [[ "$MODE" == "prune" && "$DRY_RUN" -eq 0 ]]; then
  trap 'release_worktree_lock' EXIT
  acquire_worktree_lock "worktree-clean --prune" || exit 1
fi

if ! git -C "$PRIMARY_ROOT" fetch --quiet origin main 2>/dev/null; then
  [[ "$MODE" != "prune" ]] || {
    echo "worktree-clean: could not refresh origin/main; refusing cleanup" >&2
    exit 1
  }
fi

# `du` exits non-zero when a path is missing, and under `pipefail` that failure
# propagates out of the command substitution and kills the script - silently,
# because du's stderr is suppressed. Every du here ends in `|| true`.
human() { du -sh "$1" 2>/dev/null | awk '{ print $1 }' || true; }

first_match() {
  # Keep only the first match, but drain sed to EOF so neither side can SIGPIPE.
  sed -n "$1" "$2" | awk 'NR == 1 { first = $0 } END { if (NR) print first }'
}

sim_udids_for_name() {
  [[ -x "$ROOT/scripts/worktree-sim.sh" ]] || return 0
  local inventory
  inventory="$(xcrun simctl list devices -j 2>/dev/null)" || return 2
  printf '%s\n' "$inventory" | SIM_DEVICE_NAME="$1" /usr/bin/python3 -c '
import json, os, sys
try:
    groups = json.load(sys.stdin)["devices"].values()
    matches = [device["udid"] for group in groups for device in group
               if device["name"] == os.environ["SIM_DEVICE_NAME"]]
except Exception:
    sys.exit(2)
print("\n".join(matches))
'
}

sim_name_for_udid() {
  [[ -x "$ROOT/scripts/worktree-sim.sh" ]] || return 1
  local inventory
  inventory="$(xcrun simctl list devices -j 2>/dev/null)" || return 2
  printf '%s\n' "$inventory" | SIM_UDID="$1" /usr/bin/python3 -c '
import json, os, sys
try:
    groups = json.load(sys.stdin)["devices"].values()
    for group in groups:
        for device in group:
            if device["udid"] == os.environ["SIM_UDID"]:
                print(device["name"])
                sys.exit(0)
except Exception:
    sys.exit(2)
sys.exit(1)
'
}

# Populate the one purge/accounting set for a worktree. Package-local caches are
# registered by their Package.swift manifest, rather than by recursively
# deleting every directory named .build under source.
build_paths() {
  local root="$1" package_dir
  BUILD_PATHS=("$root/.build" "$root/artifacts")
  [[ -d "$root/Packages" && ! -L "$root/Packages" ]] || return 0
  for package_dir in "$root"/Packages/*; do
    [[ -d "$package_dir" && ! -L "$package_dir" && -f "$package_dir/Package.swift" ]] || continue
    [[ -d "$package_dir/.build" && ! -L "$package_dir/.build" ]] || continue
    BUILD_PATHS+=("$package_dir/.build")
  done
}

# Regenerable bytes in a worktree, in KB.
build_kb() {
  build_paths "$1"
  du -sk "${BUILD_PATHS[@]}" 2>/dev/null | awk '{ s += $1 } END { print s+0 }' || true
}

gb() { awk -v kb="${1:-0}" 'BEGIN { printf "%.1fG", kb/1048576 }'; }

# Autonomous landing publishes the exact reviewed SHA, so destructive cleanup
# requires exact ancestry in refreshed origin/main. Patch-ID equivalence is not
# sufficient: it ignores whitespace that can be meaningful inside source
# strings, regular expressions, and generated resources.
branch_landed() {
  local branch="$1" branch_ref
  [[ -n "$branch" ]] || return 1
  branch_ref="refs/heads/$branch"
  git -C "$PRIMARY_ROOT" rev-parse --verify "$branch_ref^{commit}" >/dev/null 2>&1 || return 1
  git -C "$PRIMARY_ROOT" merge-base --is-ancestor "$branch_ref" origin/main
}

# A branch created directly from current main has no task commit proving it has
# ever done work. That is also the exact shape of a markerless worktree created
# by an external coding harness, so an untargeted sweep must not infer that it
# is finished merely because its empty diff is already on main (#70). A landed
# task can also equal or precede main, but its branch reflog contains an object
# ID different from its landed tip, proving that the task branch moved.
branch_has_no_task_history() {
  local branch="$1" branch_ref branch_sha reflog_shas reflog_sha
  [[ -n "$branch" ]] || return 1
  branch_ref="refs/heads/$branch"
  branch_sha="$(git -C "$PRIMARY_ROOT" rev-parse --verify "$branch_ref^{commit}" 2>/dev/null)" || return 1
  # An unreadable/expired reflog cannot prove a task commit existed. Protecting
  # that row is the conservative direction; targeted cleanup remains available.
  reflog_shas="$(git -C "$PRIMARY_ROOT" reflog show --format='%H' "$branch_ref" 2>/dev/null)" || return 0
  [[ -n "$reflog_shas" ]] || return 0
  while IFS= read -r reflog_sha; do
    [[ "$reflog_sha" == "$branch_sha" ]] || return 1
  done <<<"$reflog_shas"
  return 0
}

# Targeted cleanup removes the remote ref first, with a lease on the exact live
# SHA. If it advanced or carries an unlanded patch, leave every local recovery
# resource intact. The local worktree lock cannot serialize remote writers.
delete_target_remote() {
  local branch="$1" remote_lines remote_sha remote_main_sha candidate_sha landing_state
  local -a push_args
  if ! remote_lines="$(git -C "$PRIMARY_ROOT" ls-remote --heads origin \
      refs/heads/main "refs/heads/$branch" 2>/dev/null)"; then
    echo "Could not read origin/main and origin/$branch; cleanup kept every local resource." >&2
    return 1
  fi
  remote_main_sha="$(printf '%s\n' "$remote_lines" | awk '$2 == "refs/heads/main" { print $1 }')"
  remote_sha="$(printf '%s\n' "$remote_lines" | awk -v ref="refs/heads/$branch" '$2 == ref { print $1 }')"
  [[ "$remote_main_sha" =~ ^[0-9a-f]{40}$ ]] || {
    echo "origin/main is missing or invalid; cleanup kept every local resource." >&2
    return 1
  }
  git -C "$PRIMARY_ROOT" fetch --quiet origin \
    "+refs/heads/main:refs/remotes/origin/main" || return 1
  [[ "$(git -C "$PRIMARY_ROOT" rev-parse origin/main)" == "$remote_main_sha" ]] || {
    echo "origin/main moved while cleanup inspected it; kept everything." >&2
    return 1
  }
  if [[ -n "$remote_sha" ]]; then
    git -C "$PRIMARY_ROOT" fetch --quiet origin \
      "+refs/heads/$branch:refs/remotes/origin/$branch" || return 1
    [[ "$(git -C "$PRIMARY_ROOT" rev-parse "origin/$branch")" == "$remote_sha" ]] || {
      echo "origin/$branch moved while cleanup inspected it; kept everything." >&2
      return 1
    }
    candidate_sha="$remote_sha"
  elif git -C "$PRIMARY_ROOT" rev-parse --verify "$branch^{commit}" >/dev/null 2>&1; then
    candidate_sha="$(git -C "$PRIMARY_ROOT" rev-parse "$branch")"
  else
    landing_state="$(landing_state_file "$branch")"
    candidate_sha="$(first_match 's/^Review-Head: //p' "$landing_state" 2>/dev/null)"
  fi
  [[ "$candidate_sha" =~ ^[0-9a-f]{40}$ ]] || {
    echo "Could not identify the reviewed head for $branch; cleanup kept everything." >&2
    return 1
  }
  git -C "$PRIMARY_ROOT" merge-base --is-ancestor "$candidate_sha" "$remote_main_sha" || {
    echo "$branch has commits absent from live origin/main; kept worktree, simulator, and refs." >&2
    return 1
  }
  push_args=(--quiet --atomic
    --force-with-lease="refs/heads/main:$remote_main_sha")
  if [[ -n "$remote_sha" ]]; then
    push_args+=(--force-with-lease="refs/heads/$branch:$remote_sha")
  fi
  push_args+=(origin "$remote_main_sha:refs/heads/main")
  [[ -z "$remote_sha" ]] || push_args+=(":refs/heads/$branch")
  if git -C "$PRIMARY_ROOT" push "${push_args[@]}"; then
    if [[ -z "$remote_sha" ]]; then
      echo "remote branch origin/$branch was already absent; bound cleanup to origin/main ${remote_main_sha:0:9}"
      return 0
    fi
    echo "deleted remote branch origin/$branch at ${remote_sha:0:9}"
    return 0
  fi
  echo "origin/main or origin/$branch moved before atomic cleanup; kept every local resource." >&2
  return 1
}

pinned_udid() {
  local envfile="$1/.worktree-env"
  [[ -f "$envfile" ]] || return 0
  first_match 's/^export SIM_UDID="\${SIM_UDID:-\([^}]*\)}"$/\1/p' "$envfile"
}

expected_task_device_name() {
  local branch="$1" slug identity_hash
  identity_hash="$(printf '%s' "$branch" | git hash-object --stdin | cut -c1-16)"
  slug="$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '-' | cut -c1-28)"
  printf '%s-%s-%s\n' "$(basename "$PRIMARY_ROOT")" "$slug" "$identity_hash"
}

pending_sim_file() { printf '%s/%s.sim-udid\n' "$CLEANUP_STATE_DIR" "$1"; }
pending_worktree_file() { printf '%s/%s.worktree-leftover\n' "$CLEANUP_STATE_DIR" "$1"; }
task_sim_registry_file() {
  printf '%s/agent-simulators/%s.owner\n' "$COMMON_DIR" \
    "$(printf '%s' "$1" | git hash-object --stdin | cut -c1-16)"
}

record_pending_worktree() {
  local branch="$1" worktree="$2" state_file tmp_file recorded_branch recorded_worktree leftover_size
  state_file="$(pending_worktree_file "$branch")"
  if [[ -e "$state_file" || -L "$state_file" ]]; then
    [[ -f "$state_file" && ! -L "$state_file" ]] || {
      echo "cleanup leftover journal is not a regular file: $state_file" >&2
      return 1
    }
    recorded_branch="$(first_match 's/^Branch: //p' "$state_file")"
    recorded_worktree="$(first_match 's/^Worktree: //p' "$state_file")"
    [[ "$recorded_branch" == "$branch" && "$recorded_worktree" == /* &&
       "$recorded_worktree" != "$PRIMARY_ROOT" ]] || {
      echo "cleanup leftover journal is invalid: $state_file" >&2
      return 1
    }
    if [[ "$recorded_worktree" != "$worktree" &&
          ( -e "$recorded_worktree" || -L "$recorded_worktree" ) ]]; then
      leftover_size="$(human "$recorded_worktree")"
      [[ -n "$leftover_size" ]] || leftover_size="unknown size"
      echo "LEFTOVER $recorded_worktree ($leftover_size reclaimable) - inspect and remove it manually before cleaning $worktree." >&2
      return 1
    fi
    [[ "$recorded_worktree" != "$worktree" ]] || return 0
  fi
  mkdir -p "$(dirname "$state_file")" || return 1
  tmp_file="$state_file.tmp.$$"
  printf 'Branch: %s\nWorktree: %s\n' "$branch" "$worktree" >"$tmp_file" || return 1
  mv "$tmp_file" "$state_file"
}

clear_pending_worktree() { rm -f "$(pending_worktree_file "$1")"; }

retry_pending_worktree() {
  local branch="$1" inspect_only="${2:-0}" state_file recorded_branch worktree leftover_size
  state_file="$(pending_worktree_file "$branch")"
  [[ -e "$state_file" || -L "$state_file" ]] || return 0
  [[ -f "$state_file" && ! -L "$state_file" ]] || {
    echo "cleanup leftover journal is not a regular file: $state_file" >&2
    return 1
  }
  recorded_branch="$(first_match 's/^Branch: //p' "$state_file")"
  worktree="$(first_match 's/^Worktree: //p' "$state_file")"
  [[ "$recorded_branch" == "$branch" && "$worktree" == /* && "$worktree" != "$PRIMARY_ROOT" ]] || {
    echo "cleanup leftover journal is invalid: $state_file" >&2
    return 1
  }
  if [[ -e "$worktree" || -L "$worktree" ]]; then
    leftover_size="$(human "$worktree")"
    [[ -n "$leftover_size" ]] || leftover_size="unknown size"
    echo "LEFTOVER $worktree ($leftover_size reclaimable) - inspect and remove it manually before retrying targeted cleanup." >&2
    return 1
  fi
  [[ "$inspect_only" -eq 1 ]] || clear_pending_worktree "$branch"
}

record_pending_sim() {
  local branch="$1" udid="$2" device_name="$3" nonce="$4" worktree="$5" state_file tmp_file
  state_file="$(pending_sim_file "$branch")"
  mkdir -p "$(dirname "$state_file")" || return 1
  tmp_file="$state_file.tmp.$$"
  printf 'Ownership-Nonce: %s\nWorktree: %s\nDevice-Name: %s\nUDID: %s\n' \
    "$nonce" "$worktree" "$device_name" "$udid" >"$tmp_file" || return 1
  mv "$tmp_file" "$state_file"
}

cleanup_owned_sim() {
  local branch="$1" udid="$2" device_name="$3" nonce="$4" worktree="$5" state_file registry registry_nonce registry_root registry_branch registry_phase registry_name registry_udid registry_tmp recovered live_name presence
  registry="$(task_sim_registry_file "$branch")"
  if [[ ! -f "$registry" ]]; then
    [[ -z "$udid" && -z "$nonce" ]] && return 0
    return 1
  fi
  registry_nonce="$(first_match 's/^Ownership-Nonce: //p' "$registry")"
  registry_root="$(first_match 's/^Worktree: //p' "$registry")"
  registry_branch="$(first_match 's/^Branch: //p' "$registry")"
  registry_phase="$(first_match 's/^Phase: //p' "$registry")"
  [[ -n "$registry_phase" ]] || registry_phase=active
  registry_name="$(first_match 's/^Device-Name: //p' "$registry")"
  registry_udid="$(first_match 's/^UDID: //p' "$registry")"
  [[ "$nonce" =~ ^[0-9a-f]{40}$ && "$registry_nonce" == "$nonce" &&
     "$registry_root" == "$worktree" && "$registry_branch" == "$branch" &&
     "$registry_phase" =~ ^(active|deleting)$ &&
     "$registry_name" == "$device_name" &&
     ( "$registry_udid" == "$udid" || "$registry_udid" == pending ) ]] || return 1
  state_file="$(pending_sim_file "$branch")"
  if [[ -z "$udid" ]]; then
    recovered="$(sim_udids_for_name "$device_name")" || return 1
    [[ -z "$recovered" ]] || {
      echo "simulator name $device_name appeared while ownership was pending; refusing cleanup" >&2
      return 1
    }
    if [[ "$registry_phase" != deleting ]]; then
      registry_tmp="$registry.tmp.$$"
      printf 'Ownership-Nonce: %s\nWorktree: %s\nBranch: %s\nPhase: deleting\nDevice-Name: %s\nUDID: %s\n' \
        "$nonce" "$worktree" "$branch" "$device_name" "$registry_udid" >"$registry_tmp" || return 1
      mv "$registry_tmp" "$registry" || return 1
    fi
    rm -f "$state_file" || return 1
    rm -f "$registry" || return 1
    return 0
  fi
  record_pending_sim "$branch" "$udid" "$device_name" "$nonce" "$worktree" || {
    echo "could not journal simulator $udid; cleanup is blocked" >&2
    return 1
  }
  if [[ "$registry_phase" != deleting ]]; then
    registry_tmp="$registry.tmp.$$"
    printf 'Ownership-Nonce: %s\nWorktree: %s\nBranch: %s\nPhase: deleting\nDevice-Name: %s\nUDID: %s\n' \
      "$nonce" "$worktree" "$branch" "$device_name" "$registry_udid" >"$registry_tmp" || return 1
    mv "$registry_tmp" "$registry" || return 1
  fi
  if live_name="$(sim_name_for_udid "$udid")"; then
    [[ "$live_name" == "$device_name" ]] || {
      echo "simulator $udid is not the authenticated $device_name; refusing deletion" >&2
      return 1
    }
    recovered="$(sim_udids_for_name "$device_name")" || return 1
    [[ "$recovered" == "$udid" ]] || {
      echo "simulator name $device_name is not unique to $udid; refusing deletion" >&2
      return 1
    }
  else
    presence=$?
    [[ "$presence" -eq 1 ]] || {
      echo "could not inspect simulator $udid; pending cleanup recorded at $state_file" >&2
      return 1
    }
    recovered="$(sim_udids_for_name "$device_name")" || return 1
    [[ -z "$recovered" ]] || {
      echo "simulator name $device_name still exists under another UDID; refusing cleanup" >&2
      return 1
    }
    rm -f "$state_file" || return 1
    rm -f "$registry" || return 1
    return 0
  fi
  xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
  if xcrun simctl delete "$udid" >/dev/null 2>&1; then
    recovered="$(sim_udids_for_name "$device_name")" || return 1
    [[ -z "$recovered" ]] || {
      echo "simulator name $device_name still exists after deleting $udid; retaining cleanup authority" >&2
      return 1
    }
    rm -f "$state_file" || return 1
    rm -f "$registry" || return 1
    echo "deleted sim $udid"
    return 0
  fi
  echo "could not delete sim $udid; pending cleanup recorded at $state_file" >&2
  return 1
}

retry_pending_sim() {
  local branch="$1" state_file registry udid device_name nonce worktree phase registry_branch registry_root recovered live_name presence
  state_file="$(pending_sim_file "$branch")"
  if [[ -f "$state_file" ]]; then
    nonce="$(first_match 's/^Ownership-Nonce: //p' "$state_file")"
    worktree="$(first_match 's/^Worktree: //p' "$state_file")"
    device_name="$(first_match 's/^Device-Name: //p' "$state_file")"
    udid="$(first_match 's/^UDID: //p' "$state_file")"
    cleanup_owned_sim "$branch" "$udid" "$device_name" "$nonce" "$worktree"
    return
  fi
  # The registry is deliberately unlinked last. If a process stopped after
  # deleting the device and the pending sidecar, this authenticated terminal
  # phase is enough to finish the non-destructive metadata cleanup.
  registry="$(task_sim_registry_file "$branch")"
  [[ -f "$registry" ]] || return 0
  phase="$(first_match 's/^Phase: //p' "$registry")"
  [[ "$phase" == deleting ]] || return 0
  nonce="$(first_match 's/^Ownership-Nonce: //p' "$registry")"
  registry_root="$(first_match 's/^Worktree: //p' "$registry")"
  registry_branch="$(first_match 's/^Branch: //p' "$registry")"
  device_name="$(first_match 's/^Device-Name: //p' "$registry")"
  udid="$(first_match 's/^UDID: //p' "$registry")"
  [[ "$nonce" =~ ^[0-9a-f]{40}$ && "$registry_branch" == "$branch" &&
     -n "$registry_root" && "$device_name" == "$(expected_task_device_name "$branch")" &&
     -n "$udid" ]] || return 1
  if [[ "$udid" == pending ]]; then
    recovered="$(sim_udids_for_name "$device_name")" || return 1
    [[ -z "$recovered" ]] || {
      echo "a pending simulator named $device_name still exists but its deletion sidecar is gone; refusing" >&2
      return 1
    }
  else
    if live_name="$(sim_name_for_udid "$udid")"; then
      echo "simulator $udid still exists but its deletion sidecar is gone; refusing" >&2
      return 1
    else
      presence=$?
      [[ "$presence" -eq 1 ]] || return 1
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ -z "$recovered" ]] || {
        echo "simulator name $device_name still exists under another UDID; refusing" >&2
        return 1
      }
    fi
  fi
  rm -f "$registry" || return 1
}

integration_state_file() { printf '%s/%s.integration-state\n' "$CLEANUP_STATE_DIR" "$1"; }
landing_state_file() { printf '%s/%s.landing-state\n' "$CLEANUP_STATE_DIR" "$1"; }
clear_landing_state() { rm -f "$(landing_state_file "$1")"; }

retry_pending_integration() {
  local branch="$1" state_file owner_file landing_file sidecar nonce expected_head phase parent udid wt device_name wt_list common marker side_nonce side_name side_udid recovered registered wt_head owner_nonce owner_branch owner_head owner_parent owner_wt owner_name receipt_head tmp_file live_name presence
  state_file="$(integration_state_file "$branch")"
  owner_file="$state_file.owner"
  landing_file="$(landing_state_file "$branch")"
  sidecar="$state_file.udid"
  [[ -f "$state_file" || -f "$owner_file" ]] || return 0
  [[ -f "$owner_file" && -f "$landing_file" ]] || return 1
  owner_nonce="$(first_match 's/^Ownership-Nonce: //p' "$owner_file")"
  owner_branch="$(first_match 's/^Branch: //p' "$owner_file")"
  owner_head="$(first_match 's/^Expected-Head: //p' "$owner_file")"
  owner_parent="$(first_match 's/^Integration-Parent: //p' "$owner_file")"
  owner_wt="$(first_match 's/^Integration-Worktree: //p' "$owner_file")"
  owner_name="$(first_match 's/^Device-Name: //p' "$owner_file")"
  receipt_head="$(first_match 's/^Review-Head: //p' "$landing_file")"
  [[ "$owner_nonce" =~ ^[0-9a-f]{40}$ && "$owner_branch" == "$branch" &&
     "$owner_head" == "$receipt_head" && "$owner_parent" == "$INTEGRATION_PARENT_EXPECTED" &&
     -f "$owner_parent/.agent-integration-root" &&
     "$(sed -n '1p' "$owner_parent/.agent-integration-root")" == "$COMMON_DIR" &&
     "$owner_wt" == "$owner_parent/$(basename "$owner_wt")" &&
     "$(basename "$owner_wt")" =~ ^integrate-[A-Za-z0-9]{6}$ &&
     "$owner_name" == "$(basename "$PRIMARY_ROOT")-$(basename "$owner_wt")" ]] || return 1
  if [[ ! -f "$state_file" ]]; then
    wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
    [[ ! -e "$owner_wt" && $'\n'"$wt_list"$'\n' != *$'\n'"worktree $owner_wt"$'\n'* ]] || return 1
    if [[ -f "$sidecar" ]]; then
      side_nonce="$(first_match 's/^Ownership-Nonce: //p' "$sidecar")"
      side_name="$(first_match 's/^Device-Name: //p' "$sidecar")"
      side_udid="$(first_match 's/^UDID: //p' "$sidecar")"
      [[ "$side_nonce" == "$owner_nonce" && "$side_name" == "$owner_name" && -n "$side_udid" ]] || return 1
      if [[ "$side_udid" == pending ]]; then
        recovered="$(sim_udids_for_name "$side_name")" || return 1
        [[ -z "$recovered" ]] || return 1
      else
        if live_name="$(sim_name_for_udid "$side_udid")"; then
          return 1
        else
          presence=$?
          [[ "$presence" -eq 1 ]] || return 1
          recovered="$(sim_udids_for_name "$side_name")" || return 1
          [[ -z "$recovered" ]] || return 1
        fi
      fi
      rm -f "$sidecar" || return 1
    fi
    recovered="$(sim_udids_for_name "$owner_name")" || return 1
    [[ -z "$recovered" ]] || return 1
    rm -f "$owner_file" || return 1
    return 0
  fi
  nonce="$(first_match 's/^Ownership-Nonce: //p' "$state_file")"
  expected_head="$(first_match 's/^Expected-Head: //p' "$state_file")"
  phase="$(first_match 's/^Phase: //p' "$state_file")"
  parent="$(first_match 's/^Integration-Parent: //p' "$state_file")"
  udid="$(first_match 's/^Integration-UDID: //p' "$state_file")"
  wt="$(first_match 's/^Integration-Worktree: //p' "$state_file")"
  device_name="$(first_match 's/^Device-Name: //p' "$state_file")"
  [[ "$nonce" == "$owner_nonce" && "$expected_head" == "$owner_head" &&
     "$phase" =~ ^(reserved|registered|removing)$ && "$parent" == "$owner_parent" &&
     "$wt" == "$owner_wt" && "$device_name" == "$owner_name" && "$parent" == /* &&
     "$parent" == "$INTEGRATION_PARENT_EXPECTED" &&
     -f "$parent/.agent-integration-root" &&
     "$(sed -n '1p' "$parent/.agent-integration-root")" == "$COMMON_DIR" &&
     "$wt" == "$parent/$(basename "$wt")" &&
     "$(basename "$wt")" =~ ^integrate-[A-Za-z0-9]{6}$ &&
     "$device_name" == "$(basename "$PRIMARY_ROOT")-$(basename "$wt")" ]] || return 1
  wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
  registered=0
  [[ $'\n'"$wt_list"$'\n' != *$'\n'"worktree $wt"$'\n'* ]] || registered=1
  if [[ "$registered" -eq 1 ]]; then
    [[ -d "$wt" ]] || return 1
    [[ "$(cd "$(dirname "$wt")" && pwd -P)" == "$parent" ]] || return 1
    common="$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" || return 1
    [[ "$common" == "$COMMON_DIR" ]] || return 1
    wt_head="$(git -C "$wt" rev-parse HEAD 2>/dev/null)" || return 1
    [[ "$wt_head" == "$expected_head" ]] || return 1
    marker="$wt/.integration-owner"
    if [[ "$phase" == reserved ]]; then
      [[ ! -f "$marker" || "$(sed -n '1p' "$marker")" == "$nonce" ]] || return 1
    else
      [[ -f "$marker" && "$(sed -n '1p' "$marker")" == "$nonce" ]] || return 1
    fi
  elif [[ -d "$wt" && "$phase" == registered ]]; then
    return 1
  fi
  if [[ -n "$udid" || -f "$sidecar" ]]; then
    [[ -f "$sidecar" ]] || return 1
    side_nonce="$(first_match 's/^Ownership-Nonce: //p' "$sidecar")"
    side_name="$(first_match 's/^Device-Name: //p' "$sidecar")"
    side_udid="$(first_match 's/^UDID: //p' "$sidecar")"
    [[ "$side_nonce" == "$nonce" && "$side_name" == "$device_name" ]] || return 1
    if [[ "$side_udid" == "pending" ]]; then
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ "$(printf '%s\n' "$recovered" | awk 'NF { count++ } END { print count+0 }')" -le 1 ]] || return 1
      udid="$recovered"
    else
      [[ -n "$side_udid" && ( -z "$udid" || "$udid" == "$side_udid" ) ]] || return 1
      udid="$side_udid"
    fi
  fi
  if [[ -z "$udid" && -f "$wt/.worktree-env" ]]; then
    recovered="$(first_match 's/^export SIM_UDID="\${SIM_UDID:-\([^}]*\)}"$/\1/p' "$wt/.worktree-env")"
    [[ -z "$recovered" ]] || udid="$recovered"
  fi
  if [[ -n "$udid" ]]; then
    if live_name="$(sim_name_for_udid "$udid")"; then
      [[ "$live_name" == "$device_name" ]] || return 1
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ "$recovered" == "$udid" ]] || return 1
      xcrun simctl shutdown "$udid" >/dev/null 2>&1 || true
      xcrun simctl delete "$udid" >/dev/null 2>&1 || return 1
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ -z "$recovered" ]] || return 1
    else
      presence=$?
      [[ "$presence" -eq 1 ]] || return 1
      recovered="$(sim_udids_for_name "$device_name")" || return 1
      [[ -z "$recovered" ]] || return 1
    fi
  fi
  if [[ -n "$wt" ]]; then
    tmp_file="$state_file.tmp.$$"
    printf 'Ownership-Nonce: %s\nExpected-Head: %s\nPhase: removing\nIntegration-Parent: %s\nIntegration-Worktree: %s\nDevice-Name: %s\nIntegration-UDID: %s\n' \
      "$nonce" "$expected_head" "$parent" "$wt" "$device_name" "$udid" >"$tmp_file" || return 1
    mv "$tmp_file" "$state_file" || return 1
    if [[ $'\n'"$wt_list"$'\n' == *$'\n'"worktree $wt"$'\n'* ]]; then
      git -C "$PRIMARY_ROOT" worktree remove --force "$wt" >/dev/null 2>&1 || true
      wt_list="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)" || return 1
      [[ $'\n'"$wt_list"$'\n' != *$'\n'"worktree $wt"$'\n'* ]] || return 1
    fi
    [[ ! -d "$wt" ]] || rm -rf "$wt" || return 1
  fi
  rm -f "$state_file" || return 1
  rm -f "$sidecar" || return 1
  recovered="$(sim_udids_for_name "$owner_name")" || return 1
  [[ -z "$recovered" ]] || return 1
  rm -f "$owner_file" || return 1
  echo "drained pending integration resources for $branch"
}

# Collect worktrees ------------------------------------------------------------
PATHS=()
BRANCHES=()
HEADS=()
LOCKED=()

while IFS= read -r line || [[ -n "$line" ]]; do
  case "$line" in
    worktree\ *) PATHS+=("${line#worktree }"); BRANCHES+=(""); HEADS+=(""); LOCKED+=("no") ;;
    HEAD\ *) HEADS[$((${#HEADS[@]} - 1))]="${line#HEAD }" ;;
    branch\ refs/heads/*) BRANCHES[$((${#BRANCHES[@]} - 1))]="${line#branch refs/heads/}" ;;
    locked*) LOCKED[$((${#LOCKED[@]} - 1))]="yes" ;;
  esac
done < <(git -C "$ROOT" worktree list --porcelain)

TOTAL_RECLAIMED=0
printf '%-9s %-45s %-8s %-7s %s\n' "STATE" "BRANCH" "SIZE" "BUILD" "PATH"
printf '%-9s %-45s %-8s %-7s %s\n' "-----" "------" "----" "-----" "----"

PRUNABLE=()
TARGET_SEEN=0
SESSION_ROWS=()
# Initialized rather than defaulted at each read. `${SESSIONS_SKIPPED:-0}` alone
# inherits an exported SESSIONS_SKIPPED from the caller's environment, which
# both corrupts the count and - with SESSION_ROWS legitimately empty - makes the
# summary loop expand an empty array under `set -u`. On bash 3.2 that is an
# `unbound variable` abort of the script that deletes worktrees.
SESSIONS_SKIPPED=0

for i in "${!PATHS[@]}"; do
  wt="${PATHS[$i]}"
  branch="${BRANCHES[$i]:-（detached)}"
  [[ -n "$TARGET_BRANCH" && "$branch" == "$TARGET_BRANCH" ]] && TARGET_SEEN=1
  [[ -d "$wt" ]] || { printf '%-9s %-45s %-8s %-7s %s\n' "GONE" "$branch" "-" "-" "$wt"; continue; }

  size="$(human "$wt")"
  build="$(gb "$(build_kb "$wt")")"

  # Fail closed. Testing only the OUTPUT of `git status` reads a FAILED status -
  # stale .git pointer, permissions, I/O error - as "no changes, therefore
  # clean", and clean is what authorises deletion. A worktree whose state cannot
  # be established is never prunable.
  dirty="clean"
  WT_STATUS=""
  if ! WT_STATUS="$(git -C "$wt" status --short 2>/dev/null)"; then
    dirty="unknown"
  elif [[ -n "$WT_STATUS" ]]; then
    dirty="dirty"
  fi

  state="active"
  if [[ "$wt" == "$PRIMARY_ROOT" ]]; then
    state="MAIN"
  elif [[ "$wt" == "$ROOT" || "$INVOKED_FROM" == "$wt" || "$INVOKED_FROM" == "$wt"/* ]]; then
    # Never prune the checkout running this script, nor the one the caller is
    # standing in: --prune force-removes the tree and deletes its simulator, so
    # either would be destroyed mid-run. These are different directories
    # whenever main's copy of the script is run from inside a worktree.
    state="self"
  elif [[ "$dirty" == "unknown" ]]; then
    state="UNREADABLE"
  elif [[ "${LOCKED[$i]}" == "yes" ]]; then
    state="locked"
  elif [[ "$dirty" == "dirty" ]]; then
    state="dirty"
  elif [[ -z "$TARGET_BRANCH" || "${BRANCHES[$i]}" != "$TARGET_BRANCH" ]] &&
       declare -F finalization_queue_ticket_for_branch >/dev/null 2>&1 &&
       [[ -n "$(finalization_queue_ticket_for_branch "${BRANCHES[$i]}")" ]]; then
    state="finalizing"
  elif branch_landed "${BRANCHES[$i]}"; then
    # Checked last, so it only ever changes the outcome for a worktree that
    # would otherwise be deleted: everything above already declines to prune,
    # and relabelling those would just hide the more specific reason.
    #
    # Exempt the NAMED row only, not the whole run. `--branch NAME` names one
    # task, which is a deliberate instruction and not a guess about who is
    # where - and it is how worktree-land.sh reclaims the very worktree it just
    # landed from, with its own marker necessarily fresh. Every other row is
    # still only being reported, and reporting a live session as `LANDED`
    # would tell the operator the next sweep is safe when it is not.
    #
    # The `-z` half is not redundant: BRANCHES[] holds "" for a detached
    # worktree, so on an untargeted sweep `"" != ""` would be false and skip
    # the liveness check entirely - the delete direction. Unreachable today
    # only because branch_landed refuses an empty branch, which is a coupling
    # this line should not depend on.
    if [[ -z "$TARGET_BRANCH" || "${BRANCHES[$i]}" != "$TARGET_BRANCH" ]] && worktree_session_is_live "$wt"; then
      state="session"
      SESSIONS_SKIPPED=$((SESSIONS_SKIPPED + 1))
      # An age of "?" is the case worktree_session_is_live protects WITHOUT
      # being able to date: printing 0 there would invent a number the operator
      # would plan around, and contradict the warning it just wrote to stderr.
      SESSION_ROWS+=("$branch"$'\t'"$(worktree_session_age "$wt" || echo '?')")
    elif [[ -z "$TARGET_BRANCH" || "${BRANCHES[$i]}" != "$TARGET_BRANCH" ]] &&
         branch_has_no_task_history "${BRANCHES[$i]}"; then
      # Targeted cleanup is deliberate and remains able to reclaim its named
      # task immediately after a fast-forward landing. An untargeted sweep
      # cannot tell this from a new markerless harness worktree at the same tip.
      state="active"
    else
      state="LANDED"
      if [[ -z "$TARGET_BRANCH" || "${BRANCHES[$i]}" == "$TARGET_BRANCH" ]]; then
        PRUNABLE+=("$i")
      fi
    fi
  fi

  printf '%-9s %-45s %-8s %-7s %s\n' "$state" "$branch" "${size:--}" "${build:--}" "$wt"
done

# Purge builds -----------------------------------------------------------------
if [[ "$MODE" == "purge-builds" ]]; then
  echo
  # Default to this worktree only. Deleting .build/ under an agent that is
  # mid-build breaks that build with a confusing error in someone else's
  # session - a sweep across live worktrees is the owner's call, not a default.
  if [[ "$ALL" -eq 0 ]]; then
    echo "Purging this worktree only. Sweep every worktree with --all"
    echo "(that will break any build running elsewhere right now)."
    echo
  else
    # An integration is compiling in a temporary worktree right now - or a
    # worktree is being created or pruned; deleting DerivedData underneath any
    # of them fails a gate for reasons no one can trace. Take the lock rather
    # than peeking at it: a peek can pass a moment before an integration
    # starts, and the sweep would then delete .build/ under its gates.
    trap 'release_worktree_lock' EXIT
    if ! acquire_worktree_lock "worktree-clean --purge-builds --all" 5; then
      echo "worktree-clean: refusing --all while the lock is held." >&2
      echo "                Wait for it to finish, or purge just this worktree." >&2
      exit 1
    fi
  fi

  for i in "${!PATHS[@]}"; do
    wt="${PATHS[$i]}"
    [[ -d "$wt" ]] || continue
    [[ "$ALL" -eq 1 || "$wt" == "$ROOT" ]] || continue
    # A git-locked worktree is deliberately marked in-use by its owner.
    if [[ "${LOCKED[$i]}" == "yes" && "$wt" != "$ROOT" ]]; then
      echo "skipped (locked) $wt"
      continue
    fi
    freed="$(build_kb "$wt")"
    [[ "$freed" -gt 0 ]] || continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "would purge $(gb "$freed") from $wt"
    else
      build_paths "$wt"
      if rm -rf "${BUILD_PATHS[@]}" 2>/dev/null; then
        echo "purged $(gb "$freed") from $wt"
      else
        # Something is writing underneath (a live build filling DerivedData makes
        # `rm -rf` report "Directory not empty"). Purging is opportunistic: report
        # what is left and sweep on, rather than dying under `set -e` mid-sweep.
        # A writer can grow the tree between measurements; never report negative
        # reclaimed space when that happens.
        freed=$((freed - $(build_kb "$wt")))
        [[ "$freed" -gt 0 ]] || freed=0
        echo "partly purged $(gb "$freed") from $wt - still busy, re-run later"
      fi
    fi
    TOTAL_RECLAIMED=$((TOTAL_RECLAIMED + freed))
  done
  echo
  echo "Total: $(gb "$TOTAL_RECLAIMED") $([[ "$DRY_RUN" -eq 1 ]] && echo "would be reclaimed" || echo "reclaimed")"
  echo "Source trees untouched - scripts/test.sh rebuilds what it needs."
  exit 0
fi

# Prune ------------------------------------------------------------------------
if [[ "$MODE" == "prune" ]]; then
  echo
  if [[ -n "$TARGET_BRANCH" && "$DRY_RUN" -eq 1 ]]; then
    retry_pending_worktree "$TARGET_BRANCH" 1 || exit 1
  fi
  if [[ "$SESSIONS_SKIPPED" -gt 0 ]]; then
    echo "Left ${SESSIONS_SKIPPED} landed worktree(s) alone - a live agent session is checked in:"
    for row in "${SESSION_ROWS[@]}"; do
      # branch<TAB>age-in-seconds, or "?" when the marker could not be dated
      row_branch="${row%%	*}"
      row_age="${row##*	}"
      if [[ "$row_age" == "?" ]]; then
        echo "  $(printf '%-44s last seen unknown - held until its marker can be read\n' "$row_branch")"
      else
        echo "  $(printf '%-44s last seen %s ago, prunable in %s\n' "$row_branch" \
          "$(worktree_session_duration "$row_age")" \
          "$(worktree_session_duration $((WORKTREE_SESSION_TTL - row_age)))")"
      fi
    done
    echo "  Nothing to do: they prune themselves on a later pass. WORKTREE_SESSION_TTL=0"
    echo "  skips the check for every row at once, including genuinely live ones, and"
    echo "  --prune --branch NAME reclaims one named task regardless."
    echo
  fi
  if [[ "${#PRUNABLE[@]}" -eq 0 ]]; then
    if [[ -n "$TARGET_BRANCH" ]]; then
      if [[ "$TARGET_SEEN" -eq 1 ]]; then
        echo "Nothing pruned: $TARGET_BRANCH is not a clean landed worktree." >&2
        exit 1
      fi
      # Idempotent retry: if the worktree is already gone, remove any remaining
      # landed refs. A target that still has unique commits fails closed.
      if git -C "$PRIMARY_ROOT" rev-parse --verify "$TARGET_BRANCH^{commit}" >/dev/null 2>&1; then
        branch_landed "$TARGET_BRANCH" || {
          echo "Nothing pruned: $TARGET_BRANCH still has unlanded commits." >&2
          exit 1
        }
      fi
      if [[ "$DRY_RUN" -eq 0 ]]; then
        retry_pending_integration "$TARGET_BRANCH" || exit 1
        retry_pending_worktree "$TARGET_BRANCH" || exit 1
        delete_target_remote "$TARGET_BRANCH" || exit 1
        retry_pending_sim "$TARGET_BRANCH" || exit 1
      fi
      if [[ "$DRY_RUN" -eq 0 ]] &&
         git -C "$PRIMARY_ROOT" rev-parse --verify "$TARGET_BRANCH^{commit}" >/dev/null 2>&1; then
        git -C "$PRIMARY_ROOT" branch -D "$TARGET_BRANCH" >/dev/null
        echo "deleted branch $TARGET_BRANCH"
      elif [[ "$DRY_RUN" -eq 1 ]]; then
        echo "would delete landed refs for $TARGET_BRANCH"
      fi
      [[ "$DRY_RUN" -eq 1 ]] || clear_landing_state "$TARGET_BRANCH"
      echo "Target already had no registered worktree. Cleanup complete."
      exit 0
    fi
    if [[ "$SESSIONS_SKIPPED" -gt 0 ]]; then
      echo "Nothing prunable right now: every landed worktree is hosting a session."
    else
      echo "Nothing to prune: no clean worktree has a landed branch."
    fi
    echo "Free space without removing anything: scripts/worktree-clean.sh --purge-builds"
    exit 0
  fi

  # Delete the exact landed remote ref before touching the recovery worktree.
  # A lease failure or remote-only commit aborts with everything local intact.
  if [[ -n "$TARGET_BRANCH" && "$DRY_RUN" -eq 0 ]]; then
    retry_pending_integration "$TARGET_BRANCH" || exit 1
    delete_target_remote "$TARGET_BRANCH" || exit 1
  fi

  for i in "${PRUNABLE[@]}"; do
    wt="${PATHS[$i]}"
    branch="${BRANCHES[$i]}"
    udid="$(pinned_udid "$wt")"
    device_name="$(expected_task_device_name "$branch")"
    nonce=""
    registry="$(task_sim_registry_file "$branch")"
    sim_owned=0
    if [[ -f "$registry" ]]; then
      sim_owned=1
      nonce="$(first_match 's/^Ownership-Nonce: //p' "$registry")"
      owner_root="$(first_match 's/^Worktree: //p' "$registry")"
      owner_branch="$(first_match 's/^Branch: //p' "$registry")"
      owner_phase="$(first_match 's/^Phase: //p' "$registry")"
      [[ -n "$owner_phase" ]] || owner_phase=active
      device_name="$(first_match 's/^Device-Name: //p' "$registry")"
      owner_udid="$(first_match 's/^UDID: //p' "$registry")"
      [[ "$nonce" =~ ^[0-9a-f]{40}$ && "$owner_root" == "$wt" &&
         "$owner_branch" == "$branch" && "$device_name" == "$(expected_task_device_name "$branch")" &&
         ( "$owner_udid" == pending || -n "$owner_udid" ) ]] || {
        echo "SKIPPED $wt - simulator ownership registry is invalid." >&2
        FAILED=1
        continue
      }
      [[ "$owner_phase" == active ]] || {
        echo "SKIPPED $wt - simulator registry phase '$owner_phase' requires worktree-sim recovery first." >&2
        FAILED=1
        continue
      }
      owner_file="$wt/.worktree-sim-owner"
      [[ -f "$owner_file" ]] || {
        echo "SKIPPED $wt - simulator ownership sidecar is missing." >&2
        FAILED=1
        continue
      }
      side_nonce="$(first_match 's/^Ownership-Nonce: //p' "$owner_file")"
      side_root="$(first_match 's/^Worktree: //p' "$owner_file")"
      side_name="$(first_match 's/^Device-Name: //p' "$owner_file")"
      side_udid="$(first_match 's/^UDID: //p' "$owner_file")"
      [[ "$side_nonce" == "$nonce" && "$side_root" == "$wt" &&
         "$side_name" == "$device_name" &&
         ( "$side_udid" == "$owner_udid" || "$owner_udid" == pending ) ]] || {
        echo "SKIPPED $wt - simulator ownership sidecar does not match registry." >&2
        FAILED=1
        continue
      }
      if [[ "$owner_udid" == pending ]]; then
        if ! recovered="$(sim_udids_for_name "$device_name")"; then
          echo "SKIPPED $wt - could not recover pending simulator ownership." >&2
          FAILED=1
          continue
        fi
        [[ "$(printf '%s\n' "$recovered" | awk 'NF { count++ } END { print count+0 }')" -le 1 ]] || {
          echo "SKIPPED $wt - pending simulator name is ambiguous." >&2
          FAILED=1
          continue
        }
        [[ -z "$udid" || -z "$recovered" || "$udid" == "$recovered" ]] || {
          echo "SKIPPED $wt - pending simulator differs from its pin." >&2
          FAILED=1
          continue
        }
        [[ "$side_udid" == pending || -z "$recovered" || "$side_udid" == "$recovered" ]] || {
          echo "SKIPPED $wt - pending simulator differs from its sidecar." >&2
          FAILED=1
          continue
        }
        udid="$recovered"
      else
        [[ -z "$udid" || "$udid" == "$owner_udid" ]] || {
          echo "SKIPPED $wt - simulator pin differs from durable ownership." >&2
          FAILED=1
          continue
        }
        udid="$owner_udid"
      fi
    elif [[ -n "$udid" || -f "$wt/.worktree-sim-owner" ]]; then
      echo "SKIPPED $wt - simulator has no durable shared ownership registry." >&2
      FAILED=1
      continue
    fi
    if [[ -n "$udid" ]]; then
      if live_name="$(sim_name_for_udid "$udid")"; then
        [[ "$live_name" == "$device_name" ]] || {
          echo "SKIPPED $wt - simulator pin belongs to another worktree." >&2
          FAILED=1
          continue
        }
        if ! recovered="$(sim_udids_for_name "$device_name")"; then
          echo "SKIPPED $wt - could not authenticate simulator name $device_name." >&2
          FAILED=1
          continue
        fi
        [[ "$recovered" == "$udid" ]] || {
          echo "SKIPPED $wt - owned simulator name is not unique to its pin." >&2
          FAILED=1
          continue
        }
      else
        presence=$?
        [[ "$presence" -eq 1 ]] || {
          echo "SKIPPED $wt - could not authenticate simulator $udid." >&2
          FAILED=1
          continue
        }
        if ! recovered="$(sim_udids_for_name "$device_name")"; then
          echo "SKIPPED $wt - could not authenticate simulator name $device_name." >&2
          FAILED=1
          continue
        fi
        [[ -z "$recovered" ]] || {
          echo "SKIPPED $wt - owned simulator name still exists under another UDID." >&2
          FAILED=1
          continue
        }
      fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "would remove worktree $wt"
      echo "                branch $branch"
      [[ -n "$udid" ]] && echo "                sim    $udid"
      DID_DRY_RUN=1
      continue
    fi

    # The heartbeat writers (lib.sh, worktree-finish.sh) deliberately do NOT
    # take the worktree lock - making every build and test in the fleet
    # serialize on it to say "still here" would cost far more than it buys. So
    # a session can wake up inside this pass, while it is busy removing
    # somebody else's tree, and the liveness question has to be asked again
    # further down, as late as possible. `--branch NAME` is exempt there for
    # the same reason it is exempt in the scan.

    # `git worktree remove` deletes the tree file by file and then rmdir's it,
    # so ONE file it does not know about - .DS_Store is enough - aborts the
    # whole removal partway. Observed: git deregistered the worktree and left
    # 113 MB of source behind. Sweep only that OS metadata: .build/ and
    # artifacts/ stay until the removal actually succeeds, because artifacts/
    # is the only local copy of the review and evidence when no PR was opened.
    #
    # Ordered before the journal deliberately: this is a full recursive walk of
    # the source tree - hundreds of milliseconds on a real checkout - and it is
    # the last chance to notice a session before anything is written down.
    # Deleting .DS_Store under a live session costs nothing; leaving a pending
    # simulator journal behind for one does, because the next pass then refuses
    # the row until worktree-sim recovery runs.
    find "$wt" -name '.DS_Store' -delete 2>/dev/null || true

    # A markerless external harness does not participate in our session lock or
    # heartbeat. Re-read both kinds of mutable worktree state immediately before
    # removal so a first commit or edit made after the scan cannot turn a stale
    # LANDED decision into authorization to delete new work.
    current_branch_ref=""
    current_worktree_head=""
    current_branch_head=""
    if ! current_branch_ref="$(git -C "$wt" symbolic-ref --quiet HEAD 2>/dev/null)" ||
       ! current_worktree_head="$(git -C "$wt" rev-parse --verify "HEAD^{commit}" 2>/dev/null)" ||
       ! current_branch_head="$(git -C "$PRIMARY_ROOT" rev-parse --verify "refs/heads/$branch^{commit}" 2>/dev/null)" ||
       [[ "$current_branch_ref" != "refs/heads/$branch" ||
          "$current_worktree_head" != "${HEADS[$i]}" || "$current_branch_head" != "${HEADS[$i]}" ]] ||
       ! branch_landed "$branch"; then
      echo "SKIPPED $wt - worktree or branch changed while this ran." >&2
      if [[ -n "$TARGET_BRANCH" && "$branch" == "$TARGET_BRANCH" ]]; then
        FAILED=1
      fi
      continue
    fi

    # These are the final two reads before the first irreversible step. A repo
    # script can write the ignored heartbeat during the identity queries above;
    # an external harness can write an ordinary file. Read status after every
    # Git identity/ancestry query, then ask liveness after status.
    current_status=""
    if ! current_status="$(git -C "$wt" status --short 2>/dev/null)" || [[ -n "$current_status" ]]; then
      echo "SKIPPED $wt - worktree or branch changed while this ran." >&2
      if [[ -n "$TARGET_BRANCH" && "$branch" == "$TARGET_BRANCH" ]]; then
        FAILED=1
      fi
      continue
    fi
    if [[ -z "$TARGET_BRANCH" || "${BRANCHES[$i]}" != "$TARGET_BRANCH" ]] && worktree_session_is_live "$wt"; then
      echo "SKIPPED $wt - a session checked in while this ran." >&2
      continue
    fi

    # Persist ownership before `git worktree remove`: that command can delete
    # .worktree-env and still fail partway, so journaling afterward is too late.
    if [[ "$sim_owned" -eq 1 ]] &&
       ! record_pending_sim "$branch" "$udid" "$device_name" "$nonce" "$wt"; then
      echo "SKIPPED $wt - could not journal simulator ownership." >&2
      FAILED=1
      continue
    fi

    REMOVED=0
    if ! record_pending_worktree "$branch" "$wt"; then
      echo "SKIPPED $wt - could not journal worktree ownership." >&2
      FAILED=1
      continue
    fi
    if git -C "$PRIMARY_ROOT" worktree remove --force "$wt" 2>/dev/null; then
      if clear_pending_worktree "$branch"; then
        REMOVED=1
      else
        echo "SKIPPED $wt - removal succeeded but its cleanup journal remains; retry targeted cleanup." >&2
      fi
    else
      # Git can deregister a worktree and still fail partway through deleting
      # it. Do not follow that failure with recursive deletion: the guards
      # required to make an rm fallback safe are themselves a large destructive
      # surface (#36). Preserve every leftover for inspection and keep the
      # branch and simulator ownership so targeted cleanup can be retried.
      leftover_size="$(human "$wt")"
      [[ -n "$leftover_size" ]] || leftover_size="unknown size"
      WT_LIST=""
      if WT_LIST="$(git -C "$PRIMARY_ROOT" worktree list --porcelain 2>/dev/null)"; then
        case $'\n'"$WT_LIST"$'\n' in
          *$'\n'"worktree $wt"$'\n'*)
            echo "LEFTOVER $wt ($leftover_size reclaimable) - Git still registers it; retry targeted cleanup." >&2
            ;;
          *)
            echo "LEFTOVER $wt ($leftover_size reclaimable) - Git deregistered it but did not finish removal; inspect and remove it manually." >&2
            ;;
        esac
      else
        echo "LEFTOVER $wt ($leftover_size reclaimable) - could not determine registration; inspect it manually and retry targeted cleanup." >&2
      fi
    fi

    if [[ "$REMOVED" -eq 1 ]]; then
      echo "removed worktree $wt"
      # Only now, and in this order: a branch deleted while its worktree
      # survives strands the checkout with no ref to return to, and a simulator
      # deleted out from under a surviving worktree leaves .worktree-env
      # pointing at nothing.
      if ! cleanup_owned_sim "$branch" "$udid" "$device_name" "$nonce" "$wt"; then
        echo "SKIPPED branch $branch - simulator cleanup is pending." >&2
        FAILED=1
        continue
      fi
      if git -C "$PRIMARY_ROOT" branch -D "$branch" >/dev/null; then
        echo "deleted branch $branch"
        clear_landing_state "$branch"
      else
        echo "could not delete branch $branch; retry targeted cleanup." >&2
        FAILED=1
      fi
    else
      echo "SKIPPED $wt - could not remove it; branch and simulator kept." >&2
      FAILED=1
    fi
  done

  # A dry run reports and stops. `git worktree prune` mutates administrative
  # state, so it belongs strictly on the real path.
  if [[ "${DID_DRY_RUN:-0}" -eq 1 ]]; then
    echo
    echo "Dry run - nothing removed."
    exit 0
  fi

  git -C "$PRIMARY_ROOT" worktree prune
  echo
  echo "Pruned. Remaining:"
  "$ROOT/scripts/worktree-list.sh"
  exit "${FAILED:-0}"
fi

# Report -----------------------------------------------------------------------
cat <<'EOF'

STATE means:
  MAIN       integration checkout - never pruned
  self       the checkout running this command - never pruned
  LANDED     clean, and every commit is already on main: safe to prune
  session    landed, but an agent session is checked in (.worktree-session
             refreshed within WORKTREE_SESSION_TTL, default 4h); the sweep
             leaves it alone and it prunes itself once the marker goes stale.
             `--prune --branch NAME` reclaims one named task regardless.
  dirty      uncommitted work lives here; left alone
  locked     git-locked worktree; left alone
  active     clean but not landed yet, or its reflog has only ever pointed at
             its creation commit; left alone unless named explicitly with
             `--prune --branch NAME`
  finalizing an active finalization ticket owns this branch; left alone unless
             named explicitly with `--prune --branch NAME`
  UNREADABLE `git status` failed here, so nothing about it is established -
             never pruned. Investigate by hand; a stale .git pointer or a
             permissions problem is the usual cause.

  scripts/worktree-clean.sh --purge-builds        free root, artifact, and registered package build output
  scripts/worktree-clean.sh --purge-builds --all  sweep every row (breaks builds running now)
  scripts/worktree-clean.sh --prune               remove the LANDED rows, their sims, their branches
  scripts/worktree-clean.sh --prune --branch NAME remove only one landed task and its remote branch
EOF
