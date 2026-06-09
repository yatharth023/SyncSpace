//
//  FocusSessionScreen.swift
//  SyncSpace
//
//  The hero screen of the Mac app. Circular timer, transport controls,
//  preset chips, and a stats strip.
//

#if os(macOS)
import SwiftUI

struct FocusSessionScreen: View {
    @Bindable var model: AppModel
    @State private var showCustomSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                presets
                    .padding(.top, 12)

                CircularTimerView(
                    state: model.timer,
                    pulse: model.pulse,
                    diameter: 360
                )
                .padding(.vertical, 12)

                transportControls

                statsStrip

                tasksPreview
            }
            .padding(40)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomDurationSheet(model: model)
        }
    }

    private var presets: some View {
        HStack(spacing: 12) {
            ForEach(SessionType.presets) { preset in
                presetChip(for: preset)
            }
            presetChip(for: .custom(seconds: model.customDurationMinutes * 60))
                .onTapGesture { showCustomSheet = true }
        }
    }

    private func presetChip(for type: SessionType) -> some View {
        let isSelected = type.id == model.timer.sessionType.id
        let isCustom: Bool = if case .custom = type { true } else { false }
        return Button {
            if isCustom { showCustomSheet = true } else { model.selectSession(type) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: type.symbol)
                    .symbolRenderingMode(.hierarchical)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.title)
                        .font(.callout.weight(.semibold))
                    Text(TimeFormatter.minutesLabel(durationForChip(type)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? AppTheme.accent.opacity(0.28) : Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? AppTheme.accent : .white.opacity(0.10), lineWidth: 1)
            )
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.25), value: isSelected)
    }

    private func durationForChip(_ type: SessionType) -> TimeInterval {
        if case .custom = type {
            return TimeInterval(model.customDurationMinutes * 60)
        }
        return type.defaultDuration
    }

    private var transportControls: some View {
        HStack(spacing: 18) {
            secondaryButton(systemName: "arrow.counterclockwise") { model.resetTimer() }
                .help("Reset")

            Button {
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
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
                .scaleEffect(1 + model.pulse * 0.025)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.space, modifiers: [])
            .help(model.timer.isRunning ? "Pause" : "Start")

            secondaryButton(systemName: "forward.end.fill") { model.skipTimer() }
                .help("Skip")
        }
        .padding(.top, 4)
    }

    private func secondaryButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 60, height: 60)
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    .frame(width: 60, height: 60)
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
    }

    private var statsStrip: some View {
        HStack(spacing: 14) {
            statCard(title: "Today",   value: TimeFormatter.compact(model.todayFocusSeconds),
                     subtitle: "Focus time",  symbol: "flame.fill", tint: AppTheme.warning)
            statCard(title: "Sessions", value: "\(model.sessionsToday)",
                     subtitle: "Completed",   symbol: "checkmark.seal.fill", tint: AppTheme.mint)
            statCard(title: "Streak",  value: "\(model.currentStreakDays)d",
                     subtitle: "Consecutive",  symbol: "bolt.fill", tint: AppTheme.cyan)
        }
    }

    private func statCard(title: String, value: String, subtitle: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private var tasksPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Up next").font(.headline)
                Spacer()
                Text("\(model.tasks.filter { !$0.isCompleted }.count) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if model.tasks.filter({ !$0.isCompleted }).isEmpty {
                Text("Plan your next focus block by adding tasks in the Tasks tab.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .glassCard()
            } else {
                VStack(spacing: 8) {
                    ForEach(model.tasks.filter { !$0.isCompleted }.prefix(3)) { task in
                        HStack {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                            Text(task.title)
                            Spacer()
                            Text(task.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .glassCard(cornerRadius: 14)
                    }
                }
            }
        }
    }
}

private struct CustomDurationSheet: View {
    @Bindable var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Double = 30

    var body: some View {
        VStack(spacing: 20) {
            Text("Custom session")
                .font(.title2.weight(.semibold))
            Text("Set the focus duration in minutes.")
                .foregroundStyle(.secondary)
            HStack {
                Text("\(Int(minutes))")
                    .font(.system(size: 60, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("min")
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 8)
            }
            Slider(value: $minutes, in: 5...180, step: 5)
                .frame(width: 340)
            HStack(spacing: 12) {
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
            .padding(.top, 12)
        }
        .padding(30)
        .frame(width: 420)
        .onAppear { minutes = Double(model.customDurationMinutes) }
    }
}
#endif
