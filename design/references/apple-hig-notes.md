# Apple platform references (paraphrased notes)

Consulted 2026-08-24 against the current Human Interface Guidelines. These are **paraphrased
takeaways plus links** — read the source pages before relying on a detail. Re-verify when
macOS ships a major release.

| Topic | Source |
|---|---|
| The menu bar & menu bar extras | https://developer.apple.com/design/human-interface-guidelines/the-menu-bar |
| Menus | https://developer.apple.com/design/human-interface-guidelines/menus |
| Materials (Liquid Glass + standard) | https://developer.apple.com/design/human-interface-guidelines/materials |
| Windows & panels | https://developer.apple.com/design/human-interface-guidelines/windows |
| Motion | https://developer.apple.com/design/human-interface-guidelines/motion |
| Notifications | https://developer.apple.com/design/human-interface-guidelines/notifications |
| Accessibility | https://developer.apple.com/design/human-interface-guidelines/accessibility |
| Privacy | https://developer.apple.com/design/human-interface-guidelines/privacy |
| Onboarding | https://developer.apple.com/design/human-interface-guidelines/onboarding |
| Feedback | https://developer.apple.com/design/human-interface-guidelines/feedback |

Tip for future sessions: the HIG site is a JavaScript app, so plain fetches return an empty
shell. The underlying content is available as JSON at
`https://developer.apple.com/tutorials/data/design/human-interface-guidelines/<page>.json`.

## Menu bar and menu bar extras — what this means for us

- The menu bar is 24 pt tall. A menu bar extra is represented by a template-style symbol
  (black + clear) so the system can recolor it for light, dark, and selected states. That
  constrains our ambient status design: **it must read as a monochrome glyph**, not as a
  colored badge. See `design/DECISIONS.md` D-004.
- Apple's stated preference is a **menu**, not a popover, on click — a popover is for
  functionality too complex for a menu. Our status surface is close to the boundary, which is
  a real decision to make and defend rather than assume. See D-003.
- The system hides and reorders menu bar extras freely; position is not guaranteed and the
  item may be hidden entirely when space is tight. So the extra can never be the *only* route
  to anything, and animation that depends on its position is a bad idea.
- Apple suggests also exposing functionality through a Dock menu, since a Dock menu is always
  available while the app runs. Worth considering for Pause / Start break.
- Whether the extra appears at all should be the user's choice, typically a setting, though
  offering it during setup helps discoverability.

## Materials — Liquid Glass vs standard materials

Current Apple platforms have two material families, and mixing them up is a visible mistake:

- **Liquid Glass** is the *functional* layer — controls and navigation that float above
  content. Apple is explicit that it should be used **sparingly** on custom controls, and
  that it does **not** belong in the content layer (app backgrounds).
- **Standard materials** handle differentiation *within* the content layer, and vary by
  thickness according to how much of the backdrop should show through.
- Two Liquid Glass variants exist: a *regular* one that adapts luminosity for legibility
  (correct for text-heavy surfaces — popovers, alerts, sidebars) and a *clear* one for
  floating over visually rich media.
- For the clear variant over bright content, Apple suggests a dimming layer around 35%
  opacity. **This is directly relevant to our break overlay over an arbitrary desktop** — it
  gives us a sanctioned, system-consistent basis for softening the work surface rather than
  inventing an opacity. See D-005.
- Material appearance changes under Reduce Transparency and Increase Contrast. Any design
  that depends on translucency for legibility fails those settings; test both.

## Motion

Apple's own guidance lines up with the research package almost exactly:

- Motion must be purposeful; gratuitous animation distracts and can cause physical discomfort.
- Motion must never be the only carrier of information — provide an alternative.
- **Avoid animation on frequently repeated interactions.** For a break app that appears dozens
  of times a day, this is the governing sentence.
- Brief and precise beats prominent.
- People should be able to cancel or skip past motion rather than wait it out — especially if
  they'll see it more than once.

## Notifications

- One notification per thing. Explicitly do **not** re-notify because the user hasn't
  responded — which independently confirms our no-escalation rule `[03 §11]`.
- Notifications shouldn't instruct people to go do a task inside the app; offer notification
  actions instead. Our heads-up therefore needs its actions (Start now / In 5 minutes /
  More options) on the notification itself.
- Errors belong in an alert, not a notification.
- Nothing sensitive in a notification — it may be read by anyone near the screen. Relevant to
  the phrasing of movement and symptom-adjacent copy.
- The research package separately forbids requesting Time Sensitive or Critical levels `[S072]`.

## Windows and panels

- A macOS panel floats above other windows and supplies supplementary controls — the natural
  class for our break surface and heads-up, rather than a document window.
- Full-screen mode hides the menu bar, so any function reachable only via the menu bar extra
  becomes unreachable for a full-screen user. Our break surfaces must not assume the menu bar
  is visible.

## Still to verify in a later pass

- Current Reduce Motion / Reduce Transparency behavior for the specific materials we pick.
- Focus Filter (App Intents) configuration UI conventions.
- `SMAppService` launch-at-login prompt wording and where the user reverses it.
- Notification Center appearance of an actionable local notification on the current release.
