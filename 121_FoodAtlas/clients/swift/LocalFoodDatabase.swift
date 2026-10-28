import Foundation
import SQLite3

/// Read-only client for the commercial KeepFitFoods.sqlite export (schema v1).
final class LocalFoodDatabase {
    struct Food: Identifiable {
        let id: String
        let name: String
        let nameEnglish: String?
        let caloriesPer100g: Double?
        let proteinPer100g: Double?
        let fatPer100g: Double?
        let carbsPer100g: Double?
        let sourceURL: URL?
    }

    struct Portion: Identifiable {
        let id: String
        let label: String
        let amount: Double
        let unit: String
        let grams: Double
        let calories: Double?
        let protein: Double?
        let fat: Double?
        let carbs: Double?

        var gramsPerUnit: Double { grams / amount }
        var caloriesPerUnit: Double? { calories.map { $0 / amount } }
        var proteinPerUnit: Double? { protein.map { $0 / amount } }
        var fatPerUnit: Double? { fat.map { $0 / amount } }
        var carbsPerUnit: Double? { carbs.map { $0 / amount } }
    }

    enum DatabaseError: Error {
        case sqlite(String)
        case unsupportedSchema
    }

    private var database: OpaquePointer?
    private let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(url: URL) throws {
        let status = sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil)
        guard status == SQLITE_OK else {
            let message = database.map { String(cString: sqlite3_errmsg($0)) } ?? "Cannot open food database"
            sqlite3_close(database)
            database = nil
            throw DatabaseError.sqlite(message)
        }
        do {
            let statement = try prepare("PRAGMA user_version")
            defer { sqlite3_finalize(statement) }
            guard sqlite3_step(statement) == SQLITE_ROW, sqlite3_column_int(statement, 0) == 1 else {
                throw DatabaseError.unsupportedSchema
            }
        } catch {
            sqlite3_close(database)
            database = nil
            throw error
        }
    }

    deinit { sqlite3_close(database) }

    func search(_ query: String, limit: Int = 20) throws -> [Food] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let escaped = query.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        let pattern = "%\(escaped)%"
        let statement = try prepare(#"""
            SELECT f.id, COALESCE(f.name_zh,f.name), f.name_en,
              f.calories_kcal,f.protein_g,f.fat_g,f.carbs_g,f.source_url
            FROM commercial_foods f
            WHERE f.name LIKE ? ESCAPE '\' OR f.name_zh LIKE ? ESCAPE '\'
              OR f.name_en LIKE ? ESCAPE '\'
              OR EXISTS (SELECT 1 FROM aliases a WHERE a.food_id=f.id AND a.alias LIKE ? ESCAPE '\')
            ORDER BY CASE WHEN f.name=? OR f.name_zh=? OR f.name_en=? THEN 0
              WHEN EXISTS (SELECT 1 FROM aliases a WHERE a.food_id=f.id AND a.alias=?) THEN 1 ELSE 2 END,
              CASE f.source_id WHEN 'usda-foundation' THEN 0 WHEN 'usda-sr-legacy' THEN 1 ELSE 2 END,
              f.name LIMIT ?
            """#)
        defer { sqlite3_finalize(statement) }
        for (offset, value) in [pattern, pattern, pattern, pattern, query, query, query, query].enumerated() {
            try bind(value, to: statement, index: Int32(offset + 1))
        }
        sqlite3_bind_int(statement, 9, Int32(max(1, min(limit, 100))))
        var foods: [Food] = []
        while try step(statement) {
            foods.append(Food(id: string(statement, 0)!, name: string(statement, 1)!,
                nameEnglish: string(statement, 2), caloriesPer100g: number(statement, 3),
                proteinPer100g: number(statement, 4), fatPer100g: number(statement, 5),
                carbsPer100g: number(statement, 6), sourceURL: string(statement, 7).flatMap(URL.init(string:))))
        }
        return foods
    }

    func portions(for foodID: String) throws -> [Portion] {
        let statement = try prepare("""
            SELECT portion_id,label,amount,unit,gram_weight,calories_kcal,protein_g,fat_g,carbs_g
            FROM portion_nutrition WHERE food_id=? AND commercial_use_authorized=1 ORDER BY portion_id
            """)
        defer { sqlite3_finalize(statement) }
        try bind(foodID, to: statement, index: 1)
        var portions: [Portion] = []
        while try step(statement) {
            portions.append(Portion(id: string(statement, 0)!, label: string(statement, 1)!,
                amount: sqlite3_column_double(statement, 2), unit: string(statement, 3)!,
                grams: sqlite3_column_double(statement, 4), calories: number(statement, 5),
                protein: number(statement, 6), fat: number(statement, 7), carbs: number(statement, 8)))
        }
        return portions
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return statement
    }

    private func bind(_ value: String, to statement: OpaquePointer, index: Int32) throws {
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
    }

    private func step(_ statement: OpaquePointer) throws -> Bool {
        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW || result == SQLITE_DONE else {
            throw DatabaseError.sqlite(String(cString: sqlite3_errmsg(database)))
        }
        return result == SQLITE_ROW
    }

    private func string(_ statement: OpaquePointer, _ column: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, column) else { return nil }
        return String(cString: text)
    }

    private func number(_ statement: OpaquePointer, _ column: Int32) -> Double? {
        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : sqlite3_column_double(statement, column)
    }
}
