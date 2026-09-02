# 07 — Privacy and Data Specification

## 1. Privacy objective

The product should feel private because it **is** private, not because the privacy copy is reassuring.

Core scheduling must run locally without an account, server, advertising identifier, camera, microphone, Screen Recording, Accessibility permission, Calendar, HealthKit, or analytics.

The privacy design follows data minimization, purpose limitation, meaningful consent, and privacy by default [S059–S063].

## 2. Data classification

### Class 0 — Ephemeral operational state

Examples:

- seconds since input;
- current suppression reason;
- frontmost bundle ID for matching a local exclusion;
- current Calendar busy interval;
- active overlay state.
- raw companion/terminal candidate envelopes, duplicates, losers, and rejected stale actions.

Requirements:

- memory only unless necessary for crash recovery;
- discard quickly;
- no analytics;
- no server transmission.

For D-033 coordination, raw candidate buffers are strictly memory-only and minimized to fields
needed for the current reduction. They have no durable record identity; ActionID is only transient
protocol correlation and is erased with the buffer. Discard occurs at settlement, generation or
projection fence, or **90 seconds**, whichever comes first. These buffers never enter an
operational/companion history ledger, crash recovery, export, Weekly, analytics, logs, or backups.
An old-generation rejected action may produce immediate on-screen/VoiceOver feedback, but that
user-facing projection is not retained. Out-of-order counter entries use the same Class-0 boundary:
a sparse pending window holds only minimized device/counter/action correlation for at most 90
seconds and is never persisted or exported. To make a lost acknowledgement idempotent, a compact
Class-0 replay receipt remains in memory until the device returns a verified
acknowledgement-of-ack for the delivered outcome token, or 90 monotonic seconds. Creating an
outcome ACK, projection fence, or generation fence never erases it. It contains only an ActionID
SHA-256 digest, origin device/counter, outcome code, successor revisions, outcome ACK, and delivery
token. It contains no raw action payload, user content, sensor value, product
fact, health fact, or durable identity; it is never logged, exported, analyzed, or backed up. While
present it replays the original outcome without effects. After erasure, high water proves only a
contiguous disposition, not delivery; duplicate and unseen actions say “too old to verify” and
show current state.

Early receipt erasure accepts only the signed `cadence.timing-runtime-v2.ack-of-ack.v1` envelope
bound to the exact generation, paired device, ActionID digest, counter, outcome revision, random
32-byte delivery token, original-outcome digest, and coordinator-monotonic expiry. The signature is
verified with that paired device's persisted actual 32-byte Ed25519 public key. A fingerprint is
display metadata only. Invalid, replay-mismatched, expired, or duplicate envelopes do not erase a
live receipt.

The sole raw-**action**-envelope persistence exception is the **sender crash-replay outbox**. Before
a paired device exposes a generated action, it atomically stores the next counter, ActionID, exact
canonical resend envelope, selected receiver DeviceID and verification-key ID/epoch, plus its local
monotonic anchor/epoch. The entry is locally encrypted, excluded from backup, history, export,
analytics, and logs. Relaunch may resend only that exact action when the local monotonic epoch still
matches, its anchor is available, and elapsed monotonic time is **less than 90 seconds**. An epoch
mismatch, missing anchor, corrupt entry, or `elapsed >= 90 seconds` erases it without transmission,
does not mint a replacement action, and projects “too old to verify” plus current state. Receiving
the signed outcome permits erasing this action outbox only after the receiver atomically persists
the minimized outcome-ACK continuation below. This record is not a product, health, audit, or
companion-history fact.

`outcome_ack_pending` is a second, minimized Class-0 crash-continuation record, not a raw action
payload exception. It atomically retains the exact complete signed `outcome_ack_bytes_v1`, outcome
revision, coordinator expiry ticks, random delivery token and replay binding, local receive
epoch/ticks, selected receiver DeviceID, and verification-key ID/epoch. Same-epoch relaunch before
90 seconds may transmit the one bound signed acknowledgement-of-ack without reapplying or
recreating the action. Transmission permits erasing the sender's pending record; the coordinator's
compact replay receipt independently survives until it verifies that acknowledgement-of-ack or 90
seconds. No acknowledgement of the acknowledgement-of-ack is created. Epoch mismatch, missing
anchor, corrupt binding, re-pair, key mismatch, or `elapsed >= 90 seconds` erases the pending record
without transmission and uses the same uncertainty-safe projection.
For an ordinary key rotation, an already-bound pending acknowledgement may retain only a reference
to the old non-exportable private signing key in the local encrypted Keychain through that record's
same-epoch window. The handle is not raw key bytes, is unavailable to new commands, is excluded
from backup/export/logs/analytics, and erases with the pending record. Re-pairing instead fences the
old peer immediately, erases the handle and pending transport record, and shows the registered
rejected or uncertainty-safe receipt; it never re-signs under the new relationship.

### Class 1 — Local routine data

Examples:

- protocol profile;
- working hours;
- break responses;
- daily aggregate active-use estimate;
- longest estimated run;
- content preference;
- skip/snooze categories.
- current coordination continuity state: GlobalStateID, coordinator generation/revision,
  per-device contiguous action-disposition high water, active projection fences, actual paired and
  installation Ed25519 public-key bytes plus derived display fingerprints, without raw candidate
  payloads outside the bounded sender outbox exception.

Requirements:

- local by default;
- export/delete available;
- bounded retention;
- no third-party advertising use;
- clear schema and migration.

### Class 2 — Sensitive contextual data

Examples:

- selected Calendar IDs;
- app exclusion list;
- exact timestamps;
- inferred work pattern;
- accessibility preferences.
- paired-device trust mapping, actual Ed25519 public keys required for verification, and each
  device's local private coordinator/acknowledgement signing key.

Requirements:

- collect only when required;
- local only unless user explicitly enables sync;
- do not use to infer employment, disability, or productivity;
- minimize granularity.
- never export a private signing key; retain it only until reset/unpair. Export/display may include
  a derived public fingerprint for inspection, but verification always uses the locally persisted
  actual 32-byte public key from the authenticated pairing record.

### Class 3 — Health-adjacent or health data

Examples:

- symptom check-ins;
- pain/fatigue ratings;
- HealthKit/Watch data;
- camera-derived blink, gaze, posture, or face presence;
- medical-condition preferences.

Requirements:

- excluded from core MVP except optional minimal subjective check-ins;
- separate explicit consent and purpose;
- no sale, advertising, or broad analytics;
- stricter retention and access controls;
- privacy impact assessment before expansion;
- regulatory review when function or claim changes.

## 3. Data the MVP must never collect

- keystrokes or typed content;
- pointer paths or click coordinates;
- window titles;
- browser URLs or history;
- document/file names;
- screenshots or screen recordings;
- camera images/video;
- microphone/audio;
- Calendar titles, notes, attendees, organizer, location, or meeting links;
- contact lists;
- employer identity inferred from app use;
- cross-app advertising identifiers;
- raw precise location;
- biometric templates;
- free-text medical history;
- diagnostic labels.

## 4. Local-first architecture

### Core mode

- no account;
- no network required after installation/update;
- local database stores aggregate/event data;
- local preferences;
- signed app/content updates only;
- user can inspect/export/delete data.

### Optional sync later

If iCloud/CloudKit sync is added:

- opt-in, not default;
- clearly separate preferences from health-adjacent data;
- sync minimum fields;
- use Apple account infrastructure rather than creating a parallel identity where possible;
- document deletion semantics across devices;
- do not enable symptom or HealthKit-derived sync without separate review.

## 5. Calendar privacy

Purpose: suppress reminders during selected busy intervals.

Implementation:

1. ask only after user enables the feature;
2. explain purpose and alternatives;
3. allow calendar selection;
4. query a narrow time horizon;
5. map events to busy/free intervals in memory;
6. discard all content fields;
7. retain only settings and optional coarse suppression counts;
8. provide immediate disable/revoke guidance.

Do not send event data to analytics. Do not build a meeting-history database.

## 6. Application exclusions

Store bundle IDs locally only. The default summary must not reveal an app-by-app work history.

If analytics is enabled, never transmit raw bundle IDs, app names, categories inferred from usage, or timestamps that could reconstruct usage.

## 7. Subjective check-ins

Optional and disabled by default.

Allowed fields:

- eye comfort rating;
- neck/shoulder comfort rating;
- fatigue rating;
- break usefulness;
- a small controlled set of reasons.

Avoid free text in the MVP because it can contain diagnoses, names, work secrets, or other sensitive information.

UI must state:

- ratings are subjective;
- they are not diagnosis or medical measurement;
- the feature can be deleted or disabled;
- the core app works without it.

Suggested retention: 90 days locally by default, configurable to shorter/none; keep longer only if the user explicitly chooses trend history.

## 8. Analytics

### Default

Off, or separate explicit opt-in after core onboarding.

### Allowed coarse events

- app version and OS version;
- profile type;
- visual/movement opportunity category;
- response: start, shorten, snooze, skip, not appropriate;
- duration bucket;
- generic suppression reason;
- crash/performance metrics.

### Prohibited analytics

- exact work timeline;
- raw active-use intervals;
- app names/bundle IDs;
- Calendar information;
- symptom values unless a separately consented research study;
- HealthKit data;
- camera or biometric data;
- unique behavioural fingerprinting;
- employer or productivity inference;
- advertising or data-broker sharing.

### Aggregation

Prefer:

- local aggregation before transmission;
- day/week buckets rather than exact timestamps;
- minimum sample thresholds for dashboards;
- short retention;
- no user-level exploration unless required for consented support.

## 9. Data retention

Proposed defaults:

| Data | Default retention |
|---|---:|
| Ephemeral input/activity signal | memory only |
| Raw terminal/companion candidate, losing/duplicate/rejected envelope | memory only; ≤90 seconds and until settlement/fence, whichever comes first |
| Sparse out-of-order action-counter window | memory only; ≤90 seconds; never persisted/exported; holes dispose without a received claim |
| Compact ActionID replay receipt without raw payload | memory only; ≤90 seconds and until verified acknowledgement-of-ack, whichever comes first; ACK/fence creation does not erase it |
| Sender crash-replay outbox | locally encrypted persistent Class 0; exact counter/ActionID/resend envelope/receiver/key binding; resend only in the same monotonic epoch with usable anchor and elapsed <90 seconds; erase after atomic move of a verified outcome into `outcome_ack_pending`, on epoch/anchor failure, or at `elapsed >= 90`; excluded from backup/history/export/logs/analytics |
| `outcome_ack_pending` | minimized locally encrypted Class 0 without action payload; exact signed outcome-ACK bytes/revision/expiry/token/binding plus receiver/key and local epoch/anchor; an ordinary rotation may retain only its referenced non-exportable old private-key Keychain handle through the same-epoch window; transmit or erase at `elapsed >= 90`, epoch mismatch, or re-pair, whichever comes first; excluded from backup/history/export/logs/analytics |
| Current coordination continuity and signed fence/high-water state | current state plus the immediately previous fence for at most 90 seconds; compact current generation/high-water persists until reset |
| Raw opportunity event | 30–90 days locally |
| Daily aggregate | 12 months locally |
| Settings/profile | until deletion |
| Optional symptom check-ins | 90 days locally |
| Analytics event | shortest practical period; document explicitly |
| Calendar content | never retained |
| Export files | user-controlled destination only |

Provide “keep only the last 30 days” and “do not keep history” options.

## 10. Export and deletion

Users need:

- export to human-readable CSV/JSON;
- clear description of every field;
- delete history without deleting settings;
- reset all data;
- disable analytics;
- disable and clear Calendar/app integrations;
- clear synced data if sync is later added;
- confirmation of what remains after deletion.

When D-033 coordination is implemented, the local data report must include current generation,
global revision, fence/high-water status, and paired public-key fingerprints in a human-readable
form. It must exclude raw candidate buffers, sender crash-replay outbox contents, actual public-key
bytes, and every private signing key. **Delete
history** keeps coordination continuity so a live timer is not made unsafe. **Reset app data** and
device unpairing delete the applicable coordination state, paired trust, and local private signing
key. The UI must disclose these boundaries before either action. This is a future v2 obligation,
not a claim about the current runtime/export.

Deletion must be tested, including backups, caches, crash logs, and queued analytics.

## 11. Consent design

Meaningful consent requires:

- purpose-specific requests;
- plain language;
- no bundled “accept all” for optional integrations;
- no dark patterns;
- refusal does not cripple unrelated core functionality;
- easy reversal;
- just-in-time explanation;
- separate consent for research participation.

Do not ask for Calendar or notifications on first launch unless the user just chose the dependent feature.

## 12. HealthKit and companion privacy

Future companion principles:

- request only the exact HealthKit types needed;
- explain read vs write separately;
- do not write fabricated workouts, calories, symptoms, or completion;
- sync minimal derived state to Mac;
- do not make Watch ownership a wellness advantage in scoring;
- absence/delay is unknown, not failure;
- provide local data deletion and revoke guidance;
- no server collection unless independently justified.
- “Any device” means only a paired device with a live exact-generation lease; offline, expired,
  fenced, or unacknowledged actions are rejected no-ops with immediate user feedback;
- raw candidate/duplicate/loser buffers follow the Class-0 90-second maximum above and are never
  retained as an audit trail;
- restart safety retains minimized Class-1 generation/fence/high-water continuity, actual paired
  and installation Ed25519 public keys required for verification, and derived display fingerprints;
  each Ed25519 private key remains local and non-exportable. Ordinary rotation may keep an old
  Keychain signing handle only for an already-bound Class-0 pending acknowledgement through its
  same-epoch 90-second window; it erases with that record, and reset/unpair erases it immediately;
- live/neutral-offline/offline-terminal-ack-unknown/expired/transfer-pending/terminal-action-pending/neutral-revalidating/revalidating-terminal-ack-unknown/rejected-no-op/already-ended/transfer-failed states
  remain usable without HealthKit, motion, location, camera, or another sensor.
- nonterminal-action-pending, offline-nonterminal-ack-unknown, and
  revalidating-nonterminal-ack-unknown preserve the selected Start action just as terminal unknown-
  acknowledgement states preserve their selected action; none silently resends it;
- every handoff names one selected receiver DeviceID and verification-key ID/epoch. Ordinary key
  rotation retains the prior public verification key and only a pending-record-bound non-exportable
  signing handle through the bounded live window. A new
  pairing fences the old peer immediately; its old command receives a visible rejected-no-op
  receipt and is never accepted under the new trust relationship.

## 13. Camera and posture sensing gate

Camera remains out of MVP. Before reconsideration, require:

- explicit product value that cannot be achieved less invasively;
- accuracy validation across skin tones, glasses, lighting, facial differences, mobility aids, body types, and camera positions;
- false-positive/negative impact analysis;
- local-only processing design;
- no raw storage;
- visible active-use indicator;
- easy pause and deletion;
- privacy impact assessment;
- biometric/privacy-law review;
- claims/regulatory review;
- user research showing value exceeds discomfort.

A camera feature cannot be justified merely because a competitor offers one.

## 14. Security controls

- sandbox and hardened runtime;
- code signing/notarization;
- encrypted platform storage where appropriate;
- least privilege;
- no advertising SDK;
- dependency inventory and update policy;
- signed/versioned content;
- secure export and temporary-file handling;
- privacy-preserving crash reporting;
- incident response plan before any cloud feature;
- vulnerability-reporting channel;
- no secrets in app bundle or analytics payload.

## 15. Region-focused privacy considerations

### Canada

PIPEDA principles emphasize accountability, identifying purposes, consent, limiting collection/use/disclosure/retention, safeguards, access, and openness [S059, S060]. Provincial laws may also apply.

### EU/EEA

Health data and inferred health data can be special-category data. Data protection by design/default, minimization, lawful basis, transparency, rights, and potentially a DPIA are central [S061, S062].

### UK

UK GDPR and ICO guidance similarly treat health data as special category [S061].

### California/US

California sensitive-personal-information rules and expanding state consumer-health laws may apply even when HIPAA does not [S063]. Do not imply “not HIPAA-covered” means unregulated.

Obtain current legal advice before launch; the product should be designed to exceed minimums through local processing.

## 16. Privacy acceptance criteria

- Core app works offline and without account.
- No invasive permissions in MVP.
- No keystroke/window/URL/screenshot collection.
- Calendar is reduced to ephemeral busy/free.
- App exclusions remain local.
- Subjective data is optional and deletable.
- Analytics is off or explicitly opted in.
- Export/delete is complete and tested.
- Public privacy copy matches actual code paths.
- SDK/network traffic is documented.
- No feature silently changes the data classification or intended purpose.
