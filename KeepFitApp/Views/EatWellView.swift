import SwiftUI

struct EatWellView: View {
    @EnvironmentObject private var appState: AppState
    let onSettingsTap: () -> Void

    @State private var selectedFood: FoodItem?
    @State private var intakeTime = Date()
    @State private var amountText = "120"
    @State private var showFoodSheet = false

    private let cardSpacing: CGFloat = 14

    private var todayNutrition: DayNutritionSummary {
        appState.dayNutrition(on: Date())
    }

    private var targetCalories: Double {
        appState.profile.recommendedIntakeForFatLoss
    }

    private var todayLogs: [FoodLog] {
        appState.foodLogs(on: Date())
    }

    private var selectedUnitSymbol: String {
        guard let selectedFood else { return "g" }
        return appState.foodUnitSymbol(for: selectedFood)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardSpacing) {
                    intakeProgressCard
                    todayIntakeCard
                    adviceCard
                    dailyHistoryCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(GrowPageBackground(accent: .orange))
            .navigationTitle("管住嘴")
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
        }
    }

    private var intakeProgressCard: some View {
        let remain = targetCalories - todayNutrition.calories
        let centerMain = remain >= 0 ? "剩余\n\(Int(remain))" : "超出\n\(Int(abs(remain)))"

        return CardContainer(
            title: "今日摄入进度",
            subtitle: nil,
            icon: "chart.pie.fill",
            accent: .orange
        ) {
            HStack(spacing: 16) {
                ProgressRing(
                    progress: appState.intakeProgress(on: Date()),
                    lineWidth: 12,
                    gradient: LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                    valueText: centerMain,
                    caption: "目标 \(Int(targetCalories)) kcal"
                )
                .frame(width: 150, height: 150)

                VStack(alignment: .leading, spacing: 8) {
                    nutrientRow(icon: "fish", name: "蛋白", value: todayNutrition.protein, color: .blue)
                    nutrientRow(icon: "leaf", name: "碳水", value: todayNutrition.carbs, color: .green)
                    nutrientRow(icon: "drop.fill", name: "脂肪", value: todayNutrition.fat, color: .pink)

                    Text("已摄入: \(Int(todayNutrition.calories)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
        }
    }

    private var todayIntakeCard: some View {
        CardContainer(
            title: "今日进食记录",
            subtitle: nil,
            icon: "list.bullet.clipboard",
            accent: .orange
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button {
                        showFoodSheet = true
                    } label: {
                        HStack {
                            AppIconBadge(
                                icon: appState.foodIcon(for: selectedFood ?? appState.foodLibrary.first ?? SeedData.foodLibrary[0]),
                                tint: .orange,
                                size: 30
                            )
                            Text(selectedFood?.name ?? "选择食物")
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

                    TextField("数量(\(selectedUnitSymbol))", text: $amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }

                HStack(spacing: 10) {
                    DatePicker("进食时间", selection: $intakeTime, displayedComponents: [.hourAndMinute])
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("添加") {
                        addFoodLog()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
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
                            AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), tint: .orange, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.foodName)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(Int(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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

    private var adviceCard: some View {
        CardContainer(
            title: "今日进食建议",
            subtitle: nil,
            icon: "lightbulb.max.fill",
            accent: .yellow
        ) {
            Text(appState.foodAdvice(on: Date()))
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyHistoryCard: some View {
        let records = appState.dailyNutritionRecords(limit: 21)
        return CardContainer(
            title: "每天的进食记录",
            subtitle: nil,
            icon: "calendar",
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
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nutrientRow(icon: String, name: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text("\(Int(value)) g")
                .font(.caption.weight(.semibold))
        }
    }

    private func addFoodLog() {
        guard let food = selectedFood else { return }
        guard let amount = Double(amountText), amount > 0 else { return }

        let now = Date()
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: intakeTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addFoodLog(date: date, item: food, grams: amount)
        amountText = String(Int(appState.defaultEntryAmount(for: food)))
    }
}
