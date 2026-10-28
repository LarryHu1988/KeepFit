import SwiftUI

struct MoreAppsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(localized("来自 Larry Hu 的更多作品", "More from Larry Hu"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                appCard(
                    icon: "SimpleWorthBrandIcon",
                    name: localized("简值 · SimpleWorth", "SimpleWorth · 简值"),
                    platform: "iPhone · iPad / iOS 17+",
                    description: localized(
                        "记得简单，心里有数。轻松记录收支，用分类与标签理清账目，跟踪储蓄目标，看见日常的消费趋势。",
                        "Simple everyday bookkeeping. Organize income and expenses with categories and tags, track savings goals, and explore spending trends."
                    ),
                    store: AppLinks.simpleWorthStore,
                    home: AppLinks.simpleWorthHome,
                    accent: .blue
                )
                appCard(
                    icon: "PDFLibrarianBrandIcon",
                    name: "PDF Librarian",
                    platform: "Mac / macOS 13+",
                    description: localized(
                        "给 PDF 一份清楚的书目。检索并核对图书与论文元数据，编辑 Dublin Core 字段，按规则保存与重命名，让资料库更有序。",
                        "Bring order to your PDF library. Find and review book and research metadata, edit Dublin Core fields, and save and rename files with clear rules."
                    ),
                    store: AppLinks.pdfLibrarianStore,
                    home: AppLinks.pdfLibrarianHome,
                    accent: .orange
                )
            }
            .frame(maxWidth: 680)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .background { GrowPageBackground(accent: .blue) }
        .navigationTitle(localized("更多 APP", "More Apps"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func appCard(icon: String, name: String, platform: String, description: String,
                         store: URL, home: URL, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(name).font(.title3.bold())
                    Text(platform).font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Text(description)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { appLinks(store: store, home: home, accent: accent, identifier: icon) }
                VStack(alignment: .leading, spacing: 12) { appLinks(store: store, home: home, accent: accent, identifier: icon) }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder private func appLinks(store: URL, home: URL, accent: Color, identifier: String) -> some View {
        Link(destination: store) {
            Label("App Store", systemImage: "arrow.up.right")
        }
        .accessibilityIdentifier(identifier + "-store")
        .buttonStyle(.borderedProminent)
        .tint(accent)
        Link(destination: home) {
            Label(localized("访问主页", "Website"), systemImage: "globe")
        }
        .accessibilityIdentifier(identifier + "-home")
        .buttonStyle(.bordered)
        .tint(accent)
    }
}
