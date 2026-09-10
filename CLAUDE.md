# CLAUDE.md — Cadence (working name)

## 1. What this repository is

This is the **combined design and implementation repository** for a native macOS
desk-wellness utility. It contains the authoritative health research package, product design
(documents plus visual artifacts), a focused macOS development harness, and the production app
workspace. The owner explicitly chose this combined boundary on 2026-08-25; do not split or
duplicate the design package into a second app repository without a new owner decision.

Working name: **Cadence** — a placeholder. See `design/DECISIONS.md` D-001. Never hard-code
the name into a design in a way that makes renaming expensive.

Implementation starts at `design/HANDOFF.md`, then follows `design/AUTHORITY.md` and the
exact implementation inventory in `design/CURRENT_STATE_CONFORMANCE.md`. The current `App`
is product implementation. `Item`, `ItemStore`, `ItemList`, and their persistence seam remain
template examples only and must not be mistaken for product architecture. Keep the target,
scheme, module, display name, and bundle identifier neutral until the owner settles product
identity. The harness bootstrap plan is complete; retained verification must still be green at
the exact head being reviewed.

## 2. Product in one paragraph

The implemented baseline is a private, native macOS menu-bar utility that helps an adult computer user
interrupt long runs of **estimated active computer use** with short visual resets and real
movement opportunities. It keeps two independent clocks (visual and movement), offers each
break as a dismissible invitation rather than an enforced lockout, adapts its timing to
context it can honestly observe, treats seated and limited-mobility movement as equal-status,
runs locally with no account and no required invasive permissions, and reflects the week back
to the user as a pattern rather than a score. It is a **general wellness product, not a
medical product**.

Most defensible promise: *a private, research-informed way to remember visual and movement
breaks without fighting your workflow.*

## 3. Platform

Native macOS is implemented first: a menu-bar utility with overlay break surfaces, a settings
window, and a weekly view. The owner-approved Calm Ensemble intake explores iPhone and Apple
Watch companions, but it remains non-canonical until the owning product, privacy, claims,
machine, and platform contracts are promoted explicitly. No companion assumption may silently
change the current Mac behavior.

## 4. Positioning

| It is | It is not |
|---|---|
| A movement-and-recovery assistant | A posture monitor |
| A calm interrupter | A productivity tracker |
| Locally private by construction | A health dashboard |
| Honest about uncertainty | A medical or diagnostic product |
| Accessible by default | An employer-compliance tool |

Category reference is LookAway / Time Out / Stretchly / BreakTimer. **Do not clone them.**
The differentiation is honesty, calm, accessibility parity, and native craft — see
`research/health/09_COMPETITOR_AND_PATTERN_AUDIT.md` §8.

## 5. Research: location and authority

All health/product research lives in **`research/health/`** and is **immutable**
(checked in read-only). `research/INDEX.md` is the navigable index and the file-by-file map.

Authority order (higher wins on conflict):

1. `03_PRODUCT_HEALTH_PROTOCOL_SPEC.md`
2. `08_CLAIMS_SAFETY_REGULATORY_REGISTER.md`
3. `07_PRIVACY_AND_DATA_SPEC.md`
4. `05_DESIGNER_AGENT_BRIEF.md`
5. `01_EXECUTIVE_PRODUCT_DECISIONS.md`
6. `02_MASTER_HEALTH_EVIDENCE_REVIEW.md`
7. `machine-readable/*`
8. Supporting documents

Rules:

- Where the package is genuinely uncertain, choose the **more conservative** option for
  health claims, safety, accessibility, privacy, and autonomy.
- **Never silently resolve a meaningful contradiction in the research.** Log it in
  `design/OPEN_QUESTIONS.md` with both readings and the interim choice.
- Preserve research identifiers (`[S###]`, `[C###]`, `[OQ-##]`, card IDs like `[L01]`)
  in any evidence-sensitive decision, so a reviewer can verify it.
- Do not treat source *quantity* as authority. The package's stated conclusions govern.
- `design/AUTHORITY.md` defines concern-specific precedence between research, accepted product
  decisions, machine values, code, and verification. Its rules preserve this research order.

## 6. Scientific semantics that may not be distorted

These are product truths, not stylistic preferences. Any design that breaks one is wrong
regardless of how good it looks.

- **Keyboard/mouse activity estimates active computer interaction only.** It does not prove
  sitting, gaze, posture, productivity, exercise, eye strain, or attention. Always call it
  *estimated active computer use* `[C033]`. Never "you have been sitting for 60 minutes" `[C013]`.
- **Idle proves nothing.** Long idle may reset presentation timing (`likelyNaturalInterruption`)
  but never records movement `[03 §7.3]`.
- **Visual timing uses available screen-session eligibility, not gaze.** An awake, active Mac
  may advance the visual clock through short no-input periods so passive reading is not excluded.
  This does not prove a person is present, looking at the display, or experiencing strain.
- **A finished timer is not a health outcome.** Never "movement verified" `[C034]` or
  "eye strain reduced" `[C036]`.
- **Visual and movement are separate clocks.** A visual reset never completes movement.
- **Position change ≠ movement.** Standing is a *position change*, logged separately, and
  never silently completes the movement clock `[01 §3.3]`.
- **20-20-20 is a memorable heuristic, not a proven clinical optimum** `[S014]`. Product
  default is a visual reset in a 20–30 min window, target ≈25 min, ≈20 s duration.
- **Movement default** is ≈5 minutes of easy walking or equivalent around ≈60 min, with a
  legitimate 2-minute quick option `[03 §4.2]`.
- **There is no universal correct posture.** No posture score, no red slouch indicator, no
  skeleton/angle overlay, no shame. Favor fit, variation, comfort `[C020–C023]`.
- **No blue-light fear.** No retinal-damage narrative, no "protection" score, no shield
  iconography `[C008, C009]`.

Canonical timings live in `research/health/machine-readable/product_protocol.yaml`. Read the
YAML before writing any number into a design.

## 7. Privacy principles

The core experience must work with **no account, no camera, no microphone, no Screen
Recording, no Accessibility permission, no Calendar, no cloud sync, and no network**.

- Never design UI that collects or displays keystrokes, pointer paths, window titles, URLs,
  file names, screenshots, or Calendar event content `[07 §3]`.
- Optional integrations (Notifications, Calendar busy/free, Focus Filter, launch at login)
  are requested **at the moment of value**, never during first launch, never bundled.
- Refusing a permission must never degrade unrelated functionality, and the UI must say so.
- Calendar becomes ephemeral busy/free intervals in memory; content is discarded `[07 §5]`.
- Analytics is off by default and opt-in only.
- Privacy copy must describe what the code actually does — never aspirational reassurance.

## 8. Accessibility principles

Accessibility is part of the visual design, not a QA pass.

- Full keyboard operation; predictable focus order; **Escape always dismisses**, everywhere.
- VoiceOver names, values, and status for every control, timer, and state change.
- Reduce Motion honored automatically, with a genuine static equivalent for anything animated.
- Increase Contrast honored; **never color-only meaning**; text scaling without clipping.
- Migraine/photosensitivity safe: no pulsing, flashing, shimmer, rapid zoom, parallax,
  confetti, or continuously animated countdown.
- Seated / wheelchair / limited-mobility movement paths are **equal-status**: same visual
  weight, same semantic dignity, never a "fallback" in layout, order, or wording `[C047, C048]`.
- Sound is never required. No drag-only interactions. Multi-display overlays must never put
  a needed control out of reach.

## 9. Core interaction principles

**Calm interruption.** A break is an invitation. No lockout, no punishment, no shame `[01 §4]`.

**Autonomy.** Every break is immediately dismissible; Escape always works; the user can pause
indefinitely.

**Progressive interruption** — five levels, deliberately unequal in loudness:

| Level | Surface | Loudness |
|---|---|---|
| 0 | Menu-bar ambient status | Nearly silent |
| 1 | Heads-up notice (30–60 s before) | Quiet, corner |
| 2 | Break overlay | Prominent but graceful |
| 3 | Optional acknowledgement | Featherweight, skippable |
| 4 | Weekly rhythm | Deliberate, user-initiated |

**Honest intelligence.** The app may be context-aware, but must never imply it perceives more
than it does. "Smart" language that suggests sensing is a defect.

**Low cognitive load at Level 2.** The break screen appears while someone is already mentally
occupied. One instruction, one timer, obvious exits. No dashboard.

**No escalation.** Repeated deferral within a session must not make the app louder. A gentle
schedule suggestion *later* is the only permitted response `[03 §11]`.

## 10. Design personality

Calm · confident · polished · contemporary · unmistakably desktop-native · warm · private ·
precise · quiet · intentional.

Never: hospital-like · fitness-gamified · corporate-wellness mandated · childish ·
productivity-obsessed · spiritual-wellness cliché · cyberpunk · "AI-generated" · generic
Tailwind dashboard · a phone app blown up to 1440 px.

## 11. Prohibited patterns

**Product:** lockouts · streaks · health scores · posture scores · disease-risk framing ·
blue-light protection framing · camera/blink/gaze/posture sensing · employer dashboards ·
hydration quotas · required accounts · escalating nagging · engagement optimization ·
AI-generated exercise content · celebrating standing as if it were movement.

**Visual:** leaves · lotus · hearts · medical crosses · skeletons · posture silhouettes ·
"perfectly seated person" illustrations · giant activity rings · streak flames · shield icons ·
glowing blue-light eyes · fake health gauges · confetti on compliance · red for a skipped break ·
pulsing countdowns · cards used merely because cards are easy.

**Copy:** bad posture · perfect posture · failed · compliant/noncompliant · risk increasing ·
undo sitting damage · prevent eye damage · burn calories · fix your back · protect your eyes
from blue light · sitting detected · movement verified. Full list: `08 §12`.

## 12. Where the design lives

| Concern | File |
|---|---|
| Research index and authority map | `research/INDEX.md` |
| Cross-artifact product authority and traceability | `design/AUTHORITY.md` |
| Exact implemented baseline and collision map | `design/CURRENT_STATE_CONFORMANCE.md` |
| Product model / state model | `design/PRODUCT_MODEL.md` |
| Information architecture | `design/INFORMATION_ARCHITECTURE.md` |
| Screen + state inventory (**check before adding a screen**) | `design/SCREEN_INVENTORY.md` |
| User flows | `design/USER_FLOWS.md` |
| **Design system** (tokens, type, color, components) | `design/DESIGN_SYSTEM.md` |
| Interaction + motion specification | `design/INTERACTION_SPEC.md` |
| Copy source of truth | `design/COPY_INVENTORY.md` |
| Accessibility specification | `design/ACCESSIBILITY.md` |
| **Design decision log** | `design/DECISIONS.md` |
| Open questions / unresolved | `design/OPEN_QUESTIONS.md` |
| Developer handoff | `design/HANDOFF.md` |
| Visual exploration (non-canonical) | `design/explorations/` |
| Canonical rendered screens | `design/renders/` |
| Interactive prototypes | `design/prototypes/` |
| External references and platform notes | `design/references/` |

`design/README.md` explains the workspace and the current phase.

## 13. Design workflow

1. **Ground.** Read `research/INDEX.md` and the relevant canonical research section. Read
   `design/DECISIONS.md` before revisiting anything that looks like a settled choice.
2. **Locate.** Check `design/SCREEN_INVENTORY.md`. Extend an existing screen/state rather
   than inventing a parallel one.
3. **Design.** Work at real macOS density and real pixel sizes. Light and dark together, not
   dark as an afterthought.
4. **Annotate.** Every screen gets the accessibility annotation block defined in
   `design/ACCESSIBILITY.md` §2 — keyboard path, initial focus, focus order, Escape, VoiceOver
   names/values, text scaling, high contrast, reduced motion, meaning-without-color,
   alternative movement path, multi-display behavior.
5. **Register copy.** Add every new user-facing string to `design/COPY_INVENTORY.md` with a
   claim classification.
6. **Review.** Run the three review skills below. Fix findings before calling anything done.
7. **Log.** Record material decisions in `design/DECISIONS.md`; record what you could not
   resolve in `design/OPEN_QUESTIONS.md`.

## 14. Review requirements

Nothing is "done" until it has passed all three, and the findings are fixed or logged:

- `.claude/skills/design-review/` — hierarchy, clarity, interaction cost, nativeness, tone,
  repetition fatigue, unnecessary UI, visual consistency.
- `.claude/skills/claims-review/` — every health-adjacent string against
  `research/health/machine-readable/claims_register.csv`.
- `.claude/skills/accessibility-review/` — keyboard, VoiceOver, focus order, contrast,
  scaling, reduced motion, alternative paths.

Subagents in `.claude/agents/` (Design Critic, Claims Auditor, Accessibility Auditor) may run
these adversarially. **The principal designer owns final synthesis** — do not let three
subagents produce three disconnected visions and call it design.

The research package also defines its own gate: `05_DESIGNER_AGENT_BRIEF.md` §11. A screen is
not approved until every question there answers yes.

## 15. Standing rules for any session

- Do not start drawing screens before reading the research sections that govern them.
- Prefer extending the design system to inventing a new component.
- Optimize the break experience for its **500th appearance**, not its first.
- Every visual element must earn its place. Delete before decorating.
- Reversible and unspecified → choose a sensible default, label the assumption, log it, keep
  moving. Only stop and ask when a decision is irreversible, strategically defining,
  safety-sensitive, contradicts the research, or would waste substantial work if wrong.
- Record meaningful external platform references (Apple HIG etc.) in `design/references/`.

## 16. Implementation harness

`AGENTS.md` is the implementation operating manual. The accepted research and
design package is the completed product context; do not repeat reversible
preference gates. Use the direct commands in `scripts/` and climb only as far as
the change needs: focused logic tests, snapshots for view changes, and real-app
launch/accessibility proof for changed flows. `scripts/verify.sh` is the full
retained repository check.

Shared skills live in `.agents/skills/` and are projected to Claude Code through
`.claude/skills`; per-module conventions live in `Packages/*/AGENTS.md`.
