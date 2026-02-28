import SwiftUI
import UIKit

@main
struct KeepFitApp: App {
    @StateObject private var appState = AppState()
    @AppStorage("keepfit.themeMode") private var themeModeRaw = AppThemeMode.system.rawValue
    @AppStorage("keepfit.appLanguage") private var appLanguageRaw = AppLanguageOption.chinese.rawValue
    @AppStorage("keepfit.onboarding.completed") private var onboardingCompleted = false

    private var themeMode: AppThemeMode {
        AppThemeMode(rawValue: themeModeRaw) ?? .system
    }

    private var appLanguage: AppLanguageOption {
        AppLanguageOption(rawValue: appLanguageRaw) ?? .chinese
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCompleted {
                    MainTabView()
                } else {
                    OnboardingView {
                        onboardingCompleted = true
                    }
                }
            }
            .environmentObject(appState)
            .environment(\.locale, Locale(identifier: appLanguage.localeIdentifier))
            .onAppear {
                applyThemeMode(themeMode)
            }
            .onChange(of: themeModeRaw) { _, newValue in
                let mode = AppThemeMode(rawValue: newValue) ?? .system
                applyThemeMode(mode)
            }
        }
    }

    private func applyThemeMode(_ mode: AppThemeMode) {
        let interfaceStyle: UIUserInterfaceStyle
        switch mode {
        case .system:
            interfaceStyle = .unspecified
        case .light:
            interfaceStyle = .light
        case .dark:
            interfaceStyle = .dark
        }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = interfaceStyle
            }
        }
    }
}
