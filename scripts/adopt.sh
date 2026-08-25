#!/bin/bash -p
# Re-home an EXISTING SwiftUI app into this harness, on the app's own git history.
#
# Brownfield adoption — full re-home, done safely on a copy:
#   1. Clone <existing-app> to a working COPY  (the original is never touched).
#   2. Cut an adoption branch; overlay the whole harness/template onto the copy.
#   3. Commit a "template-state baseline" + a staged, resumable migration plan.
#   4. You push the branch; the agent migrates stage by stage from the plan.
#
# Usage (run from your swiftmac-base template checkout):
#   scripts/adopt.sh <path-to-existing-app> [copy-dest] [--branch <name>]
# Examples:
#   scripts/adopt.sh ~/Code/project-a               # -> ~/Code/project-a-copy
#   scripts/adopt.sh ~/Code/project-a /tmp/pa-copy  # explicit copy location
set -euo pipefail
TEMPLATE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SRC=""; COPY_DEST=""; BRANCH="agent/harness-adopt"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch)   BRANCH="${2:?--branch needs a name}"; shift 2 ;;
    --branch=*) BRANCH="${1#*=}"; shift ;;
    -h|--help)  sed -n '2,15p' "$0"; exit 0 ;;
    -*)         echo "adopt: unknown flag $1" >&2; exit 2 ;;
    *)  if   [[ -z "$SRC" ]];       then SRC="$1"
        elif [[ -z "$COPY_DEST" ]]; then COPY_DEST="$1"
        else echo "adopt: too many positional args" >&2; exit 2; fi; shift ;;
  esac
done

[[ -n "$SRC" ]] || { echo "usage: scripts/adopt.sh <existing-app> [copy-dest] [--branch name]" >&2; exit 2; }
[[ -d "$SRC" ]] || { echo "adopt: no such directory: $SRC" >&2; exit 2; }
SRC="$(cd "$SRC" && pwd)"
git -C "$SRC" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "adopt: $SRC is not a git repo — init + commit it first (history is the point)." >&2; exit 2; }

APP_NAME="$(basename "$SRC")"
COPY_DEST="${COPY_DEST:-$(dirname "$SRC")/${APP_NAME}-copy}"
[[ -e "$COPY_DEST" ]] && { echo "adopt: copy destination already exists: $COPY_DEST" >&2; exit 2; }

if [[ -n "$(git -C "$SRC" status --porcelain)" ]]; then
  echo "adopt: NOTE — $SRC has uncommitted changes; the copy captures committed state (HEAD) only." >&2
fi

echo "== Clone  $APP_NAME  ->  $COPY_DEST   (original untouched)"
git clone --quiet "$SRC" "$COPY_DEST"

UPSTREAM="$(git -C "$SRC" remote get-url origin 2>/dev/null || true)"
if [[ -n "$UPSTREAM" ]]; then
  git -C "$COPY_DEST" remote set-url origin "$UPSTREAM"
  echo "   origin -> $UPSTREAM   (push lands on the real remote)"
else
  git -C "$COPY_DEST" remote remove origin
  echo "   (source has no 'origin' remote; copy has no remote until you add one)"
fi

cd "$COPY_DEST"
COPY_ROOT="$(pwd -P)"
DEFAULT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git checkout --quiet -b "$BRANCH"

echo "== Overlay harness/template structure"
if [[ -L "$COPY_ROOT/.gitignore" ]]; then
  echo "adopt: refusing a symlinked .gitignore in the cloned app" >&2
  exit 2
fi
if [[ -e "$COPY_ROOT/pre-adopt" || -L "$COPY_ROOT/pre-adopt" ]]; then
  echo "adopt: reserved path already exists in the cloned app: pre-adopt" >&2
  exit 2
fi
mkdir "$COPY_ROOT/pre-adopt"
CONFLICTS=()
DENY=" . .. .git .build DerivedData artifacts .DS_Store .snapshot-operation-lock .snapshot-record-token pre-adopt "
overlay() {
  local name="$1" src="$TEMPLATE_ROOT/$1"
  [[ -e "$src" ]] || return 0
  case "$DENY" in *" $name "*) return 0 ;; esac
  # .gitignore: never clobber the app's — append the template's rules to merge.
  if [[ "$name" == ".gitignore" && -f ".gitignore" ]]; then
    { echo ""; echo "## --- appended by scripts/adopt.sh (harness) — dedupe/reconcile ---"; cat "$src"; } >> ".gitignore"
    return 0
  fi
  # Anything else that collides: park the app's copy under pre-adopt/ for the
  # migration to fold back in, then lay down the template's version.
  if [[ -e "$name" ]]; then
    git mv "$name" "pre-adopt/$name"
    CONFLICTS+=("$name")
  fi
  cp -R "$src" "./$name"
}
for entry in "$TEMPLATE_ROOT"/* "$TEMPLATE_ROOT"/.*; do
  [[ -e "$entry" ]] || continue
  overlay "$(basename "$entry")"
done
if [[ "${#CONFLICTS[@]}" -eq 0 ]]; then
  rmdir "$COPY_ROOT/pre-adopt"
fi

# .claude/skills must stay a relative symlink (cp -R preserves it; be defensive).
if [[ -d .agents/skills ]]; then
  rm -f .claude/skills 2>/dev/null || true
  mkdir -p .claude
  ln -s ../.agents/skills .claude/skills
fi

echo "== Generate migration plan  docs/plans/adopt-${APP_NAME}.md"
mkdir -p docs/plans
CONFLICT_MD=""
if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  for c in "${CONFLICTS[@]}"; do
    CONFLICT_MD+="- [ ] reconcile \`pre-adopt/$c\` into the harness version, then delete it"$'\n'
  done
else
  CONFLICT_MD="- none — no template/app path collisions"
fi
PLAN="docs/plans/adopt-${APP_NAME}.md"
/usr/bin/python3 -I - "$TEMPLATE_ROOT/docs/plans/adopt-TEMPLATE.md" "$PLAN" \
  "$APP_NAME" "$(date +%Y-%m-%d)" "$BRANCH" "$DEFAULT_BRANCH" "$CONFLICT_MD" <<'PY'
import sys
src, out, app, date, branch, default_branch, conflicts = sys.argv[1:8]
t = open(src).read()
for k, v in {"{{APP}}": app, "{{DATE}}": date, "{{BRANCH}}": branch,
             "{{DEFAULT_BRANCH}}": default_branch, "{{CONFLICTS}}": conflicts.rstrip()}.items():
    t = t.replace(k, v)
open(out, "w").write(t)
PY

echo "== Commit template-state baseline"
git add -A
git commit --quiet -m "Adopt harness: template-state baseline for $APP_NAME

Overlaid the swiftmac-base harness/template onto a copy of $APP_NAME on branch
'$BRANCH' (off '$DEFAULT_BRANCH'). The app's git history is preserved. Migration
is staged in $PLAN — work it top-down, one green stage per commit.

Files parked under pre-adopt/ (collided with the template): ${CONFLICTS[*]:-none}."

if [[ -n "$UPSTREAM" ]]; then
  PUBLISH_STEPS="   2. git push -u origin $BRANCH        # publish the baseline (review the diff first)
   3. gh pr create --draft --fill --base $DEFAULT_BRANCH"
else
  PUBLISH_STEPS="   2. git remote add origin <your-github-repository>
   3. git push -u origin $BRANCH
   4. gh pr create --draft --fill --base $DEFAULT_BRANCH"
fi

cat <<EOF

✅ Adopted $APP_NAME into a harness copy. The original was not modified.

   Copy:    $COPY_DEST
   Branch:  $BRANCH  (off $DEFAULT_BRANCH)
   Plan:    $PLAN   (${#CONFLICTS[@]} file(s) to reconcile)

Next:
   1. cd "$COPY_DEST"
$PUBLISH_STEPS
   - Open the copy in your agent → "continue the adoption" (\$adopt-app).
      It works the plan stage by stage; that plan file — not chat memory — is
      the source of truth for where you are and what's left.
EOF
