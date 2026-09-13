import Domain
import Foundation
import Testing
@testable import App

/// Epic 4 transport activation (issue #5; owner sign-offs 2026-09-12/13):
/// browse/advertise lifecycle gates on the QR-bound pairing key, unpaired
/// peers are rejected, and the approved rendezvous/entitlement/plist strings
/// land byte-identical to the wave-1 PR #70 quotes.
///
/// RED-first: this suite failed on the unguarded base (`cannot find
/// 'CompanionSessionGate' in scope`, entitlement key absent). No test here
/// touches live networking: admission is pinned through the pure gate and
/// the transport's `admitsPeer` seam, never through a real MCSession.
@Suite("Companion transport activation")
@MainActor
struct CompanionTransportActivationTests {
    private static var repositoryRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        // AppTests/<this file> -> repository root.
        for _ in 0 ..< 2 {
            url.deleteLastPathComponent()
        }
        return url
    }

    private static let deviceMAC = "mac-device-uuid"
    private static let devicePhone = "phone-device-uuid"
    private static let deviceStranger = "stranger-device-uuid"

    private static let liveKey = Data((0 ..< 32).map { UInt8($0) })
    private static let rotatedKey = Data((32 ..< 64).map { UInt8($0) })
    private static let wrongKey = Data(repeating: 0xA5, count: 32)
    private static let ceremonyNow = Date(timeIntervalSince1970: 1_786_000_000)

    private static func liveGate() throws -> CompanionSessionGate {
        let issued = try CompanionPairingCeremony.issue(
            key: liveKey,
            now: ceremonyNow,
        )
        var gate = CompanionSessionGate()
        gate.activate(issued.state)
        return gate
    }

    @Test("Unpaired peer is rejected")
    func unpairedPeerRejected() throws {
        var gate = try Self.liveGate()
        #expect(gate.admits(Self.devicePhone) == false)
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.wrongKey) == false)
        #expect(gate.admits(Self.devicePhone) == false)
    }

    @Test("Session establishes with the QR-bound key")
    func sessionEstablishesWithBoundKey() throws {
        var gate = try Self.liveGate()
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == true)
        #expect(gate.admits(Self.devicePhone) == true)
        #expect(gate.admits(Self.deviceStranger) == false)
    }

    @Test("Rotation kills old bindings")
    func rotationKillsOldBindings() throws {
        var gate = try Self.liveGate()
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == true)
        let issued = try CompanionPairingCeremony.issue(key: Self.liveKey, now: Self.ceremonyNow)
        let rotated = try CompanionPairingCeremony.rotate(
            issued.state,
            key: Self.rotatedKey,
            now: Self.ceremonyNow,
        )
        gate.activate(rotated.state)
        #expect(gate.admits(Self.devicePhone) == false)
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == false)
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.rotatedKey) == true)
        #expect(gate.admits(Self.devicePhone) == true)
    }

    @Test("Revocation admits nothing")
    func revocationAdmitsNothing() throws {
        var gate = try Self.liveGate()
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == true)
        gate.deactivate()
        #expect(gate.admits(Self.devicePhone) == false)
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == false)
    }

    @Test("Unbind drops one device only")
    func unbindDropsOneDevice() throws {
        var gate = try Self.liveGate()
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == true)
        #expect(gate.establish(deviceID: Self.deviceStranger, presenting: Self.liveKey) == true)
        gate.unbind(deviceID: Self.deviceStranger)
        #expect(gate.admits(Self.devicePhone) == true)
        #expect(gate.admits(Self.deviceStranger) == false)
    }

    @Test("Transport denies unpaired peers without live networking")
    func transportDeniesUnpairedPeer() {
        let transport = MultipeerCompanionTransport(deviceID: Self.deviceMAC)
        #expect(transport.admitsPeer(Self.deviceStranger) == false)
    }

    @Test("Transport admits a key-bound peer")
    func transportAdmitsBoundPeer() throws {
        var gate = try Self.liveGate()
        #expect(gate.establish(deviceID: Self.devicePhone, presenting: Self.liveKey) == true)
        let transport = MultipeerCompanionTransport(deviceID: Self.deviceMAC)
        transport.admissionGate = gate
        #expect(transport.admitsPeer(Self.devicePhone) == true)
        #expect(transport.admitsPeer(Self.deviceStranger) == false)
    }

    @Test("Approved rendezvous strings byte-match the PR #70 quotes")
    func approvedRendezvousStringsByteMatch() {
        #expect(CompanionServiceStrings.serviceType == "desklife-cmp")
        #expect(CompanionServiceStrings.serviceDomain == "local.")
    }

    @Test("Network-client entitlement is present")
    func networkClientEntitlementPresent() throws {
        let url = Self.repositoryRoot.appending(path: "App/App.entitlements")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil,
        )
        let entitlements = try #require(plist as? [String: Any])
        #expect(entitlements["com.apple.security.network.client"] as? Bool == true)
    }

    @Test("Local-network plist strings are present")
    func localNetworkPlistStringsPresent() throws {
        let url = Self.repositoryRoot.appending(path: "App/Info.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil,
        )
        let info = try #require(plist as? [String: Any])
        let usage = try #require(info["NSLocalNetworkUsageDescription"] as? String)
        #expect(usage.isEmpty == false)
        let services = try #require(info["NSBonjourServices"] as? [String])
        // Legal Bonjour plist formation of the approved service type: the MC
        // serviceType API value stays bare `desklife-cmp` (pinned above), so
        // derive the expected entry from it — the two cannot drift apart.
        #expect(services == ["_" + CompanionServiceStrings.serviceType + "._tcp"])
    }
}
