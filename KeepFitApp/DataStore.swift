import Foundation

enum DataFile: String, CaseIterable {
    case profile = "profile.json"
    case foods = "food_library.json"
    case exercises = "exercise_library.json"
    case foodLogs = "food_logs.json"
    case exerciseLogs = "exercise_logs.json"
    case bodyMetrics = "body_metrics.json"
}

final class DataStore {
    private let directoryURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init() {
        let fileManager = FileManager.default
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let bundleID = Bundle.main.bundleIdentifier ?? "KeepFit"
        directoryURL = supportURL.appendingPathComponent(bundleID, isDirectory: true)

        if !fileManager.fileExists(atPath: directoryURL.path) {
            try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load<T: Codable>(_ type: T.Type, for file: DataFile) -> T? {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    func save<T: Codable>(_ value: T, for file: DataFile) {
        let url = directoryURL.appendingPathComponent(file.rawValue)
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func latestModificationDate(for files: [DataFile] = DataFile.allCases) -> Date? {
        files.compactMap { file in
            let url = directoryURL.appendingPathComponent(file.rawValue)
            guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
                return nil
            }
            return values.contentModificationDate
        }
        .max()
    }
}

private struct BundledFoodCompositionDataset: Codable {
    let schemaVersion: Int
    let sourceName: String
    let sourceURLString: String?
    let referenceCode: String?
    let commercialUseAuthorized: Bool
    let noteZH: String?
    let noteEN: String?
    let foods: [FoodItem]
}

enum FoodCompositionDataLoader {
    private static let resourceName = "ChineseFoodCompositionLicensed"

    static func mergedFoodLibrary(with builtIn: [FoodItem], bundle: Bundle = .main) -> [FoodItem] {
        guard
            let url = bundle.url(forResource: resourceName, withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dataset = try? JSONDecoder().decode(BundledFoodCompositionDataset.self, from: data),
            dataset.schemaVersion == 1,
            dataset.commercialUseAuthorized
        else {
            return builtIn
        }

        let datasetReference = FoodNutritionReference(
            basis: .licensedChinaFoodComposition,
            sourceName: dataset.sourceName,
            sourceURLString: dataset.sourceURLString,
            referenceCode: dataset.referenceCode,
            noteZH: dataset.noteZH,
            noteEN: dataset.noteEN
        )

        let licensedFoods = dataset.foods.map { food in
            var resolved = food
            if resolved.nutritionReference == nil {
                resolved.nutritionReference = datasetReference
            }
            return resolved
        }

        var merged = builtIn
        var indexByID = Dictionary(uniqueKeysWithValues: merged.indices.map { (merged[$0].id, $0) })

        for food in licensedFoods {
            if let index = indexByID[food.id] {
                merged[index] = food
            } else {
                indexByID[food.id] = merged.count
                merged.append(food)
            }
        }

        return merged
    }
}
