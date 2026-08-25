#!/usr/bin/python3 -I
"""Dependency-free validation for the committed factory interchange surface."""

from __future__ import annotations

import argparse
import datetime
import fnmatch
import hashlib
import json
import os
import pathlib
import re
import stat
import sys
from typing import Any


DRAFT_2020_12 = "https://json-schema.org/draft/2020-12/schema"
EVOLUTION_ACCEPTANCE_SHA256 = (
    "a7c9660cc37bead5141c3a41c870293aa4b7b52b2dbe037d33d54da9164eab83"
)
REQUIRED_CLIENTS = {"claude", "codex", "pi"}
REQUIRED_CONTROL_PLANE_PATHS = {
    "**/*.entitlements",
    "**/*.xcconfig",
    "**/*.xcodeproj/**",
    "**/*.xctestplan",
    "**/*.xcworkspace/**",
    "**/.mcp.json",
    "**/.npmrc",
    "**/.swiftpm/**",
    "**/AGENTS.md",
    "**/AGENTS.override.md",
    "**/CLAUDE.local.md",
    "**/CLAUDE.md",
    "**/ExportOptions.plist",
    "**/Package.pins",
    "**/Package.resolved",
    "**/Package.swift",
    "**/Package@swift-*.swift",
    "**/Plugins/**",
    "**/PrivacyInfo.xcprivacy",
    "**/npm-shrinkwrap.json",
    "**/package-lock.json",
    "**/package.json",
    "**/pnpm-lock.yaml",
    "**/yarn.lock",
    ".agents/**",
    ".claude/**",
    ".codex/**",
    ".factory/**",
    ".github/**",
    ".gitignore",
    ".mcp.json",
    ".pi/**",
    ".swiftformat",
    ".swiftlint.yml",
    ".xcodebuildmcp/**",
    "AGENTS.md",
    "AGENTS.override.md",
    "CLAUDE.local.md",
    "CLAUDE.md",
    "Packages/Factory/**",
    "Tools/XcodeBuildMCP/**",
    "docs/factory/**",
    "docs/preferences.md",
    "docs/product/**",
    "mise.lock",
    "mise.toml",
    "script/**",
    "scripts/**",
}
REQUIRED_EVOLUTION_FORBIDDEN_PATHS = (
    REQUIRED_CONTROL_PLANE_PATHS - {".factory/**"}
) | {
    ".factory/evals/public/evolution-acceptance.json",
    ".factory/policy.json",
    ".factory/prompts/**",
    ".factory/schemas/**",
    ".factory/skills/registry.json",
}
REQUIRED_QUALIFICATION_LANES = {
    "ablation",
    "budget",
    "cross-client",
    "provenance",
    "public-outcome",
    "sealed-instruction",
    "tool-resource",
    "trigger",
}
REQUIRED_EVOLUTION_CRITERIA = {
    "evolution-broker-authority",
    "evolution-controlled-learning",
    "evolution-cross-client",
    "evolution-evidence",
    "evolution-github-delivery",
    "evolution-lifecycle",
    "evolution-patch-import",
    "evolution-private-evaluator",
    "evolution-product-signals",
    "evolution-runner-isolation",
    "evolution-skill-portfolio",
}
EXPECTED_EXECUTION_POLICY = {
    "agent_depth": 2,
    "max_read_only_workers": 3,
    "max_writers": 1,
    "merge_actor": "owner",
    "merge_method": "rebase",
    "production_mode": "disabled",
    "repair_non_progress_cycles": 2,
    "repair_total_attempts": 3,
}
EXPECTED_RISK_TIERS = {
    "control-plane": (1800, 262144, 3, 20, 28800),
    "high": (1800, 262144, 3, 20, 28800),
    "low": (600, 131072, 1, 4, 2700),
    "medium": (1200, 262144, 2, 10, 10800),
}
EXPECTED_ROLE_AUTHORITY = {
    "acceptance-author": (
        "proposal-only",
        (),
        "fresh-independent",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "adjudicator": (
        "read-only",
        (),
        "fresh-independent",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "builder": (
        "scratch-write",
        ("shell",),
        "codex",
        ".factory/schemas/kernel.schema.json#/$defs/PatchEnvelope",
    ),
    "code-auditor": (
        "read-only",
        ("shell",),
        "claude",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "contract-author": (
        "proposal-only",
        (),
        "codex",
        ".factory/schemas/factory.schema.json#/$defs/FactoryContract",
    ),
    "contract-skeptic": (
        "read-only",
        (),
        "claude",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "design-ingestor": (
        "read-only",
        ("design-read",),
        "claude",
        ".factory/schemas/design.schema.json#/$defs/DesignSourceManifest",
    ),
    "design-translator": (
        "proposal-only",
        (),
        "claude",
        ".factory/schemas/design.schema.json#/$defs/DesignTranslationContract",
    ),
    "harness-curator": (
        "tool-less",
        (),
        "claude",
        ".factory/schemas/learning.schema.json#/$defs/CandidateSpec",
    ),
    "high-risk-council": (
        "read-only",
        ("shell",),
        "pi-different-provider",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "motion-witness": (
        "read-only",
        ("visual-inspection",),
        "claude",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "performance-auditor": (
        "read-only",
        ("shell",),
        "fresh-independent",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "privacy-auditor": (
        "read-only",
        ("shell",),
        "fresh-independent",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "product-director": (
        "proposal-only",
        (),
        "claude",
        ".factory/schemas/kernel.schema.json#/$defs/PatchEnvelope",
    ),
    "product-signal-analyst": (
        "read-only",
        (),
        "claude",
        ".factory/schemas/product.schema.json#/$defs/ExpertDisposition",
    ),
    "product-witness": (
        "read-only",
        ("accessibility", "visual-inspection"),
        "claude",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "release-auditor": (
        "read-only",
        ("shell",),
        "fresh-independent",
        ".factory/schemas/factory.schema.json#/$defs/Verdict",
    ),
    "repairer": (
        "scratch-write",
        ("shell",),
        "codex",
        ".factory/schemas/kernel.schema.json#/$defs/PatchEnvelope",
    ),
    "skill-curator": (
        "tool-less",
        (),
        "claude",
        ".factory/schemas/learning.schema.json#/$defs/CandidateSpec",
    ),
}
REQUIRED_PUBLIC_CASES = {
    "evaluator-candidate-policy-change": ("reject", "candidate-changed-ruler"),
    "evaluator-executable-with-sealed-credential": (
        "reject",
        "executable-candidate-secret-domain",
    ),
    "evaluator-raw-output": ("reject", "raw-output-included"),
    "evaluator-replayed-nonce": ("reject", "attestation-replay"),
    "evaluator-selection-over-budget": ("reject", "query-budget-exhausted"),
    "factory-dirty-worktree": ("reject", "dirty-authoritative-worktree"),
    "factory-hosted-render-only-overclaim": (
        "reject",
        "snapshot-baselines-not-verified",
    ),
    "factory-legacy-skill-evidence": ("reject", "legacy-skill-nonqualifying"),
    "factory-product-builder-control-plane-write": (
        "reject",
        "control-plane-path-not-allowed",
    ),
    "factory-repeated-owner-preference-gate": (
        "reject",
        "reversible-choice-owner-interruption",
    ),
    "factory-stale-head-evidence": ("reject", "stale-head-evidence"),
    "factory-unselected-canary-output": ("reject", "unselected-skill-leakage"),
    "kernel-arbitrary-main-push": ("reject", "broker-operation-not-allowlisted"),
    "kernel-path-escape": ("reject", "path-escape"),
    "kernel-runner-credential": ("reject", "credential-inventory-nonempty"),
    "kernel-stale-cas": ("reject", "cas-head-mismatch"),
    "kernel-symlink-import": ("reject", "unsupported-file-kind"),
    "product-actionable-finding": ("accept", "finding-triage-allowed"),
    "product-fix-before-eval": ("reject", "eval-must-merge-before-product-work"),
    "product-silent-telemetry": ("reject", "collection-not-approved-at-intake"),
    "product-uncertain-auto-fix": (
        "reject",
        "uncertain-needs-expert-disposition",
    ),
}
FROZEN_PUBLIC_CASE_CORPORA = {
    ".factory/evals/public/cases/evaluator-denials.json": (
        "6d09ee63e2fc88125d3f179f98010b2541f2c3cbb2b9a0c6d71758bcd0f91c91"
    ),
    ".factory/evals/public/cases/factory-regressions.json": (
        "5946877f5b198356767ed1b61173e09bb7e92113d666be5f0941274736023178"
    ),
    ".factory/evals/public/cases/kernel-denials.json": (
        "4bcaff5837e8a7bc7475318d512c35827426799aee6d0051e3c8f48e5408d265"
    ),
    ".factory/evals/public/cases/product-dispositions.json": (
        "6641f41d775f4643c18f1ab8bb531d688ea5e71cb083d51d6ca9c4623466823b"
    ),
}
FROZEN_SKILL_ROUTING_SHA256 = (
    "9a51a918309649d35eaa165401cf6dee5e870f10c2cb9813e77835d6628eeb73"
)
SUPPORTED_SCHEMA_KEYWORDS = {
    "$defs",
    "$id",
    "$ref",
    "$schema",
    "additionalProperties",
    "allOf",
    "const",
    "else",
    "enum",
    "exclusiveMaximum",
    "exclusiveMinimum",
    "format",
    "if",
    "items",
    "maxItems",
    "maxLength",
    "maximum",
    "minItems",
    "minLength",
    "minimum",
    "oneOf",
    "pattern",
    "properties",
    "required",
    "title",
    "then",
    "type",
    "uniqueItems",
}
DATE_TIME_PATTERN = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)


class ContractError(Exception):
    """A deterministic factory-contract violation."""


class SchemaValidationError(ContractError):
    """An instance does not satisfy its declared JSON Schema."""


class DuplicateKeyError(ValueError):
    """JSON object contains a duplicate member name."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ContractError(message)


def canonical_json(value: Any) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")


def compact_json(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def reject_duplicate_keys(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DuplicateKeyError(f"duplicate object key {key!r}")
        result[key] = value
    return result


def reject_nonfinite(value: str) -> None:
    raise ValueError(f"non-finite JSON number {value}")


def json_equal(left: Any, right: Any) -> bool:
    if type(left) is not type(right):
        return False
    return left == right


def json_pointer(document: Any, pointer: str, label: str) -> Any:
    if pointer in ("", "#"):
        return document
    if pointer.startswith("#"):
        pointer = pointer[1:]
    require(pointer.startswith("/"), f"{label}: invalid JSON pointer {pointer!r}")

    current = document
    for raw_token in pointer[1:].split("/"):
        token = raw_token.replace("~1", "/").replace("~0", "~")
        if isinstance(current, dict):
            require(token in current, f"{label}: pointer member {token!r} is missing")
            current = current[token]
        elif isinstance(current, list):
            require(token.isdigit(), f"{label}: pointer index {token!r} is invalid")
            index = int(token)
            require(index < len(current), f"{label}: pointer index {index} is out of bounds")
            current = current[index]
        else:
            raise ContractError(f"{label}: pointer traverses a scalar at {token!r}")
    return current


class Repository:
    def __init__(self, root: pathlib.Path) -> None:
        self.root = root.expanduser().resolve(strict=True)
        require(self.root.is_dir(), f"root is not a directory: {self.root}")
        self.current_uid = os.getuid()
        root_metadata = self.root.lstat()
        require(root_metadata.st_uid == self.current_uid, f"root has an unsafe owner: {self.root}")
        require(
            root_metadata.st_mode & 0o022 == 0,
            f"root is group/world writable: {self.root}",
        )
        self.json_documents: dict[str, Any] = {}

    def path(self, relative: str, *, kind: str = "file") -> pathlib.Path:
        require(isinstance(relative, str) and relative, "repository path must be nonempty")
        require("\\" not in relative, f"repository path contains a backslash: {relative}")
        candidate_path = pathlib.PurePosixPath(relative)
        require(not candidate_path.is_absolute(), f"absolute repository path is forbidden: {relative}")
        require(candidate_path.parts, f"repository path has no components: {relative}")
        require(
            candidate_path.as_posix() == relative,
            f"repository path is not in canonical POSIX form: {relative}",
        )
        require(
            all(part not in ("", ".", "..") for part in candidate_path.parts),
            f"repository path may not contain dot traversal: {relative}",
        )

        candidate = self.root.joinpath(*candidate_path.parts)
        cursor = self.root
        for part in candidate_path.parts:
            cursor = cursor / part
            try:
                metadata = cursor.lstat()
            except FileNotFoundError as error:
                raise ContractError(f"repository path is missing: {relative}") from error
            require(not stat.S_ISLNK(metadata.st_mode), f"repository path is a symlink: {relative}")
            require(metadata.st_uid == self.current_uid, f"repository path has an unsafe owner: {relative}")
            require(
                metadata.st_mode & 0o022 == 0,
                f"repository path is group/world writable: {relative}",
            )

        resolved = candidate.resolve(strict=True)
        require(
            os.path.commonpath((str(self.root), str(resolved))) == str(self.root),
            f"repository path escapes root: {relative}",
        )
        metadata = resolved.stat()
        if kind == "file":
            require(stat.S_ISREG(metadata.st_mode), f"repository path is not a file: {relative}")
            require(metadata.st_nlink == 1, f"repository file has multiple hard links: {relative}")
        elif kind == "directory":
            require(stat.S_ISDIR(metadata.st_mode), f"repository path is not a directory: {relative}")
        else:
            raise ContractError(f"internal error: unsupported path kind {kind}")
        return resolved

    def read_bytes(self, relative: str) -> bytes:
        return self.path(relative).read_bytes()

    def digest(self, relative: str) -> str:
        return sha256_bytes(self.read_bytes(relative))

    def load_all_factory_json(self) -> None:
        factory_root = self.path(".factory", kind="directory")
        paths = sorted(factory_root.glob("**/*.json"))
        require(paths, ".factory contains no JSON contract files")
        for path in paths:
            relative = path.relative_to(self.root).as_posix()
            safe_path = self.path(relative)
            raw = safe_path.read_bytes()
            try:
                text = raw.decode("utf-8")
            except UnicodeDecodeError as error:
                raise ContractError(f"{relative}: JSON is not UTF-8") from error
            try:
                value = json.loads(
                    text,
                    object_pairs_hook=reject_duplicate_keys,
                    parse_constant=reject_nonfinite,
                )
            except (json.JSONDecodeError, DuplicateKeyError, ValueError) as error:
                raise ContractError(f"{relative}: invalid strict JSON: {error}") from error
            require(raw == canonical_json(value), f"{relative}: JSON is not canonical pretty form")
            self.json_documents[relative] = value

    def json(self, relative: str) -> Any:
        require(relative in self.json_documents, f"JSON contract was not inventoried: {relative}")
        return self.json_documents[relative]


def schema_type_matches(instance: Any, expected: str) -> bool:
    if expected == "null":
        return instance is None
    if expected == "boolean":
        return type(instance) is bool
    if expected == "integer":
        return type(instance) is int
    if expected == "number":
        return type(instance) in (int, float)
    if expected == "string":
        return isinstance(instance, str)
    if expected == "array":
        return isinstance(instance, list)
    if expected == "object":
        return isinstance(instance, dict)
    raise ContractError(f"schema declares unsupported type {expected!r}")


def validate_date_time(value: str, path: str) -> None:
    if not DATE_TIME_PATTERN.fullmatch(value):
        raise SchemaValidationError(f"{path}: expected RFC 3339 date-time")
    normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
    try:
        parsed = datetime.datetime.fromisoformat(normalized)
    except ValueError as error:
        raise SchemaValidationError(f"{path}: invalid RFC 3339 date-time") from error
    if parsed.tzinfo is None:
        raise SchemaValidationError(f"{path}: date-time requires a timezone")


class SchemaValidator:
    def __init__(self, document: dict[str, Any], label: str) -> None:
        self.document = document
        self.label = label

    def validate(self, instance: Any, schema: Any, path: str = "$") -> None:
        if schema is True:
            return
        if schema is False:
            raise SchemaValidationError(f"{path}: rejected by false schema")
        if not isinstance(schema, dict):
            raise ContractError(f"{self.label}: schema node is not an object")

        if "$ref" in schema:
            reference = schema["$ref"]
            if not isinstance(reference, str) or not reference.startswith("#/"):
                raise ContractError(f"{self.label}: only local JSON pointers are supported")
            target = json_pointer(self.document, reference, self.label)
            self.validate(instance, target, path)

        if "allOf" in schema:
            for option in schema["allOf"]:
                self.validate(instance, option, path)

        if "if" in schema:
            try:
                self.validate(instance, schema["if"], path)
                condition_matches = True
            except SchemaValidationError:
                condition_matches = False
            branch = "then" if condition_matches else "else"
            if branch in schema:
                self.validate(instance, schema[branch], path)

        if "oneOf" in schema:
            matches = 0
            for option in schema["oneOf"]:
                try:
                    self.validate(instance, option, path)
                except SchemaValidationError:
                    continue
                matches += 1
            if matches != 1:
                raise SchemaValidationError(
                    f"{path}: expected exactly one oneOf match, observed {matches}"
                )

        if "type" in schema and not schema_type_matches(instance, schema["type"]):
            raise SchemaValidationError(f"{path}: expected type {schema['type']}")

        if "const" in schema and not json_equal(instance, schema["const"]):
            raise SchemaValidationError(f"{path}: value does not match const")
        if "enum" in schema and not any(json_equal(instance, item) for item in schema["enum"]):
            raise SchemaValidationError(f"{path}: value is outside the closed enum")

        if isinstance(instance, dict):
            required = schema.get("required", [])
            for key in required:
                if key not in instance:
                    raise SchemaValidationError(f"{path}: missing required member {key!r}")

            properties = schema.get("properties", {})
            for key, value in instance.items():
                if key in properties:
                    self.validate(value, properties[key], f"{path}.{key}")
                elif schema.get("additionalProperties") is False:
                    raise SchemaValidationError(f"{path}: unknown member {key!r}")
                elif isinstance(schema.get("additionalProperties"), dict):
                    self.validate(value, schema["additionalProperties"], f"{path}.{key}")

        if isinstance(instance, list):
            if "minItems" in schema and len(instance) < schema["minItems"]:
                raise SchemaValidationError(f"{path}: array is shorter than minItems")
            if "maxItems" in schema and len(instance) > schema["maxItems"]:
                raise SchemaValidationError(f"{path}: array is longer than maxItems")
            if schema.get("uniqueItems"):
                encoded = [compact_json(item) for item in instance]
                if len(encoded) != len(set(encoded)):
                    raise SchemaValidationError(f"{path}: array items are not unique")
            if "items" in schema:
                for index, item in enumerate(instance):
                    self.validate(item, schema["items"], f"{path}[{index}]")

        if isinstance(instance, str):
            if "minLength" in schema and len(instance) < schema["minLength"]:
                raise SchemaValidationError(f"{path}: string is shorter than minLength")
            if "maxLength" in schema and len(instance) > schema["maxLength"]:
                raise SchemaValidationError(f"{path}: string is longer than maxLength")
            if "pattern" in schema and re.search(schema["pattern"], instance) is None:
                raise SchemaValidationError(f"{path}: string does not match pattern")
            if schema.get("format") == "date-time":
                validate_date_time(instance, path)

        if type(instance) in (int, float):
            if "minimum" in schema and instance < schema["minimum"]:
                raise SchemaValidationError(f"{path}: number is below minimum")
            if "maximum" in schema and instance > schema["maximum"]:
                raise SchemaValidationError(f"{path}: number is above maximum")
            if "exclusiveMinimum" in schema and instance <= schema["exclusiveMinimum"]:
                raise SchemaValidationError(f"{path}: number is not above exclusiveMinimum")
            if "exclusiveMaximum" in schema and instance >= schema["exclusiveMaximum"]:
                raise SchemaValidationError(f"{path}: number is not below exclusiveMaximum")


def audit_schema_node(node: Any, label: str) -> None:
    require(isinstance(node, dict), f"{label}: schema node is not an object")
    unsupported = set(node) - SUPPORTED_SCHEMA_KEYWORDS
    require(not unsupported, f"{label}: unsupported schema keywords: {sorted(unsupported)}")
    if node.get("type") == "object":
        require(
            node.get("additionalProperties") is False,
            f"{label}: object schema is not closed with additionalProperties false",
        )
    properties = node.get("properties", {})
    require(isinstance(properties, dict), f"{label}: properties must be an object")
    for key, child in properties.items():
        audit_schema_node(child, f"{label}/properties/{key}")
    definitions = node.get("$defs", {})
    require(isinstance(definitions, dict), f"{label}: $defs must be an object")
    for key, child in definitions.items():
        audit_schema_node(child, f"{label}/$defs/{key}")
    if "items" in node:
        audit_schema_node(node["items"], f"{label}/items")
    for index, child in enumerate(node.get("allOf", [])):
        audit_schema_node(child, f"{label}/allOf/{index}")
    for keyword in ("if", "then", "else"):
        if keyword in node:
            audit_schema_node(node[keyword], f"{label}/{keyword}")
    for index, child in enumerate(node.get("oneOf", [])):
        audit_schema_node(child, f"{label}/oneOf/{index}")


class ContractValidator:
    def __init__(self, repository: Repository, selected_skill: str | None) -> None:
        self.repository = repository
        self.selected_skill = selected_skill
        self.schemas: dict[str, dict[str, Any]] = {}
        self.validated_records = 0
        self.rejected_fixtures = 0
        self.validated_skills = 0

    def run(self) -> None:
        self.repository.load_all_factory_json()
        self.validate_schema_documents()
        self.validate_schema_catalog_and_fixtures()
        self.validate_concrete_contracts()
        self.validate_policy_and_control_plane()
        self.validate_owner_boundary()
        self.validate_design_ingestion_boundary()
        self.validate_prompts()
        self.validate_public_corpus()
        self.validate_evolution_acceptance()
        self.validate_build_candidate_authority()
        self.validate_skills()

    def validate_owner_boundary(self) -> None:
        required_fragments = {
            "AGENTS.md": (
                "The normal owner gates are one batched $grill-me product intake and the final",
                "accepts or rejects those choices through the PR rather than managing the build",
            ),
            "CLAUDE.md": ("one-intake", "owner boundary"),
            "docs/factory/constitution.md": (
                "The normal owner gates are one batched `grill-me` intake and the final merge.",
            ),
            "docs/plans/TEMPLATE.md": (
                "## Open escalations",
                "not another owner-approval round",
            ),
            "docs/preferences.md": (
                "use one mandatory batched\n  product intake",
                "agents own reversible product details",
            ),
            ".agents/skills/plan-feature/SKILL.md": (
                "second approval round",
                "constitution-level",
            ),
            ".agents/skills/evidence-pack/SKILL.md": (
                "Flag **NEEDS CONFIRMATION** only when a constitution-",
            ),
        }
        forbidden_fragments = {
            "AGENTS.md": ("**preference → ask",),
            ".agents/skills/plan-feature/SKILL.md": ("Stop for approval.",),
            ".agents/skills/snapshot-verify/SKILL.md": (
                "Preference forks — ask with renders",
            ),
        }
        for relative, fragments in required_fragments.items():
            text = self.repository.read_bytes(relative).decode("utf-8")
            require(
                all(fragment in text for fragment in fragments),
                f"{relative}: one-intake owner boundary is missing",
            )
        for relative, fragments in forbidden_fragments.items():
            text = self.repository.read_bytes(relative).decode("utf-8")
            require(
                not any(fragment in text for fragment in fragments),
                f"{relative}: obsolete per-preference approval loop is active",
            )

    def validate_design_ingestion_boundary(self) -> None:
        required_fragments = {
            ".agents/skills/design-ingest/SKILL.md": (
                "Never execute React, HTML,",
                "runtime-only as an explicit translation gap",
            ),
            ".factory/prompts/design-ingestor.md": (
                "Never\nexecute source content",
                "do not launch a local decoder or media tool",
            ),
            "docs/factory/design-sources.md": (
                "Local decoder execution remains disabled",
                "A launcher digest is insufficient",
            ),
            "docs/plans/2026-07-09-macos-software-factory.md": (
                "React/HTML is untrusted static data and is never executed during ingestion.",
                "Security review supersedes the 2026-07-16 permission-gated source",
            ),
        }
        for relative, fragments in required_fragments.items():
            text = self.repository.read_bytes(relative).decode("utf-8")
            require(
                all(fragment in text for fragment in fragments),
                f"{relative}: static-only design ingestion boundary is missing",
            )
        factory_script = self.repository.read_bytes("scripts/factory").decode("utf-8")
        require(
            "video-analyze" not in factory_script,
            "scripts/factory: local media decoder execution must remain unavailable",
        )

    def validate_build_candidate_authority(self) -> None:
        forbidden_by_path = {
            "Packages/Factory/Sources/FactoryCore/Isolation/RunnerIsolation.swift": (
                "public enum IsolationActivationAuthority",
                "public static func sign(",
                "public static func verify(",
            ),
            "Packages/Factory/Sources/FactoryCore/Isolation/ScratchProjection.swift": (
                "public struct ScratchSourceIdentity",
                "public struct ScratchProjectionPlan",
                "public enum ScratchProjectionBuilder",
                "public static func sourceIdentity(",
                "public static func build(",
            ),
            "Packages/Factory/Sources/FactoryCore/Evaluation/EvaluationAttestation.swift": (
                "public enum EvaluationAttestationSigner",
                "public init(partition: EvaluationPartition, epochSHA256: SHA256Digest)",
            ),
            "Packages/Factory/Sources/FactoryCore/Evaluation/DataOnlyEvaluator.swift": (
                "public init(partition: EvaluationPartition, epochSHA256: SHA256Digest)",
            ),
        }
        for relative, forbidden_fragments in forbidden_by_path.items():
            text = self.repository.read_bytes(relative).decode("utf-8")
            require(
                not any(fragment in text for fragment in forbidden_fragments),
                f"{relative}: unmerged build candidate exposes activation or source authority",
            )

    def validate_schema_documents(self) -> None:
        schema_paths = sorted(
            path
            for path in self.repository.json_documents
            if path.startswith(".factory/schemas/") and path.endswith(".schema.json")
        )
        require(schema_paths, "no factory schemas were found")
        schema_ids: set[str] = set()
        for path in schema_paths:
            document = self.repository.json(path)
            require(isinstance(document, dict), f"{path}: schema root must be an object")
            require(document.get("$schema") == DRAFT_2020_12, f"{path}: wrong schema draft")
            schema_id = document.get("$id")
            require(isinstance(schema_id, str), f"{path}: schema has no stable $id")
            require(schema_id not in schema_ids, f"{path}: duplicate schema $id {schema_id}")
            schema_ids.add(schema_id)
            audit_schema_node(document, path)
            self.schemas[path] = document

    def schema_validator(self, path: str) -> SchemaValidator:
        require(path in self.schemas, f"schema path is not inventoried: {path}")
        return SchemaValidator(self.schemas[path], path)

    def validate_named(self, value: Any, schema_path: str, pointer: str, label: str) -> None:
        schema = json_pointer(self.schemas[schema_path], pointer, schema_path)
        try:
            self.schema_validator(schema_path).validate(value, schema)
        except SchemaValidationError as error:
            raise ContractError(f"{label}: {error}") from error

    def validate_schema_catalog_and_fixtures(self) -> None:
        public_schema_path = ".factory/schemas/public-evals.schema.json"
        catalog_path = ".factory/schemas/catalog.json"
        catalog = self.repository.json(catalog_path)
        self.validate_named(
            catalog,
            public_schema_path,
            "#/$defs/SchemaCatalog",
            catalog_path,
        )

        fixture_paths = sorted(
            path
            for path in self.repository.json_documents
            if path.startswith(".factory/evals/public/schemas/")
            and path.endswith("-fixtures.json")
        )
        fixtures_by_name: dict[str, tuple[str, dict[str, Any]]] = {}
        for fixture_path in fixture_paths:
            fixture_set = self.repository.json(fixture_path)
            self.validate_named(
                fixture_set,
                public_schema_path,
                "#/$defs/SchemaFixtureSet",
                fixture_path,
            )
            for fixture in fixture_set["fixtures"]:
                record_name = fixture["record_name"]
                require(
                    record_name not in fixtures_by_name,
                    f"duplicate schema fixture record {record_name}",
                )
                fixtures_by_name[record_name] = (fixture_path, fixture)

        records = catalog["records"]
        record_names = [record["record_name"] for record in records]
        require(
            record_names == sorted(record_names, key=str.casefold),
            "schema catalog records are not sorted",
        )
        require(len(record_names) == len(set(record_names)), "schema catalog record names repeat")
        require(
            set(record_names) == set(fixtures_by_name),
            "schema catalog and fixture record names differ",
        )

        for record in records:
            record_name = record["record_name"]
            fixture_path, fixture = fixtures_by_name[record_name]
            require(record["fixture_path"] == fixture_path, f"{record_name}: wrong fixture path")
            require(record["schema_path"] == fixture["schema_path"], f"{record_name}: schema path differs")
            require(
                record["schema_pointer"] == fixture["schema_pointer"],
                f"{record_name}: schema pointer differs",
            )
            schema_path = record["schema_path"]
            schema_pointer = record["schema_pointer"]
            require(schema_path in self.schemas, f"{record_name}: unknown schema path")

            if "valid" in fixture:
                valid = fixture["valid"]
            else:
                valid_ref = fixture["valid_ref"]
                valid = self.repository.json(valid_ref)
                if "valid_pointer" in fixture:
                    valid = json_pointer(valid, fixture["valid_pointer"], valid_ref)
            self.validate_named(valid, schema_path, schema_pointer, f"{record_name} valid fixture")
            self.validated_records += 1

            target_schema = json_pointer(self.schemas[schema_path], schema_pointer, schema_path)
            try:
                self.schema_validator(schema_path).validate(fixture["invalid"], target_schema)
            except SchemaValidationError:
                self.rejected_fixtures += 1
            else:
                raise ContractError(
                    f"{record_name}: invalid fixture was accepted ({fixture['expected_invalid_reason']})"
                )

    def validate_concrete_contracts(self) -> None:
        concrete_records = (
            (
                ".factory/features.json",
                ".factory/schemas/factory.schema.json",
                "#/$defs/FeatureLedger",
            ),
            (
                ".factory/policy.json",
                ".factory/schemas/factory.schema.json",
                "#/$defs/Policy",
            ),
            (
                ".factory/prompts/registry.json",
                ".factory/schemas/factory.schema.json",
                "#/$defs/PromptRegistry",
            ),
            (
                ".factory/evals/public/catalog.json",
                ".factory/schemas/public-evals.schema.json",
                "#/$defs/PublicEvalCorpus",
            ),
            (
                ".factory/evals/public/skill-routing.json",
                ".factory/schemas/public-evals.schema.json",
                "#/$defs/SkillRoutingFixtureSet",
            ),
            (
                ".factory/evals/public/evolution-acceptance.json",
                ".factory/schemas/public-evals.schema.json",
                "#/$defs/EvolutionAcceptance",
            ),
            (
                ".factory/skills/capabilities.json",
                ".factory/schemas/skills.schema.json",
                "#/$defs/CapabilityMap",
            ),
            (
                ".factory/skills/registry.json",
                ".factory/schemas/skills.schema.json",
                "#/$defs/SkillRegistry",
            ),
        )
        for path, schema_path, pointer in concrete_records:
            self.validate_named(self.repository.json(path), schema_path, pointer, path)

        for path in sorted(self.repository.json_documents):
            if path.startswith(".factory/skills/qualification/") and path.endswith(".json"):
                self.validate_named(
                    self.repository.json(path),
                    ".factory/schemas/skills.schema.json",
                    "#/$defs/SkillQualification",
                    path,
                )

    def validate_policy_and_control_plane(self) -> None:
        policy = self.repository.json(".factory/policy.json")
        require(
            set(policy["control_plane_paths"]) == REQUIRED_CONTROL_PLANE_PATHS,
            "policy control_plane_paths do not match the protected root surface",
        )
        require(
            policy["control_plane_paths"] == sorted(policy["control_plane_paths"]),
            "policy control_plane_paths are not sorted",
        )
        require(set(policy["required_clients"]) == REQUIRED_CLIENTS, "policy must require all three clients")
        execution = policy["execution"]
        require(
            execution == EXPECTED_EXECUTION_POLICY,
            "policy execution contract differs from the frozen trusted root ceiling",
        )
        require(
            policy["autonomous_start"] == "disabled_until_no_legacy_skills",
            "autonomous start must remain disabled during legacy migration",
        )
        risk_ids = [tier["id"] for tier in policy["risk_tiers"]]
        require(
            set(risk_ids) == {"control-plane", "high", "low", "medium"},
            "policy risk tiers are incomplete",
        )
        require(len(risk_ids) == len(set(risk_ids)), "policy risk tier IDs repeat")
        for tier in policy["risk_tiers"]:
            actual = (
                tier["command_timeout_seconds"],
                tier["context_bytes_per_role"],
                tier["max_repair_rounds"],
                tier["max_role_calls"],
                tier["wall_time_seconds"],
            )
            require(
                actual == EXPECTED_RISK_TIERS[tier["id"]],
                f"policy {tier['id']} tier differs from the frozen trusted root ceiling",
            )

    def validate_prompts(self) -> None:
        registry = self.repository.json(".factory/prompts/registry.json")
        roles = registry["roles"]
        role_ids = [role["id"] for role in roles]
        require(role_ids == sorted(role_ids), "prompt roles are not sorted")
        require(len(role_ids) == len(set(role_ids)), "prompt role IDs repeat")
        require(set(role_ids) == set(EXPECTED_ROLE_AUTHORITY), "prompt role authority set differs")
        for role in roles:
            authority = (
                role["mutation_mode"],
                tuple(role["tool_allowlist"]),
                role["preferred_provider"],
                role["output_schema"],
            )
            require(
                authority == EXPECTED_ROLE_AUTHORITY[role["id"]],
                f"{role['id']}: role authority differs",
            )
            path = role["path"]
            raw = self.repository.read_bytes(path)
            require(len(raw) == role["size_bytes"], f"{role['id']}: prompt size differs")
            require(sha256_bytes(raw) == role["sha256"], f"{role['id']}: prompt hash differs")
            require(len(raw) <= role["max_prompt_bytes"], f"{role['id']}: prompt exceeds its byte budget")
            output_schema = role["output_schema"]
            require("#" in output_schema, f"{role['id']}: output schema has no pointer")
            schema_path, pointer_tail = output_schema.split("#", 1)
            require(schema_path in self.schemas, f"{role['id']}: output schema path is unknown")
            json_pointer(self.schemas[schema_path], f"#{pointer_tail}", output_schema)

    def validate_public_corpus(self) -> None:
        catalog = self.repository.json(".factory/evals/public/catalog.json")
        cases = catalog["cases"]
        fixture_ids = [case["fixture_id"] for case in cases]
        require(fixture_ids == sorted(fixture_ids), "public corpus catalog cases are not sorted")
        require(len(fixture_ids) == len(set(fixture_ids)), "public corpus fixture IDs repeat")
        input_refs: set[str] = set()
        referenced_case_ids: set[str] = set()
        public_cases_by_id: dict[str, dict[str, Any]] = {}
        for case in cases:
            input_ref = case["input_ref"]
            require(input_ref not in input_refs, f"public corpus input is listed twice: {input_ref}")
            input_refs.add(input_ref)
            require(
                self.repository.digest(input_ref) == case["input_sha256"],
                f"{case['fixture_id']}: public corpus input hash differs",
            )
            document = self.repository.json(input_ref)
            require(document.get("schema_version") == 1, f"{input_ref}: wrong schema version")
            if input_ref.endswith("skill-routing.json") or input_ref.endswith("evolution-acceptance.json"):
                continue
            raw_cases = document.get("cases")
            require(isinstance(raw_cases, list) and raw_cases, f"{input_ref}: cases must be nonempty")
            local_ids: list[str] = []
            for raw_case in raw_cases:
                require(isinstance(raw_case, dict), f"{input_ref}: case must be an object")
                require(
                    set(raw_case) == {
                        "expected_decision",
                        "expected_reason_code",
                        "fixture_id",
                        "input",
                    },
                    f"{input_ref}: case uses unknown or missing fields",
                )
                require(
                    raw_case["expected_decision"] in ("accept", "reject"),
                    f"{input_ref}: case decision is outside the closed enum",
                )
                require(
                    isinstance(raw_case["expected_reason_code"], str)
                    and raw_case["expected_reason_code"],
                    f"{input_ref}: case reason is empty",
                )
                require(isinstance(raw_case["input"], dict), f"{input_ref}: case input must be an object")
                local_ids.append(raw_case["fixture_id"])
                public_cases_by_id[raw_case["fixture_id"]] = raw_case
            require(len(local_ids) == len(set(local_ids)), f"{input_ref}: fixture IDs repeat")
            require(
                not referenced_case_ids.intersection(local_ids),
                f"{input_ref}: fixture ID repeats across public corpora",
            )
            referenced_case_ids.update(local_ids)

        for fixture_id, expected in REQUIRED_PUBLIC_CASES.items():
            require(
                fixture_id in public_cases_by_id,
                f"public denial fixture {fixture_id} is missing",
            )
            actual = (
                public_cases_by_id[fixture_id]["expected_decision"],
                public_cases_by_id[fixture_id]["expected_reason_code"],
            )
            require(
                actual == expected,
                f"public denial fixture {fixture_id} changed its expected verdict",
            )
        factory_cases = self.repository.json(
            ".factory/evals/public/cases/factory-regressions.json"
        )["cases"]
        control_plane_cases = [
            item
            for item in factory_cases
            if item["fixture_id"] == "factory-product-builder-control-plane-write"
        ]
        require(len(control_plane_cases) == 1, "product/control-plane denial fixture is missing")
        control_plane_case = control_plane_cases[0]
        requested = control_plane_case["input"].get("requested_path")
        contract_kind = control_plane_case["input"].get("contract_kind")
        policy_patterns = self.repository.json(".factory/policy.json")["control_plane_paths"]
        require(contract_kind == "product-work", "control-plane denial must exercise product work")
        require(isinstance(requested, str), "control-plane denial requested_path is missing")
        require(
            any(fnmatch.fnmatchcase(requested, pattern) for pattern in policy_patterns),
            "product/control-plane denial does not request a protected path",
        )
        require(
            control_plane_case["expected_decision"] == "reject"
            and control_plane_case["expected_reason_code"] == "control-plane-path-not-allowed",
            "product/control-plane denial no longer fails closed",
        )
        owner_boundary_cases = [
            item
            for item in factory_cases
            if item["fixture_id"] == "factory-repeated-owner-preference-gate"
        ]
        require(len(owner_boundary_cases) == 1, "owner-boundary denial fixture is missing")
        owner_boundary_case = owner_boundary_cases[0]
        require(
            owner_boundary_case["input"]
            == {
                "accepted_product_context": True,
                "choice_class": "reversible",
                "requested_owner_approval": True,
            },
            "owner-boundary denial must exercise a repeated reversible preference gate",
        )
        for path, expected_digest in FROZEN_PUBLIC_CASE_CORPORA.items():
            require(path in input_refs, f"frozen public denial corpus is not cataloged: {path}")
            require(
                self.repository.digest(path) == expected_digest,
                f"frozen public denial corpus changed: {path}",
            )

    def validate_evolution_acceptance(self) -> None:
        path = ".factory/evals/public/evolution-acceptance.json"
        raw = self.repository.read_bytes(path)
        require(
            sha256_bytes(raw) == EVOLUTION_ACCEPTANCE_SHA256,
            "Evolution acceptance ruler changed after it was frozen",
        )
        acceptance = self.repository.json(path)
        require(acceptance["status"] == "frozen-before-evolution", "Evolution ruler is not frozen")
        require(acceptance["decision_rule"] == "all-criteria-pass", "Evolution ruler must be conjunctive")
        require(
            acceptance["trusted_root_binding"] == "resolved-to-owner-merged-sha-at-dispatch",
            "Evolution ruler lost its merged trusted root binding",
        )
        require(
            acceptance["private_epoch_binding"] == "owner-merged-before-evolution",
            "Evolution ruler lost its private epoch binding",
        )
        require(
            acceptance["public_corpus_scope"] == "visible-regressions-not-promotion",
            "public evaluation corpus cannot become promotion-qualifying",
        )
        criteria = acceptance["criteria"]
        criterion_ids = [criterion["id"] for criterion in criteria]
        require(set(criterion_ids) == REQUIRED_EVOLUTION_CRITERIA, "Evolution criteria are incomplete")
        require(len(criterion_ids) == len(set(criterion_ids)), "Evolution criterion IDs repeat")
        predicates: set[str] = set()
        for criterion in criteria:
            local = criterion["deterministic_predicate_ids"]
            require(not predicates.intersection(local), f"{criterion['id']}: predicate ownership repeats")
            predicates.update(local)
        forbidden = set(acceptance["forbidden_candidate_paths"])
        require(
            REQUIRED_EVOLUTION_FORBIDDEN_PATHS.issubset(forbidden),
            "Evolution forbidden candidate surface is incomplete",
        )

    def validate_skills(self) -> None:
        registry = self.repository.json(".factory/skills/registry.json")
        skills = registry["skills"]
        skill_ids = [skill["id"] for skill in skills]
        require(skill_ids == sorted(skill_ids), "skill registry is not sorted")
        require(len(skill_ids) == len(set(skill_ids)), "skill IDs repeat")
        require(
            registry["portfolio_status"] == "legacy-migration-required"
            and any(skill["status"] == "legacy" for skill in skills),
            "legacy-migration portfolio status requires at least one legacy skill",
        )
        skills_by_id = {skill["id"]: skill for skill in skills}
        if self.selected_skill is not None:
            require(self.selected_skill in skills_by_id, f"unknown skill {self.selected_skill!r}")
            selected = [skills_by_id[self.selected_skill]]
        else:
            selected = skills

        self.validate_capabilities(skills_by_id)
        routing = self.routing_by_id()
        all_canaries = {
            fixture["unselected_canary"]
            for fixture in routing.values()
            if fixture["unselected_canary"] is not None
        }
        canary_fixture_count = sum(
            1 for fixture in routing.values() if fixture["unselected_canary"]
        )
        require(len(all_canaries) == canary_fixture_count, "routing canaries repeat")

        for skill in selected:
            self.validate_skill(skill, skills_by_id, routing, all_canaries)
            self.validated_skills += 1

    def validate_capabilities(self, skills_by_id: dict[str, dict[str, Any]]) -> None:
        capability_map = self.repository.json(".factory/skills/capabilities.json")
        capabilities = capability_map["capabilities"]
        capability_ids = [item["id"] for item in capabilities]
        primary_skill_ids = [item["primary_skill_id"] for item in capabilities]
        require(capability_ids == sorted(capability_ids), "capability map is not sorted")
        require(len(capability_ids) == len(set(capability_ids)), "capability IDs repeat")
        require(len(primary_skill_ids) == len(set(primary_skill_ids)), "a skill owns multiple primary capabilities")
        require(set(primary_skill_ids) == set(skills_by_id), "capability owners and registry skills differ")
        mapped = {item["primary_skill_id"]: item["id"] for item in capabilities}
        for skill_id, skill in skills_by_id.items():
            require(
                mapped[skill_id] == skill["primary_capability_id"],
                f"{skill_id}: primary capability mapping differs",
            )
            require(
                skill["primary_capability_id"] not in skill["non_capabilities"],
                f"{skill_id}: primary capability is also denied",
            )

        edges = capability_map["composition_edges"]
        actual_edges = [
            (edge["from_skill_id"], edge["kind"], edge["to_skill_id"])
            for edge in edges
        ]
        require(actual_edges == sorted(actual_edges), "capability composition edges are not sorted")
        require(len(actual_edges) == len(set(actual_edges)), "capability composition edges repeat")
        expected_edges: set[tuple[str, str, str]] = set()
        for skill_id, skill in skills_by_id.items():
            for dependency in skill["dependency_skill_ids"]:
                expected_edges.add((skill_id, "uses", dependency))
            for handoff in skill["handoff_skill_ids"]:
                expected_edges.add((skill_id, "hands_off_to", handoff))
        require(set(actual_edges) == expected_edges, "capability composition differs from skill manifests")

    def routing_by_id(self) -> dict[str, dict[str, Any]]:
        path = ".factory/evals/public/skill-routing.json"
        require(
            self.repository.digest(path) == FROZEN_SKILL_ROUTING_SHA256,
            "frozen skill-routing corpus changed",
        )
        fixtures = self.repository.json(path)["fixtures"]
        fixture_ids = [fixture["fixture_id"] for fixture in fixtures]
        require(fixture_ids == sorted(fixture_ids), "skill routing fixtures are not sorted")
        require(len(fixture_ids) == len(set(fixture_ids)), "skill routing fixture IDs repeat")
        return {fixture["fixture_id"]: fixture for fixture in fixtures}

    def validate_skill(
        self,
        skill: dict[str, Any],
        skills_by_id: dict[str, dict[str, Any]],
        routing: dict[str, dict[str, Any]],
        all_canaries: set[str],
    ) -> None:
        skill_id = skill["id"]
        sorted_fields = (
            "allowed_tools",
            "conflicts_with",
            "dependency_skill_ids",
            "handoff_skill_ids",
            "non_capabilities",
            "progressive_disclosure_paths",
            "public_eval_tags",
            "risk_tiers",
            "supersedes",
            "supported_phases",
            "supported_roles",
        )
        for field in sorted_fields:
            require(skill[field] == sorted(skill[field]), f"{skill_id}: {field} is not sorted")

        referenced_skills = set(
            skill["conflicts_with"]
            + skill["dependency_skill_ids"]
            + skill["handoff_skill_ids"]
            + skill["supersedes"]
        )
        require(referenced_skills.issubset(skills_by_id), f"{skill_id}: references an unknown skill")
        require(skill_id not in referenced_skills, f"{skill_id}: cannot compose with itself")
        require(
            skill["verification_command"] == f"scripts/check-factory-contract.sh --skill {skill_id}",
            f"{skill_id}: verification command is not canonical",
        )

        source_path = skill["source_path"]
        source_raw = self.repository.read_bytes(source_path)
        require(sha256_bytes(source_raw) == skill["source_sha256"], f"{skill_id}: source hash differs")
        provenance_root = skill["provenance"]["repository_path"]
        expected_provenance_root = f".agents/skills/{skill_id}"
        require(
            provenance_root == expected_provenance_root,
            f"{skill_id}: provenance root is not the canonical skill root",
        )
        self.repository.path(provenance_root, kind="directory")
        require(
            source_path == f"{provenance_root}/SKILL.md",
            f"{skill_id}: source path is not the canonical SKILL.md",
        )

        resources = skill["resources"]
        resource_paths = [resource["path"] for resource in resources]
        require(resource_paths == sorted(resource_paths), f"{skill_id}: resources are not sorted")
        for resource in resources:
            raw = self.repository.read_bytes(resource["path"])
            require(len(raw) == resource["size_bytes"], f"{skill_id}: resource size differs")
            require(sha256_bytes(raw) == resource["sha256"], f"{skill_id}: resource hash differs")
            require(
                resource["path"].startswith(provenance_root + "/"),
                f"{skill_id}: resource is outside its provenance root",
            )

        progressive_paths = skill["progressive_disclosure_paths"]
        require(
            all(path.startswith(provenance_root + "/") for path in progressive_paths),
            f"{skill_id}: progressive disclosure is outside its provenance root",
        )
        provenance_path = self.repository.path(provenance_root, kind="directory")
        declared_components = sorted([source_path, *resource_paths, *progressive_paths])
        actual_components = sorted(
            path.relative_to(self.repository.root).as_posix()
            for path in provenance_path.rglob("*")
            if not stat.S_ISDIR(path.lstat().st_mode)
        )
        require(
            actual_components == declared_components,
            f"{skill_id}: provenance root contains undeclared components",
        )
        progressive_sizes = [len(self.repository.read_bytes(path)) for path in progressive_paths]
        budget = skill["context_budget"]
        require(len(source_raw) <= budget["body_bytes"], f"{skill_id}: source exceeds body budget")
        require(
            sum(resource["size_bytes"] for resource in resources) <= budget["resource_bytes"],
            f"{skill_id}: resources exceed resource budget",
        )
        require(
            sum(progressive_sizes) <= budget["reference_bytes"],
            f"{skill_id}: progressive references exceed reference budget",
        )
        component_total = sum(
            budget[field]
            for field in ("body_bytes", "metadata_bytes", "reference_bytes", "resource_bytes")
        )
        require(component_total == budget["total_bytes"], f"{skill_id}: context budget total differs")
        required_tokens = (budget["total_bytes"] + 3) // 4
        require(
            skill["declared_cost_ceiling"]["max_context_tokens"] == required_tokens,
            f"{skill_id}: token ceiling does not bind the byte budget",
        )

        qualification_path = skill["qualification_path"]
        require(
            qualification_path == f".factory/skills/qualification/{skill_id}.json",
            f"{skill_id}: qualification path is not canonical",
        )
        require(
            self.repository.digest(qualification_path) == skill["qualification_sha256"],
            f"{skill_id}: qualification hash differs",
        )
        qualification = self.repository.json(qualification_path)
        require(qualification["skill_id"] == skill_id, f"{skill_id}: qualification belongs to another skill")
        expected_components: list[dict[str, Any]] = [
            {
                "path": source_path,
                "sha256": skill["source_sha256"],
                "size_bytes": len(source_raw),
            },
            *resources,
        ]
        for path, size in zip(progressive_paths, progressive_sizes):
            expected_components.append(
                {"path": path, "sha256": self.repository.digest(path), "size_bytes": size}
            )
        expected_components.sort(key=lambda item: item["path"])
        require(
            qualification["component_hashes"] == expected_components,
            f"{skill_id}: qualification component inventory differs",
        )
        require(
            qualification["client_results"] == skill["client_qualification"],
            f"{skill_id}: qualification client results differ",
        )
        client_ids = {result["client_id"] for result in qualification["client_results"]}
        require(client_ids == REQUIRED_CLIENTS, f"{skill_id}: client qualification is incomplete")
        lane_ids = [lane["id"] for lane in qualification["lanes"]]
        require(lane_ids == sorted(lane_ids), f"{skill_id}: qualification lanes are not sorted")
        require(set(lane_ids) == REQUIRED_QUALIFICATION_LANES, f"{skill_id}: qualification lanes are incomplete")
        if skill["status"] == "legacy":
            require(qualification["report_status"] == "placeholder", f"{skill_id}: legacy report must be placeholder")
            require(qualification["frozen_at"] is None, f"{skill_id}: legacy report cannot be frozen")
            require(
                qualification["trusted_base_sha"] is None,
                f"{skill_id}: legacy report cannot claim a trusted base",
            )
            require(qualification["blockers"], f"{skill_id}: legacy report must state its blocker")
            require(
                all(result["status"] == "unqualified" for result in qualification["client_results"]),
                f"{skill_id}: legacy client cannot claim qualification",
            )
            require(
                all(lane["status"] == "pending" for lane in qualification["lanes"]),
                f"{skill_id}: legacy lanes must remain pending",
            )
        elif skill["status"] == "active":
            require(
                qualification["report_status"] == "qualified",
                f"{skill_id}: active report must be qualified",
            )
            require(qualification["frozen_at"] is not None, f"{skill_id}: active report is not frozen")
            require(
                qualification["trusted_base_sha"] is not None,
                f"{skill_id}: active report lacks a trusted base",
            )
            require(not qualification["blockers"], f"{skill_id}: active report has blockers")
            require(
                all(result["status"] == "passed" for result in qualification["client_results"]),
                f"{skill_id}: active client qualification is incomplete",
            )
            require(
                all(lane["status"] == "passed" for lane in qualification["lanes"]),
                f"{skill_id}: active qualification lane is incomplete",
            )
            require(
                all(lane["evidence_refs"] for lane in qualification["lanes"]),
                f"{skill_id}: active qualification lane lacks evidence",
            )

        declared_positive = skill["trigger_fixture_ids"]["positive"]
        declared_negative = skill["trigger_fixture_ids"]["negative"]
        require(
            declared_positive == sorted(declared_positive),
            f"{skill_id}: positive fixture IDs are not sorted",
        )
        require(
            declared_negative == sorted(declared_negative),
            f"{skill_id}: negative fixture IDs are not sorted",
        )
        actual_ids = {
            fixture_id
            for fixture_id, fixture in routing.items()
            if fixture["target_skill_id"] == skill_id
        }
        require(
            actual_ids == set(declared_positive + declared_negative),
            f"{skill_id}: routing fixtures differ from its manifest",
        )
        for fixture_id in declared_positive:
            require(fixture_id in routing, f"{skill_id}: positive routing fixture is missing")
            fixture = routing[fixture_id]
            require(fixture["kind"] == "positive", f"{fixture_id}: expected positive kind")
            require(skill_id in fixture["expected_selected_skill_ids"], f"{fixture_id}: skill is not selected")
            require(fixture["forbidden_skill_id"] is None, f"{fixture_id}: positive fixture forbids a skill")
            require(fixture["unselected_canary"] is None, f"{fixture_id}: positive fixture carries a canary")
        for fixture_id in declared_negative:
            require(fixture_id in routing, f"{skill_id}: negative routing fixture is missing")
            fixture = routing[fixture_id]
            require(fixture["kind"] == "confusable-negative", f"{fixture_id}: expected negative kind")
            require(fixture["forbidden_skill_id"] == skill_id, f"{fixture_id}: wrong forbidden skill")
            require(
                skill_id not in fixture["expected_selected_skill_ids"],
                f"{fixture_id}: forbidden skill is selected",
            )
            require(fixture["unselected_canary"] is not None, f"{fixture_id}: negative fixture lacks canary")
        for fixture_id in actual_ids:
            expected = routing[fixture_id]["expected_selected_skill_ids"]
            require(expected == sorted(expected), f"{fixture_id}: selected skills are not sorted")
            require(set(expected).issubset(skills_by_id), f"{fixture_id}: selects an unknown skill")

        projected_paths = [source_path, *resource_paths, *progressive_paths]
        prompt_registry = self.repository.json(".factory/prompts/registry.json")
        projected_paths.extend(role["path"] for role in prompt_registry["roles"])
        projected_text = b"\n".join(self.repository.read_bytes(path) for path in projected_paths)
        for canary in all_canaries:
            require(
                canary.encode("utf-8") not in projected_text,
                f"{skill_id}: unselected routing canary leaked into projected context",
            )


def parse_arguments() -> argparse.Namespace:
    default_root = pathlib.Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=pathlib.Path, default=default_root)
    parser.add_argument("--skill", help="validate one registered skill's bound artifacts")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        repository = Repository(arguments.root)
        validator = ContractValidator(repository, arguments.skill)
        validator.run()
    except (ContractError, OSError) as error:
        print(f"factory-contract: ERROR: {error}", file=sys.stderr)
        return 1

    print(
        "factory-contract: validated "
        f"{len(repository.json_documents)} JSON files, "
        f"{validator.validated_records} schema records, "
        f"{validator.rejected_fixtures} negative fixtures, "
        f"and {validator.validated_skills} skill(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
