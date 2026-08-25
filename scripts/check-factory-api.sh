#!/bin/bash -p
# Freeze the Factory public/package trust surface from SwiftPM's symbol graph.
# Usage: scripts/check-factory-api.sh [--write]
set -euo pipefail

SCRIPT_DIR="${BASH_SOURCE[0]%/*}"
[[ "$SCRIPT_DIR" != "${BASH_SOURCE[0]}" ]] || SCRIPT_DIR=.
ROOT="$(cd "$SCRIPT_DIR/.." && /bin/pwd -P)"
PACKAGE_ROOT="$ROOT/Packages/Factory"
MANIFEST="$PACKAGE_ROOT/PublicAPI.json"
SANITIZER="$ROOT/scripts/support/run_sanitized.sh"
DEPENDENCY_PREFLIGHT="$ROOT/scripts/check-dependency-inputs.sh"
MODE=check

if [[ "$#" -gt 1 || ( "$#" -eq 1 && "${1:-}" != "--write" ) ]]; then
  echo "usage: scripts/check-factory-api.sh [--write]" >&2
  exit 2
fi
if [[ "${1:-}" == "--write" ]]; then
  MODE=write
fi

for required in \
  "$PACKAGE_ROOT/Package.swift" \
  "$DEPENDENCY_PREFLIGHT" \
  "$SANITIZER"; do
  if [[ ! -f "$required" || -L "$required" ]]; then
    echo "Factory API input is missing or unsafe: $required" >&2
    exit 2
  fi
done

"$DEPENDENCY_PREFLIGHT"

umask 077
TMP_ROOT="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/swiftmac-factory-api.XXXXXX")"
cleanup() {
  /bin/rm -rf "$TMP_ROOT"
}
trap cleanup EXIT
trap 'cleanup; exit 129' HUP
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

SCRATCH="$TMP_ROOT/build"
DESCRIPTION="$TMP_ROOT/package.json"
CANDIDATE="$TMP_ROOT/PublicAPI.json"

"$SANITIZER" /usr/bin/xcrun swift build \
  --package-path "$PACKAGE_ROOT" \
  --scratch-path "$SCRATCH" \
  --build-tests
"$SANITIZER" /usr/bin/xcrun swift package \
  --package-path "$PACKAGE_ROOT" \
  --scratch-path "$SCRATCH" \
  dump-symbol-graph \
  --minimum-access-level package \
  --skip-synthesized-members
"$SANITIZER" /usr/bin/xcrun swift package \
  --package-path "$PACKAGE_ROOT" \
  --scratch-path "$SCRATCH" \
  describe --type json >"$DESCRIPTION"

/usr/bin/python3 -I - "$DESCRIPTION" "$SCRATCH" "$CANDIDATE" <<'PY'
import hashlib
import json
import pathlib
import stat
import sys


description_path = pathlib.Path(sys.argv[1])
scratch = pathlib.Path(sys.argv[2])
candidate_path = pathlib.Path(sys.argv[3])


def fail(message: str) -> None:
    raise SystemExit(f"Factory API projection failed: {message}")


def require_regular(path: pathlib.Path) -> None:
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        fail(f"missing file: {path}")
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        fail(f"unsafe file: {path}")


def canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def project_fragment(fragment: dict[str, object]) -> dict[str, object]:
    allowed = ("kind", "spelling", "preciseIdentifier")
    return {key: fragment[key] for key in allowed if key in fragment}


def project_nested(value: object) -> object:
    if isinstance(value, dict):
        return {
            key: project_nested(item)
            for key, item in sorted(value.items())
            if key not in {"docComment", "location", "names"}
        }
    if isinstance(value, list):
        return [project_nested(item) for item in value]
    return value


require_regular(description_path)
try:
    description = json.loads(description_path.read_text(encoding="utf-8"))
except (UnicodeDecodeError, json.JSONDecodeError) as error:
    fail(f"invalid SwiftPM package description: {error}")

if description.get("name") != "Factory":
    fail("package name must remain Factory")

products = []
library_modules: set[str] = set()
targets = {
    target.get("name"): target
    for target in description.get("targets", [])
    if isinstance(target, dict) and isinstance(target.get("name"), str)
}
for product in description.get("products", []):
    if not isinstance(product, dict):
        fail("SwiftPM returned a malformed product")
    name = product.get("name")
    product_targets = product.get("targets")
    product_type = product.get("type")
    if (
        not isinstance(name, str)
        or not isinstance(product_targets, list)
        or not all(isinstance(target, str) for target in product_targets)
        or not isinstance(product_type, dict)
        or len(product_type) != 1
    ):
        fail("SwiftPM returned a malformed product")
    products.append(
        {
            "name": name,
            "targets": sorted(product_targets),
            "type": project_nested(product_type),
        }
    )
    if "library" in product_type:
        for target_name in product_targets:
            target = targets.get(target_name)
            if not isinstance(target, dict) or target.get("type") != "library":
                fail(f"library product {name} has a non-library target")
            library_modules.add(target_name)

if not products or not library_modules:
    fail("Factory must expose at least one SwiftPM library product")

graphs_by_module: dict[str, list[dict[str, object]]] = {
    module: [] for module in library_modules
}
graph_paths = sorted(scratch.rglob("*.symbols.json"))
if not graph_paths:
    fail("SwiftPM emitted no symbol graphs")
for graph_path in graph_paths:
    require_regular(graph_path)
    try:
        graph = json.loads(graph_path.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"invalid symbol graph {graph_path.name}: {error}")
    module = graph.get("module", {}).get("name")
    if module == "FactoryPackageTests":
        continue
    if module not in graphs_by_module:
        fail(f"unexpected importable symbol graph module: {module!r}")
    graphs_by_module[module].append(graph)

modules = []
for module_name in sorted(graphs_by_module):
    graphs = graphs_by_module[module_name]
    if not graphs:
        fail(f"missing importable symbol graph module: {module_name}")

    symbols = []
    relationships = []
    for graph in graphs:
        for symbol in graph.get("symbols", []):
            if not isinstance(symbol, dict):
                fail(f"malformed symbol in {module_name}")
            identifier = symbol.get("identifier")
            kind = symbol.get("kind")
            if not isinstance(identifier, dict) or not isinstance(kind, dict):
                fail(f"malformed symbol identity in {module_name}")
            projected = {
                "access_level": symbol.get("accessLevel"),
                "declaration_fragments": [
                    project_fragment(fragment)
                    for fragment in symbol.get("declarationFragments", [])
                    if isinstance(fragment, dict)
                ],
                "identifier": {
                    "interface_language": identifier.get("interfaceLanguage"),
                    "precise": identifier.get("precise"),
                },
                "kind": kind.get("identifier"),
                "path_components": symbol.get("pathComponents"),
            }
            for optional_key in (
                "availability",
                "functionSignature",
                "swiftExtension",
                "swiftGenerics",
            ):
                if optional_key in symbol:
                    projected[optional_key] = project_nested(symbol[optional_key])
            symbols.append(projected)

        for relationship in graph.get("relationships", []):
            if not isinstance(relationship, dict):
                fail(f"malformed relationship in {module_name}")
            relationships.append(
                {
                    key: project_nested(relationship[key])
                    for key in (
                        "kind",
                        "source",
                        "swiftConstraints",
                        "target",
                        "targetFallback",
                    )
                    if key in relationship
                }
            )

    symbols.sort(key=canonical_bytes)
    relationships.sort(key=canonical_bytes)
    required_package_authority = {
        "BrokerCASStore",
        "BrokerSignedAuditTransition",
        "FactoryBrokerCommand",
        "FactoryProcessInput",
        "PatchImporter",
        "PrivateEvaluationScaffold",
    }
    for authority_root in sorted(required_package_authority):
        authority_symbols = [
            symbol
            for symbol in symbols
            if symbol["path_components"]
            and symbol["path_components"][0] == authority_root
        ]
        if not authority_symbols:
            fail(f"required package authority is missing: {authority_root}")
        if any(symbol["access_level"] != "package" for symbol in authority_symbols):
            fail(f"{authority_root} authority must remain package-only")
    audit_signers = [
        symbol
        for symbol in symbols
        if symbol["path_components"]
        and symbol["path_components"][0] == "BrokerAuditChain"
        and len(symbol["path_components"]) > 1
        and symbol["path_components"][1].startswith("sign(")
    ]
    if not audit_signers:
        fail("required BrokerAuditChain signer is missing")
    if any(symbol["access_level"] != "package" for symbol in audit_signers):
        fail("BrokerAuditChain signing authority must remain package-only")
    projection = {"relationships": relationships, "symbols": symbols}
    symbol_inventory = []
    for symbol in symbols:
        declaration = "".join(
            fragment.get("spelling", "")
            for fragment in symbol["declaration_fragments"]
        )
        symbol_inventory.append(
            " | ".join(
                (
                    str(symbol["kind"]),
                    str(symbol["access_level"]),
                    ".".join(symbol["path_components"]),
                    declaration,
                    str(symbol["identifier"]["precise"]),
                )
            )
        )
    modules.append(
        {
            "name": module_name,
            "projection_sha256": hashlib.sha256(
                canonical_bytes(projection)
            ).hexdigest(),
            "relationship_count": len(relationships),
            "symbol_count": len(symbols),
            "symbol_inventory": sorted(symbol_inventory),
        }
    )

manifest = {
    "format_version": 1,
    "minimum_access_level": "package",
    "modules": modules,
    "package": "Factory",
    "products": sorted(products, key=lambda product: product["name"]),
    "skip_synthesized_members": True,
}
candidate_path.write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)
PY

/usr/bin/python3 -I - "$MODE" "$MANIFEST" "$CANDIDATE" <<'PY'
import difflib
import os
import pathlib
import stat
import sys
import tempfile


mode = sys.argv[1]
manifest = pathlib.Path(sys.argv[2])
candidate = pathlib.Path(sys.argv[3])
candidate_bytes = candidate.read_bytes()


def safe_existing_file(path: pathlib.Path) -> bool:
    try:
        metadata = path.lstat()
    except FileNotFoundError:
        return False
    if not stat.S_ISREG(metadata.st_mode) or metadata.st_nlink != 1:
        raise SystemExit(f"Factory API manifest is unsafe: {path}")
    return True


if mode == "write":
    safe_existing_file(manifest)
    descriptor, temporary_name = tempfile.mkstemp(
        dir=manifest.parent,
        prefix=".PublicAPI.json.",
    )
    temporary = pathlib.Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(candidate_bytes)
            output.flush()
            os.fsync(output.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, manifest)
        directory = os.open(manifest.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Wrote Factory public/package API manifest: {manifest}")
    raise SystemExit(0)

if not safe_existing_file(manifest):
    raise SystemExit(
        "Factory public/package API manifest is missing. "
        "Review the API, then run scripts/check-factory-api.sh --write."
    )

expected_bytes = manifest.read_bytes()
if expected_bytes != candidate_bytes:
    difference = difflib.unified_diff(
        expected_bytes.decode("utf-8").splitlines(),
        candidate_bytes.decode("utf-8").splitlines(),
        fromfile=str(manifest),
        tofile="current SwiftPM symbol graph",
        lineterm="",
    )
    print("\n".join(difference), file=sys.stderr)
    raise SystemExit(
        "Factory public/package API drift detected. Review the change, then run "
        "scripts/check-factory-api.sh --write only when the API change is intentional."
    )

print("Factory public/package API matches the frozen SwiftPM symbol graph.")
PY
