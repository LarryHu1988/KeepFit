import XCTest
@testable import KeepFit

final class FoodAtlasTests: XCTestCase {
    func food(unit: String = "g", amount: Double = 100, gramsPerUnit: Double? = 1) throws -> FoodItem {
        let entry = FoodAtlasEntry(id: "custom:test", name: "测试食物", nameEnglish: "Test food", icon: "🥚",
            category: .protein, aliases: ["测试别名"],
            basis: FoodAtlasBasis(amount: amount, unit: unit, calories: 70, protein: 6, fat: 5, carbs: 1, gramsPerUnit: gramsPerUnit),
            sourceName: "测试来源", sourceURL: nil)
        return try FoodAtlasDataset(schemaVersion: 1, version: "test", foods: [entry]).foodItems()[0]
    }

    func testGramAmountScalesAllFourNutrients() throws {
        let item = try food()
        let log = try XCTUnwrap(item.log(date: Date(), amount: 250))
        XCTAssertEqual(log.weightGrams, 250)
        XCTAssertEqual(log.calories, 175)
        XCTAssertEqual(log.protein, 15)
        XCTAssertEqual(log.fat, 12.5)
        XCTAssertEqual(log.carbs, 2.5)
    }

    func testVolumeNeverAssumesDensityAndStillRecordsNutrition() throws {
        let item = try food(unit: "mL", gramsPerUnit: nil)
        XCTAssertFalse(item.supportsGramCalculation)
        let log = try XCTUnwrap(item.log(date: Date(), amount: 250))
        XCTAssertEqual(log.weightGrams, 0)
        XCTAssertEqual(log.recordedAmount, 250)
        XCTAssertEqual(log.recordedUnit, "mL")
        XCTAssertEqual(log.calories, 175)
        XCTAssertEqual(log.protein, 15)
    }

    func testCountFractionAndExplicitMassConversion() throws {
        let item = try food(unit: "个", amount: 1, gramsPerUnit: 50)
        let log = try XCTUnwrap(item.log(date: Date(), amount: 0.5))
        XCTAssertEqual(log.weightGrams, 25)
        XCTAssertEqual(log.calories, 35)
        XCTAssertEqual(log.recordedUnit, "个")
        XCTAssertEqual(item.caloriesPer100g, 140)
    }

    func testInvalidQuantitiesAndInvalidDatasetCannotBeSaved() throws {
        let item = try food()
        for amount: Double in [0, -1, .nan, .infinity] {
            XCTAssertNil(item.log(date: Date(), amount: amount))
        }
        var entry = try XCTUnwrap(item.atlasEntry)
        entry.basis.amount = 0
        XCTAssertThrowsError(try FoodAtlasDataset(schemaVersion: 1, version: "test", foods: [entry]).foodItems())
        entry.basis.amount = 100
        XCTAssertThrowsError(try FoodAtlasDataset(schemaVersion: 1, version: "test", foods: [entry, entry]).foodItems())
    }

    func testSnapshotRoundTripSurvivesCatalogChanges() throws {
        var item = try food(unit: "mL", gramsPerUnit: nil)
        let log = try XCTUnwrap(item.log(date: Date(), amount: 250))
        item.atlasEntry?.basis.unit = "杯"
        item.atlasEntry?.basis.calories = 999
        let saved = try JSONDecoder().decode(FoodLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(saved.recordedUnit, "mL")
        XCTAssertEqual(saved.recordedAmount, 250)
        XCTAssertEqual(saved.calories, 175)
        XCTAssertEqual(saved.foodReference?.sourceName, "测试来源")
    }

    func testProductionBundleActuallyLoadsAtlasInsteadOfFallback() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "KeepFitFoodAtlas", withExtension: "json"))
        let dataset = try JSONDecoder().decode(FoodAtlasDataset.self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(try dataset.foodItems().count, 13000)
        let food = try XCTUnwrap(SeedData.foodLibrary.first { $0.id == "usda:173424" })
        XCTAssertEqual(food.name, "水煮鸡蛋")
        XCTAssertEqual(food.entryBasis.unit, "g")
        XCTAssertEqual(food.entryBasis.calories, 155)
    }

    func testLegacyFoodLogStillDecodes() throws {
        let data = Data(#"{"id":"51155CD1-3ECF-4D86-B2C4-43A28EB322F0","date":0,"foodID":"rice","foodName":"米饭","foodIcon":"🍚","weightGrams":200,"caloriesPer100g":130,"proteinPer100g":2.69,"carbsPer100g":28.17,"fatPer100g":0.28}"#.utf8)
        let log = try JSONDecoder().decode(FoodLog.self, from: data)
        XCTAssertNil(log.recordedUnit)
        XCTAssertEqual(log.calories, 260)
    }

    func testDefaultSelectionContainsOneHundredCuratedFoods() throws {
        let library = SeedData.foodLibrary
        let curated = library.filter { $0.atlasEntry?.commonFoodRank != nil }
        XCTAssertEqual(curated.count, 100)
        let result = FoodSelectionCatalog.select(from: library, usageCounts: [:], query: "  ", displayName: { $0.name })
        XCTAssertEqual(result.items.count, 100)
        XCTAssertEqual(Set(result.items.map(\.id)), Set(curated.map(\.id)))
        XCTAssertEqual(result.items.first?.id, "usda:168878")
    }

    func testUsageFrequencyCanBringFoodOutsideStarterListIntoTopHundred() throws {
        let base = try food()
        let library = (0..<110).map { index in
            var item = base
            item.id = "custom:\(index)"
            item.atlasEntry?.commonFoodRank = index < 100 ? index : nil
            return item
        }
        let result = FoodSelectionCatalog.select(from: library,
            usageCounts: ["custom:109": 5, "custom:50": 2], query: "", displayName: { $0.name })
        XCTAssertEqual(result.items.count, 100)
        XCTAssertEqual(Array(result.items.prefix(2).map(\.id)), ["custom:109", "custom:50"])
        XCTAssertFalse(result.items.contains { $0.id == "custom:99" })
    }

    func testSearchUsesFullLibraryAndPrioritizesExactAliasBeforeLimit() throws {
        let base = try food()
        let library = (0..<110).map { index in
            var item = base
            item.id = "custom:\(index)"
            item.name = "Apple food \(index)"
            item.aliases = index == 109 ? ["apple"] : []
            item.atlasEntry?.commonFoodRank = index < 100 ? index : nil
            return item
        }
        let result = FoodSelectionCatalog.select(from: library, usageCounts: [:], query: " APPLE ", displayName: { $0.name })
        XCTAssertEqual(result.matchCount, 110)
        XCTAssertEqual(result.items.count, 100)
        XCTAssertEqual(result.items.first?.id, "custom:109")
    }
}
