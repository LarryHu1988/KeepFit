import SwiftUI

struct MoveMoreView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedExercise: ExerciseItem?
    @State private var selectedDate = Date()
    @State private var exerciseTime = Date()
    @State private var durationText = "30"
    @State private var showExerciseSheet = false

    private let cardSpacing: CGFloat = 24
    private let fieldHeight: CGFloat = 44
    private let compactFieldWidth: CGFloat = 112

    private var todaySummary: DayFitnessSummary {
        appState.dayExercise(on: selectedDate)
    }

    private var todayLogs: [ExerciseLog] {
        appState.exerciseLogs(on: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardSpacing) {
                    weekCalendarStrip
                    exerciseProgressCard
                    exerciseMetricsCard
                    todayExerciseCard
                    adviceCard
                    dailyHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
            }
            .background(GrowPageBackground(accent: .green))
            .navigationTitle("迈开腿")
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
                if selectedExercise == nil {
                    selectedExercise = appState.exerciseLibrary.first
                }
            }
            .sheet(isPresented: $showExerciseSheet) {
                ExerciseSelectionSheet(items: appState.exerciseLibrary, iconForItem: { item in
                    appState.exerciseIcon(for: item)
                }) { item in
                    selectedExercise = item
                }
            }
        }
    }

    private var weekCalendarStrip: some View {
        WeekStripCalendarView(
            selectedDate: $selectedDate,
            indicatorColor: { date in
                appState.exerciseLogs(on: date).isEmpty ? nil : .green
            }
        )
    }

    private var exerciseProgressCard: some View {
        let goal = max(appState.profile.dailyExerciseGoal, 1)
        let burned = todaySummary.caloriesBurned
        let remaining = goal - burned
        let centerMain = remaining >= 0 ? "剩余\n\(Int(remaining))" : "超额\n\(Int(abs(remaining)))"

        return CardContainer(
            title: "今日运动消耗",
            subtitle: nil,
            accent: .green
        ) {
            ProgressRing(
                progress: appState.exerciseProgress(on: selectedDate),
                lineWidth: 12,
                gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                valueText: centerMain,
                caption: "目标 \(Int(goal)) kcal"
            )
            .frame(width: 186, height: 186)
            .frame(maxWidth: .infinity)
        }
    }

    private var exerciseMetricsCard: some View {
        let goal = max(appState.profile.dailyExerciseGoal, 1)
        let burned = todaySummary.caloriesBurned
        let duration = todaySummary.durationMinutes

        return CardContainer(
            title: "运动指标",
            subtitle: nil,
            accent: .green
        ) {
            HStack(spacing: 0) {
                metricColumn(symbol: "flame.fill", color: .orange, name: "消耗", value: "\(Int(burned)) kcal")
                metricColumn(symbol: "clock.fill", color: .blue, name: "时长", value: "\(Int(duration)) min")
                metricColumn(symbol: "target", color: .green, name: "目标", value: "\(Int(goal)) kcal")
            }
            .frame(maxWidth: .infinity)

            Text(burned >= goal ? "今日目标已达成" : "继续完成今日目标")
                .font(.caption)
                .foregroundStyle(burned >= goal ? Color.green : Color.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var todayExerciseCard: some View {
        CardContainer(
            title: "今日锻炼记录",
            subtitle: nil,
            accent: .green
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        showExerciseSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            AppIconBadge(
                                icon: appState.exerciseIcon(for: selectedExercise ?? appState.exerciseLibrary.first ?? SeedData.exerciseLibrary[0]),
                                seed: selectedExercise?.id ?? "exercise_selector",
                                size: 30
                            )
                            Text(selectedExercise?.name ?? "选择运动项目")
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: fieldHeight, alignment: .leading)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 6) {
                        TextField("duration", text: $durationText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        Text("min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(width: compactFieldWidth, height: fieldHeight)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                HStack(spacing: 10) {
                    HStack {
                        DatePicker("锻炼时间", selection: $exerciseTime, displayedComponents: [.hourAndMinute])
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, minHeight: fieldHeight)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Button("添加") {
                        addExerciseLog()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .frame(width: compactFieldWidth, height: fieldHeight)
                }

                Divider()

                if todayLogs.isEmpty {
                    Text("今天还没有锻炼记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(todayLogs) { log in
                        HStack(spacing: 10) {
                            AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), seed: log.exerciseID, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(formattedNumber(log.durationMinutes)) min")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(Int(log.caloriesBurned(weightKg: appState.profile.weightKg))) kcal")
                                .font(.subheadline)
                                .foregroundStyle(.green)

                            Button {
                                appState.deleteExerciseLog(log)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var adviceCard: some View {
        CardContainer(
            title: "今日锻炼建议",
            subtitle: nil,
            accent: .yellow
        ) {
            Text(appState.exerciseAdvice(on: selectedDate))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyHistoryCard: some View {
        let records = appState.dailyExerciseRecords(limit: 21)
        return CardContainer(
            title: "每日锻炼记录",
            subtitle: nil,
            accent: .teal
        ) {
            if records.isEmpty {
                Text("暂无历史记录")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(records) { record in
                        HStack {
                            Text(Formatters.monthDay.string(from: record.date))
                                .font(.subheadline)
                            Spacer()
                            Label("\(Int(record.caloriesBurned)) kcal", systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Label("\(Int(record.minutes)) min", systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricColumn(symbol: String, color: Color, name: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.headline.weight(.semibold))
                .foregroundStyle(color)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func addExerciseLog() {
        guard let exercise = selectedExercise else { return }
        guard let minutes = Double(durationText), minutes > 0 else { return }

        let now = selectedDate
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: exerciseTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addExerciseLog(date: date, item: exercise, durationMinutes: minutes)
        durationText = "30"
    }
}
