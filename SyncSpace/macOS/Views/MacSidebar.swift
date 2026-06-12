//
//  MacSidebar.swift
//  SyncSpace
//
//  Native macOS sidebar. Uses `List(selection:)` with `.listStyle(.sidebar)`
//  so the appearance matches Apple Music, Xcode, Things 3, Craft.
//  The previous version layered a custom RoundedRectangle as a selection
//  indicator — visually bulky and out of place on macOS.
//

#if os(macOS)
import SwiftUI

struct MacSidebar: View {
    @Binding var selection: MacDestination
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: $selection) {
                Section {
                    ForEach(MacDestination.allCases) { dest in
                        Label(dest.title, systemImage: dest.symbol)
                            .tag(dest)
                            .accessibilityLabel(dest.title)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            statusFooter
        }
    }

    // MARK: Header

    private var sidebarHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(AppTheme.sessionGradient)
                    .frame(width: 30, height: 30)
                    .shadow(color: AppTheme.electricIndigo.opacity(0.4), radius: 6, y: 2)
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .semibold))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("SyncSpace")
                    .font(.system(size: 13, weight: .semibold))
                Text("Focus Hub")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.md)
        .padding(.bottom, DS.Spacing.sm)
    }

    // MARK: Footer

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: model.peerManager.status == .connected
                      ? "iphone.gen3.radiowaves.left.and.right"
                      : "iphone.gen3.slash")
                    .font(.system(size: 14))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(model.peerManager.status == .connected ? AppTheme.mint : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(model.peerManager.status.title)
                        .font(.system(size: 11, weight: .semibold))
                    Text(footerSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private var footerSubtitle: String {
        switch model.peerManager.status {
        case .connected:     return model.peerManager.connectedPeerNames.first ?? "iPhone linked"
        case .advertising:   return "Open SyncSpace on iPhone"
        case .browsing:      return "Searching nearby"
        case .connecting:    return "Pairing securely"
        case .reconnecting:  return "Reconnecting…"
        case .offline:       return "Networking paused"
        }
    }
}
#endif
