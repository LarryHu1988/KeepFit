import Charts
import SwiftUI

struct CalorieTrendChartView: View {
    let calorieTrends: [DailyCalorieTrend]
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @State private var selectedDate: Date?
    @State private var focusedSeries: TrendSeries?

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private enum TrendSeries {
        case intake
        case expenditure
        case balance
    }

    private func isSeriesActive(_ series: TrendSeries) -> Bool {
        focusedSeries == nil || focusedSeries == series
    }

    private func seriesOpacity(_ series: TrendSeries) -> Double {
        isSeriesActive(series) ? 1 : 0.2
    }

    private func lineWidth(for series: TrendSeries) -> CGFloat {
        focusedSeries == series ? 3.2 : 2.4
    }

    private func toDisplayEnergy(_ value: Double) -> Double {
        energyConvertedValue(fromKcal: value, unit: energyUnit)
    }

    private var selectedEntry: DailyCalorieTrend? {
        guard let selectedDate else { return nil }
        return calorieTrends.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var axisLabelCount: Int {
        preferredAxisLabelCount(for: calorieTrends.count)
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: calorieTrends.map(\.date), maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Date> {
        let sorted = calorieTrends.map(\.date).sorted()
        let fallback = Date()
        guard let first = sorted.first, let last = sorted.last else { return fallback...fallback }
        let paddedEnd = AppPreferences.calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return first...paddedEnd
    }

    private var lineCeiling: Double {
        let intakeMax = calorieTrends.map { toDisplayEnergy($0.intake) }.max() ?? 0
        let expenditureMax = calorieTrends.map { toDisplayEnergy($0.expenditure) }.max() ?? 0
        return max(220, max(intakeMax, expenditureMax))
    }

    private func displayedBalance(_ rawBalance: Double) -> Double {
        let cap = lineCeiling * 1.05
        return min(max(toDisplayEnergy(rawBalance), -cap), cap)
    }

    private var yDomain: ClosedRange<Double> {
        let minBalance = calorieTrends.map { displayedBalance($0.balance) }.min() ?? 0
        let maxValue = [
            calorieTrends.map { toDisplayEnergy($0.intake) }.max() ?? 0,
            calorieTrends.map { toDisplayEnergy($0.expenditure) }.max() ?? 0,
            calorieTrends.map { displayedBalance($0.balance) }.max() ?? 0
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
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("差值", "Balance"), displayedBalance(entry.balance)),
                        width: .fixed(7)
                    )
                    .foregroundStyle(entry.balance <= 0 ? Color.green.opacity(0.32) : Color.red.opacity(0.32))
                    .opacity(seriesOpacity(.balance))
                }

                ForEach(calorieTrends) { entry in
                    LineMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("摄入", "Intake"), toDisplayEnergy(entry.intake))
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth(for: .intake)))
                    .interpolationMethod(.monotone)
                    .opacity(seriesOpacity(.intake))
                }

                ForEach(calorieTrends) { entry in
                    LineMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("支出", "Expenditure"), toDisplayEnergy(entry.expenditure))
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth(for: .expenditure)))
                    .interpolationMethod(.monotone)
                    .opacity(seriesOpacity(.expenditure))

                    PointMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("支出", "Expenditure"), toDisplayEnergy(entry.expenditure))
                    )
                    .symbolSize(20)
                    .foregroundStyle(.green.opacity(0.9))
                    .opacity(seriesOpacity(.expenditure))
                }

                if let selectedEntry {
                    RuleMark(x: .value(localized("选中日期", "Selected Date"), selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: xDomain)
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
            .chartYAxisLabel(energyUnit.symbol)
            .frame(height: 190)

            HStack(spacing: 12) {
                legendButton(title: localized("饮食摄入", "Food Intake"), systemImage: "circle.fill", color: .orange, series: .intake)
                legendButton(title: localized("运动支出", "Exercise Burn"), systemImage: "circle.fill", color: .green, series: .expenditure)
                legendButton(title: localized("热量差值", "Calorie Gap"), systemImage: "square.fill", color: .secondary, series: .balance)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let selectedEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.monthDay.string(from: selectedEntry.date))
                        .font(.caption.weight(.semibold))
                    Text(
                        "\(localized("饮食摄入", "Food Intake")) \(energyText(fromKcal: selectedEntry.intake, signed: false, includeUnit: true, unit: energyUnit))  ·  \(localized("运动支出", "Exercise Burn")) \(energyText(fromKcal: selectedEntry.expenditure, signed: false, includeUnit: true, unit: energyUnit))  ·  \(localized("热量差值", "Calorie Gap")) \(energyText(fromKcal: selectedEntry.balance, signed: true, includeUnit: true, unit: energyUnit))"
                    )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    private func legendButton(title: String, systemImage: String, color: Color, series: TrendSeries) -> some View {
        Button {
            focusedSeries = focusedSeries == series ? nil : series
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSeriesActive(series) ? color.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
        .opacity(seriesOpacity(series))
    }
}

struct WeightTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    @AppStorage("keepfit.unit.weight") private var weightUnitRaw = WeightUnitOption.kilogram.rawValue
    @State private var selectedDate: Date?

    private var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: weightUnitRaw) ?? .kilogram
    }

    private var selectedEntry: BodyMetricLog? {
        guard let selectedDate else { return nil }
        return bodyMetrics.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    private var axisLabelCount: Int {
        preferredAxisLabelCount(for: bodyMetrics.count)
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: bodyMetrics.map(\.date), maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Date> {
        let sorted = bodyMetrics.map(\.date).sorted()
        let fallback = Date()
        guard let first = sorted.first, let last = sorted.last else { return fallback...fallback }
        let paddedEnd = AppPreferences.calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return first...paddedEnd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(bodyMetrics) { entry in
                    LineMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("体重", "Weight"), weightDisplayValue(fromKg: entry.weightKg, unit: weightUnit))
                    )
                    .foregroundStyle(.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("体重", "Weight"), weightDisplayValue(fromKg: entry.weightKg, unit: weightUnit))
                    )
                    .foregroundStyle(.mint)
                }

                if let selectedEntry {
                    RuleMark(x: .value(localized("选中日期", "Selected Date"), selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: xDomain)
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
            .chartYAxisLabel(weightUnit.symbol)
            .frame(height: 170)

            if let selectedEntry {
                Text(
                    "\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(weightText(fromKg: selectedEntry.weightKg, decimals: 1, includeUnit: true, unit: weightUnit))"
                )
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

    private var axisLabelCount: Int {
        preferredAxisLabelCount(for: bodyMetrics.count)
    }

    private var xAxisDates: [Date] {
        evenlySpacedAxisDates(from: bodyMetrics.map(\.date), maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Date> {
        let sorted = bodyMetrics.map(\.date).sorted()
        let fallback = Date()
        guard let first = sorted.first, let last = sorted.last else { return fallback...fallback }
        let paddedEnd = AppPreferences.calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return first...paddedEnd
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                ForEach(bodyMetrics) { entry in
                    LineMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("体脂", "Body Fat"), entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value(localized("日期", "Date"), entry.date),
                        y: .value(localized("体脂", "Body Fat"), entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                }

                if let selectedEntry {
                    RuleMark(x: .value(localized("选中日期", "Selected Date"), selectedEntry.date))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedDate)
            .chartXScale(domain: xDomain)
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

    let lastIndex = sortedDates.count - 1
    var indices: [Int] = []
    for step in 0..<maxLabelCount {
        let ratio = Double(step) / Double(maxLabelCount - 1)
        let rawIndex = Int((ratio * Double(lastIndex)).rounded(.toNearestOrEven))
        if indices.last != rawIndex {
            indices.append(rawIndex)
        }
    }
    if indices.first != 0 {
        indices.insert(0, at: 0)
    }
    if indices.last != lastIndex {
        indices.append(lastIndex)
    }
    return indices.map { sortedDates[$0] }
}

private func preferredAxisLabelCount(for pointCount: Int) -> Int {
    switch pointCount {
    case 0...3:
        return max(2, pointCount)
    case 4...7:
        return 4
    case 8...14:
        return 5
    default:
        return 6
    }
}
