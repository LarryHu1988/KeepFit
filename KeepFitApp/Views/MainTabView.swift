import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("keepfit.appLanguage") private var appLanguageRaw = AppLanguageOption.chinese.rawValue

    private enum TabKey: Hashable {
        case eat
        case move
        case lose
    }

    private enum PresentedSheet: String, Identifiable {
        case settings

        var id: String { rawValue }
    }

    @State private var presentedSheet: PresentedSheet?
    @State private var selectedTab: TabKey = .eat
    @State private var eatTabSwitchToken = 0
    @State private var moveTabSwitchToken = 0
    @State private var loseTabSwitchToken = 0

    private var keepfitLaunchSelectedTab: TabKey? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-keepfit-selected-tab"), arguments.indices.contains(index + 1) else {
            return nil
        }
        switch arguments[index + 1] {
        case "eat": return .eat
        case "move": return .move
        case "lose": return .lose
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            EatWellView(onSettingsTap: handleSettingsTap)
                .tag(TabKey.eat)
                .environment(\.tabSwitchToken, eatTabSwitchToken)
                .tabItem {
                    Label(localized("管住嘴", "Eat Well"), systemImage: "fork.knife")
                }

            MoveMoreView(onSettingsTap: handleSettingsTap)
                .tag(TabKey.move)
                .environment(\.tabSwitchToken, moveTabSwitchToken)
                .tabItem {
                    Label(localized("迈开腿", "Move More"), systemImage: "figure.run")
                }

            LoseWeightView(onSettingsTap: handleSettingsTap)
                .tag(TabKey.lose)
                .environment(\.tabSwitchToken, loseTabSwitchToken)
                .tabItem {
                    Label(localized("减个肥", "Lose Weight"), systemImage: "sun.max")
                }
        }
        .id("main-tab-language-\(appLanguageRaw)")
        .tint(Color.accentColor)
        .onChange(of: selectedTab) { _, newValue in
            switch newValue {
            case .eat:
                eatTabSwitchToken += 1
            case .move:
                moveTabSwitchToken += 1
            case .lose:
                loseTabSwitchToken += 1
            }
        }
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .settings:
                SettingsView()
                    .environmentObject(appState)
            }
        }
        .onAppear {
            configureSystemTabBarAppearance()
            if let launchTab = keepfitLaunchSelectedTab {
                selectedTab = launchTab
            }
        }
        .onChange(of: colorScheme) { _, _ in
            configureSystemTabBarAppearance()
        }
    }

    private func handleSettingsTap() {
        presentedSheet = .settings
    }

    private func configureSystemTabBarAppearance() {
        // Xcode 26 gives TabView a native Liquid Glass bar. Keep the custom
        // material only as the visual fallback for iOS 17 through iOS 25.
        if #available(iOS 26.0, *) {
            return
        }

        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(
            style: colorScheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
        )
        appearance.backgroundColor = UIColor.white.withAlphaComponent(colorScheme == .dark ? 0.05 : 0.14)
        appearance.shadowColor = .clear

        let normalColor = UIColor.secondaryLabel.withAlphaComponent(colorScheme == .dark ? 0.78 : 0.9)
        let selectedColor = UIColor.systemBlue

        for itemAppearance in [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ] {
            itemAppearance.normal.iconColor = normalColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
            itemAppearance.selected.iconColor = selectedColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        }

        let tabBarAppearance = UITabBar.appearance()
        tabBarAppearance.standardAppearance = appearance
        tabBarAppearance.scrollEdgeAppearance = appearance
        tabBarAppearance.isTranslucent = true
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
