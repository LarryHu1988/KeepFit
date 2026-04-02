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

    static let visibleSources: [KeepFitNutritionSource] = [
        dietaryGuidelines,
        fiber,
        mifflinStJeor,
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
