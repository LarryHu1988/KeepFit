import SwiftUI
import UIKit

struct EatWellView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.tabSwitchToken) private var tabSwitchToken
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    let onSettingsTap: () -> Void
    var onFoodLogged: (() -> Void)? = nil

    private enum ScreenshotSectionID: String {
        case header
        case progress
        case nutrition
        case foodLog
        case history
    }

    @State private var selectedFood: FoodItem?
    @State private var selectedDate = keepFitInitialSelectedDate()
    @State private var intakeTime = Date()
    @State private var amountText = "120"
    @State private var showFoodSheet = false
    @State private var showIntakeTimeSheet = false
    @State private var naturalLanguageText = ""
    @State private var parsedFoodIntake: ParsedFoodIntake?
    @State private var foodTextErrorMessage = ""
    @State private var showFoodTextError = false
    @State private var foodSaveFeedback = 0
    @FocusState private var focusedField: InputField?

    @ScaledMetric(relativeTo: .body) private var cardSpacing: CGFloat = 22
    @ScaledMetric(relativeTo: .body) private var fieldHeight: CGFloat = 40
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

    private let proteinEmoji = "🍗"
    private let carbsEmoji = "🍚"
    private let fatEmoji = "🧈"

    private var effectiveRingSize: CGFloat {
        min(ringSize, UIScreen.main.bounds.width - 84)
    }

    private var macroEnergy: Double {
        max(1, todayNutrition.protein * 4 + todayNutrition.carbs * 4 + todayNutrition.fat * 9)
    }

    private var screenshotFocusTarget: ScreenshotSectionID? {
        guard KeepFitScreenshotConfig.isEnabled else { return nil }
        switch KeepFitScreenshotConfig.focus {
        case .eatNutrition:
            return .nutrition
        case .eatLog:
            return .foodLog
        default:
            return nil
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GrowPageBackground(accent: .orange)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: cardSpacing) {
                            weekCalendarStrip
                                .id(ScreenshotSectionID.header)
                                .keepFitEntrance(index: 0, trigger: tabSwitchToken)
                            intakeProgressCard
                                .id(ScreenshotSectionID.progress)
                                .keepFitEntrance(index: 1, trigger: tabSwitchToken)
                            intakeMacroCard
                                .id(ScreenshotSectionID.nutrition)
                                .keepFitEntrance(index: 2, trigger: tabSwitchToken)
                            todayIntakeCard
                                .id(ScreenshotSectionID.foodLog)
                                .keepFitEntrance(index: 3, trigger: tabSwitchToken)
                            dailyHistoryCard
                                .id(ScreenshotSectionID.history)
                                .keepFitEntrance(index: 4, trigger: tabSwitchToken)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 18)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.immediately)
                    .gesture(
                        TapGesture().onEnded {
                            if focusedField != nil {
                                keepFitDismissKeyboard()
                                focusedField = nil
                            }
                        },
                        including: focusedField != nil ? .gesture : .none
                    )
                    .onAppear {
                        guard let target = screenshotFocusTarget else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                proxy.scrollTo(target, anchor: .top)
                            }
                        }
                    }
                }
            }
            .navigationTitle(localized("管住嘴", "Eat Well"))
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
                resetSelectedDateForTabSwitch()
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
            .sheet(item: $parsedFoodIntake) { intake in
                NaturalFoodIntakeConfirmationSheet(intake: intake) { date, entries in
                    for entry in entries where entry.grams > 0 {
                        appState.addFoodLog(date: date, item: entry.food, grams: entry.grams)
                    }
                    if entries.contains(where: { $0.grams > 0 }) {
                        foodSaveFeedback += 1
                    }
                    naturalLanguageText = ""
                    onFoodLogged?()
                }
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .alert(localized("无法识别", "Unable to Recognize"), isPresented: $showFoodTextError) {
                Button(localized("知道了", "OK"), role: .cancel) {}
            } message: {
                Text(foodTextErrorMessage)
            }
        }
    }

    private var weekCalendarStrip: some View {
        WeekStripCalendarView(
            selectedDate: $selectedDate,
            accent: .orange,
            indicatorColor: { date in
                guard appState.hasFoodRecord(on: date) else { return nil }
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
                VStack(alignment: .leading, spacing: 8) {
                    Label(localized("文字识别录入", "Text Food Entry"), systemImage: "text.viewfinder")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)

                    TextField(
                        localized(
                            "例如：今天中午 12 点吃了 20 个猪肉白菜饺子",
                            "Example: 20 pork and cabbage dumplings at noon today"
                        ),
                        text: $naturalLanguageText,
                        axis: .vertical
                    )
                    .font(.subheadline)
                    .lineLimit(2...4)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .naturalLanguage)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(inputFieldBackground)
                    .disabled(!canEdit)

                    HStack(spacing: 10) {
                        Text(localized(
                            "识别后可核对时间、食物和重量",
                            "Review the time, food, and weight before saving"
                        ))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 4)

                        Button {
                            parseNaturalLanguageFood()
                        } label: {
                            Label(localized("识别", "Recognize"), systemImage: "wand.and.stars")
                                .font(.caption.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(
                            !canEdit ||
                            naturalLanguageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        )
                    }
                }

                Divider()

                GeometryReader { proxy in
                    let totalWidth = max(0, proxy.size.width)
                    let layout = intakeRowLayout(for: totalWidth)
                    let entryFont = layout.font

                    HStack(spacing: layout.spacing) {
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
                                    .minimumScaleFactor(0.92)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, layout.horizontalPadding)
                            .frame(width: layout.timeWidth, height: fieldHeight)
                            .background(inputFieldBackground)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canEdit)

                        Button {
                            guard canEdit else { return }
                            KeepFitHaptics.impact(.light)
                            showFoodSheet = true
                        } label: {
                            HStack(spacing: layout.iconSize <= 16 ? 6 : 8) {
                                AppIconBadge(
                                    icon: appState.foodIcon(for: selectedFood ?? appState.foodLibrary.first ?? SeedData.foodLibrary[0]),
                                    seed: selectedFood?.id ?? "food_selector",
                                    size: layout.iconSize
                                )
                                Text(selectedFood.map { appState.foodDisplayName(for: $0) } ?? localized("选择食物", "Select Food"))
                                    .font(entryFont)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.76)
                                    .allowsTightening(true)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, layout.horizontalPadding - 1)
                            .frame(width: layout.selectorWidth, height: fieldHeight, alignment: .leading)
                            .background(inputFieldBackground)
                        }
                        .buttonStyle(.plain)
                        .layoutPriority(1)
                        .disabled(!canEdit)

                        HStack(spacing: layout.unitSpacing) {
                            TextField("", text: $amountText)
                                .font(entryFont)
                                .textFieldStyle(.plain)
                                .keyboardType(.decimalPad)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .amount)
                                .submitLabel(.done)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                                .minimumScaleFactor(0.92)
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
                        .padding(.horizontal, layout.horizontalPadding - 1)
                        .frame(width: layout.valueWidth, height: fieldHeight)
                        .background(inputFieldBackground)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard canEdit else { return }
                            focusedField = .amount
                            keepFitPlaceCursorAtEndIfTextField()
                        }
                        .disabled(!canEdit)

                        KeepFitFluidActionButton(
                            systemImage: "plus",
                            accent: .orange,
                            size: layout.actionWidth,
                            iconSize: layout.actionIconSize,
                            feedbackToken: foodSaveFeedback
                        ) {
                            guard canEdit else { return }
                            focusedField = nil
                            KeepFitHaptics.impact(.medium)
                            addFoodLog()
                        }
                        .frame(width: layout.actionWidth, height: fieldHeight)
                        .disabled(!canEdit)
                        .accessibilityLabel(localized("添加进食记录", "Add Food Log"))
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
        foodSaveFeedback += 1
        amountText = String(Int(appState.defaultEntryAmount(for: food)))
        focusedField = nil
        onFoodLogged?()
    }

    private func parseNaturalLanguageFood() {
        guard !selectedDate.isFutureDayInCurrentCalendar else { return }
        focusedField = nil
        keepFitDismissKeyboard()

        do {
            parsedFoodIntake = try FoodTextParser.parse(
                naturalLanguageText,
                referenceDate: selectedDate,
                foodLibrary: appState.foodLibrary,
                defaultAmount: { appState.defaultEntryAmount(for: $0) }
            )
            KeepFitHaptics.impact(.medium)
        } catch {
            foodTextErrorMessage = error.localizedDescription
            showFoodTextError = true
            KeepFitHaptics.impact(.rigid)
        }
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

    private func resetSelectedDateForTabSwitch() {
        let today = Date().startOfDayInCurrentCalendar
        guard selectedDate != today else { return }
        DispatchQueue.main.async {
            let resolvedToday = Date().startOfDayInCurrentCalendar
            guard selectedDate != resolvedToday else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selectedDate = resolvedToday
            }
        }
    }
}

private extension EatWellView {
    struct IntakeRowLayout {
        let fontSize: CGFloat
        let spacing: CGFloat
        let timeWidth: CGFloat
        let selectorWidth: CGFloat
        let valueWidth: CGFloat
        let actionWidth: CGFloat
        let iconSize: CGFloat
        let horizontalPadding: CGFloat
        let unitSpacing: CGFloat
        let actionIconSize: CGFloat

        var font: Font {
            .system(size: fontSize, weight: .medium)
        }
    }

    enum InputField {
        case amount
        case naturalLanguage
    }
}

private struct NaturalFoodIntakeConfirmationSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue

    let originalText: String
    let notes: [String]
    let onConfirm: (Date, [ParsedFoodEntry]) -> Void

    @State private var date: Date
    @State private var entries: [ParsedFoodEntry]

    init(
        intake: ParsedFoodIntake,
        onConfirm: @escaping (Date, [ParsedFoodEntry]) -> Void
    ) {
        originalText = intake.originalText
        notes = intake.notes
        self.onConfirm = onConfirm
        _date = State(initialValue: intake.date)
        _entries = State(initialValue: intake.entries)
    }

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var canSave: Bool {
        !entries.isEmpty && entries.allSatisfy { $0.grams > 0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GrowPageBackground(accent: .orange)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(localized("原始输入", "Original Entry"))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(originalText)
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Label(localized("进食时间", "Intake Time"), systemImage: "clock")
                                .font(.subheadline.weight(.semibold))
                            DatePicker(
                                localized("日期与时间", "Date and Time"),
                                selection: $date,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                        ForEach($entries) { $entry in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 10) {
                                    AppIconBadge(
                                        icon: appState.foodIcon(for: entry.food),
                                        seed: entry.food.id,
                                        size: 32
                                    )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(appState.foodDisplayName(for: entry.food))
                                            .font(.headline)
                                        Text(entry.quantityDescription)
                                            .font(.caption)
                                            .foregroundStyle(entry.amountWasEstimated ? Color.orange : Color.secondary)
                                    }
                                    Spacer()
                                }

                                HStack {
                                    Text(localized("确认重量", "Confirm Weight"))
                                        .font(.subheadline)
                                    Spacer()
                                    TextField(
                                        localized("克", "Grams"),
                                        value: $entry.grams,
                                        format: .number.precision(.fractionLength(0...1))
                                    )
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 100)
                                    Text("g")
                                        .foregroundStyle(.secondary)
                                }

                                HStack(spacing: 8) {
                                    nutritionPill(
                                        energyText(fromKcal: entry.calories, unit: energyUnit),
                                        color: .orange
                                    )
                                    nutritionPill("P \(formatted(entry.protein)) g", color: .red)
                                    nutritionPill("C \(formatted(entry.carbs)) g", color: .blue)
                                    nutritionPill("F \(formatted(entry.fat)) g", color: .yellow)
                                }

                                if let reference = entry.food.nutritionReference {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Label(reference.basis.title, systemImage: sourceIcon(for: reference.basis))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(reference.basis == .recipeEstimate ? Color.orange : Color.green)
                                        if let note = reference.note {
                                            Text(note)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        if let url = reference.sourceURL {
                                            Link(destination: url) {
                                                Label(reference.sourceName, systemImage: "arrow.up.right.square")
                                                    .font(.caption)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(14)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 7) {
                                ForEach(notes, id: \.self) { note in
                                    Label(note, systemImage: "info.circle")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 2)
                        }

                        Button {
                            KeepFitHaptics.impact(.medium)
                            onConfirm(date, entries)
                            dismiss()
                        } label: {
                            Text(localized("确认并保存记录", "Confirm and Save"))
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .controlSize(.large)
                        .disabled(!canSave)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(localized("确认识别结果", "Review Result"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(localized("取消", "Cancel")) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func nutritionPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }

    private func sourceIcon(for basis: FoodNutritionBasis) -> String {
        switch basis {
        case .licensedChinaFoodComposition:
            return "checkmark.seal.fill"
        case .manufacturerLabel:
            return "doc.text"
        case .recipeEstimate:
            return "exclamationmark.triangle.fill"
        case .genericReference:
            return "book.closed"
        }
    }

    private func formatted(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.05 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

private extension EatWellView {
    func intakeRowLayout(for totalWidth: CGFloat) -> IntakeRowLayout {
        let amountSample = amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "120" : amountText
        let presets: [(fontSize: CGFloat, spacing: CGFloat, actionWidth: CGFloat, iconSize: CGFloat, padding: CGFloat, unitSpacing: CGFloat, selectorMin: CGFloat)] = [
            (14, 6, 34, 18, 10, 6, 110),
            (13, 5, 32, 17, 8, 5, 102),
            (12, 4, 30, 16, 7, 4, 92)
        ]

        for preset in presets {
            let timeWidth = max(
                keepFitMeasuredTextWidth("23:59", size: preset.fontSize, weight: .medium, monospacedDigits: true) + preset.padding * 2 + 18,
                74
            )
            let valueWidth = max(
                keepFitMeasuredTextWidth(amountSample, size: preset.fontSize, weight: .medium, monospacedDigits: true)
                    + keepFitMeasuredTextWidth(selectedUnitSymbol, size: preset.fontSize, weight: .medium)
                    + preset.padding * 2 + preset.unitSpacing + 4,
                58
            )
            let selectorWidth = totalWidth - timeWidth - valueWidth - preset.actionWidth - preset.spacing * 3
            if selectorWidth >= preset.selectorMin {
                return IntakeRowLayout(
                    fontSize: preset.fontSize,
                    spacing: preset.spacing,
                    timeWidth: timeWidth,
                    selectorWidth: selectorWidth,
                    valueWidth: valueWidth,
                    actionWidth: preset.actionWidth,
                    iconSize: preset.iconSize,
                    horizontalPadding: preset.padding,
                    unitSpacing: preset.unitSpacing,
                    actionIconSize: max(12, preset.fontSize - 1)
                )
            }
        }

        let fallback = presets.last!
        let timeWidth = max(
            keepFitMeasuredTextWidth("23:59", size: fallback.fontSize, weight: .medium, monospacedDigits: true) + fallback.padding * 2 + 16,
            70
        )
        let valueWidth = max(
            keepFitMeasuredTextWidth("120", size: fallback.fontSize, weight: .medium, monospacedDigits: true)
                + keepFitMeasuredTextWidth(selectedUnitSymbol, size: fallback.fontSize, weight: .medium)
                + fallback.padding * 2 + fallback.unitSpacing + 4,
            54
        )
        let selectorWidth = max(74, totalWidth - timeWidth - valueWidth - fallback.actionWidth - fallback.spacing * 3)

        return IntakeRowLayout(
            fontSize: fallback.fontSize,
            spacing: fallback.spacing,
            timeWidth: timeWidth,
            selectorWidth: selectorWidth,
            valueWidth: valueWidth,
            actionWidth: fallback.actionWidth,
            iconSize: fallback.iconSize,
            horizontalPadding: fallback.padding,
            unitSpacing: fallback.unitSpacing,
            actionIconSize: max(12, fallback.fontSize - 1)
        )
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
