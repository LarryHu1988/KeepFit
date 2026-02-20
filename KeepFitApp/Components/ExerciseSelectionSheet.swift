import SwiftUI

struct ExerciseSelectionSheet: View {
    let items: [ExerciseItem]
    let iconForItem: (ExerciseItem) -> String
    let displayName: (ExerciseItem) -> String
    let onSelect: (ExerciseItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""

    private var filtered: [ExerciseItem] {
        if keyword.isEmpty { return items }
        return items.filter { item in
            let candidate = "\(item.name) \(displayName(item))"
            return candidate.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
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
                                            Text(displayName(item))
                                                .foregroundStyle(.primary)
                                            Text("MET \(String(format: "%.1f", item.met))")
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
            .searchable(text: $keyword, prompt: localized("搜索运动项目", "Search Exercise"))
            .navigationTitle(localized("选择运动", "Select Exercise"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("关闭", "Close")) { dismiss() }
                }
            }
        }
    }
}
