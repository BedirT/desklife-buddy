#!/bin/bash -p
# Populate English string catalogs from compiler-emitted .stringsdata while
# keeping the semantic keys used by the app's localization helpers.
set -euo pipefail
. "$(dirname "$0")/lib.sh"
cd "$ROOT"

/usr/bin/python3 - "$ROOT" <<'PY'
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
objects_root = root / ".build" / "DerivedData" / "Build" / "Intermediates.noindex"

helper_pattern = re.compile(
    r"\b(?:AppL10n|DomainL10n|DesignSystemL10n|FeatureL10n|L10n)\.(?:string|resource)\(\s*\"((?:\\.|[^\"\\])*)\"",
    re.MULTILINE | re.DOTALL,
)


def line_number_at(text, offset):
    return text.count("\n", 0, offset) + 1


def find_call_end(text, open_paren):
    depth = 0
    in_string = False
    in_line_comment = False
    in_block_comment = False
    escaped = False
    index = open_paren

    while index < len(text):
        char = text[index]
        next_char = text[index + 1] if index + 1 < len(text) else ""

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
            index += 1
            continue

        if in_block_comment:
            if char == "*" and next_char == "/":
                in_block_comment = False
                index += 2
            else:
                index += 1
            continue

        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == "\"":
                in_string = False
            index += 1
            continue

        if char == "/" and next_char == "/":
            in_line_comment = True
            index += 2
            continue

        if char == "/" and next_char == "*":
            in_block_comment = True
            index += 2
            continue

        if char == "\"":
            in_string = True
            index += 1
            continue

        if char == "(":
            depth += 1
        elif char == ")":
            depth -= 1
            if depth == 0:
                return index

        index += 1

    return len(text) - 1


def helper_calls(source):
    text = source.read_text()
    calls = []
    for match in helper_pattern.finditer(text):
        open_paren = text.find("(", match.start())
        close_paren = find_call_end(text, open_paren)
        calls.append({
            "key": bytes(match.group(1), "utf-8").decode("unicode_escape"),
            "start": line_number_at(text, match.start()),
            "end": line_number_at(text, close_paren),
        })
    return calls


call_cache = {}


def semantic_key_for(source, line):
    source = pathlib.Path(source)
    if source not in call_cache:
        if not source.exists():
            call_cache[source] = []
        else:
            call_cache[source] = helper_calls(source)

    matches = [call for call in call_cache[source] if call["start"] <= line <= call["end"]]
    if not matches:
        return None
    matches.sort(key=lambda call: call["end"] - call["start"])
    return matches[0]["key"]


def collect_stringsdata(paths, source_prefixes, excluded_parts=None):
    excluded_parts = excluded_parts or set()
    entries = {}
    skipped = []

    for path in sorted(paths):
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue

        source = pathlib.Path(data.get("source", ""))
        if not source:
            continue

        try:
            relative_source = source.relative_to(root)
        except ValueError:
            continue

        if excluded_parts.intersection(relative_source.parts):
            continue

        if not any(str(relative_source).startswith(prefix) for prefix in source_prefixes):
            continue

        for item in data.get("tables", {}).get("Localizable", []):
            line = item.get("location", {}).get("startingLine")
            value = item.get("key")
            if not line or not value:
                continue

            semantic_key = semantic_key_for(source, line)
            if semantic_key is None:
                skipped.append(f"{relative_source}:{line}: {value}")
                continue

            comment = item.get("comment", "")
            existing = entries.get(semantic_key)
            if existing and existing["value"] != value:
                raise SystemExit(
                    f"Localization key {semantic_key!r} maps to multiple values: "
                    f"{existing['value']!r} and {value!r}"
                )

            entries[semantic_key] = {
                "comment": comment,
                "value": value,
            }

    return entries, skipped


def value_without_sequential_positional_specifiers(value):
    if value is None:
        return None
    pattern = re.compile(r"%(\d+)\$(?=[A-Za-z@])")
    positions = [int(match.group(1)) for match in pattern.finditer(value)]
    if positions != list(range(1, len(positions) + 1)):
        return value
    return pattern.sub("%", value)


def write_catalog(path, entries, property_separator):
    """Merge the extracted English into the catalog on disk.

    This used to build a fresh catalog from `entries` alone, which silently
    deleted every non-English localization in the file - a stale or partial
    build then wiped thousands of translated strings. Translations are only
    ever written by hand, so this never removes one: it updates English,
    flags the other locales for review when the English underneath them
    changed, and leaves keys it did not see alone.
    """
    if path.exists():
        catalog = json.loads(path.read_text())
    else:
        catalog = {"sourceLanguage": "en", "strings": {}, "version": "1.0"}

    strings = catalog.setdefault("strings", {})
    added = updated = 0

    for key in sorted(entries):
        value = entries[key]["value"]
        comment = entries[key]["comment"]
        item = strings.get(key)

        if item is None:
            strings[key] = {
                "extractionState": "manual",
                "localizations": {
                    "en": {"stringUnit": {"state": "translated", "value": value}},
                },
            }
            if comment:
                strings[key]["comment"] = comment
            added += 1
            continue

        localizations = item.setdefault("localizations", {})
        english = localizations.setdefault("en", {"stringUnit": {}})["stringUnit"]
        existing_value = english.get("value")
        if (
            existing_value != value
            and value_without_sequential_positional_specifiers(existing_value) != value
        ):
            english["state"] = "translated"
            english["value"] = value
            # The other locales now describe copy that moved underneath them.
            for code, unit in localizations.items():
                if code != "en":
                    unit["stringUnit"]["state"] = "needs_review"
            updated += 1
        if comment:
            item["comment"] = comment

    unseen = sorted(set(strings) - set(entries))

    # Keep the file's existing key order; only genuinely new keys move to the
    # end. Re-sorting the whole catalog turns a two-string change into a
    # thousand-line diff that no one can review.
    catalog["strings"] = strings
    path.write_text(
        json.dumps(
            catalog,
            indent=2,
            separators=(",", property_separator),
            ensure_ascii=False,
        )
        + "\n"
    )
    return added, updated, unseen


catalogs = [
    {
        "name": "App",
        "catalog": root / "App" / "Resources" / "Localizable.xcstrings",
        "stringsdata": (objects_root / "App.build").glob(
            "Debug*/App.build/Objects-normal/*/*.stringsdata"
        ),
        "prefixes": ("App/",),
        "excluded": set(),
        "property_separator": " : ",
    },
    {
        "name": "DesignSystem",
        "catalog": root / "Packages" / "DesignSystem" / "Sources" / "DesignSystem" / "Resources" / "Localizable.xcstrings",
        "stringsdata": (objects_root / "DesignSystem.build").glob(
            "Debug*/DesignSystem.build/Objects-normal/*/*.stringsdata"
        ),
        "prefixes": ("Packages/DesignSystem/Sources/DesignSystem/",),
        "excluded": {"Resources"},
        "property_separator": " : ",
    },
    {
        "name": "Features",
        "catalog": root / "Packages" / "Features" / "Sources" / "FeatureLocalization" / "Resources" / "Localizable.xcstrings",
        "stringsdata": (objects_root / "Features.build").glob(
            "Debug*/*.build/Objects-normal/*/*.stringsdata"
        ),
        "prefixes": ("Packages/Features/Sources/",),
        "excluded": {"FeatureLocalization", "Resources"},
        "property_separator": ": ",
    },
]

if not objects_root.exists():
    raise SystemExit("Missing DerivedData string extraction output. Run scripts/build.sh first.")

total = 0
collected = []
for spec in catalogs:
    entries, skipped = collect_stringsdata(
        list(spec["stringsdata"]),
        spec["prefixes"],
        spec["excluded"],
    )
    collected.append((spec, entries, skipped))
    total += len(entries)

if total == 0:
    raise SystemExit("No localization helper strings found in DerivedData. Run scripts/build.sh first.")

# A build that produced nothing for one target can only ever remove strings
# from that target's catalog, so it is a stale build rather than a real empty
# set. Refuse the whole run instead of writing part of it.
empty = [spec["name"] for spec, entries, _ in collected if not entries]
if empty:
    raise SystemExit(
        "No strings extracted for: " + ", ".join(empty) + ". "
        "That is a stale or partial DerivedData; run scripts/build.sh and retry."
    )

for spec, entries, skipped in collected:
    added, updated, unseen = write_catalog(
        spec["catalog"], entries, spec["property_separator"]
    )
    print(
        f"{spec['name']}: {len(entries)} strings in sources "
        f"({added} added, {updated} English value(s) changed) "
        f"→ {spec['catalog'].relative_to(root)}"
    )
    if unseen:
        print(f"  kept {len(unseen)} catalog key(s) not seen in this build (nothing is deleted here):")
        for key in unseen[:5]:
            print(f"    {key}")
        if len(unseen) > 5:
            print(f"    … and {len(unseen) - 5} more")
    for message in skipped[:5]:
        print(f"  skipped non-helper string: {message}")
    if len(skipped) > 5:
        print(f"  skipped {len(skipped) - 5} more non-helper strings")
PY
