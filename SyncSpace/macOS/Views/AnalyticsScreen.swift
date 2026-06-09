//
//  AnalyticsScreen.swift
//  SyncSpace
//
//  Daily/weekly/monthly focus charts powered by SwiftData history.
//

#if os(macOS)
import SwiftUI
import Charts
import SwiftData

struct AnalyticsScreen: View {
    @Bindable var model: AppModel
    @Query(sort: \SessionRecord.completedAt, order: .reverse) private var sessions: [SessionRecord]

    @State private var range: ChartRange = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                heroMetrics

                chartCard

                breakdownGrid

                recentSessions
            }
            .padding(36)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .onAppear { model.recalcAnalytics() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Focus Analytics")
                .font(.largeTitle.weight(.bold))
            Text("Insights based on completed sessions. Synced from your Mac's local history.")
                .foregroundStyle(.secondary)
        }
    }

    private var heroMetrics: some View {
        HStack(spacing: 14) {
            metric(title: "Today", value: TimeFormatter.compact(model.todayFocusSeconds), symbol: "sun.max.fill", tint: AppTheme.warning)
            metric(title: "This week", value: TimeFormatter.compact(model.weekFocusSeconds), symbol: "calendar", tint: AppTheme.cyan)
            metric(title: "This month", value: TimeFormatter.compact(model.monthFocusSeconds), symbol: "chart.line.uptrend.xyaxis", tint: AppTheme.electricIndigo)
            metric(title: "Streak", value: "\(model.currentStreakDays)d", symbol: "flame.fill", tint: AppTheme.plum)
        }
    }

    private func metric(title: String, value: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Focus time").font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in
                        Text(r.title).tag(r)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            let points = chartData()

            Chart(points) { point in
                BarMark(
                    x: .value("Bucket", point.label),
                    y: .value("Minutes", point.minutes)
                )
                .cornerRadius(6)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppTheme.electricIndigo, AppTheme.cyan],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
            .frame(height: 260)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.white.opacity(0.08))
                    AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(22)
        .glassCard()
    }

    private var breakdownGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            sessionTypeBreakdown
            completionBreakdown
        }
    }

    private var sessionTypeBreakdown: some View {
        let buckets = Dictionary(grouping: sessions, by: \.sessionTitle)
            .mapValues { $0.reduce(0) { $0 + $1.actualDuration } }
            .sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Session mix").font(.headline)
            if buckets.isEmpty {
                Text("Run your first focus session to see your mix here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Chart(buckets, id: \.key) { item in
                    SectorMark(
                        angle: .value("Minutes", item.value),
                        innerRadius: .ratio(0.55),
                        angularInset: 1
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Session", item.key))
                }
                .frame(height: 200)
                .chartLegend(position: .bottom, alignment: .leading)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var completionBreakdown: some View {
        let completed = sessions.filter { !$0.wasInterrupted }.count
        let interrupted = sessions.filter { $0.wasInterrupted }.count
        let total = completed + interrupted
        let pct = total == 0 ? 0 : Double(completed) / Double(total)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Completion rate").font(.headline)
            Text("\(Int(pct * 100))%")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.mint)
            Text("\(completed) finished · \(interrupted) skipped")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent sessions").font(.headline)
            if sessions.isEmpty {
                Text("Completed sessions will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(sessions.prefix(8)) { record in
                    HStack(spacing: 14) {
                        Image(systemName: symbol(for: record.sessionTypeID))
                            .frame(width: 28)
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.sessionTitle)
                                .font(.callout.weight(.semibold))
                            Text(record.completedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if record.wasInterrupted {
                            Text("Interrupted")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.warning.opacity(0.2)))
                                .foregroundStyle(AppTheme.warning)
                        }
                        Text(TimeFormatter.compact(record.actualDuration))
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 14)
                }
            }
        }
    }

    private func symbol(for id: String) -> String {
        if id == "focus" { return "scope" }
        if id == "deepWork" { return "brain.head.profile" }
        if id == "sprint" { return "bolt.fill" }
        return "slider.horizontal.3"
    }

    private func chartData() -> [ChartPoint] {
        let calendar = Calendar.current
        let now = Date.now
        switch range {
        case .day:
            // 24 hourly buckets for today
            let start = calendar.startOfDay(for: now)
            return (0..<24).map { hour in
                let bucketStart = calendar.date(byAdding: .hour, value: hour, to: start) ?? start
                let bucketEnd = calendar.date(byAdding: .hour, value: 1, to: bucketStart) ?? bucketStart
                let total = sessions
                    .filter { $0.completedAt >= bucketStart && $0.completedAt < bucketEnd }
                    .reduce(0.0) { $0 + $1.actualDuration }
                return ChartPoint(label: "\(hour)", minutes: total / 60)
            }
        case .week:
            return (0..<7).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
                let start = calendar.startOfDay(for: day)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                let total = sessions
                    .filter { $0.completedAt >= start && $0.completedAt < end }
                    .reduce(0.0) { $0 + $1.actualDuration }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return ChartPoint(label: formatter.string(from: start), minutes: total / 60)
            }
        case .month:
            return (0..<30).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
                let start = calendar.startOfDay(for: day)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
                let total = sessions
                    .filter { $0.completedAt >= start && $0.completedAt < end }
                    .reduce(0.0) { $0 + $1.actualDuration }
                let formatter = DateFormatter()
                formatter.dateFormat = "d"
                return ChartPoint(label: formatter.string(from: start), minutes: total / 60)
            }
        }
    }
}

private struct ChartPoint: Identifiable {
    let id = UUID()
    let label: String
    let minutes: Double
}

private enum ChartRange: String, CaseIterable, Identifiable {
    case day, week, month
    var id: String { rawValue }
    var title: String {
        switch self {
        case .day: return "Today"
        case .week: return "Week"
        case .month: return "Month"
        }
    }
}
#endif
