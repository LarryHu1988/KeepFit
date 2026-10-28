import SwiftUI

struct ExerciseSelectionSheet: View {
    let items: [ExerciseItem]
    let iconForItem: (ExerciseItem) -> String
    let displayName: (ExerciseItem) -> String
    let onSelect: (ExerciseItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var keyword = ""

    private var filtered: [ExerciseItem] {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty { return items }
        return items.filter { item in
            let candidate = "\(item.name) \(displayName(item)) \(englishDisplayName(from: item.id))"
            return candidate.localizedCaseInsensitiveContains(keyword)
        }
    }

    var body: some View {
        let matches = filtered
        let groups = Dictionary(grouping: matches, by: \.category)
        NavigationStack {
            List {
                ForEach(ExerciseCategory.allCases, id: \.self) { category in
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
                                .accessibilityIdentifier("exercise.choice." + item.id)
                            }
                        }
                    }
                }
            }
            .overlay {
                if matches.isEmpty {
                    ContentUnavailableView.search(text: keyword)
                }
            }
            .searchable(text: $keyword, placement: .navigationBarDrawer(displayMode: .always), prompt: localized("搜索运动项目", "Search Exercise"))
            .navigationTitle(localized("选择运动", "Select Exercise"))
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
