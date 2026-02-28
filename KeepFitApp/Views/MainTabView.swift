import SwiftUI
import UIKit

struct MainTabView: View {
    private enum TabKey: Hashable {
        case eat
        case move
        case lose
    }

    @State private var showSettings = false
    @State private var selectedTab: TabKey = .eat
    @State private var eatTabSwitchToken = 0
    @State private var moveTabSwitchToken = 0
    @State private var loseTabSwitchToken = 0
    @State private var tabBarAppearanceConfigured = false
    @State private var navigationBarAppearanceConfigured = false

    var body: some View {
        TabView(selection: $selectedTab) {
            EatWellView {
                showSettings = true
            }
            .tag(TabKey.eat)
            .environment(\.tabSwitchToken, eatTabSwitchToken)
            .tabItem {
                Label(localized("管住嘴", "Eat Well"), systemImage: "fork.knife")
            }

            MoveMoreView {
                showSettings = true
            }
            .tag(TabKey.move)
            .environment(\.tabSwitchToken, moveTabSwitchToken)
            .tabItem {
                Label(localized("迈开腿", "Move More"), systemImage: "figure.run")
            }

            LoseWeightView {
                showSettings = true
            }
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
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            configureTabBarAppearanceIfNeeded()
            configureNavigationBarAppearanceIfNeeded()
        }
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
