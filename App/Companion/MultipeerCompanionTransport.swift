import Foundation
import MultipeerConnectivity

/// Owner-approved Bonjour rendezvous strings for the companion transport.
///
/// Approved by the owner (Epic 4 issue #5, gate Q1 sign-off 2026-09-13):
/// these exact strings are quoted in the wave-1 PR #70 body. The app
/// Info.plist `NSBonjourServices` entry carries the same approved service
/// in legal Bonjour plist formation (`_desklife-cmp._tcp`) — a mechanical
/// encoding of `serviceType`, not a new string.
///
/// - `serviceType` follows the Bonjour 1–15 lowercase alnum-plus-hyphen rule
///   (`desklife-cmp` is 12 characters).
/// - `serviceDomain` is the standard link-local domain.
public enum CompanionServiceStrings {
    /// Approved Bonjour service type. QUOTE IN PR #70: `"desklife-cmp"`.
    public static let serviceType = "desklife-cmp"
    /// Approved Bonjour service domain. QUOTE IN PR #70: `"local."`.
    public static let serviceDomain = "local."
}

/// Receives session bytes from nearby peers on the Mac side.
public protocol MultipeerCompanionTransportDelegate: AnyObject {
    /// Codec-encoded session bytes arrived from a peer device UUID string.
    func companionTransport(_ transport: MultipeerCompanionTransport, didReceive data: Data, fromPeer peerID: String)
    /// A nearby peer's connectivity changed (useful for presence UI later).
    func companionTransport(_ transport: MultipeerCompanionTransport, peer peerID: String, didChangeState state: MCSessionState)
}

/// The MultipeerConnectivity transport: Mac-side advertiser + browser (Epic 4).
///
/// This class moves opaque `Data` only. Framing stays in Domain
/// (`CompanionSessionCodec`): the composition root encodes envelopes before
/// calling `send` and decodes bytes delivered to the delegate. Invitation
/// acceptance here is connectivity plus pairing admission — payload trust
/// comes from the QR-shared pairing key (see `CompanionKeychainStore`),
/// and only peers bound to the live key through `admissionGate` are
/// invited, accepted, or heard.
///
/// Sandbox note: browsing/advertising/connecting needs the
/// `com.apple.security.network.client` entitlement (owner-approved
/// 2026-09-13, quoted in the wave-1 PR #70 body). The transport starts
/// inert — the gate admits nothing until the composition root activates
/// the live pairing — so no peer is contacted before pairing binds.
public final class MultipeerCompanionTransport: NSObject {
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

    /// Pairing-bound admission policy. Starts empty (admits nothing) until
    /// the composition root activates the live QR-shared pairing; the
    /// advertiser, browser, and session callbacks all consult it.
    public var admissionGate = CompanionSessionGate()

    /// Device UUID string used as the MCPeerID display name (stable per install).
    public let deviceID: String

    /// Receive/state-change callbacks. Held weakly.
    public weak var delegate: (any MultipeerCompanionTransportDelegate)?

    /// Starts disconnected; call `startAdvertising()` / `startBrowsing()` to rendezvous.
    public init(deviceID: String) {
        self.deviceID = deviceID
        self.peerID = MCPeerID(displayName: deviceID)
        self.session = MCSession(peer: peerID)
        self.advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: nil,
            serviceType: CompanionServiceStrings.serviceType
        )
        self.browser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: CompanionServiceStrings.serviceType
        )
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
    }

    /// Advertises this Mac to nearby phones.
    public func startAdvertising() {
        advertiser.startAdvertisingPeer()
    }

    /// Browses for nearby phones.
    public func startBrowsing() {
        browser.startBrowsingForPeers()
    }

    /// Stops both advertising and browsing. Open sessions keep working.
    public func stopRendezvous() {
        advertiser.stopAdvertisingPeer()
        browser.stopBrowsingForPeers()
    }

    /// Admission check for one device UUID string: true only while the
    /// pairing gate binds it to the live QR-shared key. The transport's own
    /// callbacks consult this; tests pin it without live networking.
    public func admitsPeer(_ deviceID: String) -> Bool {
        admissionGate.admits(deviceID)
    }

    /// Currently connected peer device UUID strings.
    public var connectedPeers: [String] {
        session.connectedPeers.map(\.displayName)
    }

    /// Sends encoded session bytes: reliably, to named peers (nil = all connected).
    public func send(_ data: Data, toPeers peerIDs: [String]? = nil) throws {
        let targets: [MCPeerID]
        if let peerIDs {
            let wanted = Set(peerIDs)
            targets = session.connectedPeers.filter { wanted.contains($0.displayName) }
        } else {
            targets = session.connectedPeers
        }
        guard !targets.isEmpty else { return }
        try session.send(data, toPeers: targets, with: .reliable)
    }
}

// MARK: - MCSessionDelegate

extension MultipeerCompanionTransport: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard admitsPeer(peerID.displayName) else { return }
        delegate?.companionTransport(self, peer: peerID.displayName, didChangeState: state)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard admitsPeer(peerID.displayName) else { return }
        delegate?.companionTransport(self, didReceive: data, fromPeer: peerID.displayName)
    }

    public func session(
        _ session: MCSession,
        didReceive stream: InputStream,
        withName streamName: String,
        fromPeer peerID: MCPeerID
    ) {}

    public func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    public func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: (any Error)?
    ) {}
}

// MARK: - Advertiser / browser delegates

extension MultipeerCompanionTransport: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        // Unpaired peers are rejected: only a device bound to the live
        // QR-shared key gets a channel. Payload trust stays above this
        // layer, so a rejected peer learns nothing.
        guard admitsPeer(peerID.displayName) else {
            invitationHandler(false, nil)
            return
        }
        invitationHandler(true, session)
    }
}

extension MultipeerCompanionTransport: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        // Invite only bound peers: no channel is opened to unpaired devices.
        guard admitsPeer(peerID.displayName) else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
