import SwiftUI

struct MoveMoreView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedExercise: ExerciseItem?
    @State private var exerciseTime = Date()
    @State private var durationText = "30"
    @State private var showExerciseSheet = false

    private let cardSpacing: CGFloat = 14

    private var todaySummary: DayFitnessSummary {
        appState.dayExercise(on: Date())
    }

    private var todayLogs: [ExerciseLog] {
        appState.exerciseLogs(on: Date())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardSpacing) {
                    exerciseProgressCard
                    todayExerciseCard
                    adviceCard
                    dailyHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(GrowPageBackground(accent: .green))
            .navigationTitle("迈开腿")
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

    private var exerciseProgressCard: some View {
        let remaining = appState.profile.dailyExerciseGoal - todaySummary.caloriesBurned
        let centerMain = remaining >= 0 ? "剩余\n\(Int(remaining))" : "超额\n\(Int(abs(remaining)))"

        return CardContainer(
            title: "今日运动消耗",
            subtitle: nil,
            icon: "figure.run.circle.fill",
            accent: .green
        ) {
            HStack(spacing: 16) {
                ProgressRing(
                    progress: appState.exerciseProgress(on: Date()),
                    lineWidth: 12,
                    gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                    valueText: centerMain,
                    caption: "目标 \(Int(appState.profile.dailyExerciseGoal)) kcal"
                )
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "timer")
                            .foregroundStyle(.green)
                        Text("时长: \(Int(todaySummary.durationMinutes)) 分钟")
                            .font(.subheadline)
                    }

                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("消耗: \(Int(todaySummary.caloriesBurned)) kcal")
                            .font(.subheadline)
                    }

                    Text(remaining > 0 ? "继续完成今日目标" : "今日目标已达成")
                        .font(.caption)
                        .foregroundStyle(remaining > 0 ? Color.secondary : Color.green)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var todayExerciseCard: some View {
        CardContainer(
            title: "今日锻炼记录",
            subtitle: nil,
            icon: "list.bullet.rectangle.portrait",
            accent: .green
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        showExerciseSheet = true
                    } label: {
                        HStack {
                            AppIconBadge(
                                icon: appState.exerciseIcon(for: selectedExercise ?? appState.exerciseLibrary.first ?? SeedData.exerciseLibrary[0]),
                                tint: .green,
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
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    TextField("分钟", text: $durationText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 78)
                }

                HStack(spacing: 10) {
                    DatePicker("锻炼时间", selection: $exerciseTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("添加") {
                        addExerciseLog()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
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
                            AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), tint: .green, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(Int(log.durationMinutes)) 分钟")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            icon: "lightbulb.fill",
            accent: .yellow
        ) {
            Text(appState.exerciseAdvice(on: Date()))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyHistoryCard: some View {
        let records = appState.dailyExerciseRecords(limit: 21)
        return CardContainer(
            title: "每天的锻炼记录",
            subtitle: nil,
            icon: "calendar.badge.clock",
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
                            Label("\(Int(record.minutes)) 分钟", systemImage: "timer")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func addExerciseLog() {
        guard let exercise = selectedExercise else { return }
        guard let minutes = Double(durationText), minutes > 0 else { return }

        let now = Date()
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: exerciseTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addExerciseLog(date: date, item: exercise, durationMinutes: minutes)
        durationText = "30"
    }
}
