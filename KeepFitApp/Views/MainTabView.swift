import SwiftUI
import UIKit

struct MainTabView: View {
    private enum TabKey: Hashable {
        case eat
        case move
        case lose
    }

    private enum GuideStep: Int {
        case addFood = 0
        case switchToMove = 1
        case addExercise = 2
        case switchToLose = 3
        case addBodyMetric = 4
        case openSettings = 5
        case completed = 6

        static let totalInteractiveSteps = 6

        var isCompleted: Bool {
            self == .completed
        }

        var progressIndex: Int {
            switch self {
            case .addFood: return 1
            case .switchToMove: return 2
            case .addExercise: return 3
            case .switchToLose: return 4
            case .addBodyMetric: return 5
            case .openSettings: return 6
            case .completed: return 6
            }
        }

        var accent: Color {
            switch self {
            case .addFood, .switchToMove:
                return .orange
            case .addExercise, .switchToLose:
                return .green
            case .addBodyMetric, .openSettings, .completed:
                return .blue
            }
        }

        var title: String {
            switch self {
            case .addFood:
                return localized("添加一条进食记录", "Add a food entry")
            case .switchToMove:
                return localized("切换到迈开腿", "Switch to Move tab")
            case .addExercise:
                return localized("添加一条锻炼记录", "Add a workout entry")
            case .switchToLose:
                return localized("切换到减个肥", "Switch to Lose Weight tab")
            case .addBodyMetric:
                return localized("记录体重体脂", "Save weight/body fat")
            case .openSettings:
                return localized("打开设置完善信息", "Open Settings")
            case .completed:
                return localized("引导完成", "Guide Completed")
            }
        }

        var tip: String {
            switch self {
            case .addFood:
                return localized("请在进食记录卡片中点击 +，添加今天第一条进食。", "Tap + in Food Log to add your first meal for today.")
            case .switchToMove:
                return localized("请点击底部“迈开腿”标签，继续下一步。", "Tap the Move tab at the bottom to continue.")
            case .addExercise:
                return localized("请在锻炼记录卡片中点击 +，添加一条运动。", "Tap + in Workout Log to add one exercise.")
            case .switchToLose:
                return localized("请点击底部“减个肥”标签，继续下一步。", "Tap the Lose Weight tab at the bottom to continue.")
            case .addBodyMetric:
                return localized("请在体重体脂卡片中点击 +，保存今天的体重和体脂。", "Tap + in the Weight/Body Fat card to save today's metrics.")
            case .openSettings:
                return localized("最后一步：点击右上角设置按钮，完善基础信息。", "Final step: tap the top-right Settings button to complete profile setup.")
            case .completed:
                return localized("已完成首次引导。", "First-use guide completed.")
            }
        }
    }

    private enum GuideAction {
        case switchedTab(TabKey)
        case addedFood
        case addedExercise
        case addedBodyMetric
        case openedSettings
    }

    @Binding var onboardingCompleted: Bool
    @AppStorage("keepfit.onboarding.step") private var onboardingStepRaw = GuideStep.addFood.rawValue

    @State private var showSettings = false
    @State private var selectedTab: TabKey = .eat
    @State private var eatTabSwitchToken = 0
    @State private var moveTabSwitchToken = 0
    @State private var loseTabSwitchToken = 0
    @State private var tabBarAppearanceConfigured = false
    @State private var navigationBarAppearanceConfigured = false
    @State private var guideStep: GuideStep = .addFood

    private var isGuideActive: Bool {
        !onboardingCompleted && !guideStep.isCompleted
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EatWellView(
                onSettingsTap: handleSettingsTap,
                onFoodLogged: {
                    handleGuideAction(.addedFood)
                }
            )
            .tag(TabKey.eat)
            .environment(\.tabSwitchToken, eatTabSwitchToken)
            .tabItem {
                Label(localized("管住嘴", "Eat Well"), systemImage: "fork.knife")
            }

            MoveMoreView(
                onSettingsTap: handleSettingsTap,
                onExerciseLogged: {
                    handleGuideAction(.addedExercise)
                }
            )
            .tag(TabKey.move)
            .environment(\.tabSwitchToken, moveTabSwitchToken)
            .tabItem {
                Label(localized("迈开腿", "Move More"), systemImage: "figure.run")
            }

            LoseWeightView(
                onSettingsTap: handleSettingsTap,
                onBodyMetricSaved: {
                    handleGuideAction(.addedBodyMetric)
                }
            )
            .tag(TabKey.lose)
            .environment(\.tabSwitchToken, loseTabSwitchToken)
            .tabItem {
                Label(localized("减个肥", "Lose Weight"), systemImage: "sun.max")
            }
        }
        .tint(Color.accentColor)
        .onChange(of: selectedTab) { _, newValue in
            KeepFitHaptics.selection()
            switch newValue {
            case .eat:
                eatTabSwitchToken += 1
            case .move:
                moveTabSwitchToken += 1
            case .lose:
                loseTabSwitchToken += 1
            }
            handleGuideAction(.switchedTab(newValue))
        }
        .overlay(alignment: .bottom) {
            if isGuideActive {
                firstUseGuideBanner
                    .padding(.horizontal, 16)
                    .padding(.bottom, 84)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            configureTabBarAppearanceIfNeeded()
            configureNavigationBarAppearanceIfNeeded()
            bootstrapGuideIfNeeded()
        }
        .onChange(of: guideStep) { _, newValue in
            guard !onboardingCompleted else { return }
            onboardingStepRaw = min(newValue.rawValue, GuideStep.openSettings.rawValue)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: guideStep)
    }

    private func configureTabBarAppearanceIfNeeded() {
        guard !tabBarAppearanceConfigured else { return }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true

        tabBarAppearanceConfigured = true
    }

    private func configureNavigationBarAppearanceIfNeeded() {
        guard !navigationBarAppearanceConfigured else { return }

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance

        navigationBarAppearanceConfigured = true
    }

    private var firstUseGuideBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(localized("首次引导", "First-use Guide"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(guideStep.progressIndex)/\(GuideStep.totalInteractiveSteps)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text(guideStep.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Text(guideStep.tip)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    guideStep.accent.opacity(0.18),
                                    guideStep.accent.opacity(0.08),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.32), lineWidth: 0.8)
                )
        )
    }

    private func bootstrapGuideIfNeeded() {
        guard !onboardingCompleted else {
            guideStep = .completed
            return
        }

        guideStep = GuideStep(rawValue: onboardingStepRaw) ?? .addFood
        if guideStep.isCompleted {
            guideStep = .addFood
            onboardingStepRaw = GuideStep.addFood.rawValue
        }
    }

    private func handleSettingsTap() {
        handleGuideAction(.openedSettings)
        showSettings = true
    }

    private func handleGuideAction(_ action: GuideAction) {
        guard isGuideActive else { return }

        switch (guideStep, action) {
        case (.addFood, .addedFood):
            guideStep = .switchToMove
        case (.switchToMove, .switchedTab(.move)):
            guideStep = .addExercise
        case (.addExercise, .addedExercise):
            guideStep = .switchToLose
        case (.switchToLose, .switchedTab(.lose)):
            guideStep = .addBodyMetric
        case (.addBodyMetric, .addedBodyMetric):
            guideStep = .openSettings
        case (.openSettings, .openedSettings):
            completeFirstUseGuide()
        default:
            break
        }
    }

    private func completeFirstUseGuide() {
        guideStep = .completed
        onboardingCompleted = true
        onboardingStepRaw = GuideStep.addFood.rawValue
    }
}

private struct TabSwitchTokenKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var tabSwitchToken: Int {
        get { self[TabSwitchTokenKey.self] }
        set { self[TabSwitchTokenKey.self] = newValue }
    }
}
