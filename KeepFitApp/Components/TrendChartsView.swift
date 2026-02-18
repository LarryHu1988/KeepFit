import Charts
import SwiftUI

struct CalorieTrendChartView: View {
    let calorieTrends: [DailyCalorieTrend]
    @State private var selectedDate: Date?

    private var selectedEntry: DailyCalorieTrend? {
        guard let selectedDate else { return nil }
        return calorieTrends.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: calorieTrends.map(\.date), maxLabelCount: 6)
    }

    private var yDomain: ClosedRange<Double> {
        let minBalance = calorieTrends.map(\.balance).min() ?? 0
        let maxValue = [
            calorieTrends.map(\.intake).max() ?? 0,
            calorieTrends.map(\.exerciseBurn).max() ?? 0,
            calorieTrends.map(\.balance).max() ?? 0
        ].max() ?? 0
        let lower = min(0, minBalance * 1.08)
        let upper = max(200, maxValue * 1.12)
        return lower...upper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(calorieTrends) { entry in
                    BarMark(
                        x: .value("日期", entry.date),
                        y: .value("净差", entry.balance),
                        width: .fixed(7)
                    )
                    .foregroundStyle(entry.balance <= 0 ? Color.blue.opacity(0.28) : Color.red.opacity(0.30))

                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("摄入", entry.intake)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("运动消耗", entry.exerciseBurn)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    .interpolationMethod(.catmullRom)

                    if entry.exerciseBurn > 0 {
                        PointMark(
                            x: .value("日期", entry.date),
                            y: .value("运动消耗", entry.exerciseBurn)
                        )
                        .foregroundStyle(.green)
                        .symbolSize(20)
                    }
                }

                if let selectedEntry {
                    RuleMark(x: .value("选中日期", selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Formatters.trendDate.string(from: date))
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxisLabel("kcal")
            .frame(height: 190)

            HStack(spacing: 12) {
                Label("摄入", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Label("运动消耗", systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                Label("净差", systemImage: "square.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let selectedEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.monthDay.string(from: selectedEntry.date))
                        .font(.caption.weight(.semibold))
                    Text("摄入 \(Int(selectedEntry.intake)) kcal  ·  运动 \(Int(selectedEntry.exerciseBurn)) kcal  ·  净差 \(Int(selectedEntry.balance)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }
}

struct WeightTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    @State private var selectedDate: Date?

    private var selectedEntry: BodyMetricLog? {
        guard let selectedDate else { return nil }
        return bodyMetrics.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: bodyMetrics.map(\.date), maxLabelCount: 6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(bodyMetrics) { entry in
                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("体重", entry.weightKg)
                    )
                    .foregroundStyle(.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("日期", entry.date),
                        y: .value("体重", entry.weightKg)
                    )
                    .foregroundStyle(.mint)
                }

                if let selectedEntry {
                    RuleMark(x: .value("选中日期", selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Formatters.trendDate.string(from: date))
                        }
                    }
                }
            }
            .chartYAxisLabel("kg")
            .frame(height: 170)

            if let selectedEntry {
                Text("\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(String(format: "%.1f", selectedEntry.weightKg)) kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BodyFatTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    @State private var selectedDate: Date?

    private var selectedEntry: BodyMetricLog? {
        guard let selectedDate else { return nil }
        return bodyMetrics.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: bodyMetrics.map(\.date), maxLabelCount: 6)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(bodyMetrics) { entry in
                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("体脂", entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value("日期", entry.date),
                        y: .value("体脂", entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                }

                if let selectedEntry {
                    RuleMark(x: .value("选中日期", selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXAxis {
                AxisMarks(values: xAxisDates) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Formatters.trendDate.string(from: date))
                        }
                    }
                }
            }
            .chartYAxisLabel("%")
            .frame(height: 170)

            if let selectedEntry {
                Text("\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(String(format: "%.1f", selectedEntry.bodyFatPercent)) %")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func evenlySpacedAxisDates(from dates: [Date], maxLabelCount: Int) -> [Date] {
    let sortedDates = dates.sorted()
    guard !sortedDates.isEmpty else { return [] }
    guard maxLabelCount > 1, sortedDates.count > maxLabelCount else {
        return sortedDates
    }

    let step = max(1, Int(ceil(Double(sortedDates.count - 1) / Double(maxLabelCount - 1))))
    var values: [Date] = []
    var index = 0
    while index < sortedDates.count {
        values.append(sortedDates[index])
        index += step
    }
    if let last = sortedDates.last, !(values.last?.isSameDay(as: last) ?? false) {
        values.append(last)
    }
    return values
}
