#!/bin/bash -p
# Pinned, mock-only SkillOpt adapter for the inert build-candidate factory.
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"
POLICY="$ROOT/.factory/skillopt.json"
ARTIFACTS="$ROOT/artifacts/skillopt"

usage() {
  echo "usage: scripts/skillopt.sh <doctor|mock-proof|policy>" >&2
  exit 2
}

read_policy() {
  /usr/bin/python3 -I - "$POLICY" <<'PY'
import json
import pathlib
import stat
import sys

path = pathlib.Path(sys.argv[1])
metadata = path.lstat()
if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1 or path.resolve() != path:
    raise SystemExit("skillopt: policy must be one regular non-linked file")
policy = json.loads(path.read_text(encoding="utf-8"))
expected = {
    "allow_provider_backends": False,
    "automatic_adoption": False,
    "maximum_edits": 4,
    "package": "skillopt",
    "package_version": "0.2.0",
    "status": "build-candidate-mock-only",
    "upstream_commit": "e4ea6a6771e797ef820cdd8bfea64c57e0481065",
    "upstream_repository": "https://github.com/microsoft/SkillOpt",
    "uv_version": "0.7.13",
}
if policy != expected:
    raise SystemExit("skillopt: checked-in adapter policy differs from the reviewed pin")
sys.stdout.write(json.dumps(policy, separators=(",", ":"), sort_keys=True))
PY
}

resolve_uv() {
  local observed uv_bin
  command -v mise >/dev/null || { echo "skillopt: mise is required; run mise install" >&2; exit 69; }
  uv_bin="$(mise exec -- command -v uv)"
  [[ -x "$uv_bin" && ! -L "$uv_bin" ]] || { echo "skillopt: pinned uv executable is unavailable" >&2; exit 69; }
  observed="$($uv_bin --version)"
  [[ "$observed" == "uv 0.7.13 "* ]] || { echo "skillopt: expected uv 0.7.13, got $observed" >&2; exit 69; }
  printf '%s' "$uv_bin"
}

doctor() {
  local uv_bin
  read_policy >/dev/null
  uv_bin="$(resolve_uv)"
  "$uv_bin" tool run --from skillopt==0.2.0 skillopt-sleep --help >/dev/null
  /usr/bin/printf '%s\n' '{"package":"skillopt","status":"passed","version":"0.2.0"}'
}

mock_proof() {
  local output temporary uv_bin
  read_policy >/dev/null
  uv_bin="$(resolve_uv)"
  /bin/mkdir -p "$ARTIFACTS"
  temporary="$(/usr/bin/mktemp -d "$ARTIFACTS/.mock-proof.XXXXXX")"
  trap '/bin/rm -rf "$temporary"' EXIT
  "$uv_bin" run --isolated --with skillopt==0.2.0 python \
    -m skillopt_sleep.experiments.run_experiment \
    --persona researcher --assert-improves >"$temporary/output.txt"
  /usr/bin/grep -Fq 'gate blocks harmful edit: True' "$temporary/output.txt"
  /usr/bin/grep -Fq 'PASS: nightly consolidation improves held-out score AND gate blocks regressions.' "$temporary/output.txt"
  /usr/bin/python3 -I - "$POLICY" "$temporary/output.txt" <<'PY' >"$temporary/manifest.json"
import hashlib
import json
import pathlib
import sys

policy = pathlib.Path(sys.argv[1]).read_bytes()
output = pathlib.Path(sys.argv[2]).read_bytes()
document = {
    "automatic_adoption": False,
    "backend": "mock",
    "output_sha256": hashlib.sha256(output).hexdigest(),
    "policy_sha256": hashlib.sha256(policy).hexdigest(),
    "provider_calls": 0,
    "qualification": "nonqualifying-bootstrap",
    "status": "passed",
}
sys.stdout.write(json.dumps(document, separators=(",", ":"), sort_keys=True))
PY
  output="$ARTIFACTS/mock-proof"
  /bin/rm -rf "$output"
  /bin/mv "$temporary" "$output"
  trap - EXIT
  /bin/echo "$output"
}

[[ "$#" -eq 1 ]] || usage
case "$1" in
  doctor) doctor ;;
  mock-proof) mock_proof ;;
  policy) read_policy ;;
  *) usage ;;
esac
