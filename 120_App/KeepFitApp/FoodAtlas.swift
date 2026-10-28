import Foundation

/// All four nutrients are expressed per `amount` of `unit`, never inferred from the food category.
struct FoodAtlasBasis: Codable, Hashable {
    var amount: Double
    var unit: String
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
    var gramsPerUnit: Double? = nil

    var isValid: Bool {
        amount.isFinite && amount > 0 && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && [calories, protein, fat, carbs].allSatisfy { $0.isFinite && $0 >= 0 }
            && (gramsPerUnit.map { $0.isFinite && $0 > 0 } ?? true)
            && (unit != "g" || gramsPerUnit == nil || gramsPerUnit == 1)
    }

    func nutrition(for quantity: Double) -> FoodAtlasNutrition {
        let factor = quantity / amount
        return FoodAtlasNutrition(calories: calories * factor, protein: protein * factor,
                                  fat: fat * factor, carbs: carbs * factor)
    }
}

struct FoodAtlasNutrition: Codable, Hashable {
    var calories: Double
    var protein: Double
    var fat: Double
    var carbs: Double
}

struct FoodAtlasEntry: Codable, Hashable {
    var id: String
    var name: String
    var nameEnglish: String?
    var icon: String
    var category: FoodCategory
    var aliases: [String]
    var basis: FoodAtlasBasis
    var sourceName: String
    var sourceURL: String?
    var commonFoodRank: Int? = nil
}

enum FoodSelectionCatalog {
    static let displayLimit = 100

    struct Result {
        let items: [FoodItem]
        let matchCount: Int
    }

    static func select(from items: [FoodItem], usageCounts: [String: Int], query: String,
                       displayName: (FoodItem) -> String) -> Result {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let ranked = items.enumerated().compactMap { index, item -> (FoodItem, Int, Int)? in
            guard !query.isEmpty else { return (item, 0, index) }
            let terms = [item.name, displayName(item)] + (item.aliases ?? [])
            guard terms.contains(where: { $0.localizedCaseInsensitiveContains(query) }) else { return nil }
            let exact = terms.contains { $0.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
            let prefix = terms.contains { $0.range(of: query, options: [.anchored, .caseInsensitive, .diacriticInsensitive]) != nil }
            return (item, exact ? 0 : (prefix ? 1 : 2), index)
        }.sorted { lhs, rhs in
            if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
            let leftUses = usageCounts[lhs.0.id, default: 0]
            let rightUses = usageCounts[rhs.0.id, default: 0]
            if leftUses != rightUses { return leftUses > rightUses }
            let leftRank = lhs.0.atlasEntry?.commonFoodRank ?? Int.max
            let rightRank = rhs.0.atlasEntry?.commonFoodRank ?? Int.max
            if leftRank != rightRank { return leftRank < rightRank }
            return lhs.2 < rhs.2
        }
        return Result(items: ranked.prefix(displayLimit).map { $0.0 }, matchCount: ranked.count)
    }
}

struct FoodAtlasDataset: Codable {
    var schemaVersion: Int
    var version: String
    var foods: [FoodAtlasEntry]

    func foodItems() throws -> [FoodItem] {
        guard schemaVersion == 1, !version.isEmpty, !foods.isEmpty,
              Set(foods.map(\.id)).count == foods.count,
              foods.allSatisfy({ !$0.id.isEmpty && !$0.name.isEmpty && $0.basis.isValid }) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return foods.map { entry in
            // Legacy gram-based parsing can only use entries with an explicit mass conversion.
            let grams = entry.basis.unit == "g" ? 1 : entry.basis.gramsPerUnit
            let per100g = grams.map { entry.basis.nutrition(for: 100 / $0) }
            return FoodItem(
                id: entry.id, name: entry.name, icon: entry.icon, category: entry.category,
                caloriesPer100g: per100g?.calories ?? 0, proteinPer100g: per100g?.protein ?? 0,
                carbsPer100g: per100g?.carbs ?? 0, fatPer100g: per100g?.fat ?? 0,
                aliases: entry.aliases + [entry.nameEnglish].compactMap { $0 },
                nutritionReference: FoodNutritionReference(
                    basis: .genericReference, sourceName: entry.sourceName,
                    sourceURLString: entry.sourceURL, referenceCode: entry.id,
                    noteZH: nil, noteEN: nil),
                atlasEntry: entry)
        }
    }
}

extension FoodItem {
    var entryBasis: FoodAtlasBasis {
        atlasEntry?.basis ?? FoodAtlasBasis(
            amount: 100, unit: IconCatalog.foodUnit(id: id, category: category).symbol,
            calories: caloriesPer100g, protein: proteinPer100g, fat: fatPer100g, carbs: carbsPer100g)
    }

    var supportsGramCalculation: Bool {
        atlasEntry == nil || atlasEntry?.basis.unit == "g" || atlasEntry?.basis.gramsPerUnit != nil
    }

    func log(date: Date, amount: Double) -> FoodLog? {
        let basis = entryBasis
        guard amount.isFinite, amount > 0, basis.isValid else { return nil }
        let nutrients = basis.nutrition(for: amount)
        guard [nutrients.calories, nutrients.protein, nutrients.fat, nutrients.carbs].allSatisfy(\.isFinite) else { return nil }
        let gramsPerUnit = basis.unit == "g" ? 1 : basis.gramsPerUnit
        let grams = gramsPerUnit.map { amount * $0 } ?? 0
        guard grams.isFinite else { return nil }
        var log = FoodLog(
            id: UUID(), date: date, foodID: id, foodName: name, foodIcon: icon,
            weightGrams: grams, caloriesPer100g: caloriesPer100g, proteinPer100g: proteinPer100g,
            carbsPer100g: carbsPer100g, fatPer100g: fatPer100g)
        log.recordedAmount = amount
        log.recordedUnit = basis.unit
        log.recordedNutrition = nutrients
        log.foodReference = nutritionReference
        return log
    }
}
