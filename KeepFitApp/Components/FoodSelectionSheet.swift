import SwiftUI

struct FoodSelectionSheet: View {
    let items: [FoodItem]
    let iconForItem: (FoodItem) -> String
    let displayName: (FoodItem) -> String
    let onSelect: (FoodItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("keepfit.unit.energy") private var energyUnitRaw = EnergyUnitOption.kcal.rawValue
    @State private var keyword = ""

    private var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: energyUnitRaw) ?? .kcal
    }

    private var filtered: [FoodItem] {
        if keyword.isEmpty { return items }
        return items.filter { item in
            let candidate = ([item.name, displayName(item)] + (item.aliases ?? []))
                .joined(separator: " ")
            return candidate.localizedCaseInsensitiveContains(keyword)
        }
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
                                    KeepFitHaptics.selection()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        AppIconBadge(icon: iconForItem(item), seed: item.id, size: 30)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(displayName(item))
                                                .foregroundStyle(.primary)
                                            Text(
                                                "\(energyText(fromKcal: item.caloriesPer100g, includeUnit: true, unit: energyUnit))/100\(IconCatalog.foodUnit(id: item.id, category: item.category).symbol)"
                                            )
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if let reference = item.nutritionReference {
                                                Label(
                                                    reference.basis.title,
                                                    systemImage: reference.basis == .recipeEstimate
                                                        ? "exclamationmark.triangle"
                                                        : "checkmark.seal"
                                                )
                                                .font(.caption2)
                                                .foregroundStyle(
                                                    reference.basis == .recipeEstimate
                                                        ? Color.orange
                                                        : Color.green
                                                )
                                            }
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
                    Button(localized("关闭", "Close")) {
                        KeepFitHaptics.impact(.light)
                        dismiss()
                    }
                }
            }
        }
    }
}
