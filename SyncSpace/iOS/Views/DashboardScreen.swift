//
//  DashboardScreen.swift
//  SyncSpace
//
//  Glanceable iPhone companion screen. Hero visualisation + remote
//  transport controls + at-a-glance stats. Designed to be read from
//  across a desk.
//

#if os(iOS)
import SwiftUI

struct DashboardScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 28) {
                    statusBar
                    visualisation(in: proxy.size)
                    sessionLabel
                    transportRow
                    sessionPicker
                    miniStats
                }
                .padding(.horizontal, 22)
                .padding(.top, 24)
                .padding(.bottom, 48)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var statusBar: some View {
        HStack {
            ConnectionBadge(
                status: model.peerManager.status,
                peerNames: model.peerManager.connectedPeerNames
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("SyncSpace")
                    .font(.caption.weight(.semibold))
                Text("Remote")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func visualisation(in size: CGSize) -> some View {
        let diameter = min(size.width - 60, 320)
        return ZStack {
            PulsingOrb(
                pulse: model.pulse,
                progress: model.timer.progress,
                energy: Double(model.mix.combinedLevel),
                isRunning: model.timer.isRunning,
                palette: orbPalette,
                diameter: diameter
            )

            VStack(spacing: 8) {
                Text(TimeFormatter.clock(model.timer.remainingTime))
                    .font(.system(size: diameter * 0.18, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 6)
                    .contentTransition(.numericText())
                    .animation(.smooth, value: Int(model.timer.remainingTime))
                Text(stateCaption)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
            }
        }
        .frame(height: diameter * 1.4)
    }

    private var orbPalette: [Color] {
        if model.timer.isComplete && !model.timer.isRunning {
            return [AppTheme.mint, AppTheme.cyan, AppTheme.electricIndigo]
        }
        if model.timer.progress > 0.85 {
            return [AppTheme.warning, AppTheme.plum, AppTheme.electricIndigo]
        }
        return [AppTheme.electricIndigo, AppTheme.plum, AppTheme.cyan]
    }

    private var sessionLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: model.timer.sessionType.symbol)
                .foregroundStyle(AppTheme.cyan)
            Text(model.timer.sessionType.title)
                .font(.headline)
            Text("·").foregroundStyle(.secondary)
            Text(TimeFormatter.minutesLabel(model.timer.totalDuration))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var stateCaption: String {
        if model.timer.isComplete { return "Complete" }
        if model.timer.isRunning  { return "Focusing" }
        return "Paused"
    }

    private var transportRow: some View {
        HStack(spacing: 22) {
            circleButton(symbol: "arrow.counterclockwise", size: 56, role: .secondary) {
                model.resetTimer()
                HapticManager.shared.trigger(.tap)
            }

            Button {
                HapticManager.shared.trigger(model.timer.isRunning ? .sessionPaused : .sessionResumed)
                if model.timer.isRunning {
                    model.pauseTimer()
                } else {
                    model.startTimer()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.sessionGradient)
                        .frame(width: 86, height: 86)
                        .shadow(color: AppTheme.electricIndigo.opacity(0.6), radius: 18)
                    Image(systemName: model.timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .scaleEffect(model.timer.isRunning ? 1 + CGFloat(model.pulse) * 0.04 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.timer.isRunning ? "Pause" : "Start")

            circleButton(symbol: "forward.end.fill", size: 56, role: .secondary) {
                model.skipTimer()
                HapticManager.shared.trigger(.warning)
            }
        }
    }

    private enum ButtonRole { case primary, secondary }

    private func circleButton(symbol: String, size: CGFloat, role: ButtonRole, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size, height: size)
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 1)
                    .frame(width: size, height: size)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }

    private var sessionPicker: some View {
        HStack(spacing: 10) {
            ForEach(SessionType.presets) { type in
                sessionChip(type)
            }
            sessionChip(.custom(seconds: model.customDurationMinutes * 60))
        }
        .padding(.horizontal, 4)
    }

    private func sessionChip(_ type: SessionType) -> some View {
        let isSelected = type.id == model.timer.sessionType.id
        return Button {
            HapticManager.shared.trigger(.selection)
            model.selectSession(type)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: type.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(type.shortTitle)
                    .font(.caption.weight(.semibold))
                Text(TimeFormatter.minutesLabel(durationForChip(type)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.32) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : .white.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func durationForChip(_ type: SessionType) -> TimeInterval {
        if case .custom = type { return TimeInterval(model.customDurationMinutes * 60) }
        return type.defaultDuration
    }

    private var miniStats: some View {
        HStack(spacing: 12) {
            miniStat(title: "Today", value: TimeFormatter.compact(model.todayFocusSeconds), symbol: "flame.fill", tint: AppTheme.warning)
            miniStat(title: "Sessions", value: "\(model.sessionsToday)", symbol: "checkmark.seal.fill", tint: AppTheme.mint)
            miniStat(title: "Streak", value: "\(model.currentStreakDays)d", symbol: "bolt.fill", tint: AppTheme.cyan)
        }
    }

    private func miniStat(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: symbol).foregroundStyle(tint).font(.caption)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(cornerRadius: 16)
    }
}
#endif
