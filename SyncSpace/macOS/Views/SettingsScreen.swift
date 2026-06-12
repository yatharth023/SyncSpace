//
//  SettingsScreen.swift
//  SyncSpace
//
//  Real, working settings. Theme switches via AppStorage (applied at scene
//  root by `.appearancePreference()`). All buttons perform actions.
//

#if os(macOS)
import SwiftUI
import SwiftData
import UserNotifications
import AppKit

struct SettingsScreen: View {
    @Bindable var model: AppModel
    @Environment(\.modelContext) private var modelContext

    @AppStorage(AppearanceStorage.key) private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage("syncspace.notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("syncspace.autoStartAudio") private var autoStartAudio: Bool = true
    @AppStorage("syncspace.autoPair") private var autoPair: Bool = true

    @State private var exportMessage: String?
    @State private var exportError: String?
    @State private var showAbout: Bool = false
    @State private var showResetConfirm: Bool = false
    @State private var showClearHistoryConfirm: Bool = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                ScreenHeader(
                    title: "Settings",
                    subtitle: "Adjust appearance, connections, audio, and data."
                )

                appearanceSection
                connectionSection
                audioSection
                sessionSection
                notificationSection
                dataSection
                aboutSection
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task {
            await refreshNotificationStatus()
            // Re-check while the user is in Settings — they may grant
            // permission via System Settings and come back.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await refreshNotificationStatus()
            }
        }
        .sheet(isPresented: $showAbout) { AboutSheet() }
        .alert("Reset preferences?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetPreferences() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This restores theme, notification, audio, and session preferences to their defaults. Tasks and session history are kept.")
        }
        .alert("Clear session history?", isPresented: $showClearHistoryConfirm) {
            Button("Delete", role: .destructive) { model.clearSessionHistory() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes all completed-session records used for analytics.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        section("Appearance") {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearance.wrappedValue = mode
                    } label: {
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: mode.symbol)
                                .font(.title3)
                                .symbolRenderingMode(.hierarchical)
                            Text(mode.label).font(.callout.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(appearance.wrappedValue == mode ? AppTheme.accent.opacity(0.22) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(appearance.wrappedValue == mode ? AppTheme.accent : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .animation(DS.Motion.calm, value: appearance.wrappedValue)
                }
            }
        }
    }

    // MARK: Connection

    private var connectionSection: some View {
        section("Connection") {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: model.peerManager.status.symbol)
                    .foregroundStyle(model.peerManager.status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.peerManager.status.title).font(.callout.weight(.semibold))
                    Text(connectionDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.peerManager.status == .offline ? "Start" : "Restart") {
                    model.peerManager.restart()
                }
                .buttonStyle(.bordered)
            }
            Toggle("Auto-pair with nearby SyncSpace devices", isOn: $autoPair)
                .tint(AppTheme.accent)
            if let error = model.peerManager.lastError {
                Text(error).font(.caption).foregroundStyle(AppTheme.error)
            }
        }
    }

    private var connectionDescription: String {
        switch model.peerManager.status {
        case .connected:     return "Linked to \(model.peerManager.connectedPeerNames.joined(separator: ", "))"
        case .advertising:   return "Open SyncSpace Remote on your iPhone."
        case .browsing:      return "Searching nearby devices."
        case .connecting:    return "Negotiating secure session."
        case .reconnecting:  return "Link dropped — reconnecting automatically."
        case .offline:       return "Networking is paused."
        }
    }

    // MARK: Audio

    private var audioSection: some View {
        section("Audio") {
            Toggle("Run audio engine on launch", isOn: $autoStartAudio)
                .tint(AppTheme.accent)
                .onChange(of: autoStartAudio) { _, newValue in
                    if newValue {
                        model.audioEngine?.start()
                        model.audioEngine?.apply(model.mix)
                    } else {
                        model.audioEngine?.stop()
                    }
                }
            HStack {
                Text("Engine status")
                    .foregroundStyle(.secondary)
                Spacer()
                let running = model.audioEngine?.isRunning ?? false
                Text(running ? "Running" : "Stopped")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(running ? AppTheme.mint.opacity(0.20) : Color.primary.opacity(0.08)))
                    .foregroundStyle(running ? AppTheme.mint : .secondary)
            }
            if let err = model.audioEngine?.lastError {
                Text(err).font(.caption).foregroundStyle(AppTheme.error)
            }
        }
    }

    // MARK: Session preferences

    private var sessionSection: some View {
        section("Session preferences") {
            HStack {
                Text("Default custom duration")
                Spacer()
                Stepper("\(model.customDurationMinutes) min", value: Binding(
                    get: { model.customDurationMinutes },
                    set: { model.setCustomDuration(minutes: $0) }
                ), in: 5...180, step: 5)
            }
            Toggle("Haptic cues on connected devices", isOn: $model.hapticsEnabled)
                .tint(AppTheme.accent)
            Toggle("Play completion glow", isOn: $model.soundOnComplete)
                .tint(AppTheme.accent)
        }
    }

    // MARK: Notifications

    private var notificationSection: some View {
        section("Notifications") {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Status row — vertical layout so text and value never
                // collide and the icon has room to breathe.
                HStack(alignment: .center, spacing: DS.Spacing.md) {
                    Image(systemName: notificationStatus.iconName)
                        .font(.title2)
                        .foregroundStyle(notificationStatus.tint)
                        .frame(width: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notification Status")
                            .font(.callout.weight(.semibold))
                        Text(notificationStatus.displayName)
                            .font(.subheadline)
                            .foregroundStyle(notificationStatus.tint)
                    }
                    Spacer(minLength: 0)
                }

                if !notificationStatus.isAuthorized {
                    Button {
                        handlePermissionAction()
                    } label: {
                        Label(permissionActionTitle, systemImage: "bell.badge")
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs - 2)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }

                if notificationStatus.isAuthorized {
                    Toggle("Notify when a session completes", isOn: $notificationsEnabled)
                        .tint(AppTheme.accent)
                }
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
    }

    private var permissionActionTitle: String {
        notificationStatus == .notDetermined ? "Allow Notifications" : "Open System Settings"
    }

    private func handlePermissionAction() {
        if notificationStatus == .notDetermined {
            Task { await requestNotificationPermission() }
        } else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: Data

    private var dataSection: some View {
        section("Data") {
            HStack {
                Text("Export session history as JSON")
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    exportHistory()
                } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }
            if let msg = exportMessage {
                Text(msg).font(.caption).foregroundStyle(AppTheme.mint)
            }
            if let err = exportError {
                Text(err).font(.caption).foregroundStyle(AppTheme.error)
            }
            Divider().opacity(0.3)
            HStack {
                Text("Clear all session-history records")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    showClearHistoryConfirm = true
                } label: {
                    Label("Clear history", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            HStack {
                Text("Reset all preferences to defaults")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: About

    private var aboutSection: some View {
        section("About") {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.sessionGradient)
                        .frame(width: 28, height: 28)
                    Image(systemName: "circle.hexagongrid.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 12, weight: .semibold))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("SyncSpace").font(.callout.weight(.semibold))
                    Text("Your focus session. Synchronised everywhere.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("About") { showAbout = true }.buttonStyle(.bordered)
                Text("v1.0").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Helpers

    private func exportHistory() {
        exportError = nil
        exportMessage = nil
        do {
            let url = try model.exportSessionHistory()
            // Reveal in Finder for clarity.
            NSWorkspace.shared.activateFileViewerSelecting([url])
            exportMessage = "Saved to \(url.path)"
        } catch {
            exportError = "Couldn't export: \(error.localizedDescription)"
        }
    }

    private func resetPreferences() {
        appearanceRaw = AppearanceMode.system.rawValue
        notificationsEnabled = false
        autoStartAudio = true
        autoPair = true
        model.customDurationMinutes = 30
        model.hapticsEnabled = true
        model.soundOnComplete = true
    }

    private func refreshNotificationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
        if !settings.authorizationStatus.isAuthorized {
            notificationsEnabled = false
        }
    }

    private func requestNotificationPermission() async {
        _ = await NotificationService.requestAuthorization()
        await refreshNotificationStatus()
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .tracking(0.5)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                content()
            }
            .padding(DS.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }
}

// MARK: - About sheet

private struct AboutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.sessionGradient)
                    .frame(width: 72, height: 72)
                    .shadow(color: AppTheme.electricIndigo.opacity(0.5), radius: 14, y: 4)
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 32, weight: .semibold))
            }
            VStack(spacing: DS.Spacing.xs) {
                Text("SyncSpace").font(.title.weight(.bold))
                Text("Your focus session. Synchronised everywhere.")
                    .foregroundStyle(.secondary)
                Text("Version 1.0").font(.caption).foregroundStyle(.secondary)
            }
            Text("SyncSpace pairs a Mac focus hub with an iPhone remote over peer-to-peer Wi-Fi. No internet required.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            HStack(spacing: DS.Spacing.sm) {
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
    }
}
#endif
