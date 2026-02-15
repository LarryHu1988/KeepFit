import SwiftUI

struct FoodSelectionSheet: View {
    let items: [FoodItem]
    let onSelect: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""

    private var filtered: [FoodItem] {
        if keyword.isEmpty { return items }
        return items.filter { $0.name.localizedCaseInsensitiveContains(keyword) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    let categoryItems = filtered.filter { $0.category == category }
                    if !categoryItems.isEmpty {
                        Section(category.title) {
                            ForEach(categoryItems) { item in
                                Button {
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: item.icon)
                                            .foregroundStyle(.orange)
                                            .frame(width: 22)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .foregroundStyle(.primary)
                                            Text("\(Int(item.caloriesPer100g)) kcal/100g")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $keyword, prompt: "搜索食物")
            .navigationTitle("选择食物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
