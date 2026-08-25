---
read_when: shaping macOS scenes, windows, split views, commands, settings, inspectors, or previews
verified: 2026-06-17, Apple Developer Documentation / Xcode 26.5
---

# SwiftUI for macOS scenes and windows

macOS SwiftUI apps are scene-first. The template's default app shape is a
`WindowGroup` main scene, a separate `Settings` scene, app/menu commands, and
selection-driven content such as `NavigationSplitView`.

## The shape of it

```swift
@main
struct MyMacApp: App {
    @State private var composition = AppComposition.live()

    var body: some Scene {
        WindowGroup(AppL10n.appName, id: "main") {
            RootView(model: composition.itemListModel)
        }
        .commands {
            AppCommands(model: composition.itemListModel)
        }

        Settings {
            SettingsView()
        }
    }
}
```

`NavigationSplitView` is the default for sidebar/detail apps: a stable
selection in a leading column controls the detail column. Use `@SceneStorage`
or scene-owned `@State` for per-window selection, and `@AppStorage` for
preferences.

## Rules here

- Prefer desktop affordances: sidebars, toolbars, contextual menus, app
  commands, settings, keyboard shortcuts, and inspectors.
- Do not port iOS push-navigation as the default. If the user can benefit from
  always-visible structure, use `NavigationSplitView`.
- Put app-wide commands in `App/` and route them through focused/scene-owned
  state when the command should target the active window.
- Keep `#Preview` declarations beside views. Xcode live Previews are the
  interactive authoring surface; `scripts/snapshot.sh` is the deterministic
  evidence surface.

## Sharp edges

- `WindowGroup` creates a group of identically structured windows; per-window
  state must not be hidden in global singletons.
- `Settings` is a scene, not a navigation destination inside the main window.
- `commands` adds menu-bar commands to a scene. Provide keyboard shortcuts for
  primary desktop actions where appropriate.
- Native sidebars already have macOS material/selection behavior. Avoid
  card-like touch rows unless the product explicitly asks for custom chrome.

## Sources

- Apple: [WindowGroup](https://developer.apple.com/documentation/SwiftUI/WindowGroup)
- Apple: [NavigationSplitView](https://developer.apple.com/documentation/SwiftUI/NavigationSplitView)
- Apple: [Menus and commands](https://developer.apple.com/documentation/swiftui/menus-and-commands)
- Apple: [Settings](https://developer.apple.com/documentation/swiftui/settings)
- Apple: [Previewing your app's interface in Xcode](https://developer.apple.com/documentation/xcode/previewing-your-apps-interface-in-xcode)
