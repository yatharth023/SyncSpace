//
//  Theme.swift
//  SyncSpace
//
//  Brand colors and signature gradients. Layout primitives live in `DS`.
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

    // Legacy aliases — kept for previously-written call sites.
    public static let cornerRadius: CGFloat = DS.Radius.lg
    public static let smallRadius: CGFloat = DS.Radius.sm
}
