import SwiftUI

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

    var body: some View {
        TabView(selection: $selectedTab) {
            EatWellView {
                showSettings = true
            }
            .tag(TabKey.eat)
            .environment(\.tabSwitchToken, eatTabSwitchToken)
            .tabItem {
                Label("管住嘴", systemImage: "fork.knife")
            }

            MoveMoreView {
                showSettings = true
            }
            .tag(TabKey.move)
            .environment(\.tabSwitchToken, moveTabSwitchToken)
            .tabItem {
                Label("迈开腿", systemImage: "figure.run")
            }

            LoseWeightView {
                showSettings = true
            }
            .tag(TabKey.lose)
            .environment(\.tabSwitchToken, loseTabSwitchToken)
            .tabItem {
                Label("减个肥", systemImage: "sun.max")
            }
        }
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
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
