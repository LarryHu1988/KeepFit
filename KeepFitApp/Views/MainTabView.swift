import SwiftUI

struct MainTabView: View {
    @State private var showSettings = false

    var body: some View {
        TabView {
            EatWellView {
                showSettings = true
            }
            .tabItem {
                Label("管住嘴", systemImage: "fork.knife")
            }

            MoveMoreView {
                showSettings = true
            }
            .tabItem {
                Label("迈开腿", systemImage: "figure.run")
            }

            LoseWeightView {
                showSettings = true
            }
            .tabItem {
                Label("减个肥", systemImage: "sun.max")
            }
        }
        .tint(Color.accentColor)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
