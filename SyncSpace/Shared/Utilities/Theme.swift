//
//  Theme.swift
//  SyncSpace
//
//  Brand-level colors, gradients, and spacing primitives.
//

import SwiftUI

public enum AppTheme {

    // Brand palette
    public static let electricIndigo = Color(red: 0.42, green: 0.36, blue: 0.95)
    public static let cyan           = Color(red: 0.30, green: 0.78, blue: 0.96)
    public static let mint           = Color(red: 0.35, green: 0.92, blue: 0.75)
    public static let warning        = Color(red: 0.98, green: 0.72, blue: 0.32)
    public static let error          = Color(red: 0.96, green: 0.36, blue: 0.42)
    public static let plum           = Color(red: 0.72, green: 0.42, blue: 0.92)

    public static let accent = electricIndigo

    public static let sessionGradient = LinearGradient(
        colors: [electricIndigo, plum, cyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let calmGradient = LinearGradient(
        colors: [electricIndigo.opacity(0.5), cyan.opacity(0.35)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    public static let warmGradient = LinearGradient(
        colors: [plum, electricIndigo.opacity(0.7), .black.opacity(0.4)],
        startPoint: .top,
        endPoint: .bottom
    )

    public static let runningGlow = RadialGradient(
        colors: [electricIndigo.opacity(0.55), .clear],
        center: .center,
        startRadius: 4,
        endRadius: 260
    )

    public static let completeGlow = RadialGradient(
        colors: [mint.opacity(0.55), .clear],
        center: .center,
        startRadius: 4,
        endRadius: 260
    )

    // Spacing
    public static let cornerRadius: CGFloat = 22
    public static let smallRadius: CGFloat = 12
}
