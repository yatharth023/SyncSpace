//
//  ConnectionBadge.swift
//  SyncSpace
//

import SwiftUI

public struct ConnectionBadge: View {
    public let status: ConnectionStatus
    public let peerNames: [String]
    public var compact: Bool = false

    public init(status: ConnectionStatus, peerNames: [String], compact: Bool = false) {
        self.status = status
        self.peerNames = peerNames
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(status.tint)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(status.tint.opacity(0.4), lineWidth: 1)
                        .scaleEffect(status == .connected ? 1.8 : 1.0)
                        .opacity(status == .connected ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false),
                            value: status
                        )
                )

            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.caption.weight(.semibold))
                    if status == .connected, let name = peerNames.first {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if status != .connected {
                        Text(secondaryText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, compact ? 8 : 12)
        .padding(.vertical, compact ? 6 : 8)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(status.tint.opacity(0.35), lineWidth: 1)
        )
    }

    private var secondaryText: String {
        switch status {
        case .offline:      return "Tap to connect"
        case .advertising:  return "Waiting for iPhone"
        case .browsing:     return "Looking for Mac"
        case .connecting:   return "Linking…"
        case .connected:    return "Synced"
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ConnectionBadge(status: .offline, peerNames: [])
        ConnectionBadge(status: .browsing, peerNames: [])
        ConnectionBadge(status: .connecting, peerNames: [])
        ConnectionBadge(status: .connected, peerNames: ["Yatharth's Mac"])
    }
    .padding(40)
    .background(Color.black)
}
