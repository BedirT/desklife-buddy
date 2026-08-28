import Domain
import Foundation
import Testing

@testable import App

struct HeadsUpVerificationRouteTests {
    @Test("Verification arguments select one explicit Heads-Up route")
    func routeParsing() {
        #expect(HeadsUpVerificationMode(arguments: ["App"]) == nil)
        #expect(HeadsUpVerificationMode(arguments: ["App", "--verify-heads-up-capsule"]) == .capsule)
        #expect(HeadsUpVerificationMode(arguments: ["App", "--verify-heads-up-notification"]) == .notification)
        #expect(HeadsUpVerificationMode(arguments: ["App", "--verify-heads-up-permission"]) == .permissionPanel)
        #expect(HeadsUpVerificationMode(arguments: [
            "App",
            "--verify-heads-up-capsule",
            "--verify-heads-up-notification",
        ]) == nil)
    }

    @Test("Ordinary startup and validated runtime verification routes use one re-offer")
    func policySelectsProductionAndValidatedVerificationRuntime() {
        let expected = HeadsUpRuntimePolicy(maximumSnoozeReoffers: 1)

        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: ["App"]) == expected)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-permission",
        ]) == nil)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-capsule",
            "--verify-heads-up-notification",
        ]) == nil)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-capsule",
            "--verify-heads-up-permission",
        ]) == nil)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-notification",
            "--verify-heads-up-permission",
        ]) == nil)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-capsule",
            "--verify-heads-up-notification",
            "--verify-heads-up-permission",
        ]) == nil)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-capsule",
        ]) == expected)
        #expect(AppDelegate.verificationHeadsUpPolicy(arguments: [
            "App",
            "--verify-heads-up-notification",
        ]) == expected)
    }

    @Test("Capsule verification uses an ephemeral in-app choice without a system request")
    func capsuleAuthorizationState() {
        let store = HeadsUpVerificationAuthorizationStore(mode: .capsule)

        #expect(store.load() == HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: false,
            usesInAppHeadsUp: true,
            hasBeenAuthorized: false,
        ))
        #expect(store.saveCount == 0)
    }

    @Test("Notification verification suppresses permission prompting while probing live state")
    func notificationAuthorizationState() {
        let store = HeadsUpVerificationAuthorizationStore(mode: .notification)

        #expect(store.load() == HeadsUpNotificationAuthorizationState(
            hasPresentedExplainer: true,
            hasRequestedAuthorization: true,
            usesInAppHeadsUp: false,
            hasBeenAuthorized: false,
        ))
        #expect(store.saveCount == 0)
    }

    @Test("The post-restore seed has an exact delivery opportunity and deterministic timing")
    func deterministicSnapshot() {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = HeadsUpVerificationRoute.snapshot(
            state: ProtocolState(),
            observedAt: observedAt,
        )

        #expect(snapshot.opportunity == .visual(cycleID: 0))
        #expect(snapshot.currentVisualCycleID == 0)
        #expect(snapshot.currentMovementCycleID == 0)
        #expect(snapshot.observedAt == observedAt)
        #expect(snapshot.secondsUntilTarget == 30)
        #expect(snapshot.secondsUntilLatest == 60)
        #expect(snapshot.headsUpEnabled)
        #expect(snapshot.headsUpLeadSeconds == 45)
        #expect(!snapshot.waitsForLowFrictionMoment)
        #expect(snapshot.suppressionReason == nil)
    }

    @Test("The verification delivery UUID is stable across launches")
    func stableDeliveryID() {
        #expect(HeadsUpVerificationRoute.deliveryID.uuidString.lowercased()
            == "00000000-0000-4000-8000-0000000000c7")
    }
}
