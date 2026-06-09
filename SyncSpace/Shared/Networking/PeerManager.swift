//
//  PeerManager.swift
//  SyncSpace
//
//  Thin wrapper around MultipeerConnectivity. Each device picks a role
//  (host = Mac, remote = iPhone) at launch. Hosts advertise; remotes browse.
//  The manager surfaces status, decoded inbound messages, and an outbound
//  send API as an @Observable state object.
//

import Foundation
import MultipeerConnectivity
import Observation

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

@MainActor
@Observable
public final class PeerManager: NSObject {

    // MARK: Configuration

    private static let serviceType = "syncspace"   // Bonjour _syncspace._tcp/_udp

    public let role: PeerRole
    public let localPeerID: MCPeerID

    // MARK: Published state

    public private(set) var status: ConnectionStatus = .offline
    public private(set) var connectedPeerNames: [String] = []
    public private(set) var discoveredPeerNames: [String] = []
    public private(set) var lastError: String?

    // MARK: Outbound message stream consumers

    public var onReceiveMessage: ((SyncMessage) -> Void)?

    // MARK: MC plumbing

    nonisolated private let session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    private var discoveredPeers: [MCPeerID] = []

    private let encoder = JSONEncoder()

    // MARK: Init

    public init(role: PeerRole, displayName: String? = nil) {
        self.role = role
        let resolvedName = displayName ?? Self.defaultDeviceName()
        self.localPeerID = MCPeerID(displayName: resolvedName)
        self.session = MCSession(peer: localPeerID,
                                 securityIdentity: nil,
                                 encryptionPreference: .required)
        super.init()
        self.session.delegate = self
    }

    // MCSession is autoreleased when the manager deallocates; we just need to
    // make sure long-running discovery is paused first via stop() before any
    // explicit teardown the caller wants.

    // MARK: Lifecycle

    public func start() {
        stop()
        switch role {
        case .host:
            let adv = MCNearbyServiceAdvertiser(peer: localPeerID,
                                                discoveryInfo: ["role": PeerRole.host.rawValue],
                                                serviceType: Self.serviceType)
            adv.delegate = self
            adv.startAdvertisingPeer()
            advertiser = adv
            status = .advertising
        case .remote:
            let br = MCNearbyServiceBrowser(peer: localPeerID,
                                            serviceType: Self.serviceType)
            br.delegate = self
            br.startBrowsingForPeers()
            browser = br
            status = .browsing
        }
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser = nil
        session.disconnect()
        connectedPeerNames = []
        discoveredPeers = []
        discoveredPeerNames = []
        status = .offline
    }

    // MARK: Sending

    @discardableResult
    public func send(_ message: SyncMessage) -> Bool {
        guard !session.connectedPeers.isEmpty else { return false }
        do {
            let data = try encoder.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            return true
        } catch {
            lastError = "Send failed: \(error.localizedDescription)"
            return false
        }
    }

    /// High-frequency outbound (e.g. slider drags). Uses unreliable transport
    /// so we never queue up stale frames.
    @discardableResult
    public func sendUnreliable(_ message: SyncMessage) -> Bool {
        guard !session.connectedPeers.isEmpty else { return false }
        do {
            let data = try encoder.encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .unreliable)
            return true
        } catch {
            lastError = "Send failed: \(error.localizedDescription)"
            return false
        }
    }

    public func invite(peerNamed name: String) {
        guard let peer = discoveredPeers.first(where: { $0.displayName == name }),
              let browser else { return }
        status = .connecting
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 15)
    }

    // MARK: Helpers

    private func refreshDiscoveredNames() {
        discoveredPeerNames = discoveredPeers.map(\.displayName)
    }

    private static func defaultDeviceName() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #elseif canImport(AppKit)
        return Host.current().localizedName ?? "Mac"
        #else
        return "SyncSpace"
        #endif
    }
}

// MARK: - MCSessionDelegate

extension PeerManager: MCSessionDelegate {

    nonisolated public func session(_ session: MCSession,
                                    peer peerID: MCPeerID,
                                    didChange state: MCSessionState) {
        let connected = session.connectedPeers.map(\.displayName)
        Task { @MainActor in
            self.connectedPeerNames = connected
            switch state {
            case .connected:
                self.status = .connected
            case .connecting:
                self.status = .connecting
            case .notConnected:
                if connected.isEmpty {
                    self.status = (self.role == .host) ? .advertising : .browsing
                } else {
                    self.status = .connected
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated public func session(_ session: MCSession,
                                    didReceive data: Data,
                                    fromPeer peerID: MCPeerID) {
        let decoder = JSONDecoder()
        guard let message = try? decoder.decode(SyncMessage.self, from: data) else { return }
        Task { @MainActor in
            self.onReceiveMessage?(message)
        }
    }

    nonisolated public func session(_ session: MCSession,
                                    didReceive stream: InputStream,
                                    withName streamName: String,
                                    fromPeer peerID: MCPeerID) { /* unused */ }

    nonisolated public func session(_ session: MCSession,
                                    didStartReceivingResourceWithName resourceName: String,
                                    fromPeer peerID: MCPeerID,
                                    with progress: Progress) { /* unused */ }

    nonisolated public func session(_ session: MCSession,
                                    didFinishReceivingResourceWithName resourceName: String,
                                    fromPeer peerID: MCPeerID,
                                    at localURL: URL?,
                                    withError error: Error?) { /* unused */ }
}

// MARK: - MCNearbyServiceAdvertiserDelegate (host)

extension PeerManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                       didReceiveInvitationFromPeer peerID: MCPeerID,
                                       withContext context: Data?,
                                       invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let session = self.session
        Task { @MainActor in
            self.status = .connecting
            invitationHandler(true, session)
        }
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                       didNotStartAdvertisingPeer error: Error) {
        let description = error.localizedDescription
        Task { @MainActor in
            self.lastError = "Advertise failed: \(description)"
            self.status = .offline
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate (remote)

extension PeerManager: MCNearbyServiceBrowserDelegate {

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    foundPeer peerID: MCPeerID,
                                    withDiscoveryInfo info: [String : String]?) {
        let isHost = info?["role"] == PeerRole.host.rawValue
        let session = self.session
        Task { @MainActor in
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
                self.refreshDiscoveredNames()
            }
            // Remote auto-invites the first host it sees so the user doesn't
            // need to tap anything; the host accepts automatically.
            if isHost, session.connectedPeers.isEmpty, self.status != .connecting {
                self.status = .connecting
                browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredPeers.removeAll { $0 == peerID }
            self.refreshDiscoveredNames()
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    didNotStartBrowsingForPeers error: Error) {
        let description = error.localizedDescription
        Task { @MainActor in
            self.lastError = "Browse failed: \(description)"
            self.status = .offline
        }
    }
}
