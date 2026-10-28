import Charts
import SwiftUI
import UIKit

private struct CalorieTrendChartModel {
    let displayTrends: [DailyCalorieTrend]
    let indexedDisplayTrends: [(index: Int, entry: DailyCalorieTrend)]
    let xDomain: ClosedRange<Int>
    let axisLabels: TrendAxisLabels
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
        axisLabels = TrendAxisLabels(dates: displayTrends.map(\.date))
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
    let axisLabels: TrendAxisLabels

    init(bodyMetrics: [BodyMetricLog]) {
        indexedMetrics = bodyMetrics.enumerated().map { offset, entry in
            (index: offset, entry: entry)
        }
        xDomain = 0...max(0, indexedMetrics.count - 1)
        axisLabels = TrendAxisLabels(dates: bodyMetrics.map(\.date))
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
    @State private var measuredPlotWidth: CGFloat = 0
    @State private var focusedSeries: TrendSeries?
    @State private var model: CalorieTrendChartModel
    @Environment(\.keepFitPageWidth) private var pageWidth
    @ScaledMetric(relativeTo: .caption) private var axisFontSize: CGFloat = 11

    private var layout: TrendChartLayout {
        TrendChartLayout(width: max(1, pageWidth - 36), axisFontSize: axisFontSize)
    }

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
        model.axisLabels.indices(layout: layout, plotWidth: measuredPlotWidth)
    }

    private var xAxisIdentity: [String] {
        xAxisIndices.map { "\($0):\(model.axisLabels.labels[$0])" }
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
            .modifier(TrendPlotWidthReader(width: $measuredPlotWidth))
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: layout.edgePadding, endPadding: layout.edgePadding))
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
                            Text(model.axisLabels.labels[index])
                                .font(.system(size: layout.axisFontSize, weight: .regular, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .chartYScale(domain: yDomain)
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.18))
                    AxisTick().foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel().font(.system(size: layout.axisFontSize, design: .rounded))
                }
            }
            .chartYAxisLabel {
                Text(energyUnit.symbol).font(.system(size: layout.axisFontSize))
            }
            // Rebuild axis marks when adaptive ticks change; Charts otherwise
            // reuses labels by position and can retain dates from the old ticks.
            .id(xAxisIdentity)
            .frame(height: layout.height(baseline: 204))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { legend }
                    .fixedSize(horizontal: true, vertical: false)
                VStack(spacing: 8) { legend }
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

    @ViewBuilder
    private var legend: some View {
        legendButton(title: localized("饮食摄入", "Food Intake"), systemImage: "circle.fill", color: .orange, series: .intake)
        legendButton(title: localized("运动支出", "Exercise Burn"), systemImage: "circle.fill", color: .green, series: .expenditure)
        legendButton(title: localized("热量赤字", "Calorie Deficit"), systemImage: "square.fill", color: .secondary, series: .deficit)
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
            }
            .font(.system(size: layout.legendFontSize))
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
    @State private var measuredPlotWidth: CGFloat = 0
    @State private var model: BodyMetricTrendChartModel
    @Environment(\.keepFitPageWidth) private var pageWidth
    @ScaledMetric(relativeTo: .caption) private var axisFontSize: CGFloat = 11

    private var layout: TrendChartLayout {
        TrendChartLayout(width: max(1, pageWidth - 36), axisFontSize: axisFontSize)
    }

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
        model.axisLabels.indices(layout: layout, plotWidth: measuredPlotWidth)
    }

    private var xAxisIdentity: [String] {
        xAxisIndices.map { "\($0):\(model.axisLabels.labels[$0])" }
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
            .modifier(TrendPlotWidthReader(width: $measuredPlotWidth))
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: layout.edgePadding, endPadding: layout.edgePadding))
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
                            Text(model.axisLabels.labels[index])
                                .font(.system(size: layout.axisFontSize, weight: .regular, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.18))
                    AxisTick().foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel().font(.system(size: layout.axisFontSize, design: .rounded))
                }
            }
            .chartYAxisLabel {
                Text(weightUnit.symbol).font(.system(size: layout.axisFontSize))
            }
            // Rebuild axis marks when adaptive ticks change; Charts otherwise
            // reuses labels by position and can retain dates from the old ticks.
            .id(xAxisIdentity)
            .frame(height: layout.height(baseline: 184))

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
    @State private var measuredPlotWidth: CGFloat = 0
    @State private var model: BodyMetricTrendChartModel
    @Environment(\.keepFitPageWidth) private var pageWidth
    @ScaledMetric(relativeTo: .caption) private var axisFontSize: CGFloat = 11

    private var layout: TrendChartLayout {
        TrendChartLayout(width: max(1, pageWidth - 36), axisFontSize: axisFontSize)
    }

    init(bodyMetrics: [BodyMetricLog], targetBodyFatPercent: Double) {
        self.bodyMetrics = bodyMetrics
        self.targetBodyFatPercent = targetBodyFatPercent
        _model = State(initialValue: BodyMetricTrendChartModel(bodyMetrics: bodyMetrics))
    }

    private var selectedEntry: BodyMetricLog? {
        model.selectedEntry(for: selectedIndex)
    }

    private var xAxisIndices: [Int] {
        model.axisLabels.indices(layout: layout, plotWidth: measuredPlotWidth)
    }

    private var xAxisIdentity: [String] {
        xAxisIndices.map { "\($0):\(model.axisLabels.labels[$0])" }
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
            .modifier(TrendPlotWidthReader(width: $measuredPlotWidth))
            .chartXScale(domain: model.xDomain, range: .plotDimension(startPadding: layout.edgePadding, endPadding: layout.edgePadding))
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
                            Text(model.axisLabels.labels[index])
                                .font(.system(size: layout.axisFontSize, weight: .regular, design: .rounded))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                    AxisGridLine().foregroundStyle(.secondary.opacity(0.18))
                    AxisTick().foregroundStyle(.secondary.opacity(0.32))
                    AxisValueLabel().font(.system(size: layout.axisFontSize, design: .rounded))
                }
            }
            .chartYAxisLabel {
                Text("%").font(.system(size: layout.axisFontSize))
            }
            // Rebuild axis marks when adaptive ticks change; Charts otherwise
            // reuses labels by position and can retain dates from the old ticks.
            .id(xAxisIdentity)
            .frame(height: layout.height(baseline: 184))

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

private func compactTrendDateLabel(from date: Date) -> String {
    let calendar = AppPreferences.calendar
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    return "\(month)/\(day)"
}

// Measure labels once per data change, using the actual rounded axis font.
private struct TrendAxisLabels {
    let labels: [String]
    let widths: [CGFloat]

    init(dates: [Date]) {
        labels = dates.map(compactTrendDateLabel)
        let descriptor = UIFont.systemFont(ofSize: 11).fontDescriptor
        let font = UIFont(descriptor: descriptor.withDesign(.rounded) ?? descriptor, size: 11)
        widths = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }
    }

    func indices(layout: TrendChartLayout, plotWidth: CGFloat) -> [Int] {
        trendAxisTickIndices(
            labelWidths: widths.map { $0 * layout.axisFontSize / 11 },
            plotWidth: plotWidth > 0 ? plotWidth : max(1, layout.width - 48),
            edgePadding: layout.edgePadding
        )
    }
}

// Observe the real plotting area, including changes to the device, column,
// Dynamic Type or Y-axis labels. This passive overlay preserves chart gestures.
private struct TrendPlotWidthReader: ViewModifier {
    @Binding var width: CGFloat

    func body(content: Content) -> some View {
        content.chartOverlay { chart in
            GeometryReader { geometry in
                let plotWidth = chart.plotFrame.map { geometry[$0].width } ?? 0
                Color.clear
                    .onChange(of: plotWidth, initial: true) { _, newValue in
                        if newValue > 0, abs(width - newValue) > 0.5 {
                            width = newValue
                        }
                    }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct TrendChartLayout {
    let width: CGFloat
    let axisFontSize: CGFloat

    init(width: CGFloat, axisFontSize: CGFloat) {
        self.width = width
        self.axisFontSize = axisFontSize * min(1.15, max(1, width / 320))
    }

    var edgePadding: CGFloat { min(28, max(16, width * 0.065)) }
    var legendFontSize: CGFloat { max(13, axisFontSize * 13 / 11) }

    func height(baseline: CGFloat) -> CGFloat {
        // Preserve the phone chart's proportions as the column widens.
        min(baseline * 1.6, max(baseline, baseline * width / 320))
    }
}
