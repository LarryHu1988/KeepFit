import SwiftUI

struct LoseWeightView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedDate = Date()
    @State private var monthCursor = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""

    private let cardSpacing: CGFloat = 24
    private let fieldHeight: CGFloat = 44
    private let deficitGoal: Double = 450

    private var todayNutrition: DayNutritionSummary {
        appState.dayNutrition(on: Date())
    }

    private var todayExercise: DayFitnessSummary {
        appState.dayExercise(on: Date())
    }

    private var todayBalance: Double {
        appState.dailyBalance(on: Date())
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
            .background(GrowPageBackground(accent: .yellow))
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
        }
    }

    private var weekCalendarStrip: some View {
        WeekStripCalendarView(
            selectedDate: $selectedDate,
            indicatorColor: { date in
                let hasData = !appState.foodLogs(on: date).isEmpty || !appState.exerciseLogs(on: date).isEmpty
                guard hasData else { return nil }
                let balance = appState.dailyBalance(on: date)
                if balance <= -80 { return .green }
                if balance >= 80 { return .red }
                return .orange
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
            title: "今日综合热量",
            subtitle: nil,
            accent: .orange
        ) {
            ProgressRing(
                progress: progress,
                lineWidth: 12,
                gradient: LinearGradient(
                    colors: surplus > 0 ? [.red, .pink] : [.orange, .yellow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
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
            accent: .orange
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
            title: "当月赤字日历",
            subtitle: nil,
            accent: .yellow
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
            title: "记录体重体脂",
            subtitle: nil,
            accent: .mint
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Button {
                            shiftSelectedDate(by: -1)
                        } label: {
                            Image(systemName: "chevron.left.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)

                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        Text(Formatters.monthDay.string(from: selectedDate))

                        Button {
                            shiftSelectedDate(by: 1)
                        } label: {
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.subheadline)

                    Spacer()
                    Button("保存") {
                        saveBodyMetric()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .controlSize(.small)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "scalemass")
                            .foregroundStyle(.mint)
                        TextField("weight", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("kg")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack(spacing: 6) {
                        Image(systemName: "drop.circle")
                            .foregroundStyle(.pink)
                        TextField("body fat", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }

    private var calorieTrendCard: some View {
        CardContainer(
            title: "每日卡路里趋势",
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
            accent: .mint
        ) {
            WeightTrendChartView(bodyMetrics: appState.weightTrends(limit: 45))
        }
    }

    private var bodyFatTrendCard: some View {
        CardContainer(
            title: "体脂趋势",
            subtitle: nil,
            accent: .pink
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

    private func shiftSelectedDate(by dayDelta: Int) {
        let calendar = Calendar.current
        selectedDate = calendar.date(byAdding: .day, value: dayDelta, to: selectedDate) ?? selectedDate
    }
}
