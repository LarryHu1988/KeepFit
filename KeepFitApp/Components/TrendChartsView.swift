import Charts
import SwiftUI

struct TrendChartsView: View {
    let calorieTrends: [DailyCalorieTrend]
    let bodyMetrics: [BodyMetricLog]

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("每日卡路里趋势")
                    .font(.headline)

                Chart(calorieTrends) { entry in
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
                .chartYAxisLabel("kcal")
                .frame(height: 180)

                HStack(spacing: 14) {
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
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("体重趋势")
                    .font(.headline)
                Chart(bodyMetrics) { entry in
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
                .chartYAxisLabel("kg")
                .frame(height: 150)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("体脂趋势")
                    .font(.headline)
                Chart(bodyMetrics) { entry in
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
                .chartYAxisLabel("%")
                .frame(height: 150)
            }
        }
    }
}
