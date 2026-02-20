import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var pageIndex = 0

    private let pages = GuidePage.samples

    private var activePage: GuidePage {
        pages[pageIndex]
    }

    private var isLastPage: Bool {
        pageIndex == pages.count - 1
    }

    var body: some View {
        ZStack {
            GrowPageBackground(accent: activePage.accent)

            VStack(spacing: 16) {
                headerBar

                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        onboardingPage(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomControls
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.42), lineWidth: 0.8)
                        )
                        .frame(width: 34, height: 34)
                    TripleThemeRingsView(progress: (0.88, 0.72, 0.62), lineWidth: 4, size: 24)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("KeepFit")
                        .font(.subheadline.weight(.semibold))
                    Text(localized("管住嘴迈开腿", "Eat Well · Move More"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(localized("跳过", "Skip")) {
                KeepFitHaptics.selection()
                onFinish()
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
        }
    }

    private func onboardingPage(_ page: GuidePage) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            showcaseCard(page)

            VStack(alignment: .leading, spacing: 6) {
                Text(localized(page.titleCN, page.titleEN))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(localized(page.subtitleCN, page.subtitleEN))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            featureRows(page)
        }
    }

    private func showcaseCard(_ page: GuidePage) -> some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [page.accent.opacity(0.18), .white.opacity(0.08), page.accent.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(.white.opacity(0.46), lineWidth: 1)
                )
                .shadow(color: page.accent.opacity(0.20), radius: 16, x: 0, y: 10)

            Capsule(style: .continuous)
                .fill(.black.opacity(0.84))
                .frame(width: 110, height: 24)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                mockTopBar(page)
                mockWeekStrip(page)
                progressPreviewCard(page)
                secondaryPreviewCard(page)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)
            .padding(.bottom, 14)
        }
        .frame(height: 370)
    }

    private func mockTopBar(_ page: GuidePage) -> some View {
        HStack {
            Text(localized(page.previewTitleCN, page.previewTitleEN))
                .font(.headline.weight(.semibold))
            Spacer()
            Text("12:29")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Image(systemName: "gearshape.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func mockWeekStrip(_ page: GuidePage) -> some View {
        let cn = ["一", "二", "三", "四", "五", "六", "日"]
        let en = ["M", "T", "W", "T", "F", "S", "S"]
        return HStack(spacing: 7) {
            ForEach(0..<7, id: \.self) { idx in
                let selected = idx == page.selectedWeekDay
                VStack(spacing: 3) {
                    Text(AppPreferences.language == .english ? en[idx] : cn[idx])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(selected ? .primary : .secondary)
                    Circle()
                        .fill(selected ? page.dotColor : .secondary.opacity(0.25))
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(selected ? page.accent.opacity(0.16) : .clear)
                )
            }
        }
    }

    private func progressPreviewCard(_ page: GuidePage) -> some View {
        previewCard(accent: page.accent) {
            HStack(spacing: 12) {
                MiniProgressRing(
                    progress: page.ringProgress,
                    color: page.accent,
                    size: 92,
                    lineWidth: 13,
                    title: localized(page.ringTitleCN, page.ringTitleEN),
                    value: page.ringValue,
                    unit: page.ringUnit
                )

                VStack(alignment: .leading, spacing: 7) {
                    ForEach(page.metrics) { metric in
                        HStack(spacing: 8) {
                            Image(systemName: metric.icon)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(metric.color)
                                .frame(width: 12)
                            Text(localized(metric.nameCN, metric.nameEN))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 6)
                            Text(metric.value)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }

                    Text(localized(page.tipCN, page.tipEN))
                        .font(.caption2)
                        .foregroundStyle(page.tipColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 1)
                }
            }
        }
    }

    @ViewBuilder
    private func secondaryPreviewCard(_ page: GuidePage) -> some View {
        switch page.kind {
        case .eat, .move:
            previewCard(accent: page.accent.opacity(0.85)) {
                VStack(spacing: 8) {
                    HStack(spacing: 7) {
                        compactField(page.quickTime, width: 56)
                        compactField(localized(page.quickItemCN, page.quickItemEN), width: 132)
                        compactField(page.quickValue, width: 62)
                        Button {
                            KeepFitHaptics.selection()
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.weight(.bold))
                                .frame(width: 26, height: 26)
                                .foregroundStyle(.white)
                                .background(page.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 8) {
                        Image(systemName: page.logIcon)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(page.accent)
                        Text(localized(page.logCN, page.logEN))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(page.logValue)
                            .font(.caption2.weight(.semibold))
                    }
                }
            }
        case .lose:
            previewCard(accent: page.accent.opacity(0.85)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(localized("热量趋势", "Calorie Trend"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ZStack {
                        deficitBars
                        trendLine(points: [1100, 1240, 1320, 1260, 1380, 1420, 1360], color: .orange)
                        trendLine(points: [980, 1120, 1180, 1300, 1260, 1410, 1490], color: .green)
                    }
                    .frame(height: 48)

                    HStack(spacing: 12) {
                        legendDot(color: .orange, text: localized("饮食摄入", "Food Intake"))
                        legendDot(color: .green, text: localized("运动支出", "Exercise Burn"))
                        legendDot(color: .red, text: localized("热量赤字", "Calorie Deficit"))
                    }
                }
            }
        }
    }

    private var deficitBars: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach([10.0, 6, 11, 4, 12, 8, 7], id: \.self) { value in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(value >= 8 ? Color.green.opacity(0.35) : Color.red.opacity(0.30))
                    .frame(width: 8, height: CGFloat(value) + 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func trendLine(points: [Double], color: Color) -> some View {
        GeometryReader { proxy in
            let maxValue = points.max() ?? 1
            let minValue = points.min() ?? 0
            let range = max(maxValue - minValue, 1)
            let stepX = points.count > 1 ? proxy.size.width / CGFloat(points.count - 1) : 0

            Path { path in
                for (index, value) in points.enumerated() {
                    let x = CGFloat(index) * stepX
                    let normalized = (value - minValue) / range
                    let y = proxy.size.height - CGFloat(normalized) * (proxy.size.height - 4) - 2
                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

            ForEach(Array(points.enumerated()), id: \.offset) { index, value in
                let x = CGFloat(index) * stepX
                let normalized = (value - minValue) / range
                let y = proxy.size.height - CGFloat(normalized) * (proxy.size.height - 4) - 2
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .position(x: x, y: y)
            }
        }
    }

    private func legendDot(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func compactField(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(width: width, height: 26)
            .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func previewCard<Content: View>(accent: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.14), .white.opacity(0.08), .clear],
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

    private func featureRows(_ page: GuidePage) -> some View {
        VStack(spacing: 8) {
            ForEach(page.highlights) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(page.accent)
                        .frame(width: 14)
                    Text(localized(item.titleCN, item.titleEN))
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(page.accent.opacity(0.10))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.26), lineWidth: 0.8)
                        )
                )
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == pageIndex ? pages[index].accent : Color.secondary.opacity(0.22))
                        .frame(width: index == pageIndex ? 28 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.22), value: pageIndex)
                }
            }
            .frame(height: 10)

            Button {
                KeepFitHaptics.selection()
                if isLastPage {
                    onFinish()
                } else {
                    withAnimation(.spring(duration: 0.4)) {
                        pageIndex += 1
                    }
                }
            } label: {
                Text(isLastPage ? localized("开始使用", "Start") : localized("下一步", "Next"))
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [activePage.accent, activePage.accent.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.26), lineWidth: 1)
            )
            .shadow(color: activePage.accent.opacity(0.28), radius: 10, x: 0, y: 6)
        }
    }
}

private struct GuidePage: Identifiable {
    enum Kind {
        case eat
        case move
        case lose
    }

    let id = UUID()
    let kind: Kind
    let titleCN: String
    let titleEN: String
    let subtitleCN: String
    let subtitleEN: String
    let previewTitleCN: String
    let previewTitleEN: String
    let accent: Color
    let dotColor: Color
    let selectedWeekDay: Int
    let ringProgress: Double
    let ringTitleCN: String
    let ringTitleEN: String
    let ringValue: String
    let ringUnit: String
    let metrics: [GuideMetric]
    let tipCN: String
    let tipEN: String
    let tipColor: Color
    let quickTime: String
    let quickItemCN: String
    let quickItemEN: String
    let quickValue: String
    let logIcon: String
    let logCN: String
    let logEN: String
    let logValue: String
    let highlights: [GuideHighlight]

    static let samples: [GuidePage] = [
        .init(
            kind: .eat,
            titleCN: "管住嘴",
            titleEN: "Eat Well",
            subtitleCN: "记录饮食、自动换算热量并分析营养结构。",
            subtitleEN: "Track meals, auto-convert calories, and analyze nutrition.",
            previewTitleCN: "今日饮食",
            previewTitleEN: "Today Intake",
            accent: Color(red: 0.98, green: 0.54, blue: 0.22),
            dotColor: .red,
            selectedWeekDay: 3,
            ringProgress: 0.62,
            ringTitleCN: "剩余",
            ringTitleEN: "Left",
            ringValue: "1370",
            ringUnit: "kcal",
            metrics: [
                .init(icon: "flame.fill", nameCN: "摄入", nameEN: "Intake", value: "417 kcal", color: .orange),
                .init(icon: "bolt.fill", nameCN: "蛋白", nameEN: "Protein", value: "42 g", color: .pink),
                .init(icon: "drop.fill", nameCN: "水分", nameEN: "Hydration", value: "1200 ml", color: .blue)
            ],
            tipCN: "建议下一餐优先补充优质蛋白与蔬菜。",
            tipEN: "Next meal: prioritize quality protein and vegetables.",
            tipColor: .green,
            quickTime: "12:20",
            quickItemCN: "鸡胸沙拉",
            quickItemEN: "Chicken Salad",
            quickValue: "180 g",
            logIcon: "fork.knife",
            logCN: "午餐已记录 · 417 kcal",
            logEN: "Lunch logged · 417 kcal",
            logValue: "OK",
            highlights: [
                .init(icon: "list.bullet.rectangle", titleCN: "食材库快速选择", titleEN: "Fast Food Library"),
                .init(icon: "function", titleCN: "自动换算热量", titleEN: "Auto Calorie Conversion"),
                .init(icon: "chart.pie", titleCN: "营养结构建议", titleEN: "Macro Suggestions")
            ]
        ),
        .init(
            kind: .move,
            titleCN: "迈开腿",
            titleEN: "Move More",
            subtitleCN: "记录锻炼、计算消耗并追踪每日活动目标。",
            subtitleEN: "Log workouts, estimate burn, and track daily goals.",
            previewTitleCN: "今日运动",
            previewTitleEN: "Today Workout",
            accent: Color(red: 0.18, green: 0.78, blue: 0.39),
            dotColor: .green,
            selectedWeekDay: 4,
            ringProgress: 0.95,
            ringTitleCN: "达成",
            ringTitleEN: "Done",
            ringValue: "305",
            ringUnit: "kcal",
            metrics: [
                .init(icon: "flame.fill", nameCN: "消耗", nameEN: "Burn", value: "305 kcal", color: .green),
                .init(icon: "clock.fill", nameCN: "时长", nameEN: "Duration", value: "60 min", color: .blue),
                .init(icon: "target", nameCN: "目标", nameEN: "Goal", value: "300 kcal", color: .mint)
            ],
            tipCN: "今日运动目标已达成，建议拉伸放松。",
            tipEN: "Goal reached today. Add a stretch cooldown.",
            tipColor: .green,
            quickTime: "19:00",
            quickItemCN: "慢跑",
            quickItemEN: "Jogging",
            quickValue: "35 min",
            logIcon: "figure.run",
            logCN: "晚间慢跑 · 186 kcal",
            logEN: "Evening jog · 186 kcal",
            logValue: "Done",
            highlights: [
                .init(icon: "figure.mixed.cardio", titleCN: "运动项目库", titleEN: "Workout Library"),
                .init(icon: "flame", titleCN: "自动估算消耗", titleEN: "Auto Burn Estimate"),
                .init(icon: "calendar.badge.clock", titleCN: "历史训练追踪", titleEN: "Training History")
            ]
        ),
        .init(
            kind: .lose,
            titleCN: "减个肥",
            titleEN: "Lose Weight",
            subtitleCN: "综合摄入与消耗，查看赤字日历与长期趋势。",
            subtitleEN: "Balance intake and burn with deficit calendar and trends.",
            previewTitleCN: "综合热量",
            previewTitleEN: "Energy Balance",
            accent: Color(red: 0.24, green: 0.60, blue: 1.00),
            dotColor: .green,
            selectedWeekDay: 2,
            ringProgress: 0.78,
            ringTitleCN: "赤字",
            ringTitleEN: "Deficit",
            ringValue: "-430",
            ringUnit: "kcal",
            metrics: [
                .init(icon: "fork.knife", nameCN: "摄入", nameEN: "Intake", value: "1680 kcal", color: .orange),
                .init(icon: "figure.run", nameCN: "支出", nameEN: "Burn", value: "2110 kcal", color: .green),
                .init(icon: "chart.bar.fill", nameCN: "净差", nameEN: "Net", value: "-430 kcal", color: .blue)
            ],
            tipCN: "本周已连续 4 天达成赤字。",
            tipEN: "Deficit achieved on 4 straight days this week.",
            tipColor: .green,
            quickTime: "20:30",
            quickItemCN: "体重记录",
            quickItemEN: "Weight Log",
            quickValue: "66.4 kg",
            logIcon: "calendar",
            logCN: "赤字日历与趋势联动",
            logEN: "Calendar and trends linked",
            logValue: "Sync",
            highlights: [
                .init(icon: "calendar", titleCN: "赤字日历联动", titleEN: "Deficit Calendar"),
                .init(icon: "chart.line.uptrend.xyaxis", titleCN: "热量趋势分析", titleEN: "Calorie Trends"),
                .init(icon: "scalemass", titleCN: "体重体脂追踪", titleEN: "Weight & Fat Tracking")
            ]
        )
    ]
}

private struct GuideMetric: Identifiable {
    let id = UUID()
    let icon: String
    let nameCN: String
    let nameEN: String
    let value: String
    let color: Color
}

private struct GuideHighlight: Identifiable {
    let id = UUID()
    let icon: String
    let titleCN: String
    let titleEN: String
}

struct TripleThemeRingsView: View {
    let progress: (Double, Double, Double)
    let lineWidth: CGFloat
    let size: CGFloat

    var body: some View {
        ZStack {
            ring(radiusRatio: 0.50, progress: progress.0, color: .orange)
            ring(radiusRatio: 0.37, progress: progress.1, color: .green)
            ring(radiusRatio: 0.24, progress: progress.2, color: .blue)
        }
        .frame(width: size, height: size)
    }

    private func ring(radiusRatio: CGFloat, progress: Double, color: Color) -> some View {
        Circle()
            .stroke(color.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .overlay(
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(
                        LinearGradient(
                            colors: [color.opacity(0.80), color],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .shadow(color: color.opacity(0.26), radius: 3, x: 0, y: 1)
            )
            .frame(width: size * radiusRatio * 2, height: size * radiusRatio * 2)
    }
}

private struct MiniProgressRing: View {
    let progress: Double
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let title: String
    let value: String
    let unit: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    OnboardingView {}
}
