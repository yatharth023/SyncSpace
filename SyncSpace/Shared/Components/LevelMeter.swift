//
//  LevelMeter.swift
//  SyncSpace
//
//  Vertical bar group that animates with a 0...1 value plus a breathing pulse.
//

import SwiftUI

public struct LevelMeter: View {
    public var level: Float        // 0...1
    public var pulse: Double       // 0...1
    public var tint: Color
    public var bars: Int = 8

    public init(level: Float, pulse: Double, tint: Color, bars: Int = 8) {
        self.level = level
        self.pulse = pulse
        self.tint = tint
        self.bars = bars
    }

    @ViewBuilder
    private func bar(at index: Int) -> some View {
        let normalized: Double = Double(index + 1) / Double(bars)
        let lit: Bool = Double(level) > normalized - 0.05
        let base: Double = 14 + 18 * (1 - normalized)
        let pulseBoost: Double = 6 * pulse
        let height: CGFloat = lit ? CGFloat(base + pulseBoost) : 6
        let opacity: Double = lit ? (0.85 + 0.15 * pulse) : 0.18
        RoundedRectangle(cornerRadius: 1.5)
            .fill(tint.opacity(opacity))
            .frame(width: 3, height: height)
            .animation(.smooth(duration: 0.25), value: lit)
            .animation(.smooth(duration: 0.25), value: pulse)
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<bars, id: \.self) { i in
                bar(at: i)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        LevelMeter(level: 0.2, pulse: 0.5, tint: AppTheme.electricIndigo)
        LevelMeter(level: 0.6, pulse: 0.8, tint: AppTheme.cyan)
        LevelMeter(level: 0.9, pulse: 0.3, tint: AppTheme.mint)
    }
    .padding(40)
    .background(Color.black)
}
