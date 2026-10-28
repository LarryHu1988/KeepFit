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
        GeometryReader { geometry in
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
            .environment(\.keepFitUsesWideLayout, KeepFitAdaptiveLayout.usesColumns(in: geometry))
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

// Only an unfolded, landscape inner display gets the two-column composition.
// The native TabView owns Duo's trailing navigation rail and its safe area.
private enum KeepFitWideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

private enum KeepFitPageWidthKey: EnvironmentKey {
    static let defaultValue: CGFloat = max(0, UIScreen.main.bounds.width - 32)
}

extension EnvironmentValues {
    var keepFitUsesWideLayout: Bool {
        get { self[KeepFitWideLayoutKey.self] }
        set { self[KeepFitWideLayoutKey.self] = newValue }
    }

    var keepFitPageWidth: CGFloat {
        get { self[KeepFitPageWidthKey.self] }
        set { self[KeepFitPageWidthKey.self] = newValue }
    }
}

private enum KeepFitAdaptiveLayout {
    static func usesColumns(in geometry: GeometryProxy) -> Bool {
        if #available(iOS 27.1, *) {
            return geometry.size.width >= 700
                && geometry.size.width > geometry.size.height + geometry.safeAreaInsets.bottom
                && !geometry.reservedRegions(kind: .division, options: .includeInactive).isEmpty
        }
        return false
    }

    static func columns(in geometry: GeometryProxy) -> (leading: CGFloat, gap: CGFloat) {
        let width = max(0, geometry.size.width - 32)
        if #available(iOS 27.1, *) {
            for region in geometry.reservedRegions(kind: .division, options: .includeInactive) {
                guard region.frame.height > region.frame.width else { continue }
                let start = region.frame.minX - region.margins.leading - 12
                let end = region.frame.maxX + region.margins.trailing + 12
                guard start >= 280, geometry.size.width - end >= 300 else { continue }
                return (start - 16, end - start)
            }
        }
        // Give forms and charts more room when there is no reserved center strip.
        return (max(0, width - 22) * 0.42, 22)
    }
}

// A compact page must have one vertical scroll container. Nesting axis-less
// scroll views here collapses their proposed height and clips every card.
struct KeepFitAdaptivePage<Primary: View, Secondary: View>: View {
    @Environment(\.keepFitUsesWideLayout) private var usesWideLayout
    let spacing: CGFloat
    @ViewBuilder var primary: () -> Primary
    @ViewBuilder var secondary: () -> Secondary

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(0, geometry.size.width - 32)
            if usesWideLayout {
                let columns = KeepFitAdaptiveLayout.columns(in: geometry)
                HStack(alignment: .top, spacing: columns.gap) {
                    pane(width: columns.leading) { primary() }
                        .accessibilityIdentifier("keepfit.overview")
                    pane(width: max(0, contentWidth - columns.leading - columns.gap)) { secondary() }
                        .accessibilityIdentifier("keepfit.records")
                }
                .padding(.horizontal, 16)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: spacing) {
                        primary()
                        secondary()
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 18)
                    .frame(width: contentWidth, alignment: .topLeading)
                }
                .padding(.horizontal, 16)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.immediately)
                .environment(\.keepFitPageWidth, contentWidth)
                .accessibilityIdentifier("keepfit.singleColumn")
            }
        }
    }

    private func pane<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: spacing) {
                content()
            }
            .padding(.top, 8)
            .padding(.bottom, 18)
            .frame(width: width, alignment: .topLeading)
        }
        .frame(width: width)
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .environment(\.keepFitPageWidth, width)
    }
}

struct KeepFitPageWidthReader<Content: View>: View {
    @Environment(\.keepFitPageWidth) private var width
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View { content(width) }
}

struct KeepFitRingSizing: ViewModifier {
    @Environment(\.keepFitPageWidth) private var pageWidth
    let preferredSize: CGFloat

    func body(content: Content) -> some View {
        let size = min(preferredSize, max(0, pageWidth - 52))
        content.frame(width: size, height: size)
    }
}
