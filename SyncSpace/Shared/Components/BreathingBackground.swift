//
//  BreathingBackground.swift
//  SyncSpace
//
//  Soft animated gradient backdrop used across both apps. Cheap on the GPU:
//  it's just two overlapping radial gradients drifting on slow timers.
//

import SwiftUI

public struct BreathingBackground: View {

    public var palette: [Color]
    public var intensity: Double = 0.7
    public var pulse: Double

    public init(
        palette: [Color] = [AppTheme.electricIndigo, AppTheme.cyan, AppTheme.plum],
        intensity: Double = 0.7,
        pulse: Double
    ) {
        self.palette = palette
        self.intensity = intensity
        self.pulse = pulse
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.96)
                Color(white: 0.04)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette[0].opacity(0.55 * intensity), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.6
                        )
                    )
                    .frame(width: proxy.size.width * 0.9, height: proxy.size.width * 0.9)
                    .offset(
                        x: -proxy.size.width * 0.15 + CGFloat(sin(pulse * .pi * 2)) * 20,
                        y: -proxy.size.height * 0.10 + CGFloat(cos(pulse * .pi * 2)) * 20
                    )
                    .blur(radius: 40)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette[1].opacity(0.45 * intensity), .clear],
                            center: .center,
                            startRadius: 10,
                            endRadius: proxy.size.width * 0.55
                        )
                    )
                    .frame(width: proxy.size.width * 0.7, height: proxy.size.width * 0.7)
                    .offset(
                        x: proxy.size.width * 0.20 + CGFloat(cos(pulse * .pi * 2)) * 24,
                        y: proxy.size.height * 0.15 - CGFloat(sin(pulse * .pi * 2)) * 24
                    )
                    .blur(radius: 50)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [palette[safe: 2]?.opacity(0.35 * intensity) ?? .clear, .clear],
                            center: .center,
                            startRadius: 5,
                            endRadius: proxy.size.width * 0.45
                        )
                    )
                    .frame(width: proxy.size.width * 0.55, height: proxy.size.width * 0.55)
                    .offset(
                        x: proxy.size.width * 0.05,
                        y: proxy.size.height * 0.35 + CGFloat(sin(pulse * .pi * 2 + 1)) * 14
                    )
                    .blur(radius: 60)
            }
            .ignoresSafeArea()
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    BreathingBackground(pulse: 0.5)
        .frame(width: 600, height: 600)
}
