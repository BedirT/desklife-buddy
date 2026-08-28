import ServiceManagement
import SettingsFeature

enum LaunchAtLoginServiceStatus: Equatable, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    var isRegistered: Bool {
        self == .enabled || self == .requiresApproval
    }
}

protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginServiceStatus { get }
    func register() throws
    func unregister() throws
}

final class SMAppLaunchAtLoginService: LaunchAtLoginService {
    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
    }

    var status: LaunchAtLoginServiceStatus {
        switch service.status {
        case .notRegistered:
            .notRegistered
        case .enabled:
            .enabled
        case .requiresApproval:
            .requiresApproval
        case .notFound:
            .notFound
        @unknown default:
            .notFound
        }
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}

enum LaunchAtLoginMutationError: Error, Equatable {
    case rollbackFailed
}

struct LaunchAtLoginMutationBoundary {
    private let service: any LaunchAtLoginService

    init(service: any LaunchAtLoginService) {
        self.service = service
    }

    func apply(
        enabled: Bool,
        persist: () async throws -> SettingsApplyResult,
    ) async throws -> SettingsApplyResult {
        try await mutateRegistration(
            enabled: enabled,
            persist: persist,
            shouldRollback: { $0 == .temporarilyBusy },
        )
    }

    func reset(
        persist: () async throws -> SettingsDestructiveResult,
    ) async throws -> SettingsDestructiveResult {
        try await mutateRegistration(
            enabled: false,
            persist: persist,
            shouldRollback: { $0 == .temporarilyBusy },
        )
    }

    private func mutateRegistration<Result>(
        enabled: Bool,
        persist: () async throws -> Result,
        shouldRollback: (Result) -> Bool,
    ) async throws -> Result {
        let wasRegistered = service.status.isRegistered
        let changedSystemRegistration = wasRegistered != enabled

        if changedSystemRegistration {
            do {
                try setRegistration(enabled)
            } catch {
                try rollbackIfNeeded(to: wasRegistered)
                throw error
            }
        }

        do {
            let result = try await persist()
            if shouldRollback(result), changedSystemRegistration {
                try rollback(to: wasRegistered)
            }
            return result
        } catch {
            if changedSystemRegistration {
                try rollback(to: wasRegistered)
            }
            throw error
        }
    }

    private func setRegistration(_ enabled: Bool) throws {
        if enabled {
            try service.register()
        } else {
            try service.unregister()
        }
    }

    private func rollbackIfNeeded(to wasRegistered: Bool) throws {
        guard service.status.isRegistered != wasRegistered else { return }
        try rollback(to: wasRegistered)
    }

    private func rollback(to wasRegistered: Bool) throws {
        do {
            try setRegistration(wasRegistered)
        } catch {
            throw LaunchAtLoginMutationError.rollbackFailed
        }
    }
}
