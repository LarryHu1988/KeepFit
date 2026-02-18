import SwiftUI

struct LoseWeightView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    let onSettingsTap: () -> Void

    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var monthCursor = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var showBodyMetricDatePicker = false
    @State private var bodyMetricDateDraft = Date()

    private let cardSpacing: CGFloat = 24
    private let fieldHeight: CGFloat = 40
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

    var body: some View {
        NavigationStack {
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
            .background(GrowPageBackground(accent: .blue))
            .navigationTitle("减个肥")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onSettingsTap()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear {
                monthCursor = selectedDate
                syncBodyMetricInputs(for: selectedDate)
            }
            .onChange(of: selectedDate) { _, newValue in
                monthCursor = newValue
                syncBodyMetricInputs(for: newValue)
            }
            .onChange(of: tabSwitchToken) { _, _ in
                selectedDate = Date().startOfDayInCurrentCalendar
            }
            .sheet(isPresented: $showBodyMetricDatePicker) {
                bodyMetricDateSheet
                    .presentationDetents([.height(388)])
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
                return "超量\n\(Int(surplus))"
            }
            if deficit >= deficitGoal {
                return "达成\n\(Int(deficit))"
            }
            return "剩余\n\(Int(deficitGoal - deficit))"
        }()

        return CardContainer(
            title: "综合热量",
            subtitle: nil,
            accent: .blue
        ) {
            ProgressRing(
                progress: progress,
                lineWidth: 12,
                gradient: LinearGradient(
                    colors: surplus > 0 ? [.red, .pink] : [.blue, .cyan],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                accent: surplus > 0 ? .red : .blue,
                valueText: centerMain,
                caption: "目标 \(Int(deficitGoal)) kcal"
            )
            .frame(width: 186, height: 186)
            .frame(maxWidth: .infinity)
        }
    }

    private var summaryMetricsCard: some View {
        let surplus = max(0, todayBalance)

        return CardContainer(
            title: "热量构成",
            subtitle: nil,
            accent: .blue
        ) {
            HStack(spacing: 0) {
                summaryColumn(symbol: "bolt.fill", color: .orange, title: "基础消耗", value: "\(Int(appState.profile.dailyMaintenanceCalories)) kcal")
                summaryColumn(symbol: "figure.run", color: .green, title: "运动消耗", value: "\(Int(todayExercise.caloriesBurned)) kcal")
                summaryColumn(symbol: "fork.knife", color: .red, title: "饮食摄入", value: "\(Int(todayNutrition.calories)) kcal")
            }
            .frame(maxWidth: .infinity)

            Text(surplus > 0 ? "今天处于热量超量，建议补充有氧。" : "今天处于热量赤字，继续保持。")
                .font(.caption)
                .foregroundStyle(surplus > 0 ? Color.red : Color.green)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var calendarCard: some View {
        CardContainer(
            title: "赤字日历",
            subtitle: nil,
            accent: .blue
        ) {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        monthCursor = Calendar.current.date(byAdding: .month, value: -1, to: monthCursor) ?? monthCursor
                    } label: {
                        Image(systemName: "chevron.left")
                    }

                    Spacer()
                    Text(Formatters.monthTitle.string(from: monthCursor))
                        .font(.subheadline.weight(.semibold))
                    Spacer()

                    Button {
                        monthCursor = Calendar.current.date(byAdding: .month, value: 1, to: monthCursor) ?? monthCursor
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
            title: "\(Formatters.monthDay.string(from: selectedDate)) 记录",
            subtitle: nil,
            accent: .blue
        ) {
            VStack(alignment: .leading, spacing: 10) {
                Text(selectedBalance <= 0 ? "赤字 \(Int(-selectedBalance)) kcal" : "超量 \(Int(selectedBalance)) kcal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selectedBalance <= 0 ? Color.green : Color.red)

                HStack {
                    Label("摄入 \(Int(selectedNutrition.calories)) kcal", systemImage: "fork.knife")
                    Spacer()
                    Label("运动 \(Int(selectedExercise.caloriesBurned)) kcal", systemImage: "figure.run")
                }
                .font(.subheadline)

                Divider()

                if foodLogs.isEmpty && exerciseLogs.isEmpty {
                    Text("当天暂无饮食和运动记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(foodLogs.prefix(4)) { log in
                            HStack {
                                AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), seed: log.foodID, size: 22)
                                Text("\(Formatters.hourMinute.string(from: log.date)) \(log.foodName) \(formattedNumber(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("+\(Int(log.calories)) kcal")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        ForEach(exerciseLogs.prefix(4)) { log in
                            HStack {
                                AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), seed: log.exerciseID, size: 22)
                                Text("\(Formatters.hourMinute.string(from: log.date)) \(log.exerciseName) \(formattedNumber(log.durationMinutes)) min")
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("-\(Int(log.caloriesBurned(weightKg: appState.profile.weightKg))) kcal")
                                    .font(.caption)
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
            title: "体重体脂",
            subtitle: nil,
            accent: .blue
        ) {
            let entryFont = Font.caption.weight(.medium)

            HStack(spacing: 8) {
                Button {
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

                HStack(spacing: 5) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.blue)
                    TextField("weight", text: $weightText)
                        .keyboardType(.decimalPad)
                        .font(entryFont)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                    Text("kg")
                        .font(entryFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: fieldHeight)
                .background(metricFieldBackground)

                HStack(spacing: 5) {
                    Image(systemName: "chart.pie.fill")
                        .foregroundStyle(.cyan)
                    TextField("body fat", text: $bodyFatText)
                        .keyboardType(.decimalPad)
                        .font(entryFont)
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

                Button {
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
            }
        }
    }

    private var bodyMetricDateSheet: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("选择记录日期")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("关闭") {
                    showBodyMetricDatePicker = false
                }
                .font(.subheadline)
            }

            DatePicker(
                "记录日期",
                selection: Binding(
                    get: { bodyMetricDateDraft },
                    set: { newValue in
                        bodyMetricDateDraft = newValue
                        selectedDate = newValue
                        showBodyMetricDatePicker = false
                    }
                ),
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .labelsHidden()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var metricFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.12), Color.cyan.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.28), lineWidth: 1)
            )
    }

    private var calorieTrendCard: some View {
        CardContainer(
            title: "热量趋势",
            subtitle: nil,
            accent: .blue
        ) {
            CalorieTrendChartView(calorieTrends: appState.calorieTrends(days: 45))
        }
    }

    private var weightTrendCard: some View {
        CardContainer(
            title: "体重趋势",
            subtitle: nil,
            accent: .blue
        ) {
            WeightTrendChartView(bodyMetrics: appState.weightTrends(limit: 45))
        }
    }

    private var bodyFatTrendCard: some View {
        CardContainer(
            title: "体脂趋势",
            subtitle: nil,
            accent: .blue
        ) {
            BodyFatTrendChartView(bodyMetrics: appState.weightTrends(limit: 45))
        }
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
        if let todayMetric = appState.bodyMetricLogs.first(where: { $0.date.isSameDay(as: date) }) {
            weightText = String(format: "%.1f", todayMetric.weightKg)
            bodyFatText = String(format: "%.1f", todayMetric.bodyFatPercent)
        } else {
            let latest = appState.latestBodyMetric()
            weightText = String(format: "%.1f", latest.weightKg)
            bodyFatText = String(format: "%.1f", latest.bodyFatPercent)
        }
    }

    private func formattedNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func saveBodyMetric() {
        guard let weight = Double(weightText), weight > 20 else { return }
        guard let bodyFat = Double(bodyFatText), bodyFat > 1, bodyFat < 70 else { return }

        appState.upsertBodyMetric(date: selectedDate, weightKg: weight, bodyFatPercent: bodyFat)
        appState.profile.weightKg = weight
    }

}
