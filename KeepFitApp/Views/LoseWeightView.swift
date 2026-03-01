import SwiftUI
import UIKit

struct LoseWeightView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @AppStorage("keepfit.unit.weight") private var weightUnitRaw = WeightUnitOption.kilogram.rawValue
    let onSettingsTap: () -> Void
    var onBodyMetricSaved: (() -> Void)? = nil

    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var monthCursor = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var showBodyMetricDatePicker = false
    @State private var bodyMetricDateDraft = Date()
    @State private var calorieTrendRange: TrendRange = .all
    @State private var weightTrendRange: TrendRange = .all
    @State private var bodyFatTrendRange: TrendRange = .all
    @State private var calorieCustomStartDate = Date().startOfDayInCurrentCalendar
    @State private var calorieCustomEndDate = Date().startOfDayInCurrentCalendar
    @State private var weightCustomStartDate = Date().startOfDayInCurrentCalendar
    @State private var weightCustomEndDate = Date().startOfDayInCurrentCalendar
    @State private var bodyFatCustomStartDate = Date().startOfDayInCurrentCalendar
    @State private var bodyFatCustomEndDate = Date().startOfDayInCurrentCalendar
    @State private var showTrendCustomRangeSheet = false
    @State private var activeTrendPickerTarget: TrendPickerTarget = .calorie
    @State private var activeTrendRangePopoverTarget: TrendPickerTarget?
    @State private var trendRangeDraft: TrendRange = .all
    @State private var trendRangePopoverAnchor = UnitPoint(x: 0.92, y: 1.0)
    @State private var trendRangePopoverArrowEdge: Edge = .top
    @State private var customRangeBoundary: CustomRangeBoundary = .start
    @State private var customRangeStartDraft = Date().startOfDayInCurrentCalendar
    @State private var customRangeEndDraft = Date().startOfDayInCurrentCalendar
    @State private var bodyMetricSheetMeasuredHeight: CGFloat = 0
    @State private var trendCustomSheetMeasuredHeight: CGFloat = 0
    @FocusState private var focusedField: InputField?

    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 42
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 194
    private let deficitGoal: Double = 450

    private var todayNutrition: DayNutritionSummary {
        appState.dayNutrition(on: selectedDate)
    }

    private var todayExercise: DayFitnessSummary {
        appState.dayExercise(on: selectedDate)
    }

    private var todayBalance: Double {
        appState.dailyBalance(on: selectedDate)
    }

    private var selectedNutrition: DayNutritionSummary {
        appState.dayNutrition(on: selectedDate)
    }

    private var selectedExercise: DayFitnessSummary {
        appState.dayExercise(on: selectedDate)
    }

    private var selectedBalance: Double {
        appState.dailyBalance(on: selectedDate)
    }

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: weightUnitRaw) ?? .kilogram
    }

    private var today: Date {
        Date().startOfDayInCurrentCalendar
    }

    private var maxAdaptiveBottomSheetHeight: CGFloat {
        UIScreen.main.bounds.height * 0.88
    }

    private var bodyMetricSheetHeight: CGFloat {
        let measured = bodyMetricSheetMeasuredHeight > 0 ? bodyMetricSheetMeasuredHeight : 360
        return min(max(measured, 320), maxAdaptiveBottomSheetHeight)
    }

    private var trendCustomSheetHeight: CGFloat {
        let measured = trendCustomSheetMeasuredHeight > 0 ? trendCustomSheetMeasuredHeight : 520
        return min(max(measured, 430), maxAdaptiveBottomSheetHeight)
    }

    private var isFutureDateSelected: Bool {
        selectedDate.isFutureDayInCurrentCalendar
    }

    private var calorieTrendData: [DailyCalorieTrend] {
        let bounds = trendBounds(
            range: calorieTrendRange,
            customStart: calorieCustomStartDate,
            customEnd: calorieCustomEndDate
        )
        return appState.calorieTrends(days: 400)
            .filter { trend in
                let day = trend.date.startOfDayInCurrentCalendar
                guard day >= bounds.start, day <= bounds.end else { return false }
                return trend.intake > 0.01 || trend.expenditure > 0.01
            }
    }

    private var weightTrendData: [BodyMetricLog] {
        let bounds = trendBounds(
            range: weightTrendRange,
            customStart: weightCustomStartDate,
            customEnd: weightCustomEndDate
        )
        return appState.weightTrends(limit: 400)
            .filter { metric in
                let day = metric.date.startOfDayInCurrentCalendar
                return day >= bounds.start && day <= bounds.end
            }
    }

    private var bodyFatTrendData: [BodyMetricLog] {
        let bounds = trendBounds(
            range: bodyFatTrendRange,
            customStart: bodyFatCustomStartDate,
            customEnd: bodyFatCustomEndDate
        )
        return appState.weightTrends(limit: 400)
            .filter { metric in
                let day = metric.date.startOfDayInCurrentCalendar
                return day >= bounds.start && day <= bounds.end
            }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GrowPageBackground(accent: .blue)

                ScrollView {
                    VStack(spacing: cardSpacing) {
                        weekCalendarStrip
                        summaryRingCard
                        summaryMetricsCard
                        calendarCard
                        selectedDayCard
                        bodyMetricInputCard
                        calorieTrendCard
                        weightTrendCard
                        bodyFatTrendCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        focusedField = nil
                    }
                )
            }
            .navigationTitle(localized("减个肥", "Lose Weight"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        KeepFitHaptics.impact(.light)
                        onSettingsTap()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localized("完成", "Done")) {
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                monthCursor = selectedDate
                let defaultStart = AppPreferences.calendar.date(byAdding: .month, value: -1, to: today) ?? today
                if calorieCustomStartDate == calorieCustomEndDate {
                    calorieCustomStartDate = defaultStart
                    calorieCustomEndDate = today
                }
                if weightCustomStartDate == weightCustomEndDate {
                    weightCustomStartDate = defaultStart
                    weightCustomEndDate = today
                }
                if bodyFatCustomStartDate == bodyFatCustomEndDate {
                    bodyFatCustomStartDate = defaultStart
                    bodyFatCustomEndDate = today
                }
                syncBodyMetricInputs(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newValue in
                if newValue.isFutureDayInCurrentCalendar {
                    selectedDate = today
                    return
                }
                monthCursor = newValue
                syncBodyMetricInputs(for: newValue)
            }
            .onChange(of: weightUnitRaw) { _, _ in
                syncBodyMetricInputs(for: selectedDate)
            }
            .onReceive(appState.$bodyMetricLogs) { _ in
                guard focusedField == nil else { return }
                syncBodyMetricInputs(for: selectedDate)
            }
            .onChange(of: tabSwitchToken) { _, _ in
                selectedDate = Date().startOfDayInCurrentCalendar
            }
            .sheet(isPresented: $showBodyMetricDatePicker) {
                bodyMetricDateSheet
                    .presentationDetents([.height(bodyMetricSheetHeight)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showTrendCustomRangeSheet) {
                trendCustomRangeSheet
                    .presentationDetents([.height(trendCustomSheetHeight)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private var weekCalendarStrip: some View {
        WeekStripCalendarView(
            selectedDate: $selectedDate,
            accent: .blue,
            indicatorColor: { date in
                let hasData = !appState.foodLogs(on: date).isEmpty || !appState.exerciseLogs(on: date).isEmpty
                guard hasData else { return nil }
                return appState.dailyBalance(on: date) <= 0 ? .green : .red
            }
        )
    }

    private var summaryRingCard: some View {
        let deficit = max(0, -todayBalance)
        let surplus = max(0, todayBalance)
        let isDeficit = deficit > 0
        let progress = min((isDeficit ? deficit : surplus) / deficitGoal, 1)

        let centerMain: String = {
            if surplus > 0 {
                return "\(localized("超量", "Over"))\n\(energyText(fromKcal: surplus, includeUnit: false, unit: energyUnit))"
            }
            if deficit >= deficitGoal {
                return "\(localized("达成", "Done"))\n\(energyText(fromKcal: deficit, includeUnit: false, unit: energyUnit))"
            }
            return "\(localized("剩余", "Left"))\n\(energyText(fromKcal: (deficitGoal - deficit), includeUnit: false, unit: energyUnit))"
        }()

        return CardContainer(
            title: localized("综合热量", "Energy Balance"),
            subtitle: nil,
            accent: .blue
        ) {
            ProgressRing(
                progress: progress,
                lineWidth: 12,
                gradient: LinearGradient(
                    colors: surplus > 0
                        ? [.red.opacity(0.84), .orange.opacity(0.74), .red.opacity(0.66)]
                        : [.blue.opacity(0.84), .cyan.opacity(0.74), .blue.opacity(0.66)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                accent: surplus > 0 ? .red : .blue,
                valueText: centerMain,
                valueUnit: energyUnit.symbol,
                caption: "\(localized("目标", "Target")) \(energyText(fromKcal: deficitGoal, unit: energyUnit))"
            )
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)
        }
    }

    private var summaryMetricsCard: some View {
        let surplus = max(0, todayBalance)

        return CardContainer(
            title: localized("热量构成", "Energy Components"),
            subtitle: nil,
            accent: .blue
        ) {
            HStack(spacing: 0) {
                summaryColumn(
                    symbol: "bolt.fill",
                    color: .orange,
                    title: localized("基础消耗", "Base Burn"),
                    value: energyText(fromKcal: appState.profile.dailyMaintenanceCalories, unit: energyUnit)
                )
                summaryColumn(
                    symbol: "figure.run",
                    color: .green,
                    title: localized("运动消耗", "Exercise Burn"),
                    value: energyText(fromKcal: todayExercise.caloriesBurned, unit: energyUnit)
                )
                summaryColumn(
                    symbol: "fork.knife",
                    color: .red,
                    title: localized("饮食摄入", "Food Intake"),
                    value: energyText(fromKcal: todayNutrition.calories, unit: energyUnit)
                )
            }
            .frame(maxWidth: .infinity)

            Text(surplus > 0 ? localized("今天处于热量超量，建议补充有氧。", "Today is in surplus. Add more cardio.") : localized("今天处于热量赤字，继续保持。", "Today is in deficit. Keep it up."))
                .font(.caption)
                .foregroundStyle(surplus > 0 ? Color.red : Color.green)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var calendarCard: some View {
        CardContainer(
            title: localized("赤字日历", "Deficit Calendar"),
            subtitle: nil,
            accent: .blue
        ) {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        KeepFitHaptics.selection()
                        monthCursor = AppPreferences.calendar.date(byAdding: .month, value: -1, to: monthCursor) ?? monthCursor
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()
                    Text(Formatters.monthTitle.string(from: monthCursor))
                        .font(.subheadline.weight(.semibold))
                    Spacer()

                    Button {
                        KeepFitHaptics.selection()
                        monthCursor = AppPreferences.calendar.date(byAdding: .month, value: 1, to: monthCursor) ?? monthCursor
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }

                CalendarHeatmapView(
                    cells: appState.monthlyGrid(for: monthCursor),
                    selectedDate: $selectedDate,
                    dayBalance: { date in
                        appState.dailyBalance(on: date)
                    },
                    hasRecord: { date in
                        !appState.foodLogs(on: date).isEmpty || !appState.exerciseLogs(on: date).isEmpty
                    }
                )
            }
        }
    }

    private var selectedDayCard: some View {
        let foodLogs = appState.foodLogs(on: selectedDate)
        let exerciseLogs = appState.exerciseLogs(on: selectedDate)

        return CardContainer(
            title: "\(Formatters.monthDay.string(from: selectedDate)) \(localized("记录", "Records"))",
            subtitle: nil,
            accent: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(
                    selectedBalance <= 0
                        ? "\(localized("赤字", "Deficit")) \(energyText(fromKcal: -selectedBalance, unit: energyUnit))"
                        : "\(localized("超量", "Surplus")) \(energyText(fromKcal: selectedBalance, unit: energyUnit))"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedBalance <= 0 ? Color.green : Color.red)

                HStack {
                    Label("\(localized("摄入", "Intake")) \(energyText(fromKcal: selectedNutrition.calories, unit: energyUnit))", systemImage: "fork.knife")
                    Spacer()
                    Label("\(localized("运动", "Exercise")) \(energyText(fromKcal: selectedExercise.caloriesBurned, unit: energyUnit))", systemImage: "figure.run")
                }
                .font(.caption)

                Divider()

                if foodLogs.isEmpty && exerciseLogs.isEmpty {
                    Text(localized("当天暂无饮食和运动记录", "No records for this day"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(foodLogs.prefix(4)) { log in
                            HStack(spacing: 10) {
                                AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), seed: log.foodID, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.foodDisplayName(forFoodID: log.foodID, fallback: log.foodName))
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(formattedNumber(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("+\(energyText(fromKcal: log.calories, unit: energyUnit))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.orange)
                            }
                        }

                        ForEach(exerciseLogs.prefix(4)) { log in
                            HStack(spacing: 10) {
                                AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), seed: log.exerciseID, size: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(appState.exerciseDisplayName(forExerciseID: log.exerciseID, fallback: log.exerciseName))
                                        .font(.caption2.weight(.semibold))
                                        .lineLimit(1)
                                    Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(durationDisplayText(fromMinutes: log.durationMinutes))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("-\(energyText(fromKcal: log.caloriesBurned(weightKg: appState.profile.weightKg), unit: energyUnit))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }
    }

    private var bodyMetricInputCard: some View {
        CardContainer(
            title: localized("体重体脂", "Weight & Body Fat"),
            subtitle: nil,
            accent: .blue
        ) {
            let entryFont = Font.footnote.weight(.medium)
            let canEdit = !isFutureDateSelected

            HStack(spacing: 8) {
                Button {
                    guard canEdit else { return }
                    KeepFitHaptics.impact(.light)
                    bodyMetricDateDraft = selectedDate
                    showBodyMetricDatePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Text(Formatters.monthDay.string(from: selectedDate))
                            .font(entryFont)
                            .monospacedDigit()
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: 94, height: fieldHeight)
                    .background(metricFieldBackground)
                }
                .buttonStyle(.plain)
                .disabled(!canEdit)

                HStack(spacing: 5) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.blue)
                    TextField("weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(entryFont)
                        .focused($focusedField, equals: .weight)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                    Text(weightUnit.symbol)
                        .font(entryFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: fieldHeight)
                .background(metricFieldBackground)
                .disabled(!canEdit)

                HStack(spacing: 5) {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.cyan)
                    TextField("body fat", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                        .font(entryFont)
                        .focused($focusedField, equals: .bodyFat)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                    Text("%")
                        .font(entryFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: fieldHeight)
                .background(metricFieldBackground)
                .disabled(!canEdit)

                Button {
                    guard canEdit else { return }
                    focusedField = nil
                    KeepFitHaptics.impact(.medium)
                    saveBodyMetric()
                } label: {
                    Image(systemName: "plus")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 14, height: 14)
                        .padding(9)
                        .background(
                            Circle()
                                .fill(Color.blue.opacity(0.9))
                                .overlay(
                                    Circle()
                                        .stroke(.white.opacity(0.8), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 34, height: fieldHeight)
                .disabled(!canEdit)
            }
        }
    }

    private var bodyMetricDateSheet: some View {
        VStack(spacing: 12) {
            DatePicker(
                localized("记录日期", "Record Date"),
                selection: Binding(
                    get: { bodyMetricDateDraft },
                    set: { newValue in
                        KeepFitHaptics.selection()
                        let day = min(newValue.startOfDayInCurrentCalendar, today)
                        bodyMetricDateDraft = day
                        selectedDate = day
                        showBodyMetricDatePicker = false
                    }
                ),
                in: ...today,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateBottomSheetHeight(proxy.size.height, for: .bodyMetric)
                    }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        updateBottomSheetHeight(newHeight, for: .bodyMetric)
                    }
            }
        )
    }

    private var metricFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(colorScheme == .dark ? 0.16 : 0.1),
                                Color.cyan.opacity(colorScheme == .dark ? 0.06 : 0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(colorScheme == .dark ? 0.16 : 0.24), lineWidth: 0.8)
            )
    }

    private var calorieTrendCard: some View {
        trendCardShell(
            title: localized("热量趋势", "Calorie Trend"),
            range: $calorieTrendRange,
            target: .calorie
        ) {
            if calorieTrendData.isEmpty {
                trendEmptyState
            } else {
                CalorieTrendChartView(calorieTrends: calorieTrendData)
            }
        }
    }

    private var weightTrendCard: some View {
        trendCardShell(
            title: localized("体重趋势", "Weight Trend"),
            range: $weightTrendRange,
            target: .weight
        ) {
            if weightTrendData.isEmpty {
                trendEmptyState
            } else {
                WeightTrendChartView(bodyMetrics: weightTrendData)
            }
        }
    }

    private var bodyFatTrendCard: some View {
        trendCardShell(
            title: localized("体脂趋势", "Body Fat Trend"),
            range: $bodyFatTrendRange,
            target: .bodyFat
        ) {
            if bodyFatTrendData.isEmpty {
                trendEmptyState
            } else {
                BodyFatTrendChartView(bodyMetrics: bodyFatTrendData)
            }
        }
    }

    private func trendCardShell<Content: View>(
        title: String,
        range: Binding<TrendRange>,
        target: TrendPickerTarget,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .padding(.leading, 4)
                Spacer(minLength: 6)
                trendRangeMenuButton(
                    range: range,
                    target: target
                )
            }

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.16), Color.blue.opacity(0.07), .white.opacity(0.04)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    )
                    .shadow(color: Color.blue.opacity(0.1), radius: 8, x: 0, y: 4)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trendRangeMenuButton(
        range: Binding<TrendRange>,
        target: TrendPickerTarget
    ) -> some View {
        GeometryReader { proxy in
            Button {
                KeepFitHaptics.selection()
                let frame = proxy.frame(in: .global)
                let edge: Edge = frame.midY < UIScreen.main.bounds.height * 0.55 ? .top : .bottom
                trendRangePopoverArrowEdge = edge
                trendRangePopoverAnchor = UnitPoint(x: 0.92, y: edge == .top ? 1 : 0)
                trendRangeDraft = range.wrappedValue
                activeTrendRangePopoverTarget = target
            } label: {
                HStack(spacing: 4) {
                    Text(range.wrappedValue.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(trendRangeControlTextColor(for: target))
                        .lineLimit(1)
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trendRangeControlTextColor(for: target))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule(style: .continuous)
                        .fill(trendRangeControlTint(for: target).opacity(colorScheme == .dark ? 0.2 : 0.14))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(trendRangeControlTint(for: target).opacity(colorScheme == .dark ? 0.42 : 0.34), lineWidth: 0.9)
                        )
                )
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        }
        .frame(width: trendRangeTriggerWidth(for: range.wrappedValue.title), height: 28, alignment: .trailing)
        .popover(
            isPresented: trendRangePopoverBinding(for: target),
            attachmentAnchor: .point(trendRangePopoverAnchor),
            arrowEdge: trendRangePopoverArrowEdge
        ) {
            trendRangePopover(range: range, target: target)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.clear)
        }
    }

    private var trendEmptyState: some View {
        Text(localized("所选时间范围暂无数据", "No data in selected range"))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 10)
    }

    private var trendCustomRangeSheet: some View {
        VStack(spacing: 12) {
            HStack {
                Text(localized("趋势范围", "Trend Range"))
                    .font(.headline.weight(.semibold))
                Spacer()
                Button(localized("完成", "Done")) {
                    KeepFitHaptics.selection()
                    applyCustomRangeDraft()
                    showTrendCustomRangeSheet = false
                }
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                )
            }

            HStack(spacing: 8) {
                customBoundaryChip(
                    title: localized("起始日", "Start"),
                    value: Formatters.yearMonthDay.string(from: customRangeStartDraft),
                    selected: customRangeBoundary == .start
                ) {
                    customRangeBoundary = .start
                }
                customBoundaryChip(
                    title: localized("终止日", "End"),
                    value: Formatters.yearMonthDay.string(from: customRangeEndDraft),
                    selected: customRangeBoundary == .end
                ) {
                    customRangeBoundary = .end
                }
            }

            DatePicker(
                localized("趋势日期", "Trend Date"),
                selection: customRangeBoundary == .start ? customRangeStartBinding : customRangeEndBinding,
                in: customBoundaryDateRange,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        updateBottomSheetHeight(proxy.size.height, for: .trendCustom)
                    }
                    .onChange(of: proxy.size.height) { _, newHeight in
                        updateBottomSheetHeight(newHeight, for: .trendCustom)
                    }
            }
        )
    }

    private var customRangeStartBinding: Binding<Date> {
        Binding(
            get: { customRangeStartDraft },
            set: { newValue in
                let day = min(newValue.startOfDayInCurrentCalendar, today)
                customRangeStartDraft = min(day, customRangeEndDraft)
                customRangeBoundary = .end
            }
        )
    }

    private var customRangeEndBinding: Binding<Date> {
        Binding(
            get: { customRangeEndDraft },
            set: { newValue in
                let day = min(newValue.startOfDayInCurrentCalendar, today)
                customRangeEndDraft = max(day, customRangeStartDraft)
            }
        )
    }

    private var customBoundaryDateRange: ClosedRange<Date> {
        let earliest = Date(timeIntervalSince1970: 0)
        if customRangeBoundary == .start {
            return earliest...min(customRangeEndDraft, today)
        }
        return customRangeStartDraft...today
    }

    private func openCustomRangeSheet(for target: TrendPickerTarget) {
        activeTrendPickerTarget = target
        customRangeBoundary = .start
        switch target {
        case .calorie:
            customRangeStartDraft = calorieCustomStartDate
            customRangeEndDraft = calorieCustomEndDate
        case .weight:
            customRangeStartDraft = weightCustomStartDate
            customRangeEndDraft = weightCustomEndDate
        case .bodyFat:
            customRangeStartDraft = bodyFatCustomStartDate
            customRangeEndDraft = bodyFatCustomEndDate
        }
        showTrendCustomRangeSheet = true
    }

    private func applyCustomRangeDraft() {
        let start = min(customRangeStartDraft.startOfDayInCurrentCalendar, customRangeEndDraft.startOfDayInCurrentCalendar)
        let end = max(customRangeStartDraft.startOfDayInCurrentCalendar, customRangeEndDraft.startOfDayInCurrentCalendar)
        switch activeTrendPickerTarget {
        case .calorie:
            calorieCustomStartDate = start
            calorieCustomEndDate = end
        case .weight:
            weightCustomStartDate = start
            weightCustomEndDate = end
        case .bodyFat:
            bodyFatCustomStartDate = start
            bodyFatCustomEndDate = end
        }
    }

    private func trendBounds(range: TrendRange, customStart: Date, customEnd: Date) -> (start: Date, end: Date) {
        let calendar = AppPreferences.calendar
        let end = today
        switch range {
        case .all:
            return (Date(timeIntervalSince1970: 0), end)
        case .sevenDays:
            return (calendar.date(byAdding: .day, value: -6, to: end) ?? end, end)
        case .oneMonth:
            return (calendar.date(byAdding: .month, value: -1, to: end) ?? end, end)
        case .threeMonths:
            return (calendar.date(byAdding: .month, value: -3, to: end) ?? end, end)
        case .halfYear:
            return (calendar.date(byAdding: .month, value: -6, to: end) ?? end, end)
        case .oneYear:
            return (calendar.date(byAdding: .year, value: -1, to: end) ?? end, end)
        case .custom:
            let start = min(customStart.startOfDayInCurrentCalendar, customEnd.startOfDayInCurrentCalendar, end)
            let clampedEnd = min(max(customEnd.startOfDayInCurrentCalendar, start), end)
            return (start, clampedEnd)
        }
    }

    private func customBoundaryChip(title: String, value: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            KeepFitHaptics.selection()
            action()
        } label: {
            VStack(alignment: .center, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                Text(value)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Color.blue.opacity(0.18) : Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(selected ? Color.blue.opacity(0.45) : Color.white.opacity(0.2), lineWidth: 0.9)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func summaryColumn(symbol: String, color: Color, title: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func syncBodyMetricInputs(for date: Date) {
        if let todayMetric = appState.latestBodyMetric(on: date) {
            weightText = String(format: "%.1f", weightDisplayValue(fromKg: todayMetric.weightKg, unit: weightUnit))
            bodyFatText = String(format: "%.1f", todayMetric.bodyFatPercent)
        } else {
            weightText = String(format: "%.1f", weightDisplayValue(fromKg: appState.profile.weightKg, unit: weightUnit))
            bodyFatText = String(format: "%.1f", max(10, appState.profile.targetBodyFat + 8))
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func saveBodyMetric() {
        guard !selectedDate.isFutureDayInCurrentCalendar else { return }
        guard let displayWeight = Double(weightText), displayWeight > 20 else { return }
        guard let bodyFat = Double(bodyFatText), bodyFat > 1, bodyFat < 70 else { return }

        let weight = weightFromDisplayValue(displayWeight, unit: weightUnit)
        appState.upsertBodyMetric(date: selectedDate, weightKg: weight, bodyFatPercent: bodyFat)
        appState.profile.weightKg = weight
        focusedField = nil
        onBodyMetricSaved?()
    }

    private func trendRangePopoverBinding(for target: TrendPickerTarget) -> Binding<Bool> {
        Binding(
            get: { activeTrendRangePopoverTarget == target },
            set: { isPresented in
                activeTrendRangePopoverTarget = isPresented ? target : nil
            }
        )
    }

    private func trendRangePopover(range: Binding<TrendRange>, target: TrendPickerTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(localized("趋势范围", "Trend Range"), selection: $trendRangeDraft) {
                ForEach(TrendRange.allCases) { option in
                    trendWheelOptionText(option.title)
                        .tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 172)

            trendPopoverDoneButton {
                KeepFitHaptics.selection()
                applyTrendRangeDraft(range: range, target: target)
            }
        }
        .font(.body)
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(width: trendRangeWheelPopoverWidth, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            trendRangePopoverTint(for: target)
                                .opacity(colorScheme == .dark ? 0.08 : 0.06)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.8)
                )
        )
    }

    @ViewBuilder
    private func trendWheelOptionText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .allowsTightening(true)
    }

    private func trendPopoverDoneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(localized("确认", "Confirm"))
                .font(.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.52))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 0.7)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func applyTrendRangeDraft(range: Binding<TrendRange>, target: TrendPickerTarget) {
        let selection = trendRangeDraft
        range.wrappedValue = selection
        activeTrendRangePopoverTarget = nil
        if selection == .custom {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                openCustomRangeSheet(for: target)
            }
        }
    }

    private var trendRangeWheelPopoverWidth: CGFloat {
        let maxTextWidth = TrendRange.allCases
            .map { trendWheelTextWidth($0.title) }
            .max() ?? 0
        let oneColumnWidth = maxTextWidth + 44
        let desired = oneColumnWidth + 20
        let maxAllowed = min(UIScreen.main.bounds.width * 0.8, 300)
        return min(max(desired, 176), maxAllowed)
    }

    private func trendRangeTriggerWidth(for title: String) -> CGFloat {
        let textWidth = trendMenuTextWidth(title)
        let iconAndPadding: CGFloat = 36
        return min(max(textWidth + iconAndPadding, 70), 140)
    }

    private func trendMenuTextWidth(_ text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption1)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    private func trendWheelTextWidth(_ text: String) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        return ceil((text as NSString).size(withAttributes: attributes).width)
    }

    private func trendRangePopoverTint(for target: TrendPickerTarget) -> Color {
        switch target {
        case .calorie:
            return .orange
        case .weight:
            return .cyan
        case .bodyFat:
            return .pink
        }
    }

    private func trendRangeControlTint(for target: TrendPickerTarget) -> Color {
        switch target {
        case .calorie:
            return .orange
        case .weight:
            return .cyan
        case .bodyFat:
            return .pink
        }
    }

    private func trendRangeControlTextColor(for target: TrendPickerTarget) -> Color {
        trendRangeControlTint(for: target).opacity(colorScheme == .dark ? 0.95 : 0.88)
    }

    private func updateBottomSheetHeight(_ contentHeight: CGFloat, for kind: BottomSheetKind) {
        guard contentHeight > 0 else { return }
        // Include drag-indicator / sheet chrome area so content stays fully visible.
        let target = ceil(contentHeight + 26)
        switch kind {
        case .bodyMetric:
            guard abs(bodyMetricSheetMeasuredHeight - target) > 1 else { return }
            bodyMetricSheetMeasuredHeight = target
        case .trendCustom:
            guard abs(trendCustomSheetMeasuredHeight - target) > 1 else { return }
            trendCustomSheetMeasuredHeight = target
        }
    }

}

private extension LoseWeightView {
    enum InputField {
        case weight
        case bodyFat
    }

    enum BottomSheetKind {
        case bodyMetric
        case trendCustom
    }
}

private enum TrendRange: String, CaseIterable, Identifiable {
    case all
    case sevenDays
    case oneMonth
    case threeMonths
    case halfYear
    case oneYear
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return localized("全部", "All")
        case .sevenDays:
            return localized("7天", "7D")
        case .oneMonth:
            return localized("1个月", "1M")
        case .threeMonths:
            return localized("3个月", "3M")
        case .halfYear:
            return localized("6个月", "6M")
        case .oneYear:
            return localized("1年", "1Y")
        case .custom:
            return localized("自定义", "Custom")
        }
    }
}

private enum TrendPickerTarget {
    case calorie
    case weight
    case bodyFat
}

private enum CustomRangeBoundary {
    case start
    case end
}
