import SwiftUI

struct EatWellView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedFood: FoodItem?
    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var intakeTime = Date()
    @State private var amountText = "120"
    @State private var showFoodSheet = false
    @State private var showIntakeTimeSheet = false

    private let cardSpacing: CGFloat = 24
    private let fieldHeight: CGFloat = 36
    private let timeFieldWidth: CGFloat = 82
    private let compactFieldWidth: CGFloat = 58

    private var todayNutrition: DayNutritionSummary {
        appState.dayNutrition(on: selectedDate)
    }

    private var targetCalories: Double {
        appState.profile.recommendedIntakeForFatLoss
    }

    private var todayLogs: [FoodLog] {
        appState.foodLogs(on: selectedDate)
    }

    private var selectedUnitSymbol: String {
        guard let selectedFood else { return "g" }
        return appState.foodUnitSymbol(for: selectedFood)
    }

    private var macroEnergy: Double {
        max(1, todayNutrition.protein * 4 + todayNutrition.carbs * 4 + todayNutrition.fat * 9)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardSpacing) {
                    weekCalendarStrip
                    intakeProgressCard
                    intakeMacroCard
                    todayIntakeCard
                    dailyHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity)
            }
            .background(GrowPageBackground(accent: .orange))
            .navigationTitle("管住嘴")
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
                    .accessibilityLabel("设置")
                }
            }
            .onAppear {
                if selectedFood == nil {
                    selectedFood = appState.foodLibrary.first
                }
                if let selectedFood {
                    amountText = String(Int(appState.defaultEntryAmount(for: selectedFood)))
                }
            }
            .sheet(isPresented: $showFoodSheet) {
                FoodSelectionSheet(items: appState.foodLibrary, iconForItem: { item in
                    appState.foodIcon(for: item)
                }) { item in
                    selectedFood = item
                    amountText = String(Int(appState.defaultEntryAmount(for: item)))
                }
            }
            .sheet(isPresented: $showIntakeTimeSheet) {
                intakeTimeSheet
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
            accent: .orange,
            indicatorColor: { date in
                let logs = appState.foodLogs(on: date)
                guard !logs.isEmpty else { return nil }
                let intake = appState.dayNutrition(on: date).calories
                return intake > appState.profile.recommendedIntakeForFatLoss ? .red : .green
            }
        )
    }

    private var intakeProgressCard: some View {
        let remain = targetCalories - todayNutrition.calories
        let centerMain = remain >= 0 ? "剩余\n\(Int(remain))" : "超出\n\(Int(abs(remain)))"

        return CardContainer(
            title: "摄入进度",
            subtitle: nil,
            accent: .orange
        ) {
            ProgressRing(
                progress: appState.intakeProgress(on: selectedDate),
                lineWidth: 12,
                gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                valueText: centerMain,
                caption: "目标 \(Int(targetCalories)) kcal"
            )
            .frame(width: 186, height: 186)
            .frame(maxWidth: .infinity)
        }
    }

    private var intakeMacroCard: some View {
        let advice = appState.foodAdvice(on: selectedDate)
        let warningKeywords = ["超目标", "偏低", "偏高", "不再加餐"]
        let isWarning = warningKeywords.contains { advice.contains($0) } || todayNutrition.calories > targetCalories

        return CardContainer(
            title: "营养结构",
            subtitle: nil,
            accent: .orange
        ) {
            HStack(spacing: 0) {
                nutrientColumn(icon: "🥩", name: "蛋白", value: "\(Int(todayNutrition.protein)) g", percent: Int(todayNutrition.protein * 4 / macroEnergy * 100))
                nutrientColumn(icon: "🍚", name: "碳水", value: "\(Int(todayNutrition.carbs)) g", percent: Int(todayNutrition.carbs * 4 / macroEnergy * 100))
                nutrientColumn(icon: "🥑", name: "脂肪", value: "\(Int(todayNutrition.fat)) g", percent: Int(todayNutrition.fat * 9 / macroEnergy * 100))
            }
            .frame(maxWidth: .infinity)

            Text(advice)
                .font(.caption)
                .foregroundStyle(isWarning ? Color.red : Color.green)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
        }
    }

    private var todayIntakeCard: some View {
        CardContainer(
            title: "进食记录",
            subtitle: nil,
            accent: .orange
        ) {
            let entryFont = Font.caption.weight(.medium)

            VStack(spacing: 10) {
                HStack(spacing: 6) {
                    Button {
                        showIntakeTimeSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(Formatters.hourMinute.string(from: intakeTime))
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
                        showFoodSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            AppIconBadge(
                                icon: appState.foodIcon(for: selectedFood ?? appState.foodLibrary.first ?? SeedData.foodLibrary[0]),
                                seed: selectedFood?.id ?? "food_selector",
                                size: 20
                            )
                            Text(selectedFood?.name ?? "选择食物")
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
                        TextField("amount", text: $amountText)
                            .font(entryFont)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(selectedUnitSymbol)
                            .font(entryFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .padding(.horizontal, 8)
                    .frame(width: compactFieldWidth, height: fieldHeight)
                    .background(inputFieldBackground)

                    Button {
                        addFoodLog()
                    } label: {
                        Image(systemName: "plus")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 14, height: 14)
                            .padding(9)
                            .background(
                                Circle()
                                    .fill(Color.orange.opacity(0.9))
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
                    Text("今天还没有进食记录")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(todayLogs) { log in
                        HStack(spacing: 10) {
                            AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), seed: log.foodID, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.foodName)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(formattedAmount(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text("\(Int(log.calories)) kcal")
                                .font(.subheadline)
                                .foregroundStyle(.orange)

                            Button {
                                appState.deleteFoodLog(log)
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
        let records = appState.dailyNutritionRecords(limit: 21)
        return CardContainer(
            title: "历史进食",
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
                            Label("\(Int(record.calories)) kcal", systemImage: "flame")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Label("P\(Int(record.protein)) C\(Int(record.carbs)) F\(Int(record.fat))", systemImage: "chart.bar")
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
    private func nutrientColumn(icon: String, name: String, value: String, percent: Int) -> some View {
        VStack(spacing: 5) {
            Text(icon)
                .font(.title3)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
            Text("\(max(0, percent))%")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedAmount(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }

    private func addFoodLog() {
        guard let food = selectedFood else { return }
        guard let amount = Double(amountText), amount > 0 else { return }

        let now = selectedDate
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: intakeTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addFoodLog(date: date, item: food, grams: amount)
        amountText = String(Int(appState.defaultEntryAmount(for: food)))
    }

    private var intakeTimeSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                DatePicker(
                    "进食时间",
                    selection: $intakeTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("完成") {
                    showIntakeTimeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .navigationTitle("选择进食时间")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var inputFieldBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.35))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(.white.opacity(0.8), lineWidth: 1)
            )
    }
}
