---
read_when: building AppKit break panels, multi-display overlays, Spaces behavior, or focus restoration
verified: 2026-08-26, Apple Developer Documentation / Xcode 26.5 SDK
---

# AppKit break overlays on macOS 26

The visual-reset field is an App-owned set of borderless `NSPanel` instances,
one logical experience across the selected displays. It intentionally makes
exactly one panel key so Escape and Command-period work from frame one, but it
never becomes the app's main window and returns activation when it closes.

## The shape of it

```swift
final class BreakPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

panel.level = .floating
panel.collectionBehavior = [
    .canJoinAllSpaces,
    .canJoinAllApplications,
    .ignoresCycle,
]
```

`.canJoinAllApplications` is the macOS 26 behavior Apple explicitly recommends
for floating windows and system overlays. It can join other apps' eligible
full-screen spaces and is mutually exclusive with `.primary` and `.auxiliary`.
Do not use `.screenSaver`: `.floating` keeps the live menu bar above the field.

## Screens and mirroring

- Query `NSScreen.screens` at presentation time; Apple says not to cache it.
- On macOS 26 use `screen.cgDirectDisplayID`. Do not use private display or
  Space APIs; the older `deviceDescription["NSScreenNumber"]` bridge is not
  needed for this deployment target.
- `CGDisplayIsInMirrorSet` is the public membership check.
  `CGDisplayMirrorsDisplay` returns the primary ID for a mirrored secondary,
  and `kCGNullDirectDisplay` for a primary or unmirrored display. Canonicalize
  secondaries to that returned primary ID so a mirror set gets one panel.
- Observe `NSApplication.didChangeScreenParametersNotification`. It arrives on
  the main actor with no `userInfo`; requery screens and reconcile the whole
  panel set. A disconnected display ID is no longer safe to query.

## Activation and restoration

Before opening, retain `NSWorkspace.shared.frontmostApplication`. Request
activation with `NSApp.activate()`, then make one eligible panel key and order
the other panels front without making them key. On every exit path, close the
panels, call `NSApp.yieldActivation(to: previousApplication)`, then call
`previousApplication.activate()`.

Activation is cooperative and best-effort: neither request is guaranteed, and
the public API restores an app rather than its exact old window or responder.
Do not use deprecated `activateIgnoringOtherApps`. The separate heads-up
capsule remains non-activating; this key-panel decision applies to break fields.

## Sources

- Apple: [`NSWindow.canBecomeKey`](https://developer.apple.com/documentation/appkit/nswindow/canbecomekey) and [`canBecomeMain`](https://developer.apple.com/documentation/appkit/nswindow/canbecomemain)
- Apple: [`NSWindow.Level`](https://developer.apple.com/documentation/appkit/nswindow/level-swift.struct)
- Apple: [`NSWindow.CollectionBehavior`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct) and [`canJoinAllApplications`](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/canjoinallapplications)
- Apple: [`NSScreen.screens`](https://developer.apple.com/documentation/appkit/nsscreen/screens) and [`NSScreen`](https://developer.apple.com/documentation/appkit/nsscreen)
- Apple: [`CGDisplayIsInMirrorSet`](https://developer.apple.com/documentation/coregraphics/cgdisplayisinmirrorset(_:)) and [`CGDisplayMirrorsDisplay`](https://developer.apple.com/documentation/coregraphics/cgdisplaymirrorsdisplay(_:))
- Apple: [`didChangeScreenParametersNotification`](https://developer.apple.com/documentation/appkit/nsapplication/didchangescreenparametersnotification)
- Apple: [Cooperative activation](https://developer.apple.com/documentation/appkit/passing-control-from-one-app-to-another-with-cooperative-activation)
