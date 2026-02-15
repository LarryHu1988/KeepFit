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
                        HStack(spacing: 10) {
                            rowIcon("person.crop.circle.badge.plus", .purple)
                            Text("选择头像")
                        }
                    }
                } header: {
                    Label("个人头像", systemImage: "person.crop.circle")
                }

                Section {
                    iconTextFieldRow(icon: "ruler", title: "身高", text: bindingDouble(\.heightCm, format: "%.0f"), unit: "cm", keyboard: .decimalPad, color: .blue)
                    iconTextFieldRow(icon: "scalemass", title: "体重", text: bindingDouble(\.weightKg, format: "%.1f"), unit: "kg", keyboard: .decimalPad, color: .mint)

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("calendar", .orange)
                            Text("年龄")
                        }
                        Spacer()
                        HStack(spacing: 8) {
                            Text("\(appState.profile.age) yr")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Stepper("", value: binding(\.age), in: 10...90)
                                .labelsHidden()
                        }
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("person.fill", .pink)
                            Text("性别")
                        }
                        Spacer()
                        Menu {
                            ForEach(BiologicalSex.allCases) { sex in
                                Button(sex.title) {
                                    appState.profile.sex = sex
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(appState.profile.sex.title)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("figure.walk", .green)
                            Text("活动水平")
                        }
                        Spacer()
                        Menu {
                            ForEach(ActivityLevel.allCases) { level in
                                Button(level.title) {
                                    appState.profile.activityLevel = level
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(appState.profile.activityLevel.title)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("基础信息", systemImage: "person.text.rectangle")
                }

                Section {
                    iconTextFieldRow(icon: "target", title: "目标体重", text: bindingDouble(\.targetWeightKg, format: "%.1f"), unit: "kg", keyboard: .decimalPad, color: .teal)
                    iconTextFieldRow(icon: "drop", title: "目标体脂", text: bindingDouble(\.targetBodyFat, format: "%.1f"), unit: "%", keyboard: .decimalPad, color: .cyan)
                    iconTextFieldRow(icon: "figure.run.circle.fill", title: "每日运动目标", text: bindingDouble(\.dailyExerciseGoal, format: "%.0f"), unit: "kcal", keyboard: .decimalPad, color: .green)

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("speedometer", .green)
                            Text("维持消耗")
                        }
                        Spacer()
                        valueWithUnit(value: "\(Int(appState.profile.dailyMaintenanceCalories))", unit: "kcal")
                    }

                    HStack {
                        HStack(spacing: 10) {
                            rowIcon("fork.knife.circle.fill", .red)
                            Text("减脂建议摄入")
                        }
                        Spacer()
                        valueWithUnit(value: "\(Int(appState.profile.recommendedIntakeForFatLoss))", unit: "kcal")
                    }
                } header: {
                    Label("目标与建议", systemImage: "chart.line.uptrend.xyaxis")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            rowIcon("heart.text.square.fill", .green)
                            Text("基础代谢 BMR (Mifflin-St Jeor)")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("男: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 + 5")
                            .font(.caption)
                        Text("女: 10×体重(kg) + 6.25×身高(cm) - 5×年龄 - 161")
                            .font(.caption)
                        Text("当前 BMR ≈ \(Int(appState.profile.bmr)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack(spacing: 10) {
                            rowIcon("speedometer", .green)
                            Text("维持消耗 TDEE")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("TDEE = BMR × 活动系数")
                            .font(.caption)
                        Text("活动系数: 久坐 1.2 / 轻度 1.375 / 中度 1.55 / 高强度 1.725")
                            .font(.caption)
                        Text("当前 TDEE ≈ \(Int(appState.profile.dailyMaintenanceCalories)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider()

                        HStack(spacing: 10) {
                            rowIcon("fork.knife.circle.fill", .red)
                            Text("建议摄入与净差计算")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("减脂建议摄入 = max(1200, TDEE - 450)")
                            .font(.caption)
                        Text("当前建议摄入 ≈ \(Int(appState.profile.recommendedIntakeForFatLoss)) kcal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("当日净差 = 摄入 - (TDEE + 运动消耗)，负值为赤字，正值为超量。")
                            .font(.caption)
                    }
                    .padding(.vertical, 2)
                } header: {
                    Label("科学计算说明", systemImage: "book.closed")
                }

                Section {
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
                    Label("常用设置", systemImage: "gearshape.2")
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
