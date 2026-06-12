//
//  DashboardScreen.swift
//  SyncSpace
//
//  iPhone glanceable focus dashboard. All content is centred with
//  `.frame(maxWidth: .infinity)` on the containing VStack — the previous
//  oversize PulsingOrb frame had been pushing layout to the right.
//

#if os(iOS)
import SwiftUI

struct DashboardScreen: View {
    @Bindable var model: AppModel

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                statusBar

                CircularTimerView(
                    state: model.timer,
                    diameter: 280,
                    palette: orbPalette,
                    showSessionChip: true
                )
                .frame(maxWidth: .infinity)
                .padding(.top, DS.Spacing.xs)

                transportRow
                    .frame(maxWidth: .infinity)

                sessionPicker

                miniStats
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Focus")
    }

    // MARK: Top status bar

    private var statusBar: some View {
        HStack {
            ConnectionBadge(
                status: model.peerManager.status,
                peerNames: model.peerManager.connectedPeerNames
            )
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("SyncSpace").font(.caption.weight(.semibold))
                Text("Remote").font(.caption2).foregroundStyle(.secondary)
            }
        }
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

    // MARK: Transport

    private var transportRow: some View {
        HStack(spacing: DS.Spacing.lg) {
            secondaryButton(symbol: "arrow.counterclockwise") {
                HapticManager.shared.trigger(.tap)
                model.resetTimer()
            }

            Button {
                HapticManager.shared.trigger(model.timer.isRunning ? .sessionPaused : .sessionResumed)
                if model.timer.isRunning { model.pauseTimer() } else { model.startTimer() }
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.sessionGradient)
                        .frame(width: 86, height: 86)
                        .shadow(color: AppTheme.electricIndigo.opacity(0.5), radius: 16, y: 4)
                    Image(systemName: model.timer.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.timer.isRunning ? "Pause" : "Start")

            secondaryButton(symbol: "forward.end.fill") {
                HapticManager.shared.trigger(.warning)
                model.skipTimer()
            }
        }
    }

    private func secondaryButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DS.Surface.chip)
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Presets

    private var sessionPicker: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(SessionType.presets) { type in
                sessionChip(type)
            }
            sessionChip(.custom(seconds: model.customDurationMinutes * 60))
        }
    }

    private func sessionChip(_ type: SessionType) -> some View {
        let isSelected = type.id == model.timer.sessionType.id
        return Button {
            HapticManager.shared.trigger(.selection)
            model.selectSession(type)
        } label: {
            VStack(spacing: DS.Spacing.xxs) {
                Image(systemName: type.symbol)
                    .font(.system(size: 18, weight: .semibold))
                Text(type.shortTitle)
                    .font(.caption.weight(.semibold))
                Text(TimeFormatter.minutesLabel(durationForChip(type)))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md - 2)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.24) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.accent : Color.primary.opacity(0.08), lineWidth: 1)
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    private func durationForChip(_ type: SessionType) -> TimeInterval {
        if case .custom = type { return TimeInterval(model.customDurationMinutes * 60) }
        return type.defaultDuration
    }

    // MARK: Stats

    private var miniStats: some View {
        HStack(spacing: DS.Spacing.sm) {
            miniStat(title: "Today", value: TimeFormatter.compact(model.todayFocusSeconds), symbol: "flame.fill", tint: AppTheme.warning)
            miniStat(title: "Sessions", value: "\(model.sessionsToday)", symbol: "checkmark.seal.fill", tint: AppTheme.mint)
            miniStat(title: "Streak", value: "\(model.currentStreakDays)d", symbol: "bolt.fill", tint: AppTheme.cyan)
        }
    }

    private func miniStat(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack(spacing: DS.Spacing.xxs) {
                Image(systemName: symbol).foregroundStyle(tint).font(.caption)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.4)
            }
            Text(value)
                .font(.display(22, weight: .bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.md)
        .glassCard(cornerRadius: DS.Radius.md)
    }
}
#endif
