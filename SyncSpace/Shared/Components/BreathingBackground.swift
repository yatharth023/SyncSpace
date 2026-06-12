//
//  BreathingBackground.swift
//  SyncSpace
//
//  Calm ambient backdrop. Runs the drift accent at a low refresh rate
//  (~10 FPS) with a smaller blur radius so it doesn't hot-loop the GPU
//  while the user is scrolling.
//

import SwiftUI

public struct BreathingBackground: View {

    public var palette: [Color]
    public var intensity: Double
    public var animated: Bool

    public init(
        palette: [Color] = [AppTheme.electricIndigo, AppTheme.cyan, AppTheme.plum],
        intensity: Double = 0.45,
        animated: Bool = true
    ) {
        self.palette = palette
        self.intensity = intensity
        self.animated = animated
    }

    public var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette[0].opacity(0.10 * intensity),
                    palette[1].opacity(0.06 * intensity),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if animated {
                TimelineView(.animation(minimumInterval: 1.0 / 10.0, paused: false)) { ctx in
                    let p = breathingPulse(at: ctx.date, period: 9)
                    accent(pulse: p)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func accent(pulse: Double) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        palette[0].opacity(0.14 * intensity + 0.06 * pulse * intensity),
                        .clear
                    ],
                    center: .center,
                    startRadius: 30,
                    endRadius: 240
                )
            )
            .blur(radius: 18)
            .frame(width: 360, height: 360)
            .offset(
                x: CGFloat(sin(pulse * .pi)) * 24 - 60,
                y: CGFloat(cos(pulse * .pi)) * 24 - 40
            )
    }
}

#Preview {
    BreathingBackground()
        .frame(width: 600, height: 600)
}
