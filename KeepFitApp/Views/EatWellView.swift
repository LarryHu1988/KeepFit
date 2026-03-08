import SwiftUI
import UIKit

struct EatWellView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    let onSettingsTap: () -> Void
    var onFoodLogged: (() -> Void)? = nil

    @State private var selectedFood: FoodItem?
    @State private var selectedDate = Date().startOfDayInCurrentCalendar
    @State private var intakeTime = Date()
    @State private var amountText = "120"
    @State private var showFoodSheet = false
    @State private var showIntakeTimeSheet = false
    @FocusState private var focusedField: InputField?

    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 40
    @ScaledMetric(relativeTo: .body) private var timeFieldWidth: CGFloat = 90
    @ScaledMetric(relativeTo: .body) private var compactFieldWidth: CGFloat = 62
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 194

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
        guard let selectedFood else { return localized("g", "g") }
        return appState.foodUnitSymbol(for: selectedFood)
    }

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var isFutureDateSelected: Bool {
        selectedDate.isFutureDayInCurrentCalendar
    }

    private var barBackgroundTint: Color {
        colorScheme == .dark
            ? Color.orange.opacity(0.22)
            : Color.orange.opacity(0.14)
    }

    private let proteinEmoji = "🍗"
    private let carbsEmoji = "🍚"
    private let fatEmoji = "🧈"

    private var effectiveRingSize: CGFloat {
        min(ringSize, UIScreen.main.bounds.width - 84)
    }

    private var macroEnergy: Double {
        max(1, todayNutrition.protein * 4 + todayNutrition.carbs * 4 + todayNutrition.fat * 9)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GrowPageBackground(accent: .orange)

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
                .scrollDismissesKeyboard(.immediately)
                .simultaneousGesture(
                    TapGesture().onEnded {
                        if focusedField != nil {
                            keepFitDismissKeyboard()
                            focusedField = nil
                        }
                    }
                )
            }
            .navigationTitle(localized("管住嘴", "Eat Well"))
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
                    .accessibilityLabel(localized("设置", "Settings"))
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(localized("完成", "Done")) {
                        focusedField = nil
                    }
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
            .onChange(of: tabSwitchToken) { _, _ in
                selectedDate = Date().startOfDayInCurrentCalendar
            }
            .onChange(of: selectedDate) { _, newValue in
                if newValue.isFutureDayInCurrentCalendar {
                    selectedDate = Date().startOfDayInCurrentCalendar
                }
            }
            .onChange(of: focusedField) { _, newValue in
                if newValue == .amount {
                    keepFitPlaceCursorAtEndIfTextField()
                }
            }
            .sheet(isPresented: $showFoodSheet) {
                FoodSelectionSheet(items: appState.foodLibrary, iconForItem: { item in
                    appState.foodIcon(for: item)
                }, displayName: { item in
                    appState.foodDisplayName(for: item)
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
        let centerMain = remain >= 0
            ? "\(localized("剩余", "Left"))\n\(energyText(fromKcal: remain, includeUnit: false, unit: energyUnit))"
            : "\(localized("超出", "Over"))\n\(energyText(fromKcal: abs(remain), includeUnit: false, unit: energyUnit))"

        return CardContainer(
            title: localized("摄入进度", "Intake Progress"),
            subtitle: nil,
            accent: .orange
        ) {
            ProgressRing(
                progress: appState.intakeProgress(on: selectedDate),
                lineWidth: 12,
                gradient: LinearGradient(
                    colors: [.orange.opacity(0.86), .yellow.opacity(0.72), .orange.opacity(0.68)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                accent: .orange,
                valueText: centerMain,
                valueUnit: energyUnit.symbol,
                caption: "\(localized("目标", "Target")) \(energyText(fromKcal: targetCalories, unit: energyUnit))"
            )
            .frame(width: effectiveRingSize, height: effectiveRingSize)
            .frame(maxWidth: .infinity)
        }
    }

    private var intakeMacroCard: some View {
        let advice = appState.foodAdvice(on: selectedDate)
        let warningKeywords = ["超目标", "偏低", "偏高", "不再加餐"]
        let isWarning = warningKeywords.contains { advice.contains($0) } || todayNutrition.calories > targetCalories

        return CardContainer(
            title: localized("营养结构", "Nutrition"),
            subtitle: nil,
            accent: .orange
        ) {
            HStack(spacing: 0) {
                nutrientColumn(iconEmoji: proteinEmoji, name: localized("蛋白", "Protein"), value: "\(Int(todayNutrition.protein)) g", percent: Int(todayNutrition.protein * 4 / macroEnergy * 100))
                nutrientColumn(iconEmoji: carbsEmoji, name: localized("碳水", "Carbs"), value: "\(Int(todayNutrition.carbs)) g", percent: Int(todayNutrition.carbs * 4 / macroEnergy * 100))
                nutrientColumn(iconEmoji: fatEmoji, name: localized("脂肪", "Fat"), value: "\(Int(todayNutrition.fat)) g", percent: Int(todayNutrition.fat * 9 / macroEnergy * 100))
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
            title: localized("进食记录", "Food Log"),
            subtitle: nil,
            accent: .orange
        ) {
            let canEdit = !isFutureDateSelected

            VStack(spacing: 10) {
                GeometryReader { proxy in
                    let totalWidth = max(0, proxy.size.width)
                    let compactLayout = totalWidth < 340 || dynamicTypeSize >= .xxxLarge
                    let entryFont: Font = compactLayout ? .system(size: 13, weight: .medium) : .system(size: 15, weight: .medium)
                    let spacing: CGFloat = compactLayout ? 5 : 6
                    let actionWidth: CGFloat = compactLayout ? 32 : 34
                    let timeWidth = min(max(compactLayout ? 72 : 84, totalWidth * 0.21), compactLayout ? 82 : 96)
                    let amountWidth = min(max(compactLayout ? 54 : 60, totalWidth * 0.14), compactLayout ? 62 : 70)
                    let selectorWidth = max(102, totalWidth - timeWidth - amountWidth - actionWidth - spacing * 3)

                    HStack(spacing: spacing) {
                        Button {
                            guard canEdit else { return }
                            KeepFitHaptics.impact(.light)
                            showIntakeTimeSheet = true
                        } label: {
                            HStack(spacing: 5) {
                                Text(Formatters.hourMinute.string(from: intakeTime))
                                    .font(entryFont)
                                    .monospacedDigit()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, compactLayout ? 8 : 10)
                            .frame(width: timeWidth, height: fieldHeight)
                            .background(inputFieldBackground)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canEdit)

                        Button {
                            guard canEdit else { return }
                            KeepFitHaptics.impact(.light)
                            showFoodSheet = true
                        } label: {
                            HStack(spacing: compactLayout ? 6 : 8) {
                                AppIconBadge(
                                    icon: appState.foodIcon(for: selectedFood ?? appState.foodLibrary.first ?? SeedData.foodLibrary[0]),
                                    seed: selectedFood?.id ?? "food_selector",
                                    size: compactLayout ? 16 : 18
                                )
                                Text(selectedFood.map { appState.foodDisplayName(for: $0) } ?? localized("选择食物", "Select Food"))
                                    .font(entryFont)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.56)
                                    .allowsTightening(true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, compactLayout ? 7 : 8)
                            .frame(width: selectorWidth, height: fieldHeight, alignment: .leading)
                            .background(inputFieldBackground)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)
                        .disabled(!canEdit)

                        HStack(spacing: compactLayout ? 4 : 6) {
                            TextField(text: $amountText) {
                                EmptyView()
                            }
                            .font(entryFont)
                            .keyboardType(.decimalPad)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .amount)
                            .submitLabel(.done)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                guard canEdit else { return }
                                focusedField = .amount
                                keepFitPlaceCursorAtEndIfTextField()
                            }
                            Text(selectedUnitSymbol)
                                .font(entryFont)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        .padding(.horizontal, compactLayout ? 7 : 8)
                        .frame(width: amountWidth, height: fieldHeight)
                        .background(inputFieldBackground)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard canEdit else { return }
                            focusedField = .amount
                            keepFitPlaceCursorAtEndIfTextField()
                        }
                        .disabled(!canEdit)

                        Button {
                            guard canEdit else { return }
                            focusedField = nil
                            KeepFitHaptics.impact(.medium)
                            addFoodLog()
                        } label: {
                            Image(systemName: "plus")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 14, height: 14)
                                .padding(compactLayout ? 8 : 9)
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
                        .frame(width: actionWidth, height: fieldHeight)
                        .disabled(!canEdit)
                    }
                }
                .frame(height: fieldHeight)

                if !todayLogs.isEmpty {
                    Divider()
                    ForEach(todayLogs) { log in
                        HStack(spacing: 10) {
                            AppIconBadge(icon: appState.foodIcon(forFoodID: log.foodID), seed: log.foodID, size: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.foodDisplayName(forFoodID: log.foodID, fallback: log.foodName))
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(Formatters.hourMinute.string(from: log.date))  ·  \(formattedAmount(log.weightGrams))\(appState.foodUnitSymbol(forFoodID: log.foodID))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(energyText(fromKcal: log.calories, unit: energyUnit))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.orange)

                            Button {
                                KeepFitHaptics.impact(.rigid)
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
        let records = appState.dailyNutritionRecords(inMonthOf: selectedDate)
        return CardContainer(
            title: localized("当月进食", "Monthly Food"),
            subtitle: nil,
            accent: .orange
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
                            Label(energyText(fromKcal: record.calories, unit: energyUnit), systemImage: "flame")
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
    private func nutrientColumn(iconEmoji: String, name: String, value: String, percent: Int) -> some View {
        VStack(spacing: 5) {
            Text(iconEmoji)
                .font(.system(size: 18))
                .frame(height: 22)
                .accessibilityHidden(true)
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
        guard !selectedDate.isFutureDayInCurrentCalendar else { return }
        guard let food = selectedFood else { return }
        guard let amount = Double(amountText), amount > 0 else { return }

        let now = selectedDate
        let calendar = Calendar.current
        let selectedComponents = calendar.dateComponents([.hour, .minute], from: intakeTime)
        let date = calendar.date(bySettingHour: selectedComponents.hour ?? 0, minute: selectedComponents.minute ?? 0, second: 0, of: now) ?? now

        appState.addFoodLog(date: date, item: food, grams: amount)
        amountText = String(Int(appState.defaultEntryAmount(for: food)))
        focusedField = nil
        onFoodLogged?()
    }

    private var intakeTimeSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                DatePicker(
                    localized("进食时间", "Intake Time"),
                    selection: $intakeTime,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button(localized("完成", "Done")) {
                    KeepFitHaptics.impact(.light)
                    showIntakeTimeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }
            .padding()
            .navigationTitle(localized("选择进食时间", "Select Time"))
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
                                Color.orange.opacity(colorScheme == .dark ? 0.16 : 0.1),
                                Color.orange.opacity(colorScheme == .dark ? 0.06 : 0.04)
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

private extension EatWellView {
    enum InputField {
        case amount
    }
}

private weak var keepFitCurrentFirstResponder: UIResponder?

extension UIResponder {
    @objc fileprivate func keepFitCaptureFirstResponder() {
        keepFitCurrentFirstResponder = self
    }
}

func keepFitDismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

private func keepFitFindCurrentFirstResponder() -> UIResponder? {
    keepFitCurrentFirstResponder = nil
    UIApplication.shared.sendAction(#selector(UIResponder.keepFitCaptureFirstResponder), to: nil, from: nil, for: nil)
    return keepFitCurrentFirstResponder
}

func keepFitPlaceCursorAtEndIfTextField() {
    DispatchQueue.main.async {
        guard let textField = keepFitFindCurrentFirstResponder() as? UITextField else { return }
        let end = textField.endOfDocument
        textField.selectedTextRange = textField.textRange(from: end, to: end)
    }
}
