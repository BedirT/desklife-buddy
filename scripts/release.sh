#!/bin/bash -p
# Release machinery. Three modes:
#   scripts/release.sh preflight          # full verification gate + human checklist
#   scripts/release.sh bump 1.2.0         # set MARKETING_VERSION, increment build
#   scripts/release.sh archive [TEAM_ID]  # Release archive + optional .pkg/.app export
#
# `archive` needs signing: TEAM_ID arg or DEVELOPMENT_TEAM env, with an Apple
# Developer account usable by Xcode. Distribution/upload stays human-owned.
. "$(dirname "$0")/lib.sh"
cd "$ROOT"
secure_artifact_storage

MODE="${1:?mode: preflight | bump <version> | archive [team-id]}"

case "$MODE" in
  preflight)
    "$ROOT/scripts/test.sh" all
    "$ROOT/scripts/snapshot.sh" Features
    "$ROOT/scripts/snapshot.sh" DesignSystem
    "$ROOT/scripts/build.sh"
    "$ROOT/scripts/lint.sh"
    echo
    echo "Automated gate: GREEN. Human checklist before archiving:"
    echo "  [ ] capture-matrix.sh output reviewed for changed windows"
    echo "  [ ] motion feel checked where animations changed"
    echo "  [ ] version bumped (scripts/release.sh bump X.Y.Z)"
    echo "  [ ] AppIcon asset is real (template ships a placeholder)"
    echo "  [ ] signing/export method chosen (App Store, Developer ID, or local archive)"
    echo "  [ ] release notes drafted (git log --oneline <last-tag>..HEAD)"
    ;;

  bump)
    VERSION="${2:?semantic version, e.g. 1.2.0}"
    /usr/bin/python3 -I - "$ROOT/App.xcodeproj/project.pbxproj" "$VERSION" <<'PY'
import re
import sys

path, version = sys.argv[1], sys.argv[2]
text = open(path).read()
text = re.sub(r"MARKETING_VERSION = [^;]+;", f"MARKETING_VERSION = {version};", text)

builds = [int(m) for m in re.findall(r"CURRENT_PROJECT_VERSION = (\d+);", text)]
next_build = (max(builds) if builds else 0) + 1
text = re.sub(r"CURRENT_PROJECT_VERSION = \d+;", f"CURRENT_PROJECT_VERSION = {next_build};", text)

open(path, "w").write(text)
print(f"version -> {version}, build -> {next_build}")
PY
    ;;

  archive)
    TEAM="${2:-${DEVELOPMENT_TEAM:-}}"
    STAMP="$(timestamp)"
    ARCHIVE="$ARTIFACTS/release/App-$STAMP.xcarchive"
    EXPORT_DIR="$ARTIFACTS/release/export-$STAMP"
    EXPORT_METHOD="${EXPORT_METHOD:-app-store-connect}"
    mkdir -p "$ARTIFACTS/release"

    ARCHIVE_ARGS=(
      archive
      "${XCB_CONTAINER[@]}"
      -scheme "$SCHEME"
      -configuration Release
      -destination 'generic/platform=macOS'
      -derivedDataPath "$DERIVED"
      -archivePath "$ARCHIVE"
    )
    if [[ -n "$TEAM" ]]; then
      ARCHIVE_ARGS+=(DEVELOPMENT_TEAM="$TEAM")
    fi

    run_sanitized /usr/bin/xcodebuild "${ARCHIVE_ARGS[@]}" 2>&1 | beautify

    echo "ARCHIVE: $ARCHIVE"

    if [[ -z "$TEAM" && "${EXPORT_WITHOUT_TEAM:-0}" != "1" ]]; then
      echo "No team provided; archive created without export."
      echo "To export, rerun with scripts/release.sh archive <TEAM_ID> or set EXPORT_WITHOUT_TEAM=1 for a local export attempt."
      exit 0
    fi

    PLIST="$ARTIFACTS/release/ExportOptions-$STAMP.plist"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>$EXPORT_METHOD</string>
EOF
    if [[ -n "$TEAM" ]]; then
      cat >> "$PLIST" <<EOF
  <key>teamID</key><string>$TEAM</string>
EOF
    fi
    cat >> "$PLIST" <<'EOF'
  <key>uploadSymbols</key><true/>
</dict>
</plist>
EOF

    run_sanitized /usr/bin/xcodebuild -exportArchive \
      -archivePath "$ARCHIVE" \
      -exportOptionsPlist "$PLIST" \
      -exportPath "$EXPORT_DIR" 2>&1 | beautify

    echo "EXPORT:  $EXPORT_DIR"
    echo "Method:  $EXPORT_METHOD"
    echo "Distribution/upload remains a human step."
    ;;

  *)
    echo "Unknown mode: $MODE (preflight | bump <version> | archive [team-id])" >&2
    exit 2
    ;;
esac
