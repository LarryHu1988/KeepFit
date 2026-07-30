import Foundation
import SwiftUI
import UIKit

private enum AppPreferenceKeys {
    static let timeFormat = "keepfit.unit.time"
    static let distanceUnit = "keepfit.unit.distance"
    static let energyUnit = "keepfit.unit.energy"
    static let heightUnit = "keepfit.unit.height"
    static let weightUnit = "keepfit.unit.weight"
    static let weekStart = "keepfit.calendar.weekStart"
    static let appLanguage = "keepfit.appLanguage"
}

enum TimeFormatOption: String, CaseIterable, Identifiable {
    case hour24
    case hour12

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hour24: return localized("24 小时制", "24-Hour")
        case .hour12: return localized("12 小时制", "12-Hour")
        }
    }
}

enum DistanceUnitOption: String, CaseIterable, Identifiable {
    case kilometer
    case mile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilometer: return localized("公里", "Kilometer")
        case .mile: return localized("英里", "Mile")
        }
    }

    var symbol: String {
        switch self {
        case .kilometer: return "km"
        case .mile: return "mi"
        }
    }
}

enum EnergyUnitOption: String, CaseIterable, Identifiable {
    case kcal
    case kJ

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kcal: return localized("千卡", "Kilocalorie")
        case .kJ: return localized("千焦", "Kilojoule")
        }
    }

    var symbol: String {
        switch self {
        case .kcal: return "kcal"
        case .kJ: return "kJ"
        }
    }

    func fromKcal(_ kcal: Double) -> Double {
        switch self {
        case .kcal: return kcal
        case .kJ: return kcal * 4.184
        }
    }

    func toKcal(_ value: Double) -> Double {
        switch self {
        case .kcal: return value
        case .kJ: return value / 4.184
        }
    }
}

enum HeightUnitOption: String, CaseIterable, Identifiable {
    case centimeter
    case foot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .centimeter: return localized("厘米", "Centimeter")
        case .foot: return localized("英尺", "Foot")
        }
    }

    var symbol: String {
        switch self {
        case .centimeter: return "cm"
        case .foot: return "ft"
        }
    }
}

enum WeightUnitOption: String, CaseIterable, Identifiable {
    case kilogram
    case pound

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilogram: return localized("公斤", "Kilogram")
        case .pound: return localized("磅", "Pound")
        }
    }

    var symbol: String {
        switch self {
        case .kilogram: return "kg"
        case .pound: return "lb"
        }
    }
}

enum WeekStartOption: String, CaseIterable, Identifiable {
    case sunday
    case monday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunday: return localized("星期日", "Sunday")
        case .monday: return localized("星期一", "Monday")
        }
    }

    var firstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        }
    }
}

enum AppLanguageOption: String, CaseIterable, Identifiable {
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chinese: return "中文"
        case .english: return "English"
        }
    }

    var flag: String {
        switch self {
        case .chinese: return "🇨🇳"
        case .english: return "🇺🇸"
        }
    }

    var localeIdentifier: String { rawValue }
}

enum AppPreferences {
    static var timeFormat: TimeFormatOption {
        .hour24
    }

    static var distanceUnit: DistanceUnitOption {
        DistanceUnitOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.distanceUnit) ?? "") ?? .kilometer
    }

    static var energyUnit: EnergyUnitOption {
        EnergyUnitOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.energyUnit) ?? "") ?? .kcal
    }

    static var heightUnit: HeightUnitOption {
        HeightUnitOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.heightUnit) ?? "") ?? .centimeter
    }

    static var weightUnit: WeightUnitOption {
        WeightUnitOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.weightUnit) ?? "") ?? .kilogram
    }

    static var weekStart: WeekStartOption {
        WeekStartOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.weekStart) ?? "") ?? .sunday
    }

    static var language: AppLanguageOption {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-keepfit-screenshot-language"), arguments.indices.contains(index + 1) {
            return AppLanguageOption(rawValue: arguments[index + 1]) ?? .chinese
        }
        return AppLanguageOption(rawValue: UserDefaults.standard.string(forKey: AppPreferenceKeys.appLanguage) ?? "") ?? .chinese
    }

    static var locale: Locale {
        Locale(identifier: language.localeIdentifier)
    }

    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = locale
        calendar.firstWeekday = weekStart.firstWeekday
        return calendar
    }
}

enum KeepFitScreenshotRoot: String {
    case main
    case settings
}

enum KeepFitScreenshotFocus: String {
    case eatLog = "eat-log"
    case eatNutrition = "eat-nutrition"
    case moveLog = "move-log"
    case moveGoal = "move-goal"
    case loseOverview = "lose-overview"
    case loseTrends = "lose-trends"
    case settingsData = "settings-data"
}

enum KeepFitScreenshotConfig {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-keepfit-screenshot-mode")
    }

    static var root: KeepFitScreenshotRoot {
        value(after: "-keepfit-screenshot-root")
            .flatMap(KeepFitScreenshotRoot.init(rawValue:)) ?? .main
    }

    static var selectedTab: String? {
        value(after: "-keepfit-selected-tab")
    }

    static var focus: KeepFitScreenshotFocus? {
        value(after: "-keepfit-screenshot-focus")
            .flatMap(KeepFitScreenshotFocus.init(rawValue:))
    }

    static var referenceDate: Date {
        if let raw = value(after: "-keepfit-screenshot-date") {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyy-MM-dd"
            if let date = formatter.date(from: raw) {
                return date
            }
        }
        return AppPreferences.calendar.date(from: DateComponents(year: 2026, month: 3, day: 21))
            ?? Date()
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else {
            return nil
        }
        return arguments[index + 1]
    }
}

func keepFitInitialSelectedDate() -> Date {
    if KeepFitScreenshotConfig.isEnabled {
        return KeepFitScreenshotConfig.referenceDate.startOfDayInCurrentCalendar
    }
    return Date().startOfDayInCurrentCalendar
}

struct DynamicDateFormatter {
    let builder: () -> DateFormatter

    func string(from date: Date) -> String {
        builder().string(from: date)
    }
}

extension Date {
    var startOfDayInCurrentCalendar: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeekInCurrentCalendar: Date {
        let calendar = AppPreferences.calendar
        let dayStart = calendar.startOfDay(for: self)
        let weekday = calendar.component(.weekday, from: dayStart)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: dayStart) ?? dayStart
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    var isFutureDayInCurrentCalendar: Bool {
        startOfDayInCurrentCalendar > Date().startOfDayInCurrentCalendar
    }
}

enum Formatters {
    static let dayAndTime: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        switch AppPreferences.timeFormat {
        case .hour24:
            formatter.setLocalizedDateFormatFromTemplate("MdHHmm")
        case .hour12:
            formatter.setLocalizedDateFormatFromTemplate("Mdhmma")
        }
        return formatter
    }

    static let monthDay: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }

    static let monthTitle: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }

    static let yearMonth: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("yMMM")
        return formatter
    }

    static let yearMonthDay: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("yMd")
        return formatter
    }

    static let weekDayShort: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("E")
        return formatter
    }

    static let hourMinute: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.dateFormat = AppPreferences.timeFormat == .hour24 ? "HH:mm" : "h:mm a"
        return formatter
    }

    static let trendDate: DynamicDateFormatter = .init {
        let formatter = DateFormatter()
        formatter.locale = AppPreferences.locale
        formatter.setLocalizedDateFormatFromTemplate("Md")
        return formatter
    }
}

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return localized("跟随系统", "System")
        case .light:
            return localized("浅色", "Light")
        case .dark:
            return localized("深色", "Dark")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

func rounded(_ value: Double, places: Int = 0) -> Double {
    let divisor = pow(10.0, Double(places))
    return (value * divisor).rounded() / divisor
}

func energyConvertedValue(fromKcal kcal: Double, unit: EnergyUnitOption = AppPreferences.energyUnit) -> Double {
    unit.fromKcal(kcal)
}

func energyText(fromKcal kcal: Double, decimals: Int = 0, signed: Bool = false, includeUnit: Bool = true, unit: EnergyUnitOption = AppPreferences.energyUnit) -> String {
    let value = energyConvertedValue(fromKcal: kcal, unit: unit)
    let display: String
    if decimals > 0 {
        display = String(format: "%.\(decimals)f", value)
    } else {
        display = String(Int(value.rounded()))
    }
    let withSign = signed && value > 0 ? "+\(display)" : display
    if includeUnit {
        return "\(withSign) \(unit.symbol)"
    }
    return withSign
}

func energyFromDisplayValue(_ value: Double, unit: EnergyUnitOption = AppPreferences.energyUnit) -> Double {
    unit.toKcal(value)
}

func weightDisplayValue(fromKg kg: Double, unit: WeightUnitOption = AppPreferences.weightUnit) -> Double {
    switch unit {
    case .kilogram: return kg
    case .pound: return kg * 2.20462
    }
}

func weightFromDisplayValue(_ value: Double, unit: WeightUnitOption = AppPreferences.weightUnit) -> Double {
    switch unit {
    case .kilogram: return value
    case .pound: return value / 2.20462
    }
}

func heightDisplayText(fromCm cm: Double, unit: HeightUnitOption = AppPreferences.heightUnit) -> String {
    switch unit {
    case .centimeter:
        return "\(Int(cm.rounded())) cm"
    case .foot:
        let totalInches = max(cm / 2.54, 0)
        var feet = Int(totalInches / 12)
        var inches = Int((totalInches - Double(feet * 12)).rounded())
        if inches == 12 {
            feet += 1
            inches = 0
        }
        return "\(feet) ft \(inches) in"
    }
}

func weightText(fromKg kg: Double, decimals: Int = 1, includeUnit: Bool = true, unit: WeightUnitOption = AppPreferences.weightUnit) -> String {
    let value = weightDisplayValue(fromKg: kg, unit: unit)
    let display = String(format: "%.\(decimals)f", value)
    if includeUnit {
        return "\(display) \(unit.symbol)"
    }
    return display
}

func durationDisplayText(fromMinutes minutes: Double, includeUnit: Bool = true) -> String {
    let display: String
    if abs(minutes.rounded() - minutes) < 0.05 {
        display = String(Int(minutes.rounded()))
    } else {
        display = String(format: "%.1f", minutes)
    }
    if includeUnit {
        return "\(display) min"
    }
    return display
}

func localized(_ chinese: String, _ english: String) -> String {
    AppPreferences.language == .english ? english : chinese
}

enum FoodTextParserError: LocalizedError {
    case emptyInput
    case foodNotRecognized

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return localized("请先输入进食内容。", "Enter what you ate first.")
        case .foodNotRecognized:
            return localized(
                "暂时没有识别出食物，请换一种说法或使用下方的手动记录。",
                "No food was recognized. Try different wording or use the manual entry below."
            )
        }
    }
}

enum FoodTextParser {
    private struct FoodMatch {
        let food: FoodItem
        let score: Int
    }

    private struct FoodMention {
        let food: FoodItem
        let score: Int
        let range: NSRange
    }

    private struct QuantityMatch {
        let grams: Double
        let description: String
        let estimated: Bool
        let score: Int
    }

    private static let compositeKeywordRules: [String: [[String]]] = [
        "pork_cabbage_dumpling": [["饺子", "水饺"], ["猪肉"], ["白菜"], ["馅"]],
        "chive_egg_dumpling": [["饺子", "水饺"], ["韭菜"], ["鸡蛋", "蛋"], ["馅"]],
        "pork_baozi": [["包子", "肉包"], ["猪肉", "鲜肉"], ["馅"]],
        "vegetable_baozi": [["包子", "菜包"], ["素馅", "菜馅", "蔬菜馅", "青菜馅"]],
        "pork_wonton_soup": [["馄饨", "云吞"], ["猪肉", "鲜肉"], ["馅"]],
        "pork_preserved_egg_congee": [["粥"], ["皮蛋"], ["瘦肉"]],
        "tomato_scrambled_egg": [["番茄", "西红柿"], ["鸡蛋", "炒蛋"], ["炒"]],
        "steamed_fish_cn": [["蒸鱼", "清蒸"], ["鱼", "鲈鱼"]]
    ]

    private static let compositeSuppressedFoodIDs: [String: Set<String>] = [
        "pork_cabbage_dumpling": ["dumpling", "pork_lean", "cabbage"],
        "chive_egg_dumpling": ["dumpling", "egg"],
        "pork_baozi": ["bun_steamed", "pork_lean"],
        "vegetable_baozi": ["bun_steamed"],
        "pork_wonton_soup": ["wonton", "pork_lean"],
        "pork_preserved_egg_congee": ["congee", "pork_lean"],
        "tomato_scrambled_egg": ["egg", "tomato"],
        "steamed_fish_cn": ["tilapia", "cod"]
    ]

    private static let spokenNumberPattern =
        #"[0-9]+(?:\.[0-9]+)?|[零〇一二两兩俩倆仨三四五六七八九十百千半]+"#

    private static let quantityPattern =
        #"("# + spokenNumberPattern + #")\s*([大中小满]?)\s*(公斤|千克|kg|KG|克|g|G|斤|两|毫升|ml|ML|个|只|枚|份|碗|盘|杯|根|片|块儿?|串|包|袋|盒|张|套|条)"#

    private static let clauseSeparatorPattern =
        #"(?:还吃了|还喝了|又吃了|又喝了|再加上|以及|并且|而且|还有|加上|外加|再加|再来|配上|搭配|另外|然后|跟|与|和|\band\b|\bwith\b|\bplus\b|，|,|、|；|;|。|/|\+|\n)"#

    // Short aliases require an explicit count and a standalone boundary to avoid partial-word matches.
    private static let countQualifiedShortAliases: Set<String> = ["蛋"]

    static func parse(
        _ input: String,
        referenceDate: Date,
        foodLibrary: [FoodItem],
        defaultAmount: (FoodItem) -> Double
    ) throws -> ParsedFoodIntake {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw FoodTextParserError.emptyInput }

        let mentions = explicitFoodMentions(in: text, foodLibrary: foodLibrary)
        var entries = entries(
            in: text,
            mentions: mentions,
            defaultAmount: defaultAmount
        )
        let compositeMatches = compositeFoodMatches(in: text, foodLibrary: foodLibrary)

        for compositeMatch in compositeMatches where !entries.contains(where: { $0.food.id == compositeMatch.food.id }) {
            let suppressedIDs = compositeSuppressedFoodIDs[compositeMatch.food.id] ?? []
            let insertionIndex = entries.firstIndex(where: { suppressedIDs.contains($0.food.id) }) ?? entries.endIndex
            entries.removeAll { suppressedIDs.contains($0.food.id) }
            entries.insert(
                makeEntry(
                    foodMatch: compositeMatch,
                    quantityText: text,
                    defaultAmount: defaultAmount
                ),
                at: min(insertionIndex, entries.endIndex)
            )
        }

        guard !entries.isEmpty else { throw FoodTextParserError.foodNotRecognized }

        var notes: [String] = []
        if entries.contains(where: \.amountWasEstimated) {
            notes.append(localized(
                "“个、碗、份”等数量已按常见份量换算，请按实际重量核对。",
                "Counts and household portions use typical-weight conversions. Check the actual weight."
            ))
        }
        if entries.contains(where: { $0.food.nutritionReference?.basis == .recipeEstimate }) {
            notes.append(localized(
                "菜品营养按常见配方估算，原料、用油、大小和品牌不同会影响结果。",
                "Dish nutrition uses a typical recipe estimate; ingredients, oil, size, and brand can change the result."
            ))
        }
        let unrecognizedFragments = unrecognizedFragments(
            in: text,
            mentions: mentions,
            compositeMatches: compositeMatches
        )
        if !unrecognizedFragments.isEmpty {
            notes.append(localized(
                "以下内容未能识别，请手动补充：\(unrecognizedFragments.joined(separator: "、"))",
                "These parts were not recognized; add them manually: \(unrecognizedFragments.joined(separator: ", "))"
            ))
        }

        return ParsedFoodIntake(
            originalText: text,
            date: resolvedDate(from: text, referenceDate: referenceDate),
            entries: entries,
            notes: notes
        )
    }

    private static func entries(
        in text: String,
        mentions: [FoodMention],
        defaultAmount: (FoodItem) -> Double
    ) -> [ParsedFoodEntry] {
        guard !mentions.isEmpty else { return [] }

        let amountTexts = assignedQuantityTexts(in: text, mentions: mentions)
        let source = text as NSString

        return mentions.enumerated().map { index, mention in
            let previousEnd = index == 0 ? 0 : NSMaxRange(mentions[index - 1].range)
            let nextStart = index == mentions.count - 1 ? source.length : mentions[index + 1].range.location
            let localRange = NSRange(
                location: previousEnd,
                length: max(0, nextStart - previousEnd)
            )
            let localText = source.substring(with: localRange)
            let quantityText = amountTexts[index].isEmpty
                ? localText
                : amountTexts[index].joined(separator: "，")

            return makeEntry(
                foodMatch: FoodMatch(food: mention.food, score: mention.score),
                quantityText: quantityText,
                defaultAmount: defaultAmount
            )
        }
    }

    private static func makeEntry(
        foodMatch: FoodMatch,
        quantityText: String,
        defaultAmount: (FoodItem) -> Double
    ) -> ParsedFoodEntry {
        let quantity = bestQuantityMatch(in: quantityText, for: foodMatch.food)
        let fallbackGrams = max(1, defaultAmount(foodMatch.food))
        let grams = quantity?.grams ?? fallbackGrams
        let quantityDescription = quantity?.description ?? localized(
            "未识别份量，暂按 \(formattedNumber(fallbackGrams)) 克",
            "No amount found; using \(formattedNumber(fallbackGrams)) g"
        )
        let amountWasEstimated = quantity?.estimated ?? true
        let foodConfidence = min(1, max(0.45, Double(foodMatch.score) / 500))
        let amountConfidence = quantity == nil ? 0.55 : (amountWasEstimated ? 0.78 : 0.98)

        return ParsedFoodEntry(
            food: foodMatch.food,
            grams: grams,
            quantityDescription: quantityDescription,
            confidence: min(foodConfidence, amountConfidence),
            amountWasEstimated: amountWasEstimated
        )
    }

    private static func explicitFoodMentions(
        in text: String,
        foodLibrary: [FoodItem]
    ) -> [FoodMention] {
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var candidates: [FoodMention] = []

        for food in foodLibrary {
            for (term, score) in foodSearchTerms(for: food) {
                let flexiblePattern = term.map {
                    NSRegularExpression.escapedPattern(for: String($0))
                }.joined(separator: #"\s*"#)
                let isShortAlias = countQualifiedShortAliases.contains(normalized(term))
                let searchPattern = isShortAlias
                    ? #"(?:("# + spokenNumberPattern + #")\s*(?:个|只|枚)\s*)("# +
                        flexiblePattern + #")(?=$|[\s和与、，,；;。/\+])"#
                    : flexiblePattern
                guard let expression = try? NSRegularExpression(
                    pattern: searchPattern,
                    options: [.caseInsensitive]
                ) else {
                    continue
                }

                for match in expression.matches(in: text, range: fullRange) {
                    let foodRange = isShortAlias ? match.range(at: 2) : match.range
                    candidates.append(FoodMention(
                        food: food,
                        score: score,
                        range: foodRange
                    ))
                }
            }
        }

        let prioritized = candidates.sorted {
            if $0.range.length != $1.range.length {
                return $0.range.length > $1.range.length
            }
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.range.location < $1.range.location
        }

        var selected: [FoodMention] = []
        for candidate in prioritized {
            guard !selected.contains(where: {
                NSIntersectionRange($0.range, candidate.range).length > 0
            }) else {
                continue
            }
            selected.append(candidate)
        }

        return selected.sorted { $0.range.location < $1.range.location }
    }

    private static func foodSearchTerms(for food: FoodItem) -> [(String, Int)] {
        let nameWithoutParentheses = food.name.replacingOccurrences(
            of: #"[（(][^）)]*[）)]"#,
            with: "",
            options: .regularExpression
        )
        let terms = [
            (nameWithoutParentheses, 10),
            (food.name, 10),
            (englishDisplayName(from: food.id), 0)
        ] + (food.aliases ?? []).map { ($0, 5) }
        var seen = Set<String>()

        return terms.compactMap { term, bonus in
            let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
            let candidate = normalized(trimmed)
            let deduplicationKey = trimmed.folding(
                options: [.caseInsensitive, .widthInsensitive],
                locale: Locale(identifier: "zh_Hans_CN")
            )
            let isEligibleShortAlias = countQualifiedShortAliases.contains(candidate)
            guard
                (candidate.count >= 2 || isEligibleShortAlias),
                seen.insert(deduplicationKey).inserted
            else {
                return nil
            }
            return (trimmed, candidate.count * 20 + bonus)
        }
    }

    private static func compositeFoodMatches(
        in text: String,
        foodLibrary: [FoodItem]
    ) -> [FoodMatch] {
        let normalizedText = normalized(text)
        guard !normalizedText.isEmpty else { return [] }

        return compositeKeywordRules.compactMap { foodID, groups in
            guard
                groups.allSatisfy({ alternatives in
                    alternatives.contains(where: { normalizedText.contains(normalized($0)) })
                }),
                let food = foodLibrary.first(where: { $0.id == foodID })
            else {
                return nil
            }
            return FoodMatch(food: food, score: 500)
        }
    }

    private static func assignedQuantityTexts(
        in text: String,
        mentions: [FoodMention]
    ) -> [[String]] {
        guard !mentions.isEmpty else { return [] }
        guard let expression = try? NSRegularExpression(pattern: quantityPattern) else {
            return Array(repeating: [], count: mentions.count)
        }

        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let quantityMatches = expression.matches(in: text, range: fullRange)
        guard let firstQuantity = quantityMatches.first else {
            return Array(repeating: [], count: mentions.count)
        }

        let prefersPrefixAmounts = firstQuantity.range.location < mentions[0].range.location
        var assignments = Array(repeating: [String](), count: mentions.count)

        for quantity in quantityMatches {
            let previousIndex = mentions.lastIndex {
                NSMaxRange($0.range) <= quantity.range.location
            }
            let nextIndex = mentions.firstIndex {
                $0.range.location >= NSMaxRange(quantity.range)
            }

            let targetIndex: Int?
            switch (previousIndex, nextIndex) {
            case (nil, let next?):
                targetIndex = next
            case (let previous?, nil):
                targetIndex = previous
            case (let previous?, let next?):
                let beforeGap = NSRange(
                    location: NSMaxRange(mentions[previous].range),
                    length: max(0, quantity.range.location - NSMaxRange(mentions[previous].range))
                )
                let afterGap = NSRange(
                    location: NSMaxRange(quantity.range),
                    length: max(0, mentions[next].range.location - NSMaxRange(quantity.range))
                )
                let separatorBefore = containsClauseSeparator(source.substring(with: beforeGap))
                let separatorAfter = containsClauseSeparator(source.substring(with: afterGap))

                if separatorBefore != separatorAfter {
                    targetIndex = separatorBefore ? next : previous
                } else {
                    targetIndex = prefersPrefixAmounts ? next : previous
                }
            case (nil, nil):
                targetIndex = nil
            }

            if let targetIndex {
                assignments[targetIndex].append(source.substring(with: quantity.range))
            }
        }

        return assignments
    }

    private static func containsClauseSeparator(_ text: String) -> Bool {
        guard let expression = try? NSRegularExpression(
            pattern: clauseSeparatorPattern,
            options: [.caseInsensitive]
        ) else {
            return false
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.firstMatch(in: text, range: range) != nil
    }

    private static func unrecognizedFragments(
        in text: String,
        mentions: [FoodMention],
        compositeMatches: [FoodMatch]
    ) -> [String] {
        guard let separator = try? NSRegularExpression(
            pattern: clauseSeparatorPattern,
            options: [.caseInsensitive]
        ) else {
            return []
        }

        let source = text as NSString
        let fullRange = NSRange(location: 0, length: source.length)
        let separators = separator.matches(in: text, range: fullRange)
        var clauseRanges: [NSRange] = []
        var clauseStart = 0
        for match in separators {
            clauseRanges.append(NSRange(
                location: clauseStart,
                length: max(0, match.range.location - clauseStart)
            ))
            clauseStart = NSMaxRange(match.range)
        }
        clauseRanges.append(NSRange(
            location: clauseStart,
            length: max(0, source.length - clauseStart)
        ))

        var fragments: [String] = []

        for clauseRange in clauseRanges where clauseRange.length > 0 {
            let remainder = NSMutableString(string: source.substring(with: clauseRange))
            let clauseMentions = mentions.filter {
                $0.range.location >= clauseRange.location &&
                    NSMaxRange($0.range) <= NSMaxRange(clauseRange)
            }
            for mention in clauseMentions.sorted(by: { $0.range.location > $1.range.location }) {
                let localRange = NSRange(
                    location: mention.range.location - clauseRange.location,
                    length: mention.range.length
                )
                remainder.replaceCharacters(in: localRange, with: "")
            }
            let withoutCompositeKeywords = removingCompositeKeywords(
                from: remainder as String,
                matches: compositeMatches
            )
            guard let unknownText = meaningfulFoodText(in: withoutCompositeKeywords) else {
                continue
            }
            if !fragments.contains(unknownText) {
                fragments.append(unknownText)
            }
        }

        return fragments
    }

    private static func removingCompositeKeywords(
        from text: String,
        matches: [FoodMatch]
    ) -> String {
        let normalizedText = normalized(text)
        let relevantGroups = matches.compactMap {
            compositeKeywordRules[$0.food.id]
        }.filter { groups in
            let matchingGroupCount = groups.filter { alternatives in
                alternatives.contains {
                    normalizedText.contains(normalized($0))
                }
            }.count
            return matchingGroupCount >= 2 ||
                normalizedText.contains("馅") ||
                normalizedText.contains("炒") ||
                normalizedText.contains("清蒸")
        }
        let keywords = relevantGroups
            .flatMap { $0 }
            .flatMap { $0 }
            .sorted { $0.count > $1.count }

        return keywords.reduce(text) { remainder, keyword in
            remainder.replacingOccurrences(
                of: keyword,
                with: "",
                options: [.caseInsensitive, .widthInsensitive]
            )
        }
    }

    private static func meaningfulFoodText(in fragment: String) -> String? {
        var remainder = fragment
        let removablePatterns = [
            quantityPattern,
            #"(?:(?:凌晨|清晨|早晨|早上|上午|中午|下午|傍晚|晚上)\s*)?(?:[0-9]{1,2}|[零〇一二两兩三四五六七八九十]+)\s*(?::|：|点|时)\s*(?:[0-9]{1,2}\s*分?|半|一刻|三刻)?"#,
            #"[0-9]{1,2}月[0-9]{1,2}[日号]?"#
        ]
        for pattern in removablePatterns {
            remainder = remainder.replacingOccurrences(
                of: pattern,
                with: "",
                options: .regularExpression
            )
        }

        let fillerWords = [
            "今天", "昨天", "前天", "今晚", "早餐", "早饭", "午餐", "午饭", "晚餐", "晚饭", "夜宵",
            "凌晨", "清晨", "早晨", "早上", "上午", "中午", "下午", "傍晚", "晚上",
            "我们", "我", "吃了", "吃", "喝了", "喝", "的是", "大约", "大概", "差不多", "左右",
            "一点", "一些", "请帮我记录", "帮我记录", "记录", "然后", "另外", "又", "还", "的", "了"
        ]
        for word in fillerWords {
            remainder = remainder.replacingOccurrences(of: word, with: "")
        }

        let cleaned = remainder.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        )
        guard normalized(cleaned).count >= 2 else { return nil }
        return cleaned
    }

    private static func bestQuantityMatch(in text: String, for food: FoodItem) -> QuantityMatch? {
        let matches = regexMatches(pattern: quantityPattern, in: text)
        var best: QuantityMatch?

        for groups in matches {
            guard
                groups.count >= 4,
                let value = numericValue(from: groups[1]),
                value > 0
            else {
                continue
            }

            let sizeModifier = groups[2]
            let rawUnit = groups[3]
            let unit = rawUnit.hasSuffix("儿") ? String(rawUnit.dropLast()) : rawUnit
            let candidate: QuantityMatch

            switch unit.lowercased() {
            case "克", "g":
                candidate = QuantityMatch(
                    grams: value,
                    description: localized("\(formattedNumber(value)) 克", "\(formattedNumber(value)) g"),
                    estimated: false,
                    score: 1_000
                )
            case "公斤", "千克", "kg":
                candidate = QuantityMatch(
                    grams: value * 1_000,
                    description: localized("\(formattedNumber(value)) 千克", "\(formattedNumber(value)) kg"),
                    estimated: false,
                    score: 1_000
                )
            case "斤":
                candidate = QuantityMatch(
                    grams: value * 500,
                    description: "\(formattedNumber(value)) \(localized("斤", "jin"))",
                    estimated: false,
                    score: 980
                )
            case "两":
                candidate = QuantityMatch(
                    grams: value * 50,
                    description: "\(formattedNumber(value)) \(localized("两", "liang"))",
                    estimated: false,
                    score: 980
                )
            case "毫升", "ml":
                candidate = QuantityMatch(
                    grams: value,
                    description: localized(
                        "\(formattedNumber(value)) 毫升，按 1 毫升约 1 克换算",
                        "\(formattedNumber(value)) ml, converted at approximately 1 g/ml"
                    ),
                    estimated: true,
                    score: 900
                )
            default:
                let portion = food.portions?.first(where: {
                    $0.unit == unit || $0.aliases.contains(unit)
                })
                let gramsPerUnit = portion?.grams ?? genericPortionGrams(for: unit, food: food)
                let sizeMultiplier = portionSizeMultiplier(for: sizeModifier)
                let isSpecificPortion = portion != nil
                let countPriority = value > 1 ? 850 : 650
                candidate = QuantityMatch(
                    grams: value * gramsPerUnit * sizeMultiplier,
                    description: localized(
                        "\(formattedNumber(value))\(sizeModifier)\(unit)，按每\(sizeModifier)\(unit)约 \(formattedNumber(gramsPerUnit * sizeMultiplier)) 克换算",
                        "\(formattedNumber(value)) \(sizeModifier)\(unit), using approximately \(formattedNumber(gramsPerUnit * sizeMultiplier)) g each"
                    ),
                    estimated: true,
                    score: countPriority + (isSpecificPortion ? 40 : 0)
                )
            }

            if best == nil || candidate.score > best!.score {
                best = candidate
            }
        }

        return best ?? implicitCountMatch(in: text, for: food)
    }

    private static func implicitCountMatch(in text: String, for food: FoodItem) -> QuantityMatch? {
        let names = ([food.name] + (food.aliases ?? []))
            .sorted { $0.count > $1.count }

        for name in names {
            let escapedName = NSRegularExpression.escapedPattern(for: name)
            let pattern = #"("# + spokenNumberPattern + #")\s*(?:个|只|枚)?\s*"# + escapedName
            guard
                let groups = regexMatches(pattern: pattern, in: text).first,
                groups.count >= 2,
                let value = numericValue(from: groups[1]),
                value > 0
            else {
                continue
            }

            let portion = food.portions?.first
            let unit = portion?.unit ?? "个"
            let gramsPerUnit = portion?.grams ?? genericPortionGrams(for: unit, food: food)
            return QuantityMatch(
                grams: value * gramsPerUnit,
                description: localized(
                    "口语数量 \(formattedNumber(value))\(unit)，按每\(unit)约 \(formattedNumber(gramsPerUnit)) 克换算",
                    "Spoken count \(formattedNumber(value)) \(unit), using approximately \(formattedNumber(gramsPerUnit)) g each"
                ),
                estimated: true,
                score: portion == nil ? 720 : 780
            )
        }

        return nil
    }

    private static func portionSizeMultiplier(for modifier: String) -> Double {
        switch modifier {
        case "小":
            return 0.75
        case "大", "满":
            return 1.25
        default:
            return 1
        }
    }

    private static func genericPortionGrams(for unit: String, food: FoodItem) -> Double {
        switch unit {
        case "碗": return 300
        case "盘": return 250
        case "杯": return 240
        case "份": return 200
        case "个", "只", "枚": return food.category == .fruit ? 150 : 50
        case "根", "条": return 80
        case "片": return 30
        case "块": return 50
        case "串": return 50
        case "包", "袋", "盒": return 100
        case "张": return 100
        case "套": return 250
        default: return 100
        }
    }

    private static func resolvedDate(from text: String, referenceDate: Date) -> Date {
        let calendar = AppPreferences.calendar
        let referenceDay = calendar.startOfDay(for: referenceDate)
        var day = referenceDay

        if text.contains("前天") {
            day = calendar.date(byAdding: .day, value: -2, to: referenceDay) ?? referenceDay
        } else if text.contains("昨天") || text.localizedCaseInsensitiveContains("yesterday") {
            day = calendar.date(byAdding: .day, value: -1, to: referenceDay) ?? referenceDay
        } else if let groups = regexMatches(
            pattern: #"([0-9]{1,2})月([0-9]{1,2})[日号]?"#,
            in: text
        ).first,
                  groups.count >= 3,
                  let month = Int(groups[1]),
                  let dayOfMonth = Int(groups[2]) {
            var components = calendar.dateComponents([.year], from: referenceDay)
            components.month = month
            components.day = dayOfMonth
            day = calendar.date(from: components) ?? referenceDay
        }

        let resolvedTime = parsedTime(from: text) ?? inferredMealTime(from: text)
        let hour = resolvedTime?.hour ?? calendar.component(.hour, from: Date())
        let minute = resolvedTime?.minute ?? calendar.component(.minute, from: Date())
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }

    private static func parsedTime(from text: String) -> (hour: Int, minute: Int)? {
        if let groups = regexMatches(
            pattern: #"(?:(凌晨|清晨|早晨|早上|上午|中午|下午|傍晚|晚上)\s*)?([0-9]{1,2}|[零〇一二两兩三四五六七八九十]+)\s*[:：]\s*([0-9]{1,2})"#,
            in: text
        ).first,
           groups.count >= 4,
           let hourValue = numericValue(from: groups[2]),
           hourValue.rounded() == hourValue,
           let hour = Int(exactly: hourValue),
           let minute = Int(groups[3]),
           hour <= 23,
           minute <= 59 {
            return (normalizedHour(hour, period: groups[1]), minute)
        }

        if let groups = regexMatches(
            pattern: #"(?:(凌晨|清晨|早晨|早上|上午|中午|下午|傍晚|晚上)\s*)?([0-9]{1,2}|[零〇一二两兩三四五六七八九十]+)\s*[点时]\s*(半|一刻|三刻|[0-9]{1,2}\s*分?)?"#,
            in: text
        ).first,
           groups.count >= 4,
           let hourValue = numericValue(from: groups[2]),
           hourValue.rounded() == hourValue,
           let hour = Int(exactly: hourValue),
           hour <= 23 {
            let minuteText = groups[3].replacingOccurrences(of: "分", with: "")
                .trimmingCharacters(in: .whitespaces)
            let minute: Int
            switch minuteText {
            case "半":
                minute = 30
            case "一刻":
                minute = 15
            case "三刻":
                minute = 45
            default:
                minute = Int(minuteText) ?? 0
            }
            guard minute <= 59 else { return nil }
            return (normalizedHour(hour, period: groups[1]), minute)
        }

        return nil
    }

    private static func normalizedHour(_ hour: Int, period: String) -> Int {
        switch period {
        case "凌晨", "清晨":
            return hour == 12 ? 0 : hour
        case "下午", "傍晚", "晚上":
            return hour < 12 ? hour + 12 : hour
        case "中午":
            return hour < 11 ? hour + 12 : hour
        default:
            return hour
        }
    }

    private static func inferredMealTime(from text: String) -> (hour: Int, minute: Int)? {
        if text.contains("早餐") || text.contains("早饭") ||
            text.contains("清晨") || text.contains("早晨") || text.contains("早上") {
            return (8, 0)
        }
        if text.contains("午餐") || text.contains("午饭") || text.contains("中午") {
            return (12, 0)
        }
        if text.contains("晚餐") || text.contains("晚饭") {
            return (18, 0)
        }
        if text.contains("傍晚") || text.contains("晚上") || text.contains("今晚") {
            return (19, 0)
        }
        if text.contains("夜宵") {
            return (22, 0)
        }
        return nil
    }

    private static func numericValue(from text: String) -> Double? {
        if let value = Double(text) {
            return value
        }
        switch text {
        case "半":
            return 0.5
        case "俩", "倆":
            return 2
        case "仨":
            return 3
        default:
            break
        }

        let digitValues: [Character: Int] = [
            "零": 0, "〇": 0, "一": 1, "二": 2, "两": 2, "兩": 2, "三": 3,
            "四": 4, "五": 5, "六": 6, "七": 7, "八": 8, "九": 9
        ]
        let unitValues: [Character: Int] = ["十": 10, "百": 100, "千": 1_000]

        if !text.contains(where: { unitValues[$0] != nil }) {
            let digits = text.compactMap { digitValues[$0] }
            guard digits.count == text.count else { return nil }
            return Double(digits.reduce(0) { $0 * 10 + $1 })
        }

        var total = 0
        var currentDigit = 0
        for character in text {
            if let digit = digitValues[character] {
                currentDigit = digit
            } else if let unit = unitValues[character] {
                total += max(1, currentDigit) * unit
                currentDigit = 0
            } else {
                return nil
            }
        }
        return Double(total + currentDigit)
    }

    private static func normalized(_ value: String) -> String {
        let folded = value.folding(
            options: [.caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_Hans_CN")
        )
        let withoutParentheses = folded.replacingOccurrences(
            of: #"[（(][^）)]*[）)]"#,
            with: "",
            options: .regularExpression
        )
        return withoutParentheses.unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private static func regexMatches(pattern: String, in text: String) -> [[String]] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: fullRange).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else {
                    return ""
                }
                return String(text[swiftRange])
            }
        }
    }

    private static func formattedNumber(_ value: Double) -> String {
        if abs(value.rounded() - value) < 0.01 {
            return String(Int(value.rounded()))
        }
        return String(format: "%.1f", value)
    }
}

struct KeepFitNutritionSource: Identifiable, Hashable {
    let id: String
    let titleZH: String
    let titleEN: String
    let summaryZH: String
    let summaryEN: String
    let urlString: String

    var title: String {
        localized(titleZH, titleEN)
    }

    var summary: String {
        localized(summaryZH, summaryEN)
    }

    var url: URL? {
        URL(string: urlString)
    }
}

enum KeepFitNutritionReferences {
    static let bodyWeightPlanner = KeepFitNutritionSource(
        id: "niddk_body_weight_planner",
        titleZH: "NIDDK：Body Weight Planner",
        titleEN: "NIDDK: Body Weight Planner",
        summaryZH: "支持体重管理中的热量消耗、活动水平与目标体重估算概念。",
        summaryEN: "Supports the concepts behind calorie expenditure, activity level, and goal-weight planning.",
        urlString: "https://www.niddk.nih.gov/health-information/weight-management/body-weight-planner"
    )

    static let weightControl = KeepFitNutritionSource(
        id: "medlineplus_weight_control",
        titleZH: "MedlinePlus：体重控制",
        titleEN: "MedlinePlus: Weight Control",
        summaryZH: "支持设置页中的体重管理、热量平衡与生活方式建议说明。",
        summaryEN: "Supports the settings guidance about weight management, calorie balance, and lifestyle changes.",
        urlString: "https://medlineplus.gov/weightcontrol.html"
    )

    static let calorieDeficit = KeepFitNutritionSource(
        id: "medlineplus_cut_500_calories",
        titleZH: "MedlinePlus：每天减少 500 卡路里的方法",
        titleEN: "MedlinePlus: 10 Ways to Cut 500 Calories a Day",
        summaryZH: "支持减重中“适度热量缺口”的一般健康概念。",
        summaryEN: "Supports the general wellness concept of a moderate calorie deficit for weight loss.",
        urlString: "https://medlineplus.gov/ency/patientinstructions/000892.htm"
    )

    static let dietaryGuidelines = KeepFitNutritionSource(
        id: "dietary_guidelines_2025_2030",
        titleZH: "MedlinePlus：美国膳食指南 2025-2030",
        titleEN: "MedlinePlus: Dietary Guidelines 2025-2030",
        summaryZH: "支持应用中的均衡饮食、蔬菜/蛋白优先与减少含糖饮料等通用营养建议。",
        summaryEN: "Supports the app's general nutrition tips about balanced meals, vegetables/protein, and limiting sugary drinks.",
        urlString: "https://medlineplus.gov/ency/article/002093.htm"
    )

    static let fiber = KeepFitNutritionSource(
        id: "medlineplus_fiber",
        titleZH: "MedlinePlus：膳食纤维",
        titleEN: "MedlinePlus: Dietary Fiber",
        summaryZH: "支持应用中的高纤维碳水与全谷物提醒。",
        summaryEN: "Supports the app's reminders about high-fiber carbs and whole grains.",
        urlString: "https://medlineplus.gov/ency/article/002470.htm"
    )

    static let mifflinStJeor = KeepFitNutritionSource(
        id: "mifflin_st_jeor",
        titleZH: "PubMed：Mifflin-St Jeor 代谢公式",
        titleEN: "PubMed: Mifflin-St Jeor Equation",
        summaryZH: "支持应用用于估算基础代谢与热量目标的公式。",
        summaryEN: "Supports the formula KeepFit uses to estimate BMR and calorie targets.",
        urlString: "https://pubmed.ncbi.nlm.nih.gov/2305711/"
    )

    static let foodDataCentral = KeepFitNutritionSource(
        id: "food_data_central",
        titleZH: "USDA：FoodData Central",
        titleEN: "USDA: FoodData Central",
        summaryZH: "可用于查询常见食物营养组成；包装食品请以产品标签为准。",
        summaryEN: "A standard nutrient-composition reference for common foods; packaged foods should be verified against the label.",
        urlString: "https://fdc.nal.usda.gov/"
    )

    static let chinaFoodComposition = KeepFitNutritionSource(
        id: "china_food_composition",
        titleZH: "中国疾控中心营养与健康所：食物营养成分查询平台",
        titleEN: "China CDC NINH: Food Nutrition Query Platform",
        summaryZH: "用于公开查询中国常见食物营养成分。平台数据版权归中国疾控中心营养与健康所所有，KeepFit 仅会在获得商业使用授权后内置相应数据。",
        summaryEN: "Provides public nutrient lookups for common Chinese foods. Data will only be bundled in KeepFit after commercial-use authorization is obtained.",
        urlString: "https://nlc.chinanutri.cn/fq/"
    )

    static let visibleSources: [KeepFitNutritionSource] = [
        mifflinStJeor,
        bodyWeightPlanner,
        weightControl,
        calorieDeficit,
        dietaryGuidelines,
        fiber,
        chinaFoodComposition,
        foodDataCentral
    ]

    static var intro: String {
        localized(
            "以下链接对应 KeepFit 中营养提示与热量估算所依据的公开参考来源。",
            "These public references support the nutrition tips and calorie estimates shown in KeepFit."
        )
    }

    static var disclaimer: String {
        localized(
            "KeepFit 的营养信息仅用于一般健康管理，不替代医生或注册营养师的个体化建议。",
            "KeepFit's nutrition guidance is for general wellness only and does not replace personalized advice from a clinician or registered dietitian."
        )
    }
}

func englishDisplayName(from identifier: String) -> String {
    let acronyms: [String: String] = [
        "hiit": "HIIT",
        "trx": "TRX"
    ]

    return identifier
        .split(separator: "_")
        .map { token in
            let lower = token.lowercased()
            if let mapped = acronyms[lower] {
                return mapped
            }
            guard let first = lower.first else { return "" }
            return first.uppercased() + lower.dropFirst()
        }
        .joined(separator: " ")
}

func keepFitMeasuredTextWidth(
    _ text: String,
    size: CGFloat,
    weight: UIFont.Weight = .regular,
    monospacedDigits: Bool = false
) -> CGFloat {
    let font: UIFont
    if monospacedDigits {
        font = .monospacedDigitSystemFont(ofSize: size, weight: weight)
    } else {
        font = .systemFont(ofSize: size, weight: weight)
    }
    return ceil((text as NSString).size(withAttributes: [.font: font]).width)
}

enum KeepFitHaptics {
    private static let hapticKey = "keepfit.haptic"
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let rigidImpactGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private static let softImpactGenerator = UIImpactFeedbackGenerator(style: .soft)
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    private static var isEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: hapticKey) == nil {
            return true
        }
        return defaults.bool(forKey: hapticKey)
    }

    private static func performOnMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread {
            action()
        } else {
            DispatchQueue.main.async(execute: action)
        }
    }

    private static func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        switch style {
        case .light:
            return lightImpactGenerator
        case .medium:
            return mediumImpactGenerator
        case .rigid:
            return rigidImpactGenerator
        case .soft:
            return softImpactGenerator
        default:
            return lightImpactGenerator
        }
    }

    static func prepare() {
        guard isEnabled else { return }
        performOnMain {
            lightImpactGenerator.prepare()
            mediumImpactGenerator.prepare()
            rigidImpactGenerator.prepare()
            softImpactGenerator.prepare()
            selectionGenerator.prepare()
        }
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        performOnMain {
            let generator = impactGenerator(for: style)
            generator.impactOccurred()
            generator.prepare()
        }
    }

    static func selection() {
        guard isEnabled else { return }
        performOnMain {
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
        }
    }
}
