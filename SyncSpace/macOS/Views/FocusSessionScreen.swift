//
//  FocusSessionScreen.swift
//  SyncSpace
//
//  Mac hero screen: ScreenHeader, circular timer, transport controls,
//  preset chips, stats grid, upcoming-tasks block.
//

#if os(macOS)
import SwiftUI

struct FocusSessionScreen: View {
    @Bindable var model: AppModel
    @State private var showCustomSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.xl) {
                ScreenHeader(
                    title: "Focus Session",
                    subtitle: "Stay present. Mac orchestrates everything; iPhone visualises."
                )

                presets
                CircularTimerView(state: model.timer, diameter: 320)
                    .frame(maxWidth: .infinity)
                transportControls
                statsGrid
                tasksPreview
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 920)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomDurationSheet(model: model)
        }
    }

    // MARK: Presets

    private var presets: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(SessionType.presets) { type in
                PresetChip(
                    type: type,
                    duration: type.defaultDuration,
                    isSelected: type.id == model.timer.sessionType.id
                ) {
                    model.selectSession(type)
                }
            }
            PresetChip(
                type: .custom(seconds: model.customDurationMinutes * 60),
                duration: TimeInterval(model.customDurationMinutes * 60),
                isSelected: { if case .custom = model.timer.sessionType { return true } else { return false } }()
            ) {
                showCustomSheet = true
            }
        }
    }

    // MARK: Transport

    private var transportControls: some View {
        HStack(spacing: DS.Spacing.lg) {
            SecondaryCircleButton(symbol: "arrow.counterclockwise") { model.resetTimer() }
                .help("Reset")
            PrimaryTransportButton(isRunning: model.timer.isRunning) {
                if model.timer.isRunning { model.pauseTimer() } else { model.startTimer() }
            }
            .keyboardShortcut(.space, modifiers: [])
            SecondaryCircleButton(symbol: "forward.end.fill") { model.skipTimer() }
                .help("Skip")
        }
    }

    // MARK: Stats

    private var statsGrid: some View {
        HStack(spacing: DS.Spacing.md) {
            StatCard(title: "Today",
                     value: TimeFormatter.compact(model.todayFocusSeconds),
                     subtitle: "Focus time",
                     symbol: "flame.fill",
                     tint: AppTheme.warning)
            StatCard(title: "Sessions",
                     value: "\(model.sessionsToday)",
                     subtitle: "Completed",
                     symbol: "checkmark.seal.fill",
                     tint: AppTheme.mint)
            StatCard(title: "Streak",
                     value: "\(model.currentStreakDays)d",
                     subtitle: "Consecutive",
                     symbol: "bolt.fill",
                     tint: AppTheme.cyan)
        }
    }

    // MARK: Up-next

    private var tasksPreview: some View {
        let open = model.tasks.filter { !$0.isCompleted }
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text("Up next").font(.headline)
                Spacer()
                Text("\(open.count) open").font(.caption).foregroundStyle(.secondary)
            }
            if open.isEmpty {
                Text("Plan your next focus block by adding tasks in the Tasks tab.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DS.Spacing.lg)
                    .glassCard()
            } else {
                VStack(spacing: DS.Spacing.xs) {
                    ForEach(open.prefix(3)) { task in
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "circle").foregroundStyle(.secondary)
                            Text(task.title)
                            Spacer()
                            Text(task.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm + 2)
                        .glassCard(cornerRadius: DS.Radius.md)
                    }
                }
            }
        }
    }
}

// MARK: - Subcomponents

private struct PresetChip: View {
    let type: SessionType
    let duration: TimeInterval
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: type.symbol)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.title).font(.callout.weight(.semibold))
                    Text(TimeFormatter.minutesLabel(duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.20) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(isSelected ? AppTheme.accent : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(DS.Motion.calm, value: isSelected)
    }
}

private struct PrimaryTransportButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(AppTheme.sessionGradient)
                    .frame(width: 84, height: 84)
                    .shadow(color: AppTheme.electricIndigo.opacity(0.45), radius: 14, y: 4)
                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRunning ? "Pause" : "Start")
    }
}

private struct SecondaryCircleButton: View {
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DS.Surface.chip)
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                    .frame(width: 56, height: 56)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.9))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .tracking(0.5)
            }
            Text(value)
                .font(.display(28, weight: .bold))
                .monospacedDigit()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .glassCard()
    }
}

private struct CustomDurationSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Double = 30

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text("Custom session").font(.title2.weight(.semibold))
            Text("Set the focus duration in minutes.")
                .foregroundStyle(.secondary)
            HStack(alignment: .lastTextBaseline, spacing: DS.Spacing.xs) {
                Text("\(Int(minutes))")
                    .font(.display(56, weight: .semibold))
                    .monospacedDigit()
                Text("min").foregroundStyle(.secondary)
            }
            Slider(value: $minutes, in: 5...180, step: 5).frame(width: 340)
            HStack(spacing: DS.Spacing.sm) {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Set Session") {
                    let mins = Int(minutes)
                    model.setCustomDuration(minutes: mins)
                    model.selectSession(.custom(seconds: mins * 60))
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
            .padding(.top, DS.Spacing.sm)
        }
        .padding(DS.Spacing.xl)
        .frame(width: 440)
        .onAppear { minutes = Double(model.customDurationMinutes) }
    }
}
#endif
