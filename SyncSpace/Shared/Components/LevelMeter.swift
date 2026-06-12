//
//  LevelMeter.swift
//  SyncSpace
//
//  Static-state level meter. The bars are coloured purely from the input
//  `level` — no per-frame TimelineView. The visual was decorative; removing
//  the timer removes 5 channels × ~18 FPS of layout work from the audio
//  mixer and from the connected-device sync overhead.
//

import SwiftUI

public struct LevelMeter: View {
    public var level: Float
    public var tint: Color
    public var bars: Int

    public init(level: Float, tint: Color, bars: Int = 8) {
        self.level = level
        self.tint = tint
        self.bars = bars
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<bars, id: \.self) { i in
                bar(at: i)
            }
        }
        .accessibilityLabel("Level")
        .accessibilityValue("\(Int(level * 100)) percent")
        .animation(DS.Motion.calm, value: level)
    }

    @ViewBuilder
    private func bar(at index: Int) -> some View {
        let normalized: Double = Double(index + 1) / Double(bars)
        let lit: Bool = Double(level) > normalized - 0.05
        let baseHeight: Double = 14 + 18 * (1 - normalized)
        let height: CGFloat = lit ? CGFloat(baseHeight) : 6
        let opacity: Double = lit ? 0.92 : 0.18
        RoundedRectangle(cornerRadius: 1.5)
            .fill(tint.opacity(opacity))
            .frame(width: 3, height: height)
    }
}

#Preview {
    HStack(spacing: 20) {
        LevelMeter(level: 0.2, tint: AppTheme.electricIndigo)
        LevelMeter(level: 0.6, tint: AppTheme.cyan)
        LevelMeter(level: 0.9, tint: AppTheme.mint)
    }
    .padding(40)
    .background(Color.black)
}
