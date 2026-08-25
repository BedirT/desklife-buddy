#!/bin/bash -p
# Preview-only state law. Runs inside scripts/lint.sh.
#
# Fails when an Optional property on an @Observable model is assigned a non-nil
# value ONLY by preview fixtures (`*+Previews.swift`, `*PreviewData*`,
# `*PreviewLibrary*`, `*PreviewFixture*`) and never by shipping code. That state
# renders perfectly in Xcode canvas, in the SnapshotPreviews contact sheet and in
# the baseline suite, and never once occurs in the app - every review surface the
# repo has stays green. (GleamRoll #43 shipped exactly that; #64 asked for this.)
#
# The rule reports a syntactic fact, not a proof: it never claims "nothing writes
# this". A property with no writers at all - state reachable only through
# injected app state - is silent, and any shipping write the analyzer cannot
# attribute counts in favour of reachability. That is why it can block.
#
# Genuine exception: annotate the declaration with
#   // observable-preview-wiring-exempt: <reason>
# The reason is the review artifact; an empty one is itself a violation.
#
# Usage: scripts/check-observable-preview-wiring.sh [source-root]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TARGET="${1:-$ROOT}"
PACKAGE="$ROOT/Tools/ObservablePreviewWiring"

if [[ ! -d "$TARGET" ]]; then
  echo "observable-preview-wiring: source root does not exist: $TARGET" >&2
  exit 2
fi

# Correct computed-property/backing-storage semantics need a real Swift parser;
# a regex scan reads `var x: T? { get { storage } }` as no declaration at all and
# goes green on the very shape this check exists to catch. The tool is host-only
# and never links into the app, so the swift-syntax pin is a developer
# dependency - bump it only with the toolchain, then re-run the rehearsal.
LOG="$(mktemp -t observable-preview-wiring)"
trap 'rm -f "$LOG"' EXIT
if ! swift build --package-path "$PACKAGE" --product observable-preview-wiring >"$LOG" 2>&1; then
  echo "observable-preview-wiring: failed to build the checker" >&2
  cat "$LOG" >&2
  exit 2
fi

BINARY="$(swift build --package-path "$PACKAGE" --product observable-preview-wiring --show-bin-path)/observable-preview-wiring"

# `exec` here would replace the shell before the EXIT trap runs and leak one
# build log per lint run, so the log goes now and the exit status is forwarded
# by hand.
rm -f "$LOG"
trap - EXIT
"$BINARY" "$TARGET"
