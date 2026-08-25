# 005 — Localization is mandatory from the first English string

## Context

Agent-built apps accumulate user-facing English quickly: empty states, buttons,
accessibility labels, preview states, permission affordances, and placeholder
copy all arrive before a product has real translations. If that copy is allowed
to live directly in views, localization becomes a risky late rewrite and agents
cannot reliably tell which strings are user-facing.

## Decision

The harness ships with English base string catalogs and small `*L10n.swift`
helpers for app, feature, and design-system copy. Production SwiftUI/app source
must use those helpers for user-facing strings in common UI APIs (`Text`,
`Button`, `Label`, navigation titles, accessibility labels/hints, DS buttons and
empty states). `scripts/check-localization.sh` runs from `scripts/lint.sh`, and
`scripts/new-feature.sh` scaffolds a feature-local `L10n` helper plus catalog
keys. English base copy is normal implementation work; adding real translated
locales or machine-translated copy is owner-reviewed copy work.

## Consequences

Every app starts localization-ready without waiting for a translation project.
The guardrail is intentionally cheap rather than exhaustive: it catches the raw
UI literals agents most commonly add, while allowing localized values,
user-generated strings, fixture data, and domain identifiers to flow through the
app. If a concrete app needs stronger extraction or translator handoff later,
it can build on the existing catalogs instead of first untangling view code.
