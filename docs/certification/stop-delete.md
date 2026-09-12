# Stop / Delete instructions (trust baseline)

Collector anchor: trust-stop-delete-doc v1.
Status: baseline, releasable without release-scope selection.
Scope: the permission-free Mac core. Nothing here requires an account,
a network, or owner approval to execute.

## Stop (immediate, reversible)

1. Kill switch first: `PermissionBroker.engageKillSwitch()` stops all
   sensing-effect behavior at once. Source:
   `Packages/Domain/Sources/Domain/PermissionBroker.swift`
   (`engageKillSwitch`, `disengageKillSwitch`, `isKillSwitchEngaged`).
   Resume strictly requires post-disengage re-consent; grants issued
   while engaged throw.
2. Withdraw consent per capability: revoking a granted capability moves
   it to `revoked`; the 5-tick revocation deadline
   (`revocationDeadlineTicks`, `revocationOverdue(atTicks:)`,
   `drainRevocations`) is unit-pinned by
   `PermissionBrokerRevocationTests`. Wall-clock completion on device
   waits on the owner hardware run (dossier:
   `tcc-revocation-device-timing`).
3. Quiet the surface without uninstalling: pause or hold presentation
   from the menu-bar/Dock menus; presentation holds never pause the
   underlying accumulation and never lock the user out.
4. Disable launch at login (local-only `SMAppService` registration, no
   transport, no entitlement, no protected data): turn it off in
   Settings. Sources: `App/Settings/LaunchAtLoginService.swift`,
   `App/Settings/SettingsIntegrationsAppRuntime.swift`.

## Delete (local-only, no account to close)

1. Exported files you saved: `HistoryExport` and `LedgerExport` write
   only to files you explicitly chose (csv/json). Delete those files
   with Finder or `rm`; the product keeps no other copy and transmits
   nothing anywhere.
2. Local ledger rows: six additive-only stores of sanitized rows (see
   `ledger-card.md`). Removing the app's local data removes them;
   retention otherwise prunes on every write and read.
3. Local opportunity events and preferences: bounded by `HistoryPolicy`
   retention choices; removing the app's local data removes them.
4. Exact container/bundle paths for the signed candidate are named at
   release-scope selection (dossier: `trust-release-scope-selection`);
   until then, delete via the standard system path for the running
   build (Settings removal plus deleting any files you exported).

## What Stop/Delete never needs

- No support ticket, no account deletion flow, no network call: strict
  local mode has no egress by construction (dossier: the five
  `no-egress-*` checks, re-collected on every script run).
- No permission to revoke in System Settings: the product requests no
  protected API, so there is no TCC prompt to clear (dossier:
  `tcc-physical-prompt-evidence` stays pending-owner until an owner
  hardware run says otherwise).
