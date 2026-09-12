import Foundation
import SwiftData

@Model
final class StoredProtocolState {
    @Attribute(.unique) var key: String
    var schemaVersion: Int
    var profileID: String
    var visualAccumulatedActiveUseSeconds: Double
    var movementAccumulatedActiveUseSeconds: Double
    var visualSnoozeDeadline: Date?
    var movementSnoozeDeadline: Date?
    var recoveryActiveUseSeconds: Double = 0
    var recoveryMovementDeferralCount: Int = 0
    var recoveryWasOfferedThisSession: Bool = false
    var recoveryLastObservedAt: Date?
    var visualNotAppropriateThisSession: Bool?
    var movementNotAppropriateThisSession: Bool?
    var visualCycleIDStorage: Int64?
    var movementCycleIDStorage: Int64?
    var headsUpDeliveryStatePayload: Data?
    /// Versioned coordinator fence/dedup snapshot (Story 2.5, row version
    /// 2+). Additive-only: v1 rows predate this column and restore with an
    /// empty fence; only the versioned store reads or writes it.
    var coordinatorFencePayload: Data?
    init(
        key: String,
        schemaVersion: Int,
        profileID: String,
        visualAccumulatedActiveUseSeconds: Double,
        movementAccumulatedActiveUseSeconds: Double,
        visualSnoozeDeadline: Date?,
        movementSnoozeDeadline: Date?,
        recoveryActiveUseSeconds: Double,
        recoveryMovementDeferralCount: Int,
        recoveryWasOfferedThisSession: Bool,
        recoveryLastObservedAt: Date?,
        visualNotAppropriateThisSession: Bool? = nil,
        movementNotAppropriateThisSession: Bool? = nil,
        visualCycleIDStorage: Int64? = nil,
        movementCycleIDStorage: Int64? = nil,
        headsUpDeliveryStatePayload: Data? = nil,
        coordinatorFencePayload: Data? = nil,
    ) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.profileID = profileID
        self.visualAccumulatedActiveUseSeconds = visualAccumulatedActiveUseSeconds
        self.movementAccumulatedActiveUseSeconds = movementAccumulatedActiveUseSeconds
        self.visualSnoozeDeadline = visualSnoozeDeadline
        self.movementSnoozeDeadline = movementSnoozeDeadline
        self.recoveryActiveUseSeconds = recoveryActiveUseSeconds
        self.recoveryMovementDeferralCount = recoveryMovementDeferralCount
        self.recoveryWasOfferedThisSession = recoveryWasOfferedThisSession
        self.recoveryLastObservedAt = recoveryLastObservedAt
        self.visualNotAppropriateThisSession = visualNotAppropriateThisSession
        self.movementNotAppropriateThisSession = movementNotAppropriateThisSession
        self.visualCycleIDStorage = visualCycleIDStorage
        self.movementCycleIDStorage = movementCycleIDStorage
        self.headsUpDeliveryStatePayload = headsUpDeliveryStatePayload
        self.coordinatorFencePayload = coordinatorFencePayload
    }

    func updateClocks(
        profileID: String,
        visualCycleIDStorage: Int64,
        visualAccumulatedActiveUseSeconds: Double,
        movementCycleIDStorage: Int64,
        movementAccumulatedActiveUseSeconds: Double,
    ) {
        self.profileID = profileID
        self.visualCycleIDStorage = visualCycleIDStorage
        self.visualAccumulatedActiveUseSeconds = visualAccumulatedActiveUseSeconds
        self.movementCycleIDStorage = movementCycleIDStorage
        self.movementAccumulatedActiveUseSeconds = movementAccumulatedActiveUseSeconds
    }

    func updateSnoozes(visual: Date?, movement: Date?) {
        visualSnoozeDeadline = visual
        movementSnoozeDeadline = movement
    }

    func updateRecovery(
        activeUseSeconds: Double,
        movementDeferralCount: Int,
        wasOfferedThisSession: Bool,
        lastObservedAt: Date?,
    ) {
        recoveryActiveUseSeconds = activeUseSeconds
        recoveryMovementDeferralCount = movementDeferralCount
        recoveryWasOfferedThisSession = wasOfferedThisSession
        recoveryLastObservedAt = lastObservedAt
    }

    func updateNotAppropriateOpportunities(visual: Bool, movement: Bool) {
        visualNotAppropriateThisSession = visual
        movementNotAppropriateThisSession = movement
    }

    func updateHeadsUpDeliveryStatePayload(_ payload: Data) {
        headsUpDeliveryStatePayload = payload
    }

    func updateCoordinatorFencePayload(_ payload: Data) {
        coordinatorFencePayload = payload
    }
}
