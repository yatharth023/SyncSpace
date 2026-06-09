//
//  PulsingOrb.swift
//  SyncSpace
//
//  Layered ambient orb used in the iPhone dashboard hero and Mac empty states.
//  Responds to a pulse value (breathing 0...1), session progress, and audio
//  energy. No images; just SwiftUI gradients and PhaseAnimator.
//

import SwiftUI

public struct PulsingOrb: View {
    public var pulse: Double            // 0...1 breathing source
    public var progress: Double         // 0...1 session progress
    public var energy: Double           // 0...1 audio energy
    public var isRunning: Bool
    public var palette: [Color] = [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan]
    public var diameter: CGFloat = 220

    public init(
        pulse: Double,
        progress: Double,
        energy: Double,
        isRunning: Bool,
        palette: [Color]? = nil,
        diameter: CGFloat = 220
    ) {
        self.pulse = pulse
        self.progress = progress
        self.energy = energy
        self.isRunning = isRunning
        if let palette { self.palette = palette }
        self.diameter = diameter
    }

    public var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[0].opacity(0.45 + 0.3 * pulse), .clear],
                        center: .center,
                        startRadius: diameter * 0.05,
                        endRadius: diameter * (0.9 + 0.2 * energy)
                    )
                )
                .frame(width: diameter * 1.5, height: diameter * 1.5)
                .blur(radius: 18)

            // Halo ring
            Circle()
                .stroke(
                    AngularGradient(colors: palette + [palette[0]], center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: diameter * 0.92, height: diameter * 0.92)
                .rotationEffect(.degrees(progress * 360))
                .opacity(0.75)
                .blur(radius: 0.5)

            // Core
            Circle()
                .fill(
                    LinearGradient(
                        colors: palette,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: diameter * 0.78, height: diameter * 0.78)
                .blur(radius: 1)
                .overlay(
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.45), .clear],
                                center: UnitPoint(x: 0.32, y: 0.28),
                                startRadius: 4,
                                endRadius: diameter * 0.45
                            )
                        )
                )
                .scaleEffect(1 + (isRunning ? CGFloat(pulse) * 0.06 : 0.02))

            // Inner sparkle moving with progress
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .offset(y: -diameter * 0.34)
                    .rotationEffect(.degrees(progress * 360 + Double(i) * 60))
                    .opacity(isRunning ? 0.85 : 0.4)
            }
        }
        .frame(width: diameter * 1.5, height: diameter * 1.5)
        .animation(.smooth(duration: 0.4), value: pulse)
        .animation(.smooth(duration: 0.6), value: energy)
        .accessibilityElement()
        .accessibilityLabel("Focus visualisation")
    }
}

#Preview {
    PulsingOrb(pulse: 0.6, progress: 0.45, energy: 0.5, isRunning: true)
        .frame(width: 360, height: 360)
        .background(Color.black)
}
