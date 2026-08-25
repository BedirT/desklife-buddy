#!/bin/bash -p
# Durable FIFO admission for final task finalization.
#
# This is deliberately separate from the short-lived worktree mutation lock.
# Review inspection can span multiple commands, so the queue ticket remains
# active after the process that acquired it exits. The owning worktree can
# explicitly resume or abort that ticket; no reviewer output is auto-accepted.

if ! declare -F acquire_worktree_lock >/dev/null 2>&1; then
  ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}"
  # shellcheck source=scripts/worktree-lock.sh
  . "$ROOT/scripts/worktree-lock.sh"
fi

FINALIZATION_QUEUE_COMMON_DIR="${FINALIZATION_QUEUE_COMMON_DIR:-$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)}"
FINALIZATION_QUEUE_DIR="${FINALIZATION_QUEUE_DIR:-$FINALIZATION_QUEUE_COMMON_DIR/agent-finalization}"
FINALIZATION_QUEUE_LOCK_WAIT="${FINALIZATION_QUEUE_LOCK_WAIT:-900}"
FINALIZATION_QUEUE_CREATED_TICKET=""
FINALIZATION_QUEUE_CREATED_TOKEN=""
FINALIZATION_QUEUE_ACQUIRED_TICKET=""

finalization_queue_die() {
  echo "finalization queue: $*" >&2
  return 1
}

finalization_queue_field() {
  local key="$1" file="$2"
  awk -F': ' -v key="$key" '$1 == key { value = substr($0, length(key) + 3) } END { if (value != "") print value }' "$file"
}

finalization_queue_files() {
  local file
  for file in "$FINALIZATION_QUEUE_DIR"/*.ticket; do
    [[ -f "$file" ]] && printf '%s\n' "$file"
  done | LC_ALL=C sort
}

finalization_queue_ticket_for_branch() {
  local branch="$1" file found="" count=0
  while IFS= read -r file; do
    [[ "$(finalization_queue_field Branch "$file")" == "$branch" ]] || continue
    found="$file"
    count=$((count + 1))
  done < <(finalization_queue_files)
  if [[ "$count" -gt 1 ]]; then
    finalization_queue_die "branch $branch has $count active tickets"
    return 1
  fi
  if [[ "$count" -eq 1 ]]; then
    printf '%s\n' "$found"
  fi
  return 0
}

finalization_queue_write() {
  local file="$1" token="$2" branch="$3" worktree="$4" phase="$5" created="$6" updated="$7"
  local temporary="${file}.tmp.$$"
  printf 'Version: 1\nTicket: %s\nBranch: %s\nWorktree: %s\nPhase: %s\nCreated-At: %s\nUpdated-At: %s\n' \
    "$token" "$branch" "$worktree" "$phase" "$created" "$updated" >"$temporary" || return 1
  mv "$temporary" "$file"
}

finalization_queue_now() { date +%s; }

finalization_queue_wait_for_lock() {
  local operation="$1" lock_wait="${2:-$FINALIZATION_QUEUE_LOCK_WAIT}" warned=0
  while ! acquire_worktree_lock "$operation" "$lock_wait"; do
    if [[ "$warned" -eq 0 ]]; then
      echo "$operation: finalization queue remains waiting for the shared lock" >&2
      warned=1
    fi
    sleep 1
  done
}

finalization_queue_create() {
  local branch="$1" worktree="$2" token sequence sequence_file ticket created existing
  FINALIZATION_QUEUE_CREATED_TICKET=""
  FINALIZATION_QUEUE_CREATED_TOKEN=""
  mkdir -p "$FINALIZATION_QUEUE_DIR" || return 1
  if ! existing="$(finalization_queue_ticket_for_branch "$branch")"; then
    return 1
  fi
  if [[ -n "$existing" ]]; then
    finalization_queue_die "branch $branch already has a ticket"
    return 1
  fi

  sequence_file="$FINALIZATION_QUEUE_DIR/.next"
  sequence=0
  if [[ -f "$sequence_file" ]]; then
    sequence="$(cat "$sequence_file")"
    if ! [[ "$sequence" =~ ^[0-9]+$ ]]; then
      finalization_queue_die "queue sequence is corrupt"
      return 1
    fi
  fi
  sequence=$((sequence + 1))
  printf '%s\n' "$sequence" >"$sequence_file.tmp.$$" || return 1
  mv "$sequence_file.tmp.$$" "$sequence_file"

  token="$(printf '%s' "$branch|$worktree|$$|$RANDOM|$(finalization_queue_now)" | git hash-object --stdin)"
  ticket="$FINALIZATION_QUEUE_DIR/$(printf '%020d' "$sequence")-$token.ticket"
  FINALIZATION_QUEUE_CREATED_TICKET="$ticket"
  FINALIZATION_QUEUE_CREATED_TOKEN="$token"
  created="$(finalization_queue_now)"
  if ! finalization_queue_write "$ticket" "$token" "$branch" "$worktree" waiting "$created" "$created"; then
    FINALIZATION_QUEUE_CREATED_TICKET=""
    FINALIZATION_QUEUE_CREATED_TOKEN=""
    return 1
  fi
}

finalization_queue_admit() {
  local ticket="$1" file first token branch worktree now phase
  first="$(finalization_queue_files | awk 'NR == 1 { value = $0 } END { if (value != "") print value }')"
  [[ "$first" == "$ticket" ]] || return 1
  token="$(finalization_queue_field Ticket "$ticket")"
  branch="$(finalization_queue_field Branch "$ticket")"
  worktree="$(finalization_queue_field Worktree "$ticket")"
  phase="$(finalization_queue_field Phase "$ticket")"
  [[ "$phase" == waiting ]] || return 0
  now="$(finalization_queue_now)"
  finalization_queue_write "$ticket" "$token" "$branch" "$worktree" active \
    "$(finalization_queue_field Created-At "$ticket")" "$now"
}

finalization_queue_acquire() {
  local branch="$1" worktree="$2" lock_wait="${3:-$FINALIZATION_QUEUE_LOCK_WAIT}"
  local ticket warned=0
  FINALIZATION_QUEUE_ACQUIRED_TICKET=""
  finalization_queue_wait_for_lock "finalization queue create $branch" "$lock_wait"
  if ! finalization_queue_create "$branch" "$worktree"; then
    release_worktree_lock
    return 1
  fi
  ticket="$FINALIZATION_QUEUE_CREATED_TICKET"
  FINALIZATION_QUEUE_ACQUIRED_TICKET="$FINALIZATION_QUEUE_CREATED_TOKEN"
  release_worktree_lock

  while :; do
    finalization_queue_wait_for_lock "finalization queue $branch" "$lock_wait"
    if finalization_queue_admit "$ticket"; then
      release_worktree_lock
      return 0
    fi
    release_worktree_lock
    if [[ ! -e "$ticket" ]]; then
      echo "$branch: its finalization ticket disappeared; aborting" >&2
      return 1
    fi
    if [[ "$warned" -eq 0 ]]; then
      echo "$branch: waiting for finalization queue" >&2
      warned=1
    fi
    sleep 1
  done
}

finalization_queue_require() {
  local branch="$1" worktree="$2" token="$3" expected_phase="${4:-}"
  local ticket actual_token actual_branch actual_worktree actual_phase
  if ! ticket="$(finalization_queue_ticket_for_branch "$branch")"; then
    return 1
  fi
  if [[ -z "$ticket" ]]; then
    finalization_queue_die "branch $branch has no finalization ticket"
    return 1
  fi
  actual_token="$(finalization_queue_field Ticket "$ticket")"
  actual_branch="$(finalization_queue_field Branch "$ticket")"
  actual_worktree="$(finalization_queue_field Worktree "$ticket")"
  actual_phase="$(finalization_queue_field Phase "$ticket")"
  if [[ "$actual_token" != "$token" || "$actual_branch" != "$branch" ||
        "$actual_worktree" != "$worktree" ]]; then
    finalization_queue_die "ticket does not belong to $branch at $worktree"
    return 1
  fi
  if [[ -n "$expected_phase" && "$actual_phase" != "$expected_phase" ]]; then
    finalization_queue_die "ticket for $branch is in phase '$actual_phase', expected '$expected_phase'"
    return 1
  fi
  printf '%s\n' "$ticket"
}

finalization_queue_mark_review_pending() {
  local branch="$1" worktree="$2" token="$3" ticket now
  finalization_queue_wait_for_lock "finalization queue $branch"
  ticket="$(finalization_queue_require "$branch" "$worktree" "$token" active)" || {
    release_worktree_lock
    return 1
  }
  now="$(finalization_queue_now)"
  finalization_queue_write "$ticket" "$token" "$branch" "$worktree" review-pending \
    "$(finalization_queue_field Created-At "$ticket")" "$now"
  release_worktree_lock
}

finalization_queue_remove_ticket() {
  local ticket="$1"
  rm -f "$ticket" || return 1
  if [[ -z "$(finalization_queue_files)" ]]; then
    rm -f "$FINALIZATION_QUEUE_DIR/.next"
    rmdir "$FINALIZATION_QUEUE_DIR" 2>/dev/null || true
  fi
}

finalization_queue_release() {
  local branch="$1" worktree="$2" token="$3" ticket
  finalization_queue_wait_for_lock "finalization queue release $branch"
  ticket="$(finalization_queue_require "$branch" "$worktree" "$token")" || {
    release_worktree_lock
    return 1
  }
  finalization_queue_remove_ticket "$ticket" || {
    release_worktree_lock
    return 1
  }
  release_worktree_lock
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "This file provides finalization queue functions for repository scripts." >&2
  exit 0
fi
