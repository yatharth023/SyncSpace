//
//  NotificationService.swift
//  SyncSpace
//
//  Thin wrapper around UNUserNotificationCenter so completion alerts feel the
//  same on Mac and iPhone. Authorisation is requested explicitly from
//  Settings; if it has been granted we deliver a local banner when the
//  session reaches zero.
//

import Foundation
import SwiftUI
import UserNotifications

#if canImport(AppKit)
import AppKit
#endif

public extension UNAuthorizationStatus {
    var isAuthorized: Bool {
        switch self {
        case .authorized, .provisional: return true
        default:                        return isEphemeralAuthorized
        }
    }

    // `.ephemeral` is iOS-only; isolating it keeps this file cross-platform.
    private var isEphemeralAuthorized: Bool {
        #if os(iOS)
        if #available(iOS 14, *) { return self == .ephemeral }
        #endif
        return false
    }

    var displayName: String {
        switch self {
        case .authorized:    return "Allowed"
        case .denied:        return "Not Allowed"
        case .notDetermined: return "Not Requested"
        case .provisional:   return "Provisional"
        default:             return isEphemeralAuthorized ? "Ephemeral" : "Unknown"
        }
    }

    var iconName: String {
        switch self {
        case .authorized, .provisional: return "bell.badge.fill"
        case .denied:                   return "bell.slash.fill"
        case .notDetermined:            return "bell"
        default:                        return isEphemeralAuthorized ? "bell.badge.fill" : "bell"
        }
    }

    var tint: Color {
        switch self {
        case .authorized, .provisional: return AppTheme.mint
        case .denied:                   return AppTheme.warning
        case .notDetermined:            return .secondary
        default:                        return isEphemeralAuthorized ? AppTheme.mint : .secondary
        }
    }
}

public enum NotificationService {

    public static let completionIdentifier = "com.yatharth.SyncSpace.sessionCompleted"

    public static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    @discardableResult
    public static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Fires a local banner notification announcing session completion.
    /// No-ops if the user hasn't authorised notifications.
    public static func notifyCompletion(of sessionType: SessionType) async {
        let status = await currentAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "\(sessionType.title) complete"
        content.body = "Nice work — your focus block just ended."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: completionIdentifier + "-" + UUID().uuidString,
            content: content,
            trigger: nil       // deliver immediately
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    /// Plays the system completion sound — useful when the app is foregrounded
    /// and a notification banner would feel redundant.
    public static func playCompletionSound() {
        #if canImport(AppKit)
        NSSound(named: "Glass")?.play()
        #endif
    }
}
