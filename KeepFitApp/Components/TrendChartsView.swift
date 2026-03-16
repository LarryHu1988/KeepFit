import Charts
import SwiftUI
import UIKit

private struct CalorieTrendChartModel {
    let displayTrends: [DailyCalorieTrend]
    let indexedDisplayTrends: [(index: Int, entry: DailyCalorieTrend)]
    let xDomain: ClosedRange<Int>
    let minDeficitRaw: Double
    let maxIntakeRaw: Double
    let maxExpenditureRaw: Double
    let maxDeficitRaw: Double

    init(calorieTrends: [DailyCalorieTrend]) {
        displayTrends = calorieTrends.filter { trend in
            trend.intake > 0.01 || trend.expenditure > 0.01
        }
        indexedDisplayTrends = displayTrends.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
        xDomain = 0...max(0, indexedDisplayTrends.count - 1)
        minDeficitRaw = displayTrends.map(\.deficit).min() ?? 0
        maxIntakeRaw = displayTrends.map(\.intake).max() ?? 0
        maxExpenditureRaw = displayTrends.map(\.expenditure).max() ?? 0
        maxDeficitRaw = displayTrends.map(\.deficit).max() ?? 0
    }

    func selectedEntry(for selectedIndex: Int?) -> DailyCalorieTrend? {
        guard let selectedIndex, !indexedDisplayTrends.isEmpty else { return nil }
        let clampedIndex = min(max(selectedIndex, 0), indexedDisplayTrends.count - 1)
        return indexedDisplayTrends[clampedIndex].entry
    }
}

private struct BodyMetricTrendChartModel {
    let indexedMetrics: [(index: Int, entry: BodyMetricLog)]
    let xDomain: ClosedRange<Int>

    init(bodyMetrics: [BodyMetricLog]) {
        indexedMetrics = bodyMetrics.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
        xDomain = 0...max(0, indexedMetrics.count - 1)
    }

    func selectedEntry(for selectedIndex: Int?) -> BodyMetricLog? {
        guard let selectedIndex, !indexedMetrics.isEmpty else { return nil }
        let clampedIndex = min(max(selectedIndex, 0), indexedMetrics.count - 1)
        return indexedMetrics[clampedIndex].entry
    }
}

struct CalorieTrendChartView: View {
    let calorieTrends: [DailyCalorieTrend]
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @State private var selectedIndex: Int?
    @State private var focusedSeries: TrendSeries?
    @State private var model: CalorieTrendChartModel
    @State private var chartWidth: CGFloat = UIScreen.main.bounds.width

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    init(calorieTrends: [DailyCalorieTrend]) {
        self.calorieTrends = calorieTrends
        _model = State(initialValue: CalorieTrendChartModel(calorieTrends: calorieTrends))
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

    private var selectedEntry: DailyCalorieTrend? {
        model.selectedEntry(for: selectedIndex)
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndicesForChart(
            labels: model.indexedDisplayTrends.map { compactTrendDateLabel(from: $0.entry.date) },
            chartWidth: chartWidth
        )
    }

    private var yDomain: ClosedRange<Double> {
        let minDeficit = toDisplayEnergy(model.minDeficitRaw)
        let maxValue = [
            toDisplayEnergy(model.maxIntakeRaw),
            toDisplayEnergy(model.maxExpenditureRaw),
            toDisplayEnergy(model.maxDeficitRaw)
        ].max() ?? 0
        let lower = min(minDeficit * 1.12, 0)
        let upper = max(200, maxValue * 1.12)
        return lower...upper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(model.indexedDisplayTrends, id: \.entry.id) { point in
                    BarMark(
                        x: .value(localized("索引", "Index"), point.index),
                        y: .value(localized("赤字", "Deficit"), toDisplayEnergy(point.entry.deficit)),
                        width: .fixed(7)
                    )
                    .foregroundStyle(point.entry.deficit <= 0 ? Color.green.opacity(0.34) : Color.red.opacity(0.34))
                    .opacity(seriesOpacity(.deficit))
                }

                ForEach(model.indexedDisplayTrends, id: \.entry.id) { point in
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

                ForEach(model.indexedDisplayTrends, id: \.entry.id) { point in
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
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            model.indexedDisplayTrends.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: model.indexedDisplayTrends[index].entry.date))
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
            .background(chartWidthBackground(width: $chartWidth))

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
        .onChange(of: calorieTrends) { _, newValue in
            model = CalorieTrendChartModel(calorieTrends: newValue)
            if let selectedIndex {
                self.selectedIndex = min(selectedIndex, max(0, model.indexedDisplayTrends.count - 1))
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
    @State private var model: BodyMetricTrendChartModel
    @State private var chartWidth: CGFloat = UIScreen.main.bounds.width

    private var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: weightUnitRaw) ?? .kilogram
    }

    init(bodyMetrics: [BodyMetricLog], targetWeightKg: Double) {
        self.bodyMetrics = bodyMetrics
        self.targetWeightKg = targetWeightKg
        _model = State(initialValue: BodyMetricTrendChartModel(bodyMetrics: bodyMetrics))
    }

    private var selectedEntry: BodyMetricLog? {
        model.selectedEntry(for: selectedIndex)
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndicesForChart(
            labels: model.indexedMetrics.map { compactTrendDateLabel(from: $0.entry.date) },
            chartWidth: chartWidth
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                RuleMark(
                    y: .value(localized("目标体重", "Target Weight"), weightDisplayValue(fromKg: targetWeightKg, unit: weightUnit))
                )
                .foregroundStyle(.mint.opacity(0.58))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

                ForEach(model.indexedMetrics, id: \.entry.id) { point in
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
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            model.indexedMetrics.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: model.indexedMetrics[index].entry.date))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYAxisLabel(weightUnit.symbol)
            .frame(height: 184)
            .background(chartWidthBackground(width: $chartWidth))

            if let selectedEntry {
                Text(
                    "\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(weightText(fromKg: selectedEntry.weightKg, decimals: 1, includeUnit: true, unit: weightUnit))"
                )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: bodyMetrics) { _, newValue in
            model = BodyMetricTrendChartModel(bodyMetrics: newValue)
            if let selectedIndex {
                self.selectedIndex = min(selectedIndex, max(0, model.indexedMetrics.count - 1))
            }
        }
    }
}

struct BodyFatTrendChartView: View {
    let bodyMetrics: [BodyMetricLog]
    let targetBodyFatPercent: Double
    @State private var selectedIndex: Int?
    @State private var model: BodyMetricTrendChartModel
    @State private var chartWidth: CGFloat = UIScreen.main.bounds.width

    init(bodyMetrics: [BodyMetricLog], targetBodyFatPercent: Double) {
        self.bodyMetrics = bodyMetrics
        self.targetBodyFatPercent = targetBodyFatPercent
        _model = State(initialValue: BodyMetricTrendChartModel(bodyMetrics: bodyMetrics))
    }

    private var selectedEntry: BodyMetricLog? {
        model.selectedEntry(for: selectedIndex)
    }

    private var xAxisIndices: [Int] {
        evenlySpacedAxisIndicesForChart(
            labels: model.indexedMetrics.map { compactTrendDateLabel(from: $0.entry.date) },
            chartWidth: chartWidth
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Chart {
                RuleMark(
                    y: .value(localized("目标体脂", "Target Body Fat"), targetBodyFatPercent)
                )
                .foregroundStyle(.pink.opacity(0.58))
                .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [6, 4]))

                ForEach(model.indexedMetrics, id: \.entry.id) { point in
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
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: 46, endPadding: 46))
            .chartXAxis {
                AxisMarks(preset: .aligned, values: xAxisIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.8, dash: [2, 3]))
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                        .foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel(anchor: .center, collisionResolution: .disabled) {
                        if
                            let index = value.as(Int.self),
                            model.indexedMetrics.indices.contains(index)
                        {
                            Text(compactTrendDateLabel(from: model.indexedMetrics[index].entry.date))
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                }
            }
            .chartYAxisLabel("%")
            .frame(height: 184)
            .background(chartWidthBackground(width: $chartWidth))

            if let selectedEntry {
                Text("\(Formatters.monthDay.string(from: selectedEntry.date))  ·  \(String(format: "%.1f", selectedEntry.bodyFatPercent)) %")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: bodyMetrics) { _, newValue in
            model = BodyMetricTrendChartModel(bodyMetrics: newValue)
            if let selectedIndex {
                self.selectedIndex = min(selectedIndex, max(0, model.indexedMetrics.count - 1))
            }
        }
    }
}

private func chartWidthBackground(width: Binding<CGFloat>) -> some View {
    GeometryReader { proxy in
        Color.clear
            .onAppear {
                width.wrappedValue = proxy.size.width
            }
            .onChange(of: proxy.size.width) { _, newWidth in
                width.wrappedValue = newWidth
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

private func evenlySpacedAxisIndicesForChart(
    labels: [String],
    chartWidth: CGFloat,
    plotStartPadding: CGFloat = 46,
    plotEndPadding: CGFloat = 46,
    trailingAxisReserve: CGFloat = 44,
    fontSize: CGFloat = 11,
    interLabelSpacing: CGFloat = 8
) -> [Int] {
    let maxLabelCount = maxVisibleXAxisLabels(
        labels: labels,
        chartWidth: chartWidth,
        plotStartPadding: plotStartPadding,
        plotEndPadding: plotEndPadding,
        trailingAxisReserve: trailingAxisReserve,
        fontSize: fontSize,
        interLabelSpacing: interLabelSpacing
    )
    return evenlySpacedAxisIndices(count: labels.count, maxLabelCount: maxLabelCount)
}

private func maxVisibleXAxisLabels(
    labels: [String],
    chartWidth: CGFloat,
    plotStartPadding: CGFloat = 46,
    plotEndPadding: CGFloat = 46,
    trailingAxisReserve: CGFloat = 44,
    fontSize: CGFloat = 11,
    interLabelSpacing: CGFloat = 8
) -> Int {
    guard !labels.isEmpty else { return 0 }
    let availablePlotWidth = max(120, chartWidth - plotStartPadding - plotEndPadding - trailingAxisReserve)
    let maxMeasuredWidth = labels
        .map { keepFitMeasuredTextWidth($0, size: fontSize, monospacedDigits: true) }
        .max() ?? 28
    let requiredSlotWidth = max(34, maxMeasuredWidth + interLabelSpacing)
    let maxVisible = Int(floor((availablePlotWidth + interLabelSpacing) / requiredSlotWidth))
    return max(2, min(labels.count, maxVisible))
}
