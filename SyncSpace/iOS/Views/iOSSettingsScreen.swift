//
//  iOSSettingsScreen.swift
//  SyncSpace
//
//  All controls are wired. Theme picker writes to the AppStorage key that
//  the Scene root reads, so changes apply immediately and persist.
//

#if os(iOS)
import SwiftUI
import UserNotifications
import UIKit

struct iOSSettingsScreen: View {
    @Bindable var model: AppModel

    @AppStorage(AppearanceStorage.key) private var appearanceRaw: String = AppearanceMode.system.rawValue
    @AppStorage("syncspace.notificationsEnabled") private var notificationsEnabled: Bool = false
    @AppStorage("syncspace.autoPair") private var autoPair: Bool = true

    @State private var showAbout = false
    @State private var showResetConfirm = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private var appearance: Binding<AppearanceMode> {
        Binding(
            get: { AppearanceMode(rawValue: appearanceRaw) ?? .system },
            set: { appearanceRaw = $0.rawValue }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                ScreenHeader(
                    title: "Settings",
                    subtitle: "Theme, haptics, connection."
                )

                appearanceSection
                connectionSection
                hapticsSection
                notificationSection
                preferencesSection
                aboutSection
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .scrollIndicators(.hidden)
        .task {
            await refreshNotificationStatus()
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
            Text("This restores appearance, notification, and connection preferences to their defaults.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        section("Appearance") {
            HStack(spacing: DS.Spacing.xs) {
                ForEach(AppearanceMode.allCases) { mode in
                    Button {
                        appearance.wrappedValue = mode
                    } label: {
                        VStack(spacing: DS.Spacing.xs) {
                            Image(systemName: mode.symbol).font(.title3).symbolRenderingMode(.hierarchical)
                            Text(mode.label).font(.caption.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .fill(appearance.wrappedValue == mode ? AppTheme.accent.opacity(0.20) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(appearance.wrappedValue == mode ? AppTheme.accent : Color.primary.opacity(0.08), lineWidth: 1)
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Connection

    private var connectionSection: some View {
        section("Connection") {
            HStack {
                Image(systemName: model.peerManager.status.symbol)
                    .foregroundStyle(model.peerManager.status.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.peerManager.status.title).font(.callout.weight(.semibold))
                    Text(connectionDescription).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Restart") {
                    model.peerManager.stop()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        model.peerManager.start()
                    }
                }
                .buttonStyle(.bordered).tint(AppTheme.accent)
            }
            Toggle("Auto-pair with nearby Mac", isOn: $autoPair).tint(AppTheme.accent)
            if !model.peerManager.discoveredPeerNames.isEmpty {
                Divider().opacity(0.3)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Discovered").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ForEach(model.peerManager.discoveredPeerNames, id: \.self) { name in
                        discoveryRow(name: name)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func discoveryRow(name: String) -> some View {
        let isLinked = model.peerManager.status == .connected
            && model.peerManager.connectedPeerNames.contains(name)
        let isInFlight = model.peerManager.status.isInFlight
            && !model.peerManager.connectedPeerNames.isEmpty == false
        HStack {
            Image(systemName: "desktopcomputer").foregroundStyle(.secondary)
            Text(name)
            Spacer()
            if isLinked {
                Label("Connected", systemImage: "checkmark.circle.fill")
                    .labelStyle(.titleAndIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.mint)
            } else if isInFlight {
                HStack(spacing: 4) {
                    ProgressView().controlSize(.mini)
                    Text(model.peerManager.status.buttonLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("Connect") { model.peerManager.invite(peerNamed: name) }
                    .buttonStyle(.borderless)
                    .tint(AppTheme.accent)
            }
        }
    }

    private var connectionDescription: String {
        switch model.peerManager.status {
        case .connected:     return "Linked to \(model.peerManager.connectedPeerNames.joined(separator: ", "))"
        case .browsing:      return "Searching for your Mac on Wi-Fi."
        case .connecting:    return "Negotiating link…"
        case .reconnecting:  return "Link interrupted — reconnecting…"
        case .advertising:   return "Discoverable to nearby devices."
        case .offline:       return "Networking is paused."
        }
    }

    // MARK: Haptics

    private var hapticsSection: some View {
        section("Haptics") {
            Toggle("Haptic feedback for events", isOn: $model.hapticsEnabled)
                .tint(AppTheme.accent)
            HStack {
                Text("Test pattern").foregroundStyle(.secondary)
                Spacer()
                Button("Trigger") { HapticManager.shared.trigger(.sessionCompleted) }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
            }
        }
    }

    // MARK: Notifications

    private var notificationSection: some View {
        section("Notifications") {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.xs)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }

                if notificationStatus.isAuthorized {
                    Toggle("Notify on session completion", isOn: $notificationsEnabled)
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
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: Preferences

    private var preferencesSection: some View {
        section("Preferences") {
            HStack {
                Text("Reset preferences").foregroundStyle(.secondary)
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
                    Text("SyncSpace Remote").font(.callout.weight(.semibold))
                    Text("Pair with SyncSpace on your Mac.")
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

    private func resetPreferences() {
        appearanceRaw = AppearanceMode.system.rawValue
        notificationsEnabled = false
        autoPair = true
        model.hapticsEnabled = true
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
            .padding(DS.Spacing.md)
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
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundStyle(.white)
                    .font(.system(size: 30, weight: .semibold))
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
                .padding(.horizontal, DS.Spacing.md)
            Button("Done") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
        }
        .padding(DS.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.background)
    }
}
#endif
