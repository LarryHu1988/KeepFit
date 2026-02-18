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

    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var showSexSheet = false
    @State private var showActivitySheet = false
    @State private var activeInfo: SettingsInfoTopic?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        avatarView
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("用户名", text: binding(\.name))
                                .textFieldStyle(.roundedBorder)
                            Text("KeepFit · 管住嘴迈开腿")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    PhotosPicker(selection: $selectedAvatarItem, matching: .images) {
                        HStack(spacing: 10) {
                            rowIcon("person.crop.circle.badge.plus", .purple)
                            Text("选择头像")
                        }
                    }
                } header: {
                    Text("个人头像")
                }

                Section {
                    iconTextFieldRow(icon: "ruler", title: "身高", text: bindingDouble(\.heightCm, format: "%.0f"), unit: "cm", keyboard: .decimalPad, color: .blue)
                    iconTextFieldRow(icon: "scalemass", title: "体重", text: bindingDouble(\.weightKg, format: "%.1f"), unit: "kg", keyboard: .decimalPad, color: .mint)
                    iconTextFieldRow(icon: "calendar", title: "年龄", text: bindingInt(\.age), unit: "yr", keyboard: .numberPad, color: .orange)

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("person.fill", .pink)
                            Text("性别")
                        }
                        Spacer()
                        Button {
                            showSexSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(appState.profile.sex.title)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("figure.walk", .green)
                            Text("活动水平")
                        }
                        Spacer()
                        Button {
                            showActivitySheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Text(appState.profile.activityLevel.title)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("基础信息")
                }

                Section {
                    iconTextFieldRow(icon: "target", title: "目标体重", text: bindingDouble(\.targetWeightKg, format: "%.1f"), unit: "kg", keyboard: .decimalPad, color: .teal)
                    iconTextFieldRow(icon: "chart.pie.fill", title: "目标体脂", text: bindingDouble(\.targetBodyFat, format: "%.1f"), unit: "%", keyboard: .decimalPad, color: .pink)
                    iconTextFieldRow(icon: "figure.run.circle.fill", title: "每日运动目标", text: bindingDouble(\.dailyExerciseGoal, format: "%.0f"), unit: "kcal", keyboard: .decimalPad, color: .green)

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("heart.text.square.fill", .green)
                            Text("基础代谢 BMR")
                            infoButton(.bmr)
                        }
                        Spacer()
                        valueWithUnit(value: "\(Int(appState.profile.bmr))", unit: "kcal")
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("speedometer", .green)
                            Text("维持消耗 TDEE")
                            infoButton(.tdee)
                        }
                        Spacer()
                        valueWithUnit(value: "\(Int(appState.profile.dailyMaintenanceCalories))", unit: "kcal")
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("fork.knife.circle.fill", .red)
                            Text("减脂建议摄入")
                            infoButton(.intake)
                        }
                        Spacer()
                        valueWithUnit(value: "\(Int(appState.profile.recommendedIntakeForFatLoss))", unit: "kcal")
                    }
                } header: {
                    Text("目标与建议")
                }

                Section {
                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("circle.lefthalf.filled", .indigo)
                            Text("主题模式")
                        }
                        Spacer()
                        Picker("", selection: $themeModeRaw) {
                            ForEach(AppThemeMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }

                    Toggle(isOn: $reminderEnabled) {
                        HStack(spacing: 10) {
                            rowIcon("bell", .orange)
                            Text("饮食/运动提醒")
                        }
                    }

                    Toggle(isOn: $hapticEnabled) {
                        HStack(spacing: 10) {
                            rowIcon("hand.tap", .blue)
                            Text("触感反馈")
                        }
                    }

                    Toggle(isOn: $autoSyncEnabled) {
                        HStack(spacing: 10) {
                            rowIcon("arrow.triangle.2.circlepath", .green)
                            Text("自动同步健康数据")
                        }
                    }
                } header: {
                    Text("常用设置")
                }
            }
            .navigationTitle("个人设置")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
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
            .sheet(isPresented: $showSexSheet) {
                selectionSheet(
                    title: "选择性别",
                    options: [.male, .female],
                    selectedTitle: appState.profile.sex.title,
                    label: { $0.title },
                    onSelect: { value in
                        appState.profile.sex = value
                    },
                    onClose: {
                        showSexSheet = false
                    }
                )
                .presentationDetents([.fraction(0.35)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(isPresented: $showActivitySheet) {
                selectionSheet(
                    title: "选择活动水平",
                    options: ActivityLevel.allCases,
                    selectedTitle: appState.profile.activityLevel.title,
                    label: { $0.title },
                    onSelect: { value in
                        appState.profile.activityLevel = value
                    },
                    onClose: {
                        showActivitySheet = false
                    }
                )
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
                .presentationBackground(.ultraThinMaterial)
            }
            .sheet(item: $activeInfo) { topic in
                infoSheet(topic: topic)
                    .presentationDetents([.height(topic.sheetHeight)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                    .presentationBackground(.ultraThinMaterial)
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

    private func infoButton(_ topic: SettingsInfoTopic) -> some View {
        Button {
            activeInfo = topic
        } label: {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
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
                .monospacedDigit()
                .frame(width: 84, alignment: .trailing)
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 130, alignment: .trailing)
    }

    private func selectionSheet<T: Identifiable>(
        title: String,
        options: [T],
        selectedTitle: String,
        label: @escaping (T) -> String,
        onSelect: @escaping (T) -> Void,
        onClose: @escaping () -> Void
    ) -> some View {
        NavigationStack {
            List {
                ForEach(options) { option in
                    Button {
                        onSelect(option)
                        onClose()
                    } label: {
                        HStack {
                            Text(label(option))
                                .foregroundStyle(.primary)
                            Spacer()
                            if label(option) == selectedTitle {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        onClose()
                    }
                }
            }
        }
    }

    private func infoSheet(topic: SettingsInfoTopic) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(topic.title)
                    .font(.headline.weight(.semibold))
                Spacer()
                Button("完成") {
                    activeInfo = nil
                }
                .font(.subheadline)
            }

            ForEach(Array(topic.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .padding(.bottom, 2)
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

    private func bindingInt(_ keyPath: WritableKeyPath<UserProfile, Int>) -> Binding<String> {
        Binding(
            get: { String(appState.profile[keyPath: keyPath]) },
            set: { input in
                let digits = input.filter(\.isNumber)
                if let value = Int(digits) {
                    appState.profile[keyPath: keyPath] = min(max(value, 10), 90)
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
            return "基础代谢 BMR"
        case .tdee:
            return "维持消耗 TDEE"
        case .intake:
            return "减脂建议摄入"
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
                "Mifflin-St Jeor 公式。",
                "男性: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 + 5。",
                "女性: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 - 161。"
            ]
        case .tdee:
            return [
                "TDEE = BMR × 活动系数。",
                "活动系数: 久坐 1.2 / 轻度活动 1.375 / 中度活动 1.55 / 高强度活动 1.725。"
            ]
        case .intake:
            return [
                "减脂建议摄入 = max(1200, TDEE - 450)。",
                "当日净差 = 摄入 - (TDEE + 运动消耗)。",
                "负值为赤字，正值为超量。"
            ]
        }
    }
}
