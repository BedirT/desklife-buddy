# Menu-Bar Activation and Settings Fronting

## Goal

Keep the utility out of the Dock while it has no ordinary app window, and reliably bring
Settings or another owned window above other applications when the user opens it.

## Contract

- Normal background operation uses the accessory activation policy and lives in the menu bar.
- Opening Settings, onboarding, or weekly rhythm switches to the regular policy before fronting
  the window.
- Presentation activates the app explicitly and orders the requested window to the front.
- Closing the last owned ordinary window returns the app to accessory mode.
- Floating break, heads-up, and completion panels never make the Dock icon appear.
- A second open request re-fronts the existing Settings window instead of creating another one.

## Steps

- [x] Observe a failing App test for menu-bar-only launch and last-window policy restoration.
- [x] Add one App-owned activation-policy coordinator with injected policy and activation seams.
- [x] Route Settings, onboarding, and weekly rhythm windows through the shared presentation path.
- [x] Verify focused App tests, build, lint, and the real status-menu Settings route.

## Evidence

- The first focused test run failed because `AppWindowActivationController` did not exist.
- Focused activation, Settings, onboarding, and weekly-rhythm App tests pass.
- The built app Info.plist contains `LSUIElement = true`.
- Real verification reports Settings visible, key, and frontmost with a regular activation policy.
- The real accessibility tree contains the Settings window and the status-menu item.
- `scripts/build.sh` and `scripts/lint.sh` pass.
