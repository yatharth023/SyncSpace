//
//  MacSidebar.swift
//  SyncSpace
//

#if os(macOS)
import SwiftUI

struct MacSidebar: View {
    @Binding var selection: MacDestination
    let model: AppModel
    @Namespace private var selectionNS

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            VStack(spacing: 4) {
                ForEach(MacDestination.allCases) { dest in
                    SidebarRow(
                        destination: dest,
                        isSelected: selection == dest,
                        namespace: selectionNS
                    ) {
                        withAnimation(.smooth(duration: 0.32)) {
                            selection = dest
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            Spacer()

            statusFooter
        }
        .background(.thinMaterial)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.sessionGradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: AppTheme.electricIndigo.opacity(0.5), radius: 10)
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("SyncSpace")
                        .font(.headline)
                    Text("Focus Hub")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 10)
        }
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().opacity(0.2)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(model.peerManager.status == .connected ? AppTheme.mint : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.peerManager.status.title)
                        .font(.caption.weight(.semibold))
                    Text(footerSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private var footerSubtitle: String {
        switch model.peerManager.status {
        case .connected:
            return model.peerManager.connectedPeerNames.first ?? "iPhone linked"
        case .advertising:
            return "Open SyncSpace on iPhone"
        case .browsing:
            return "Searching nearby…"
        case .connecting:
            return "Pairing securely"
        case .offline:
            return "Tap to discover"
        }
    }
}

private struct SidebarRow: View {
    let destination: MacDestination
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void
    @State private var hovering: Bool = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.accent.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.45), lineWidth: 1)
                        )
                        .matchedGeometryEffect(id: "sidebar-selection", in: namespace)
                }
                HStack(spacing: 10) {
                    Image(systemName: destination.symbol)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(isSelected ? AppTheme.accent : .primary.opacity(0.85))
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 22)
                    Text(destination.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
            }
            .contentShape(Rectangle())
            .background(
                hovering && !isSelected
                ? RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                : nil
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
#endif
