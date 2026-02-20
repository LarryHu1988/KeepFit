import Foundation

struct DailyNutritionRecord: Identifiable {
    var id: Date { date }
    let date: Date
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct DailyExerciseRecord: Identifiable {
    var id: Date { date }
    let date: Date
    let caloriesBurned: Double
    let minutes: Double
}

struct DailyCalorieTrend: Identifiable {
    var id: Date { date }
    let date: Date
    let intake: Double
    let expenditure: Double
    let balance: Double
}

@MainActor
final class AppState: ObservableObject {
    @Published var profile: UserProfile {
        didSet {
            store.save(profile, for: .profile)
        }
    }

    @Published var foodLibrary: [FoodItem] {
        didSet {
            store.save(foodLibrary, for: .foods)
        }
    }

    @Published var exerciseLibrary: [ExerciseItem] {
        didSet {
            store.save(exerciseLibrary, for: .exercises)
        }
    }

    @Published var foodLogs: [FoodLog] {
        didSet {
            store.save(foodLogs, for: .foodLogs)
        }
    }

    @Published var exerciseLogs: [ExerciseLog] {
        didSet {
            store.save(exerciseLogs, for: .exerciseLogs)
        }
    }

    @Published var bodyMetricLogs: [BodyMetricLog] {
        didSet {
            store.save(bodyMetricLogs, for: .bodyMetrics)
        }
    }

    private let store = DataStore()

    init() {
        let loadedProfile = store.load(UserProfile.self, for: .profile) ?? .default
        let loadedFoods = store.load([FoodItem].self, for: .foods) ?? SeedData.foodLibrary
        let loadedExercises = store.load([ExerciseItem].self, for: .exercises) ?? SeedData.exerciseLibrary
        let loadedFoodLogs = store.load([FoodLog].self, for: .foodLogs) ?? []
        let loadedExerciseLogs = store.load([ExerciseLog].self, for: .exerciseLogs) ?? []
        let loadedBodyMetrics = store.load([BodyMetricLog].self, for: .bodyMetrics) ?? []

        profile = loadedProfile
        foodLibrary = Self.mergeFoodLibrary(loadedFoods, with: SeedData.foodLibrary)
        exerciseLibrary = Self.mergeExerciseLibrary(loadedExercises, with: SeedData.exerciseLibrary)
        foodLogs = loadedFoodLogs.sorted(by: { $0.date > $1.date })
        exerciseLogs = loadedExerciseLogs.sorted(by: { $0.date > $1.date })
        bodyMetricLogs = loadedBodyMetrics.sorted(by: { $0.date < $1.date })

        if bodyMetricLogs.isEmpty {
            bodyMetricLogs.append(
                BodyMetricLog(
                    id: UUID(),
                    date: Date(),
                    weightKg: profile.weightKg,
                    bodyFatPercent: max(10, profile.targetBodyFat + 8)
                )
            )
        }
    }

    private static func mergeFoodLibrary(_ existing: [FoodItem], with seed: [FoodItem]) -> [FoodItem] {
        var merged: [FoodItem] = []
        var seen = Set<String>()

        for item in existing where seen.insert(item.id).inserted {
            merged.append(item)
        }
        for item in seed where seen.insert(item.id).inserted {
            merged.append(item)
        }
        return merged
    }

    private static func mergeExerciseLibrary(_ existing: [ExerciseItem], with seed: [ExerciseItem]) -> [ExerciseItem] {
        var merged: [ExerciseItem] = []
        var seen = Set<String>()

        for item in existing where seen.insert(item.id).inserted {
            merged.append(item)
        }
        for item in seed where seen.insert(item.id).inserted {
            merged.append(item)
        }
        return merged
    }

    func addFoodLog(date: Date, item: FoodItem, grams: Double) {
        guard grams > 0 else { return }
        let log = FoodLog(
            id: UUID(),
            date: date,
            foodID: item.id,
            foodName: item.name,
            foodIcon: item.icon,
            weightGrams: grams,
            caloriesPer100g: item.caloriesPer100g,
            proteinPer100g: item.proteinPer100g,
            carbsPer100g: item.carbsPer100g,
            fatPer100g: item.fatPer100g
        )
        foodLogs.append(log)
        foodLogs.sort(by: { $0.date > $1.date })
    }

    func addExerciseLog(date: Date, item: ExerciseItem, durationMinutes: Double) {
        guard durationMinutes > 0 else { return }
        let log = ExerciseLog(
            id: UUID(),
            date: date,
            exerciseID: item.id,
            exerciseName: item.name,
            exerciseIcon: item.icon,
            durationMinutes: durationMinutes,
            met: item.met
        )
        exerciseLogs.append(log)
        exerciseLogs.sort(by: { $0.date > $1.date })
    }

    func upsertBodyMetric(date: Date, weightKg: Double, bodyFatPercent: Double) {
        let day = date.startOfDayInCurrentCalendar
        if let index = bodyMetricLogs.firstIndex(where: { $0.date.startOfDayInCurrentCalendar == day }) {
            bodyMetricLogs[index].weightKg = weightKg
            bodyMetricLogs[index].bodyFatPercent = bodyFatPercent
        } else {
            bodyMetricLogs.append(
                BodyMetricLog(
                    id: UUID(),
                    date: date,
                    weightKg: weightKg,
                    bodyFatPercent: bodyFatPercent
                )
            )
            bodyMetricLogs.sort(by: { $0.date < $1.date })
        }
    }

    func deleteFoodLog(_ log: FoodLog) {
        foodLogs.removeAll(where: { $0.id == log.id })
    }

    func deleteExerciseLog(_ log: ExerciseLog) {
        exerciseLogs.removeAll(where: { $0.id == log.id })
    }

    func foodIcon(for food: FoodItem) -> String {
        IconCatalog.foodIcon(id: food.id, category: food.category)
    }

    func foodIcon(forFoodID foodID: String) -> String {
        if let item = foodLibrary.first(where: { $0.id == foodID }) {
            return foodIcon(for: item)
        }
        return IconCatalog.foodIcon(id: foodID, category: .staple)
    }

    func exerciseIcon(for exercise: ExerciseItem) -> String {
        IconCatalog.exerciseIcon(id: exercise.id, category: exercise.category)
    }

    func exerciseIcon(forExerciseID exerciseID: String) -> String {
        if let item = exerciseLibrary.first(where: { $0.id == exerciseID }) {
            return exerciseIcon(for: item)
        }
        return IconCatalog.exerciseIcon(id: exerciseID, category: .cardio)
    }

    func foodUnitSymbol(for food: FoodItem) -> String {
        IconCatalog.foodUnit(id: food.id, category: food.category).symbol
    }

    func foodUnitSymbol(forFoodID foodID: String) -> String {
        if let item = foodLibrary.first(where: { $0.id == foodID }) {
            return foodUnitSymbol(for: item)
        }
        return IconCatalog.foodUnit(id: foodID, category: nil).symbol
    }

    func defaultEntryAmount(for food: FoodItem) -> Double {
        IconCatalog.foodUnit(id: food.id, category: food.category).defaultAmount
    }

    func foodLogs(on date: Date) -> [FoodLog] {
        foodLogs.filter { $0.date.isSameDay(as: date) }.sorted(by: { $0.date > $1.date })
    }

    func exerciseLogs(on date: Date) -> [ExerciseLog] {
        exerciseLogs.filter { $0.date.isSameDay(as: date) }.sorted(by: { $0.date > $1.date })
    }

    func dayNutrition(on date: Date) -> DayNutritionSummary {
        foodLogs(on: date).reduce(
            DayNutritionSummary(calories: 0, protein: 0, carbs: 0, fat: 0)
        ) { partial, log in
            DayNutritionSummary(
                calories: partial.calories + log.calories,
                protein: partial.protein + log.protein,
                carbs: partial.carbs + log.carbs,
                fat: partial.fat + log.fat
            )
        }
    }

    func dayExercise(on date: Date) -> DayFitnessSummary {
        let todayLogs = exerciseLogs(on: date)
        let calories = todayLogs.reduce(0) { $0 + $1.caloriesBurned(weightKg: profile.weightKg) }
        let minutes = todayLogs.reduce(0) { $0 + $1.durationMinutes }
        return DayFitnessSummary(caloriesBurned: calories, durationMinutes: minutes)
    }

    func dailyBalance(on date: Date) -> Double {
        let intake = dayNutrition(on: date).calories
        let exerciseBurn = dayExercise(on: date).caloriesBurned
        return intake - (profile.dailyMaintenanceCalories + exerciseBurn)
    }

    func deficitValue(on date: Date) -> Double {
        max(0, -dailyBalance(on: date))
    }

    func surplusValue(on date: Date) -> Double {
        max(0, dailyBalance(on: date))
    }

    func intakeProgress(on date: Date) -> Double {
        let current = dayNutrition(on: date).calories
        return min(max(current / profile.recommendedIntakeForFatLoss, 0), 1.5)
    }

    func exerciseProgress(on date: Date) -> Double {
        let current = dayExercise(on: date).caloriesBurned
        return min(max(current / max(profile.dailyExerciseGoal, 1), 0), 1.5)
    }

    func foodAdvice(on date: Date) -> String {
        let nutrition = dayNutrition(on: date)
        let remaining = profile.recommendedIntakeForFatLoss - nutrition.calories
        let proteinKcal = nutrition.protein * 4
        let carbKcal = nutrition.carbs * 4
        let fatKcal = nutrition.fat * 9
        let totalMacroKcal = max(1, proteinKcal + carbKcal + fatKcal)

        let proteinRatio = proteinKcal / totalMacroKcal
        let fatRatio = fatKcal / totalMacroKcal

        if nutrition.calories == 0 {
            return localized("今天还没记录饮食。建议先补充优质蛋白与蔬菜，再安排主食。", "No food logged yet. Start with quality protein and vegetables.")
        }
        if remaining > 350 {
            return localized("今日仍可摄入约 \(energyText(fromKcal: remaining))，优先补充蛋白质和高纤维碳水。", "You can still take about \(energyText(fromKcal: remaining)); prioritize protein and high-fiber carbs.")
        }
        if remaining >= 0 {
            return localized("当前摄入接近目标，晚餐以清淡高蛋白为主，避免额外甜饮。", "You're close to target. Keep dinner lean and high-protein.")
        }
        if remaining < -250 {
            return localized("已超目标 \(energyText(fromKcal: abs(remaining)))，建议晚间不再加餐并增加步行。", "You are over by \(energyText(fromKcal: abs(remaining))). Skip late snacks and add walking.")
        }
        if proteinRatio < 0.2 {
            return localized("蛋白质占比偏低，下一餐可加鸡胸肉、鱼虾或豆制品。", "Protein ratio is low. Add chicken, fish, shrimp, or tofu next meal.")
        }
        if fatRatio > 0.35 {
            return localized("脂肪占比较高，下一餐优先蒸煮食物并减少坚果/油炸。", "Fat ratio is high. Prefer steamed/boiled food and reduce nuts/fried food.")
        }
        return localized("营养结构整体平衡，继续保持。", "Nutrition structure is balanced. Keep it up.")
    }

    func exerciseAdvice(on date: Date) -> String {
        let summary = dayExercise(on: date)
        let remaining = profile.dailyExerciseGoal - summary.caloriesBurned

        if summary.durationMinutes == 0 {
            return localized("今天还没有运动记录。建议先完成 30 min 快走或 20 min 间歇训练。", "No workout logged yet. Start with 30 min brisk walk or 20 min intervals.")
        }
        if remaining > 120 {
            return localized("距离今日运动目标还差约 \(energyText(fromKcal: remaining))，可加 20-30 min 有氧。", "About \(energyText(fromKcal: remaining)) left to goal. Add 20-30 min cardio.")
        }
        if remaining > 0 {
            return localized("你已接近目标，再补 10-15 min 拉伸或轻有氧即可。", "You are close to goal. Add 10-15 min stretch or light cardio.")
        }
        return localized("今日运动目标已达成，建议做低强度拉伸帮助恢复。", "Goal reached. Do low-intensity stretching for recovery.")
    }

    func monthlyGrid(for month: Date) -> [Date?] {
        let calendar = AppPreferences.calendar
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month),
            let dayRange = calendar.range(of: .day, in: .month, for: monthInterval.start)
        else {
            return []
        }

        let firstDay = monthInterval.start
        let weekday = calendar.component(.weekday, from: firstDay)
        let leadingBlank = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: leadingBlank)
        for day in dayRange {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                cells.append(date)
            }
        }

        let trailing = (7 - cells.count % 7) % 7
        cells.append(contentsOf: Array(repeating: nil, count: trailing))
        return cells
    }

    func deficitSunCount(on date: Date) -> Int {
        let deficit = deficitValue(on: date)
        switch deficit {
        case 0..<80:
            return 0
        case 80..<200:
            return 1
        case 200..<350:
            return 2
        case 350..<500:
            return 3
        default:
            return 4
        }
    }

    func dailyNutritionRecords(limit: Int = 30) -> [DailyNutritionRecord] {
        let grouped = Dictionary(grouping: foodLogs) { $0.date.startOfDayInCurrentCalendar }
        return grouped
            .map { day, logs in
                DailyNutritionRecord(
                    date: day,
                    calories: logs.reduce(0) { $0 + $1.calories },
                    protein: logs.reduce(0) { $0 + $1.protein },
                    carbs: logs.reduce(0) { $0 + $1.carbs },
                    fat: logs.reduce(0) { $0 + $1.fat }
                )
            }
            .sorted(by: { $0.date > $1.date })
            .prefix(limit)
            .map { $0 }
    }

    func dailyExerciseRecords(limit: Int = 30) -> [DailyExerciseRecord] {
        let grouped = Dictionary(grouping: exerciseLogs) { $0.date.startOfDayInCurrentCalendar }
        return grouped
            .map { day, logs in
                DailyExerciseRecord(
                    date: day,
                    caloriesBurned: logs.reduce(0) { $0 + $1.caloriesBurned(weightKg: profile.weightKg) },
                    minutes: logs.reduce(0) { $0 + $1.durationMinutes }
                )
            }
            .sorted(by: { $0.date > $1.date })
            .prefix(limit)
            .map { $0 }
    }

    func calorieTrends(days: Int = 30) -> [DailyCalorieTrend] {
        let calendar = AppPreferences.calendar
        let today = Date().startOfDayInCurrentCalendar
        return (0..<days).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let nutrition = dayNutrition(on: day)
            let exercise = dayExercise(on: day)
            let exerciseExpenditure = exercise.caloriesBurned
            let balance = nutrition.calories - (profile.dailyMaintenanceCalories + exerciseExpenditure)
            return DailyCalorieTrend(date: day, intake: nutrition.calories, expenditure: exerciseExpenditure, balance: balance)
        }
    }

    func weightTrends(limit: Int = 60) -> [BodyMetricLog] {
        Array(bodyMetricLogs.sorted(by: { $0.date < $1.date }).suffix(limit))
    }

    func latestBodyMetric() -> BodyMetricLog {
        bodyMetricLogs.sorted(by: { $0.date > $1.date }).first
            ?? BodyMetricLog(id: UUID(), date: Date(), weightKg: profile.weightKg, bodyFatPercent: profile.targetBodyFat + 8)
    }
}
