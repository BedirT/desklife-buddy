# Design System — Horizon

**Status: first consolidated draft (2026-08-25), extracted from `explorations/round-2/`.**
Values are authoritative for implementing the Horizon direction; they graduate to
`canonical` when the 2x renders in `renders/` exist. Sizes are points at 1x unless noted.
Sources: the round-2 artboards (every value below appears there), D-012–D-029, and the
platform rules in `.claude/rules/macos-design.md`.

The organizing idea (D-013): **a break is a place, not a dialog.** Sky holds the
instruction, ground holds the controls, the horizon between them is the progress
indicator. Everything below serves that.

---

## 1. Typography

SF Pro (system), with `ui-serif` (New York) *only* for the single emphasized word of a
break instruction. No SF Mono; tabular figures cover every counting need.

| Token | Size / weight / tracking | System-style mapping | Used for |
|---|---|---|---|
| `display` | 58–62 / 590 / −0.024em | none — deliberate display type | Break instruction. The one large-type surface (macos-design §5). 62 for short lines (visual), 58 for longer (movement) |
| `display.em` | inherits, New York italic 500 / −0.012em | — | One emphasized word per instruction, never more |
| `count` | 27 / 500 / +0.02em, tabular | — | Break countdown |
| `guide` | 18–19 / 400 / 1.5 lh | Title 3 (scaled) | The one optional sentence under the instruction |
| `control` | 15 / 500 | Body (emphasized) | Pill buttons |
| `body` | 13 / 400–590 | Body | Menu items, labels, menu-bar text, status line. (13.5 appears in the round-2 menu; consolidate to 13 at render time) |
| `meta` | 12.5 / 400–500 / 1.5 lh | Footnote | Secondary values, safety footer, capsule text, position-change line |
| `caption` | 11–11.5 / 500 / +0.04em | Caption 1 | Keycap chips, capsule buttons |
| `eyebrow` | 13 / 500 / +0.16em, uppercase | — | Surface name above the instruction ("Visual reset") |

Rules: no size outside this table; weights only 400 / 500 / 590 / 600; anything that
changes in place uses `font-variant-numeric: tabular-nums`; sentence case everywhere
except platform-conventional title case (menu titles, window titles); body copy never
below 11 (design-quality §5).

Text scaling: all sizes track the system text-size setting proportionally; layouts must
tolerate +35% without clipping — per-screen behavior is stated in each screen's
accessibility annotation block.

## 2. Color

Two atmospheres of one landscape (D-014): **dusk** (visual reset — far, cool, vast) and
**late-golden** (movement — near, warm, energetic). Recognition of break type comes from
color temperature at a peripheral glance, never from reading.

### Fields (dark appearance)

| Role | Value | Where |
|---|---|---|
| Dusk sky ramp | `linear-gradient(178deg, #08091b, #14132e 40%, #33203c 72%, #55303f)` + warm sun-bloom radials | Visual-reset sky; CSS fallback under the `sky-dusk` render |
| Golden sky ramp | as shipped in `Movement.dc.html` (`sky-warm` render, graded `hue-rotate(14deg) saturate(0.84) brightness(0.97)`) | Movement sky |
| Ground (dusk) | `linear-gradient(180deg, #241a30, #120f24 54%, #0a0a19)` + horizon-glow radial | Below the horizon |
| Ground (golden) | warmer variant, same structure | Below the horizon |
| Grain | 5% fractal-noise overlay, `mix-blend-mode: overlay` | Every field; kills banding |

### Ink (on dark fields)

White at fixed opacities — never freestanding grays: **0.90–0.94** primary ·
**0.62–0.78** secondary · **0.52–0.58** tertiary (short, non-essential strings over the
*darkest* ground only, verified per render) · **0.28–0.36 is a non-text tier** — hairlines,
tracks, borders, separators; no string may use it (D-028; the 2026-08-25 audit measured the
old quaternary strings at ≈2.6:1). Anything textual that crosses the bright sky band gets a
scrim or a soft dark text-shadow — legibility is checked against the brightest pixels the
string crosses, not the average field.
Countdown ink is warm: `rgba(255,238,216,0.92)` with a soft warm glow shadow.

### Accents

| Token | Value | Meaning |
|---|---|---|
| `sun` | radial `#fff6e0 → #ffd9a0 → #ff9e62` | The character, the countdown glow, the primary-pill tint |
| `horizon` | track `rgba(255,255,255,0.28)` with a faint dark under-edge; fill to `rgba(255,226,196,1)` + warm outer glow; Increase Contrast raises the track a tier | Progress. The only "chart" on a break surface — the whole extent must be visible, not just the fill (D-028) |
| `visualBar` | `#ffc98f` ramp | Visual clock bar in the status menu |
| `movementBar` | `#ff9ec0` ramp | Movement clock bar in the status menu |
| `tiles` | `#ffc074→#f0743f` · `#ff9ec0→#e0487e` · `#b39bff→#6f4fd8` | The three movement-choice glyph tiles only |

**Red is reserved** for genuine errors and safety content. Never for a skipped break,
never for state (macos-design §6). Every state also carries a label, shape, or position
difference — each screen must read in grayscale (accessibility rule §2).

### Light appearance (canonical, not derived)

Dawn field `linear-gradient(178deg, #dbe1f6, #e7e5f2 42%, #f5e4e2 74%, #fde9d8)`; ink
is near-black plum (`#3a2438` ramp); pills are the same equal-weight glass anatomy with
plum ink and `rgba(58,36,56,0.14)` borders — there is no filled primary in either
appearance (D-027). Reference: `VisualLight.dc.html`. Still owed: light menu/settings,
light golden field, MovementLight render (logged in `OPEN_QUESTIONS.md`).

### System-color mapping

Break surfaces and the capsule use the palette above deliberately — they are a *place*,
and the sun ramp is the product accent (a custom palette with its mapping stated, per
macos-design §6). Settings, the weekly window, and menus use **semantic system colors**
(`labelColor`, `secondaryLabelColor`, `separatorColor`, the user's accent for selection)
so they track appearance, accent, and contrast settings natively. The warm menu highlight
in the artboards is a *stand-in for the user's accent* ("the user chose orange"), darkened
to `rgba(179,81,42,0.95)` so white item text measures ≈5:1 — shipped menus use the system
accent selection, which the system keeps legible (D-028). DQ-12 (brand color)
remains open; the sun ramp is the interim answer and renaming-safe.

## 3. Space and layout

Base unit 4. Working rhythm: **8 · 12 · 16 · 22 · 44**. Optical alignment beats the grid
where they disagree (design-quality §2) — the artboards are the reference.

Three layout problems, solved separately:

- **Break surface (1440×900 reference).** Horizon at 560 (visual) / 640 (movement) —
  the golden field sits lower because its sun is nearer. Sky content centered, measure
  ≤ 1000–1100. Ground stack, fixed order on every break surface, every time
  (design-quality §3 — same actions, same positions, always): countdown → status line
  → exit pills → tertiary action → safety/footnote line.
- **Status menu.** 300 wide; status region (two labeled clock rows with 2px bars +
  estimate line), separator `rgba(255,255,255,0.10)`, standard 24-high items.
- **Capsule.** 34 high, pill; 24 tiny-sky disc + text; on hover, two 24-high buttons.

## 4. Materials

| Surface | Material | Reduce Transparency fallback | Increase Contrast |
|---|---|---|---|
| Exit pills / choice chips | glass `rgba(255,255,255,0.07–0.13)` + `blur(24–26) saturate(1.5–1.6)` + 1px `rgba(255,255,255,0.13)` border + inset top highlight; **chips over a bright sky band add a dark scrim layer `rgba(24,10,22,0.45)` under the glass** so titles hold 4.5:1 (D-028) | solid `rgba(32,24,42,0.96)` (dusk) / `rgba(42,18,28,0.96)` (golden), borders kept | border → `rgba(255,255,255,0.42)`; ink one tier up; 3px focus ring |
| Capsule | near-solid `rgba(18,14,30,0.88)` + blur 24 | fully solid `#120e1e` | border `rgba(255,255,255,0.40)` |
| Menu bar over a break | `rgba(16,14,30,0.60)` + blur 30 — the bar stays visible and lit (D-012) | solid `rgba(16,14,30,0.94)` | system-owned |
| Menus / Settings / weekly | system materials | system-owned | system-owned |
| Break field | **content layer**: image/gradient, never glass (macos-design §4) | opaque already | dimming raised until ink reaches 7:1 |

Legibility must never depend on the blur, and every fallback is verified against its
worst-case backdrop (the light golden field is the hardest). The default break surface has
**no dimming layer — it is a full opaque field (D-021, D-026)**; the platform's ~35% dimming
anchor applies only to the static/migraine presentation (BR-04), where the level is
user-adjustable.

## 5. Elevation and edges

A break surface has **no window chrome, no card, no shadowed panel** — it is a field;
only floating controls (pills, chips, capsule) carry elevation: inset top highlight +
`0 10–14px 28–44px rgba(0,0,0,0.30–0.50)`. Radii tokens: `r-key 5` · `r-item 6` ·
`r-panel 12` · `r-tile 12–13` · `r-card 16` · `r-pill 999`. The overlay must never read
as a lock screen: menu bar visible, clock visible, exits visible (macos-design §3).

## 6. Motion

The closed ten-moment vocabulary is specified in `INTERACTION_SPEC.md` §5 (D-025).
System-level rules: nothing loops, everything is one-shot and eased, every motion has a
stated Reduce Motion equivalent, and **a motion not in that table does not exist**.

## 7. Iconography

- Menu-bar glyph: monochrome template symbol, 24pt bar, no badge, no live countdown
  (D-004).
- In-app: SF Symbols wherever one exists; custom 2px round-cap stroke glyphs only for
  the three movement choices, always inside their gradient tiles (38×38, `r-tile`).
- The sun character appears **only** in the capsule and identity surfaces — never on a
  break surface, where the instruction is to look away (D-020a).
- Banned iconography per design-quality §5 (leaves, rings, flames, shields, gauges…).

## 8. Components

Only things that recur:

| Component | States specified |
|---|---|
| **Pill button** | rest `bg 0.08` · hover `bg 0.12` · focus: 2px ring `rgba(255,214,178,0.9)`, 2px offset (light: `#3a2438` ring) · pressed `bg 0.16`, no scale · disabled ink 0.35. A keycap chip is part of the anatomy on interrupting surfaces (accessibility rule §2: visible keyboard affordances). Break-surface exits are always this equal-weight glass anatomy — no filled primary variant exists (D-027) |
| **Choice chip** (movement) | as pill, plus selected: `bg 0.13` + warm border + 1px outer warm ring; selection is also carried by the bound guidance sentence and announced — never color-only |
| **Keycap chip** | 20 high, `r-key`, `caption` type, `bg 0.14` (`0.10` border) |
| **Notch capsule** | approach (sun high) · countdown (sun sinking, x = pointer station) · hover (exit buttons revealed) · hold (dashed ring + honest reason) · no-notch dock variant (under the clock) · notifications-preferred variant (first-class, not fallback) |
| **Horizon progress** | track `rgba(255,255,255,0.28)` + faint dark under-edge, fill grows left→right once over the break; RM: stepped fills — legible only because the track is visible (D-028). Never a ring, never a percentage |
| **Countdown** | `count` type, tabular, digits change in place with no per-digit animation (D-025) |
| **Status region** | two labeled 2px bars + the estimate line. Full form is "estimated active computer use" `[C033]`; the menu's compressed form "Estimated active use today" is a registered variant (CP-ST11) — compression may drop "computer", never *estimated* |
| **Safety footer** | fixed string `[04 §2]`, `meta` type, one line at ≤1160 measure, contrast-checked at its tier |

## 9. Density and sizing

Native desktop density: 24-high menu rows; 44-high pills and 64-high choice chips on
break surfaces (interrupted users click with less precision — generous tier); dense tier
for browsing surfaces (menu, weekly, settings). Hit targets ≥ 24×24 everywhere,
≥ 44 high on break surfaces. Reference artboards are 1x; renders ship at 2x.
