#!/bin/bash -p
# Rehearse catalog synchronization against a small compiler-output fixture.
#
# Each catalog writer and its existing consumer must agree on JSON separators.
# This keeps a source change reviewable instead of turning it into a formatting
# rewrite, and the localization check must catch a future compact rewrite.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/sync-localization-rehearsal-XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT INT TERM

fail() {
  echo "sync-localization rehearsal: $*" >&2
  exit 1
}

REPO="$SANDBOX/repo"
mkdir -p "$REPO/scripts"
cp "$ROOT/scripts/lib.sh" "$REPO/scripts/lib.sh"
cp "$ROOT/scripts/check-localization.sh" "$REPO/scripts/check-localization.sh"
cp "$ROOT/scripts/sync-localization-catalogs.sh" "$REPO/scripts/sync-localization-catalogs.sh"
printf '#!/usr/bin/env bash\nexit 0\n' >"$REPO/scripts/check-dependency-inputs.sh"
chmod +x "$REPO/scripts/check-localization.sh" "$REPO/scripts/sync-localization-catalogs.sh"
chmod +x "$REPO/scripts/check-dependency-inputs.sh"

/usr/bin/python3 - "$REPO" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])

catalogs = {
    "App": ("App/Resources/Localizable.xcstrings", "App/Fixture.swift", "AppL10n"),
    "DesignSystem": (
        "Packages/DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings",
        "Packages/DesignSystem/Sources/DesignSystem/Fixture.swift",
        "DesignSystemL10n",
    ),
    "Features": (
        "Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings",
        "Packages/Features/Sources/Review/Fixture.swift",
        "FeatureL10n",
    ),
}
catalog_separators = {
    "App": " : ",
    "DesignSystem": " : ",
    "Features": ": ",
}

for name, (catalog_relative, source_relative, helper) in catalogs.items():
    key = f"fixture.{name.lower()}"
    value = "%lld of %lld reviewed" if name == "Features" else f"{name} fixture"
    english_value = "%1$lld of %2$lld reviewed" if name == "Features" else value
    localizations = {
        "en": {
            "stringUnit": {
                "state": "translated",
                "value": english_value,
            }
        }
    }
    if name == "Features":
        localizations.update(
            {
                "sv": {
                    "stringUnit": {
                        "state": "translated",
                        "value": "%1$lld av %2$lld granskade",
                    }
                },
                "tr": {
                    "stringUnit": {
                        "state": "translated",
                        "value": "%2$lld öğeden %1$lld tanesi gözden geçirildi",
                    }
                },
            }
        )
    else:
        localizations.update(
            {
                "sv": {
                    "stringUnit": {
                        "state": "translated",
                        "value": f"{name} svensk fixture",
                    }
                },
                "tr": {
                    "stringUnit": {
                        "state": "translated",
                        "value": f"{name} Türkçe fixture",
                    }
                },
            }
        )
    catalog = {
        "sourceLanguage": "en",
        "strings": {
            key: {
                "extractionState": "manual",
                "localizations": localizations,
            }
        },
        "version": "1.0",
    }
    catalog_path = repo / catalog_relative
    catalog_path.parent.mkdir(parents=True, exist_ok=True)
    catalog_path.write_text(
        json.dumps(
            catalog,
            indent=2,
            separators=(",", catalog_separators[name]),
            ensure_ascii=False,
        )
        + "\n"
    )

    source_path = repo / source_relative
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(f'{helper}.string("{key}", defaultValue: "{value}")\n')

    if name == "App":
        stringsdata_path = (
            repo
            / ".build/DerivedData/Build/Intermediates.noindex/App.build/"
            "Debug/App.build/Objects-normal/arm64/App.stringsdata"
        )
    elif name == "DesignSystem":
        stringsdata_path = (
            repo
            / ".build/DerivedData/Build/Intermediates.noindex/DesignSystem.build/"
            "Debug/DesignSystem.build/Objects-normal/arm64/DesignSystem.stringsdata"
        )
    else:
        stringsdata_path = (
            repo
            / ".build/DerivedData/Build/Intermediates.noindex/Features.build/"
            "Debug/Review.build/Objects-normal/arm64/Review.stringsdata"
        )

    stringsdata_path.parent.mkdir(parents=True, exist_ok=True)
    stringsdata_path.write_text(
        json.dumps(
            {
                "source": str(source_path),
                "tables": {
                    "Localizable": [
                        {
                            "location": {"startingLine": 1},
                            "key": value,
                        }
                    ]
                },
            }
        )
    )

info_catalog = repo / "App/Resources/InfoPlist.xcstrings"
info_catalog.parent.mkdir(parents=True, exist_ok=True)
info_catalog.write_text(
    json.dumps(
        {"sourceLanguage": "en", "strings": {}, "version": "1.0"},
        indent=2,
        separators=(",", " : "),
        ensure_ascii=False,
    )
    + "\n"
)
PY

"$REPO/scripts/sync-localization-catalogs.sh" >"$SANDBOX/sync.log" 2>&1 || {
  cat "$SANDBOX/sync.log" >&2
  fail "sync script failed against the compiler-output fixture"
}

FEATURES_CATALOG="$REPO/Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings"
cp "$FEATURES_CATALOG" "$SANDBOX/features-after-first-sync.xcstrings"
"$REPO/scripts/sync-localization-catalogs.sh" >"$SANDBOX/resync.log" 2>&1 || {
  cat "$SANDBOX/resync.log" >&2
  fail "sync script failed on an unchanged second run"
}
cmp -s "$FEATURES_CATALOG" "$SANDBOX/features-after-first-sync.xcstrings" ||
  fail "sync rewrote the catalog on an unchanged second run"

/usr/bin/python3 - "$REPO" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
catalogs = [
    repo / "App/Resources/Localizable.xcstrings",
    repo / "Packages/DesignSystem/Sources/DesignSystem/Resources/Localizable.xcstrings",
    repo / "Packages/Features/Sources/FeatureLocalization/Resources/Localizable.xcstrings",
]

for path in catalogs:
    raw = path.read_text()
    property_separator = ": " if "/FeatureLocalization/" in str(path) else " : "
    expected = json.dumps(
        json.loads(raw),
        indent=2,
        separators=(",", property_separator),
        ensure_ascii=False,
    ) + "\n"
    if raw != expected:
        raise SystemExit(f"{path.relative_to(repo)} was not written in its expected format")

features = json.loads(catalogs[-1].read_text())["strings"]["fixture.features"]["localizations"]
if features["en"]["stringUnit"]["value"] != "%1$lld of %2$lld reviewed":
    raise SystemExit("sync stripped positional specifiers from equivalent English copy")
for locale in ("sv", "tr"):
    if features[locale]["stringUnit"]["state"] != "translated":
        raise SystemExit(f"sync demoted the unchanged {locale} translation")
PY

/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
localizations = catalog["strings"]["fixture.features"]["localizations"]
localizations["en"]["stringUnit"]["value"] = "%2$lld of %1$lld reviewed"
for locale in ("sv", "tr"):
    localizations[locale]["stringUnit"]["state"] = "translated"
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

"$REPO/scripts/sync-localization-catalogs.sh" >"$SANDBOX/reordered.log" 2>&1 || {
  cat "$SANDBOX/reordered.log" >&2
  fail "sync script failed against reordered positional specifiers"
}

/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

localizations = json.loads(pathlib.Path(sys.argv[1]).read_text())["strings"][
    "fixture.features"
]["localizations"]
if localizations["en"]["stringUnit"]["value"] != "%lld of %lld reviewed":
    raise SystemExit("sync treated reordered positional specifiers as equivalent")
for locale in ("sv", "tr"):
    if localizations[locale]["stringUnit"]["state"] != "needs_review":
        raise SystemExit(f"sync did not demote {locale} after placeholder reordering")
PY

/usr/bin/python3 - "$REPO" <<'PY'
import json
import pathlib
import sys

repo = pathlib.Path(sys.argv[1])
stringsdata = (
    repo
    / ".build/DerivedData/Build/Intermediates.noindex/Features.build/"
    "Debug/Review.build/Objects-normal/arm64/Review.stringsdata"
)
payload = json.loads(stringsdata.read_text())
payload["tables"]["Localizable"][0]["key"] = "%lld of %lld reviewed today"
stringsdata.write_text(json.dumps(payload))
PY

"$REPO/scripts/sync-localization-catalogs.sh" >"$SANDBOX/changed-copy.log" 2>&1 || {
  cat "$SANDBOX/changed-copy.log" >&2
  fail "sync script failed after a genuine English copy change"
}

/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

localizations = json.loads(pathlib.Path(sys.argv[1]).read_text())["strings"][
    "fixture.features"
]["localizations"]
if localizations["en"]["stringUnit"]["value"] != "%lld of %lld reviewed today":
    raise SystemExit("sync did not apply a genuine English copy change")
for locale in ("sv", "tr"):
    if localizations[locale]["stringUnit"]["state"] != "needs_review":
        raise SystemExit(f"sync did not demote {locale} after a genuine copy change")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/changed-copy-coverage.log" 2>&1; then
  cat "$SANDBOX/changed-copy-coverage.log" >&2
  fail "localization check accepted translations invalidated by changed English copy"
fi

/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
localizations = catalog["strings"]["fixture.features"]["localizations"]
localizations["sv"]["stringUnit"] = {
    "state": "translated",
    "value": "%1$lld av %2$lld granskade i dag",
}
localizations["tr"]["stringUnit"] = {
    "state": "translated",
    "value": "%2$lld öğeden %1$lld tanesi bugün gözden geçirildi",
}
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

"$REPO/scripts/check-localization.sh" >"$SANDBOX/check.log" 2>&1 || {
  cat "$SANDBOX/check.log" >&2
  fail "localization check rejected a fully translated synchronized catalog"
}

MULTILINE_LITERAL="$REPO/Packages/Features/Sources/Review/MultilineLiteral.swift"
cat >"$MULTILINE_LITERAL" <<'SWIFT'
Text(
    "Raw multiline copy"
)
SWIFT
if "$REPO/scripts/check-localization.sh" >"$SANDBOX/multiline-literal.log" 2>&1; then
  fail "localization check accepted a multiline raw UI literal"
fi
grep -q 'MultilineLiteral.swift:1: raw UI literal' "$SANDBOX/multiline-literal.log" || {
  cat "$SANDBOX/multiline-literal.log" >&2
  fail "localization check did not report the multiline raw UI literal"
}
rm -f "$MULTILINE_LITERAL"

cp "$FEATURES_CATALOG" "$SANDBOX/features-before-coverage-drift.xcstrings"
/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
localizations = catalog["strings"]["fixture.features"]["localizations"]
localizations["tr"]["stringUnit"]["state"] = "needs_review"
del localizations["sv"]
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/coverage-drift.log" 2>&1; then
  cat "$SANDBOX/coverage-drift.log" >&2
  fail "localization check accepted missing and stale translated-locale coverage"
fi
grep -q "fixture.features.*tr.*needs_review" "$SANDBOX/coverage-drift.log" || {
  cat "$SANDBOX/coverage-drift.log" >&2
  fail "localization check did not report the stale Turkish translation"
}
grep -q "fixture.features.*sv.*missing" "$SANDBOX/coverage-drift.log" || {
  cat "$SANDBOX/coverage-drift.log" >&2
  fail "localization check did not report the missing Swedish translation"
}
cp "$SANDBOX/features-before-coverage-drift.xcstrings" "$FEATURES_CATALOG"

cp "$FEATURES_CATALOG" "$SANDBOX/features-before-placeholder-drift.xcstrings"
/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
catalog["strings"]["fixture.features"]["localizations"]["tr"]["stringUnit"]["value"] = (
    "%1$lld öğe bugün gözden geçirildi"
)
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/placeholder-drift.log" 2>&1; then
  cat "$SANDBOX/placeholder-drift.log" >&2
  fail "localization check accepted a translated placeholder mismatch"
fi
grep -q "fixture.features.*tr.*placeholder" "$SANDBOX/placeholder-drift.log" || {
  cat "$SANDBOX/placeholder-drift.log" >&2
  fail "localization check did not report the Turkish placeholder mismatch"
}
cp "$SANDBOX/features-before-placeholder-drift.xcstrings" "$FEATURES_CATALOG"

cp "$FEATURES_CATALOG" "$SANDBOX/features-before-positional-drift.xcstrings"
/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
catalog["strings"]["fixture.positional"] = {
    "extractionState": "manual",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%1$lld items for %2$@"}},
        "sv": {"stringUnit": {"state": "translated", "value": "%2$@ har %1$lld objekt"}},
        "tr": {"stringUnit": {"state": "translated", "value": "%1$@ için %2$lld öğe"}},
    },
}
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/positional-drift.log" 2>&1; then
  cat "$SANDBOX/positional-drift.log" >&2
  fail "localization check accepted placeholder types assigned to the wrong positions"
fi
grep -q "fixture.positional.*tr.*placeholder" "$SANDBOX/positional-drift.log" || {
  cat "$SANDBOX/positional-drift.log" >&2
  fail "localization check did not report the positional Turkish placeholder mismatch"
}
cp "$SANDBOX/features-before-positional-drift.xcstrings" "$FEATURES_CATALOG"

cp "$FEATURES_CATALOG" "$SANDBOX/features-before-dynamic-placeholder-drift.xcstrings"
/usr/bin/python3 - "$FEATURES_CATALOG" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
catalog = json.loads(path.read_text())
catalog["strings"]["fixture.dynamic-placeholder"] = {
    "extractionState": "manual",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%*lld items"}},
        "sv": {"stringUnit": {"state": "translated", "value": "%2$*1$lld objekt"}},
        "tr": {"stringUnit": {"state": "translated", "value": "%lld öğe"}},
    },
}
catalog["strings"]["fixture.dynamic-precision"] = {
    "extractionState": "manual",
    "localizations": {
        "en": {"stringUnit": {"state": "translated", "value": "%.*f score"}},
        "sv": {"stringUnit": {"state": "translated", "value": "%2$.*1$f poäng"}},
        "tr": {"stringUnit": {"state": "translated", "value": "%f puan"}},
    },
}
path.write_text(json.dumps(catalog, indent=2, separators=(",", " : "), ensure_ascii=False) + "\n")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/dynamic-placeholder-drift.log" 2>&1; then
  cat "$SANDBOX/dynamic-placeholder-drift.log" >&2
  fail "localization check accepted a missing dynamic-width argument"
fi
grep -q "fixture.dynamic-placeholder.*tr.*placeholder" "$SANDBOX/dynamic-placeholder-drift.log" || {
  cat "$SANDBOX/dynamic-placeholder-drift.log" >&2
  fail "localization check did not report the dynamic-width Turkish placeholder mismatch"
}
grep -q "fixture.dynamic-precision.*tr.*placeholder" "$SANDBOX/dynamic-placeholder-drift.log" || {
  cat "$SANDBOX/dynamic-placeholder-drift.log" >&2
  fail "localization check did not report the dynamic-precision Turkish placeholder mismatch"
}
cp "$SANDBOX/features-before-dynamic-placeholder-drift.xcstrings" "$FEATURES_CATALOG"

/usr/bin/python3 - "$REPO/App/Resources/Localizable.xcstrings" <<'PY'
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps(json.loads(path.read_text()), indent=2, ensure_ascii=False) + "\n")
PY

if "$REPO/scripts/check-localization.sh" >"$SANDBOX/drift.log" 2>&1; then
  cat "$SANDBOX/drift.log" >&2
  fail "localization check accepted a compact catalog rewrite"
fi
grep -q "catalog formatting" "$SANDBOX/drift.log" || {
  cat "$SANDBOX/drift.log" >&2
  fail "localization check did not report catalog formatting drift"
}

echo "sync-localization rehearsal: passed"
