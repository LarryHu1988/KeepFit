import Charts
import SwiftUI
import UIKit

struct CalorieTrendChartView: View {
    let calorieTrends: [DailyCalorieTrend]
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @State private var selectedIndex: Int?
    @State private var focusedSeries: TrendSeries?

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private enum TrendSeries {
        case intake
        case expenditure
        case deficit
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

    private var indexedDisplayTrends: [(index: Int, entry: DailyCalorieTrend)] {
        displayTrends.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
    }

    private var selectedEntry: DailyCalorieTrend? {
        guard
            let selectedIndex,
            !indexedDisplayTrends.isEmpty
        else { return nil }
        let clampedIndex = min(max(selectedIndex, 0), indexedDisplayTrends.count - 1)
        return indexedDisplayTrends[clampedIndex].entry
    }

    private var displayTrends: [DailyCalorieTrend] {
        calorieTrends.filter { trend in
            trend.intake > 0.01 || trend.expenditure > 0.01
        }
    }

    private var axisLabelCount: Int {
        maxVisibleXAxisLabels(
            labels: indexedDisplayTrends.map { compactTrendDateLabel(from: $0.entry.date) }
        )
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndices(count: indexedDisplayTrends.count, maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Int> {
        0...max(0, indexedDisplayTrends.count - 1)
    }

    private var yDomain: ClosedRange<Double> {
        let minDeficit = displayTrends.map { toDisplayEnergy($0.deficit) }.min() ?? 0
        let maxValue = [
            displayTrends.map { toDisplayEnergy($0.intake) }.max() ?? 0,
            displayTrends.map { toDisplayEnergy($0.expenditure) }.max() ?? 0,
            displayTrends.map { toDisplayEnergy($0.deficit) }.max() ?? 0
        ].max() ?? 0
        let lower = min(minDeficit * 1.12, 0)
        let upper = max(200, maxValue * 1.12)
        return lower...upper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(indexedDisplayTrends, id: \.entry.id) { point in
                    BarMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("赤字", "Deficit"), toDisplayEnergy(point.entry.deficit)),
                        width: .fixed(7)
                    )
                    .foregroundStyle(point.entry.deficit <= 0 ? Color.green.opacity(0.34) : Color.red.opacity(0.34))
                    .opacity(seriesOpacity(.deficit))
                }

                ForEach(indexedDisplayTrends, id: \.entry.id) { point in
                    LineMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("摄入", "Intake"), toDisplayEnergy(point.entry.intake)),
                        series: .value(localized("序列", "Series"), localized("饮食摄入", "Food Intake"))
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth(for: .intake)))
                    .interpolationMethod(.catmullRom)
                    .opacity(seriesOpacity(.intake))

                    PointMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("摄入", "Intake"), toDisplayEnergy(point.entry.intake))
                    )
                    .symbolSize(18)
                    .foregroundStyle(.orange)
                    .opacity(seriesOpacity(.intake))
                }

                ForEach(indexedDisplayTrends, id: \.entry.id) { point in
                    LineMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("支出", "Expenditure"), toDisplayEnergy(point.entry.expenditure)),
                        series: .value(localized("序列", "Series"), localized("运动支出", "Exercise Burn"))
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: lineWidth(for: .expenditure)))
                    .interpolationMethod(.catmullRom)
                    .opacity(seriesOpacity(.expenditure))

                    PointMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("支出", "Expenditure"), toDisplayEnergy(point.entry.expenditure))
                    )
                    .symbolSize(18)
                    .foregroundStyle(.green)
                    .opacity(seriesOpacity(.expenditure))
                }

                if let selectedIndex {
                    RuleMark(x: .value(localized("选中索引", "Selected Index"), selectedIndex))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedIndex)
            .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            indexedDisplayTrends.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: indexedDisplayTrends[index].entry.date))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxisLabel(energyUnit.symbol)
            .frame(height: 204)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), spacing: 8, alignment: .center)],
                alignment: .center,
                spacing: 8
            ) {
                legendButton(title: localized("饮食摄入", "Food Intake"), systemImage: "circle.fill", color: .orange, series: .intake)
                legendButton(title: localized("运动支出", "Exercise Burn"), systemImage: "circle.fill", color: .green, series: .expenditure)
                legendButton(title: localized("热量赤字", "Calorie Deficit"), systemImage: "square.fill", color: .secondary, series: .deficit)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if let selectedEntry {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.monthDay.string(from: selectedEntry.date))
                        .font(.footnote.weight(.semibold))
                    Text(
                        "\(localized("饮食摄入", "Food Intake")) \(energyText(fromKcal: selectedEntry.intake, signed: false, includeUnit: true, unit: energyUnit))  ·  \(localized("运动支出", "Exercise Burn")) \(energyText(fromKcal: selectedEntry.expenditure, signed: false, includeUnit: true, unit: energyUnit))  ·  \(localized("热量赤字", "Calorie Deficit")) \(energyText(fromKcal: selectedEntry.deficit, signed: true, includeUnit: true, unit: energyUnit))"
                    )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
    }

    private func legendButton(title: String, systemImage: String, color: Color, series: TrendSeries) -> some View {
        Button {
            KeepFitHaptics.selection()
            focusedSeries = focusedSeries == series ? nil : series
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.footnote)
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSeriesActive(series) ? color.opacity(0.12) : .clear)
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .buttonStyle(.plain)
        .opacity(seriesOpacity(series))
    }
}

struct WeightTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    let targetWeightKg: Double
    @AppStorage("keepfit.unit.weight") private var weightUnitRaw = WeightUnitOption.kilogram.rawValue
    @State private var selectedIndex: Int?

    private var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: weightUnitRaw) ?? .kilogram
    }

    private var indexedMetrics: [(index: Int, entry: BodyMetricLog)] {
        bodyMetrics.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
    }

    private var selectedEntry: BodyMetricLog? {
        guard
            let selectedIndex,
            !indexedMetrics.isEmpty
        else { return nil }
        let clampedIndex = min(max(selectedIndex, 0), indexedMetrics.count - 1)
        return indexedMetrics[clampedIndex].entry
    }

    private var axisLabelCount: Int {
        maxVisibleXAxisLabels(
            labels: indexedMetrics.map { compactTrendDateLabel(from: $0.entry.date) }
        )
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndices(count: indexedMetrics.count, maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Int> {
        0...max(0, indexedMetrics.count - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                RuleMark(
                    y: .value(localized("目标体重", "Target Weight"), weightDisplayValue(fromKg: targetWeightKg, unit: weightUnit))
                )
                .foregroundStyle(.mint.opacity(0.58))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

                ForEach(indexedMetrics, id: \.entry.id) { point in
                    LineMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("体重", "Weight"), weightDisplayValue(fromKg: point.entry.weightKg, unit: weightUnit))
                    )
                    .foregroundStyle(.mint)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("体重", "Weight"), weightDisplayValue(fromKg: point.entry.weightKg, unit: weightUnit))
                    )
                    .foregroundStyle(.mint)
                }

                if let selectedIndex {
                    RuleMark(x: .value(localized("选中索引", "Selected Index"), selectedIndex))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedIndex)
            .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            indexedMetrics.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: indexedMetrics[index].entry.date))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYAxisLabel(weightUnit.symbol)
            .frame(height: 184)

            if let selectedEntry {
                Text(
                    "\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(weightText(fromKg: selectedEntry.weightKg, decimals: 1, includeUnit: true, unit: weightUnit))"
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct BodyFatTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    let targetBodyFatPercent: Double
    @State private var selectedIndex: Int?

    private var indexedMetrics: [(index: Int, entry: BodyMetricLog)] {
        bodyMetrics.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
    }

    private var selectedEntry: BodyMetricLog? {
        guard
            let selectedIndex,
            !indexedMetrics.isEmpty
        else { return nil }
        let clampedIndex = min(max(selectedIndex, 0), indexedMetrics.count - 1)
        return indexedMetrics[clampedIndex].entry
    }

    private var axisLabelCount: Int {
        maxVisibleXAxisLabels(
            labels: indexedMetrics.map { compactTrendDateLabel(from: $0.entry.date) }
        )
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndices(count: indexedMetrics.count, maxLabelCount: axisLabelCount)
    }

    private var xDomain: ClosedRange<Int> {
        0...max(0, indexedMetrics.count - 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                RuleMark(
                    y: .value(localized("目标体脂", "Target Body Fat"), targetBodyFatPercent)
                )
                .foregroundStyle(.pink.opacity(0.58))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

                ForEach(indexedMetrics, id: \.entry.id) { point in
                    LineMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("体脂", "Body Fat"), point.entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    PointMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("体脂", "Body Fat"), point.entry.bodyFatPercent)
                    )
                    .foregroundStyle(.pink)
                }

                if let selectedIndex {
                    RuleMark(x: .value(localized("选中索引", "Selected Index"), selectedIndex))
                        .foregroundStyle(.secondary.opacity(0.28))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .chartXSelection(value: $selectedIndex)
            .chartXScale(domain: xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            indexedMetrics.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: indexedMetrics[index].entry.date))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYAxisLabel("%")
            .frame(height: 184)

            if let selectedEntry {
                Text("\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(String(format: "%.1f", selectedEntry.bodyFatPercent)) %")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func evenlySpacedAxisIndices(count: Int, maxLabelCount: Int) -> [Int] {
    guard count > 0 else { return [] }
    guard maxLabelCount > 1 else {
        return [0]
    }
    guard count > maxLabelCount else {
        return Array(0..<count)
    }

    let lastIndex = count - 1
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
    return indices
}

private func compactTrendDateLabel(from date: Date) -> String {
    let calendar = AppPreferences.calendar
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    return "\(month)/\(day)"
}

private func maxVisibleXAxisLabels(
    labels: [String],
    chartHorizontalPadding: CGFloat = 68,
    plotInnerPadding: CGFloat = 92,
    minLabelCharacters: Int = 4,
    fontSize: CGFloat = 11,
    interLabelSpacing: CGFloat = 6
) -> Int {
    let screenWidth = UIScreen.main.bounds.width
    let plotWidth = max(120, screenWidth - chartHorizontalPadding - plotInnerPadding)
    let longestLabelCharacters = max(minLabelCharacters, labels.map(\.count).max() ?? minLabelCharacters)
    let estimatedLabelWidth = max(28, CGFloat(longestLabelCharacters) * fontSize * 0.58)
    let requiredSlotWidth = max(32, estimatedLabelWidth + interLabelSpacing)
    return max(2, Int(floor(plotWidth / requiredSlotWidth)))
}
