import AuthenticationServices
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @AppStorage("keepfit.haptic") private var hapticEnabled = true
    @AppStorage("keepfit.reminder.food") private var foodReminderEnabled = true
    @AppStorage("keepfit.reminder.exercise") private var exerciseReminderEnabled = true
    @AppStorage("keepfit.reminder.summary") private var dailySummaryEnabled = true
    @AppStorage("keepfit.reminder.food.minuteOfDay") private var foodReminderMinuteOfDay = 12 * 60
    @AppStorage("keepfit.reminder.exercise.minuteOfDay") private var exerciseReminderMinuteOfDay = 19 * 60
    @AppStorage("keepfit.reminder.summary.minuteOfDay") private var summaryReminderMinuteOfDay = 21 * 60 + 30
    @AppStorage("keepfit.sync.healthKit") private var healthSyncEnabled = false
    @AppStorage("keepfit.sync.iCloud") private var iCloudSyncEnabled = false
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
    @State private var showFoodReminderTimeSheet = false
    @State private var showExerciseReminderTimeSheet = false
    @State private var showSummaryReminderTimeSheet = false

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
    @State private var foodReminderTimeDraft = Date()
    @State private var exerciseReminderTimeDraft = Date()
    @State private var summaryReminderTimeDraft = Date()

    @State private var activeInfo: SettingsInfoTopic?
    @State private var infoPopoverSourceRect: CGRect = .zero
    @State private var selectionPopoverAnchor = UnitPoint(x: 0.9, y: 0.5)
    @State private var selectionPopoverArrowEdge: Edge = .bottom
    @State private var handlingHealthToggle = false
    @State private var handlingReminderToggle = false
    @State private var showHealthSyncAlert = false
    @State private var healthSyncAlertMessage = ""
    @State private var showAboutSheet = false
    @State private var showReminderAlert = false
    @State private var reminderAlertMessage = ""
    @State private var showFeedbackAlert = false
    @State private var showAppleAccountSheet = false

    private let feedbackEmail = "longyu.huihui@gmail.com"

    private var settingsCompactLayout: Bool {
        UIScreen.main.bounds.width <= 390 || dynamicTypeSize >= .xLarge
    }

    private var settingsTitleFontSize: CGFloat {
        settingsCompactLayout ? 15 : 16
    }

    private var settingsValueFontSize: CGFloat {
        settingsCompactLayout ? 14 : 15
    }

    private var settingsTitleFont: Font {
        .system(size: settingsTitleFontSize)
    }

    private var settingsValueFont: Font {
        .system(size: settingsValueFontSize)
    }

    private var settingsTitleUIFont: UIFont {
        .systemFont(ofSize: settingsTitleFontSize)
    }

    private var settingsValueUIFont: UIFont {
        .systemFont(ofSize: settingsValueFontSize)
    }

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

    private var cloudSyncTitle: String {
        appState.isSignedInWithAppleAccount
            ? localized("账号同步", "Account Sync")
            : localized("iCloud 同步", "iCloud Sync")
    }

    private var cloudSyncSummary: String {
        if appState.isSignedInWithAppleAccount {
            if !appState.iCloudAccountAvailable {
                return localized("需先在当前设备登录 iCloud。", "Sign in to iCloud on this device first.")
            }
            return iCloudSyncEnabled
                ? localized("通过当前 Apple 账号在设备间同步。", "Sync across devices with the current Apple account.")
                : localized("已登录 Apple 账号，可按需开启跨设备同步。", "Signed in with Apple. Enable cross-device sync when needed.")
        }

        if !appState.iCloudAccountAvailable {
            return localized("需先在当前设备登录 iCloud。", "Sign in to iCloud on this device first.")
        }
        return localized("通过 iCloud 在设备间同步数据。", "Sync data across devices with iCloud.")
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

    private var settingsSeparatorTint: Color {
        colorScheme == .dark ? .white.opacity(0.18) : .black.opacity(0.12)
    }

    private var foodReminderTimeText: String {
        Formatters.hourMinute.string(from: date(fromMinuteOfDay: foodReminderMinuteOfDay))
    }

    private var exerciseReminderTimeText: String {
        Formatters.hourMinute.string(from: date(fromMinuteOfDay: exerciseReminderMinuteOfDay))
    }

    private var summaryReminderTimeText: String {
        Formatters.hourMinute.string(from: date(fromMinuteOfDay: summaryReminderMinuteOfDay))
    }

    var body: some View {
        NavigationStack {
            settingsPresentedView
        }
        .onAppear {
            applyThemeModeImmediately(themeMode)
        }
        .onChange(of: themeModeRaw) { _, newValue in
            let mode = AppThemeMode(rawValue: newValue) ?? .system
            applyThemeModeImmediately(mode)
        }
    }

    private var settingsFormView: some View {
        Form {
            basicInfoSection
            goalsAdviceSection
            generalSettingsSection
            unitsSection
            dataSection
            remindersSection
            otherSection
            rateKeepFitSection
        }
        .listStyle(.insetGrouped)
        .listRowSeparator(.hidden, edges: .all)
        .listRowSeparatorTint(.clear)
        .listSectionSeparator(.hidden, edges: .all)
        .listSectionSeparatorTint(.clear)
        .navigationTitle(localized("设置", "Settings"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(localized("完成", "Done")) {
                    dismiss()
                }
            }
        }
    }

    private var settingsInteractiveView: some View {
        settingsFormView
            .onAppear {
                ensureBirthDateSeeded()
                syncHeightDrafts()
                syncWeightDrafts()
                syncBirthDrafts()
                syncGoalDrafts()
                refreshICloudSyncState()
                Task {
                    await syncReminderSchedulesOnAppear()
                }
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
            .onChange(of: iCloudSyncEnabled) { _, isEnabled in
                triggerHapticIfNeeded()
                appState.setICloudSyncEnabled(isEnabled)
                let effective = appState.isICloudSyncEnabled
                if iCloudSyncEnabled != effective {
                    iCloudSyncEnabled = effective
                }
            }
            .onChange(of: appState.iCloudAccountAvailable) { _, _ in
                let effective = appState.isICloudSyncEnabled
                if iCloudSyncEnabled != effective {
                    iCloudSyncEnabled = effective
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshICloudSyncState()
            }
            .onChange(of: healthSyncEnabled) { _, isEnabled in
                Task {
                    triggerHapticIfNeeded()
                    await handleHealthToggleChanged(isEnabled)
                }
            }
            .onChange(of: foodReminderEnabled) { _, isEnabled in
                Task {
                    triggerHapticIfNeeded()
                    await handleReminderToggleChanged(.food, enabled: isEnabled)
                }
            }
            .onChange(of: exerciseReminderEnabled) { _, isEnabled in
                Task {
                    triggerHapticIfNeeded()
                    await handleReminderToggleChanged(.exercise, enabled: isEnabled)
                }
            }
            .onChange(of: dailySummaryEnabled) { _, isEnabled in
                Task {
                    triggerHapticIfNeeded()
                    await handleReminderToggleChanged(.summary, enabled: isEnabled)
                }
            }
            .onChange(of: hapticEnabled) { _, isEnabled in
                if isEnabled {
                    triggerHapticIfNeeded()
                }
            }
    }

    private var settingsPresentedView: some View {
        settingsInteractiveView
            .overlay {
                settingsInfoOverlay
            }
            .alert(localized("健康同步", "Health Sync"), isPresented: $showHealthSyncAlert) {
                Button(localized("知道了", "OK"), role: .cancel) {}
            } message: {
                Text(healthSyncAlertMessage)
            }
            .alert(localized("提醒", "Reminders"), isPresented: $showReminderAlert) {
                Button(localized("知道了", "OK"), role: .cancel) {}
            } message: {
                Text(reminderAlertMessage)
            }
            .alert(localized("意见反馈", "Feedback"), isPresented: $showFeedbackAlert) {
                Button(localized("发送邮件", "Send Mail")) {
                    openFeedbackEmail()
                }
                Button(localized("取消", "Cancel"), role: .cancel) {}
            } message: {
                Text(feedbackEmail)
            }
            .sheet(isPresented: $showAboutSheet) {
                aboutSheet
            }
            .sheet(isPresented: $showAppleAccountSheet) {
                AppleAccountSheet(requireChoice: false)
            }
    }

    private var basicInfoSection: some View {
        Section {
            avatarSelectionRow
                .keepFitSettingsSeparatorAligned()
            usernameRow
                .keepFitSettingsSeparatorAligned()
            sexSelectionRow
                .keepFitSettingsSeparatorAligned()
            birthSelectionRow
                .keepFitSettingsSeparatorAligned()
            heightSelectionRow
                .keepFitSettingsSeparatorAligned()
            weightSelectionRow
                .keepFitSettingsSeparatorAligned()
            activitySelectionRow
                .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("信息", "Info"))
        }
    }

    private var goalsAdviceSection: some View {
        Section {
            targetWeightSelectionRow
                .keepFitSettingsSeparatorAligned()
            targetBodyFatSelectionRow
                .keepFitSettingsSeparatorAligned()
            exerciseGoalSelectionRow
                .keepFitSettingsSeparatorAligned()
            bmrInfoRow
                .keepFitSettingsSeparatorAligned()
            tdeeInfoRow
                .keepFitSettingsSeparatorAligned()
            intakeInfoRow
                .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("目标", "Goals"))
        }
    }

    private var generalSettingsSection: some View {
        Section {
            languageSelectionRow
                .keepFitSettingsSeparatorAligned()
            themeSelectionRow
                .keepFitSettingsSeparatorAligned()
            weekStartSelectionRow
                .keepFitSettingsSeparatorAligned()

            Toggle(isOn: $hapticEnabled) {
                HStack(spacing: 10) {
                    rowIcon("hand.tap", .blue)
                    Text(localized("触感反馈", "Haptics"))
                }
            }
            .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("通用", "General"))
        }
    }

    private var unitsSection: some View {
        Section {
            energyUnitSelectionRow
                .keepFitSettingsSeparatorAligned()
            heightUnitSelectionRow
                .keepFitSettingsSeparatorAligned()
            weightUnitSelectionRow
                .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("单位", "Units"))
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                triggerHapticIfNeeded()
                showAppleAccountSheet = true
            } label: {
                HStack(spacing: settingsCompactLayout ? 8 : 10) {
                    appleAccountRowIcon
                    Text(localized("Apple 账号", "Apple Account"))
                        .font(settingsTitleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .allowsTightening(true)
                        .layoutPriority(1)
                    Spacer(minLength: 8)
                    Text(appState.accountDisplayTitle)
                        .font(settingsValueFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .keepFitSettingsSeparatorAligned()

            Toggle(isOn: $healthSyncEnabled) {
                HStack(spacing: 10) {
                    rowIcon("heart.text.square.fill", .green)
                    Text(localized("Apple 健康", "Apple Health"))
                        .font(settingsTitleFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .keepFitSettingsSeparatorAligned()

            Toggle(isOn: $iCloudSyncEnabled) {
                HStack(spacing: 10) {
                    rowIcon("icloud.fill", .blue)
                    Text(cloudSyncTitle)
                        .font(settingsTitleFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                }
            }
            .disabled(!appState.iCloudAccountAvailable)
            .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("数据", "Data"))
        } footer: {
            if appState.isSignedInWithAppleAccount && !appState.iCloudAccountAvailable {
                Text(localized("已登录 Apple 账号，但当前设备未登录 iCloud，暂时无法同步到其他设备。", "Signed in with Apple, but iCloud is not signed in on this device. Sync to your other devices is temporarily unavailable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.top, 2)
            } else if !appState.iCloudAccountAvailable {
                Text(localized("当前设备未登录 iCloud，iCloud 同步暂不可用。", "No iCloud account signed in. iCloud sync is unavailable."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                    .padding(.top, 2)
            }
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle(isOn: $foodReminderEnabled) {
                HStack(spacing: 10) {
                    rowIcon("fork.knife", .orange)
                    Text(localized("饮食提醒", "Diet Reminder"))
                }
            }
            .keepFitSettingsSeparatorAligned()
            reminderTimeSelectionRow(
                title: localized("饮食提醒时间", "Diet Reminder Time"),
                color: .orange,
                value: foodReminderTimeText,
                isPresented: $showFoodReminderTimeSheet,
                draft: $foodReminderTimeDraft,
                minuteOfDay: $foodReminderMinuteOfDay,
                reminder: .food
            )
            .keepFitSettingsSeparatorAligned()

            Toggle(isOn: $exerciseReminderEnabled) {
                HStack(spacing: 10) {
                    rowIcon("figure.run", .green)
                    Text(localized("运动提醒", "Exercise Reminder"))
                }
            }
            .keepFitSettingsSeparatorAligned()
            reminderTimeSelectionRow(
                title: localized("运动提醒时间", "Exercise Reminder Time"),
                color: .green,
                value: exerciseReminderTimeText,
                isPresented: $showExerciseReminderTimeSheet,
                draft: $exerciseReminderTimeDraft,
                minuteOfDay: $exerciseReminderMinuteOfDay,
                reminder: .exercise
            )
            .keepFitSettingsSeparatorAligned()

            Toggle(isOn: $dailySummaryEnabled) {
                HStack(spacing: 10) {
                    rowIcon("doc.text", .indigo)
                    Text(localized("每日总结", "Daily Summary"))
                }
            }
            .keepFitSettingsSeparatorAligned()
            reminderTimeSelectionRow(
                title: localized("每日总结时间", "Daily Summary Time"),
                color: .indigo,
                value: summaryReminderTimeText,
                isPresented: $showSummaryReminderTimeSheet,
                draft: $summaryReminderTimeDraft,
                minuteOfDay: $summaryReminderMinuteOfDay,
                reminder: .summary
            )
            .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("提醒", "Reminders"))
        }
    }

    private var otherSection: some View {
        Section {
            ShareLink(item: shareText) {
                HStack(spacing: 10) {
                    rowIcon("square.and.arrow.up", .blue)
                    Text(localized("分享 APP", "Share App"))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                TapGesture().onEnded {
                    triggerHapticIfNeeded()
                }
            )
            .keepFitSettingsSeparatorAligned()

            Button {
                triggerHapticIfNeeded()
                showFeedbackAlert = true
            } label: {
                HStack(spacing: 10) {
                    rowIcon("envelope", .orange)
                    Text(localized("意见反馈", "Feedback"))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .keepFitSettingsSeparatorAligned()

            Button {
                triggerHapticIfNeeded()
                showAboutSheet = true
            } label: {
                HStack(spacing: 10) {
                    rowIcon("info.circle", .teal)
                    Text(localized("关于", "About"))
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            .keepFitSettingsSeparatorAligned()
        } header: {
            Text(localized("其他", "Other"))
        }
    }

    private var rateKeepFitSection: some View {
        Section {
            Button {
                triggerHapticIfNeeded(style: .medium)
                requestReview()
            } label: {
                HStack(spacing: settingsCompactLayout ? 10 : 12) {
                    Image(systemName: "star.bubble.fill")
                        .font(.system(size: settingsCompactLayout ? 18 : 20))
                        .foregroundStyle(.yellow)
                    Text(localized("为 KeepFit 评分", "Rate KeepFit"))
                        .font(settingsTitleFont)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                        .layoutPriority(1)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .keepFitSettingsSeparatorAligned()
        }
    }

    private var avatarSelectionRow: some View {
        PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
            HStack(spacing: 10) {
                rowIcon("person.crop.circle", .purple)
                Text(localized("头像", "Avatar"))
                    .foregroundStyle(.primary)
                Spacer()
                avatarView(size: 36)
            }
        }
        .buttonStyle(.plain)
    }

    private var usernameRow: some View {
        HStack(spacing: 10) {
            rowIcon("person.text.rectangle", .blue)
            Text(localized("用户名", "Username"))
                .font(settingsTitleFont)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            TextField(localized("请输入用户名", "Enter username"), text: binding(\.name))
                .font(settingsValueFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private func reminderTimeSelectionRow(
        title: String,
        color: Color,
        value: String,
        isPresented: Binding<Bool>,
        draft: Binding<Date>,
        minuteOfDay: Binding<Int>,
        reminder: ReminderKind
    ) -> some View {
        selectionPopoverRow(
            icon: "clock",
            title: title,
            color: color,
            value: value,
            isPresented: isPresented,
            onOpen: {
                draft.wrappedValue = date(fromMinuteOfDay: minuteOfDay.wrappedValue)
            }
        ) {
            let hourOptions = (0...23).map { String(format: "%02d", $0) }
            let minuteOptions = (0...59).map { String(format: "%02d", $0) }
            let hourColumnWidth = adaptiveWheelColumnWidth(options: hourOptions, minWidth: 62, maxWidth: 82, sideInset: 24)
            let minuteColumnWidth = adaptiveWheelColumnWidth(options: minuteOptions, minWidth: 62, maxWidth: 82, sideInset: 24)
            let popoverWidth = adaptiveWheelPopoverWidth(
                columnWidths: [hourColumnWidth, minuteColumnWidth],
                horizontalPadding: 5,
                minWidth: 176,
                maxWidth: 236
            )
            let hourBinding = reminderHourBinding(for: draft)
            let minuteBinding = reminderMinuteBinding(for: draft)
            glassOptionPopover(accent: color, title: title, width: popoverWidth, horizontalPadding: 5) {
                HStack(spacing: 0) {
                    Picker(localized("时", "Hour"), selection: hourBinding) {
                        ForEach(0...23, id: \.self) { hour in
                            wheelOptionText(String(format: "%02d", hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: hourColumnWidth)

                    Picker(localized("分", "Minute"), selection: minuteBinding) {
                        ForEach(0...59, id: \.self) { minute in
                            wheelOptionText(String(format: "%02d", minute)).tag(minute)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: minuteColumnWidth)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 156)

                popoverDoneButton {
                    minuteOfDay.wrappedValue = minuteOfDayValue(from: draft.wrappedValue)
                    isPresented.wrappedValue = false
                    Task {
                        await rescheduleReminderIfEnabled(reminder)
                    }
                }
            }
        }
    }

    private var sexSelectionRow: some View {
        selectionPopoverRow(icon: "person.fill", title: localized("性别", "Sex"), color: .pink, value: appState.profile.sex.title, isPresented: $showSexSheet) {
            glassOptionPopover(
                accent: .pink,
                title: localized("选择性别", "Select Sex"),
                width: estimatedPopoverWidth(from: [BiologicalSex.male.title, BiologicalSex.female.title], minWidth: 184, maxWidth: 220)
            ) {
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
        let currentYear = AppPreferences.calendar.component(.year, from: Date())
        let yearOptions = ((currentYear - 100)...(currentYear - 10)).map { localized("\($0) 年", "\($0)") }
        let monthOptions = (1...12).map { localized("\($0) 月", "\($0)") }
        let dayOptions = (1...31).map { localized("\($0) 日", "\($0)") }
        let yearColumnWidth = adaptiveWheelColumnWidth(options: yearOptions, minWidth: 84, maxWidth: 122, sideInset: 34)
        let monthColumnWidth = adaptiveWheelColumnWidth(options: monthOptions, minWidth: 68, maxWidth: 94, sideInset: 30)
        let dayColumnWidth = adaptiveWheelColumnWidth(options: dayOptions, minWidth: 68, maxWidth: 94, sideInset: 30)
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: [yearColumnWidth, monthColumnWidth, dayColumnWidth],
            horizontalPadding: 5,
            minWidth: 226,
            maxWidth: 332
        )
        return selectionPopoverRow(
            icon: "calendar",
            title: localized("生日", "Birthday"),
            color: .orange,
            value: birthDisplayText,
            isPresented: $showBirthSheet,
            onOpen: { syncBirthDrafts() }
        ) {
            glassOptionPopover(accent: .orange, title: localized("选择生日", "Select Birthday"), width: popoverWidth, horizontalPadding: 5) {
                HStack(spacing: 0) {
                    Picker(localized("年", "Year"), selection: $birthYearDraft) {
                        ForEach((currentYear - 100)...(currentYear - 10), id: \.self) { year in
                            wheelOptionText(localized("\(year) 年", "\(year)")).tag(year)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: yearColumnWidth)

                    Picker(localized("月", "Month"), selection: $birthMonthDraft) {
                        ForEach(1...12, id: \.self) { month in
                            wheelOptionText(localized("\(month) 月", "\(month)")).tag(month)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: monthColumnWidth)

                    Picker(localized("日", "Day"), selection: $birthDayDraft) {
                        ForEach(1...maxBirthDayInDraftMonth, id: \.self) { day in
                            wheelOptionText(localized("\(day) 日", "\(day)")).tag(day)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: dayColumnWidth)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .frame(height: 156)

                popoverDoneButton {
                    applyBirthSelection()
                    showBirthSheet = false
                }
            }
        }
    }

    private var heightSelectionRow: some View {
        let metricOptions = (120...220).map { "\($0) cm" }
        let feetOptions = (3...7).map { "\($0) ft" }
        let inchOptions = (0...11).map { "\($0) in" }
        let metricColumnWidth = adaptiveWheelColumnWidth(options: metricOptions, minWidth: 92, maxWidth: 136, sideInset: 32)
        let feetColumnWidth = adaptiveWheelColumnWidth(options: feetOptions, minWidth: 70, maxWidth: 102, sideInset: 30)
        let inchColumnWidth = adaptiveWheelColumnWidth(options: inchOptions, minWidth: 70, maxWidth: 102, sideInset: 30)
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: heightUnit == .centimeter ? [metricColumnWidth] : [feetColumnWidth, inchColumnWidth],
            horizontalPadding: 5,
            minWidth: heightUnit == .centimeter ? 178 : 204,
            maxWidth: heightUnit == .centimeter ? 246 : 292
        )
        return selectionPopoverRow(
            icon: "ruler",
            title: localized("身高", "Height"),
            color: .blue,
            value: heightDisplayLabel,
            isPresented: $showHeightSheet,
            onOpen: { syncHeightDrafts() }
        ) {
            glassOptionPopover(
                accent: .blue,
                title: localized("选择身高", "Select Height"),
                width: popoverWidth,
                horizontalPadding: 5
            ) {
                if heightUnit == .centimeter {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker(localized("身高", "Height"), selection: $metricHeightDraft) {
                            ForEach(120...220, id: \.self) { value in
                                wheelOptionText("\(value) cm").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: metricColumnWidth)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 156)
                } else {
                    HStack(spacing: 0) {
                        Picker("ft", selection: $imperialHeightFeetDraft) {
                            ForEach(3...7, id: \.self) { value in
                                wheelOptionText("\(value) ft").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: feetColumnWidth)

                        Picker("in", selection: $imperialHeightInchesDraft) {
                            ForEach(0...11, id: \.self) { value in
                                wheelOptionText("\(value) in").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: inchColumnWidth)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
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
        let kilogramOptions = (60...400).map { String(format: "%.1f kg", Double($0) / 2) }
        let poundOptions = (66...440).map { "\($0) lb" }
        let columnWidth = adaptiveWheelColumnWidth(
            options: weightUnit == .kilogram ? kilogramOptions : poundOptions,
            minWidth: 98,
            maxWidth: 152,
            sideInset: 34
        )
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: [columnWidth],
            horizontalPadding: 5,
            minWidth: 178,
            maxWidth: 246
        )
        return selectionPopoverRow(
            icon: "scalemass",
            title: localized("体重", "Weight"),
            color: .mint,
            value: weightDisplayText,
            isPresented: $showWeightSheet,
            onOpen: { syncWeightDrafts() }
        ) {
            glassOptionPopover(accent: .mint, title: localized("选择体重", "Select Weight"), width: popoverWidth, horizontalPadding: 5) {
                if weightUnit == .kilogram {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker(localized("体重", "Weight"), selection: $metricWeightHalfDraft) {
                            ForEach(60...400, id: \.self) { value in
                                let kg = Double(value) / 2
                                wheelOptionText(String(format: "%.1f kg", kg)).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: columnWidth)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 156)
                } else {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker(localized("体重", "Weight"), selection: $imperialWeightLbDraft) {
                            ForEach(66...440, id: \.self) { value in
                                wheelOptionText("\(value) lb").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: columnWidth)
                        Spacer(minLength: 0)
                    }
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
            glassOptionPopover(
                accent: .green,
                title: localized("选择活动水平", "Select Activity"),
                width: estimatedPopoverWidth(from: ActivityLevel.allCases.map(\.title), minWidth: 190, maxWidth: 248)
            ) {
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
        let kilogramOptions = (70...360).map { String(format: "%.1f kg", Double($0) / 2) }
        let poundOptions = (88...440).map { "\($0) lb" }
        let columnWidth = adaptiveWheelColumnWidth(
            options: weightUnit == .kilogram ? kilogramOptions : poundOptions,
            minWidth: 98,
            maxWidth: 152,
            sideInset: 34
        )
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: [columnWidth],
            horizontalPadding: 5,
            minWidth: 178,
            maxWidth: 246
        )
        return selectionPopoverRow(
            icon: "target",
            title: localized("目标体重", "Target Weight"),
            color: .teal,
            value: targetWeightDisplayLabel,
            isPresented: $showTargetWeightSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .teal, title: localized("选择目标体重", "Select Target Weight"), width: popoverWidth, horizontalPadding: 5) {
                if weightUnit == .kilogram {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker(localized("目标体重", "Target Weight"), selection: $targetMetricWeightHalfDraft) {
                            ForEach(70...360, id: \.self) { value in
                                let kg = Double(value) / 2
                                wheelOptionText(String(format: "%.1f kg", kg)).tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: columnWidth)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 156)
                } else {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Picker(localized("目标体重", "Target Weight"), selection: $targetImperialWeightLbDraft) {
                            ForEach(88...440, id: \.self) { value in
                                wheelOptionText("\(value) lb").tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .keepFitPopoverWheelSizing()
                        .frame(width: columnWidth)
                        Spacer(minLength: 0)
                    }
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
        let bodyFatOptions = (80...450).map { String(format: "%.1f %%", Double($0) / 10) }
        let columnWidth = adaptiveWheelColumnWidth(options: bodyFatOptions, minWidth: 102, maxWidth: 152, sideInset: 34)
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: [columnWidth],
            horizontalPadding: 5,
            minWidth: 178,
            maxWidth: 246
        )
        return selectionPopoverRow(
            icon: "chart.pie.fill",
            title: localized("目标体脂", "Target Body Fat"),
            color: .pink,
            value: targetBodyFatDisplayLabel,
            isPresented: $showTargetBodyFatSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .pink, title: localized("选择目标体脂", "Select Target Body Fat"), width: popoverWidth, horizontalPadding: 5) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Picker(localized("目标体脂", "Target Body Fat"), selection: $targetBodyFatTenthDraft) {
                        ForEach(80...450, id: \.self) { value in
                            let percent = Double(value) / 10
                            wheelOptionText(String(format: "%.1f %%", percent)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: columnWidth)
                    Spacer(minLength: 0)
                }
                .frame(height: 156)

                popoverDoneButton {
                    applyTargetBodyFatSelection()
                    showTargetBodyFatSheet = false
                }
            }
        }
    }

    private var exerciseGoalSelectionRow: some View {
        let options = exerciseGoalRange.map { "\($0) \(energyUnit.symbol)" }
        let columnWidth = adaptiveWheelColumnWidth(options: options, minWidth: 104, maxWidth: 164, sideInset: 36)
        let popoverWidth = adaptiveWheelPopoverWidth(
            columnWidths: [columnWidth],
            horizontalPadding: 5,
            minWidth: 178,
            maxWidth: 258
        )
        return selectionPopoverRow(
            icon: "figure.run.circle.fill",
            title: localized("每日运动目标", "Daily Exercise Goal"),
            color: .green,
            value: exerciseGoalDisplayLabel,
            isPresented: $showExerciseGoalSheet,
            onOpen: { syncGoalDrafts() }
        ) {
            glassOptionPopover(accent: .green, title: localized("选择每日运动目标", "Select Daily Exercise Goal"), width: popoverWidth, horizontalPadding: 5) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Picker(localized("每日运动目标", "Daily Exercise Goal"), selection: $exerciseGoalDraft) {
                        ForEach(exerciseGoalRange, id: \.self) { value in
                            wheelOptionText("\(value) \(energyUnit.symbol)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .keepFitPopoverWheelSizing()
                    .frame(width: columnWidth)
                    Spacer(minLength: 0)
                }
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
                    .font(settingsTitleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
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
                    .font(settingsTitleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
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
                    .font(settingsTitleFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .allowsTightening(true)
                infoButton(.intake)
            }
            Spacer()
            valueWithUnit(value: energyText(fromKcal: appState.profile.recommendedIntakeForFatLoss, includeUnit: false, unit: energyUnit), unit: energyUnit.symbol)
        }
    }

    private var languageSelectionRow: some View {
        selectionPopoverRow(icon: "globe", title: localized("语言选择", "Language Selection"), color: .blue, value: appLanguage.title, isPresented: $showLanguageSheet) {
            glassOptionPopover(
                accent: .blue,
                title: localized("选择语言", "Select Language"),
                width: estimatedPopoverWidth(from: AppLanguageOption.allCases.map(\.title), minWidth: 184, maxWidth: 228)
            ) {
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
        selectionPopoverRow(icon: "flame.fill", title: localized("能量", "Energy"), color: .teal, value: energyUnit.title, isPresented: $showEnergyUnitSheet) {
            glassOptionPopover(
                accent: .teal,
                title: localized("选择能量", "Select Energy"),
                width: estimatedPopoverWidth(from: EnergyUnitOption.allCases.map(\.title), minWidth: 184, maxWidth: 228)
            ) {
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
        selectionPopoverRow(icon: "ruler", title: localized("身高", "Height"), color: .blue, value: heightUnit.title, isPresented: $showHeightUnitSheet) {
            glassOptionPopover(
                accent: .blue,
                title: localized("选择身高", "Select Height"),
                width: estimatedPopoverWidth(from: HeightUnitOption.allCases.map(\.title), minWidth: 184, maxWidth: 232)
            ) {
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
        selectionPopoverRow(icon: "scalemass", title: localized("体重", "Weight"), color: .mint, value: weightUnit.title, isPresented: $showWeightUnitSheet) {
            glassOptionPopover(
                accent: .mint,
                title: localized("选择体重", "Select Weight"),
                width: estimatedPopoverWidth(from: WeightUnitOption.allCases.map(\.title), minWidth: 184, maxWidth: 232)
            ) {
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
            glassOptionPopover(
                accent: .orange,
                title: localized("选择日历开始", "Select Week Start"),
                width: estimatedPopoverWidth(from: WeekStartOption.allCases.map(\.title), minWidth: 184, maxWidth: 232)
            ) {
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
            glassOptionPopover(
                accent: .indigo,
                title: localized("选择主题模式", "Select Theme"),
                width: estimatedPopoverWidth(from: AppThemeMode.allCases.map(\.title), minWidth: 184, maxWidth: 236)
            ) {
                ForEach(AppThemeMode.allCases) { option in
                    popoverOptionCell(title: option.title, selected: option == themeMode, accent: .indigo) {
                        themeModeRaw = option.rawValue
                        applyThemeModeImmediately(option)
                        showThemeSheet = false
                    }
                }
            }
        }
    }

    private var shareText: String {
        localized(
            "我在用 KeepFit（管住嘴迈开腿）记录饮食和运动，推荐你也试试。",
            "I am using KeepFit to track food and workouts. Give it a try."
        )
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "v\(version) (\(build))"
    }

    private var aboutSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    avatarView(size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("KeepFit")
                            .font(.headline)
                        Text(localized("管住嘴迈开腿", "Eat Well · Move More"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                separatorLine()

                infoLine(title: localized("版本", "Version"), value: appVersionLabel)
                infoLine(title: localized("开发支持", "Support"), value: feedbackEmail)

                Text(localized("KeepFit 专注于饮食记录、运动消耗和热量平衡管理。", "KeepFit focuses on food logs, workout burn, and calorie balance."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                Spacer(minLength: 0)
            }
            .padding(18)
            .navigationTitle(localized("关于 KeepFit", "About KeepFit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("完成", "Done")) {
                        showAboutSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(330)])
    }

    private func infoLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func separatorLine() -> some View {
        Rectangle()
            .fill(settingsSeparatorTint)
            .frame(height: 0.8)
            .frame(maxWidth: .infinity)
    }

    private func openFeedbackEmail() {
        triggerHapticIfNeeded()
        guard let url = URL(string: "mailto:\(feedbackEmail)?subject=KeepFit%20Feedback") else {
            return
        }
        openURL(url)
    }

    private func refreshICloudSyncState() {
        appState.refreshICloudAvailability()
        let effective = appState.isICloudSyncEnabled
        if iCloudSyncEnabled != effective {
            iCloudSyncEnabled = effective
        }
    }

    private func triggerHapticIfNeeded(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        KeepFitHaptics.impact(style)
    }

    @MainActor
    private func handleReminderToggleChanged(_ reminder: ReminderKind, enabled: Bool) async {
        guard !handlingReminderToggle else { return }
        handlingReminderToggle = true
        defer { handlingReminderToggle = false }

        if enabled {
            let authorized = await requestReminderAuthorization()
            guard authorized else {
                setReminderToggle(reminder, enabled: false)
                reminderAlertMessage = localized("请先允许通知权限，再开启提醒。", "Please allow notifications before enabling reminders.")
                showReminderAlert = true
                appState.noteSettingsDidChange(refreshReminders: true)
                return
            }
            do {
                try await scheduleReminder(reminder)
                appState.noteSettingsDidChange(refreshReminders: true)
            } catch {
                setReminderToggle(reminder, enabled: false)
                reminderAlertMessage = localized("提醒创建失败，请稍后重试。", "Failed to schedule reminder. Please try again.")
                showReminderAlert = true
                appState.noteSettingsDidChange(refreshReminders: true)
            }
        } else {
            cancelReminder(reminder)
            appState.noteSettingsDidChange(refreshReminders: true)
        }
    }

    @MainActor
    private func syncReminderSchedulesOnAppear() async {
        guard !handlingReminderToggle else { return }
        handlingReminderToggle = true
        defer { handlingReminderToggle = false }

        let settings = await notificationSettings()
        let authorized = isNotificationAuthorized(settings.authorizationStatus)
        if !authorized {
            cancelReminder(.food)
            cancelReminder(.exercise)
            cancelReminder(.summary)
            return
        }

        if foodReminderEnabled {
            try? await scheduleReminder(.food)
        }
        if exerciseReminderEnabled {
            try? await scheduleReminder(.exercise)
        }
        if dailySummaryEnabled {
            try? await scheduleReminder(.summary)
        }
    }

    private func requestReminderAuthorization() async -> Bool {
        let currentSettings = await notificationSettings()
        switch currentSettings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return await requestNotificationAuthorization()
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func requestNotificationAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    @MainActor
    private func rescheduleReminderIfEnabled(_ reminder: ReminderKind) async {
        if isReminderEnabled(reminder) {
            do {
                try await scheduleReminder(reminder)
                appState.noteSettingsDidChange(refreshReminders: true)
            } catch {
                reminderAlertMessage = localized("提醒时间更新失败，请稍后重试。", "Failed to update reminder time. Please try again.")
                showReminderAlert = true
            }
        } else {
            cancelReminder(reminder)
            appState.noteSettingsDidChange(refreshReminders: true)
        }
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func isNotificationAuthorized(_ status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private func scheduleReminder(_ reminder: ReminderKind) async throws {
        cancelReminder(reminder)

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminderBody(for: reminder)
        content.sound = .default

        let minuteOfDay = minuteOfDay(for: reminder)
        var dateComponents = DateComponents()
        dateComponents.hour = minuteOfDay / 60
        dateComponents.minute = minuteOfDay % 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func reminderBody(for reminder: ReminderKind) -> String {
        switch reminder {
        case .food:
            return appState.foodReminderBody(on: Date())
        case .exercise:
            return appState.exerciseReminderBody(on: Date())
        case .summary:
            return appState.dailySummaryReminderBody(on: Date())
        }
    }

    private func cancelReminder(_ reminder: ReminderKind) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminder.identifier])
        center.removeDeliveredNotifications(withIdentifiers: [reminder.identifier])
    }

    private func setReminderToggle(_ reminder: ReminderKind, enabled: Bool) {
        switch reminder {
        case .food:
            foodReminderEnabled = enabled
        case .exercise:
            exerciseReminderEnabled = enabled
        case .summary:
            dailySummaryEnabled = enabled
        }
    }

    private func isReminderEnabled(_ reminder: ReminderKind) -> Bool {
        switch reminder {
        case .food:
            return foodReminderEnabled
        case .exercise:
            return exerciseReminderEnabled
        case .summary:
            return dailySummaryEnabled
        }
    }

    private func minuteOfDay(for reminder: ReminderKind) -> Int {
        switch reminder {
        case .food:
            return foodReminderMinuteOfDay
        case .exercise:
            return exerciseReminderMinuteOfDay
        case .summary:
            return summaryReminderMinuteOfDay
        }
    }

    private func date(fromMinuteOfDay minuteOfDay: Int) -> Date {
        let calendar = AppPreferences.calendar
        let dayStart = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: dayStart) ?? Date()
    }

    private func minuteOfDayValue(from date: Date) -> Int {
        let components = AppPreferences.calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func reminderHourBinding(for draft: Binding<Date>) -> Binding<Int> {
        Binding(
            get: {
                AppPreferences.calendar.component(.hour, from: draft.wrappedValue)
            },
            set: { newHour in
                let minute = AppPreferences.calendar.component(.minute, from: draft.wrappedValue)
                draft.wrappedValue = date(fromMinuteOfDay: newHour * 60 + minute)
            }
        )
    }

    private func reminderMinuteBinding(for draft: Binding<Date>) -> Binding<Int> {
        Binding(
            get: {
                AppPreferences.calendar.component(.minute, from: draft.wrappedValue)
            },
            set: { newMinute in
                let hour = AppPreferences.calendar.component(.hour, from: draft.wrappedValue)
                draft.wrappedValue = date(fromMinuteOfDay: hour * 60 + newMinute)
            }
        )
    }

    private func avatarView(size: CGFloat = 68) -> some View {
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
        .frame(width: size, height: size)
        .background(Color(.tertiarySystemBackground), in: Circle())
        .clipShape(Circle())
    }

    private func rowIcon(_ icon: String, _ color: Color) -> some View {
        Image(systemName: icon)
            .foregroundStyle(color)
            .frame(width: settingsCompactLayout ? 16 : 18)
    }

    private var appleAccountRowIcon: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.indigo.opacity(0.92),
                            Color.blue.opacity(0.88),
                            Color.cyan.opacity(0.82)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 19, height: 19)

            Image(systemName: "apple.logo")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 18)
    }

    private func adaptivePopoverArrowEdge(globalY: CGFloat) -> Edge {
        let screenHeight = max(UIScreen.main.bounds.height, 1)
        return globalY < screenHeight * 0.5 ? .top : .bottom
    }

    private func anchorY(for arrowEdge: Edge) -> CGFloat {
        switch arrowEdge {
        case .top:
            return 1
        case .bottom:
            return 0
        default:
            return 0.5
        }
    }

    private var popoverMaxWidthOnScreen: CGFloat {
        max(220, UIScreen.main.bounds.width - 42)
    }

    private let popoverWidthScale: CGFloat = 0.73

    private func clampedPopoverWidth(_ proposed: CGFloat, minWidth: CGFloat, maxWidth: CGFloat) -> CGFloat {
        let scaledMin = minWidth * popoverWidthScale
        let scaledMax = maxWidth * popoverWidthScale
        let scaledProposed = proposed * popoverWidthScale
        let safeMax = min(scaledMax, popoverMaxWidthOnScreen)
        return Swift.min(Swift.max(scaledProposed, scaledMin), safeMax)
    }

    private func estimatedPopoverWidth(from options: [String], minWidth: CGFloat = 184, maxWidth: CGFloat = 248) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let maxTextWidth = options
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let width = maxTextWidth + 58
        return clampedPopoverWidth(width, minWidth: minWidth, maxWidth: maxWidth)
    }

    private func estimatedParagraphPopoverWidth(_ paragraphs: [String], minWidth: CGFloat = 220, maxWidth: CGFloat = 360) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption2)
        let maxTextWidth = paragraphs
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let width = maxTextWidth + 34
        let safeMax = min(maxWidth, popoverMaxWidthOnScreen)
        return Swift.min(Swift.max(width, minWidth), safeMax)
    }

    private func measuredTextWidth(_ text: String, font: UIFont? = nil) -> CGFloat {
        let resolvedFont = font ?? settingsValueUIFont
        return ceil((text as NSString).size(withAttributes: [.font: resolvedFont]).width)
    }

    private func adaptiveWheelColumnWidth(
        options: [String],
        minWidth: CGFloat,
        maxWidth: CGFloat,
        sideInset: CGFloat = 28
    ) -> CGFloat {
        let maxTextWidth = options
            .map { measuredTextWidth($0) }
            .max() ?? 0
        let proposed = maxTextWidth + sideInset
        return Swift.min(Swift.max(proposed, minWidth), maxWidth)
    }

    private func adaptiveWheelPopoverWidth(
        columnWidths: [CGFloat],
        spacing: CGFloat = 0,
        horizontalPadding: CGFloat = 5,
        minWidth: CGFloat = 176,
        maxWidth: CGFloat = 360
    ) -> CGFloat {
        let columns = columnWidths.reduce(0, +)
        let spacingWidth = spacing * CGFloat(max(columnWidths.count - 1, 0))
        let proposed = columns + spacingWidth + horizontalPadding * 2
        let safeMax = min(maxWidth, popoverMaxWidthOnScreen)
        return Swift.min(Swift.max(proposed, minWidth), safeMax)
    }

    @ViewBuilder
    private func wheelOptionText(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .allowsTightening(true)
    }

    private func presentSelectionPopover(
        isPresented: Binding<Bool>,
        onOpen: (() -> Void)?,
        anchor: UnitPoint? = nil,
        arrowEdge: Edge? = nil
    ) {
        triggerHapticIfNeeded()
        if let anchor {
            selectionPopoverAnchor = anchor
        }
        if let arrowEdge {
            selectionPopoverArrowEdge = arrowEdge
        }
        onOpen?()
        isPresented.wrappedValue = true
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
        HStack(spacing: settingsCompactLayout ? 8 : 10) {
            rowIcon(icon, color)
            Text(title)
                .font(settingsTitleFont)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .allowsTightening(true)
                .layoutPriority(1)
            Spacer(minLength: 8)
            HStack(spacing: 2) {
                if let value, !value.isEmpty {
                    Text(value)
                        .lineLimit(1)
                        .font(settingsValueFont)
                        .minimumScaleFactor(0.74)
                        .allowsTightening(true)
                        .foregroundStyle(.secondary)
                }
                GeometryReader { proxy in
                    Button {
                        let frame = proxy.frame(in: .global)
                        let arrowEdge = adaptivePopoverArrowEdge(globalY: frame.midY)
                        let anchor = UnitPoint(x: 0.92, y: anchorY(for: arrowEdge))
                        presentSelectionPopover(
                            isPresented: isPresented,
                            onOpen: onOpen,
                            anchor: anchor,
                            arrowEdge: arrowEdge
                        )
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(localized("打开选项", "Open Options"))
                }
                .frame(width: settingsCompactLayout ? 18 : 20, height: 22)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .popover(isPresented: isPresented, attachmentAnchor: .point(selectionPopoverAnchor), arrowEdge: selectionPopoverArrowEdge) {
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
        width: CGFloat? = nil,
        minWidth: CGFloat = 184,
        maxWidth: CGFloat = 248,
        horizontalPadding: CGFloat = 12,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .font(.body)
        .padding(.vertical, 12)
        .padding(.horizontal, horizontalPadding)
        .frame(
            minWidth: minWidth,
            idealWidth: width ?? minWidth,
            maxWidth: width ?? min(maxWidth, popoverMaxWidthOnScreen),
            alignment: .leading
        )
        .fixedSize(horizontal: width == nil, vertical: false)
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
        Button {
            triggerHapticIfNeeded()
            action()
        } label: {
            HStack(spacing: 10) {
                Text(title)
                    .font(.body)
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
        Button {
            triggerHapticIfNeeded()
            action()
        } label: {
            Text(localized("完成", "Done"))
                .font(.body.weight(.medium))
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
                .font(.body)
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
        GeometryReader { proxy in
            Button {
                triggerHapticIfNeeded()
                infoPopoverSourceRect = proxy.frame(in: .global)
                withAnimation(.spring(response: 0.24, dampingFraction: 0.92)) {
                    activeInfo = activeInfo == topic ? nil : topic
                }
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 18, height: 18)
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
        let unitFont = UIFont.systemFont(ofSize: max(13, settingsValueFontSize - 1))
        let valueWidth = measuredTextWidth(value, font: settingsValueUIFont)
        let unitWidth = measuredTextWidth(unit, font: unitFont)
        let totalWidth = min(
            max(valueWidth + unitWidth + (settingsCompactLayout ? 10 : 12), settingsCompactLayout ? 84 : 96),
            settingsCompactLayout ? 120 : 136
        )

        return HStack(spacing: 6) {
            Text(value)
                .font(settingsValueFont)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(unit)
                .font(.system(size: max(13, settingsValueFontSize - 1)))
                .foregroundStyle(.secondary)
        }
        .frame(width: totalWidth, alignment: .trailing)
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

    private func glassInfoPopover(topic: SettingsInfoTopic, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.caption2)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.75)
                    .allowsTightening(true)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .frame(width: width ?? estimatedParagraphPopoverWidth(topic.paragraphs), alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(topic.accent.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 0.7)
                )
        )
    }

    @ViewBuilder
    private var settingsInfoOverlay: some View {
        GeometryReader { proxy in
            if let topic = activeInfo {
                let bubbleWidth = estimatedParagraphPopoverWidth(topic.paragraphs)
                let bubbleHeight = measuredInfoPopoverHeight(for: topic, width: bubbleWidth)
                let rootFrame = proxy.frame(in: .global)
                let showBelow = infoPopoverSourceRect.midY < rootFrame.midY
                let edgeInset: CGFloat = 16
                let verticalSpacing: CGFloat = 12
                let anchorX = infoPopoverSourceRect.midX - rootFrame.minX
                let clampedX = min(
                    max(anchorX, bubbleWidth / 2 + edgeInset),
                    proxy.size.width - bubbleWidth / 2 - edgeInset
                )
                let targetY = showBelow
                    ? infoPopoverSourceRect.maxY - rootFrame.minY + verticalSpacing + bubbleHeight / 2
                    : infoPopoverSourceRect.minY - rootFrame.minY - verticalSpacing - bubbleHeight / 2
                let clampedY = min(
                    max(targetY, bubbleHeight / 2 + edgeInset),
                    proxy.size.height - bubbleHeight / 2 - edgeInset
                )

                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.94)) {
                                activeInfo = nil
                            }
                        }

                    glassInfoPopover(topic: topic, width: bubbleWidth)
                        .position(x: clampedX, y: clampedY)
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .center)))
                }
            }
        }
        .allowsHitTesting(activeInfo != nil)
    }

    private func measuredInfoPopoverHeight(for topic: SettingsInfoTopic, width: CGFloat) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .caption2)
        let usableWidth = max(120, width - 24)
        let textHeight = topic.paragraphs.reduce(CGFloat.zero) { partial, paragraph in
            let rect = (paragraph as NSString).boundingRect(
                with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            return partial + ceil(rect.height)
        }
        return textHeight + CGFloat(max(topic.paragraphs.count - 1, 0)) * 5 + 24
    }

    private func ensureBirthDateSeeded() {
        if birthDateTimestamp > 0 { return }
        let date = birthDateFromAge(appState.profile.age)
        birthDateTimestamp = date.timeIntervalSince1970
    }

    private func applyThemeModeImmediately(_ mode: AppThemeMode) {
        let interfaceStyle: UIUserInterfaceStyle
        switch mode {
        case .system:
            interfaceStyle = .unspecified
        case .light:
            interfaceStyle = .light
        case .dark:
            interfaceStyle = .dark
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
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

    @MainActor
    private func handleHealthToggleChanged(_ enabled: Bool) async {
        guard !handlingHealthToggle else { return }
        handlingHealthToggle = true
        defer { handlingHealthToggle = false }

        if let errorMessage = await appState.setHealthSyncEnabled(enabled) {
            healthSyncEnabled = false
            healthSyncAlertMessage = errorMessage
            showHealthSyncAlert = true
        }
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

private enum ReminderKind: CaseIterable {
    case food
    case exercise
    case summary

    var identifier: String {
        switch self {
        case .food:
            return "keepfit.reminder.food"
        case .exercise:
            return "keepfit.reminder.exercise"
        case .summary:
            return "keepfit.reminder.summary"
        }
    }

    var title: String {
        switch self {
        case .food:
            return localized("饮食提醒", "Diet Reminder")
        case .exercise:
            return localized("运动提醒", "Exercise Reminder")
        case .summary:
            return localized("每日总结", "Daily Summary")
        }
    }

    var body: String {
        switch self {
        case .food:
            return localized("记得记录今天的饮食，保持摄入清晰。", "Remember to log today's meals and keep intake clear.")
        case .exercise:
            return localized("安排一段运动时间，迈开腿更接近目标。", "Schedule a workout and move closer to your goal.")
        case .summary:
            return localized("查看今天的数据总结，优化明天计划。", "Check today's summary and optimize tomorrow's plan.")
        }
    }
}

private enum SettingsInfoTopic: String, Identifiable {
    case bmr
    case tdee
    case intake

    var id: String { rawValue }

    var accent: Color {
        switch self {
        case .bmr, .tdee:
            return .green
        case .intake:
            return .red
        }
    }

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
                localized("活动系数：久坐1.2/轻度1.375/中度1.55/高强度1.725。", "Multiplier: sedentary 1.2 / light 1.375 / moderate 1.55 / very active 1.725.")
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

private extension View {
    func keepFitPopoverWheelSizing() -> some View {
        font(.body)
    }

    func keepFitSettingsSeparatorAligned() -> some View {
        keepFitSettingsRowStyle(verticalInset: 8)
    }

    private func keepFitSettingsRowStyle(verticalInset: CGFloat) -> some View {
        let rowBackground = Color(.secondarySystemGroupedBackground)
        return listRowSeparator(.hidden, edges: .all)
            .listRowInsets(EdgeInsets(top: verticalInset, leading: 18, bottom: verticalInset, trailing: 16))
            .listRowBackground(
                rowBackground
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(rowBackground)
                            .frame(height: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(rowBackground)
                            .frame(height: 1)
                    }
            )
    }
}

struct AppleAccountSheet: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let requireChoice: Bool

    @State private var errorMessage = ""
    @State private var showError = false

    private var isSignedIn: Bool {
        appState.isSignedInWithAppleAccount
    }

    private var heroTitle: String {
        if isSignedIn {
            return appState.accountDisplayTitle
        }
        return requireChoice
            ? localized("选择使用方式", "Choose How to Use")
            : localized("Apple 账号", "Apple Account")
    }

    private var heroSubtitle: String {
        if isSignedIn {
            return appState.accountStatusDetail
        }
        return requireChoice
            ? localized("登录后可在同一账号下同步数据与设置，不登录也可以先在本机使用。", "Sign in to sync your data and settings with the same account, or continue using this device locally.")
            : localized("可选择登录 Apple 账号，或继续本地使用。", "Sign in with Apple, or continue using local mode.")
    }

    private var heroDescription: String {
        if requireChoice {
            return localized(
                "登录 Apple 账号后，KeepFit 会同步你的档案、记录与常用设置。更换设备后，登录同一账号即可继续使用这些数据；如果暂不登录，也可以继续本地使用，现有功能不受影响。",
                "Sign in with Apple and KeepFit will sync your profile, logs, and common settings with this account. If you switch devices later, sign in with the same account to keep using your data. Or continue in local mode with all current features unchanged."
            )
        }
        return localized(
            "登录后，KeepFit 会在同一账号下同步你的档案、记录与常用设置；如果不登录，数据将继续仅保存在本机。",
            "After signing in, KeepFit will sync your profile, logs, and common settings with this account. If you do not sign in, your data will remain on this device only."
        )
    }

    private var localModeButtonTitle: String {
        requireChoice
            ? localized("先本地使用", "Use Local Mode First")
            : localized("继续本地使用", "Use Local Mode")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard
                    actionCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 24)
            }
            .navigationTitle(localized("Apple 账号", "Apple Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !requireChoice {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(localized("完成", "Done")) {
                            dismiss()
                        }
                    }
                }
            }
        }
        .interactiveDismissDisabled(requireChoice && appState.isAccountChoiceUndecided)
        .alert(localized("Apple 账号", "Apple Account"), isPresented: $showError) {
            Button(localized("知道了", "OK"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.26), lineWidth: 0.8)
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: isSignedIn ? "person.crop.circle.badge.checkmark" : "person.crop.circle.badge.plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(isSignedIn ? .green : .primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(heroTitle)
                        .font(.headline.weight(.semibold))
                    Text(heroSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Text(heroDescription)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.blue.opacity(0.10),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.26), lineWidth: 0.8)
                )
        )
    }

    @ViewBuilder
    private var actionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if isSignedIn {
                Button(role: .destructive) {
                    KeepFitHaptics.impact(.medium)
                    appState.signOutAppleAccount()
                    if !requireChoice {
                        dismiss()
                    }
                } label: {
                    Text(localized("退出 Apple 账号并切换为本地使用", "Sign Out and Use Local Mode"))
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.red.opacity(0.10))
                )
            } else {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAuthorizationResult(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    KeepFitHaptics.selection()
                    appState.continueWithLocalMode()
                    dismiss()
                } label: {
                    Text(localModeButtonTitle)
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.8)
                        )
                )
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.8)
                )
        )
    }

    private func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task {
                if let message = await appState.completeAppleSignIn(with: authorization) {
                    errorMessage = message
                    showError = true
                    return
                }
                dismiss()
            }
        case .failure(let error):
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                return
            }
            errorMessage = localized("Apple 登录失败，请稍后再试。", "Apple sign-in failed. Please try again.")
            showError = true
        }
    }
}
