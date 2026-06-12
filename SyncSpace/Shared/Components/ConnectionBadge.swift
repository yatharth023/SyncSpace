//
//  ConnectionBadge.swift
//  SyncSpace
//
//  Compact connection-status badge. The pulse ring only animates when
//  actually connected — previously it was animating in every state, which
//  forced layout work even while disconnected.
//

import SwiftUI

public struct ConnectionBadge: View {
    public let status: ConnectionStatus
    public let peerNames: [String]
    public var compact: Bool

    public init(status: ConnectionStatus, peerNames: [String], compact: Bool = false) {
        self.status = status
        self.peerNames = peerNames
        self.compact = compact
    }

    public var body: some View {
        HStack(spacing: compact ? DS.Spacing.xs : DS.Spacing.sm) {
            indicator

            if !compact {
                VStack(alignment: .leading, spacing: 1) {
                    Text(status.title)
                        .font(.caption.weight(.semibold))
                    Text(secondaryText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.horizontal, compact ? DS.Spacing.sm : DS.Spacing.md)
        .padding(.vertical, compact ? DS.Spacing.xs : DS.Spacing.xs + 2)
        .background(DS.Surface.chip, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(status.tint.opacity(0.30), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var indicator: some View {
        ZStack {
            if status == .connected {
                TimelineView(.animation(minimumInterval: 1.0 / 14.0, paused: false)) { ctx in
                    let phase = sin(ctx.date.timeIntervalSinceReferenceDate * 2) * 0.5 + 0.5
                    Circle()
                        .stroke(status.tint.opacity(0.45 - 0.35 * phase), lineWidth: 1)
                        .scaleEffect(1 + phase * 0.9)
                        .frame(width: 8, height: 8)
                }
            }
            Circle()
                .fill(status.tint)
                .frame(width: 8, height: 8)
        }
        .frame(width: 14, height: 14)
    }

    private var secondaryText: String {
        switch status {
        case .connected:     return peerNames.first ?? "Synced"
        case .offline:       return "Tap to connect"
        case .advertising:   return "Waiting for iPhone"
        case .browsing:      return "Looking for Mac"
        case .connecting:    return "Linking…"
        case .reconnecting:  return "Reconnecting…"
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
