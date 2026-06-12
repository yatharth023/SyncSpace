//
//  PeerManager.swift
//  SyncSpace
//
//  Stable MultipeerConnectivity wrapper.
//
//  Earlier revisions fixed the "iPhone stuck on Connecting…" failure mode by
//  resetting stale status, adding a watchdog, and dropping
//  `MCEncryptionPreference` to `.none` for reliable handshakes on a
//  local-network productivity app.
//
//  This revision tightens four lingering issues:
//
//   1. Duplicate discoverables. MC publishes the same physical device under
//      separate `MCPeerID` instances when it sees the device over more than
//      one transport (Wi-Fi + AWDL/Bluetooth). De-duplication by MCPeerID
//      identity therefore failed. We now de-duplicate by `displayName` and
//      replace the stored peer with the most recently discovered one — that
//      MCPeerID is the one MC will accept invitations on.
//
//   2. Slow connection establishment. Invitation timeout 15s, watchdog 6s,
//      throttle 8s. With the host accepting immediately, a single failed
//      probe stalled the perceived flow for ~14s. Tighter constants here.
//
//   3. Stale `.connecting`. If MC silently fails to send `.notConnected`
//      after a dropped handshake, status pinned at `.connecting` until the
//      next watchdog tick. A connecting-watchdog now reverts to idle after
//      a hard ceiling so a fresh invite fires.
//
//   4. `lostPeer` left the entry in the discovered list. If a stale MCPeerID
//      is referenced by an in-flight invite, the session never completes.
//      `lostPeer` now updates state and clears the in-flight target.
//
//  An `os.Logger` is added so every transition is observable in Console.app
//  for future debugging.
//

import Foundation
import MultipeerConnectivity
import Observation
import os

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

private let log = Logger(subsystem: "com.yatharth.SyncSpace", category: "PeerManager")

@MainActor
@Observable
public final class PeerManager: NSObject {

    // MARK: Constants

    private static let serviceType = "syncspace"
    private static let heartbeatInterval: TimeInterval = 3.0
    // Tightened from 6s → 3s so a failed first invite re-fires within one
    // perceived "beat" instead of stalling the user.
    private static let watchdogInterval: TimeInterval = 3.0
    // Throttle stays a hair under inviteTimeout so we don't queue a second
    // invite while the first is still on the wire.
    private static let inviteThrottle: TimeInterval = 4.0
    private static let reconnectDelay: TimeInterval = 0.8
    private static let inviteTimeout: TimeInterval = 10.0
    /// Hard ceiling on `.connecting` before we drop back to idle and let the
    /// watchdog fire a fresh invite. MC sometimes swallows `notConnected`
    /// after a silent handshake failure; without this ceiling the UI sits on
    /// "Connecting…" indefinitely.
    private static let connectingCeiling: TimeInterval = 12.0

    // MARK: Identity

    public let role: PeerRole
    public let localPeerID: MCPeerID

    // MARK: Observable state

    public private(set) var status: ConnectionStatus = .offline
    public private(set) var connectedPeerNames: [String] = []
    public private(set) var discoveredPeerNames: [String] = []
    public private(set) var lastError: String?

    // MARK: Diagnostics (SyncDebugOverlay)

    public private(set) var totalSent: Int = 0
    public private(set) var totalReceived: Int = 0
    public private(set) var lastSentAt: Date?
    public private(set) var lastReceivedAt: Date?
    public private(set) var lastInviteAt: Date?
    public private(set) var lastInvitedPeerName: String?
    public private(set) var lastConnectionAttemptAt: Date?

    // MARK: Callbacks

    public var onReceiveMessage: ((SyncMessage) -> Void)?
    public var onConnect: (() -> Void)?
    public var onDisconnect: (() -> Void)?

    // MARK: MC plumbing

    nonisolated private let session: MCSession
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var watchdogTask: Task<Void, Never>?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var discoveredPeers: [MCPeerID] = []
    @ObservationIgnored private var hasReceivedFirstConnect: Bool = false
    @ObservationIgnored private var connectingStartedAt: Date?
    @ObservationIgnored private var inFlightInviteTarget: MCPeerID?

    private let encoder = JSONEncoder()

    // MARK: Init

    public init(role: PeerRole, displayName: String? = nil) {
        self.role = role
        let resolvedName = displayName ?? Self.defaultDeviceName()
        self.localPeerID = MCPeerID(displayName: resolvedName)
        // `.none` is materially more reliable than `.optional` for our P2P
        // use case. Local-network app, no sensitive payloads — encryption
        // negotiation stalls were producing the "stuck on Connecting…" bug.
        self.session = MCSession(peer: localPeerID,
                                 securityIdentity: nil,
                                 encryptionPreference: .none)
        super.init()
        self.session.delegate = self
        log.info("PeerManager init role=\(role.rawValue, privacy: .public) name=\(resolvedName, privacy: .public)")
    }

    // MARK: Lifecycle

    public func start() {
        log.info("start() role=\(self.role.rawValue, privacy: .public)")
        stopDiscovery()
        discoveredPeers.removeAll()
        discoveredPeerNames = []
        lastError = nil

        switch role {
        case .host:
            startAdvertising()
            status = (advertiser != nil) ? .advertising : .offline
        case .remote:
            startBrowsing()
            startWatchdog()
            status = (browser != nil) ? .browsing : .offline
        }
    }

    public func stop() {
        log.info("stop()")
        reconnectTask?.cancel(); reconnectTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        watchdogTask?.cancel();  watchdogTask = nil
        stopDiscovery()
        session.disconnect()
        discoveredPeers.removeAll()
        discoveredPeerNames = []
        connectedPeerNames = []
        inFlightInviteTarget = nil
        connectingStartedAt = nil
        status = .offline
    }

    /// Atomic restart used by the connection-restart button. Avoids the
    /// `stop()`-then-asyncAfter-`start()` dance that callers were doing
    /// inline (and which left a window where MC reported stale state).
    public func restart() {
        log.info("restart()")
        stop()
        start()
    }

    private func stopDiscovery() {
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
    }

    private func startAdvertising() {
        let adv = MCNearbyServiceAdvertiser(
            peer: localPeerID,
            discoveryInfo: ["role": PeerRole.host.rawValue],
            serviceType: Self.serviceType
        )
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv
        log.info("Advertising started")
    }

    private func startBrowsing() {
        let br = MCNearbyServiceBrowser(peer: localPeerID, serviceType: Self.serviceType)
        br.delegate = self
        br.startBrowsingForPeers()
        browser = br
        log.info("Browsing started")
    }

    /// Reset status to its natural idle value when there is no in-flight or
    /// established link. Only `.connected` and `.reconnecting` are preserved.
    private func revertToIdle() {
        guard status != .connected && status != .reconnecting else { return }
        switch role {
        case .host:   status = (advertiser != nil) ? .advertising : .offline
        case .remote: status = (browser != nil)    ? .browsing    : .offline
        }
    }

    // MARK: Outbound

    @discardableResult
    public func send(_ message: SyncMessage) -> Bool {
        sendInternal(message, reliable: true)
    }

    @discardableResult
    public func sendUnreliable(_ message: SyncMessage) -> Bool {
        sendInternal(message, reliable: false)
    }

    private func sendInternal(_ message: SyncMessage, reliable: Bool) -> Bool {
        guard !session.connectedPeers.isEmpty else { return false }
        do {
            let data = try encoder.encode(message)
            try session.send(data,
                             toPeers: session.connectedPeers,
                             with: reliable ? .reliable : .unreliable)
            totalSent &+= 1
            lastSentAt = .now
            return true
        } catch {
            lastError = "Send failed: \(error.localizedDescription)"
            log.error("Send failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func invite(peerNamed name: String) {
        guard let peer = discoveredPeers.first(where: { $0.displayName == name }) else { return }
        invite(peer: peer)
    }

    private func invite(peer: MCPeerID) {
        guard let browser else { return }
        guard !session.connectedPeers.contains(peer) else { return }
        status = .connecting
        connectingStartedAt = .now
        inFlightInviteTarget = peer
        lastInviteAt = .now
        lastInvitedPeerName = peer.displayName
        lastConnectionAttemptAt = .now
        log.info("Invite → \(peer.displayName, privacy: .public)")
        browser.invitePeer(peer, to: session, withContext: nil, timeout: Self.inviteTimeout)
    }

    // MARK: Heartbeat / watchdog / reconnect

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.heartbeatInterval * 1_000_000_000))
                guard let self else { return }
                await MainActor.run {
                    guard self.status == .connected else { return }
                    _ = self.sendUnreliable(.heartbeat)
                }
            }
        }
    }

    private func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.watchdogInterval * 1_000_000_000))
                guard let self else { return }
                await MainActor.run { self.watchdogTick() }
            }
        }
    }

    /// Re-invite the first discovered host peer if we're not yet connected.
    /// Throttled so we don't queue duplicate invites within a single MC
    /// invitation window. Also enforces a hard ceiling on `.connecting` —
    /// MC occasionally swallows `notConnected` after a silent handshake
    /// failure, leaving the UI pinned.
    private func watchdogTick() {
        guard role == .remote else { return }

        // Connecting-ceiling: if we've been "Connecting…" for too long
        // without ever entering `.connected`, drop back to browsing so a
        // fresh invite can fire. session.connectedPeers stays empty across
        // these failed handshakes.
        if status == .connecting,
           session.connectedPeers.isEmpty,
           let started = connectingStartedAt,
           Date.now.timeIntervalSince(started) > Self.connectingCeiling {
            log.info("Connecting ceiling exceeded — reverting to idle")
            inFlightInviteTarget = nil
            connectingStartedAt = nil
            revertToIdle()
        }

        guard session.connectedPeers.isEmpty else { return }
        guard !discoveredPeers.isEmpty else { return }
        guard browser != nil else { return }

        if let last = lastInviteAt,
           Date.now.timeIntervalSince(last) < Self.inviteThrottle {
            return
        }

        // Pick the first discovered peer. If we ever support more than one
        // host on the same Wi-Fi, this becomes a user choice.
        let peer = discoveredPeers[0]
        log.info("Watchdog re-invite → \(peer.displayName, privacy: .public) (status=\(self.status.rawValue, privacy: .public))")
        invite(peer: peer)
    }

    private func scheduleReconnect() {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.reconnectDelay * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            await MainActor.run {
                guard self.status == .reconnecting else { return }
                log.info("Reconnect tick — restarting discovery")
                self.start()
            }
        }
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
        let connectedNames = session.connectedPeers.map(\.displayName)
        let stateName: String
        switch state {
        case .connected:    stateName = "connected"
        case .connecting:   stateName = "connecting"
        case .notConnected: stateName = "notConnected"
        @unknown default:   stateName = "unknown"
        }
        log.info("Session ⇄ \(peerID.displayName, privacy: .public) → \(stateName, privacy: .public)")

        Task { @MainActor in
            self.connectedPeerNames = connectedNames
            switch state {
            case .connected:
                let wasReconnecting = (self.status == .reconnecting || self.status == .connecting)
                self.status = .connected
                self.lastError = nil
                self.connectingStartedAt = nil
                self.inFlightInviteTarget = nil
                self.startHeartbeat()
                if !self.hasReceivedFirstConnect || wasReconnecting {
                    self.hasReceivedFirstConnect = true
                }
                self.onConnect?()

            case .connecting:
                if self.status != .connecting {
                    self.connectingStartedAt = .now
                }
                self.status = .connecting
                self.lastConnectionAttemptAt = .now

            case .notConnected:
                self.stopHeartbeat()
                self.inFlightInviteTarget = nil
                self.connectingStartedAt = nil
                if connectedNames.isEmpty {
                    if self.hasReceivedFirstConnect {
                        // Lost an established link — go into auto-reconnect.
                        self.status = .reconnecting
                        self.onDisconnect?()
                        self.scheduleReconnect()
                    } else {
                        // Handshake failed before we ever linked. Drop back
                        // to idle so the watchdog can retry. The previous
                        // version left status pinned at .connecting here,
                        // which is what caused the iOS "stuck" bug.
                        self.revertToIdle()
                    }
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
            self.totalReceived &+= 1
            self.lastReceivedAt = .now
            switch message {
            case .heartbeat: break
            default:         self.onReceiveMessage?(message)
            }
        }
    }

    nonisolated public func session(_ session: MCSession,
                                    didReceive stream: InputStream,
                                    withName streamName: String,
                                    fromPeer peerID: MCPeerID) {}

    nonisolated public func session(_ session: MCSession,
                                    didStartReceivingResourceWithName resourceName: String,
                                    fromPeer peerID: MCPeerID,
                                    with progress: Progress) {}

    nonisolated public func session(_ session: MCSession,
                                    didFinishReceivingResourceWithName resourceName: String,
                                    fromPeer peerID: MCPeerID,
                                    at localURL: URL?,
                                    withError error: Error?) {}
}

// MARK: - Advertiser delegate (host)

extension PeerManager: MCNearbyServiceAdvertiserDelegate {

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                       didReceiveInvitationFromPeer peerID: MCPeerID,
                                       withContext context: Data?,
                                       invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        log.info("Invitation ⇠ \(peerID.displayName, privacy: .public) — accepting")
        // Accept synchronously on whatever queue MC dispatched us on. Any
        // delay here (e.g. MainActor hop) was previously enough to produce
        // fragile connections.
        invitationHandler(true, self.session)
        Task { @MainActor in
            self.status = .connecting
            self.lastConnectionAttemptAt = .now
        }
    }

    nonisolated public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                       didNotStartAdvertisingPeer error: Error) {
        let description = error.localizedDescription
        log.error("Advertiser failed: \(description, privacy: .public)")
        Task { @MainActor in
            self.lastError = "Advertise failed: \(description)"
            self.status = .offline
        }
    }
}

// MARK: - Browser delegate (remote)

extension PeerManager: MCNearbyServiceBrowserDelegate {

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    foundPeer peerID: MCPeerID,
                                    withDiscoveryInfo info: [String: String]?) {
        let isHost = info?["role"] == PeerRole.host.rawValue
        log.info("Discovered \(peerID.displayName, privacy: .public) host=\(isHost, privacy: .public)")
        Task { @MainActor in
            // De-duplicate by displayName. MC publishes the same physical
            // device under separate MCPeerID instances when it's reachable
            // over more than one transport (Wi-Fi + AWDL/Bluetooth), so
            // identity comparison alone misses these duplicates. When we
            // see a fresh MCPeerID for an already-known displayName we
            // REPLACE the stored one — the newer ID is the one MC will
            // route invitations through.
            let displayName = peerID.displayName
            if let existingIndex = self.discoveredPeers.firstIndex(where: { $0.displayName == displayName }) {
                self.discoveredPeers[existingIndex] = peerID
            } else {
                self.discoveredPeers.append(peerID)
            }
            self.refreshDiscoveredNames()

            guard isHost else { return }
            guard !self.session.connectedPeers.contains(peerID) else { return }
            // Auto-invite only when we're not already inside an attempt.
            // The watchdog handles retries on a fixed cadence so we don't
            // pile invites on top of each other if foundPeer fires twice.
            if self.status == .browsing || self.status == .reconnecting {
                self.invite(peer: peerID)
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    lostPeer peerID: MCPeerID) {
        log.info("Lost \(peerID.displayName, privacy: .public)")
        Task { @MainActor in
            let displayName = peerID.displayName
            self.discoveredPeers.removeAll { $0.displayName == displayName }
            self.refreshDiscoveredNames()
            // If we were trying to connect to exactly this peer, drop the
            // in-flight marker so the watchdog can immediately target the
            // next discovery without waiting on a dead invite to time out.
            if let target = self.inFlightInviteTarget, target.displayName == displayName {
                self.inFlightInviteTarget = nil
                if self.status == .connecting {
                    self.connectingStartedAt = nil
                    self.revertToIdle()
                }
            }
        }
    }

    nonisolated public func browser(_ browser: MCNearbyServiceBrowser,
                                    didNotStartBrowsingForPeers error: Error) {
        let description = error.localizedDescription
        log.error("Browser failed: \(description, privacy: .public)")
        Task { @MainActor in
            self.lastError = "Browse failed: \(description)"
            self.status = .offline
        }
    }
}
