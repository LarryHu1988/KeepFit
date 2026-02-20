import SwiftUI

@main
struct KeepFitApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("keepfit.themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("keepfit.appLanguage") private var appLanguageRaw = AppLanguageOption.chinese.rawValue

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var appLanguage: AppLanguageOption {
        AppLanguageOption(rawValue: appLanguageRaw) ?? .chinese
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(themeMode.preferredColorScheme)
                .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
        }
    }
}
