---
read_when: building macOS chrome/overlay UI, toolbar/sheet styling, anything the user calls "glass"
verified: 2026-06-17, Xcode 26.5 / macOS 26 SDK
---

# Liquid Glass on macOS

Liquid Glass is system chrome vocabulary: translucent, refractive surfaces for
toolbars, floating controls, sheets, and overlays. Most standard macOS SwiftUI
chrome adopts current system styling automatically when built with the macOS 26
SDK, so the default move is to use native components first.

## The shape of it

- Prefer standard `WindowGroup`, toolbars, sheets, popovers, sidebars, and
  settings before custom glass.
- Custom floating elements use the platform glass modifiers/styles available in
  the current SDK; route shape/tint choices through DesignSystem tokens.
- Multiple custom glass elements that need shared visual behavior should live in
  a small wrapper/component, not ad hoc per screen.

## Rules here

- Do not put glass on content cards, rows, or text containers by default. Content
  surfaces remain `dsSurface`; glass is for chrome floating above content.
- A new glass tint, radius, or motion feel is a design decision. Ask first, then
  add a DS token/component and a `DSGallery` preview.
- Glass is environment-dependent. Snapshot tests need stable backgrounds; final
  judgment for glass-heavy polish should include `scripts/shot.sh` or
  `scripts/capture-matrix.sh`.

## Sharp edges

- Do not fall back to old `.ultraThinMaterial` habits unless the API surface you
  are using actually requires material. Glass and material are not synonyms.
- Spacing changes can affect how adjacent glass elements merge or visually read.
- AppKit interop should be narrow and explicit; use SwiftUI scene/chrome APIs
  first.
