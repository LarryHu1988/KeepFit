import SwiftUI

@main
struct KeepFitApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("keepfit.themeMode") private var themeModeRaw = AppThemeMode.system.rawValue

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(themeMode.preferredColorScheme)
        }
    }
}
