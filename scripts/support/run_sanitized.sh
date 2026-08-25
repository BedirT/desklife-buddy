#!/bin/bash -p
# Run a tool with a minimal environment suitable for app launch and evidence
# capture. Credential-bearing variables are explicitly shadowed with empties.
set -euo pipefail

if [[ "$#" -eq 0 ]]; then
  echo "usage: run_sanitized.sh <command> [arguments...]" >&2
  exit 2
fi

ACCOUNT="$(/usr/bin/id -un)"
PASSWD_ENTRY="$(/usr/bin/id -P "$ACCOUNT")"
IFS=: read -r USER_NAME _ _ _ _ _ _ _ USER_HOME USER_SHELL <<<"$PASSWD_ENTRY"
if [[ -z "$USER_HOME" || -z "$USER_SHELL" ]]; then
  echo "Could not derive the current account environment." >&2
  exit 1
fi
USER_UID="$(/usr/bin/id -u "$USER_NAME")"

trusted_owner() {
  local owner
  owner="$(/usr/bin/stat -f %u "$1")"
  [[ "$owner" == 0 || "$owner" == "$USER_UID" ]]
}

validate_apple_tool() {
  local path="$1" identifier="$2" label="$3"
  if [[ ! -f "$path" \
    || -L "$path" \
    || "$(/usr/bin/stat -f %l "$path")" != 1 \
    || $((8#$(/usr/bin/stat -f %Lp "$path") & 0022)) != 0 ]] \
    || ! trusted_owner "$path"; then
    echo "DEVELOPER_DIR contains an unsafe $label." >&2
    exit 2
  fi
  /usr/bin/codesign --verify --strict \
    --test-requirement="=identifier \"$identifier\" and anchor apple" \
    "$path" 2>/dev/null || {
    echo "DEVELOPER_DIR $label signature verification failed." >&2
    exit 2
  }
}

USER_TMP="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
[[ -n "$USER_TMP" ]] || USER_TMP=/tmp/

ENVIRONMENT=(
  /usr/bin/env -i
  "HOME=$USER_HOME"
  "LANG=en_US.UTF-8"
  "LC_CTYPE=en_US.UTF-8"
  "LOGNAME=$USER_NAME"
  "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
  "SHELL=$USER_SHELL"
  "TMPDIR=$USER_TMP"
  "USER=$USER_NAME"
)

REQUESTED_DEVELOPER="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"
CANONICAL_DEVELOPER="$(cd "$REQUESTED_DEVELOPER" 2>/dev/null && pwd -P)" || {
  echo "DEVELOPER_DIR must resolve to an installed Xcode developer directory." >&2
  exit 2
}
case "$CANONICAL_DEVELOPER" in
  /Applications/Xcode*.app/Contents/Developer) ;;
  *)
    echo "DEVELOPER_DIR must resolve inside an Xcode app in /Applications." >&2
    exit 2
    ;;
esac
XCODE_APP="${CANONICAL_DEVELOPER%/Contents/Developer}"
XCODEBUILD_BIN="$CANONICAL_DEVELOPER/usr/bin/xcodebuild"
MCPBRIDGE_BIN="$CANONICAL_DEVELOPER/usr/bin/mcpbridge"
for directory in \
  "$XCODE_APP" \
  "$XCODE_APP/Contents" \
  "$CANONICAL_DEVELOPER" \
  "$CANONICAL_DEVELOPER/usr" \
  "$CANONICAL_DEVELOPER/usr/bin"; do
  if [[ ! -d "$directory" || -L "$directory" \
    || $((8#$(/usr/bin/stat -f %Lp "$directory") & 0022)) != 0 ]] \
    || ! trusted_owner "$directory"; then
    echo "DEVELOPER_DIR contains an unsafe directory." >&2
    exit 2
  fi
done
validate_apple_tool "$XCODEBUILD_BIN" com.apple.dt.xcodebuild xcodebuild
validate_apple_tool "$MCPBRIDGE_BIN" com.apple.dt.mcpbridge mcpbridge
ENVIRONMENT+=("DEVELOPER_DIR=$CANONICAL_DEVELOPER")

while IFS= read -r name; do
  if [[ "$name" =~ (^|_)(API_?KEY|TOKEN|SECRET|PASS(WORD|PHRASE)?|CREDENTIALS?|AUTH(ORIZATION)?|COOKIE|PRIVATE_?KEY|ACCESS_?KEY|CLIENT_?SECRET|PAT)($|_) ]] \
    || [[ "$name" =~ (API_?KEY|APIKEY|PASSWORD|PASSWD|TOKEN|SECRET|CREDENTIALS?|AUTH|COOKIE|PRIVATE_?KEY|PRIVATEKEY|ACCESS_?KEY|ACCESSKEY|CLIENT_?SECRET|PAT)$ ]] \
    || [[ "$name" == "MYSQL_PWD" || "$name" == "PGPASSFILE" ]] \
    || [[ "$name" =~ ^(CODEX|CLAUDE|GITHUB|AWS|AZURE|GOOGLE|OPENAI|ANTHROPIC|RUNWAY)($|_) ]] \
    || [[ "$name" =~ ^(PI|GH)($|_) ]]; then
    ENVIRONMENT+=("$name=")
  fi
done < <(compgen -e | LC_ALL=C /usr/bin/sort -u)

ENVIRONMENT+=("SSH_AUTH_SOCK=" "GPG_AGENT_INFO=")

exec "${ENVIRONMENT[@]}" "$@"
