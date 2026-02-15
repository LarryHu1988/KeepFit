import PhotosUI
import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @AppStorage("keepfit.reminder") private var reminderEnabled = true
    @AppStorage("keepfit.haptic") private var hapticEnabled = true
    @AppStorage("keepfit.autoSync") private var autoSyncEnabled = false

    @State private var selectedAvatarItem: PhotosPickerItem?

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
                        Label("选择头像", systemImage: "person.crop.circle.badge.plus")
                    }
                } header: {
                    Label("个人头像", systemImage: "person.crop.circle")
                }

                Section {
                    iconTextFieldRow(icon: "ruler", title: "身高(cm)", text: bindingDouble(\.heightCm, format: "%.0f"), keyboard: .decimalPad)
                    iconTextFieldRow(icon: "scalemass", title: "体重(kg)", text: bindingDouble(\.weightKg, format: "%.1f"), keyboard: .decimalPad)

                    HStack {
                        Label("年龄", systemImage: "calendar")
                        Spacer()
                        Stepper("\(appState.profile.age)", value: binding(\.age), in: 10...90)
                            .labelsHidden()
                    }

                    HStack {
                        Label("性别", systemImage: "person.fill")
                        Spacer()
                        Picker("性别", selection: binding(\.sex)) {
                            ForEach(BiologicalSex.allCases) { sex in
                                Text(sex.title).tag(sex)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    HStack {
                        Label("活动水平", systemImage: "figure.walk")
                        Spacer()
                        Picker("活动水平", selection: binding(\.activityLevel)) {
                            ForEach(ActivityLevel.allCases) { level in
                                Text(level.title).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                } header: {
                    Label("基础信息", systemImage: "person.text.rectangle")
                }

                Section {
                    iconTextFieldRow(icon: "target", title: "目标体重(kg)", text: bindingDouble(\.targetWeightKg, format: "%.1f"), keyboard: .decimalPad)
                    iconTextFieldRow(icon: "drop", title: "目标体脂(%)", text: bindingDouble(\.targetBodyFat, format: "%.1f"), keyboard: .decimalPad)
                    iconTextFieldRow(icon: "flame", title: "每日运动目标(kcal)", text: bindingDouble(\.dailyExerciseGoal, format: "%.0f"), keyboard: .decimalPad)

                    HStack {
                        Label("维持消耗", systemImage: "bolt.heart")
                        Spacer()
                        Text("\(Int(appState.profile.dailyMaintenanceCalories)) kcal")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("减脂建议摄入", systemImage: "leaf")
                        Spacer()
                        Text("\(Int(appState.profile.recommendedIntakeForFatLoss)) kcal")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("目标与建议", systemImage: "chart.line.uptrend.xyaxis")
                }

                Section {
                    Toggle(isOn: $reminderEnabled) {
                        Label("饮食/运动提醒", systemImage: "bell")
                    }

                    Toggle(isOn: $hapticEnabled) {
                        Label("触感反馈", systemImage: "hand.tap")
                    }

                    Toggle(isOn: $autoSyncEnabled) {
                        Label("自动同步健康数据", systemImage: "arrow.triangle.2.circlepath")
                    }
                } header: {
                    Label("常用设置", systemImage: "gearshape.2")
                }
            }
            .navigationTitle("个人设置")
            .navigationBarTitleDisplayMode(.inline)
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

    private func iconTextFieldRow(icon: String, title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            TextField(title, text: text)
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
                .frame(width: 120)
        }
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
