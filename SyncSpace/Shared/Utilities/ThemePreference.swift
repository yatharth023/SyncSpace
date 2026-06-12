//
//  ThemePreference.swift
//  SyncSpace
//
//  Single source of truth for app appearance.
//
//  Two earlier iterations of this file applied the theme through *two*
//  competing channels: SwiftUI's `.preferredColorScheme(...)` AND
//  AppKit's `NSApp.appearance` / UIKit's `UIWindow.overrideUserInterfaceStyle`.
//  When the user picked Light → System on macOS, the SwiftUI path tried to
//  clear via `preferredColorScheme(nil)` (which on macOS does NOT reliably
//  invalidate a previously-stamped `.light` override), while the AppKit
//  path correctly cleared `NSApp.appearance`. The two paths diverged: the
//  window chrome and any `NSVisualEffectView`-backed Material followed the
//  system, but SwiftUI views still reading `Environment(\.colorScheme)`
//  stayed pinned on `.light`. That is the "window dark, cards light,
//  materials mixed" symptom from the screenshot.
//
//  This revision uses ONE channel: `.preferredColorScheme(...)` with an
//  *always-explicit* value (never nil). For System mode we resolve the
//  live OS appearance via `ThemeBridge`, which KVO-observes
//  `NSApp.effectiveAppearance` on macOS so live OS light/dark toggles
//  propagate immediately. SwiftUI never sees a `nil` transition, so its
//  cached override is always invalidated correctly.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Mode

public enum AppearanceMode: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    public var symbol: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    /// Convenience used in places that still want the raw optional form.
    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

public enum AppearanceStorage {
    public static let key = "syncspace.appearance"
}

// MARK: - System-appearance bridge

/// Observes the host OS's current appearance and republishes it as a
/// SwiftUI-friendly `ColorScheme`. Lets us pass an explicit value to
/// `.preferredColorScheme` even when the user has picked System mode, so
/// SwiftUI's override invalidation works correctly on macOS.
@MainActor
@Observable
public final class ThemeBridge {

    public static let shared = ThemeBridge()

    public private(set) var systemColorScheme: ColorScheme

    #if canImport(AppKit)
    @ObservationIgnored private var appearanceObservation: NSKeyValueObservation?
    @ObservationIgnored private var launchObserver: NSObjectProtocol?
    #endif

    private init() {
        self.systemColorScheme = Self.detectSystemScheme()
        attachObservers()
    }

    public func refresh() {
        let resolved = Self.detectSystemScheme()
        if resolved != systemColorScheme {
            systemColorScheme = resolved
        }
    }

    // MARK: - Detection

    private static func detectSystemScheme() -> ColorScheme {
        #if canImport(AppKit)
        // `NSApp` may not be ready during early init; fall back to .light.
        guard let appearance = NSApp?.effectiveAppearance else { return .light }
        let best = appearance.bestMatch(from: [.aqua, .darkAqua])
        return (best == .darkAqua) ? .dark : .light
        #elseif canImport(UIKit)
        let style: UIUserInterfaceStyle = {
            if let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState != .unattached }),
               let window = scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first {
                return window.traitCollection.userInterfaceStyle
            }
            return UITraitCollection.current.userInterfaceStyle
        }()
        return (style == .dark) ? .dark : .light
        #else
        return .light
        #endif
    }

    // MARK: - Observation

    private func attachObservers() {
        #if canImport(AppKit)
        if NSApp != nil {
            installAppearanceKVO()
        } else {
            // Singleton may be touched before `NSApplication.shared` exists
            // (during app launch). Defer KVO setup until launch.
            launchObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didFinishLaunchingNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.installAppearanceKVO()
                    self?.refresh()
                }
            }
        }
        #endif
    }

    #if canImport(AppKit)
    private func installAppearanceKVO() {
        guard let app = NSApp, appearanceObservation == nil else { return }
        appearanceObservation = app.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
            Task { @MainActor in self?.refresh() }
        }
    }
    #endif
}

// MARK: - Modifier

/// Applies the user's stored appearance preference to a Scene root.
/// Drives appearance through exactly one channel — `preferredColorScheme` —
/// with an always-explicit value on macOS so SwiftUI never has to clear a
/// stale override.
public struct AppearanceModifier: ViewModifier {

    @AppStorage(AppearanceStorage.key) private var rawValue: String = AppearanceMode.system.rawValue

    public func body(content: Content) -> some View {
        let mode = AppearanceMode(rawValue: rawValue) ?? .system
        // Read the bridge inside body so the @Observable registrar wires up
        // the dependency. Live OS appearance flips in System mode will
        // re-run this body with the new value.
        let bridge = ThemeBridge.shared
        let resolved: ColorScheme? = {
            switch mode {
            case .light: return .light
            case .dark:  return .dark
            case .system:
                #if canImport(AppKit)
                // Always explicit on macOS — never nil — to dodge the
                // `preferredColorScheme(nil)` stale-state bug. The value
                // tracks the live OS appearance through the bridge.
                return bridge.systemColorScheme
                #else
                // iOS handles `nil` correctly: the trait collection of the
                // window inherits the OS appearance and SwiftUI propagates
                // changes through the colorScheme environment.
                _ = bridge.systemColorScheme
                return nil
                #endif
            }
        }()
        return content.preferredColorScheme(resolved)
    }
}

public extension View {
    /// Applies the user's stored appearance preference to a Scene root or any
    /// view tree that should respond to theme switching.
    func appearancePreference() -> some View {
        modifier(AppearanceModifier())
    }
}
