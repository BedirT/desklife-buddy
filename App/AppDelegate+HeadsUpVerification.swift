import AppKit
import Domain
import Foundation
import HeadsUp

#if DEBUG
    extension AppDelegate {
        func configureHeadsUpPermissionVerification(arguments: [String]) {
            guard arguments.contains("--verify-heads-up-permission") else { return }
            addVerificationTimer(
                delay: 0.5,
                selector: #selector(openVerificationHeadsUpPermission),
            )
            for delay in [1.0, 2.0, 3.0] {
                addVerificationTimer(
                    delay: delay,
                    selector: #selector(captureVerificationHeadsUpPermission),
                )
            }
        }

        func runHeadsUpVerificationAfterRestore() async {
            guard let mode = headsUpVerificationMode,
                  mode.enablesRuntime,
                  let coordinator = headsUpLifecycleCoordinator,
                  let runtime
            else {
                return
            }

            do {
                headsUpVerificationSettings = try await coordinator.center.notificationSettings()
            } catch {
                lastRuntimeError = error
            }

            if mode == .notification,
               headsUpVerificationSettings?.authorizationStatus != .authorized
               || headsUpVerificationSettings?.alertsEnabled != true
            {
                writeHeadsUpVerificationEvidence(
                    route: mode.rawValue,
                    outcome: "blocked-authorization-unavailable",
                    capsuleCaptured: false,
                )
                return
            }

            coordinator.observeHeadsUp(HeadsUpVerificationRoute.snapshot(
                state: runtime.state,
                observedAt: Date(),
            ))
            await coordinator.drain()

            if mode == .capsule {
                for delay in [0.5, 1.0, 2.0] {
                    addVerificationTimer(
                        delay: delay,
                        selector: #selector(captureVerificationHeadsUpCapsule),
                    )
                }
            } else {
                writeHeadsUpVerificationEvidence(
                    route: mode.rawValue,
                    outcome: "presented",
                    capsuleCaptured: false,
                )
            }
        }

        @objc func openVerificationHeadsUpPermission() {
            let panel = HeadsUpPermissionPanel(
                onAction: { [weak self] _ in
                    self?.headsUpVerificationPermissionPanel?.close()
                },
                onClose: { [weak self] in
                    self?.headsUpVerificationPermissionPanel = nil
                },
            )
            headsUpVerificationPermissionPanel = panel
            panel.present()
            Task { [weak self] in
                guard let self else { return }
                do {
                    headsUpVerificationSettings = try await UNUserNotificationCenterAdapter()
                        .notificationSettings()
                } catch {
                    lastRuntimeError = error
                }
            }
        }

        @objc func captureVerificationHeadsUpPermission() {
            guard let panel = headsUpVerificationPermissionPanel else { return }
            let captured = panel.captureForVerification()
            writeHeadsUpVerificationEvidence(
                route: HeadsUpVerificationMode.permissionPanel.rawValue,
                outcome: "presented-without-system-request",
                capsuleCaptured: captured,
                filenamePrefix: "heads-up-permission",
            )
        }

        @objc func captureVerificationHeadsUpCapsule() {
            guard let coordinator = headsUpLifecycleCoordinator else { return }
            headsUpVerificationCaptureCount += 1
            let captured = coordinator.captureCapsuleForVerification()
            writeHeadsUpVerificationEvidence(
                route: HeadsUpVerificationMode.capsule.rawValue,
                outcome: "presented",
                capsuleCaptured: captured,
            )
        }

        func writeHeadsUpVerificationEvidence(
            route: String,
            outcome: String,
            capsuleCaptured: Bool,
            filenamePrefix: String = "heads-up-capsule",
        ) {
            guard let caches = FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask,
            ).first else {
                return
            }
            let active = runtime?.state.headsUpDeliveryState.activeDelivery
            let presentation = headsUpLifecycleCoordinator?.activePresentation
            let settings = headsUpVerificationSettings
            let trace = headsUpVerificationStore
            let evidence = HeadsUpVerificationEvidence(
                route: route,
                outcome: outcome,
                deliveryID: active?.id.rawValue.uuidString.lowercased(),
                opportunity: active.map { Self.verificationOpportunity($0.opportunity) },
                channel: active?.channel?.rawValue,
                phase: active.map { Self.verificationPhase($0.phase) },
                promptFactStatus: active?.promptFactStatus?.rawValue,
                approachProgress: presentation?.model.approachProgress,
                statusProjectionScope: headsUpLifecycleCoordinator?.statusProjection.map {
                    Self.verificationScope($0.scope)
                },
                adapter: "UNUserNotificationCenterAdapter",
                authorizationStatus: settings.map {
                    Self.verificationAuthorizationStatus($0.authorizationStatus)
                } ?? "probe-unavailable",
                alertsEnabled: settings?.alertsEnabled ?? false,
                persistedPhases: trace?.persistedPhases ?? [],
                promptPresentedEventCount: trace?.promptPresentedEventCount ?? 0,
                capsuleCaptured: capsuleCaptured,
                runtimeStatus: lastRuntimeError == nil ? "ok" : "error",
                runtimeError: lastRuntimeError.map { String(describing: $0) },
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            guard let data = try? encoder.encode(evidence) else { return }
            let state = caches.appendingPathComponent(
                "\(filenamePrefix)-state-\(ProcessInfo.processInfo.processIdentifier).json",
            )
            try? data.write(to: state, options: Data.WritingOptions.atomic)
        }

        private static func verificationOpportunity(_ opportunity: HeadsUpOpportunityID) -> String {
            switch opportunity {
            case let .visual(cycleID):
                "visual:\(cycleID)"
            case let .movement(cycleID):
                "movement:\(cycleID)"
            case let .merged(visualCycleID, movementCycleID):
                "merged:\(visualCycleID):\(movementCycleID)"
            }
        }

        private static func verificationPhase(_ phase: HeadsUpActiveDeliveryPhase) -> String {
            switch phase {
            case .reserved: "reserved"
            case .presented: "presented"
            }
        }

        private static func verificationScope(_ scope: HeadsUpScope) -> String {
            switch scope {
            case .visual: "visual"
            case .movement: "movement"
            case .merged: "merged"
            }
        }

        private static func verificationAuthorizationStatus(
            _ status: HeadsUpNotificationAuthorizationStatus,
        ) -> String {
            switch status {
            case .notDetermined: "not-determined"
            case .denied: "denied"
            case .revoked: "revoked"
            case .authorized: "authorized"
            case .provisional: "provisional"
            case .unknown: "unknown"
            }
        }
    }
#endif
