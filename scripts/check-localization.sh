#!/bin/bash -p
# Localization policy checks. This is intentionally a cheap guardrail, not a
# full Swift parser: it catches direct raw UI literals in production sources,
# verifies that each source-owning bundle has a string catalog home, and keeps
# manually owned Turkish/Swedish translations complete and format-compatible.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

/usr/bin/python3 -I - "$ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
failures = []

printf_placeholder_pattern = re.compile(
    r"%(?!%)(?:(?P<position>\d+)\$)?[-+ #0']*"
    r"(?:(?P<width>\d+)|(?P<width_star>\*)(?:(?P<width_position>\d+)\$)?)?"
    r"(?:\.(?:(?P<precision>\d+)|(?P<precision_star>\*)"
    r"(?:(?P<precision_position>\d+)\$)?))?"
    r"(?P<length>hh|h|ll|l|L|z|j|t|q)?(?P<conversion>[@diuoxXfFeEgGaAcCsSp])"
)


def placeholder_signature(value):
    signature = []
    next_position = 1

    def consume_position(explicit_position):
        nonlocal next_position
        if explicit_position:
            return int(explicit_position)
        position = next_position
        next_position += 1
        return position

    for match in printf_placeholder_pattern.finditer(value or ""):
        if match.group("width_star"):
            signature.append((consume_position(match.group("width_position")), "d"))
        if match.group("precision_star"):
            signature.append((consume_position(match.group("precision_position")), "d"))
        position = consume_position(match.group("position"))
        value_type = f"{match.group('length') or ''}{match.group('conversion')}"
        signature.append((position, value_type))
    return sorted(signature)

required_catalogs = [
    "App/Resources/Localizable.xcstrings",
    "App/Resources/InfoPlist.xcstrings",
    "Packages/DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings",
    "Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings",
]

# These catalogs are round-tripped by both Xcode and the sync script. Keep the
# separator they share explicit so a compact Python rewrite cannot hide a
# small localization change inside a whole-file diff. Features keeps its
# compact script-owned layout and is not rewritten by Xcode.
xcode_round_tripped_catalogs = {
    "App/Resources/Localizable.xcstrings",
    "Packages/DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings",
}
catalog_property_pattern = re.compile(r'^\s*"(?:\\.|[^"\\])*"(?P<separator>\s*):')

for relative in required_catalogs:
    path = root / relative
    if not path.exists():
        failures.append(f"{relative}: missing localization catalog")
        continue
    try:
        catalog_text = path.read_text()
        json.loads(catalog_text)
    except (OSError, json.JSONDecodeError) as error:
        failures.append(f"{relative}: invalid localization catalog ({error})")
        continue

    catalog = json.loads(catalog_text)
    for key, entry in catalog.get("strings", {}).items():
        for locale, localization in entry.get("localizations", {}).items():
            value = localization.get("stringUnit", {}).get("value")
            if value is not None and "\u2014" in value:
                failures.append(
                    f"{relative}: {key}: {locale}: runtime copy contains an em dash"
                )

        if entry.get("extractionState") != "manual":
            continue
        localizations = entry.get("localizations", {})
        english_unit = localizations.get("en", {}).get("stringUnit")
        english_signature = placeholder_signature((english_unit or {}).get("value"))
        for locale in ("tr", "sv"):
            unit = localizations.get(locale, {}).get("stringUnit")
            if unit is None:
                failures.append(f"{relative}: {key}: {locale}: missing manual translation")
            elif unit.get("state") != "translated":
                failures.append(
                    f"{relative}: {key}: {locale}: {unit.get('state', 'missing')} manual translation"
                )
            elif placeholder_signature(unit.get("value")) != english_signature:
                failures.append(f"{relative}: {key}: {locale}: placeholder mismatch")

    if relative in xcode_round_tripped_catalogs:
        for line_number, line in enumerate(catalog_text.splitlines(), start=1):
            match = catalog_property_pattern.match(line)
            if match and match.group("separator") != " ":
                failures.append(
                    f"{relative}:{line_number}: catalog formatting drift; "
                    'use Xcode-style `"key" : value` separators'
                )
                break

literal_patterns = [
    re.compile(r'\bText\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\bButton\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\bLabel\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\bToggle\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\.navigationTitle\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\.accessibilityLabel\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\.accessibilityHint\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\bDSButton\(\s*"[^"]*[A-Za-z][^"]*"'),
    re.compile(r'\bDSEmptyState\([^)]*\b(title|message|actionTitle):\s*"[^"]*[A-Za-z][^"]*"', re.DOTALL),
]

source_roots = [
    root / "App",
    root / "Packages" / "Features" / "Sources",
    root / "Packages" / "DesignSystem" / "Sources",
]
excluded_parts = {"FeatureLocalization", "Resources"}

for source_root in source_roots:
    for file in sorted(source_root.rglob("*L10n.swift")):
        if "\u2014" not in file.read_text():
            continue
        failures.append(
            f"{file.relative_to(root)}: runtime localization source contains an em dash"
        )

for source_root in source_roots:
    for file in sorted(source_root.rglob("*.swift")):
        if any(part in excluded_parts for part in file.parts):
            continue
        text = file.read_text()
        lines = text.splitlines()
        reported_lines = set()
        for pattern in literal_patterns:
            for match in pattern.finditer(text):
                index = text.count("\n", 0, match.start()) + 1
                if index in reported_lines:
                    continue
                line = lines[index - 1] if index <= len(lines) else ""
                stripped = line.strip()
                if stripped.startswith("#Preview") or "preview-localization-exempt" in stripped:
                    continue
                failures.append(
                    f"{file.relative_to(root)}:{index}: raw UI literal should use a localization helper"
                )
                reported_lines.add(index)

if failures:
    print("Localization policy violations:")
    for failure in failures:
        print(f"  {failure}")
    sys.exit(1)

print("check-localization: OK")
PY
