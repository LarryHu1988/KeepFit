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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(calorieTrends) { entry in
                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("摄入", entry.intake)
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    LineMark(
                        x: .value("日期", entry.date),
                        y: .value("运动消耗", entry.exerciseBurn)
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    BarMark(
                        x: .value("日期", entry.date),
                        y: .value("净差", entry.balance)
                    )
                    .foregroundStyle(entry.balance <= 0 ? Color.blue.opacity(0.35) : Color.red.opacity(0.35))
                }

                if let selectedEntry {
                    RuleMark(x: .value("选中日期", selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
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
