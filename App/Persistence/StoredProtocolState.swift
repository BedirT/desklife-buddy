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
    }

    func updateClocks(
        profileID: String,
        visualAccumulatedActiveUseSeconds: Double,
        movementAccumulatedActiveUseSeconds: Double,
    ) {
        self.profileID = profileID
        self.visualAccumulatedActiveUseSeconds = visualAccumulatedActiveUseSeconds
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
}
