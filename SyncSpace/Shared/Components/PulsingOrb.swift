//
//  PulsingOrb.swift
//  SyncSpace
//
//  Hero ambient visualisation. Pulse is derived from a TimelineView so the
//  enclosing screens do not re-render on every animation frame. The orb
//  paints itself within a fixed `diameter × diameter` frame so it can be
//  placed inside any layout without overflowing.
//

import SwiftUI

public struct PulsingOrb: View {
    public var progress: Double         // 0...1 session progress
    public var energy: Double           // 0...1 audio energy
    public var isRunning: Bool
    public var palette: [Color]
    public var diameter: CGFloat

    public init(
        progress: Double,
        energy: Double,
        isRunning: Bool,
        palette: [Color] = [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan],
        diameter: CGFloat = 220
    ) {
        self.progress = progress
        self.energy = energy
        self.isRunning = isRunning
        self.palette = palette
        self.diameter = diameter
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isRunning)) { context in
            let pulse = breathingPulse(at: context.date)
            orb(pulse: pulse)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement()
        .accessibilityLabel("Focus visualisation")
    }

    @ViewBuilder
    private func orb(pulse: Double) -> some View {
        ZStack {
            // Outer glow — kept inside the orb's own diameter so layout is honest.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[0].opacity(0.5 + 0.25 * pulse), .clear],
                        center: .center,
                        startRadius: diameter * 0.05,
                        endRadius: diameter * (0.55 + 0.1 * energy)
                    )
                )
                .blur(radius: 12)

            // Halo ring rotating with progress.
            Circle()
                .stroke(
                    AngularGradient(colors: palette + [palette[0]], center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .padding(diameter * 0.05)
                .rotationEffect(.degrees(progress * 360))
                .opacity(0.7)

            // Core
            Circle()
                .fill(
                    LinearGradient(
                        colors: palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(diameter * 0.12)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.35), .clear],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 4,
                                endRadius: diameter * 0.35
                            )
                        )
                        .padding(diameter * 0.12)
                )
                .scaleEffect(isRunning ? 1 + CGFloat(pulse) * 0.04 : 0.98)
                .animation(DS.Motion.calm, value: isRunning)
        }
    }
}

@inline(__always)
func breathingPulse(at date: Date, period: Double = 4.5) -> Double {
    let t = date.timeIntervalSinceReferenceDate
    return (sin(t * (2 * .pi / period)) + 1) * 0.5
}

#Preview {
    PulsingOrb(progress: 0.45, energy: 0.5, isRunning: true, diameter: 240)
        .frame(width: 320, height: 320)
        .background(Color.black)
}
