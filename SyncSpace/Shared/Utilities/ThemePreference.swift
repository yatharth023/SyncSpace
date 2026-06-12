//
//  ThemePreference.swift
//  SyncSpace
//
//  AppStorage-backed appearance preference. Applied at the Scene root so the
//  whole window tree responds immediately to a change and persists across
//  launches.
//

import SwiftUI

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

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

/// View modifier that resolves the AppStorage preference and applies it.
public struct AppearanceModifier: ViewModifier {
    @AppStorage(AppearanceStorage.key) private var rawValue: String = AppearanceMode.system.rawValue

    public func body(content: Content) -> some View {
        content.preferredColorScheme(AppearanceMode(rawValue: rawValue)?.colorScheme)
    }
}

public extension View {
    /// Applies the user's stored appearance preference to a Scene root or any
    /// view tree that should respond to theme switching.
    func appearancePreference() -> some View {
        modifier(AppearanceModifier())
    }
}

public enum AppearanceStorage {
    public static let key = "syncspace.appearance"
}
