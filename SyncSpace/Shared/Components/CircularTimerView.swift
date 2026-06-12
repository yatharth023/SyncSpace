//
//  CircularTimerView.swift
//  SyncSpace
//
//  Headline countdown ring. Pulse is driven by an internal TimelineView so
//  the host screen does not redraw on every animation frame.
//

import SwiftUI

public struct CircularTimerView: View {

    public var state: TimerState
    public var diameter: CGFloat
    public var palette: [Color]
    public var showSessionChip: Bool

    public init(
        state: TimerState,
        diameter: CGFloat = 320,
        palette: [Color] = [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan],
        showSessionChip: Bool = true
    ) {
        self.state = state
        self.diameter = diameter
        self.palette = palette
        self.showSessionChip = showSessionChip
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !state.isRunning)) { ctx in
            let pulse = breathingPulse(at: ctx.date)
            content(pulse: pulse)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Timer \(state.sessionType.title)")
        .accessibilityValue("\(TimeFormatter.clock(state.remainingTime)) remaining")
    }

    @ViewBuilder
    private func content(pulse: Double) -> some View {
        ZStack {
            // Soft breathing glow that respects the orb's own bounds.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [palette[0].opacity(0.35 + 0.18 * pulse), .clear],
                        center: .center,
                        startRadius: diameter * 0.08,
                        endRadius: diameter * 0.55
                    )
                )
                .blur(radius: 14)
                .opacity(state.isRunning ? 1 : 0.55)
                .animation(DS.Motion.calm, value: state.isRunning)

            // Track
            Circle()
                .stroke(Color.primary.opacity(0.10),
                        style: StrokeStyle(lineWidth: trackWidth, lineCap: .round))
                .padding(trackWidth / 2)

            // Progress
            Circle()
                .trim(from: 0, to: max(0.001, min(1, state.progress)))
                .stroke(
                    AngularGradient(colors: palette + [palette[0]], center: .center),
                    style: StrokeStyle(lineWidth: trackWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(trackWidth / 2)
                .shadow(color: palette[0].opacity(0.35), radius: 12)
                .animation(DS.Motion.track, value: state.progress)

            // Centre stack
            VStack(spacing: DS.Spacing.sm) {
                if showSessionChip {
                    InfoChip(
                        title: state.sessionType.title,
                        symbol: state.sessionType.symbol
                    )
                }
                Text(TimeFormatter.clock(state.remainingTime))
                    .font(.display(diameter * 0.22))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(DS.Motion.snap, value: Int(state.remainingTime))

                Text(progressCaption)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(diameter * 0.12)
        }
        .scaleEffect(state.isRunning ? 1.0 + pulse * 0.01 : 1.0)
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
        state: TimerState(sessionType: .focus,
                          totalDuration: 1500,
                          remainingTime: 845,
                          isRunning: true),
        diameter: 320
    )
    .frame(width: 380, height: 380)
    .background(Color.black)
}
