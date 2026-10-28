import XCTest
@testable import KeepFit

@MainActor final class MealImportTests: XCTestCase {
    func record(status: String = "confirmed", valid: Bool = true) -> ModelMealRecord {
        let n = MealNutrition(caloriesKcal: 130, proteinG: 2.69, fatG: 0.28, carbsG: 28.17)
        let item = ModelMealItem(id: "rice", name: "熟米饭", originalPortion: "半碗", consumedGrams: valid ? 100 : nil, portionIsEstimate: true, nutritionBasis: "food_database", nutritionSource: nil, nutrientsPer100G: n, nutrients: n, includedInTotals: true, estimationNotes: ["半碗按100g估计"])
        let d = ModelMealDraft(id: UUID().uuidString, revision: 2, status: status, originalText: "吃了半碗熟米饭", understanding: .init(mealTime: Date(), questions: [], warnings: []), items: [item], totals: n, totalsComplete: true, requiresEstimateAcceptance: true, recordId: nil, model: .init(provider: "test", baseModel: "contract-test", simulated: false, nutritionVersion: "test-v1"))
        return .init(id: UUID().uuidString, acceptedEstimates: true, snapshot: d)
    }
    func testConfirmedMealIsSavedOnceAndPreservesProvenance() throws {
        let state = AppState(); let before = state.foodLogs.count; let r = record()
        try state.importModelMeal(r); try state.importModelMeal(r)
        XCTAssertEqual(state.foodLogs.count, before + 1)
        let log = try XCTUnwrap(state.foodLogs.first { $0.modelRecordID == r.id })
        XCTAssertEqual(log.originalPortion, "半碗"); XCTAssertEqual(log.originalMealText, r.snapshot.originalText)
        XCTAssertEqual(log.calories, 130, accuracy: 0.01)
        XCTAssertEqual(state.foodLogs(on: Date()).filter { $0.modelRecordID == r.id }.count, 1)
        state.foodLogs.removeAll { $0.modelRecordID == r.id }
    }
    func testIncompleteAndUnconfirmedMealsCannotBePartiallyImported() throws {
        let state = AppState(); let before = state.foodLogs.count
        XCTAssertThrowsError(try state.importModelMeal(record(status: "needs_clarification")))
        XCTAssertThrowsError(try state.importModelMeal(record(valid: false)))
        XCTAssertEqual(state.foodLogs.count, before)
    }
    func testActualServerSnakeCaseNutrientKeyDecodes() throws {
        let payload = Data(#"{"id":"rice","name":"米饭","original_portion":"半碗","consumed_grams":100,"portion_is_estimate":true,"nutrition_basis":"food_database","nutrients_per_100g":{"calories_kcal":130,"protein_g":2.69,"fat_g":0.28,"carbs_g":28.17},"nutrients":{"calories_kcal":130,"protein_g":2.69,"fat_g":0.28,"carbs_g":28.17},"included_in_totals":true,"estimation_notes":[]}"#.utf8)
        let item = try MealModelClient.decoder.decode(ModelMealItem.self, from: payload)
        XCTAssertEqual(try XCTUnwrap(item.nutrientsPer100G).caloriesKcal, 130)
    }
    func testLegacyFoodLogStillDecodesWithoutModelFields() throws {
        let old = Data(#"{"id":"51155CD1-3ECF-4D86-B2C4-43A28EB322F0","date":"2026-10-23T12:00:00Z","foodID":"rice","foodName":"米饭","foodIcon":"🍚","weightGrams":100,"caloriesPer100g":130,"proteinPer100g":2.69,"carbsPer100g":28.17,"fatPer100g":0.28}"#.utf8)
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let log = try decoder.decode(FoodLog.self, from: old)
        XCTAssertNil(log.modelRecordID); XCTAssertEqual(log.calories, 130, accuracy: 0.01)
    }
}
