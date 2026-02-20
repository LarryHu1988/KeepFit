import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @AppStorage("keepfit.reminder") private var reminderEnabled = true
    @AppStorage("keepfit.haptic") private var hapticEnabled = true
    @AppStorage("keepfit.autoSync") private var autoSyncEnabled = false
    @AppStorage("keepfit.themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @AppStorage("keepfit.unit.height") private var heightUnitRaw = HeightUnitOption.centimeter.rawValue
    @AppStorage("keepfit.unit.weight") private var weightUnitRaw = WeightUnitOption.kilogram.rawValue
    @AppStorage("keepfit.calendar.weekStart") private var weekStartRaw = WeekStartOption.sunday.rawValue
    @AppStorage("keepfit.appLanguage") private var appLanguageRaw = AppLanguageOption.chinese.rawValue
    @AppStorage("keepfit.birthDateTS") private var birthDateTimestamp: Double = 0

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var showSexSheet = false
    @State private var showActivitySheet = false
    @State private var showUnitSheet = false
    @State private var showEnergyUnitSheet = false
    @State private var showHeightUnitSheet = false
    @State private var showWeightUnitSheet = false
    @State private var showHeightSheet = false
    @State private var showWeightSheet = false
    @State private var showBirthSheet = false
    @State private var showWeekStartSheet = false
    @State private var showLanguageSheet = false
    @State private var showThemeSheet = false
    @State private var showTargetWeightSheet = false
    @State private var showTargetBodyFatSheet = false
    @State private var showExerciseGoalSheet = false

    @State private var metricHeightDraft = 170
    @State private var imperialHeightFeetDraft = 5
    @State private var imperialHeightInchesDraft = 7
    @State private var metricWeightHalfDraft = 140
    @State private var imperialWeightLbDraft = 154
    @State private var birthYearDraft = 1998
    @State private var birthMonthDraft = 1
    @State private var birthDayDraft = 1
    @State private var targetMetricWeightHalfDraft = 130
    @State private var targetImperialWeightLbDraft = 143
    @State private var targetBodyFatTenthDraft = 180
    @State private var exerciseGoalDraft = 300

    @State private var activeInfo: SettingsInfoTopic?

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var heightUnit: HeightUnitOption {
        HeightUnitOption(rawValue: heightUnitRaw) ?? .centimeter
    }

    private var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: weightUnitRaw) ?? .kilogram
    }

    private var weekStart: WeekStartOption {
        WeekStartOption(rawValue: weekStartRaw) ?? .sunday
    }

    private var appLanguage: AppLanguageOption {
        AppLanguageOption(rawValue: appLanguageRaw) ?? .chinese
    }

    private var resolvedBirthDate: Date {
        if birthDateTimestamp > 0 {
            return Date(timeIntervalSince1970: birthDateTimestamp)
        }
        return birthDateFromAge(appState.profile.age)
    }

    private var heightDisplayLabel: String {
        KeepFit.heightDisplayText(fromCm: appState.profile.heightCm, unit: heightUnit)
    }

    private var weightDisplayText: String {
        weightText(fromKg: appState.profile.weightKg, decimals: 1, includeUnit: true, unit: weightUnit)
    }

    private var birthDisplayText: String {
        Formatters.yearMonthDay.string(from: resolvedBirthDate)
    }

    private var targetWeightDisplayLabel: String {
        weightText(fromKg: appState.profile.targetWeightKg, decimals: 1, includeUnit: true, unit: weightUnit)
    }

    private var targetBodyFatDisplayLabel: String {
        String(format: "%.1f %%", appState.profile.targetBodyFat)
    }

    private var exerciseGoalDisplayLabel: String {
        energyText(fromKcal: appState.profile.dailyExerciseGoal, includeUnit: true, unit: energyUnit)
    }

    private var exerciseGoalRange: [Int] {
        switch energyUnit {
        case .kcal:
            return Array(stride(from: 50, through: 1500, by: 10))
        case .kJ:
            return Array(stride(from: 200, through: 6300, by: 40))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                avatarSection
                basicInfoSection
                goalsAdviceSection
                commonSettingsSection
            }
            .navigationTitle(localized("个人设置", "Settings"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                ensureBirthDateSeeded()
                syncHeightDrafts()
                syncWeightDrafts()
                syncBirthDrafts()
                syncGoalDrafts()
            }
            .onChange(of: selectedAvatarItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let compressed = image.jpegData(compressionQuality: 0.75) {
                        appState.profile.avatarJPEGData = compressed
                    }
                    selectedAvatarItem = nil
                }
            }
            .onChange(of: heightUnitRaw) { _, _ in
                syncHeightDrafts()
            }
            .onChange(of: weightUnitRaw) { _, _ in
                syncWeightDrafts()
                syncGoalDrafts()
            }
            .onChange(of: energyUnitRaw) { _, _ in
                syncGoalDrafts()
            }
        }
        .preferredColorScheme(themeMode.preferredColorScheme)
    }

    private var avatarSection: some View {
        Section {
            HStack(spacing: 14) {
                PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                    avatarView
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    TextField(localized("用户名", "Username"), text: binding(\.name))
                        .textFieldStyle(.roundedBorder)
                    Text("KeepFit · 管住嘴迈开腿")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text(localized("个人头像", "Avatar"))
        }
    }

    private var basicInfoSection: some View {
        Section {
            sexSelectionRow
            birthSelectionRow
            heightSelectionRow
            weightSelectionRow
            activitySelectionRow
        } header: {
            Text(localized("基础信息", "Basic Info"))
        }
    }

    private var goalsAdviceSection: some View {
        Section {
            targetWeightSelectionRow
            targetBodyFatSelectionRow
            exerciseGoalSelectionRow
            bmrInfoRow
            tdeeInfoRow
            intakeInfoRow
        } header: {
            Text(localized("目标与建议", "Goals & Advice"))
        }
    }

    private var commonSettingsSection: some View {
        Section {
            languageSelectionRow
            energyUnitSelectionRow
            heightUnitSelectionRow
            weightUnitSelectionRow
            weekStartSelectionRow
            themeSelectionRow

            Toggle(isOn: $hapticEnabled) {
                HStack(spacing: 10) {
                    rowIcon("hand.tap", .blue)
                    Text(localized("触感反馈", "Haptics"))
                }
            }

            Toggle(isOn: $reminderEnabled) {
                HStack(spacing: 10) {
                    rowIcon("bell", .orange)
                    Text(localized("饮食/运动提醒", "Diet/Exercise Reminder"))
                }
            }

            Toggle(isOn: $autoSyncEnabled) {
                HStack(spacing: 10) {
                    rowIcon("arrow.triangle.2.circlepath", .green)
                    Text(localized("自动同步健康数据", "Auto Sync Health Data"))
                }
            }
        } header: {
            Text(localized("常用设置", "Common Settings"))
        }
    }

    private var sexSelectionRow: some View {
        selectionPopoverRow(icon: "person.fill", title: localized("性别", "Sex"), color: .pink, value: appState.profile.sex.title, isPresented: $showSexSheet) {
            glassOptionPopover(accent: .pink, title: localized("选择性别", "Select Sex")) {
                ForEach([BiologicalSex.male, .female]) { option in
                    popoverOptionCell(title: option.title, selected: appState.profile.sex == option, accent: .pink) {
                        appState.profile.sex = option
                        showSexSheet = false
                    }
                }
            }
        }
    }

    private var birthSelectionRow: some View {
        selectionPopoverRow(
            icon: "calendar",
            title: localized("生日", "Birthday"),
            color: .orange,
            value: birthDisplayText,
            isPresented: $showBirthSheet,
            onOpen: { syncBirthDrafts() }
        ) {
            glassOptionPopover(accent: .orange, title: localized("选择生日", "Select Birthday"), width: 330) {
                HStack(spacing: 0) {
                    let currentYear = AppPreferences.calendar.component(.year, from: Date())
                    Picker(localized("年", "Year"), selection: $birthYearDraft) {
                        ForEach((currentYear - 100)...(currentYear - 10), id: \.self) { year in
                            Text(localized("\(year) 年", "\(year)")).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()

                    Picker(localized("月", "Month"), selection: $birthMonthDraft) {
                        ForEach(1...12, id: \.self) { month in
                            Text(localized("\(month) 月", "\(month)")).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()

                    Picker(localized("日", "Day"), selection: $birthDayDraft) {
                        ForEach(1...maxBirthDayInDraftMonth, id: \.self) { day in
                            Text(localized("\(day) 日", "\(day)")).tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
                .frame(height: 156)

                popoverDoneButton {
                    applyBirthSelection()
                    showBirthSheet = false
                }
            }
        }
    }

    private var heightSelectionRow: some View {
        selectionPopoverRow(
            icon: "ruler",
            title: localized("身高", "Height"),
            color: .blue,
            value: heightDisplayLabel,
            isPresented: $showHeightSheet,
            onOpen: { syncHeightDrafts() }
        ) {
            glassOptionPopover(accent: .blue, title: localized("选择身高", "Select Height"), width: 330) {
                if heightUnit == .centimeter {
                    Picker(localized("身高", "Height"), selection: $metricHeightDraft) {
                        ForEach(120...220, id: \.self) { value in
                            Text("\(value) cm").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 156)
                } else {
                    HStack(spacing: 0) {
                        Picker("ft", selection: $imperialHeightFeetDraft) {
                            ForEach(3...7, id: \.self) { value in
                                Text("\(value) ft").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()

                        Picker("in", selection: $imperialHeightInchesDraft) {
                            ForEach(0...11, id: \.self) { value in
                                Text("\(value) in").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                    }
                    .frame(height: 156)
                }

                popoverDoneButton {
                    applyHeightSelection()
                    showHeightSheet = false
                }
            }
        }
    }

    private var weightSelectionRow: some View {
        selectionPopoverRow(
            icon: "scalemass",
            title: localized("体重", "Weight"),
            color: .mint,
            value: weightDisplayText,
            isPresented: $showWeightSheet,
            onOpen: { syncWeightDrafts() }
        ) {
            glassOptionPopover(accent: .mint, title: localized("选择体重", "Select Weight"), width: 320) {
                if weightUnit == .kilogram {
                    Picker(localized("体重", "Weight"), selection: $metricWeightHalfDraft) {
                        ForEach(60...400, id: \.self) { value in
                            let kg = Double(value) / 2
                            Text(String(format: "%.1f kg", kg)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 156)
                } else {
                    Picker(localized("体重", "Weight"), selection: $imperialWeightLbDraft) {
                        ForEach(66...440, id: \.self) { value in
                            Text("\(value) lb").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 156)
                }

                popoverDoneButton {
                    applyWeightSelection()
                    showWeightSheet = false
                }
            }
        }
    }

    private var activitySelectionRow: some View {
        selectionPopoverRow(icon: "figure.walk", title: localized("活动水平", "Activity"), color: .green, value: appState.profile.activityLevel.title, isPresented: $showActivitySheet) {
            glassOptionPopover(accent: .green, title: localized("选择活动水平", "Select Activity")) {
                ForEach(ActivityLevel.allCases) { option in
                    popoverOptionCell(title: option.title, selected: appState.profile.activityLevel == option, accent: .green) {
                        appState.profile.activityLevel = option
                        showActivitySheet = false
                    }
                }
            }
        }
    }

    private var targetWeightSelectionRow: some View {
        selectionPopoverRow(
            icon: "target",
            title: localized("目标体重", "Target Weight"),
            color: .teal,
            value: targetWeightDisplayLabel,
            isPresented: $showTargetWeightSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .teal, title: localized("选择目标体重", "Select Target Weight"), width: 320) {
                if weightUnit == .kilogram {
                    Picker(localized("目标体重", "Target Weight"), selection: $targetMetricWeightHalfDraft) {
                        ForEach(70...360, id: \.self) { value in
                            let kg = Double(value) / 2
                            Text(String(format: "%.1f kg", kg)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 156)
                } else {
                    Picker(localized("目标体重", "Target Weight"), selection: $targetImperialWeightLbDraft) {
                        ForEach(88...440, id: \.self) { value in
                            Text("\(value) lb").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(height: 156)
                }

                popoverDoneButton {
                    applyTargetWeightSelection()
                    showTargetWeightSheet = false
                }
            }
        }
    }

    private var targetBodyFatSelectionRow: some View {
        selectionPopoverRow(
            icon: "chart.pie.fill",
            title: localized("目标体脂", "Target Body Fat"),
            color: .pink,
            value: targetBodyFatDisplayLabel,
            isPresented: $showTargetBodyFatSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .pink, title: localized("选择目标体脂", "Select Target Body Fat"), width: 320) {
                Picker(localized("目标体脂", "Target Body Fat"), selection: $targetBodyFatTenthDraft) {
                    ForEach(80...450, id: \.self) { value in
                        let percent = Double(value) / 10
                        Text(String(format: "%.1f %%", percent)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 156)

                popoverDoneButton {
                    applyTargetBodyFatSelection()
                    showTargetBodyFatSheet = false
                }
            }
        }
    }

    private var exerciseGoalSelectionRow: some View {
        selectionPopoverRow(
            icon: "figure.run.circle.fill",
            title: localized("每日运动目标", "Daily Exercise Goal"),
            color: .green,
            value: exerciseGoalDisplayLabel,
            isPresented: $showExerciseGoalSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .green, title: localized("选择每日运动目标", "Select Daily Exercise Goal"), width: 320) {
                Picker(localized("每日运动目标", "Daily Exercise Goal"), selection: $exerciseGoalDraft) {
                    ForEach(exerciseGoalRange, id: \.self) { value in
                        Text("\(value) \(energyUnit.symbol)").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 156)

                popoverDoneButton {
                    applyExerciseGoalSelection()
                    showExerciseGoalSheet = false
                }
            }
        }
    }

    private var bmrInfoRow: some View {
        HStack {
            HStack(spacing: 10) {
                rowIcon("heart.text.square.fill", .green)
                Text(localized("基础代谢 BMR", "BMR"))
                infoButton(.bmr)
            }
            Spacer()
            valueWithUnit(value: energyText(fromKcal: appState.profile.bmr, includeUnit: false, unit: energyUnit), unit: energyUnit.symbol)
        }
    }

    private var tdeeInfoRow: some View {
        HStack {
            HStack(spacing: 10) {
                rowIcon("speedometer", .green)
                Text(localized("维持消耗 TDEE", "TDEE"))
                infoButton(.tdee)
            }
            Spacer()
            valueWithUnit(value: energyText(fromKcal: appState.profile.dailyMaintenanceCalories, includeUnit: false, unit: energyUnit), unit: energyUnit.symbol)
        }
    }

    private var intakeInfoRow: some View {
        HStack {
            HStack(spacing: 10) {
                rowIcon("fork.knife.circle.fill", .red)
                Text(localized("减脂建议摄入", "Fat-Loss Intake"))
                infoButton(.intake)
            }
            Spacer()
            valueWithUnit(value: energyText(fromKcal: appState.profile.recommendedIntakeForFatLoss, includeUnit: false, unit: energyUnit), unit: energyUnit.symbol)
        }
    }

    private var languageSelectionRow: some View {
        selectionPopoverRow(icon: "globe", title: localized("语言选择", "Language Selection"), color: .blue, value: appLanguage.title, isPresented: $showLanguageSheet) {
            glassOptionPopover(accent: .blue, title: localized("选择语言", "Select Language")) {
                ForEach(AppLanguageOption.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == appLanguage, accent: .blue) {
                        appLanguageRaw = option.rawValue
                        showLanguageSheet = false
                    }
                }
            }
        }
    }

    private var energyUnitSelectionRow: some View {
        selectionPopoverRow(icon: "flame.fill", title: localized("能量单位", "Energy Unit"), color: .teal, value: energyUnit.title, isPresented: $showEnergyUnitSheet) {
            glassOptionPopover(accent: .teal, title: localized("选择能量单位", "Select Energy Unit")) {
                ForEach(EnergyUnitOption.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == energyUnit, accent: .teal) {
                        energyUnitRaw = option.rawValue
                        syncGoalDrafts()
                        showEnergyUnitSheet = false
                    }
                }
            }
        }
    }

    private var heightUnitSelectionRow: some View {
        selectionPopoverRow(icon: "ruler", title: localized("身高单位", "Height Unit"), color: .blue, value: heightUnit.title, isPresented: $showHeightUnitSheet) {
            glassOptionPopover(accent: .blue, title: localized("选择身高单位", "Select Height Unit")) {
                ForEach(HeightUnitOption.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == heightUnit, accent: .blue) {
                        heightUnitRaw = option.rawValue
                        syncHeightDrafts()
                        showHeightUnitSheet = false
                    }
                }
            }
        }
    }

    private var weightUnitSelectionRow: some View {
        selectionPopoverRow(icon: "scalemass", title: localized("体重单位", "Weight Unit"), color: .mint, value: weightUnit.title, isPresented: $showWeightUnitSheet) {
            glassOptionPopover(accent: .mint, title: localized("选择体重单位", "Select Weight Unit")) {
                ForEach(WeightUnitOption.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == weightUnit, accent: .mint) {
                        weightUnitRaw = option.rawValue
                        syncWeightDrafts()
                        syncGoalDrafts()
                        showWeightUnitSheet = false
                    }
                }
            }
        }
    }

    private var weekStartSelectionRow: some View {
        selectionPopoverRow(icon: "calendar", title: localized("日历开始", "Week Start"), color: .orange, value: weekStart.title, isPresented: $showWeekStartSheet) {
            glassOptionPopover(accent: .orange, title: localized("选择日历开始", "Select Week Start")) {
                ForEach(WeekStartOption.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == weekStart, accent: .orange) {
                        weekStartRaw = option.rawValue
                        showWeekStartSheet = false
                    }
                }
            }
        }
    }

    private var themeSelectionRow: some View {
        selectionPopoverRow(icon: "circle.lefthalf.filled", title: localized("主题模式", "Theme"), color: .indigo, value: themeMode.title, isPresented: $showThemeSheet) {
            glassOptionPopover(accent: .indigo, title: localized("选择主题模式", "Select Theme")) {
                ForEach(AppThemeMode.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == themeMode, accent: .indigo) {
                        themeModeRaw = option.rawValue
                        showThemeSheet = false
                    }
                }
            }
        }
    }

    private var avatarView: some View {
        Group {
            if let data = appState.profile.avatarJPEGData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 68, height: 68)
        .background(Color(.tertiarySystemBackground), in: Circle())
        .clipShape(Circle())
    }

    private func rowIcon(_ icon: String, _ color: Color) -> some View {
        Image(systemName: icon)
            .foregroundStyle(color)
            .frame(width: 18)
    }

    private func selectionPopoverRow<PopoverContent: View>(
        icon: String,
        title: String,
        color: Color,
        value: String?,
        isPresented: Binding<Bool>,
        onOpen: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> PopoverContent
    ) -> some View {
        Button {
            onOpen?()
            isPresented.wrappedValue = true
        } label: {
            HStack(spacing: 10) {
                rowIcon(icon, color)
                Text(title)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let value, !value.isEmpty {
                    Text(value)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            content()
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.clear)
        }
    }

    private func glassRowBackground(accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.14), .white.opacity(0.08), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 0.8)
            )
    }

    private func glassOptionPopover<Content: View>(
        accent: Color,
        title _: String,
        width: CGFloat = 292,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(width: width, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(accent.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.8)
                )
        )
    }

    private func popoverOptionCell(title: String, selected: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? accent.opacity(0.16) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(selected ? accent.opacity(0.34) : .white.opacity(0.10), lineWidth: 0.8)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func popoverDoneButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(localized("完成", "Done"))
                .font(.footnote.weight(.medium))
                .foregroundStyle(.primary.opacity(0.86))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.52))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 0.7)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func popoverChipGroup<T: Identifiable & Equatable>(
        title: String,
        options: [T],
        selected: T,
        accent: Color,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options) { option in
                        let isSelected = option == selected
                        Button {
                            onSelect(option)
                        } label: {
                            Text(label(option))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(isSelected ? accent.opacity(0.85) : .white.opacity(0.12))
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(.white.opacity(isSelected ? 0.25 : 0.14), lineWidth: 0.7)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func sheetHeight(forOptionCount count: Int) -> CGFloat {
        min(540, max(220, CGFloat(count) * 52 + 124))
    }

    private func sheetBackground(accent: Color) -> some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)
            LinearGradient(
                colors: [accent.opacity(0.20), .white.opacity(0.08), .black.opacity(0.03)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .compositingGroup()
        .ignoresSafeArea()
    }

    private func selectionCell(title: String, selected: Bool, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(selected ? 0.14 : 0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(selected ? 0.22 : 0.10),
                                        .white.opacity(selected ? 0.10 : 0.03),
                                        .clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(selected ? 0.26 : 0.14), lineWidth: 0.8)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var unitSettingsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    NavigationLink {
                        unitOptionListView(
                            title: localized("能量单位", "Energy Unit"),
                            options: EnergyUnitOption.allCases,
                            selected: energyUnit,
                            accent: .teal,
                            label: { $0.title },
                            onSelect: { value in energyUnitRaw = value.rawValue }
                        )
                    } label: {
                        unitTopicLabel(title: localized("能量单位", "Energy Unit"), value: energyUnit.title, accent: .teal)
                    }

                    NavigationLink {
                        unitOptionListView(
                            title: localized("身高", "Height"),
                            options: HeightUnitOption.allCases,
                            selected: heightUnit,
                            accent: .blue,
                            label: { $0.title },
                            onSelect: { value in
                                heightUnitRaw = value.rawValue
                                syncHeightDrafts()
                            }
                        )
                    } label: {
                        unitTopicLabel(title: localized("身高", "Height"), value: heightUnit.title, accent: .blue)
                    }

                    NavigationLink {
                        unitOptionListView(
                            title: localized("体重", "Weight"),
                            options: WeightUnitOption.allCases,
                            selected: weightUnit,
                            accent: .mint,
                            label: { $0.title },
                            onSelect: { value in
                                weightUnitRaw = value.rawValue
                                syncWeightDrafts()
                            }
                        )
                    } label: {
                        unitTopicLabel(title: localized("体重", "Weight"), value: weightUnit.title, accent: .mint)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: .teal))
            .navigationTitle(localized("单位", "Units"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        showUnitSheet = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var languageSelectionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(AppLanguageOption.allCases) { option in
                        selectionCell(
                            title: option.title,
                            selected: option == appLanguage,
                            accent: .blue,
                            action: {
                                appLanguageRaw = option.rawValue
                                showLanguageSheet = false
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: .blue))
            .navigationTitle(localized("选择语言", "Select Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        showLanguageSheet = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func unitTopicLabel(title: String, value: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.16), .white.opacity(0.06), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 0.8)
                )
        )
    }

    private func unitOptionListView<T: Identifiable & Equatable>(
        title: String,
        options: [T],
        selected: T,
        accent: Color,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void
    ) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(options) { option in
                    selectionCell(
                        title: label(option),
                        selected: option == selected,
                        accent: accent,
                        action: {
                            onSelect(option)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(sheetBackground(accent: .teal))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var heightSelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if heightUnit == .centimeter {
                    Picker(localized("身高", "Height"), selection: $metricHeightDraft) {
                        ForEach(120...220, id: \.self) { value in
                            Text("\(value) cm").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                } else {
                    HStack(spacing: 0) {
                        Picker("ft", selection: $imperialHeightFeetDraft) {
                            ForEach(3...7, id: \.self) { value in
                                Text("\(value) ft").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()

                        Picker("in", selection: $imperialHeightInchesDraft) {
                            ForEach(0...11, id: \.self) { value in
                                Text("\(value) in").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: .blue))
            .navigationTitle(localized("选择身高", "Select Height"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        applyHeightSelection()
                        showHeightSheet = false
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var weightSelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if weightUnit == .kilogram {
                    Picker(localized("体重", "Weight"), selection: $metricWeightHalfDraft) {
                        ForEach(60...400, id: \.self) { value in
                            let kg = Double(value) / 2
                            Text(String(format: "%.1f kg", kg)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                } else {
                    Picker(localized("体重", "Weight"), selection: $imperialWeightLbDraft) {
                        ForEach(66...440, id: \.self) { value in
                            Text("\(value) lb").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: .mint))
            .navigationTitle(localized("选择体重", "Select Weight"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        applyWeightSelection()
                        showWeightSheet = false
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var birthSelectionSheet: some View {
        NavigationStack {
            HStack(spacing: 0) {
                let currentYear = AppPreferences.calendar.component(.year, from: Date())
                Picker(localized("年", "Year"), selection: $birthYearDraft) {
                    ForEach((currentYear - 100)...(currentYear - 10), id: \.self) { year in
                        Text(localized("\(year) 年", "\(year)")).tag(year)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Picker(localized("月", "Month"), selection: $birthMonthDraft) {
                    ForEach(1...12, id: \.self) { month in
                        Text(localized("\(month) 月", "\(month)")).tag(month)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()

                Picker(localized("日", "Day"), selection: $birthDayDraft) {
                    ForEach(1...maxBirthDayInDraftMonth, id: \.self) { day in
                        Text(localized("\(day) 日", "\(day)")).tag(day)
                    }
                }
                .pickerStyle(.wheel)
                .labelsHidden()
            }
            .onChange(of: birthYearDraft) { _, _ in
                clampBirthDay()
            }
            .onChange(of: birthMonthDraft) { _, _ in
                clampBirthDay()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: .orange))
            .navigationTitle(localized("选择生日", "Select Birthday"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        applyBirthSelection()
                        showBirthSheet = false
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func infoButton(_ topic: SettingsInfoTopic) -> some View {
        Button {
            activeInfo = topic
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: infoPopoverBinding(for: topic), attachmentAnchor: .rect(.bounds), arrowEdge: infoPopoverArrowEdge(for: topic)) {
            glassInfoPopover(topic: topic)
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.clear)
        }
    }

    private func infoPopoverBinding(for topic: SettingsInfoTopic) -> Binding<Bool> {
        Binding(
            get: { activeInfo == topic },
            set: { isShowing in
                activeInfo = isShowing ? topic : nil
            }
        )
    }

    private func infoPopoverArrowEdge(for topic: SettingsInfoTopic) -> Edge {
        switch topic {
        case .bmr:
            return .top
        case .tdee, .intake:
            return .bottom
        }
    }

    private func iconTextFieldRow(icon: String, title: String, text: Binding<String>, unit: String, keyboard: UIKeyboardType, color: Color) -> some View {
        HStack {
            HStack(spacing: 10) {
                rowIcon(icon, color)
                Text(title)
            }
            Spacer()
            HStack(spacing: 6) {
                TextField(title, text: text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 84)
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 130, alignment: .trailing)
        }
    }

    private func valueWithUnit(value: String, unit: String) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.subheadline)
                .monospacedDigit()
                .frame(width: 84, alignment: .trailing)
            Text(unit)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 130, alignment: .trailing)
    }

    private func selectionSheet<T: Identifiable>(
        title: String,
        options: [T],
        selectedTitle: String,
        accent: Color,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void,
        onClose: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(options) { option in
                        selectionCell(
                            title: label(option),
                            selected: label(option) == selectedTitle,
                            accent: accent,
                            action: {
                                onSelect(option)
                                onClose()
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(sheetBackground(accent: accent))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        onClose()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func glassInfoPopover(topic: SettingsInfoTopic) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                Text(paragraph)
                    .font(.caption)
                    .lineSpacing(1.5)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if index < topic.paragraphs.count - 1 {
                    Divider()
                        .overlay(.white.opacity(0.10))
                }
            }
        }
        .padding(12)
        .frame(width: 286, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.24), lineWidth: 0.8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.white.opacity(0.02))
                )
        )
    }

    private func ensureBirthDateSeeded() {
        if birthDateTimestamp > 0 { return }
        let date = birthDateFromAge(appState.profile.age)
        birthDateTimestamp = date.timeIntervalSince1970
    }

    private func syncHeightDrafts() {
        metricHeightDraft = min(max(Int(appState.profile.heightCm.rounded()), 120), 220)
        let converted = centimetersToFeetInches(appState.profile.heightCm)
        imperialHeightFeetDraft = converted.feet
        imperialHeightInchesDraft = converted.inches
    }

    private func applyHeightSelection() {
        switch heightUnit {
        case .centimeter:
            appState.profile.heightCm = Double(metricHeightDraft)
        case .foot:
            appState.profile.heightCm = (Double(imperialHeightFeetDraft * 12 + imperialHeightInchesDraft)) * 2.54
        }
    }

    private func syncWeightDrafts() {
        metricWeightHalfDraft = min(max(Int((appState.profile.weightKg * 2).rounded()), 60), 400)
        imperialWeightLbDraft = min(max(Int((appState.profile.weightKg * 2.20462).rounded()), 66), 440)
    }

    private func applyWeightSelection() {
        switch weightUnit {
        case .kilogram:
            appState.profile.weightKg = Double(metricWeightHalfDraft) / 2
        case .pound:
            appState.profile.weightKg = Double(imperialWeightLbDraft) / 2.20462
        }
    }

    private func syncGoalDrafts() {
        targetMetricWeightHalfDraft = min(max(Int((appState.profile.targetWeightKg * 2).rounded()), 70), 360)
        targetImperialWeightLbDraft = min(max(Int(weightDisplayValue(fromKg: appState.profile.targetWeightKg, unit: .pound).rounded()), 88), 440)
        targetBodyFatTenthDraft = min(max(Int((appState.profile.targetBodyFat * 10).rounded()), 80), 450)

        let displayValue = energyConvertedValue(fromKcal: appState.profile.dailyExerciseGoal, unit: energyUnit)
        let roundedDisplay = Int(displayValue.rounded())
        switch energyUnit {
        case .kcal:
            exerciseGoalDraft = min(max(roundedDisplay, 50), 1500)
        case .kJ:
            exerciseGoalDraft = min(max(roundedDisplay, 200), 6300)
        }
    }

    private func applyTargetWeightSelection() {
        switch weightUnit {
        case .kilogram:
            appState.profile.targetWeightKg = Double(targetMetricWeightHalfDraft) / 2
        case .pound:
            appState.profile.targetWeightKg = weightFromDisplayValue(Double(targetImperialWeightLbDraft), unit: .pound)
        }
    }

    private func applyTargetBodyFatSelection() {
        appState.profile.targetBodyFat = Double(targetBodyFatTenthDraft) / 10
    }

    private func applyExerciseGoalSelection() {
        appState.profile.dailyExerciseGoal = energyFromDisplayValue(Double(exerciseGoalDraft), unit: energyUnit)
    }

    private func syncBirthDrafts() {
        let components = AppPreferences.calendar.dateComponents([.year, .month, .day], from: resolvedBirthDate)
        birthYearDraft = components.year ?? 1998
        birthMonthDraft = components.month ?? 1
        birthDayDraft = components.day ?? 1
        clampBirthDay()
    }

    private func applyBirthSelection() {
        var components = DateComponents()
        components.year = birthYearDraft
        components.month = birthMonthDraft
        components.day = birthDayDraft

        if let date = AppPreferences.calendar.date(from: components) {
            birthDateTimestamp = date.timeIntervalSince1970
            let age = AppPreferences.calendar.dateComponents([.year], from: date, to: Date()).year ?? appState.profile.age
            appState.profile.age = min(max(age, 10), 100)
        }
    }

    private var maxBirthDayInDraftMonth: Int {
        var components = DateComponents()
        components.year = birthYearDraft
        components.month = birthMonthDraft
        components.day = 1
        guard
            let date = AppPreferences.calendar.date(from: components),
            let range = AppPreferences.calendar.range(of: .day, in: .month, for: date)
        else {
            return 31
        }
        return range.count
    }

    private func clampBirthDay() {
        birthDayDraft = min(max(1, birthDayDraft), maxBirthDayInDraftMonth)
    }

    private func birthDateFromAge(_ age: Int) -> Date {
        let calendar = AppPreferences.calendar
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.year = (components.year ?? 2000) - age
        components.day = 1
        return calendar.date(from: components) ?? now
    }

    private func centimetersToFeetInches(_ cm: Double) -> (feet: Int, inches: Int) {
        let totalInches = max(cm / 2.54, 0)
        var feet = Int(totalInches / 12)
        var inches = Int((totalInches - Double(feet * 12)).rounded())
        if inches == 12 {
            feet += 1
            inches = 0
        }
        return (max(3, min(feet, 7)), max(0, min(inches, 11)))
    }

    private var targetWeightBinding: Binding<String> {
        Binding(
            get: {
                switch weightUnit {
                case .kilogram:
                    return String(format: "%.1f", appState.profile.targetWeightKg)
                case .pound:
                    return String(format: "%.1f", weightDisplayValue(fromKg: appState.profile.targetWeightKg, unit: .pound))
                }
            },
            set: { input in
                let filtered = input.filter { "0123456789.".contains($0) }
                guard let value = Double(filtered), value > 0 else { return }
                switch weightUnit {
                case .kilogram:
                    appState.profile.targetWeightKg = value
                case .pound:
                    appState.profile.targetWeightKg = weightFromDisplayValue(value, unit: .pound)
                }
            }
        )
    }

    private var exerciseGoalBinding: Binding<String> {
        Binding(
            get: {
                energyText(fromKcal: appState.profile.dailyExerciseGoal, includeUnit: false, unit: energyUnit)
            },
            set: { input in
                let filtered = input.filter { "0123456789.".contains($0) }
                guard let value = Double(filtered), value > 0 else { return }
                appState.profile.dailyExerciseGoal = energyFromDisplayValue(value, unit: energyUnit)
            }
        )
    }

    private func binding<T>(_ keyPath: WritableKeyPath<UserProfile, T>) -> Binding<T> {
        Binding(
            get: { appState.profile[keyPath: keyPath] },
            set: { appState.profile[keyPath: keyPath] = $0 }
        )
    }

    private func bindingDouble(_ keyPath: WritableKeyPath<UserProfile, Double>, format: String) -> Binding<String> {
        Binding(
            get: { String(format: format, appState.profile[keyPath: keyPath]) },
            set: { input in
                if let value = Double(input.filter { "0123456789.".contains($0) }) {
                    appState.profile[keyPath: keyPath] = value
                }
            }
        )
    }
}

private enum SettingsInfoTopic: String, Identifiable {
    case bmr
    case tdee
    case intake

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bmr:
            return localized("基础代谢 BMR", "BMR")
        case .tdee:
            return localized("维持消耗 TDEE", "TDEE")
        case .intake:
            return localized("减脂建议摄入", "Fat-Loss Intake")
        }
    }

    var sheetHeight: CGFloat {
        switch self {
        case .bmr:
            return 220
        case .tdee:
            return 194
        case .intake:
            return 208
        }
    }

    var paragraphs: [String] {
        switch self {
        case .bmr:
            return [
                localized("Mifflin-St Jeor 公式。", "Mifflin-St Jeor formula."),
                localized("男性: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 + 5。", "Male: 10×weight(kg) + 6.25×height(cm) - 5×age + 5."),
                localized("女性: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 - 161。", "Female: 10×weight(kg) + 6.25×height(cm) - 5×age - 161.")
            ]
        case .tdee:
            return [
                localized("TDEE = BMR × 活动系数。", "TDEE = BMR × activity multiplier."),
                localized("活动系数: 久坐 1.2 / 轻度活动 1.375 / 中度活动 1.55 / 高强度活动 1.725。", "Activity multiplier: Sedentary 1.2 / Light 1.375 / Moderate 1.55 / Very active 1.725.")
            ]
        case .intake:
            return [
                localized("减脂建议摄入 = max(1200, TDEE - 450)。", "Recommended intake = max(1200, TDEE - 450)."),
                localized("当日净差 = 摄入 - (TDEE + 运动消耗)。", "Daily net = intake - (TDEE + exercise)."),
                localized("负值为赤字，正值为超量。", "Negative is deficit, positive is surplus.")
            ]
        }
    }
}
