import SwiftUI

struct FoodSelectionSheet: View {
    let items: [FoodItem]
    var usageCounts: [String: Int] = [:]
    let iconForItem: (FoodItem) -> String
    let displayName: (FoodItem) -> String
    let onSelect: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""

    var body: some View {
        let result = FoodSelectionCatalog.select(from: items, usageCounts: usageCounts,
                                                query: keyword, displayName: displayName)
        let visible = result.items
        let groups = Dictionary(grouping: visible, by: \.category)
        NavigationStack {
            List {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    let categoryItems = groups[category] ?? []
                    if !categoryItems.isEmpty {
                        Section(category.title) {
                            ForEach(categoryItems) { item in
                                Button {
                                    KeepFitHaptics.selection()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        AppIconBadge(icon: iconForItem(item), seed: item.id, size: 30)
                                        Text(displayName(item))
                                            .foregroundStyle(.primary)
                                        Spacer()
                                    }
                                }
                                .accessibilityIdentifier("food.choice." + item.id)
                            }
                        }
                    }
                }
                if !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   result.matchCount > visible.count {
                    Text(localized("显示前 100 项，请进一步搜索。", "Showing the first 100 results. Refine your search."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if visible.isEmpty {
                    ContentUnavailableView.search(text: keyword)
                }
            }
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: localized("搜索食物", "Search Food"))
            .navigationTitle(localized("选择食物", "Select Food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("关闭", "Close")) {
                        KeepFitHaptics.impact(.light)
                        dismiss()
                    }
                }
            }
        }
    }
}
