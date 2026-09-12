import Foundation

// NON-SHIPPING SPIKE — Epic 5 story S2 (issue #6).
// Stand-in for what the public NSWorkspace API exposes, mirroring the SDK
// fields verified against MacOSX26.5.sdk:
//   AppKit/NSWorkspace.h:144: `frontmostApplication` (KVO-observable,
//     also delivered via NSWorkspaceDidActivateApplicationNotification);
//   AppKit/NSRunningApplication.h:92,95: `localizedName`,
//     `bundleIdentifier`. NSRunningApplication exposes NO window titles,
//     NO window content, NO activation history — there is nothing to drop
//   beyond the app name / pid / launch date the sanitizer discards here.
// The probe NEVER observes a real workspace (no live pids, no history
// log). Permission-free: no entitlement, no TCC prompt, no owner gate.

/// Raw shape mirroring the NSRunningApplication fields a production
/// adapter COULD see. `windowTitle` is included as a canary: no public
/// NSWorkspace/NSRunningApplication API returns it (it would require
/// CGWindowListCopyWindowInfo or AXUIElement — both banned by the raw
/// import guard), so a production adapter can never populate it.
public struct RawFrontmostApp: Sendable {
    public let bundleIdentifier: String?
    public let localizedName: String?
    public let processIdentifier: Int32
    public let windowTitle: String?
    public let launchDate: Date?

    public init(
        bundleIdentifier: String?, localizedName: String?,
        processIdentifier: Int32, windowTitle: String?, launchDate: Date?
    ) {
        self.bundleIdentifier = bundleIdentifier
        self.localizedName = localizedName
        self.processIdentifier = processIdentifier
        self.windowTitle = windowTitle
        self.launchDate = launchDate
    }
}

/// Sanitized output: selected-bundle active boolean ONLY.
public struct FrontmostAppMatch: Equatable, Sendable {
    public let isSelectedActive: Bool
}

/// SPIKE (b) — Live frontmost-app rules.
///
/// VERDICT: VIABLE + ceiling.
/// - Ceiling: `frontmostApplication.bundleIdentifier == <selected>`
///   boolean, refreshed on NSWorkspaceDidActivateApplicationNotification
///   (or KVO on `frontmostApplication`). No polling needed; effectively
///   zero sampling cost.
/// - Dropped at the boundary: localizedName (app names never retained),
///   pid, launch date. Window titles are unobtainable through this API
///   by construction (canary field above stays permanently nil in
///   production; populating it would require a banned API).
/// - Denial/revocation: none possible — no permission governs it, so no
///   revocation path exists. Nil frontmost app (login window / no GUI
///   session) emits not-active (unknown, never negative).
/// - Retained state: the single current boolean only. No history, no log,
///   no per-app counters — enforced by the stateless sanitizer below.
public struct FrontmostAppProbe: Sendable {
    private let selectedBundleIdentifier: String

    public init(selectedBundleIdentifier: String) {
        self.selectedBundleIdentifier = selectedBundleIdentifier
    }

    public func sanitize(raw: RawFrontmostApp?) -> FrontmostAppMatch {
        FrontmostAppMatch(isSelectedActive: raw?.bundleIdentifier == selectedBundleIdentifier)
    }
}
