#!/bin/bash -p
# Rehearse the preview-only state law against a disposable source tree.
#
# The unit tests pin the analyzer's rules; this pins the thing that actually
# matters: that the check catches a computed Optional state written by previews
# but never by shipping code. The disposable fixture keeps this harness test
# independent of whichever example feature the template currently carries.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/observable-preview-wiring-rehearsal-XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

fail() {
  echo "observable-preview-wiring rehearsal: $*" >&2
  exit 1
}

swift test --package-path "$ROOT/Tools/ObservablePreviewWiring" >/dev/null ||
  fail "analyzer unit tests failed"

feature="$SANDBOX/Packages/Features/Sources/Fixture"
mkdir -p "$feature" "$SANDBOX/App"
printf '%s\n' \
  'import Observation' \
  '@Observable final class FixtureModel {' \
  '    private var progressStorage: FixtureProgress?' \
  '    var progress: FixtureProgress? {' \
  '        get { progressStorage }' \
  '        set { progressStorage = newValue }' \
  '    }' \
  '}' \
  'struct FixtureProgress {}' >"$feature/FixtureModel.swift"
printf '%s\n' \
  'func makePreviewFixture() -> FixtureModel {' \
  '    let model = FixtureModel()' \
  '    model.progress = FixtureProgress()' \
  '    return model' \
  '}' >"$feature/FixtureView+Previews.swift"
printf '%s\n' \
  'func configureShippingFixture(_ model: FixtureModel) {' \
  '    model.progress = FixtureProgress()' \
  '}' >"$SANDBOX/App/AppComposition+Fixture.swift"

# lint.sh runs this on every invocation, so a temp file that outlives a
# successful run accumulates one build log per lint.
logs_before="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'observable-preview-wiring*' | wc -l)"

"$ROOT/scripts/check-observable-preview-wiring.sh" "$SANDBOX" >/dev/null ||
  fail "the intact progress wiring should pass"

logs_after="$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'observable-preview-wiring*' | wc -l)"
[[ "$logs_before" -eq "$logs_after" ]] ||
  fail "a successful run leaked its temporary build log"

# The #64 regression: the App/ writer goes away, the preview fixture stays, and
# every other review surface in the repo still renders the state correctly.
sharing="$SANDBOX/App/AppComposition+Fixture.swift"
sed -i.bak 's/model\.progress = FixtureProgress()/_ = model/' "$sharing"
rm -f "$sharing.bak"
grep -Fq 'model.progress = FixtureProgress()' "$sharing" &&
  fail "fixture edit did not remove the App/ writers"

set +e
output="$("$ROOT/scripts/check-observable-preview-wiring.sh" "$SANDBOX" 2>&1)"
status=$?
set -e

[[ "$status" -eq 1 ]] ||
  fail "dropping the App/ writer was not caught (exit $status)"
grep -Fq 'FixtureModel.progress' <<<"$output" ||
  fail "failure did not identify FixtureModel.progress"
grep -Fq 'FixtureView+Previews.swift' <<<"$output" ||
  fail "failure did not identify the preview-only writer"

# An exemption with a stated reason is the sanctioned escape hatch.
model="$feature/FixtureModel.swift"
sed -i.bak 's|^\( *\)var progress: FixtureProgress? {|\1// observable-preview-wiring-exempt: rehearsal fixture.\n\1var progress: FixtureProgress? {|' "$model"
rm -f "$model.bak"

"$ROOT/scripts/check-observable-preview-wiring.sh" "$SANDBOX" >/dev/null ||
  fail "a reasoned exemption should silence the finding"

# An exemption without a reason is itself a violation.
sed -i.bak 's|// observable-preview-wiring-exempt: rehearsal fixture.|// observable-preview-wiring-exempt:|' "$model"
rm -f "$model.bak"

set +e
output="$("$ROOT/scripts/check-observable-preview-wiring.sh" "$SANDBOX" 2>&1)"
status=$?
set -e

[[ "$status" -eq 1 ]] ||
  fail "an empty exemption reason was accepted"
grep -Fq 'no reason' <<<"$output" ||
  fail "failure did not explain the empty exemption reason"

echo "check-observable-preview-wiring rehearsal: passed"
