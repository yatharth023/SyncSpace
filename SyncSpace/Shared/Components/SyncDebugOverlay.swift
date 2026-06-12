//
//  SyncDebugOverlay.swift
//  SyncSpace
//
//  DEBUG-only diagnostics chip. Now surfaces enough state to triage future
//  connectivity bugs without firing up Console.app: discovered peers, last
//  invitation, last error, and the live sent/received counters.
//

import SwiftUI

public struct SyncDebugOverlay: View {

    @Bindable var model: AppModel
    @State private var expanded: Bool = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 0) {
            header
            if expanded { details.padding(.top, DS.Spacing.xs) }
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
        )
        .padding(DS.Spacing.sm)
        .frame(maxWidth: 320, alignment: .leading)
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var header: some View {
        Button {
            expanded.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(model.peerManager.status.tint)
                    .frame(width: 6, height: 6)
                Text(model.peerManager.status.title)
                    .font(.system(size: 10, weight: .semibold))
                Text("\(model.peerManager.totalSent)↑ \(model.peerManager.totalReceived)↓")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sync diagnostics")
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 3) {
            row("Role",      model.role == .host ? "Host (Mac)" : "Remote (iPhone)")
            row("Status",    model.peerManager.status.title)
            row("Peer",      model.peerManager.connectedPeerNames.first ?? "—")
            row("Found",     discoveredSummary)
            row("Invite",    inviteSummary)
            row("Attempt",   relative(model.peerManager.lastConnectionAttemptAt))
            row("Sent",      "\(model.peerManager.totalSent)  last \(relative(model.peerManager.lastSentAt))")
            row("Recv",      "\(model.peerManager.totalReceived)  last \(relative(model.peerManager.lastReceivedAt))")
            row("Timer",     "\(TimeFormatter.clock(model.timer.remainingTime))  \(model.timer.isRunning ? "RUN" : "IDLE")")
            row("Tasks",     "\(model.tasks.count)")
            if let err = model.peerManager.lastError, !err.isEmpty {
                row("Error", err).foregroundStyle(AppTheme.error)
            }
            if let last = model.lastCompletionAt {
                row("Done",  relative(last))
            }
        }
    }

    private var discoveredSummary: String {
        let names = model.peerManager.discoveredPeerNames
        if names.isEmpty { return "—" }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names.prefix(2).joined(separator: ", ")) +\(names.count - 2)"
    }

    private var inviteSummary: String {
        guard let name = model.peerManager.lastInvitedPeerName else { return "—" }
        return "\(name)  \(relative(model.peerManager.lastInviteAt))"
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(key)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Text(value)
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    private func relative(_ date: Date?) -> String {
        guard let date else { return "—" }
        let delta = Int(Date.now.timeIntervalSince(date))
        if delta < 1 { return "now" }
        if delta < 60 { return "\(delta)s ago" }
        return "\(delta / 60)m ago"
    }
}
