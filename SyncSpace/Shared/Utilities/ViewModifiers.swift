//
//  ViewModifiers.swift
//  SyncSpace
//
//  Reusable visual treatments: glass cards, breathing scale, soft shadow.
//

import SwiftUI

public struct GlassCardStyle: ViewModifier {
    public var cornerRadius: CGFloat = AppTheme.cornerRadius
    public var strokeOpacity: Double = 0.18

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(strokeOpacity), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
    }
}

public struct BreathingScale: ViewModifier {
    var pulse: Double
    var amount: Double = 0.04
    public func body(content: Content) -> some View {
        content
            .scaleEffect(1.0 + pulse * amount)
            .animation(.smooth(duration: 0.4), value: pulse)
    }
}

public extension View {
    func glassCard(cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius))
    }
    func breathing(pulse: Double, amount: Double = 0.04) -> some View {
        modifier(BreathingScale(pulse: pulse, amount: amount))
    }
}
