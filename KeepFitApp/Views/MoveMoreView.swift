import SwiftUI

struct MoveMoreView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    let onSettingsTap: () -> Void
    var onExerciseLogged: (() -> Void)? = nil

    @State private var selectedExercise: ExerciseItem?
    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var exerciseTime = Date()
    @State private var durationText = "30"
    @State private var showExerciseSheet = false
    @State private var showExerciseTimeSheet = false
    @FocusState private var focusedField: InputField?

    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var timeFieldWidth: CGFloat = 90
    @ScaledMetric(relativeTo: .body) private var compactFieldWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 194

    private var todaySummary: DayFitnessSummary {
        appState.dayExercise(on: selectedDate)
    }

    private var todayLogs: [ExerciseLog] {
        appState.exerciseLogs(on: selectedDate)
    }

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var isFutureDateSelected: Bool {
        selectedDate.isFutureDayInCurrentCalendar
    }

    private var barBackgroundTint: Color {
        colorScheme == .dark
            ? Color.green.opacity(0.22)
            : Color.green.opacity(0.14)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GrowPageBackground(accent: .green)

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
                .simultaneousGesture(
                    TapGesture().onEnded {
                        focusedField = nil
                    }
                )
            }
            .navigationTitle(localized("迈开腿", "Move More"))
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarBackground(barBackgroundTint, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
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
                if selectedExercise == nil {
                    selectedExercise = appState.exerciseLibrary.first
                }
            }
            .onChange(of: tabSwitchToken) { _, _ in
                selectedDate = Date().startOfDayInCurrentCalendar
            }
            .onChange(of: selectedDate) { _, newValue in
                if newValue.isFutureDayInCurrentCalendar {
                    selectedDate = Date().startOfDayInCurrentCalendar
                }
            }
            .sheet(isPresented: $showExerciseSheet) {
                ExerciseSelectionSheet(items: appState.exerciseLibrary, iconForItem: { item in
                    appState.exerciseIcon(for: item)
                }, displayName: { item in
                    appState.exerciseDisplayName(for: item)
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
        let centerMain = remaining >= 0
            ? "\(localized("剩余", "Left"))\n\(energyText(fromKcal: remaining, includeUnit: false, unit: energyUnit))"
            : "\(localized("超额", "Over"))\n\(energyText(fromKcal: abs(remaining), includeUnit: false, unit: energyUnit))"

        return CardContainer(
            title: localized("运动消耗", "Exercise Burn"),
            subtitle: nil,
            accent: .green
        ) {
            ProgressRing(
                progress: appState.exerciseProgress(on: selectedDate),
                lineWidth: 12,
                gradient: LinearGradient(
                    colors: [.green.opacity(0.84), .mint.opacity(0.74), .green.opacity(0.66)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                accent: .green,
                valueText: centerMain,
                valueUnit: energyUnit.symbol,
                caption: "\(localized("目标", "Target")) \(energyText(fromKcal: goal, unit: energyUnit))"
            )
            .frame(width: ringSize, height: ringSize)
            .frame(maxWidth: .infinity)
        }
    }

    private var exerciseMetricsCard: some View {
        let goal = max(appState.profile.dailyExerciseGoal, 1)
        let burned = todaySummary.caloriesBurned
        let duration = todaySummary.durationMinutes
        let isWarning = burned < goal

        return CardContainer(
            title: localized("运动指标", "Exercise Metrics"),
            subtitle: nil,
            accent: .green
        ) {
            HStack(spacing: 0) {
                metricColumn(symbol: "flame.fill", color: .orange, name: localized("消耗", "Burn"), value: energyText(fromKcal: burned, unit: energyUnit))
                metricColumn(symbol: "clock.fill", color: .blue, name: localized("时长", "Duration"), value: durationDisplayText(fromMinutes: duration))
                metricColumn(symbol: "target", color: .green, name: localized("目标", "Target"), value: energyText(fromKcal: goal, unit: energyUnit))
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
            title: localized("锻炼记录", "Workout Log"),
            subtitle: nil,
            accent: .green
        ) {
            let entryFont = Font.caption.weight(.medium)
            let canEdit = !isFutureDateSelected

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Button {
                        guard canEdit else { return }
                        KeepFitHaptics.impact(.light)
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
                    .disabled(!canEdit)

                    Button {
                        guard canEdit else { return }
                        KeepFitHaptics.impact(.light)
                        showExerciseSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            AppIconBadge(
                                icon: appState.exerciseIcon(for: selectedExercise ?? appState.exerciseLibrary.first ?? SeedData.exerciseLibrary[0]),
                                seed: selectedExercise?.id ?? "exercise_selector",
                                size: 18
                            )
                            Text(selectedExercise.map { appState.exerciseDisplayName(for: $0) } ?? localized("选择运动项目", "Select Exercise"))
                                .font(entryFont)
                                .lineLimit(1)
                                .minimumScaleFactor(0.66)
                                .allowsTightening(true)
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
                    .disabled(!canEdit)

                    HStack(spacing: 6) {
                        TextField("duration", text: $durationText)
                            .font(entryFont)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .duration)
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
                    .disabled(!canEdit)

                    Button {
                        guard canEdit else { return }
                        focusedField = nil
                        KeepFitHaptics.impact(.medium)
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
                    .disabled(!canEdit)
                }

                Divider()

                if todayLogs.isEmpty {
                    Text(localized("今天还没有锻炼记录", "No workout records today"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(todayLogs) { log in
                        HStack(spacing: 10) {
                            AppIconBadge(icon: appState.exerciseIcon(forExerciseID: log.exerciseID), seed: log.exerciseID, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.exerciseDisplayName(forExerciseID: log.exerciseID, fallback: log.exerciseName))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(formattedNumber(log.durationMinutes)) min")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                                Text(energyText(fromKcal: log.caloriesBurned(weightKg: appState.profile.weightKg), unit: energyUnit))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)

                            Button {
                                KeepFitHaptics.impact(.rigid)
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
        let records = appState.dailyExerciseRecords(inMonthOf: selectedDate)
        return CardContainer(
            title: localized("当月锻炼", "Monthly Workout"),
            subtitle: nil,
            accent: .green
        ) {
            if records.isEmpty {
                Text(localized("暂无历史记录", "No history"))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(records) { record in
                        HStack {
                            Text(Formatters.monthDay.string(from: record.date))
                                .font(.subheadline)
                            Spacer()
                            Label(energyText(fromKcal: record.caloriesBurned, unit: energyUnit), systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                            Label(durationDisplayText(fromMinutes: record.minutes), systemImage: "timer")
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
        guard !selectedDate.isFutureDayInCurrentCalendar else { return }
        guard let exercise = selectedExercise else { return }
        guard let minutes = Double(durationText), minutes > 0 else { return }

        let now = selectedDate
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: exerciseTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addExerciseLog(date: date, item: exercise, durationMinutes: minutes)
        durationText = "30"
        focusedField = nil
        onExerciseLogged?()
    }

    private var exerciseTimeSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                DatePicker(
                    localized("锻炼时间", "Workout Time"),
                    selection: $exerciseTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button(localized("完成", "Done")) {
                    KeepFitHaptics.impact(.light)
                    showExerciseTimeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding()
            .navigationTitle(localized("选择锻炼时间", "Select Time"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.green.opacity(colorScheme == .dark ? 0.16 : 0.1),
                                Color.green.opacity(colorScheme == .dark ? 0.06 : 0.04)
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
}

private extension MoveMoreView {
    enum InputField {
        case duration
    }
}
