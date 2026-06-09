//
//  SettingsScreen.swift
//  SyncSpace
//

#if os(macOS)
import SwiftUI
import SwiftData

struct SettingsScreen: View {
    @Bindable var model: AppModel
    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferredAppearance") private var preferredAppearance: String = "system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Settings")
                    .font(.largeTitle.weight(.bold))

                section("Appearance") {
                    Picker("Theme", selection: $preferredAppearance) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 380)
                }

                section("Connection") {
                    HStack {
                        Image(systemName: model.peerManager.status.symbol)
                            .foregroundStyle(model.peerManager.status.tint)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.peerManager.status.title).font(.callout.weight(.semibold))
                            Text(connectionDescription).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(model.peerManager.status == .offline ? "Start" : "Restart") {
                            model.peerManager.stop()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                model.peerManager.start()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    if let error = model.peerManager.lastError {
                        Text(error).font(.caption).foregroundStyle(AppTheme.error)
                    }
                }

                section("Audio") {
                    Toggle("Run audio engine while app is active", isOn: Binding(
                        get: { model.audioEngine?.isRunning ?? false },
                        set: { newValue in
                            if newValue { model.audioEngine?.start() }
                            else        { model.audioEngine?.stop() }
                        }
                    ))
                    .tint(AppTheme.accent)

                    if let err = model.audioEngine?.lastError {
                        Text(err).font(.caption).foregroundStyle(AppTheme.error)
                    }
                }

                section("Session preferences") {
                    HStack {
                        Text("Default custom duration")
                        Spacer()
                        Stepper("\(model.customDurationMinutes) min", value: Binding(
                            get: { model.customDurationMinutes },
                            set: { model.setCustomDuration(minutes: $0) }
                        ), in: 5...180, step: 5)
                    }
                    Toggle("Haptic feedback on connected devices", isOn: $model.hapticsEnabled)
                        .tint(AppTheme.accent)
                    Toggle("Play completion glow", isOn: $model.soundOnComplete)
                        .tint(AppTheme.accent)
                }

                section("Data") {
                    HStack {
                        Text("Session history is stored locally with SwiftData.")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Spacer()
                        Button(role: .destructive) {
                            clearHistory()
                        } label: {
                            Label("Clear history", systemImage: "trash")
                        }
                    }
                }

                section("About") {
                    HStack {
                        Image(systemName: "circle.hexagongrid.fill")
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SyncSpace").font(.callout.weight(.semibold))
                            Text("Your Focus Session. Synchronized Everywhere.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("v1.0").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(36)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var connectionDescription: String {
        switch model.peerManager.status {
        case .connected:
            return "Linked to \(model.peerManager.connectedPeerNames.joined(separator: ", "))"
        case .advertising:
            return "Open SyncSpace Remote on your iPhone."
        case .browsing:
            return "Searching nearby devices."
        case .connecting:
            return "Negotiating secure session."
        case .offline:
            return "Networking is paused."
        }
    }

    private func clearHistory() {
        let descriptor = FetchDescriptor<SessionRecord>()
        if let records = try? modelContext.fetch(descriptor) {
            records.forEach(modelContext.delete)
            try? modelContext.save()
            model.recalcAnalytics()
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}
#endif
