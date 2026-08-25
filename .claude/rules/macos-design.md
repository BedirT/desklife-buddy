# Rule: macOS design

Target: a native macOS utility that a Mac user would call *well made*. Platform notes and
links: `design/references/apple-hig-notes.md`. Engineering constraints that bound design:
`research/health/06_DEVELOPER_AGENT_BRIEF_MACOS.md`.

## 1. App shape

A menu-bar utility with **no Dock presence by default** and no main window. Surfaces are:

| Surface | Type | Notes |
|---|---|---|
| Menu-bar item | Status item, 24 pt bar, template symbol | Monochrome glyph; system recolors it |
| Status surface | Menu-first (see §2) | Two clocks, quick actions |
| Heads-up | Local notification, or in-app panel if notifications are denied | Never Time Sensitive/Critical |
| Break surface | Borderless floating panel per display | Not a window, not a sheet |
| Settings | Standard settings window, `⌘,` | Tabbed/sidebar per platform convention |
| Weekly rhythm | Ordinary window, user-initiated | Not a "dashboard" |
| Onboarding | Single window, sequential | No permissions requested |

Also consider a Dock menu for Pause / Start break: the menu bar extra can be hidden by the
system or by the user, so it must never be the only path to anything.

## 2. Menu vs popover

Apple's guidance prefers a **menu** on click, reserving a popover for functionality genuinely
too complex for a menu. Our status surface is right at that boundary because it must show two
independent clocks plus state.

**Default position:** a menu-shaped surface with a compact custom status region at the top,
then standard menu items. Do not reach for a full popover "mini-app" — that is the generic
choice, not the native one. If a direction argues for a popover, it must argue against this
rule explicitly and log the decision.

Menu content, in order: status region (visual clock, movement clock, current state) ·
Start visual reset · Start movement · Pause ▸ · Working hours toggle · Weekly rhythm… ·
Settings… · Quit.

## 3. Windows, panels, and the break surface

- The break surface is a borderless, non-activating-where-possible floating panel, one per
  target display, coordinated as **one experience** — not N independent modals.
- It must never imitate a system lock screen, never use screen-saver-level window ordering,
  and never obscure or block system security dialogs or emergency controls.
- It must never hide its exit. Escape, an explicit control, and a visible shortcut hint are
  all present, always.
- The user chooses primary-display-only or all-displays. Controls must be reachable in every
  configuration, including mirrored and 3-display setups.
- Display disconnect, display sleep, Spaces switch, Stage Manager, full-screen apps, and
  screen sharing must not strand a panel or lose the exit.
- Full-screen apps hide the menu bar. Never assume the menu-bar item is visible.

## 4. Materials

- Use **Liquid Glass sparingly**, and only for the functional layer — floating controls and
  navigation. Never as a content-layer background.
- Use **standard materials** for content-layer surfaces, choosing thickness by how much
  backdrop should show through.
- Prefer the *regular* Liquid Glass variant anywhere there is significant text.
- Over a bright, arbitrary desktop the guidance suggests a dimming layer around 35% opacity;
  use that as the anchor for the break overlay's softening of the work surface rather than an
  invented number.
- **Every material decision needs a Reduce Transparency and an Increase Contrast answer.**
  If legibility depends on the blur, the design is broken for those users.
- Do not fake Apple materials with a flat translucent gray in specs. Name the intended
  material and the fallback.

## 5. Typography

- SF Pro (text/display, optical sizes) and SF Mono where a monospace figure genuinely helps.
  Use system text styles, not arbitrary point sizes, so scaling behaves.
- Native desktop density: controls and body copy at Mac sizes, not iOS sizes.
- The break instruction is the one place large display type is justified. Everywhere else,
  restraint.
- Use tabular figures for anything that counts down or changes in place, so numbers don't
  jitter.
- Sentence case for controls and labels; title case only where the platform uses it (menu
  titles, window titles).

## 6. Color and appearance

- Light and dark are designed together, not derived. Both are canonical.
- Prefer semantic system colors so the app tracks accent color, appearance, and contrast
  settings; a custom palette must state its system-color mapping.
- Reserve high-severity color for genuine errors and safety content only. **Never red for a
  skipped break.** Never color as the sole carrier of state.
- Respect the user's accent color where the platform would.

## 7. Motion

Apple's own guidance is the strictest constraint we have here: avoid animation on frequently
repeated interactions, keep it brief and precise, never make it the only signal, and let
people move past it rather than wait.

Because this app appears many times a day:

- Appearance/dismissal transitions are short (≈200–300 ms), single-shot, and eased.
- No looping animation for the duration of a break. No pulsing countdown. No animated
  background.
- Every transition has a Reduce Motion equivalent that is a crossfade or an instant change,
  and the design says which.
- A user must never have to wait out an animation to dismiss a break.

## 8. Keyboard, focus, and Escape

- **Escape dismisses, everywhere, immediately.** Also support ⌘. where the platform would.
- ⌘, opens Settings. Standard menu shortcuts behave normally.
- Full keyboard operability with a visible, contrast-passing focus ring in both appearances.
- Initial focus on a break surface goes to the least destructive primary action, and is stated
  per screen.
- Restore focus to the previously active app when a break surface closes; do not steal
  keyboard input unpredictably while it is open.
- Custom shortcuts only where warranted, and never one that shadows a standard system binding.

## 9. Permissions and system integration

- Notifications, Calendar (EventKit), Focus Filter, and launch at login (`SMAppService`) are
  **all optional**, all requested at the moment of value, and each has a designed
  denied/revoked state.
- Camera, microphone, Screen Recording, and the Accessibility permission are **out of scope**.
  No design may imply a capability that would require them.
- No private APIs, so no design may depend on reading other apps' window titles, contents, or
  global Focus state.

## 10. System settings to honor

Reduce Motion · Reduce Transparency · Increase Contrast · Differentiate Without Color ·
Display appearance (light/dark/auto) · accent color · text size · display scaling ·
multiple displays · Spaces · Stage Manager · Focus.

Each of these needs a stated behavior in `design/INTERACTION_SPEC.md`, not an assumption.

## 11. Smell test

If a screen could be dropped into a web app unchanged, it is not native enough. If it looks
like an iOS sheet scaled up, it is wrong. If it uses a card because a card was easy, delete
the card.
