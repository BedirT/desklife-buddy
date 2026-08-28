import AppKit
import StatusMenu

#if DEBUG
    extension AppDelegate {
        @objc func openVerificationMerged() {
            present(.merged, for: .startHeadsUpNow)
        }

        @objc func openVerificationSnooze() {
            present(.snooze(.merged), for: .openSnoozeOptions)
        }

        @objc func captureVerificationMerged() {
            guard let coordinator = mergedOverlayCoordinator,
                  let phase = coordinator.phaseForVerification,
                  let remainingSeconds = coordinator.remainingSecondsForVerification,
                  let caches = FileManager.default.urls(
                      for: .cachesDirectory,
                      in: .userDomainMask,
                  ).first
            else {
                return
            }
            mergedCaptureCount += 1
            let runtimeStatus = lastRuntimeError == nil ? "ok" : "error"
            let dockStatus = NSApp.currentSystemPresentationOptions.contains(.hideDock)
                ? "hidden"
                : "visible"
            let value = "\(mergedCaptureCount) \(phase) \(remainingSeconds) "
                + "\(runtimeStatus) \(dockStatus)"
            let state = caches.appendingPathComponent(
                "merged-state-\(ProcessInfo.processInfo.processIdentifier).txt",
            )
            try? value.write(to: state, atomically: true, encoding: .utf8)
            _ = coordinator.captureForVerification()
        }

        @objc func captureVerificationSnooze() {
            guard let coordinator = breakFlowOverlayCoordinator,
                  let scope = coordinator.scopeForVerification,
                  let caches = FileManager.default.urls(
                      for: .cachesDirectory,
                      in: .userDomainMask,
                  ).first
            else {
                return
            }
            snoozeCaptureCount += 1
            let runtimeStatus = lastRuntimeError == nil ? "ok" : "error"
            let dockStatus = NSApp.currentSystemPresentationOptions.contains(.hideDock)
                ? "hidden"
                : "visible"
            let value = "\(snoozeCaptureCount) \(scope) \(runtimeStatus) \(dockStatus)"
            let state = caches.appendingPathComponent(
                "snooze-state-\(ProcessInfo.processInfo.processIdentifier).txt",
            )
            try? value.write(to: state, atomically: true, encoding: .utf8)
            _ = coordinator.captureForVerification()
        }
    }
#endif
