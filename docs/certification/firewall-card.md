# Firewall model + policy card (ClosedPolicyFirewall)

Collector anchor: trust-firewall-card v1.
Source: `Packages/Domain/Sources/Domain/ClosedPolicyFirewall.swift`.
Status: baseline, releasable without release-scope selection.

## Model

The firewall is the sole bridge from fused sensing input to product
behavior. It owns one in-memory bus, fuses internally at injected ticks,
qualifies the fused verdict, and routes at most one closed command per
evaluation through the fenced coordinator entry point. It never touches
the unfenced single-producer path, never invents action kinds, never
presents UI, never settles product facts, and never mutates clocks:
every routed command commits identity, rank, and fence only, with no
fact and no clock delta.

Memory-only (Class 0): the firewall persists nothing. The public result
is a sanitized receipt — identities, closed kind, effect class, lease
window, an opaque assessment digest, and ticks — carrying no reading,
confidence, provider, or group content. Full provenance stays
module-internal, pinned by in-module tests.

## Policy (deny by default)

- Unknown verdicts — missing, stale, denied, degraded, contradictory,
  revoked, fenced, rotated-out — emit nothing. Authority retirements
  (revision advance, epoch fence, session rotation) are exposed as
  passthroughs to the held bus authority, so no retirement is
  unreceivable: post-retirement atoms stop voting at once.
- Weak (low-confidence) presence may only quiet (hold presentation while
  accumulation continues) or shift within the live soft-to-latest window.
  Weak signals never restart and never release. One live representative
  sustains at most one outstanding hold per input kind.
- Strong (medium/high-confidence) motion restarts the movement cycle
  through the registered strong-movement command. Strong presence holds
  quietly. Strong absence releases at most the firewall's own outstanding
  hold for the same input kind, by naming its exact decision identity.
- Every hold carries a deadline; an expired hold is released lazily at
  the next evaluation of its kind. Every routed command carries a
  coordinator lease: the smaller of the remaining source lifetime and
  the 90-second coordinator maximum, minted at the evaluation ticks.
- Command identities mix an injected firewall identity with seeds plus a
  per-emission counter: identical inputs on one firewall reproduce
  identical commands, different firewalls never collide, and routing the
  same command twice replays the original receipt without reapplying.

## Limits

- Three qualified plan cases for three allowlisted commands: a
  non-allowlisted kind is unrepresentable by construction.
- Shift has no dedicated command in the 2.x vocabulary; a shift is a
  hold paired with a bounded re-evaluation horizon read live from the
  passed coordinator's engine configuration, never from a held copy.
- No performance, energy, or health-outcome claim is made for the
  firewall here; measured behavior waits on the owner hardware run.
