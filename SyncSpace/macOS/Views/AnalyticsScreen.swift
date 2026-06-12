//
//  AnalyticsScreen.swift
//  SyncSpace
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
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                ScreenHeader(
                    title: "Analytics",
                    subtitle: "Insights based on completed sessions. Stored locally on this Mac."
                )

                heroMetrics
                chartCard
                breakdownGrid
                recentSessions
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .onAppear { model.recalcAnalytics() }
    }

    private var heroMetrics: some View {
        HStack(spacing: DS.Spacing.md) {
            metric("Today", value: TimeFormatter.compact(model.todayFocusSeconds), symbol: "sun.max.fill", tint: AppTheme.warning)
            metric("This week", value: TimeFormatter.compact(model.weekFocusSeconds), symbol: "calendar", tint: AppTheme.cyan)
            metric("This month", value: TimeFormatter.compact(model.monthFocusSeconds), symbol: "chart.line.uptrend.xyaxis", tint: AppTheme.electricIndigo)
            metric("Streak", value: "\(model.currentStreakDays)d", symbol: "flame.fill", tint: AppTheme.plum)
        }
    }

    private func metric(_ title: String, value: String, symbol: String, tint: Color) -> some View {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.Spacing.lg)
        .glassCard()
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text("Focus time").font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(ChartRange.allCases) { r in Text(r.title).tag(r) }
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
                    AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                    AxisValueLabel().foregroundStyle(.secondary)
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel().foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .glassCard()
    }

    private var breakdownGrid: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            sessionTypeBreakdown
            completionBreakdown
        }
    }

    private var sessionTypeBreakdown: some View {
        let buckets = Dictionary(grouping: sessions, by: \.sessionTitle)
            .mapValues { $0.reduce(0) { $0 + $1.actualDuration } }
            .sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
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
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var completionBreakdown: some View {
        let completed = sessions.filter { !$0.wasInterrupted }.count
        let interrupted = sessions.filter { $0.wasInterrupted }.count
        let total = completed + interrupted
        let pct = total == 0 ? 0 : Double(completed) / Double(total)
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Completion rate").font(.headline)
            Text("\(Int(pct * 100))%")
                .font(.display(54, weight: .bold))
                .foregroundStyle(AppTheme.mint)
            Text("\(completed) finished · \(interrupted) skipped")
                .font(.callout)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text("Recent sessions").font(.headline)
            if sessions.isEmpty {
                Text("Completed sessions will appear here.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, DS.Spacing.xs)
            } else {
                ForEach(sessions.prefix(8)) { record in
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: symbol(for: record.sessionTypeID))
                            .frame(width: 28)
                            .foregroundStyle(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.sessionTitle).font(.callout.weight(.semibold))
                            Text(record.completedAt, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if record.wasInterrupted {
                            Text("Interrupted")
                                .font(.caption2)
                                .padding(.horizontal, DS.Spacing.xs + 2)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(AppTheme.warning.opacity(0.18)))
                                .foregroundStyle(AppTheme.warning)
                        }
                        Text(TimeFormatter.compact(record.actualDuration))
                            .font(.callout.weight(.semibold))
                            .monospacedDigit()
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md - 2)
                    .glassCard(cornerRadius: DS.Radius.md)
                }
            }
        }
    }

    private func symbol(for id: String) -> String {
        switch id {
        case "focus":    return "scope"
        case "deepWork": return "brain.head.profile"
        case "sprint":   return "bolt.fill"
        default:         return "slider.horizontal.3"
        }
    }

    private func chartData() -> [ChartPoint] {
        let calendar = Calendar.current
        let now = Date.now
        switch range {
        case .day:
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
        case .day:    return "Today"
        case .week:   return "Week"
        case .month:  return "Month"
        }
    }
}
#endif
