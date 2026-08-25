#!/bin/bash -p
# Rehearse the opportunistic cleanup contract against a disposable worktree.
#
# The rm stub removes the easy part of a build and then reports a live-writer
# failure. That is deterministic, exercises the same non-zero rm path, and
# never touches this checkout's build output or another agent's worktree.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/purge-rehearsal-XXXXXX")"
REAL_RM="$(command -v rm)"
REAL_DU="$(command -v du)"
export REAL_RM REAL_DU
PASS=0
EXPECTED_FAILURES=0

cleanup() {
  chmod -R u+w "$SANDBOX" 2>/dev/null || true
  "$REAL_RM" -rf "$SANDBOX"
}
trap cleanup EXIT INT TERM

ok() {
  PASS=$((PASS + 1))
  printf '  ok   %s\n' "$1"
}

fail() {
  echo "worktree-purge rehearsal: $*" >&2
  exit 1
}

check() {
  [[ "$2" == "$3" ]] || fail "$1: got '$2', want '$3'"
  ok "$1"
}

contains() {
  [[ "$2" == *"$3"* ]] || fail "$1: output lacks '$3'"
  ok "$1"
}

expect_check() {
  if [[ "$2" == "$3" ]]; then
    ok "$1"
  else
    EXPECTED_FAILURES=$((EXPECTED_FAILURES + 1))
    printf '  FAIL %s: got '\''%s'\'', want '\''%s'\''\n' "$1" "$2" "$3" >&2
  fi
}

expect_contains() {
  if [[ "$2" == *"$3"* ]]; then
    ok "$1"
  else
    EXPECTED_FAILURES=$((EXPECTED_FAILURES + 1))
    printf '  FAIL %s: output lacks '\''%s'\''\n' "$1" "$3" >&2
  fi
}

new_world() {
  local world="$SANDBOX/world" main task
  mkdir -p "$world/bin"
  git init --quiet --bare -b main "$world/origin.git"
  git clone --quiet "$world/origin.git" "$world/integration" 2>/dev/null
  main="$world/integration"
  printf 'artifacts/\n.build/\nscripts/\n.worktree-env\n.worktree-session\nPackages/*/.build/\nPackages/*/.swiftpm/\nPackages/Linked\n' >"$main/.gitignore"
  printf 'base\n' >"$main/base.txt"
  git -C "$main" add -A
  git -C "$main" commit --quiet -m base
  git -C "$main" push --quiet -u origin main
  git -C "$main" worktree add --quiet -b agent/task "$world/task" main
  task="$world/task"
  printf 'feature\n' >"$task/feature.txt"
  for package in Domain DesignSystem Features; do
    mkdir -p "$task/Packages/$package"
    printf '// rehearsal package\n' >"$task/Packages/$package/Package.swift"
  done
  git -C "$task" add feature.txt
  git -C "$task" add Packages
  git -C "$task" commit --quiet -m feature
  mkdir -p "$task/scripts"
  cp "$ROOT/scripts/worktree-finish.sh" "$task/scripts/worktree-finish.sh"
  cp "$ROOT/scripts/worktree-clean.sh" "$task/scripts/worktree-clean.sh"
  cp "$ROOT/scripts/worktree-lock.sh" "$task/scripts/worktree-lock.sh"
  cp "$ROOT/scripts/worktree-session.sh" "$task/scripts/worktree-session.sh"
  chmod +x "$task/scripts/"*.sh
  mkdir -p "$task/artifacts" "$task/.build/DerivedData" "$task/.build/Other"
  for package in Domain DesignSystem Features; do
    mkdir -p "$task/Packages/$package/.build"
    printf 'package cache\n' >"$task/Packages/$package/.build/cache.bin"
  done
  mkdir -p "$task/Packages/Domain/.swiftpm"
  printf 'package state\n' >"$task/Packages/Domain/.swiftpm/workspace-state.json"
  mkdir -p "$task/Packages/Unregistered/.build"
  printf 'unregistered cache\n' >"$task/Packages/Unregistered/.build/cache.bin"
  printf 'session state\n' >"$task/.worktree-session"
  printf 'sim state\n' >"$task/.worktree-env"
  printf 'review\n' >"$task/artifacts/review.md"
  HEAD_SHA="$(git -C "$task" rev-parse HEAD)"
  BASE_SHA="$(git -C "$task" rev-parse origin/main)"
  cat >"$task/artifacts/review.md" <<EOF
Review-Head: $HEAD_SHA
Review-Base: $BASE_SHA
Review-Verdict: clean

No material findings.
EOF
  printf 'busy\n' >"$task/.build/DerivedData/locked.bin"
  printf '%s\n' "$task"
}

BIN="$SANDBOX/bin"
mkdir -p "$BIN"

# The report must count the same package paths that purge later removes. Return
# deterministic large values so a package-local omission is visible in the
# human-readable GB column without making the rehearsal write large files.
cat >"$BIN/du" <<'STUB'
#!/bin/bash -p
set -euo pipefail
if [[ "${1:-}" == "-sk" ]]; then
    shift
  for path in "$@"; do
    case "$path" in
      */Packages/Domain/.build|*/Packages/DesignSystem/.build|*/Packages/Features/.build)
        printf '1048576 %s\n' "$path"
        ;;
      */.build) printf '1048576 %s\n' "$path" ;;
      */artifacts) printf '1048576 %s\n' "$path" ;;
    esac
  done
  exit 0
fi
exec "${REAL_DU:?}" "$@"
STUB
chmod +x "$BIN/du"

TASK="$(new_world)"
EXTERNAL="$SANDBOX/external"
mkdir -p "$EXTERNAL/.build"
printf 'external cache\n' >"$EXTERNAL/.build/cache.bin"
ln -s "$EXTERNAL" "$TASK/Packages/Linked"

set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" "$TASK/scripts/worktree-clean.sh" 2>&1)"
STATUS=$?
set -e
check "report rehearsal exits cleanly" "$STATUS" "0"
expect_contains "report includes registered package caches" "$OUT" "5.0G"

rm -f "$BIN/du"

cat >"$BIN/rm" <<'STUB'
#!/bin/bash -p
set -euo pipefail
paths=()
for arg in "$@"; do
  [[ "$arg" == -* ]] || paths+=("$arg")
done
if [[ "${paths[0]:-}" == */.build ]]; then
  for index in "${!paths[@]}"; do
    if [[ "$index" -eq 0 ]]; then
      "${REAL_RM:?}" -rf "${paths[index]}/Other" || true
    else
      "${REAL_RM:?}" -rf "${paths[index]}"
    fi
  done
  exit 1
fi
exec "${REAL_RM:?}" "$@"
STUB
chmod +x "$BIN/rm"

printf 'busy\n' >"$TASK/.build/Other/removable.bin"
set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" "$TASK/scripts/worktree-finish.sh" \
  --review artifacts/review.md --no-push 2>&1)"
STATUS=$?
set -e
check "finish keeps a busy cleanup from failing the handoff" "$STATUS" "0"
contains "finish reports the busy build" "$OUT" "Could not fully purge .build/"
contains "finish still prints its summary" "$OUT" "Handed off."
check "finish leaves the busy build for a later sweep" \
  "$([[ -e "$TASK/.build/DerivedData/locked.bin" ]] && echo present || echo gone)" "present"

printf 'artifact\n' >"$TASK/artifacts/kept.txt"
set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" "$TASK/scripts/worktree-clean.sh" \
  --purge-builds 2>&1)"
STATUS=$?
set -e
check "clean sweep continues after a busy rm" "$STATUS" "0"
contains "clean sweep reports a partial purge" "$OUT" "still busy, re-run later"
contains "clean sweep reports reclaimed space" "$OUT" "Total:"
check "clean sweep removes the idle artifacts half" \
  "$([[ -e "$TASK/artifacts" ]] && echo present || echo gone)" "gone"
check "clean sweep leaves the busy build" \
  "$([[ -e "$TASK/.build/DerivedData/locked.bin" ]] && echo present || echo gone)" "present"
expect_check "clean sweep removes Domain package build" \
  "$([[ -e "$TASK/Packages/Domain/.build" ]] && echo present || echo gone)" "gone"
expect_check "clean sweep removes DesignSystem package build" \
  "$([[ -e "$TASK/Packages/DesignSystem/.build" ]] && echo present || echo gone)" "gone"
expect_check "clean sweep removes Features package build" \
  "$([[ -e "$TASK/Packages/Features/.build" ]] && echo present || echo gone)" "gone"
expect_check "clean sweep preserves unregistered package cache" \
  "$([[ -e "$TASK/Packages/Unregistered/.build/cache.bin" ]] && echo present || echo gone)" "present"
expect_check "clean sweep preserves symlinked package cache" \
  "$([[ -e "$EXTERNAL/.build/cache.bin" ]] && echo present || echo gone)" "present"
expect_check "clean sweep preserves package source" \
  "$([[ -e "$TASK/Packages/Domain/Package.swift" ]] && echo present || echo gone)" "present"
expect_check "clean sweep preserves package state" \
  "$([[ -e "$TASK/Packages/Domain/.swiftpm/workspace-state.json" ]] && echo present || echo gone)" "present"
expect_check "clean sweep preserves session state" \
  "$([[ -e "$TASK/.worktree-session" ]] && echo present || echo gone)" "present"

# A symlink at the Packages boundary must not turn a worktree-scoped purge into
# a delete of an external package cache.
PACKAGES_REAL="$TASK/Packages"
PARENT_EXTERNAL="$SANDBOX/external-packages"
mkdir -p "$PARENT_EXTERNAL/Outside/.build"
printf '// external package\n' >"$PARENT_EXTERNAL/Outside/Package.swift"
printf 'external parent cache\n' >"$PARENT_EXTERNAL/Outside/.build/cache.bin"
mv "$PACKAGES_REAL" "$TASK/Packages-real"
ln -s "$PARENT_EXTERNAL" "$PACKAGES_REAL"
set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" "$TASK/scripts/worktree-clean.sh" \
  --purge-builds 2>&1)"
STATUS=$?
set -e
check "parent symlink purge exits cleanly" "$STATUS" "0"
expect_check "clean sweep preserves parent-symlinked package cache" \
  "$([[ -e "$PARENT_EXTERNAL/Outside/.build/cache.bin" ]] && echo present || echo gone)" "present"
"$REAL_RM" "$PACKAGES_REAL"
mv "$TASK/Packages-real" "$PACKAGES_REAL"

# Force the second size measurement to grow. The result must be zero, never a
# negative reclaimed-space total.
COUNT_FILE="$SANDBOX/du-count"
cat >"$BIN/du" <<'STUB'
#!/bin/bash -p
set -euo pipefail
if [[ "${1:-}" == -sk ]]; then
  count=0
  [[ ! -f "${DU_COUNT_FILE:?}" ]] || count="$(<"$DU_COUNT_FILE")"
  count=$((count + 1))
  printf '%s\n' "$count" >"$DU_COUNT_FILE"
  if [[ "$count" -le 3 ]]; then
    printf '100 %s\n0 %s\n' "$2" "$3"
  else
    printf '200 %s\n0 %s\n' "$2" "$3"
  fi
  exit 0
fi
exec "${REAL_DU:?}" "$@"
STUB
chmod +x "$BIN/du"
mkdir -p "$TASK/.build/Other" "$TASK/artifacts"
printf 'busy\n' >"$TASK/.build/DerivedData/locked-again.bin"
rm -f "$COUNT_FILE"
set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" DU_COUNT_FILE="$COUNT_FILE" \
  REAL_DU="$REAL_DU" "$TASK/scripts/worktree-clean.sh" --purge-builds 2>&1)"
STATUS=$?
set -e
check "growing busy tree still exits cleanly" "$STATUS" "0"
contains "growing tree clamps partial reclaim" "$OUT" "partly purged 0.0G"
contains "growing tree clamps total reclaim" "$OUT" "Total: 0.0G reclaimed"

rm -f "$BIN/du"
rm -f "$BIN/rm"
mkdir -p "$TASK/.build/idle" "$TASK/artifacts"
set +e
OUT="$(cd "$TASK" && PATH="$BIN:$PATH" "$TASK/scripts/worktree-clean.sh" --purge-builds 2>&1)"
STATUS=$?
set -e
check "idle cleanup exits cleanly" "$STATUS" "0"
contains "idle cleanup purges outright" "$OUT" "purged "
check "idle cleanup removes the build" \
  "$([[ -e "$TASK/.build" ]] && echo present || echo gone)" "gone"

printf '\n%d passed, %d failed\n' "$PASS" "$EXPECTED_FAILURES"
[[ "$EXPECTED_FAILURES" -eq 0 ]]
