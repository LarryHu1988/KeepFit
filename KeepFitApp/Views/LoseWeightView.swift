import SwiftUI

struct LoseWeightView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedDate = Date()
    @State private var monthCursor = Date()
    @State private var weightText = ""
    @State private var bodyFatText = ""

    private let cardSpacing: CGFloat = 14
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
                    summaryRingCard
                    calendarCard
                    selectedDayCard
                    bodyMetricInputCard
                    calorieTrendCard
                    weightTrendCard
                    bodyFatTrendCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(GrowPageBackground(accent: .yellow))
            .navigationTitle("减个肥")
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
                syncBodyMetricInputs(for: newValue)
            }
        }
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
            icon: "sun.max.fill",
            accent: .orange
        ) {
            HStack(spacing: 16) {
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
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    row(icon: "flame", title: "基础代谢+日常", value: appState.profile.dailyMaintenanceCalories)
                    row(icon: "figure.run", title: "运动消耗", value: todayExercise.caloriesBurned)
                    row(icon: "fork.knife", title: "饮食摄入", value: todayNutrition.calories)

                    Text(surplus > 0 ? "今天处于热量超量，建议补充有氧。" : "今天处于热量赤字，继续保持。")
                        .font(.caption)
                        .foregroundStyle(surplus > 0 ? Color.red : Color.green)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var calendarCard: some View {
        CardContainer(
            title: "当月赤字日历",
            subtitle: nil,
            icon: "calendar.badge.plus",
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
                    month: monthCursor,
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
            icon: "list.bullet.below.rectangle",
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
                                AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), tint: .orange, size: 22)
                                Text("\(Formatters.hourMinute.string(from: log.date)) \(log.foodName) \(Int(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                    .font(.caption)
                                Spacer()
                                Text("+\(Int(log.calories))")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        ForEach(exerciseLogs.prefix(4)) { log in
                            HStack {
                                AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), tint: .green, size: 22)
                                Text("\(Formatters.hourMinute.string(from: log.date)) \(log.exerciseName) \(Int(log.durationMinutes))分")
                                    .font(.caption)
                                Spacer()
                                Text("-\(Int(log.caloriesBurned(weightKg: appState.profile.weightKg)))")
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
            title: "记录体重与体脂",
            subtitle: nil,
            icon: "person.crop.circle.badge.checkmark",
            accent: .mint
        ) {
            VStack(spacing: 10) {
                HStack {
                    Label(Formatters.monthDay.string(from: selectedDate), systemImage: "calendar")
                        .font(.subheadline)
                    Spacer()
                }

                HStack(spacing: 10) {
                    HStack {
                        Image(systemName: "scalemass")
                            .foregroundStyle(.mint)
                        TextField("体重 kg", text: $weightText)
                            .keyboardType(.decimalPad)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    HStack {
                        Image(systemName: "drop.circle")
                            .foregroundStyle(.pink)
                        TextField("体脂 %", text: $bodyFatText)
                            .keyboardType(.decimalPad)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                Button("保存体测数据") {
                    saveBodyMetric()
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private var calorieTrendCard: some View {
        CardContainer(
            title: "每日卡路里趋势",
            subtitle: nil,
            icon: "chart.xyaxis.line",
            accent: .blue
        ) {
            CalorieTrendChartView(calorieTrends: appState.calorieTrends(days: 45))
        }
    }

    private var weightTrendCard: some View {
        CardContainer(
            title: "体重趋势",
            subtitle: nil,
            icon: "figure.stand",
            accent: .mint
        ) {
            WeightTrendChartView(bodyMetrics: appState.weightTrends(limit: 45))
        }
    }

    private var bodyFatTrendCard: some View {
        CardContainer(
            title: "体脂趋势",
            subtitle: nil,
            icon: "drop.fill",
            accent: .pink
        ) {
            BodyFatTrendChartView(bodyMetrics: appState.weightTrends(limit: 45))
        }
    }

    @ViewBuilder
    private func row(icon: String, title: String, value: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(value)) kcal")
                .font(.caption.weight(.semibold))
        }
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

    private func saveBodyMetric() {
        guard let weight = Double(weightText), weight > 20 else { return }
        guard let bodyFat = Double(bodyFatText), bodyFat > 1, bodyFat < 70 else { return }

        appState.upsertBodyMetric(date: selectedDate, weightKg: weight, bodyFatPercent: bodyFat)
        appState.profile.weightKg = weight
    }
}
