import Foundation
import HealthKit
import UIKit

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
    let deficit: Double
}

private struct KeepFitCloudSnapshot: Codable {
    let version: Int
    let modifiedAt: Date
    let profile: UserProfile
    let foodLibrary: [FoodItem]
    let exerciseLibrary: [ExerciseItem]
    let foodLogs: [FoodLog]
    let exerciseLogs: [ExerciseLog]
    let bodyMetricLogs: [BodyMetricLog]
}

@MainActor
final class AppState: ObservableObject {
    private enum SyncKeys {
        static let iCloudEnabled = "keepfit.sync.iCloud"
        static let healthEnabled = "keepfit.sync.healthKit"
        static let localMutationTS = "keepfit.sync.localMutationTS"
        static let cloudSnapshot = "keepfit.sync.iCloud.snapshot.v1"
        static let exportedFoodLogIDs = "keepfit.sync.health.exported.foodLogIDs"
        static let exportedExerciseLogIDs = "keepfit.sync.health.exported.exerciseLogIDs"
        static let exportedBodyMetricIDs = "keepfit.sync.health.exported.bodyMetricIDs"
        static let importedDietarySampleUUIDs = "keepfit.sync.health.imported.dietarySampleUUIDs"
        static let importedWorkoutUUIDs = "keepfit.sync.health.imported.workoutUUIDs"
        static let importedBodyMassUUIDs = "keepfit.sync.health.imported.bodyMassUUIDs"
        static let importedBodyFatUUIDs = "keepfit.sync.health.imported.bodyFatUUIDs"
        static let healthMetadataSource = "KeepFitSource"
        static let healthMetadataSourceValue = "KeepFit"
    }

    @Published var profile: UserProfile {
        didSet {
            store.save(profile, for: .profile)
            handleLocalStateDidChange()
        }
    }

    @Published var foodLibrary: [FoodItem] {
        didSet {
            store.save(foodLibrary, for: .foods)
            handleLocalStateDidChange()
        }
    }

    @Published var exerciseLibrary: [ExerciseItem] {
        didSet {
            store.save(exerciseLibrary, for: .exercises)
            handleLocalStateDidChange()
        }
    }

    @Published var foodLogs: [FoodLog] {
        didSet {
            store.save(foodLogs, for: .foodLogs)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
        }
    }

    @Published var exerciseLogs: [ExerciseLog] {
        didSet {
            store.save(exerciseLogs, for: .exerciseLogs)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
        }
    }

    @Published var bodyMetricLogs: [BodyMetricLog] {
        didSet {
            store.save(bodyMetricLogs, for: .bodyMetrics)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
        }
    }

    private let store = DataStore()
    private let defaults = UserDefaults.standard
    private let iCloudStore = NSUbiquitousKeyValueStore.default
    private let healthStore = HKHealthStore()
    private let cloudEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let cloudDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    private var cloudObserver: NSObjectProtocol?
    private var foregroundObserver: NSObjectProtocol?
    private var pendingCloudPushTask: Task<Void, Never>?
    private var pendingHealthSyncTask: Task<Void, Never>?
    private var isApplyingCloudSnapshot = false
    private var isRunningHealthSync = false
    private var localMutationAt: Date = .distantPast

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

        let savedLocalMutationTS = defaults.double(forKey: SyncKeys.localMutationTS)
        localMutationAt = savedLocalMutationTS > 0 ? Date(timeIntervalSince1970: savedLocalMutationTS) : .distantPast
        setupForegroundObserver()
        if isICloudSyncEnabled {
            startICloudSync()
        }
        if isHealthSyncEnabled {
            Task { [weak self] in
                await self?.syncHealthDataIfEnabled()
            }
        }
    }

    deinit {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
        }
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
        pendingCloudPushTask?.cancel()
        pendingHealthSyncTask?.cancel()
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

    var isICloudSyncEnabled: Bool {
        defaults.bool(forKey: SyncKeys.iCloudEnabled)
    }

    var isHealthSyncEnabled: Bool {
        defaults.bool(forKey: SyncKeys.healthEnabled)
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: SyncKeys.iCloudEnabled)
        if enabled {
            startICloudSync()
            pullCloudSnapshotIfNeeded(force: true)
            queueCloudPush(immediate: true)
        } else {
            stopICloudSync()
        }
    }

    func setHealthSyncEnabled(_ enabled: Bool) async -> String? {
        if enabled {
            guard HKHealthStore.isHealthDataAvailable() else {
                return localized("当前设备不支持 Apple 健康。", "Apple Health is not available on this device.")
            }
            do {
                let granted = try await requestHealthAuthorization()
                guard granted else {
                    return localized("未获得 Apple 健康权限。", "Apple Health permission was not granted.")
                }
                defaults.set(true, forKey: SyncKeys.healthEnabled)
                await syncHealthDataIfEnabled()
                return nil
            } catch {
                return localized("健康数据授权失败，请稍后重试。", "Failed to authorize Apple Health. Please try again.")
            }
        }

        defaults.set(false, forKey: SyncKeys.healthEnabled)
        pendingHealthSyncTask?.cancel()
        return nil
    }

    func syncHealthDataIfEnabled() async {
        guard isHealthSyncEnabled else { return }
        await runHealthSync()
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

    func foodDisplayName(for food: FoodItem) -> String {
        displayName(id: food.id, chinese: food.name)
    }

    func foodDisplayName(forFoodID foodID: String, fallback: String? = nil) -> String {
        let chinese = foodLibrary.first(where: { $0.id == foodID })?.name ?? fallback ?? foodID
        return displayName(id: foodID, chinese: chinese)
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

    func exerciseDisplayName(for exercise: ExerciseItem) -> String {
        displayName(id: exercise.id, chinese: exercise.name)
    }

    func exerciseDisplayName(forExerciseID exerciseID: String, fallback: String? = nil) -> String {
        let chinese = exerciseLibrary.first(where: { $0.id == exerciseID })?.name ?? fallback ?? exerciseID
        return displayName(id: exerciseID, chinese: chinese)
    }

    func exerciseIcon(forExerciseID exerciseID: String) -> String {
        if let item = exerciseLibrary.first(where: { $0.id == exerciseID }) {
            return exerciseIcon(for: item)
        }
        return IconCatalog.exerciseIcon(id: exerciseID, category: .cardio)
    }

    private func displayName(id: String, chinese: String) -> String {
        if AppPreferences.language == .english {
            return englishDisplayName(from: id)
        }
        return chinese
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
            let totalExpenditure = profile.dailyMaintenanceCalories + exerciseExpenditure
            // Negative means deficit achieved, positive means surplus.
            let deficit = nutrition.calories - totalExpenditure
            return DailyCalorieTrend(date: day, intake: nutrition.calories, expenditure: exerciseExpenditure, deficit: deficit)
        }
    }

    func weightTrends(limit: Int = 60) -> [BodyMetricLog] {
        Array(bodyMetricLogs.sorted(by: { $0.date < $1.date }).suffix(limit))
    }

    func latestBodyMetric() -> BodyMetricLog {
        bodyMetricLogs.sorted(by: { $0.date > $1.date }).first
            ?? BodyMetricLog(id: UUID(), date: Date(), weightKg: profile.weightKg, bodyFatPercent: profile.targetBodyFat + 8)
    }

    private func handleLocalStateDidChange() {
        guard !isApplyingCloudSnapshot else { return }
        localMutationAt = Date()
        defaults.set(localMutationAt.timeIntervalSince1970, forKey: SyncKeys.localMutationTS)
        queueCloudPush()
    }

    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pullCloudSnapshotIfNeeded(force: false)
                await self.syncHealthDataIfEnabled()
            }
        }
    }

    private func startICloudSync() {
        guard cloudObserver == nil else { return }
        cloudObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: iCloudStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pullCloudSnapshotIfNeeded(force: false)
            }
        }
        iCloudStore.synchronize()
        pullCloudSnapshotIfNeeded(force: true)
    }

    private func stopICloudSync() {
        if let cloudObserver {
            NotificationCenter.default.removeObserver(cloudObserver)
            self.cloudObserver = nil
        }
        pendingCloudPushTask?.cancel()
        pendingCloudPushTask = nil
    }

    private func queueCloudPush(immediate: Bool = false) {
        guard isICloudSyncEnabled, !isApplyingCloudSnapshot else { return }
        pendingCloudPushTask?.cancel()
        if immediate {
            pushCloudSnapshotToICloud()
            return
        }
        pendingCloudPushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.pushCloudSnapshotToICloud()
            }
        }
    }

    private func pushCloudSnapshotToICloud() {
        guard isICloudSyncEnabled, !isApplyingCloudSnapshot else { return }
        let snapshot = KeepFitCloudSnapshot(
            version: 1,
            modifiedAt: localMutationAt == .distantPast ? Date() : localMutationAt,
            profile: profile,
            foodLibrary: foodLibrary,
            exerciseLibrary: exerciseLibrary,
            foodLogs: foodLogs,
            exerciseLogs: exerciseLogs,
            bodyMetricLogs: bodyMetricLogs
        )
        guard let data = try? cloudEncoder.encode(snapshot) else { return }
        iCloudStore.set(data, forKey: SyncKeys.cloudSnapshot)
        iCloudStore.synchronize()
    }

    private func pullCloudSnapshotIfNeeded(force: Bool) {
        guard isICloudSyncEnabled else { return }
        guard let data = iCloudStore.data(forKey: SyncKeys.cloudSnapshot) else { return }
        guard let snapshot = try? cloudDecoder.decode(KeepFitCloudSnapshot.self, from: data) else { return }
        guard snapshot.version == 1 else { return }

        let remoteTS = snapshot.modifiedAt.timeIntervalSince1970
        let localTS = localMutationAt.timeIntervalSince1970
        guard force || remoteTS > localTS + 1 else { return }

        isApplyingCloudSnapshot = true
        defer { isApplyingCloudSnapshot = false }

        profile = snapshot.profile
        foodLibrary = Self.mergeFoodLibrary(snapshot.foodLibrary, with: SeedData.foodLibrary)
        exerciseLibrary = Self.mergeExerciseLibrary(snapshot.exerciseLibrary, with: SeedData.exerciseLibrary)
        foodLogs = snapshot.foodLogs.sorted(by: { $0.date > $1.date })
        exerciseLogs = snapshot.exerciseLogs.sorted(by: { $0.date > $1.date })
        bodyMetricLogs = snapshot.bodyMetricLogs.sorted(by: { $0.date < $1.date })
        if bodyMetricLogs.isEmpty {
            bodyMetricLogs = [
                BodyMetricLog(
                    id: UUID(),
                    date: Date(),
                    weightKg: profile.weightKg,
                    bodyFatPercent: max(10, profile.targetBodyFat + 8)
                )
            ]
        }

        localMutationAt = snapshot.modifiedAt
        defaults.set(localMutationAt.timeIntervalSince1970, forKey: SyncKeys.localMutationTS)
    }

    private func scheduleHealthExportIfNeeded() {
        guard isHealthSyncEnabled else { return }
        pendingHealthSyncTask?.cancel()
        pendingHealthSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await self?.runHealthSync()
        }
    }

    private func runHealthSync() async {
        guard isHealthSyncEnabled, HKHealthStore.isHealthDataAvailable(), !isRunningHealthSync else { return }
        isRunningHealthSync = true
        defer { isRunningHealthSync = false }

        do {
            try await exportUnsyncedLocalDataToHealth()
            try await importHealthDataIntoKeepFit()
        } catch {
            // Keep silent for background/automatic sync to avoid interrupting user flow.
        }
    }

    private func requestHealthAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: healthWriteTypes, read: healthReadTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: success)
            }
        }
    }

    private var healthReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(dietary) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(bodyFat) }
        return types
    }

    private var healthWriteTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = [HKObjectType.workoutType()]
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) { types.insert(dietary) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(bodyFat) }
        return types
    }

    private func exportUnsyncedLocalDataToHealth() async throws {
        guard
            let dietaryType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        else {
            return
        }

        var exportedFoodIDs = loadStringSet(forKey: SyncKeys.exportedFoodLogIDs)
        var exportedExerciseIDs = loadStringSet(forKey: SyncKeys.exportedExerciseLogIDs)
        var exportedBodyMetricIDs = loadStringSet(forKey: SyncKeys.exportedBodyMetricIDs)

        for log in foodLogs {
            let logID = log.id.uuidString
            if exportedFoodIDs.contains(logID) { continue }
            let metadata: [String: Any] = [
                HKMetadataKeyExternalUUID: logID,
                SyncKeys.healthMetadataSource: SyncKeys.healthMetadataSourceValue
            ]
            let sample = HKQuantitySample(
                type: dietaryType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: max(log.calories, 0)),
                start: log.date,
                end: log.date.addingTimeInterval(60),
                metadata: metadata
            )
            try await saveHealthObject(sample)
            exportedFoodIDs.insert(logID)
        }

        for log in exerciseLogs {
            let logID = log.id.uuidString
            if exportedExerciseIDs.contains(logID) { continue }
            let calories = max(log.caloriesBurned(weightKg: profile.weightKg), 0)
            let durationSeconds = max(log.durationMinutes * 60, 60)
            let endDate = log.date.addingTimeInterval(durationSeconds)
            let metadata: [String: Any] = [
                HKMetadataKeyExternalUUID: logID,
                SyncKeys.healthMetadataSource: SyncKeys.healthMetadataSourceValue
            ]
            let workout = HKWorkout(
                activityType: .other,
                start: log.date,
                end: endDate,
                duration: durationSeconds,
                totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                totalDistance: nil,
                metadata: metadata
            )
            try await saveHealthObject(workout)
            exportedExerciseIDs.insert(logID)
        }

        for log in bodyMetricLogs {
            let logID = log.id.uuidString
            if exportedBodyMetricIDs.contains(logID) { continue }
            let metadata: [String: Any] = [
                HKMetadataKeyExternalUUID: logID,
                SyncKeys.healthMetadataSource: SyncKeys.healthMetadataSourceValue
            ]
            let weightSample = HKQuantitySample(
                type: bodyMassType,
                quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: max(log.weightKg, 0)),
                start: log.date,
                end: log.date.addingTimeInterval(60),
                metadata: metadata
            )
            let fatSample = HKQuantitySample(
                type: bodyFatType,
                quantity: HKQuantity(unit: .percent(), doubleValue: max(log.bodyFatPercent, 0) / 100),
                start: log.date,
                end: log.date.addingTimeInterval(60),
                metadata: metadata
            )
            try await saveHealthObject(weightSample)
            try await saveHealthObject(fatSample)
            exportedBodyMetricIDs.insert(logID)
        }

        saveStringSet(exportedFoodIDs, forKey: SyncKeys.exportedFoodLogIDs)
        saveStringSet(exportedExerciseIDs, forKey: SyncKeys.exportedExerciseLogIDs)
        saveStringSet(exportedBodyMetricIDs, forKey: SyncKeys.exportedBodyMetricIDs)
    }

    private func importHealthDataIntoKeepFit() async throws {
        guard
            let dietaryType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed),
            let bodyMassType = HKQuantityType.quantityType(forIdentifier: .bodyMass),
            let bodyFatType = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage)
        else {
            return
        }

        let calendar = AppPreferences.calendar
        let since = calendar.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast

        var importedDietaryUUIDs = loadStringSet(forKey: SyncKeys.importedDietarySampleUUIDs)
        var importedWorkoutUUIDs = loadStringSet(forKey: SyncKeys.importedWorkoutUUIDs)
        var importedBodyMassUUIDs = loadStringSet(forKey: SyncKeys.importedBodyMassUUIDs)
        var importedBodyFatUUIDs = loadStringSet(forKey: SyncKeys.importedBodyFatUUIDs)
        var exportedFoodIDs = loadStringSet(forKey: SyncKeys.exportedFoodLogIDs)
        var exportedExerciseIDs = loadStringSet(forKey: SyncKeys.exportedExerciseLogIDs)
        var exportedBodyMetricIDs = loadStringSet(forKey: SyncKeys.exportedBodyMetricIDs)

        let dietarySamples = try await fetchQuantitySamples(type: dietaryType, from: since)
        var mergedFoodLogs = foodLogs
        for sample in dietarySamples {
            let sampleUUID = sample.uuid.uuidString
            if importedDietaryUUIDs.contains(sampleUUID) { continue }
            importedDietaryUUIDs.insert(sampleUUID)

            let kcal = sample.quantity.doubleValue(for: .kilocalorie())
            guard kcal > 0 else { continue }

            let log = FoodLog(
                id: UUID(),
                date: sample.startDate,
                foodID: "apple_health_dietary_energy",
                foodName: localized("Apple 健康摄入", "Apple Health Intake"),
                foodIcon: "heart.fill",
                weightGrams: 100,
                caloriesPer100g: kcal,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0
            )
            mergedFoodLogs.append(log)
            exportedFoodIDs.insert(log.id.uuidString)
        }
        if mergedFoodLogs.count != foodLogs.count {
            foodLogs = mergedFoodLogs.sorted(by: { $0.date > $1.date })
        }

        let workouts = try await fetchWorkouts(from: since)
        var mergedExerciseLogs = exerciseLogs
        for workout in workouts {
            let workoutUUID = workout.uuid.uuidString
            if importedWorkoutUUIDs.contains(workoutUUID) { continue }
            importedWorkoutUUIDs.insert(workoutUUID)

            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            let durationMinutes = max(workout.duration / 60, 1)
            guard calories > 0 else { continue }

            let met = max((calories * 200) / (3.5 * max(profile.weightKg, 1) * durationMinutes), 1)
            let log = ExerciseLog(
                id: UUID(),
                date: workout.startDate,
                exerciseID: "apple_health_workout",
                exerciseName: localized("Apple 健康运动", "Apple Health Workout"),
                exerciseIcon: "heart.circle.fill",
                durationMinutes: durationMinutes,
                met: met
            )
            mergedExerciseLogs.append(log)
            exportedExerciseIDs.insert(log.id.uuidString)
        }
        if mergedExerciseLogs.count != exerciseLogs.count {
            exerciseLogs = mergedExerciseLogs.sorted(by: { $0.date > $1.date })
        }

        let bodyMassSamples = try await fetchQuantitySamples(type: bodyMassType, from: since)
        let bodyFatSamples = try await fetchQuantitySamples(type: bodyFatType, from: since)
        var mergedBodyMetrics = bodyMetricLogs
        var didImportBodyMetrics = false

        for sample in bodyMassSamples {
            let sampleUUID = sample.uuid.uuidString
            if importedBodyMassUUIDs.contains(sampleUUID) { continue }
            importedBodyMassUUIDs.insert(sampleUUID)

            let day = sample.startDate.startOfDayInCurrentCalendar
            let weight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            let fallbackFat = mergedBodyMetrics.first(where: { $0.date.startOfDayInCurrentCalendar == day })?.bodyFatPercent
                ?? max(10, profile.targetBodyFat + 8)
            let metricID = upsertBodyMetric(in: &mergedBodyMetrics, date: day, weightKg: weight, bodyFatPercent: fallbackFat)
            exportedBodyMetricIDs.insert(metricID.uuidString)
            didImportBodyMetrics = true
        }

        for sample in bodyFatSamples {
            let sampleUUID = sample.uuid.uuidString
            if importedBodyFatUUIDs.contains(sampleUUID) { continue }
            importedBodyFatUUIDs.insert(sampleUUID)

            let day = sample.startDate.startOfDayInCurrentCalendar
            let fatPercent = sample.quantity.doubleValue(for: .percent()) * 100
            let fallbackWeight = mergedBodyMetrics.first(where: { $0.date.startOfDayInCurrentCalendar == day })?.weightKg
                ?? profile.weightKg
            let metricID = upsertBodyMetric(in: &mergedBodyMetrics, date: day, weightKg: fallbackWeight, bodyFatPercent: fatPercent)
            exportedBodyMetricIDs.insert(metricID.uuidString)
            didImportBodyMetrics = true
        }

        if didImportBodyMetrics {
            bodyMetricLogs = mergedBodyMetrics.sorted(by: { $0.date < $1.date })
        }

        saveStringSet(importedDietaryUUIDs, forKey: SyncKeys.importedDietarySampleUUIDs)
        saveStringSet(importedWorkoutUUIDs, forKey: SyncKeys.importedWorkoutUUIDs)
        saveStringSet(importedBodyMassUUIDs, forKey: SyncKeys.importedBodyMassUUIDs)
        saveStringSet(importedBodyFatUUIDs, forKey: SyncKeys.importedBodyFatUUIDs)
        saveStringSet(exportedFoodIDs, forKey: SyncKeys.exportedFoodLogIDs)
        saveStringSet(exportedExerciseIDs, forKey: SyncKeys.exportedExerciseLogIDs)
        saveStringSet(exportedBodyMetricIDs, forKey: SyncKeys.exportedBodyMetricIDs)
    }

    private func saveHealthObject(_ object: HKObject) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(object) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "KeepFit.HealthKit", code: -1))
                }
            }
        }
    }

    private func fetchQuantitySamples(type: HKQuantityType, from startDate: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(from startDate: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: nil, options: .strictStartDate)
        let sortDescriptors = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sortDescriptors) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
    }

    @discardableResult
    private func upsertBodyMetric(in logs: inout [BodyMetricLog], date: Date, weightKg: Double, bodyFatPercent: Double) -> UUID {
        let day = date.startOfDayInCurrentCalendar
        if let index = logs.firstIndex(where: { $0.date.startOfDayInCurrentCalendar == day }) {
            logs[index].weightKg = weightKg
            logs[index].bodyFatPercent = bodyFatPercent
            return logs[index].id
        }

        let log = BodyMetricLog(
            id: UUID(),
            date: day,
            weightKg: weightKg,
            bodyFatPercent: bodyFatPercent
        )
        logs.append(log)
        return log.id
    }

    private func loadStringSet(forKey key: String) -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    private func saveStringSet(_ values: Set<String>, forKey key: String) {
        defaults.set(Array(values), forKey: key)
    }
}
