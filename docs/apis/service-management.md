---
read_when: implementing or changing launch-at-login registration
verified: 2026-08-28, Apple Developer Documentation
---

# ServiceManagement launch at login

The app targets macOS 26 and uses `SMAppService.mainApp` for the reversible
Open at login preference. Do not use the deprecated `SMLoginItemSetEnabled` API.

## Contract used here

- `SMAppService.mainApp.status` reports `.notRegistered`, `.enabled`,
  `.requiresApproval`, or `.notFound`.
- `.requiresApproval` means registration succeeded but the user must approve it
  in System Settings, or later revoked consent there. It is still registered.
- Registration is not effective in `.requiresApproval`; Settings must not render
  that status as an enabled toggle. It exposes the framework-owned Login Items
  recovery route instead.
- `register()` registers the main app for subsequent logins, subject to user
  approval. Calling it for an already registered service can throw.
- `unregister()` reverses registration without terminating the currently
  running main app. Calling it for an already unregistered service can throw.
- `SMAppService.openSystemSettingsLoginItems()` is the framework-owned route to
  the Login Items pane if a future recovery control needs it.

## App boundary

Read status before changing it and skip redundant system calls. When a Settings
mutation changes ServiceManagement before durable preferences are acknowledged,
restore the prior registration if persistence is busy or throws. If compensation
also fails, surface that failure rather than claiming the preference rolled back.
The App refreshes this status without prompting whenever the Settings window is
brought forward or the app becomes active after visiting System Settings. The
durable selection is reconciled to the effective external status without calling
`register()` or `unregister()` again.

Primary reference: Apple Developer Documentation, `SMAppService` and
`SMAppService.Status`.
