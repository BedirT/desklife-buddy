import Foundation
import MultipeerConnectivity

/// Proposed Bonjour rendezvous strings for the companion transport.
///
/// Owner sign-off pending (Epic 4 issue #5, gate Q1): these exact strings
/// are quoted in the wave-1 PR body and no Info.plist `NSBonjourServices`
/// entry is added until the owner approves them.
///
/// - `serviceType` follows the Bonjour 1–15 lowercase alnum-plus-hyphen rule
///   (`desklife-cmp` is 12 characters).
/// - `serviceDomain` is the standard link-local domain.
public enum CompanionServiceStrings {
    /// Proposed Bonjour service type. QUOTE IN PR: `"desklife-cmp"`.
    public static let serviceType = "desklife-cmp"
    /// Proposed Bonjour service domain. QUOTE IN PR: `"local."`.
    public static let serviceDomain = "local."
}

/// Receives session bytes from nearby peers on the Mac side.
public protocol MultipeerCompanionTransportDelegate: AnyObject {
    /// Codec-encoded session bytes arrived from a peer device UUID string.
    func companionTransport(_ transport: MultipeerCompanionTransport, didReceive data: Data, fromPeer peerID: String)
    /// A nearby peer's connectivity changed (useful for presence UI later).
    func companionTransport(_ transport: MultipeerCompanionTransport, peer peerID: String, didChangeState state: MCSessionState)
}

/// The MultipeerConnectivity transport: Mac-side advertiser + browser (Epic 4 wave 1).
///
/// This class moves opaque `Data` only. Framing stays in Domain
/// (`CompanionSessionCodec`): the composition root encodes envelopes before
/// calling `send` and decodes bytes delivered to the delegate. Invitation
/// acceptance here is connectivity only — payload trust comes from the
/// QR-shared pairing key (see `CompanionKeychainStore`), verified above
/// this layer.
///
/// Sandbox note: browsing/advertising/connecting needs the
/// `com.apple.security.network.client` entitlement, which the repo's
/// raw-import guard currently bans. The entitlement is PROPOSED in the
/// wave-1 PR body, not added here; discovery stays inert in sandboxed
/// builds until the owner signs off.
public final class MultipeerCompanionTransport: NSObject {
    private let peerID: MCPeerID
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let browser: MCNearbyServiceBrowser

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
        delegate?.companionTransport(self, peer: peerID.displayName, didChangeState: state)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
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
        // Connectivity only: accept the channel; payload trust is pairing-key
        // verification above this layer, so a stray peer learns nothing.
        invitationHandler(true, session)
    }
}

extension MultipeerCompanionTransport: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser,
        foundPeer peerID: MCPeerID,
        withDiscoveryInfo info: [String: String]?
    ) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
