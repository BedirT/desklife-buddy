import Domain
import Foundation

#if DEBUG
    enum HeadsUpVerificationMode: String, Equatable {
        case capsule
        case notification
        case permissionPanel

        init?(arguments: [String]) {
            let matches = [
                ("--verify-heads-up-capsule", Self.capsule),
                ("--verify-heads-up-notification", Self.notification),
                ("--verify-heads-up-permission", Self.permissionPanel),
            ].filter { arguments.contains($0.0) }
            guard matches.count == 1, let mode = matches.first?.1 else { return nil }
            self = mode
        }

        var enablesRuntime: Bool {
            self == .capsule || self == .notification
        }
    }

    enum HeadsUpVerificationRoute {
        static let deliveryID = UUID(uuidString: "00000000-0000-4000-8000-0000000000c7")!

        static func snapshot(
            state: ProtocolState,
            observedAt: Date,
        ) -> HeadsUpDeliverySnapshot {
            HeadsUpDeliverySnapshot(
                opportunity: .visual(cycleID: state.visualClock.cycleID),
                currentVisualCycleID: state.visualClock.cycleID,
                currentMovementCycleID: state.movementClock.cycleID,
                observedAt: observedAt,
                secondsUntilTarget: 30,
                secondsUntilLatest: 60,
                headsUpEnabled: true,
                headsUpLeadSeconds: 45,
                waitsForLowFrictionMoment: false,
                isLowFrictionMoment: true,
                suppressionReason: nil,
            )
        }
    }

    final class HeadsUpVerificationAuthorizationStore: HeadsUpAuthorizationStore {
        private var state: HeadsUpNotificationAuthorizationState
        private(set) var saveCount = 0

        init(mode: HeadsUpVerificationMode) {
            state = switch mode {
            case .capsule:
                HeadsUpNotificationAuthorizationState(
                    hasPresentedExplainer: true,
                    hasRequestedAuthorization: false,
                    usesInAppHeadsUp: true,
                    hasBeenAuthorized: false,
                )
            case .notification:
                HeadsUpNotificationAuthorizationState(
                    hasPresentedExplainer: true,
                    hasRequestedAuthorization: true,
                    usesInAppHeadsUp: false,
                    hasBeenAuthorized: false,
                )
            case .permissionPanel:
                HeadsUpNotificationAuthorizationState()
            }
        }

        func load() -> HeadsUpNotificationAuthorizationState { state }

        func save(_ state: HeadsUpNotificationAuthorizationState) {
            saveCount += 1
            self.state = state
        }
    }

    final class HeadsUpVerificationRuntimeStore: ProtocolRuntimeStore, ProtocolRuntimeSettingsStore {
        private let base: any ProtocolRuntimeStore
        private(set) var persistedPhases: [String] = []
        private(set) var promptPresentedEventCount = 0

        init(base: any ProtocolRuntimeStore) {
            self.base = base
        }

        func loadState() async throws -> ProtocolState? {
            try await base.loadState()
        }

        func commit(events: [OpportunityEvent], state: ProtocolState) async throws {
            try await base.commit(events: events, state: state)
            promptPresentedEventCount += events.count(where: { $0.kind == .promptPresented })
            guard let active = state.headsUpDeliveryState.activeDelivery else { return }
            let phase = switch (
                active.phase,
                active.promptFactStatus,
            ) {
            case (.reserved, _):
                "reserved"
            case (.presented, .pending):
                "presented-prompt-pending"
            case (.presented, .acknowledged):
                "presented-prompt-acknowledged"
            case (.presented, nil):
                "presented"
            }
            if persistedPhases.last != phase { persistedPhases.append(phase) }
        }

        func resolve(_ preferences: AppPreferences) throws -> ResolvedAppPreferences {
            try settingsStore.resolve(preferences)
        }

        @discardableResult
        func commitPreferences(
            _ preferences: ResolvedAppPreferences,
            state: ProtocolState,
        ) async throws -> Int {
            try await settingsStore.commitPreferences(preferences, state: state)
        }

        func deleteHistory() async throws {
            try await settingsStore.deleteHistory()
        }

        func resetAll(state: ProtocolState) async throws -> ResolvedAppPreferences {
            try await settingsStore.resetAll(state: state)
        }

        private var settingsStore: any ProtocolRuntimeSettingsStore {
            get throws {
                guard let store = base as? any ProtocolRuntimeSettingsStore else {
                    throw ProtocolRuntimeSettingsError.persistenceUnavailable
                }
                return store
            }
        }
    }

    struct HeadsUpVerificationEvidence: Encodable {
        let route: String
        let outcome: String
        let deliveryID: String?
        let opportunity: String?
        let channel: String?
        let phase: String?
        let promptFactStatus: String?
        let approachProgress: Double?
        let statusProjectionScope: String?
        let adapter: String
        let authorizationStatus: String
        let alertsEnabled: Bool
        let persistedPhases: [String]
        let promptPresentedEventCount: Int
        let capsuleCaptured: Bool
        let runtimeStatus: String
        let runtimeError: String?
    }
#endif
