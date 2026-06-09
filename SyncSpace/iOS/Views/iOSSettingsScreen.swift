//
//  iOSSettingsScreen.swift
//  SyncSpace
//

#if os(iOS)
import SwiftUI

struct iOSSettingsScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings")
                    .font(.title.weight(.bold))

                section("Connection") {
                    HStack {
                        Image(systemName: model.peerManager.status.symbol)
                            .foregroundStyle(model.peerManager.status.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.peerManager.status.title).font(.callout.weight(.semibold))
                            Text(connectionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restart") {
                            model.peerManager.stop()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                model.peerManager.start()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                    }
                    if !model.peerManager.discoveredPeerNames.isEmpty {
                        Divider().opacity(0.2)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Discovered")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(model.peerManager.discoveredPeerNames, id: \.self) { name in
                                HStack {
                                    Image(systemName: "desktopcomputer")
                                        .foregroundStyle(.secondary)
                                    Text(name)
                                    Spacer()
                                    Button("Connect") {
                                        model.peerManager.invite(peerNamed: name)
                                    }
                                    .buttonStyle(.borderless)
                                    .tint(AppTheme.accent)
                                }
                            }
                        }
                    }
                }

                section("Haptics") {
                    Toggle("Haptic feedback for events", isOn: $model.hapticsEnabled)
                        .tint(AppTheme.accent)
                    HStack {
                        Text("Test pattern")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Trigger") {
                            HapticManager.shared.trigger(.sessionCompleted)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.accent)
                    }
                }

                section("Display") {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(AppTheme.cyan)
                        Text("SyncSpace Remote uses a dark, ambient appearance optimised for low-light desk placement.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                section("About") {
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SyncSpace Remote").font(.callout.weight(.semibold))
                            Text("Pair with SyncSpace on your Mac to begin.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("v1.0").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }

    private var connectionDescription: String {
        switch model.peerManager.status {
        case .connected:
            return "Linked to \(model.peerManager.connectedPeerNames.joined(separator: ", "))"
        case .browsing:
            return "Searching for your Mac on Wi-Fi."
        case .connecting:
            return "Negotiating link…"
        case .advertising:
            return "Discoverable to nearby devices."
        case .offline:
            return "Networking is paused."
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}
#endif
