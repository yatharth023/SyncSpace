//
//  CircularTimerView.swift
//  SyncSpace
//
//  The centerpiece countdown ring used on both Mac and iPhone.
//

import SwiftUI

public struct CircularTimerView: View {

    public var state: TimerState
    public var pulse: Double
    public var diameter: CGFloat
    public var palette: [Color] = [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan]
    public var showMillis: Bool = false

    public init(
        state: TimerState,
        pulse: Double,
        diameter: CGFloat = 360,
        palette: [Color]? = nil,
        showMillis: Bool = false
    ) {
        self.state = state
        self.pulse = pulse
        self.diameter = diameter
        if let palette { self.palette = palette }
        self.showMillis = showMillis
    }

    public var body: some View {
        ZStack {
            // Outer breathing glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[0].opacity(0.45 + 0.2 * pulse), .clear],
                        center: .center,
                        startRadius: diameter * 0.1,
                        endRadius: diameter * 0.75
                    )
                )
                .frame(width: diameter * 1.2, height: diameter * 1.2)
                .blur(radius: 20)
                .opacity(state.isRunning ? 1 : 0.5)
                .animation(.smooth(duration: 0.6), value: state.isRunning)

            // Track ring
            Circle()
                .stroke(
                    Color.white.opacity(0.06),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .frame(width: diameter, height: diameter)

            // Progress ring
            Circle()
                .trim(from: 0, to: max(0.001, min(1, state.progress)))
                .stroke(
                    AngularGradient(
                        colors: palette + [palette[0]],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: diameter, height: diameter)
                .shadow(color: palette[0].opacity(0.5), radius: 18)
                .animation(.smooth(duration: 0.4), value: state.progress)

            // Inner content
            VStack(spacing: 12) {
                Label(state.sessionType.title, systemImage: state.sessionType.symbol)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.18), lineWidth: 1))

                Text(TimeFormatter.clock(state.remainingTime))
                    .font(.system(size: diameter * 0.22,
                                  weight: .semibold,
                                  design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: Int(state.remainingTime))

                Text(progressCaption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(width: diameter * 0.8)
        }
        .frame(width: diameter * 1.2, height: diameter * 1.2)
        .scaleEffect(1.0 + (state.isRunning ? pulse * 0.012 : 0))
        .animation(.smooth(duration: 0.4), value: pulse)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer \(state.sessionType.title)")
        .accessibilityValue("\(TimeFormatter.clock(state.remainingTime)) remaining")
    }

    private var trackWidth: CGFloat { diameter * 0.045 }

    private var progressCaption: String {
        if state.isComplete { return "Complete" }
        let percent = Int((state.progress * 100).rounded())
        return state.isRunning ? "\(percent)% · running" : "\(percent)% · paused"
    }
}

#Preview {
    CircularTimerView(
        state: TimerState(
            sessionType: .focus,
            totalDuration: 1500,
            remainingTime: 845,
            isRunning: true
        ),
        pulse: 0.6,
        diameter: 320
    )
    .frame(width: 500, height: 500)
    .background(Color.black)
}
