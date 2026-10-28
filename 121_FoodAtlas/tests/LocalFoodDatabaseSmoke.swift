import Foundation

@main
struct FoodDatabaseSmoke {
    static func main() throws {
        let database = try LocalFoodDatabase(url: URL(fileURLWithPath: CommandLine.arguments[1]))
        let foods = try database.search("水煮鸡蛋")
        guard let egg = foods.first, egg.id == "usda:173424" else {
            fatalError("Expected exact cooked egg match")
        }
        let portions = try database.portions(for: egg.id)
        guard portions.contains(where: { $0.grams == 100 }),
              portions.contains(where: { abs($0.gramsPerUnit - 50) < 0.001 }) else {
            fatalError("Expected 100g basis and official 50g egg portion")
        }
        guard try database.search("% OR 1=1").isEmpty else {
            fatalError("Search must bind literal input")
        }
        print("Swift SQLite smoke passed: \(egg.name), \(portions.count) portions")
    }
}
