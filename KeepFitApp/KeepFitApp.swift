import SwiftUI
import UIKit
import UserNotifications

final class KeepFitAppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = KeepFitNotificationDelegate()

    func application(
        _: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        KeepFitHaptics.prepare()
        return true
    }

    func applicationDidBecomeActive(_: UIApplication) {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        KeepFitHaptics.prepare()
    }
}

final class KeepFitNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound, .badge])
    }
}

@main
struct KeepFitApp: App {
    @UIApplicationDelegateAdaptor(KeepFitAppDelegate.self) private var appDelegate
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
