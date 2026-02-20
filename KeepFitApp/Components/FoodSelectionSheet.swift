import SwiftUI

struct FoodSelectionSheet: View {
    let items: [FoodItem]
    let iconForItem: (FoodItem) -> String
    let onSelect: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @State private var keyword = ""

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

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
                                        AppIconBadge(icon: iconForItem(item), seed: item.id, size: 30)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name)
                                                .foregroundStyle(.primary)
                                            Text(
                                                "\(energyText(fromKcal: item.caloriesPer100g, includeUnit: true, unit: energyUnit))/100\(IconCatalog.foodUnit(id: item.id, category: item.category).symbol)"
                                            )
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
            .searchable(text: $keyword, prompt: localized("搜索食物", "Search Food"))
            .navigationTitle(localized("选择食物", "Select Food"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("关闭", "Close")) { dismiss() }
                }
            }
        }
    }
}
