#!/bin/bash -p
# Fail when CI can gain unnecessary authority or execute mutable dependencies.
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"

"$ROOT/scripts/check-dependency-inputs.sh"

/usr/bin/python3 -I - "$ROOT" <<'PY'
from __future__ import annotations

import pathlib
import hashlib
import json
import os
import re
import stat
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
current_uid = os.getuid()
root_metadata = root.lstat()
if (
    not stat.S_ISDIR(root_metadata.st_mode)
    or root.is_symlink()
    or root_metadata.st_uid != current_uid
    or root_metadata.st_mode & 0o022
):
    raise SystemExit("CI security violation: repository root has unsafe ownership or mode")
workflow_dir = root / ".github" / "workflows"
workflow_paths = sorted((*workflow_dir.glob("*.yml"), *workflow_dir.glob("*.yaml")))
action_dir = root / ".github" / "actions"
action_paths = sorted((*action_dir.glob("**/action.yml"), *action_dir.glob("**/action.yaml")))
policy_paths = [*workflow_paths, *action_paths]
violations: list[str] = []


def report(message: str) -> None:
    violations.append(message)


def active_lines(path: pathlib.Path) -> tuple[str, ...]:
    return tuple(
        line.strip()
        for line in path.read_text().splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )


if not workflow_paths:
    report("no GitHub Actions workflows found")

expected_actions = {
    "actions/checkout": "9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0",  # v7.0.0
    "jdx/mise-action": "e6a8b3978addb5a52f2b4cd9d91eafa7f0ab959d",  # v4.2.0
}

for path in policy_paths:
    text = path.read_text()
    lines = text.splitlines()
    relative = path.relative_to(root)

    policy_text = "\n".join(line.split("#", 1)[0] for line in lines)
    if re.search(r"zizmor\s*:\s*ignore", text, re.IGNORECASE):
        report(f"{relative}: zizmor ignore directives are forbidden")
    if re.search(r"(?m)^\s*-\s*\{[^\n}]*(?:uses|permissions)\s*:", policy_text):
        report(f"{relative}: flow-style uses/permissions are forbidden")
    if re.search(r"\bpull_request_target\b", policy_text):
        report(f"{relative}: pull_request_target is forbidden")
    if re.search(r"(?m)^\s*continue-on-error\s*:\s*true\s*(?:#.*)?$", text):
        report(f"{relative}: continue-on-error may not hide verification failures")
    if re.search(r"doctor\.sh\s*\|\|\s*true", text):
        report(f"{relative}: doctor must not be silently ignored")
    github_remainder = text
    for allowed_github_reference in (
        r"\.github/",
        r"github\.workflow\b",
        r"github\.ref\b",
        r"github\.workspace\b",
        r"github\.event_name\b",
        r"github\.sha\b",
    ):
        github_remainder = re.sub(
            allowed_github_reference,
            "",
            github_remainder,
            flags=re.IGNORECASE,
        )
    if re.search(r"\bsecrets\b", text, re.IGNORECASE) or re.search(
        r"\bgithub\s*(?:\.\s*token\b|\[\s*['\"]token['\"]\s*\])",
        text,
        re.IGNORECASE,
    ) or re.search(r"\bgithub\b", github_remainder, re.IGNORECASE):
        report(f"{relative}: workflow code must not materialize GitHub or repository secrets")
    if re.search(
        r"\b(?:curl|wget|nc|ncat|socat|ftp|sftp|scp)\b",
        text,
    ):
        report(f"{relative}: ad hoc network transfer commands are forbidden")

    if path in workflow_paths:
        if re.search(r"(?m)^\s*defaults\s*:", policy_text):
            report(f"{relative}: workflow defaults are forbidden; security-sensitive steps pin their own shell and cwd")
        for line_number, line in enumerate(lines, start=1):
            match = re.match(r"^(\s*)permissions\s*:\s*(.*?)\s*(?:#.*)?$", line)
            if not match:
                continue
            if len(match.group(1)) != 0 or match.group(2):
                report(
                    f"{relative}:{line_number}: permissions must be the single block-style top-level declaration"
                )
        permission_blocks: list[tuple[int, list[str]]] = []
        for index, line in enumerate(lines):
            match = re.match(r"^(\s*)permissions\s*:\s*(?:#.*)?$", line)
            if not match:
                continue
            indent = len(match.group(1))
            block: list[str] = []
            cursor = index + 1
            while cursor < len(lines):
                candidate = lines[cursor]
                if not candidate.strip() or candidate.lstrip().startswith("#"):
                    cursor += 1
                    continue
                candidate_indent = len(candidate) - len(candidate.lstrip())
                if candidate_indent <= indent:
                    break
                block.append(candidate.strip())
                cursor += 1
            permission_blocks.append((indent, block))

        if permission_blocks != [(0, ["contents: read"])]:
            report(f"{relative}: permissions must be one top-level block containing only contents: read")

    for line_number, line in enumerate(lines, start=1):
        match = re.match(r"^\s*(?:-\s*)?uses\s*:\s*([^\s#]+)", line)
        if not match:
            continue
        value = match.group(1).strip('"\'')
        if value.startswith("./"):
            local_action = (root / value[2:]).resolve()
            expected_root = action_dir.resolve()
            manifests = (local_action / "action.yml", local_action / "action.yaml")
            if expected_root not in local_action.parents or not any(manifest.is_file() for manifest in manifests):
                report(f"{relative}:{line_number}: local action must be a reviewed .github/actions manifest: {value}")
            continue
        if value.startswith("docker://"):
            if "@sha256:" not in value:
                report(f"{relative}:{line_number}: container action is not digest-pinned: {value}")
            report(f"{relative}:{line_number}: container action has not been reviewed: {value}")
            continue
        if "@" not in value:
            report(f"{relative}:{line_number}: action has no immutable ref: {value}")
            continue
        action, ref = value.rsplit("@", 1)
        if not re.fullmatch(r"[0-9a-f]{40}", ref):
            report(f"{relative}:{line_number}: action is not pinned to a full commit SHA: {value}")
        expected = expected_actions.get(action)
        if expected is None:
            report(f"{relative}:{line_number}: external action has not been reviewed: {action}")
        elif ref != expected:
            report(f"{relative}:{line_number}: {action} must use reviewed commit {expected}")

ci_path = workflow_dir / "ci.yml"
if ci_path not in workflow_paths:
    report("missing .github/workflows/ci.yml")
else:
    ci = ci_path.read_text()
    if not re.search(r"(?m)^jobs:\s*$\n\s{2}verify:\s*$\n\s{4}name:\s*verify\s*$", ci):
        report("ci.yml: jobs.verify must declare stable name 'verify'")
    trigger_match = re.search(r"(?ms)^on:\s*\n(?P<body>.*?)^permissions:\s*$", ci)
    trigger_lines = () if trigger_match is None else tuple(
        line.strip()
        for line in trigger_match.group("body").splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )
    if trigger_lines != ("workflow_dispatch:",):
        report("ci.yml: hosted verification must be manual workflow_dispatch only")

    def action_step(action: str) -> str:
        action_line = next(
            (index for index, line in enumerate(ci.splitlines()) if f"uses: {action}@" in line),
            None,
        )
        if action_line is None:
            return ""
        all_lines = ci.splitlines()
        start = action_line
        while start > 0 and not re.match(r"^\s{6}-\s", all_lines[start]):
            start -= 1
        end = action_line + 1
        while end < len(all_lines) and not re.match(r"^\s{6}-\s", all_lines[end]):
            end += 1
        return "\n".join(all_lines[start:end])

    def named_step(name: str) -> tuple[str, int]:
        all_lines = ci.splitlines()
        matches = [
            index for index, line in enumerate(all_lines)
            if line == f"      - name: {name}"
        ]
        if len(matches) != 1:
            return "", -1
        start = matches[0]
        end = start + 1
        while end < len(all_lines) and not re.match(r"^\s{6}-\s", all_lines[end]):
            end += 1
        return "\n".join(all_lines[start:end]), start

    checkout_step = action_step("actions/checkout")
    if not re.search(r"(?m)^\s+persist-credentials\s*:\s*false\s*$", checkout_step):
        report("ci.yml: checkout must set persist-credentials: false in its own step")
    mise_step = action_step("jdx/mise-action")
    required_mise_inputs = (
        "MISE_GLOBAL_CONFIG_FILE: ${{ github.workspace }}/mise.toml",
        'MISE_NO_ENV: "1"',
        'MISE_NO_HOOKS: "1"',
        "MISE_OVERRIDE_CONFIG_FILENAMES: mise.toml",
        "MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES: none",
        "MISE_SYSTEM_CONFIG_FILE: ${{ github.workspace }}/mise.toml",
        "MISE_TRUSTED_CONFIG_PATHS: ${{ github.workspace }}/mise.toml",
        "PATH: /usr/bin:/bin:/usr/sbin:/sbin",
        "version: 2026.6.3",
        "sha256: 737353e07a404ff7d0be079fcc9325fb5b68840293a5165c714c26deabee9a9d",
        "mise_dir: ${{ runner.temp }}/swiftmac-mise",
        'github_token: ""',
        "env: false",
        "cache_save: false",
        "working_directory: ${{ github.workspace }}",
    )
    for required in required_mise_inputs:
        if required not in mise_step:
            report(f"ci.yml: mise-action step is missing reviewed input: {required}")
    lock_step, lock_step_line = named_step("Verify reviewed dependency inputs")
    policy_step, policy_step_line = named_step("Enforce CI security policy")
    factory_test_step, _ = named_step("Factory and host tests (ladder rung 1)")
    snapshot_step, _ = named_step("Hosted snapshot render contract (non-baseline)")
    checkout_step_digest = hashlib.sha256(checkout_step.encode()).hexdigest()
    lock_step_digest = hashlib.sha256(lock_step.encode()).hexdigest()
    mise_step_digest = hashlib.sha256(mise_step.encode()).hexdigest()
    policy_step_digest = hashlib.sha256(policy_step.encode()).hexdigest()
    snapshot_step_digest = hashlib.sha256(snapshot_step.encode()).hexdigest()
    checkout_action_line = next(
        (index for index, line in enumerate(ci.splitlines()) if "uses: actions/checkout@" in line),
        -1,
    )
    mise_action_line = next(
        (index for index, line in enumerate(ci.splitlines()) if "uses: jdx/mise-action@" in line),
        -1,
    )
    step_starts = [
        index for index, line in enumerate(ci.splitlines())
        if re.match(r"^\s{6}-\s", line)
    ]
    checkout_step_line = next(
        (index for index in step_starts if index <= checkout_action_line < (
            next((candidate for candidate in step_starts if candidate > index), len(ci.splitlines()))
        )),
        -1,
    )
    mise_step_line = next(
        (index for index in step_starts if index <= mise_action_line < (
            next((candidate for candidate in step_starts if candidate > index), len(ci.splitlines()))
        )),
        -1,
    )
    following_step = next((index for index in step_starts if index > lock_step_line), -1)
    post_checkout_step = next((index for index in step_starts if index > checkout_step_line), -1)
    post_mise_step = next((index for index in step_starts if index > mise_step_line), -1)
    if (
        checkout_step_digest != "82833ff139d222a964f3b9fc56d66f0f18d686f568b335656f2819eee50f021b"
        or not step_starts
        or step_starts[0] != checkout_step_line
        or post_checkout_step != lock_step_line
    ):
        report("ci.yml: exact credential-free checkout must be the first step before dependency verification")
    if (
        lock_step_digest != "05ec14232e2193b74f15828e9c65dfb938a0714a64470fb62b0cb649dfdcb548"
        or not (0 <= lock_step_line < mise_action_line)
        or following_step != mise_step_line
    ):
        report("ci.yml: exact reviewed dependency-input check must run immediately before mise-action")
    if mise_step_digest != "dbde322d3b824c61382c58737e62e84fc7d6241487d3337a9b0e8f91f52a64b2":
        report("ci.yml: mise-action must use the exact reviewed config and hook isolation boundary")
    if (
        policy_step_digest != "282c190b1e5b6ea55a0c6ed71746c4d923f73281f03f4899d1fabcad356690bf"
        or post_mise_step != policy_step_line
    ):
        report("ci.yml: the exact CI security policy gate must run before mutable repo controllers")
    if "./scripts/test-template.sh" not in ci:
        report("ci.yml: destructive template smoke is required")
    factory_test_lines = tuple(
        line.strip()
        for line in factory_test_step.splitlines()
        if line.strip() and not line.lstrip().startswith("#")
    )
    if factory_test_lines != (
        "- name: Factory and host tests (ladder rung 1)",
        "run: ./scripts/test.sh all",
    ):
        report("ci.yml: the complete Factory and host test ladder is required")
    if snapshot_step_digest != "13a1cd794fe225c7e8311fbf0baf56fda78b64e8536476f9872f744b5c9418ba":
        report("ci.yml: hosted snapshot proof must be the exact non-baseline render contract")
    if "actions/upload-artifact" in ci or re.search(r"(?m)^\s+path:\s*artifacts/?\s*$", ci):
        report("ci.yml: raw artifact trees are local-restricted and must not be uploaded")

evaluator_workflows = {
    "selection": workflow_dir / "evaluator-selection.yml",
    "sealed": workflow_dir / "evaluator-sealed.yml",
}
expected_evaluator_workflow_digests = {
    "selection": "0c4ba5e156a7c4625ce21256e051d3915a5e55aee59f669cffd280f6b4d0b3ac",
    "sealed": "932108957c9bb6d88739d0cb7eaf942a76c1b669b460baa8c603b36417908304",
}
for partition, path in evaluator_workflows.items():
    if path not in workflow_paths:
        report(f"missing protected {partition} evaluator workflow")
        continue
    workflow = path.read_text()
    if hashlib.sha256(workflow.encode()).hexdigest() != expected_evaluator_workflow_digests[partition]:
        report(f"{path.relative_to(root)}: exact reviewed protected evaluator workflow changed")
    evaluator_uid_variable = f"FACTORY_{partition.upper()}_EVALUATOR_UID"
    required = (
        "  workflow_dispatch:\n",
        "      phase:\n",
        "        required: true\n",
        "        type: choice\n",
        "          - reserve\n",
        "          - evaluate\n",
        f"  group: factory-evaluator-{partition}\n",
        "  cancel-in-progress: false\n",
        "    if: github.ref == 'refs/tags/factory-v1-root'\n",
        f"    environment: factory-evaluator-{partition}\n",
        f"    runs-on: [self-hosted, macOS, factory-evaluator-{partition}]\n",
        "          EXPECTED_EVALUATOR_SHA256: ${{ vars.FACTORY_EVALUATOR_SHA256 }}\n",
        "          EXPECTED_EVALUATOR_TEAM_ID: ${{ vars.FACTORY_EVALUATOR_TEAM_ID }}\n",
        f"          EXPECTED_EVALUATOR_UID: ${{{{ vars.{evaluator_uid_variable} }}}}\n",
        "          EXPECTED_TRUSTED_ROOT_SHA: ${{ vars.FACTORY_TRUSTED_ROOT_SHA }}\n",
        "          PHASE: ${{ inputs.phase }}\n",
        "          WORKFLOW_SHA: ${{ github.sha }}\n",
        "        shell: /bin/bash --noprofile --norc -p -c 'exec /usr/bin/env -i PATH=/usr/bin:/bin:/usr/sbin:/sbin EXPECTED_EVALUATOR_SHA256=\"$EXPECTED_EVALUATOR_SHA256\" EXPECTED_EVALUATOR_TEAM_ID=\"$EXPECTED_EVALUATOR_TEAM_ID\" EXPECTED_EVALUATOR_UID=\"$EXPECTED_EVALUATOR_UID\" EXPECTED_TRUSTED_ROOT_SHA=\"$EXPECTED_TRUSTED_ROOT_SHA\" PHASE=\"$PHASE\" WORKFLOW_SHA=\"$WORKFLOW_SHA\" /bin/bash --noprofile --norc -e -o pipefail \"$1\"' _ {0}\n",
        "          binary=/usr/local/libexec/swiftmac-factory/FactoryEvaluator\n",
        f"          root=/var/db/swiftmac-factory/evaluator/{partition}\n",
        '          reservation="$root/inbox/reservation.json"\n',
        '          signing_key="$root/attestation.key"\n',
        '          /usr/bin/test "$WORKFLOW_SHA" = "$EXPECTED_TRUSTED_ROOT_SHA"\n',
        '          /usr/bin/test "$(/usr/bin/id -u)" != "0"\n',
        '          /usr/bin/test "$(/usr/bin/id -u)" = "$EXPECTED_EVALUATOR_UID"\n',
        "          for directory in /usr/local /usr/local/libexec /usr/local/libexec/swiftmac-factory; do\n",
        '            /usr/bin/test ! -L "$directory"\n',
        '            /usr/bin/test "$(/usr/bin/stat -f %HT "$directory")" = "Directory"\n',
        '            /usr/bin/test "$(/usr/bin/stat -f %u "$directory")" = "0"\n',
        "            (( (8#$mode & 8#22) == 0 ))\n",
        "          done\n",
        '          /usr/bin/test ! -L "$binary"\n',
        '          /usr/bin/test "$(/usr/bin/stat -f %u "$binary")" = "0"\n',
        '          /usr/bin/test "$(/usr/bin/stat -f %l "$binary")" = "1"\n',
        '          /usr/bin/test "$(/usr/bin/stat -f %Lp "$binary")" = "555"\n',
        '          /usr/bin/test "$(/usr/bin/shasum -a 256 "$binary" | /usr/bin/awk \'{print $1}\')" = "$EXPECTED_EVALUATOR_SHA256"\n',
        '          /usr/bin/codesign --verify --strict "$binary"\n',
        "          /usr/bin/codesign -dvv \"$binary\" 2>&1 | /usr/bin/grep -Eq 'flags=.*runtime'\n",
        '            | /usr/bin/grep -Eq "TeamIdentifier=$EXPECTED_EVALUATOR_TEAM_ID"\n',
        '          /usr/bin/test -z "$(/usr/bin/codesign -d --entitlements - "$binary" 2>/dev/null)"\n',
        '          /usr/sbin/spctl --assess --type execute --verbose=2 "$binary"\n',
        '          /usr/bin/test "$(/usr/bin/stat -f %Lp "$signing_key")" = "600"\n',
        '            reserve) input="$reservation" ;;\n',
        '            evaluate) input="$execution" ;;\n',
        "            *) exit 64 ;;\n",
        f'            reserve) "$binary" query reserve {partition} "$root/ledger" "$signing_key" "$reservation" ;;\n',
        f'            evaluate) "$binary" query evaluate {partition} "$root/ledger" "$signing_key" "$execution" ;;\n',
    )
    for value in required:
        if value not in workflow:
            report(f"{path.relative_to(root)}: missing protected evaluator contract: {value.strip()}")
    if "uses:" in workflow or "pull_request" in workflow or re.search(r"(?m)^\s+push\s*:", workflow):
        report(f"{path.relative_to(root)}: evaluator workflow must be dispatch-only and action-free")
    if f"query run {partition}" in workflow:
        report(f"{path.relative_to(root)}: private execution must begin only after a separate durable reservation")

codex_config_path = root / ".codex" / "config.toml"
expected_codex_config = (
    "[mcp_servers.xcodebuildmcp]",
    'command = "./scripts/xcodebuildmcp-session.sh"',
    'args = ["mcp"]',
    'cwd = "."',
    "enabled = false",
    "[mcp_servers.xcode]",
    'command = "./scripts/support/run_sanitized.sh"',
    'args = ["/usr/bin/xcrun", "mcpbridge"]',
    "enabled = false",
)
if active_lines(codex_config_path) != expected_codex_config:
    report(".codex/config.toml: only the two reviewed, sanitized MCP launchers are allowed")

codex_environment_path = root / ".codex" / "environments" / "environment.toml"
expected_codex_environment = (
    "version = 1",
    'name = "swiftmac-base"',
    "[setup]",
    'script = ""',
    "[[actions]]",
    'name = "Run"',
    'icon = "run"',
    'command = "./script/build_and_run.sh"',
)
if active_lines(codex_environment_path) != expected_codex_environment:
    report(".codex/environments/environment.toml: only the reviewed inert setup and Run action are allowed")

codex_rules_path = root / ".codex" / "rules" / "macos.rules"
expected_rule_lines = [
    'prefix_rule(pattern=["scripts/check-previews.sh"], decision="allow")',
    'prefix_rule(pattern=["./scripts/check-previews.sh"], decision="allow")',
]
allowed_commands = (
    ("doctor.sh",),
    ("build.sh",),
    ("test.sh",),
    ("snapshot.sh",),
    ("run.sh", "--verify"),
    ("lint.sh",),
    ("format.sh",),
    ("new-feature.sh",),
)
for command_prefix in ("scripts/", "./scripts/"):
    for command in allowed_commands:
        pattern = json.dumps([command_prefix + command[0], *command[1:]])
        expected_rule_lines.append(f'prefix_rule(pattern={pattern}, decision="allow")')
if active_lines(codex_rules_path) != tuple(expected_rule_lines):
    report(".codex/rules/macos.rules: approval rules must equal the reviewed verification command set")

snapshot_mode_owner = pathlib.PurePosixPath(
    "Packages/TestSupport/Sources/SnapshotSupport/SnapshotSupport.swift"
)
for swift_path in root.rglob("*.swift"):
    relative = swift_path.relative_to(root)
    if ".build" in relative.parts or relative == snapshot_mode_owner:
        continue
    metadata = swift_path.lstat()
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        report(f"{relative}: Swift source mode scan requires a single-link regular file")
        continue
    text = swift_path.read_text()
    if "SNAPSHOT_RENDER_ONLY" in text or "SNAPSHOT_BASELINE_VERIFICATION" in text:
        report(
            f"{relative}: snapshot verification mode flags are private to SnapshotSupport"
        )

privacy_controller_path = root / "scripts" / "support" / "artifact_privacy_scan.py"
privacy_library_path = root / "scripts" / "lib.sh"
visual_scanner_path = root / "scripts" / "support" / "visual_secret_scan.swift"
try:
    privacy_controller = privacy_controller_path.read_text()
    privacy_library = privacy_library_path.read_text()
    visual_scanner = visual_scanner_path.read_text()
except OSError:
    report("artifact privacy boundary controllers are missing")
else:
    required_privacy_controller_fragments = (
        "captured_stream(",
        "artifact_path_findings(",
        "module.scan_descriptor(staged.fileno()",
        "pass_fds=tuple(descriptors)",
        "artifact inventory changed during privacy scan",
        "MAX_ARTIFACT_ENTRIES",
        "st_ctime_ns",
        "VISUAL_BATCH_BYTES",
    )
    for fragment in required_privacy_controller_fragments:
        if fragment not in privacy_controller:
            report(f"artifact privacy controller is missing reviewed binding: {fragment}")
    if "--image-inventory" in privacy_controller or "--image-inventory" in privacy_library:
        report("artifact privacy scan must not reopen a path-based image inventory")
    if 'case descriptor(Int32)' not in visual_scanner or "func readData() throws -> Data" not in visual_scanner:
        report("visual secret scan must decode descriptor-bound inputs one at a time")
    if (
        'artifact_privacy_scan_with_timeout "$timeout_seconds" 0 0 "$@"' not in privacy_library
        or "/usr/bin/python3 -I \"$ROOT/scripts/support/artifact_privacy_scan.py\"" not in privacy_library
        or "trap cleanup_artifact_privacy_scan EXIT" not in privacy_library
    ):
        report("artifact privacy scan must use the single reviewed controller deadline")

mcp_package_path = root / "Tools" / "XcodeBuildMCP" / "package.json"
mcp_lock_path = root / "Tools" / "XcodeBuildMCP" / "package-lock.json"
mcp_wrapper_path = root / "scripts" / "xcodebuildmcp.sh"
if not mcp_package_path.is_file() or not mcp_lock_path.is_file():
    report("Tools/XcodeBuildMCP: package.json and package-lock.json are required")
else:
    try:
        mcp_package = json.loads(mcp_package_path.read_text())
        mcp_lock = json.loads(mcp_lock_path.read_text())
    except ValueError as error:
        report(f"Tools/XcodeBuildMCP: invalid package metadata: {error}")
    else:
        if mcp_package.get("dependencies") != {"xcodebuildmcp": "2.6.2"}:
            report("Tools/XcodeBuildMCP/package.json: dependency must be exactly xcodebuildmcp 2.6.2")
        packages = mcp_lock.get("packages", {})
        root_package = packages.get("", {})
        xcodebuild_package = packages.get("node_modules/xcodebuildmcp", {})
        if mcp_lock.get("lockfileVersion") != 3 or root_package.get("dependencies") != {"xcodebuildmcp": "2.6.2"}:
            report("Tools/XcodeBuildMCP/package-lock.json: lockfile v3 root dependency is required")
        if xcodebuild_package.get("version") != "2.6.2" or xcodebuild_package.get("integrity") != (
            "sha512-bTS7Bkz4NICHl12QU7CR70EA361KuR3BhIqp+27Yzj2/egTDImJvEyJPJ3qJZs/"
            "jjvsqMwEvxMimeyDTRm6AMQ=="
        ):
            report("Tools/XcodeBuildMCP/package-lock.json: reviewed package version/integrity is missing")
        for package_path, package in packages.items():
            if not package_path:
                continue
            if not isinstance(package.get("version"), str) or not isinstance(package.get("integrity"), str):
                report(f"Tools/XcodeBuildMCP/package-lock.json: unpinned package entry {package_path}")
if not mcp_wrapper_path.is_file():
    report("scripts/xcodebuildmcp.sh is required")
else:
    wrapper = mcp_wrapper_path.read_text()
    for required in (
        "#!/bin/bash -p",
        'DEFAULT_NODE_ROOT="$USER_HOME/.local/share/mise/installs/node/24.16.0"',
        "EXPECTED_NODE_SHA=1ee75375e33b94fc34b3b19aede049e11dae90efb63b374dc96d6bdace70c4b8",
        "EXPECTED_NODE_SHA=47483a524a057d93e246bb0e63867e2b4d189810aef53a6978d9e708a3d0f453",
        'verify_runtime_file "$NODE_BIN" "$EXPECTED_NODE_SHA"',
        "verify_runtime_file \"$NPM_CLI\" 8e5f6f3429f8cdbe693cdc29904e9d5a7b127a494bd15c804bd54c7403bfcbe7",
        '"$NODE_BIN" "$NPM_CLI" ci',
        "--timeout 300",
        '/usr/bin/python3 -I "$RUN_WITH_TIMEOUT"',
        "--ignore-scripts",
        "--allow-git=none",
        "NPM_CONFIG_USERCONFIG=/dev/null",
        "/usr/bin/lockf -s -t 900 6",
        'exec 6>>"$INSTALL_LOCK"',
        "start_process_group.py",
        "--inherit-process-group",
        "--owner-file",
        "--pass-fd 5",
        "--pass-fd 6",
        'exec 5>>"$RUN_ROOT/lease"',
        "generation_lease_status",
        "begin_managed_launch 1",
        ") </dev/null >&2 &",
        '"$NODE_BIN" "$RUN_CLI" "$@" <&0 &',
        'kill -KILL -- "-$child_pid"',
        "tree_digest.py",
        "bc194478d828a5f7b0df29c4421ee216ea18fc80863264dbfe959228ae19fb26",
        '== "2.6.2"',
        'cd "$ROOT"',
        'XCODEBUILDMCP_CWD="$ROOT"',
        "XCODEBUILDMCP_SENTRY_DISABLED=true",
        "run_sanitized.sh",
        "run_with_timeout.py",
        "verify_reviewed_file mise.toml",
    ):
        if required not in wrapper:
            report(f"scripts/xcodebuildmcp.sh: missing locked-install contract: {required}")
    for forbidden in ("#!/usr/bin/env bash", "command -v mise", "MISE_BIN="):
        if forbidden in wrapper:
            report(f"scripts/xcodebuildmcp.sh: ambient launcher is forbidden: {forbidden}")

sanitizer = (root / "scripts" / "support" / "run_sanitized.sh").read_text()
for required in (
    "/Applications/Xcode*.app/Contents/Developer",
    "/usr/bin/codesign --verify --strict",
    'validate_apple_tool "$XCODEBUILD_BIN" com.apple.dt.xcodebuild xcodebuild',
    'validate_apple_tool "$MCPBRIDGE_BIN" com.apple.dt.mcpbridge mcpbridge',
    'MCPBRIDGE_BIN="$CANONICAL_DEVELOPER/usr/bin/mcpbridge"',
    'REQUESTED_DEVELOPER="${DEVELOPER_DIR:-$(/usr/bin/xcode-select -p)}"',
):
    if required not in sanitizer:
        report(f"scripts/support/run_sanitized.sh: missing Xcode trust check: {required}")
if "LC_ALL=C /usr/bin/sort -u" not in sanitizer:
    report("scripts/support/run_sanitized.sh: environment-name sorting must use the system binary")

mcp_config = (root / ".xcodebuildmcp" / "config.yaml").read_text()
if not re.search(r"(?m)^sentryDisabled:\s*true\s*$", mcp_config):
    report(".xcodebuildmcp/config.yaml: telemetry must default off with sentryDisabled: true")

mise_path = root / "mise.toml"
lock_path = root / "mise.lock"
mise = mise_path.read_text() if mise_path.is_file() else ""
expected_tools = {
    "actionlint": ("1.7.12", "aqua:rhysd/actionlint"),
    "node": ("24.16.0", "core:node"),
    "swiftlint": ("0.61.0", "aqua:realm/SwiftLint"),
    "swiftformat": ("0.58.7", "github:nicklockwood/SwiftFormat"),
    "uv": ("0.7.13", "aqua:astral-sh/uv"),
    "xcbeautify": ("2.30.1", "aqua:cpisciotta/xcbeautify"),
    "zizmor": ("1.26.1", "aqua:zizmorcore/zizmor"),
}
for tool, (version, _backend) in expected_tools.items():
    match = re.search(rf'(?m)^{tool}\s*=\s*"([^"]+)"\s*$', mise)
    if not match or match.group(1) != version:
        report(f"mise.toml: {tool} must use reviewed version {version}")
if not re.search(r"(?m)^locked\s*=\s*true\s*$", mise):
    report("mise.toml: locked mode must be enabled")
if not lock_path.is_file():
    report("mise.lock is required")
else:
    lock = lock_path.read_text()
    for tool, (version, backend) in expected_tools.items():
        pattern = (
            rf"(?ms)^\[\[tools\.{re.escape(tool)}\]\]\s*$"
            rf".*?^version\s*=\s*\"{re.escape(version)}\"\s*$"
            rf".*?^backend\s*=\s*\"{re.escape(backend)}\"\s*$"
        )
        if not re.search(pattern, lock):
            report(f"mise.lock: {tool} must resolve reviewed version/backend")
    for platform in ("macos-arm64", "macos-x64"):
        if f'"platforms.{platform}"' not in lock:
            report(f"mise.lock: missing {platform} resolutions")

test_script_path = root / "scripts" / "test.sh"
test_script = test_script_path.read_text() if test_script_path.is_file() else ""
if (
    "all)\n    run_pkg Factory\n    run_pkg Domain" not in test_script
    or "Factory|Domain|Features|DesignSystem)" not in test_script
):
    report("scripts/test.sh: Factory must be a direct selector and the first all-suite package")

lint_script_path = root / "scripts" / "lint.sh"
lint_script = lint_script_path.read_text() if lint_script_path.is_file() else ""
lib_script_path = root / "scripts" / "lib.sh"
lib_script = lib_script_path.read_text() if lib_script_path.is_file() else ""
doctor_script_path = root / "scripts" / "doctor.sh"
doctor_script = doctor_script_path.read_text() if doctor_script_path.is_file() else ""
xcodebuildmcp_script_path = root / "scripts" / "xcodebuildmcp.sh"
xcodebuildmcp_script = xcodebuildmcp_script_path.read_text() if xcodebuildmcp_script_path.is_file() else ""
if (
    '"$ROOT/scripts/check-ci-security.sh"\n'
    '"$ROOT/scripts/check-factory-contract.sh"\n'
    '"$ROOT/scripts/check-factory-api.sh"\n'
    '"$ROOT/scripts/check-capture-policy.sh"'
) not in lint_script:
    report("scripts/lint.sh: Factory contract and public API gates must run inside the executable lint contract")


def requires_early_dependency_preflight(relative: str, text: str) -> None:
    invocation = '"$ROOT/scripts/check-dependency-inputs.sh"'
    invocation_index = text.find(invocation)
    controller_indices = tuple(
        index
        for marker in (
            '. "$ROOT/scripts/lib.sh"',
            'source "$ROOT/scripts/lib.sh"',
            "mise_exec ",
            "run_sanitized ",
            "verify_reviewed_file ",
        )
        if (index := text.find(marker)) >= 0
    )
    if (
        invocation_index < 0
        or not controller_indices
        or invocation_index >= min(controller_indices)
    ):
        report(f"{relative}: dependency preflight must run before shared or dependency-controlled tooling")


requires_early_dependency_preflight("scripts/lint.sh", lint_script)
requires_early_dependency_preflight("scripts/test.sh", test_script)
requires_early_dependency_preflight("scripts/lib.sh", lib_script)
requires_early_dependency_preflight("scripts/doctor.sh", doctor_script)
requires_early_dependency_preflight("scripts/xcodebuildmcp.sh", xcodebuildmcp_script)

if 'scripts/lib.sh' in (root / "scripts" / "check-dependency-inputs.sh").read_text():
    report("scripts/check-dependency-inputs.sh: dependency preflight must not source lib.sh recursively")

listed = subprocess.run(
    ["/usr/bin/git", "-C", str(root), "ls-files", "-co", "--exclude-standard", "-z"],
    check=True,
    capture_output=True,
).stdout.decode("utf-8").split("\0")


def is_mise_input(relative: str) -> bool:
    path = pathlib.PurePosixPath(relative)
    name = path.name
    return (
        name == ".tool-versions"
        or name in {".mise", "mise", "mise-tasks"}
        or re.fullmatch(r"\.?(?:mise|rtx)(?:\.[^/]+)*\.toml", name) is not None
        or re.fullmatch(r"\.?mise(?:\.[^/]+)*\.lock", name) is not None
        or any(part in {".mise", "mise", "mise-tasks"} for part in path.parts[:-1])
        or tuple(path.parts[:2]) == (".config", "mise")
    )


reviewed_mise_inputs = {"mise.toml", "mise.lock"}
unexpected_mise_inputs = [
    path for path in listed
    if path and is_mise_input(path) and path not in reviewed_mise_inputs
]
if unexpected_mise_inputs:
    report(f"unexpected mise configuration inputs: {len(unexpected_mise_inputs)}")

forbidden_factory_inputs = {
    "Packages/Factory/Package.pins",
    "Packages/Factory/Package.resolved",
    "Packages/Factory/Plugins",
    "Packages/Factory/.swiftpm",
}
unexpected_factory_inputs = [
    relative for relative in listed
    if relative and any(
        relative == forbidden
        or relative.startswith(forbidden + "/")
        for forbidden in forbidden_factory_inputs
    )
    or re.fullmatch(r"Packages/Factory/Package@swift-[^/]+\.swift", relative)
]
if unexpected_factory_inputs:
    report(f"unexpected Factory dependency or plugin inputs: {len(unexpected_factory_inputs)}")

for relative in sorted(forbidden_factory_inputs):
    path = root / relative
    try:
        path.lstat()
    except FileNotFoundError:
        continue
    except OSError:
        report(f"{relative}: forbidden Factory input could not be inspected")
    else:
        report(f"{relative}: forbidden Factory dependency or plugin input exists")
try:
    factory_entries = tuple((root / "Packages" / "Factory").iterdir())
except OSError:
    report("Packages/Factory: alternate manifest scan failed closed")
else:
    for path in factory_entries:
        if path.name.startswith("Package@") and path.name.endswith(".swift"):
            report(f"Packages/Factory/{path.name}: alternate SwiftPM manifest is forbidden")


boundary_manifest = root / "scripts" / "security-boundary.sha256"
boundary_manifest_digest = "f7e5463241a046599c0882e1c0a1eb4fec075db357e14d7472601378558509e7"
try:
    manifest_metadata = boundary_manifest.lstat()
    manifest_content = boundary_manifest.read_bytes()
except OSError:
    report("scripts/security-boundary.sha256: reviewed controller allowlist is missing")
    manifest_content = b""
else:
    if (
        not stat.S_ISREG(manifest_metadata.st_mode)
        or manifest_metadata.st_nlink != 1
        or manifest_metadata.st_uid != current_uid
        or manifest_metadata.st_mode & 0o022
        or hashlib.sha256(manifest_content).hexdigest() != boundary_manifest_digest
    ):
        report("scripts/security-boundary.sha256: reviewed controller allowlist changed")

manifest_entries: dict[str, str] = {}
manifest_order: list[str] = []
for line_number, line in enumerate(manifest_content.decode("utf-8").splitlines(), start=1):
    match = re.fullmatch(r"([0-9a-f]{64})  ([A-Za-z0-9_./-]+)", line)
    if not match:
        report(f"scripts/security-boundary.sha256:{line_number}: malformed allowlist entry")
        continue
    digest, relative = match.groups()
    path = pathlib.PurePosixPath(relative)
    if path.is_absolute() or ".." in path.parts or relative in manifest_entries:
        report(f"scripts/security-boundary.sha256:{line_number}: unsafe or duplicate path")
        continue
    manifest_entries[relative] = digest
    manifest_order.append(relative)

expected_controller_paths: set[str] = set()
required_controller_directories = (
    root / ".agents",
    root / ".claude",
    root / ".codex",
    root / ".factory",
    root / ".github",
    root / ".xcodebuildmcp",
    root / "Packages" / "Factory" / "Sources",
    root / "Packages" / "Factory" / "Tests",
    root / "Tools" / "XcodeBuildMCP",
    root / "docs" / "factory",
    root / "docs" / "product",
    root / "script",
    root / "scripts",
)
optional_controller_directories = (root / ".pi",)
allowed_controller_symlinks = {".claude/skills": "../.agents/skills"}
observed_controller_symlinks: set[str] = set()
for directory in (*required_controller_directories, *optional_controller_directories):
    if not directory.exists():
        if directory in required_controller_directories:
            report(f"{directory.relative_to(root)}: required controller directory is missing")
        continue
    directory_metadata = directory.lstat()
    if (
        not stat.S_ISDIR(directory_metadata.st_mode)
        or directory.is_symlink()
        or directory_metadata.st_uid != current_uid
        or directory_metadata.st_mode & 0o022
    ):
        report(f"{directory.relative_to(root)}: controller directory is unsafe")
    for path in directory.rglob("*"):
        directory_relative = path.relative_to(directory)
        if (
            directory == root / "Tools" / "XcodeBuildMCP"
            and "node_modules" in directory_relative.parts
        ):
            continue
        relative = path.relative_to(root).as_posix()
        if relative in {"scripts/check-ci-security.sh", "scripts/security-boundary.sha256"}:
            continue
        try:
            metadata = path.lstat()
        except OSError:
            report("controller allowlist traversal failed closed")
            continue
        if stat.S_ISLNK(metadata.st_mode):
            expected_target = allowed_controller_symlinks.get(relative)
            if (
                expected_target is None
                or metadata.st_uid != current_uid
                or metadata.st_nlink != 1
                or os.readlink(path) != expected_target
            ):
                report(f"{relative}: controller path must not be a symlink")
            else:
                observed_controller_symlinks.add(relative)
        elif stat.S_ISDIR(metadata.st_mode):
            if metadata.st_uid != current_uid or metadata.st_mode & 0o022:
                report(f"{relative}: controller directory is unsafe")
        elif stat.S_ISREG(metadata.st_mode):
            expected_controller_paths.add(relative)
        else:
            report(f"{relative}: unsupported controller path type")

if observed_controller_symlinks != set(allowed_controller_symlinks):
    report(".claude/skills: exact shared skill discovery link is required")

required_controller_files = {
    "CLAUDE.md",
    "Packages/Factory/AGENTS.md",
    "Packages/Factory/Package.swift",
    "Packages/Factory/PublicAPI.json",
    "docs/preferences.md",
    "mise.lock",
    "mise.toml",
    "scripts/check-factory-api.sh",
}
native_controller_names = {
    ".mcp.json",
    "agents.md",
    "agents.override.md",
    "claude.local.md",
    "claude.md",
    "exportoptions.plist",
    "privacyinfo.xcprivacy",
}
excluded_controller_tree_names = {
    ".build",
    ".git",
    ".snapshot-operation-lock",
    ".snapshot-record-token",
    "DerivedData",
    "artifacts",
    "node_modules",
    "xcuserdata",
}
filesystem_controller_files: set[str] = set()


def controller_traversal_error(error: OSError) -> None:
    report(f"native controller discovery failed closed: {error}")


for current, directories, files in os.walk(
    root, topdown=True, followlinks=False, onerror=controller_traversal_error
):
    current_path = pathlib.Path(current)
    retained_directories: list[str] = []
    for name in directories:
        candidate = current_path / name
        relative = candidate.relative_to(root).as_posix()
        folded_name = name.casefold()
        if folded_name in native_controller_names or folded_name.endswith(".entitlements"):
            filesystem_controller_files.add(relative)
        if name not in excluded_controller_tree_names and not name.endswith(".xcresult"):
            retained_directories.append(name)
    directories[:] = retained_directories
    for name in files:
        folded_name = name.casefold()
        if folded_name in native_controller_names or folded_name.endswith(".entitlements"):
            filesystem_controller_files.add(
                (current_path / name).relative_to(root).as_posix()
            )

required_controller_files.update(
    filesystem_controller_files
)
for relative in sorted(required_controller_files):
    path = root / relative
    cursor = root
    unsafe_ancestor = False
    for component in pathlib.PurePosixPath(relative).parts[:-1]:
        cursor /= component
        try:
            ancestor_metadata = cursor.lstat()
        except OSError:
            report(f"{relative}: controller ancestor is missing")
            unsafe_ancestor = True
            break
        if (
            not stat.S_ISDIR(ancestor_metadata.st_mode)
            or cursor.is_symlink()
            or ancestor_metadata.st_uid != current_uid
            or ancestor_metadata.st_mode & 0o022
        ):
            report(f"{relative}: controller ancestor is unsafe")
            unsafe_ancestor = True
            break
    if unsafe_ancestor:
        continue
    try:
        metadata = path.lstat()
    except OSError:
        report(f"{relative}: required controller file is missing")
        continue
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != current_uid
        or metadata.st_mode & 0o022
    ):
        report(f"{relative}: controller file is unsafe")
        continue
    expected_controller_paths.add(relative)

if manifest_order != sorted(manifest_order) or set(manifest_entries) != expected_controller_paths:
    report("scripts/security-boundary.sha256: controller path set is incomplete or unordered")
for relative, expected_digest in manifest_entries.items():
    path = root / relative
    try:
        metadata = path.lstat()
        content = path.read_bytes()
    except OSError:
        report(f"{relative}: reviewed controller is missing")
        continue
    if (
        not stat.S_ISREG(metadata.st_mode)
        or metadata.st_nlink != 1
        or metadata.st_uid != current_uid
        or metadata.st_mode & 0o022
        or hashlib.sha256(content).hexdigest() != expected_digest
    ):
        report(f"{relative}: reviewed controller digest changed")

for directory in (root / "script", root / "scripts"):
    for path in directory.rglob("*.sh"):
        relative = path.relative_to(root)
        if path.read_text().splitlines()[:1] != ["#!/bin/bash -p"]:
            report(f"{relative}: executable Bash controller must use privileged fixed-shell startup")
for path in (root / "scripts" / "support").glob("*.py"):
    relative = path.relative_to(root)
    if path.read_text().splitlines()[:1] != ["#!/usr/bin/python3 -I"]:
        report(f"{relative}: executable Python controller must use isolated system-Python startup")

if violations:
    for violation in violations:
        print(f"CI security violation: {violation}", file=sys.stderr)
    raise SystemExit(1)

PY
echo "check-ci-security: OK"
