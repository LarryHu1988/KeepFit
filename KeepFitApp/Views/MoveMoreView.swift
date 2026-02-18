import SwiftUI

struct MoveMoreView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    let onSettingsTap: () -> Void

    @State private var selectedExercise: ExerciseItem?
    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var exerciseTime = Date()
    @State private var durationText = "30"
    @State private var showExerciseSheet = false
    @State private var showExerciseTimeSheet = false

    private let cardSpacing: CGFloat = 24
    private let fieldHeight: CGFloat = 36
    private let timeFieldWidth: CGFloat = 82
    private let compactFieldWidth: CGFloat = 60

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
            .onChange(of: tabSwitchToken) { _, _ in
                selectedDate = Date().startOfDayInCurrentCalendar
            }
            .sheet(isPresented: $showExerciseSheet) {
                ExerciseSelectionSheet(items: appState.exerciseLibrary, iconForItem: { item in
                    appState.exerciseIcon(for: item)
                }) { item in
                    selectedExercise = item
                }
            }
            .sheet(isPresented: $showExerciseTimeSheet) {
                exerciseTimeSheet
                    .presentationDetents([.height(320)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    .presentationBackground(.ultraThinMaterial)
            }
        }
    }

    private var weekCalendarStrip: some View {
        WeekStripCalendarView(
            selectedDate: $selectedDate,
            accent: .green,
            indicatorColor: { date in
                let logs = appState.exerciseLogs(on: date)
                guard !logs.isEmpty else { return nil }
                let burned = appState.dayExercise(on: date).caloriesBurned
                return burned >= appState.profile.dailyExerciseGoal ? .green : .red
            }
        )
    }

    private var exerciseProgressCard: some View {
        let goal = max(appState.profile.dailyExerciseGoal, 1)
        let burned = todaySummary.caloriesBurned
        let remaining = goal - burned
        let centerMain = remaining >= 0 ? "剩余\n\(Int(remaining))" : "超额\n\(Int(abs(remaining)))"

        return CardContainer(
            title: "运动消耗",
            subtitle: nil,
            accent: .green
        ) {
            ProgressRing(
                progress: appState.exerciseProgress(on: selectedDate),
                lineWidth: 12,
                gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                accent: .green,
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
        let isWarning = burned < goal

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

            Text(appState.exerciseAdvice(on: selectedDate))
                .font(.caption)
                .foregroundStyle(isWarning ? Color.red : Color.green)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private var todayExerciseCard: some View {
        CardContainer(
            title: "锻炼记录",
            subtitle: nil,
            accent: .green
        ) {
            let entryFont = Font.caption.weight(.medium)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Button {
                        showExerciseTimeSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(Formatters.hourMinute.string(from: exerciseTime))
                                .font(entryFont)
                                .monospacedDigit()
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .frame(width: timeFieldWidth, height: fieldHeight)
                        .background(inputFieldBackground)
                    }
                    .buttonStyle(.plain)

                    Button {
                        showExerciseSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            AppIconBadge(
                                icon: appState.exerciseIcon(for: selectedExercise ?? appState.exerciseLibrary.first ?? SeedData.exerciseLibrary[0]),
                                seed: selectedExercise?.id ?? "exercise_selector",
                                size: 20
                            )
                            Text(selectedExercise?.name ?? "选择运动项目")
                                .font(entryFont)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: fieldHeight, alignment: .leading)
                        .background(inputFieldBackground)
                    }
                    .buttonStyle(.plain)
                    .layoutPriority(1)

                    HStack(spacing: 6) {
                        TextField("duration", text: $durationText)
                            .font(entryFont)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("min")
                            .font(entryFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: compactFieldWidth, height: fieldHeight)
                    .background(inputFieldBackground)

                    Button {
                        addExerciseLog()
                    } label: {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .padding(9)
                            .background(
                                Circle()
                                    .fill(Color.green.opacity(0.9))
                                    .overlay(
                                        Circle()
                                            .stroke(.white.opacity(0.8), lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: 34, height: fieldHeight)
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

    private var dailyHistoryCard: some View {
        let records = appState.dailyExerciseRecords(limit: 21)
        return CardContainer(
            title: "历史锻炼",
            subtitle: nil,
            accent: .green
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

    private var exerciseTimeSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                DatePicker(
                    "锻炼时间",
                    selection: $exerciseTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("完成") {
                    showExerciseTimeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .navigationTitle("选择锻炼时间")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.green.opacity(0.12), Color.green.opacity(0.04)],
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
}
