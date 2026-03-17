import Foundation
import AuthenticationServices
import HealthKit
import UIKit
@preconcurrency import UserNotifications

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

struct DailyCalorieTrend: Identifiable, Equatable, Hashable {
    var id: Date { date }
    let date: Date
    let intake: Double
    let expenditure: Double
    let deficit: Double
}

struct DataDeletionSummary: Equatable {
    let foodLogCount: Int
    let exerciseLogCount: Int
    let bodyMetricCount: Int

    var totalCount: Int {
        foodLogCount + exerciseLogCount + bodyMetricCount
    }

    static let empty = DataDeletionSummary(foodLogCount: 0, exerciseLogCount: 0, bodyMetricCount: 0)
}

struct AppleHealthPermissionItem: Identifiable, Hashable {
    enum Section: Hashable {
        case activity
        case healthData
    }

    let id: String
    let title: String
    let section: Section
    let isEnabled: Bool
}

private struct KeepFitCloudSnapshot: Codable {
    let version: Int
    let modifiedAt: Date
    let settings: KeepFitSettingsSnapshot?
    let profile: UserProfile
    let foodLibrary: [FoodItem]
    let exerciseLibrary: [ExerciseItem]
    let foodLogs: [FoodLog]
    let exerciseLogs: [ExerciseLog]
    let bodyMetricLogs: [BodyMetricLog]
}

private struct KeepFitSettingsSnapshot: Codable {
    let themeModeRaw: String
    let energyUnitRaw: String
    let heightUnitRaw: String
    let weightUnitRaw: String
    let weekStartRaw: String
    let appLanguageRaw: String
    let birthDateTimestamp: Double
    let hapticEnabled: Bool
    let foodReminderEnabled: Bool
    let exerciseReminderEnabled: Bool
    let dailySummaryEnabled: Bool
    let foodReminderMinuteOfDay: Int
    let exerciseReminderMinuteOfDay: Int
    let summaryReminderMinuteOfDay: Int
}

enum KeepFitAccountMode: String, Codable {
    case undecided
    case local
    case apple
}

struct KeepFitAccount: Codable {
    var mode: KeepFitAccountMode
    var userID: String?
    var email: String?
    var displayName: String?
    var lastAuthenticatedAt: Date?

    static let undecided = KeepFitAccount(mode: .undecided, userID: nil, email: nil, displayName: nil, lastAuthenticatedAt: nil)
    static let local = KeepFitAccount(mode: .local, userID: nil, email: nil, displayName: nil, lastAuthenticatedAt: nil)

    var isSignedInWithApple: Bool {
        mode == .apple && !(userID ?? "").isEmpty
    }
}

@MainActor
final class AppState: ObservableObject {
    private struct RecordedDataOverview {
        var earliestDate: Date?
        var latestDate: Date?
        var summary: DataDeletionSummary

        static let empty = RecordedDataOverview(earliestDate: nil, latestDate: nil, summary: .empty)
    }

    private struct DailyMetricsCache {
        var foodLogsByDay: [Date: [FoodLog]]
        var exerciseLogsByDay: [Date: [ExerciseLog]]
        var nutritionByDay: [Date: DayNutritionSummary]
        var exerciseByDay: [Date: DayFitnessSummary]
        var dailyNutritionRecordsDescending: [DailyNutritionRecord]
        var dailyExerciseRecordsDescending: [DailyExerciseRecord]
        var calorieTrendsAscending: [DailyCalorieTrend]
        var latestBodyMetricByDay: [Date: BodyMetricLog]
        var bodyMetricsAscending: [BodyMetricLog]
        var daysWithAnyActivity: Set<Date>

        static let empty = DailyMetricsCache(
            foodLogsByDay: [:],
            exerciseLogsByDay: [:],
            nutritionByDay: [:],
            exerciseByDay: [:],
            dailyNutritionRecordsDescending: [],
            dailyExerciseRecordsDescending: [],
            calorieTrendsAscending: [],
            latestBodyMetricByDay: [:],
            bodyMetricsAscending: [],
            daysWithAnyActivity: []
        )
    }

    private enum SyncKeys {
        static let iCloudEnabled = "keepfit.sync.iCloud"
        static let healthEnabled = "keepfit.sync.healthKit"
        static let localMutationTS = "keepfit.sync.localMutationTS"
        static let cloudSnapshot = "keepfit.sync.iCloud.snapshot.v1"
        static let cloudSnapshotAccountPrefix = "keepfit.sync.iCloud.snapshot.account."
        static let exportedFoodLogIDs = "keepfit.sync.health.exported.foodLogIDs"
        static let exportedExerciseLogIDs = "keepfit.sync.health.exported.exerciseLogIDs"
        static let exportedBodyMetricIDs = "keepfit.sync.health.exported.bodyMetricIDs"
        static let importedDietarySampleUUIDs = "keepfit.sync.health.imported.dietarySampleUUIDs"
        static let importedWorkoutUUIDs = "keepfit.sync.health.imported.workoutUUIDs"
        static let importedBodyMassUUIDs = "keepfit.sync.health.imported.bodyMassUUIDs"
        static let importedBodyFatUUIDs = "keepfit.sync.health.imported.bodyFatUUIDs"
        static let healthInitialImportCompleted = "keepfit.sync.health.initialImportCompleted.v2"
        static let healthMetadataSource = "KeepFitSource"
        static let healthMetadataSourceValue = "KeepFit"
        static let account = "keepfit.account.current.v1"
    }

    private enum PreferenceKeys {
        static let themeMode = "keepfit.themeMode"
        static let energyUnit = "keepfit.unit.energy"
        static let heightUnit = "keepfit.unit.height"
        static let weightUnit = "keepfit.unit.weight"
        static let weekStart = "keepfit.calendar.weekStart"
        static let appLanguage = "keepfit.appLanguage"
        static let birthDateTimestamp = "keepfit.birthDateTS"
        static let hapticEnabled = "keepfit.haptic"
        static let foodReminderEnabled = "keepfit.reminder.food"
        static let exerciseReminderEnabled = "keepfit.reminder.exercise"
        static let dailySummaryEnabled = "keepfit.reminder.summary"
        static let foodReminderMinuteOfDay = "keepfit.reminder.food.minuteOfDay"
        static let exerciseReminderMinuteOfDay = "keepfit.reminder.exercise.minuteOfDay"
        static let summaryReminderMinuteOfDay = "keepfit.reminder.summary.minuteOfDay"
    }

    private enum ReminderKeys {
        static let foodEnabled = "keepfit.reminder.food"
        static let foodMinuteOfDay = "keepfit.reminder.food.minuteOfDay"
        static let foodIdentifier = "keepfit.reminder.food"
        static let exerciseEnabled = "keepfit.reminder.exercise"
        static let exerciseMinuteOfDay = "keepfit.reminder.exercise.minuteOfDay"
        static let exerciseIdentifier = "keepfit.reminder.exercise"
        static let summaryEnabled = "keepfit.reminder.summary"
        static let summaryMinuteOfDay = "keepfit.reminder.summary.minuteOfDay"
        static let summaryIdentifier = "keepfit.reminder.summary"
        static let schedulingHorizonDays = 14
    }

    @Published var profile: UserProfile {
        didSet {
            rebuildDailyMetricsCache()
            store.save(profile, for: .profile)
            handleLocalStateDidChange()
            refreshDynamicRemindersIfNeeded()
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
            rebuildRecordedDataOverview()
            rebuildDailyMetricsCache()
            store.save(foodLogs, for: .foodLogs)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
            refreshDynamicRemindersIfNeeded()
        }
    }

    @Published var exerciseLogs: [ExerciseLog] {
        didSet {
            rebuildRecordedDataOverview()
            rebuildDailyMetricsCache()
            store.save(exerciseLogs, for: .exerciseLogs)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
            refreshDynamicRemindersIfNeeded()
        }
    }

    @Published var bodyMetricLogs: [BodyMetricLog] {
        didSet {
            rebuildRecordedDataOverview()
            rebuildDailyMetricsCache()
            store.save(bodyMetricLogs, for: .bodyMetrics)
            handleLocalStateDidChange()
            scheduleHealthExportIfNeeded()
            refreshDynamicRemindersIfNeeded()
        }
    }

    @Published private(set) var account: KeepFitAccount
    @Published private(set) var iCloudAccountAvailable = FileManager.default.ubiquityIdentityToken != nil

    private let store = DataStore()
    private let defaults = UserDefaults.standard
    private lazy var iCloudStore = NSUbiquitousKeyValueStore.default
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
    private var ubiquityIdentityObserver: NSObjectProtocol?
    private var didBecomeActiveObserver: NSObjectProtocol?
    private var didEnterBackgroundObserver: NSObjectProtocol?
    private var dayChangedObserver: NSObjectProtocol?
    private var pendingCloudPushTask: Task<Void, Never>?
    private var pendingHealthSyncTask: Task<Void, Never>?
    private var healthPollingTask: Task<Void, Never>?
    private var isApplyingCloudSnapshot = false
    private var isRunningHealthSync = false
    private var localMutationAt: Date = .distantPast
    private var healthObserverQueries: [HKObserverQuery] = []
    private var hadKnownHealthWriteAuthorization = false
    private var recordedDataOverview = RecordedDataOverview.empty
    private var dailyMetricsCache = DailyMetricsCache.empty

    init() {
        let loadedProfile = store.load(UserProfile.self, for: .profile) ?? .default
        let loadedFoods = store.load([FoodItem].self, for: .foods) ?? SeedData.foodLibrary
        let loadedExercises = store.load([ExerciseItem].self, for: .exercises) ?? SeedData.exerciseLibrary
        let loadedFoodLogs = store.load([FoodLog].self, for: .foodLogs) ?? []
        let loadedExerciseLogs = store.load([ExerciseLog].self, for: .exerciseLogs) ?? []
        let loadedBodyMetrics = store.load([BodyMetricLog].self, for: .bodyMetrics) ?? []
        let loadedAccount = Self.loadAccount(from: UserDefaults.standard) ?? .undecided

        profile = loadedProfile
        foodLibrary = Self.mergeFoodLibrary(loadedFoods, with: SeedData.foodLibrary)
        exerciseLibrary = Self.mergeExerciseLibrary(loadedExercises, with: SeedData.exerciseLibrary)
        foodLogs = loadedFoodLogs.sorted(by: { $0.date > $1.date })
        exerciseLogs = loadedExerciseLogs.sorted(by: { $0.date > $1.date })
        bodyMetricLogs = loadedBodyMetrics.sorted(by: { $0.date < $1.date })
        account = loadedAccount
        rebuildRecordedDataOverview()
        rebuildDailyMetricsCache()

        let savedLocalMutationTS = defaults.double(forKey: SyncKeys.localMutationTS)
        localMutationAt = savedLocalMutationTS > 0 ? Date(timeIntervalSince1970: savedLocalMutationTS) : .distantPast
        if defaults.bool(forKey: SyncKeys.healthEnabled), HKHealthStore.isHealthDataAvailable() {
            hadKnownHealthWriteAuthorization = hasAnyHealthAuthorization()
        }
        refreshICloudAccountAvailability()
        setupUbiquityIdentityObserver()
        setupForegroundObserver()
        setupHealthActivityObservers()
        setupCalendarDayChangedObserver()
        refreshDynamicRemindersIfNeeded()
        if isICloudSyncEnabled {
            startICloudSync()
        }
        if isHealthSyncEnabled {
            Task { [weak self] in
                await self?.startHealthObserversIfNeeded()
                self?.startHealthPollingIfNeeded()
                await self?.syncHealthDataIfEnabled()
            }
        }
        if account.isSignedInWithApple {
            Task { [weak self] in
                await self?.refreshAppleCredentialStateIfNeeded()
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
        if let ubiquityIdentityObserver {
            NotificationCenter.default.removeObserver(ubiquityIdentityObserver)
        }
        if let didBecomeActiveObserver {
            NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        }
        if let didEnterBackgroundObserver {
            NotificationCenter.default.removeObserver(didEnterBackgroundObserver)
        }
        if let dayChangedObserver {
            NotificationCenter.default.removeObserver(dayChangedObserver)
        }
        pendingCloudPushTask?.cancel()
        pendingHealthSyncTask?.cancel()
        healthPollingTask?.cancel()
    }

    private static func mergeFoodLibrary(_ existing: [FoodItem], with seed: [FoodItem]) -> [FoodItem] {
        let seedIDs = Set(seed.map(\.id))
        let extras = existing.filter { !seedIDs.contains($0.id) }
        return seed + extras
    }

    private static func mergeExerciseLibrary(_ existing: [ExerciseItem], with seed: [ExerciseItem]) -> [ExerciseItem] {
        let seedIDs = Set(seed.map(\.id))
        let extras = existing.filter { !seedIDs.contains($0.id) }
        return seed + extras
    }

    private static func loadAccount(from defaults: UserDefaults) -> KeepFitAccount? {
        guard let data = defaults.data(forKey: SyncKeys.account) else { return nil }
        return try? JSONDecoder().decode(KeepFitAccount.self, from: data)
    }

    var isICloudSyncEnabled: Bool {
        defaults.bool(forKey: SyncKeys.iCloudEnabled)
    }

    var isHealthSyncEnabled: Bool {
        defaults.bool(forKey: SyncKeys.healthEnabled)
    }

    var isSignedInWithAppleAccount: Bool {
        account.isSignedInWithApple
    }

    var appleHealthPermissionItems: [AppleHealthPermissionItem] {
        [
            AppleHealthPermissionItem(
                id: "workout",
                title: localized("体能训练", "Workouts"),
                section: .activity,
                isEnabled: shareAuthorizationStatus(for: HKObjectType.workoutType())
            ),
            AppleHealthPermissionItem(
                id: "activeEnergy",
                title: localized("运动消耗", "Exercise Burn"),
                section: .activity,
                isEnabled: shareAuthorizationStatus(for: HKObjectType.quantityType(forIdentifier: .activeEnergyBurned))
            ),
            AppleHealthPermissionItem(
                id: "dietaryEnergy",
                title: localized("饮食摄入", "Diet Intake"),
                section: .activity,
                isEnabled: shareAuthorizationStatus(for: HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed))
            ),
            AppleHealthPermissionItem(
                id: "bodyMass",
                title: localized("体重", "Weight"),
                section: .healthData,
                isEnabled: shareAuthorizationStatus(for: HKObjectType.quantityType(forIdentifier: .bodyMass))
            ),
            AppleHealthPermissionItem(
                id: "bodyFat",
                title: localized("体脂率", "Body Fat"),
                section: .healthData,
                isEnabled: shareAuthorizationStatus(for: HKObjectType.quantityType(forIdentifier: .bodyFatPercentage))
            )
        ]
    }

    var appleHealthPermissionSummaryText: String {
        if !isHealthSyncEnabled {
            return localized("未开启", "Off")
        }
        let enabledCount = appleHealthPermissionItems.filter(\.isEnabled).count
        if enabledCount > 0 {
            return localized("已开启 \(enabledCount) 项", "\(enabledCount) Enabled")
        }
        return localized("已连接", "Connected")
    }

    var isAccountChoiceUndecided: Bool {
        account.mode == .undecided
    }

    var accountDisplayTitle: String {
        if let displayName = trimmedNonEmpty(account.displayName) {
            return displayName
        }
        if let email = trimmedNonEmpty(account.email) {
            return email
        }
        switch account.mode {
        case .apple:
            return localized("Apple 账号", "Apple Account")
        case .local, .undecided:
            return localized("本地使用", "Local Mode")
        }
    }

    var accountStatusDetail: String {
        switch account.mode {
        case .apple:
            return iCloudAccountAvailable
                ? localized("已登录 Apple 账号，数据与常用设置可在同一账号下保持同步。", "Signed in with Apple. Your data and settings sync with this account.")
                : localized("已登录 Apple 账号，但当前设备未登录 iCloud。", "Signed in with Apple, but iCloud is not signed in on this device.")
        case .local:
            return localized("当前为本地使用，数据仅保存在本机。", "Currently using local mode. Your data stays on this device only.")
        case .undecided:
            return localized("请选择使用方式。", "No account mode selected yet.")
        }
    }

    var accountStatusSummary: String {
        switch account.mode {
        case .apple:
            return iCloudAccountAvailable
                ? localized("数据与设置会跟随账号同步。", "Your data and settings sync with this account.")
                : localized("当前设备未登录 iCloud。", "iCloud is not signed in on this device.")
        case .local:
            return localized("数据仅保存在本机。", "Your data stays on this device only.")
        case .undecided:
            return localized("可选择 Apple 账号或本地使用。", "Choose Apple Account or local mode.")
        }
    }

    var accountModeCaption: String {
        switch account.mode {
        case .apple:
            return localized("当前同步账号", "Current Sync Account")
        case .local:
            return localized("当前使用方式", "Current Mode")
        case .undecided:
            return localized("尚未选择", "Not Selected")
        }
    }

    func refreshICloudAvailability() {
        refreshICloudAccountAvailability()
    }

    func continueWithLocalMode() {
        persistAccount(.local)
    }

    func signOutAppleAccount() {
        persistAccount(.local)
        defaults.set(false, forKey: SyncKeys.iCloudEnabled)
        stopICloudSync()
    }

    func completeAppleSignIn(with authorization: ASAuthorization) async -> String? {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            return localized("Apple 登录返回的数据无效。", "Apple sign-in returned invalid credentials.")
        }

        let displayName = Self.string(from: credential.fullName)
        let email = trimmedNonEmpty(credential.email) ?? account.email
        let resolvedDisplayName = displayName ?? account.displayName

        let updatedAccount = KeepFitAccount(
            mode: .apple,
            userID: credential.user,
            email: email,
            displayName: resolvedDisplayName,
            lastAuthenticatedAt: Date()
        )
        persistAccount(updatedAccount)

        if let resolvedDisplayName, (profile.name.isEmpty || profile.name == UserProfile.default.name) {
            profile.name = resolvedDisplayName
        }

        if iCloudAccountAvailable {
            defaults.set(true, forKey: SyncKeys.iCloudEnabled)
            startICloudSync()
            if hasCloudSnapshot(forKey: currentCloudSnapshotKey()) {
                pullCloudSnapshotIfNeeded(force: true)
            } else {
                queueCloudPush(immediate: true)
            }
        }

        await refreshAppleCredentialStateIfNeeded()
        return nil
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        if enabled {
            refreshICloudAccountAvailability()
            guard iCloudAccountAvailable else {
                defaults.set(false, forKey: SyncKeys.iCloudEnabled)
                stopICloudSync()
                return
            }
            defaults.set(true, forKey: SyncKeys.iCloudEnabled)
            startICloudSync()
            pullCloudSnapshotIfNeeded(force: true)
            queueCloudPush(immediate: true)
        } else {
            defaults.set(false, forKey: SyncKeys.iCloudEnabled)
            stopICloudSync()
        }
    }

    func setHealthSyncEnabled(_ enabled: Bool) async -> String? {
        if enabled {
            guard HKHealthStore.isHealthDataAvailable() else {
                defaults.set(false, forKey: SyncKeys.healthEnabled)
                return localized("当前设备不支持 Apple 健康。", "Apple Health is not available on this device.")
            }
            do {
                let authorizationFlowCompleted = try await requestHealthAuthorization()
                let grantedWritePermission = await waitForAnyHealthAuthorization()
                let effectiveGranted = authorizationFlowCompleted || grantedWritePermission

                guard effectiveGranted else {
                    defaults.set(false, forKey: SyncKeys.healthEnabled)
                    return localized(
                        "未获得 Apple 健康权限。请在授权界面或健康 App 中至少开启一项 KeepFit 需要的项目后再试。",
                        "No Apple Health permission was granted. Please allow at least one KeepFit health item in the authorization screen or Health app and try again."
                    )
                }
                defaults.set(true, forKey: SyncKeys.healthEnabled)
                hadKnownHealthWriteAuthorization = grantedWritePermission
                await startHealthObserversIfNeeded()
                startHealthPollingIfNeeded()
                await syncHealthDataIfEnabled()
                return nil
            } catch {
                defaults.set(false, forKey: SyncKeys.healthEnabled)
                hadKnownHealthWriteAuthorization = false
                return localized("健康数据授权失败，请稍后重试。", "Failed to authorize Apple Health. Please try again.")
            }
        }

        defaults.set(false, forKey: SyncKeys.healthEnabled)
        hadKnownHealthWriteAuthorization = false
        pendingHealthSyncTask?.cancel()
        stopHealthPolling()
        stopHealthObservers()
        return nil
    }

    @discardableResult
    func refreshHealthSyncEffectiveState() -> Bool {
        guard defaults.bool(forKey: SyncKeys.healthEnabled) else {
            hadKnownHealthWriteAuthorization = false
            return false
        }
        guard HKHealthStore.isHealthDataAvailable() else {
            defaults.set(false, forKey: SyncKeys.healthEnabled)
            hadKnownHealthWriteAuthorization = false
            stopHealthPolling()
            stopHealthObservers()
            return false
        }

        let currentlyHasWriteAuthorization = hasAnyHealthAuthorization()
        if hadKnownHealthWriteAuthorization && !currentlyHasWriteAuthorization {
            defaults.set(false, forKey: SyncKeys.healthEnabled)
            hadKnownHealthWriteAuthorization = false
            pendingHealthSyncTask?.cancel()
            stopHealthPolling()
            stopHealthObservers()
            return false
        }

        if currentlyHasWriteAuthorization {
            hadKnownHealthWriteAuthorization = true
        }
        return defaults.bool(forKey: SyncKeys.healthEnabled)
    }

    func syncHealthDataIfEnabled() async {
        guard isHealthSyncEnabled else { return }
        await runHealthSync()
    }

    func addFoodLog(date: Date, item: FoodItem, grams: Double) {
        guard grams > 0 else { return }
        guard !date.isFutureDayInCurrentCalendar else { return }
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
        guard !date.isFutureDayInCurrentCalendar else { return }
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
        guard !date.isFutureDayInCurrentCalendar else { return }
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

    @discardableResult
    func deleteBodyMetric(on date: Date) -> Bool {
        let day = date.startOfDayInCurrentCalendar
        let originalCount = bodyMetricLogs.count
        bodyMetricLogs.removeAll(where: { $0.date.startOfDayInCurrentCalendar == day })
        let deleted = bodyMetricLogs.count != originalCount
        if deleted, let latestRemaining = bodyMetricLogs.max(by: { $0.date < $1.date }) {
            profile.weightKg = latestRemaining.weightKg
        }
        return deleted
    }

    func deleteFoodLog(_ log: FoodLog) {
        foodLogs.removeAll(where: { $0.id == log.id })
    }

    func deleteExerciseLog(_ log: ExerciseLog) {
        exerciseLogs.removeAll(where: { $0.id == log.id })
    }

    var earliestRecordedDate: Date? {
        recordedDataOverview.earliestDate
    }

    var latestRecordedDate: Date? {
        recordedDataOverview.latestDate
    }

    var allRecordedDataSummary: DataDeletionSummary {
        recordedDataOverview.summary
    }

    func recordedDataSummary(startDate: Date, endDate: Date) -> DataDeletionSummary {
        let range = normalizedDeletionRange(startDate: startDate, endDate: endDate)
        if let earliest = recordedDataOverview.earliestDate,
           let latest = recordedDataOverview.latestDate,
           range.lowerBound <= earliest,
           range.upperBound >= latest {
            return recordedDataOverview.summary
        }
        let foodCount = foodLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }.count
        let exerciseCount = exerciseLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }.count
        let bodyMetricCount = bodyMetricLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }.count
        return DataDeletionSummary(
            foodLogCount: foodCount,
            exerciseLogCount: exerciseCount,
            bodyMetricCount: bodyMetricCount
        )
    }

    @discardableResult
    func deleteAllRecordedData() -> DataDeletionSummary {
        let summary = DataDeletionSummary(
            foodLogCount: foodLogs.count,
            exerciseLogCount: exerciseLogs.count,
            bodyMetricCount: bodyMetricLogs.count
        )
        guard summary.totalCount > 0 else { return summary }

        let deletedFoodLogs = foodLogs
        let deletedExerciseLogs = exerciseLogs
        let deletedBodyMetrics = bodyMetricLogs

        foodLogs = []
        exerciseLogs = []
        bodyMetricLogs = []
        pruneHealthSyncState(
            deletedFoodLogs: deletedFoodLogs,
            deletedExerciseLogs: deletedExerciseLogs,
            deletedBodyMetrics: deletedBodyMetrics
        )
        syncProfileWeightAfterBodyMetricDeletion()
        return summary
    }

    @discardableResult
    func deleteRecordedData(startDate: Date, endDate: Date) -> DataDeletionSummary {
        let range = normalizedDeletionRange(startDate: startDate, endDate: endDate)
        let deletedFoodLogs = foodLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }
        let deletedExerciseLogs = exerciseLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }
        let deletedBodyMetrics = bodyMetricLogs.filter { range.contains($0.date.startOfDayInCurrentCalendar) }

        let summary = DataDeletionSummary(
            foodLogCount: deletedFoodLogs.count,
            exerciseLogCount: deletedExerciseLogs.count,
            bodyMetricCount: deletedBodyMetrics.count
        )
        guard summary.totalCount > 0 else { return summary }

        foodLogs.removeAll { range.contains($0.date.startOfDayInCurrentCalendar) }
        exerciseLogs.removeAll { range.contains($0.date.startOfDayInCurrentCalendar) }
        bodyMetricLogs.removeAll { range.contains($0.date.startOfDayInCurrentCalendar) }
        pruneHealthSyncState(
            deletedFoodLogs: deletedFoodLogs,
            deletedExerciseLogs: deletedExerciseLogs,
            deletedBodyMetrics: deletedBodyMetrics
        )
        syncProfileWeightAfterBodyMetricDeletion()
        return summary
    }

    func foodIcon(for food: FoodItem) -> String {
        if !food.icon.isEmpty {
            return food.icon
        }
        return IconCatalog.foodIcon(id: food.id, category: food.category)
    }

    func foodDisplayName(for food: FoodItem) -> String {
        displayName(id: food.id, chinese: food.name)
    }

    func foodDisplayName(forFoodID foodID: String, fallback: String? = nil) -> String {
        if let item = foodLibrary.first(where: { $0.id == foodID }) {
            return displayName(id: foodID, chinese: item.name)
        }
        if let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallback
        }
        return AppPreferences.language == .english ? englishDisplayName(from: foodID) : foodID
    }

    func foodIcon(forFoodID foodID: String) -> String {
        if let item = foodLibrary.first(where: { $0.id == foodID }) {
            return foodIcon(for: item)
        }
        return IconCatalog.foodIcon(id: foodID, category: .staple)
    }

    func exerciseIcon(for exercise: ExerciseItem) -> String {
        if !exercise.icon.isEmpty {
            return exercise.icon
        }
        return IconCatalog.exerciseIcon(id: exercise.id, category: exercise.category)
    }

    func exerciseDisplayName(for exercise: ExerciseItem) -> String {
        displayName(id: exercise.id, chinese: exercise.name)
    }

    func exerciseDisplayName(forExerciseID exerciseID: String, fallback: String? = nil) -> String {
        if let item = exerciseLibrary.first(where: { $0.id == exerciseID }) {
            return displayName(id: exerciseID, chinese: item.name)
        }
        if let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fallback
        }
        return AppPreferences.language == .english ? englishDisplayName(from: exerciseID) : exerciseID
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
        dailyMetricsCache.foodLogsByDay[date.startOfDayInCurrentCalendar] ?? []
    }

    func exerciseLogs(on date: Date) -> [ExerciseLog] {
        dailyMetricsCache.exerciseLogsByDay[date.startOfDayInCurrentCalendar] ?? []
    }

    func dayNutrition(on date: Date) -> DayNutritionSummary {
        dailyMetricsCache.nutritionByDay[date.startOfDayInCurrentCalendar]
            ?? DayNutritionSummary(calories: 0, protein: 0, carbs: 0, fat: 0)
    }

    func dayExercise(on date: Date) -> DayFitnessSummary {
        dailyMetricsCache.exerciseByDay[date.startOfDayInCurrentCalendar]
            ?? DayFitnessSummary(caloriesBurned: 0, durationMinutes: 0)
    }

    func hasAnyFoodOrExerciseRecord(on date: Date) -> Bool {
        dailyMetricsCache.daysWithAnyActivity.contains(date.startOfDayInCurrentCalendar)
    }

    func hasFoodRecord(on date: Date) -> Bool {
        dailyMetricsCache.foodLogsByDay[date.startOfDayInCurrentCalendar] != nil
    }

    func hasExerciseRecord(on date: Date) -> Bool {
        dailyMetricsCache.exerciseLogsByDay[date.startOfDayInCurrentCalendar] != nil
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

    func foodReminderBody(on date: Date) -> String {
        let day = date.startOfDayInCurrentCalendar
        let logs = foodLogs(on: day)
        let summary = dayNutrition(on: day)
        let target = profile.recommendedIntakeForFatLoss
        let remaining = target - summary.calories
        let intakeText = energyText(fromKcal: summary.calories)
        let targetText = energyText(fromKcal: target)

        if AppPreferences.language == .english {
            if logs.isEmpty {
                return "No meal logs today. Intake \(intakeText) / target \(targetText). Log your first meal to keep intake on track."
            }
            if remaining > 250 {
                return "Logged \(logs.count) meals, intake \(intakeText) / target \(targetText). About \(energyText(fromKcal: remaining)) left, prioritize protein and vegetables."
            }
            if remaining >= 0 {
                return "Logged \(logs.count) meals, intake \(intakeText) / target \(targetText). Intake is near target; keep your next meal lighter."
            }
            return "Logged \(logs.count) meals, intake \(intakeText) / target \(targetText). Over target by \(energyText(fromKcal: abs(remaining))); avoid extra snacks."
        }

        if logs.isEmpty {
            return "今天还没有饮食记录，当前摄入\(intakeText)/目标\(targetText)，先记录第一餐更好控制全天摄入。"
        }
        if remaining > 250 {
            return "今天已记录\(logs.count)餐，已摄入\(intakeText)/目标\(targetText)，还可摄入约\(energyText(fromKcal: remaining))，优先蛋白和蔬菜。"
        }
        if remaining >= 0 {
            return "今天已记录\(logs.count)餐，已摄入\(intakeText)/目标\(targetText)，已接近目标，下一餐建议清淡高蛋白。"
        }
        return "今天已记录\(logs.count)餐，已摄入\(intakeText)/目标\(targetText)，已超目标约\(energyText(fromKcal: abs(remaining)))，后续建议避免加餐。"
    }

    func exerciseReminderBody(on date: Date) -> String {
        let day = date.startOfDayInCurrentCalendar
        let logs = exerciseLogs(on: day)
        let summary = dayExercise(on: day)
        let goal = max(profile.dailyExerciseGoal, 1)
        let remaining = goal - summary.caloriesBurned
        let burnedText = energyText(fromKcal: summary.caloriesBurned)
        let goalText = energyText(fromKcal: goal)
        let durationText = durationDisplayText(fromMinutes: summary.durationMinutes)

        if AppPreferences.language == .english {
            if logs.isEmpty {
                return "No workout logs today. Burn \(burnedText) / goal \(goalText). Start with 20-30 min walk or cardio."
            }
            if remaining > 120 {
                return "Logged \(logs.count) workouts, burn \(burnedText) in \(durationText) / goal \(goalText). About \(energyText(fromKcal: remaining)) left."
            }
            if remaining > 0 {
                return "Logged \(logs.count) workouts, burn \(burnedText) in \(durationText) / goal \(goalText). You're close to goal; add 10-15 min."
            }
            return "Logged \(logs.count) workouts, burn \(burnedText) in \(durationText) / goal \(goalText). Goal achieved; keep recovery and stretching."
        }

        if logs.isEmpty {
            return "今天还没有运动记录，当前消耗\(burnedText)/目标\(goalText)，建议先完成 20-30 min 快走或有氧。"
        }
        if remaining > 120 {
            return "今天已记录\(logs.count)次运动，消耗\(burnedText)，时长\(durationText)/目标\(goalText)，还差约\(energyText(fromKcal: remaining))。"
        }
        if remaining > 0 {
            return "今天已记录\(logs.count)次运动，消耗\(burnedText)，时长\(durationText)/目标\(goalText)，你已接近目标，再补 10-15 min 即可。"
        }
        return "今天已记录\(logs.count)次运动，消耗\(burnedText)，时长\(durationText)/目标\(goalText)，今日目标已达成，注意拉伸恢复。"
    }

    func dailySummaryReminderBody(on date: Date) -> String {
        let day = date.startOfDayInCurrentCalendar
        let nutrition = dayNutrition(on: day)
        let exercise = dayExercise(on: day)
        let maintenance = profile.dailyMaintenanceCalories
        let balance = dailyBalance(on: day) // intake - (maintenance + exercise)

        let intakeText = energyText(fromKcal: nutrition.calories)
        let exerciseText = energyText(fromKcal: exercise.caloriesBurned)
        let maintenanceText = energyText(fromKcal: maintenance)
        let balanceText = energyText(fromKcal: abs(balance))

        if AppPreferences.language == .english {
            if nutrition.calories <= 0.01 && exercise.caloriesBurned <= 0.01 {
                return "No logs today yet. Add your meals and workouts first for an accurate summary."
            }

            let head = "Intake \(intakeText), exercise \(exerciseText), maintenance \(maintenanceText)."
            if balance <= -300 {
                return "\(head) Deficit \(balanceText) today. Great pace for fat loss, keep protein and sleep on track."
            }
            if balance < 0 {
                return "\(head) Mild deficit \(balanceText). Good control today, keep hydration and recovery."
            }
            if balance <= 200 {
                return "\(head) Nearly balanced today. Keep dinner lighter to secure tomorrow's deficit."
            }
            return "\(head) Surplus \(balanceText) today. Add light cardio/walking and tighten intake tomorrow."
        }

        if nutrition.calories <= 0.01 && exercise.caloriesBurned <= 0.01 {
            return "今天还没有有效记录，建议先补充饮食和运动数据，才能得到准确总结。"
        }

        let head = "摄入\(intakeText)，运动\(exerciseText)，维持\(maintenanceText)。"
        if balance <= -300 {
            return "\(head) 今日赤字\(balanceText)，减脂节奏很好，继续保持蛋白和睡眠。"
        }
        if balance < 0 {
            return "\(head) 今日小幅赤字\(balanceText)，控制不错，注意补水与恢复。"
        }
        if balance <= 200 {
            return "\(head) 今日接近平衡，晚间尽量清淡，帮助明天进入赤字。"
        }
        return "\(head) 今日超量\(balanceText)，建议补充步行/轻有氧，明天适当控制摄入。"
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
        Array(dailyMetricsCache.dailyNutritionRecordsDescending.prefix(limit))
    }

    func dailyNutritionRecords(inMonthOf date: Date) -> [DailyNutritionRecord] {
        let calendar = AppPreferences.calendar
        return dailyMetricsCache.dailyNutritionRecordsDescending.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
    }

    func dailyExerciseRecords(limit: Int = 30) -> [DailyExerciseRecord] {
        Array(dailyMetricsCache.dailyExerciseRecordsDescending.prefix(limit))
    }

    func dailyExerciseRecords(inMonthOf date: Date) -> [DailyExerciseRecord] {
        let calendar = AppPreferences.calendar
        return dailyMetricsCache.dailyExerciseRecordsDescending.filter {
            calendar.isDate($0.date, equalTo: date, toGranularity: .month)
        }
    }

    func calorieTrends(days: Int = 30) -> [DailyCalorieTrend] {
        let calendar = AppPreferences.calendar
        let today = Date().startOfDayInCurrentCalendar
        guard let earliestIncludedDay = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today) else {
            return dailyMetricsCache.calorieTrendsAscending
        }
        return dailyMetricsCache.calorieTrendsAscending.filter { $0.date >= earliestIncludedDay && $0.date <= today }
    }

    func weightTrends(limit: Int = 60) -> [BodyMetricLog] {
        Array(dailyMetricsCache.bodyMetricsAscending.suffix(limit))
    }

    func latestBodyMetric() -> BodyMetricLog {
        bodyMetricLogs.sorted(by: { $0.date > $1.date }).first
            ?? BodyMetricLog(id: UUID(), date: Date(), weightKg: profile.weightKg, bodyFatPercent: profile.targetBodyFat + 8)
    }

    func latestBodyMetric(on date: Date) -> BodyMetricLog? {
        dailyMetricsCache.latestBodyMetricByDay[date.startOfDayInCurrentCalendar]
    }

    private func handleLocalStateDidChange() {
        guard !isApplyingCloudSnapshot else { return }
        localMutationAt = Date()
        defaults.set(localMutationAt.timeIntervalSince1970, forKey: SyncKeys.localMutationTS)
        queueCloudPush()
    }

    func noteSettingsDidChange(refreshReminders: Bool = false) {
        guard !isApplyingCloudSnapshot else { return }
        localMutationAt = Date()
        defaults.set(localMutationAt.timeIntervalSince1970, forKey: SyncKeys.localMutationTS)
        if refreshReminders {
            refreshDynamicRemindersIfNeeded()
        }
        queueCloudPush()
    }

    func refreshReminderSchedules() {
        refreshDynamicRemindersIfNeeded()
    }

    private struct ReminderScheduleConfig {
        let enabled: Bool
        let identifier: String
        let title: String
        let minuteOfDay: Int
        let kind: ReminderKind
    }

    private struct ReminderScheduleEntry {
        let identifier: String
        let title: String
        let body: String
        let fireDate: Date
    }

    private enum ReminderKind {
        case food
        case exercise
        case summary
    }

    private func refreshDynamicRemindersIfNeeded() {
        let now = Date()
        let configs = reminderScheduleConfigs(for: now)
        let center = UNUserNotificationCenter.current()
        let identifiersToClear = reminderIdentifiersToClear(referenceDate: now, horizonDays: ReminderKeys.schedulingHorizonDays)
        center.removePendingNotificationRequests(withIdentifiers: identifiersToClear)
        center.removeDeliveredNotifications(withIdentifiers: identifiersToClear)

        let enabledEntries = configs
            .filter(\.enabled)
            .flatMap { scheduledReminderEntries(for: $0, referenceDate: now, horizonDays: ReminderKeys.schedulingHorizonDays) }
        guard !enabledEntries.isEmpty else { return }

        center.getNotificationSettings { settings in
            let authorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                authorized = true
            default:
                authorized = false
            }
            guard authorized else { return }

            for entry in enabledEntries {
                let components = AppPreferences.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: entry.fireDate)
                let content = UNMutableNotificationContent()
                content.title = entry.title
                content.body = entry.body
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                let request = UNNotificationRequest(identifier: entry.identifier, content: content, trigger: trigger)

                center.add(request) { _ in }
            }
        }
    }

    private func reminderScheduleConfigs(for _: Date) -> [ReminderScheduleConfig] {
        [
            ReminderScheduleConfig(
                enabled: reminderEnabled(forKey: ReminderKeys.foodEnabled, defaultValue: true),
                identifier: ReminderKeys.foodIdentifier,
                title: localized("饮食提醒", "Diet Reminder"),
                minuteOfDay: reminderMinuteOfDay(forKey: ReminderKeys.foodMinuteOfDay, defaultValue: 12 * 60),
                kind: .food
            ),
            ReminderScheduleConfig(
                enabled: reminderEnabled(forKey: ReminderKeys.exerciseEnabled, defaultValue: true),
                identifier: ReminderKeys.exerciseIdentifier,
                title: localized("运动提醒", "Exercise Reminder"),
                minuteOfDay: reminderMinuteOfDay(forKey: ReminderKeys.exerciseMinuteOfDay, defaultValue: 19 * 60),
                kind: .exercise
            ),
            ReminderScheduleConfig(
                enabled: reminderEnabled(forKey: ReminderKeys.summaryEnabled, defaultValue: true),
                identifier: ReminderKeys.summaryIdentifier,
                title: localized("每日总结", "Daily Summary"),
                minuteOfDay: reminderMinuteOfDay(forKey: ReminderKeys.summaryMinuteOfDay, defaultValue: 21 * 60 + 30),
                kind: .summary
            )
        ]
    }

    private func scheduledReminderEntries(
        for config: ReminderScheduleConfig,
        referenceDate: Date,
        horizonDays: Int
    ) -> [ReminderScheduleEntry] {
        reminderFireDates(minuteOfDay: config.minuteOfDay, referenceDate: referenceDate, horizonDays: horizonDays)
            .map { fireDate in
                ReminderScheduleEntry(
                    identifier: reminderIdentifier(for: config.identifier, fireDate: fireDate),
                    title: config.title,
                    body: reminderBody(for: config.kind, on: fireDate),
                    fireDate: fireDate
                )
            }
    }

    private func reminderFireDates(minuteOfDay: Int, referenceDate: Date, horizonDays: Int) -> [Date] {
        let calendar = AppPreferences.calendar
        let startDay = referenceDate.startOfDayInCurrentCalendar
        let minimumDate = referenceDate.addingTimeInterval(5)

        return (0..<max(horizonDays, 1)).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let fireDate = calendar.date(
                    bySettingHour: minuteOfDay / 60,
                    minute: minuteOfDay % 60,
                    second: 0,
                    of: day
                  )
            else {
                return nil
            }
            return fireDate >= minimumDate ? fireDate : nil
        }
    }

    private func reminderIdentifiersToClear(referenceDate: Date, horizonDays: Int) -> [String] {
        let calendar = AppPreferences.calendar
        let reminderBases = [
            ReminderKeys.foodIdentifier,
            ReminderKeys.exerciseIdentifier,
            ReminderKeys.summaryIdentifier
        ]

        var identifiers = Set(reminderBases)
        let startDay = referenceDate.startOfDayInCurrentCalendar
        for offset in -1...(horizonDays + 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            for base in reminderBases {
                identifiers.insert(reminderIdentifier(for: base, fireDate: day))
            }
        }
        return Array(identifiers)
    }

    private func reminderIdentifier(for baseIdentifier: String, fireDate: Date) -> String {
        let components = AppPreferences.calendar.dateComponents([.year, .month, .day], from: fireDate)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return "\(baseIdentifier).\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }

    private func reminderBody(for kind: ReminderKind, on date: Date) -> String {
        switch kind {
        case .food:
            return foodReminderBody(on: date)
        case .exercise:
            return exerciseReminderBody(on: date)
        case .summary:
            return dailySummaryReminderBody(on: date)
        }
    }

    private func reminderEnabled(forKey key: String, defaultValue: Bool) -> Bool {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return defaults.bool(forKey: key)
    }

    private func reminderMinuteOfDay(forKey key: String, defaultValue: Int) -> Int {
        if defaults.object(forKey: key) == nil {
            return defaultValue
        }
        return min(max(defaults.integer(forKey: key), 0), 1439)
    }

    private func setupForegroundObserver() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshICloudAccountAvailability()
                self.refreshDynamicRemindersIfNeeded()
                self.pullCloudSnapshotIfNeeded(force: false)
                await self.syncHealthDataIfEnabled()
            }
        }
    }

    private func setupCalendarDayChangedObserver() {
        dayChangedObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshDynamicRemindersIfNeeded()
            }
        }
    }

    private func setupHealthActivityObservers() {
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.refreshHealthSyncEffectiveState() else { return }
                self.startHealthPollingIfNeeded()
                await self.syncHealthDataIfEnabled()
            }
        }

        didEnterBackgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopHealthPolling()
            }
        }
    }

    private func setupUbiquityIdentityObserver() {
        ubiquityIdentityObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.NSUbiquityIdentityDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshICloudAccountAvailability()
            }
        }
    }

    private func refreshICloudAccountAvailability() {
        iCloudAccountAvailable = FileManager.default.ubiquityIdentityToken != nil
        if !iCloudAccountAvailable, isICloudSyncEnabled {
            defaults.set(false, forKey: SyncKeys.iCloudEnabled)
            stopICloudSync()
        }
    }

    private func persistAccount(_ value: KeepFitAccount) {
        account = value
        if let data = try? JSONEncoder().encode(value) {
            defaults.set(data, forKey: SyncKeys.account)
        }
    }

    private static func string(from nameComponents: PersonNameComponents?) -> String? {
        guard let nameComponents else { return nil }
        let value = PersonNameComponentsFormatter().string(from: nameComponents).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func trimmedNonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func currentCloudSnapshotKey() -> String {
        guard account.isSignedInWithApple, let userID = trimmedNonEmpty(account.userID) else {
            return SyncKeys.cloudSnapshot
        }
        return "\(SyncKeys.cloudSnapshotAccountPrefix)\(stableHashHex(of: userID)).v1"
    }

    private func hasCloudSnapshot(forKey key: String) -> Bool {
        iCloudStore.data(forKey: key) != nil
    }

    private func currentSettingsSnapshot() -> KeepFitSettingsSnapshot {
        KeepFitSettingsSnapshot(
            themeModeRaw: defaults.string(forKey: PreferenceKeys.themeMode) ?? AppThemeMode.system.rawValue,
            energyUnitRaw: defaults.string(forKey: PreferenceKeys.energyUnit) ?? EnergyUnitOption.kcal.rawValue,
            heightUnitRaw: defaults.string(forKey: PreferenceKeys.heightUnit) ?? HeightUnitOption.centimeter.rawValue,
            weightUnitRaw: defaults.string(forKey: PreferenceKeys.weightUnit) ?? WeightUnitOption.kilogram.rawValue,
            weekStartRaw: defaults.string(forKey: PreferenceKeys.weekStart) ?? WeekStartOption.sunday.rawValue,
            appLanguageRaw: defaults.string(forKey: PreferenceKeys.appLanguage) ?? AppLanguageOption.chinese.rawValue,
            birthDateTimestamp: defaults.double(forKey: PreferenceKeys.birthDateTimestamp),
            hapticEnabled: defaults.object(forKey: PreferenceKeys.hapticEnabled) as? Bool ?? true,
            foodReminderEnabled: defaults.object(forKey: PreferenceKeys.foodReminderEnabled) as? Bool ?? true,
            exerciseReminderEnabled: defaults.object(forKey: PreferenceKeys.exerciseReminderEnabled) as? Bool ?? true,
            dailySummaryEnabled: defaults.object(forKey: PreferenceKeys.dailySummaryEnabled) as? Bool ?? true,
            foodReminderMinuteOfDay: defaults.object(forKey: PreferenceKeys.foodReminderMinuteOfDay) as? Int ?? 12 * 60,
            exerciseReminderMinuteOfDay: defaults.object(forKey: PreferenceKeys.exerciseReminderMinuteOfDay) as? Int ?? 19 * 60,
            summaryReminderMinuteOfDay: defaults.object(forKey: PreferenceKeys.summaryReminderMinuteOfDay) as? Int ?? 21 * 60 + 30
        )
    }

    private func applySettingsSnapshot(_ snapshot: KeepFitSettingsSnapshot) {
        defaults.set(snapshot.themeModeRaw, forKey: PreferenceKeys.themeMode)
        defaults.set(snapshot.energyUnitRaw, forKey: PreferenceKeys.energyUnit)
        defaults.set(snapshot.heightUnitRaw, forKey: PreferenceKeys.heightUnit)
        defaults.set(snapshot.weightUnitRaw, forKey: PreferenceKeys.weightUnit)
        defaults.set(snapshot.weekStartRaw, forKey: PreferenceKeys.weekStart)
        defaults.set(snapshot.appLanguageRaw, forKey: PreferenceKeys.appLanguage)
        defaults.set(snapshot.birthDateTimestamp, forKey: PreferenceKeys.birthDateTimestamp)
        defaults.set(snapshot.hapticEnabled, forKey: PreferenceKeys.hapticEnabled)
        defaults.set(snapshot.foodReminderEnabled, forKey: PreferenceKeys.foodReminderEnabled)
        defaults.set(snapshot.exerciseReminderEnabled, forKey: PreferenceKeys.exerciseReminderEnabled)
        defaults.set(snapshot.dailySummaryEnabled, forKey: PreferenceKeys.dailySummaryEnabled)
        defaults.set(snapshot.foodReminderMinuteOfDay, forKey: PreferenceKeys.foodReminderMinuteOfDay)
        defaults.set(snapshot.exerciseReminderMinuteOfDay, forKey: PreferenceKeys.exerciseReminderMinuteOfDay)
        defaults.set(snapshot.summaryReminderMinuteOfDay, forKey: PreferenceKeys.summaryReminderMinuteOfDay)
        refreshDynamicRemindersIfNeeded()
    }

    private func refreshAppleCredentialStateIfNeeded() async {
        guard account.isSignedInWithApple, let userID = trimmedNonEmpty(account.userID) else { return }
        let provider = ASAuthorizationAppleIDProvider()

        do {
            let state = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorizationAppleIDProvider.CredentialState, Error>) in
                provider.getCredentialState(forUserID: userID) { credentialState, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: credentialState)
                }
            }

            switch state {
            case .authorized:
                break
            case .revoked, .notFound, .transferred:
                signOutAppleAccount()
            @unknown default:
                break
            }
        } catch {
            // Ignore transient credential-state lookup failures on simulator/offline devices.
        }
    }

    private func startICloudSync() {
        guard iCloudAccountAvailable else { return }
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
        guard isICloudSyncEnabled, iCloudAccountAvailable, !isApplyingCloudSnapshot else { return }
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
        guard isICloudSyncEnabled, iCloudAccountAvailable, !isApplyingCloudSnapshot else { return }
        let snapshot = KeepFitCloudSnapshot(
            version: 2,
            modifiedAt: localMutationAt == .distantPast ? Date() : localMutationAt,
            settings: currentSettingsSnapshot(),
            profile: profile,
            foodLibrary: foodLibrary,
            exerciseLibrary: exerciseLibrary,
            foodLogs: foodLogs,
            exerciseLogs: exerciseLogs,
            bodyMetricLogs: bodyMetricLogs
        )
        guard let data = try? cloudEncoder.encode(snapshot) else { return }
        iCloudStore.set(data, forKey: currentCloudSnapshotKey())
        iCloudStore.synchronize()
    }

    private func pullCloudSnapshotIfNeeded(force: Bool) {
        guard isICloudSyncEnabled, iCloudAccountAvailable else { return }
        guard let data = iCloudStore.data(forKey: currentCloudSnapshotKey()) else { return }
        guard let snapshot = try? cloudDecoder.decode(KeepFitCloudSnapshot.self, from: data) else { return }
        guard (1...2).contains(snapshot.version) else { return }

        let remoteTS = snapshot.modifiedAt.timeIntervalSince1970
        let localTS = localMutationAt.timeIntervalSince1970
        guard force || remoteTS > localTS + 1 else { return }

        isApplyingCloudSnapshot = true
        defer { isApplyingCloudSnapshot = false }

        profile = snapshot.profile
        if let settings = snapshot.settings {
            applySettingsSnapshot(settings)
        }
        foodLibrary = Self.mergeFoodLibrary(snapshot.foodLibrary, with: SeedData.foodLibrary)
        exerciseLibrary = Self.mergeExerciseLibrary(snapshot.exerciseLibrary, with: SeedData.exerciseLibrary)
        foodLogs = snapshot.foodLogs.sorted(by: { $0.date > $1.date })
        exerciseLogs = snapshot.exerciseLogs.sorted(by: { $0.date > $1.date })
        bodyMetricLogs = snapshot.bodyMetricLogs.sorted(by: { $0.date < $1.date })
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
            try await importHealthDataIntoKeepFit()
        } catch {
            logHealthSyncError(stage: "import", error: error)
        }

        do {
            try await exportUnsyncedLocalDataToHealth()
        } catch {
            logHealthSyncError(stage: "export", error: error)
        }
    }

    private func logHealthSyncError(stage: String, error: Error) {
        #if DEBUG
        print("KeepFit Apple Health \(stage) failed: \(error.localizedDescription)")
        #endif
    }

    private var healthObserverTypes: [HKSampleType] {
        var types: [HKSampleType] = [HKObjectType.workoutType()]
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.append(dietary)
        }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.append(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.append(bodyFat)
        }
        return types
    }

    private func startHealthObserversIfNeeded() async {
        guard isHealthSyncEnabled, HKHealthStore.isHealthDataAvailable() else { return }
        guard healthObserverQueries.isEmpty else { return }

        for sampleType in healthObserverTypes {
            let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, completionHandler, error in
                completionHandler()
                guard error == nil else { return }
                Task { @MainActor [weak self] in
                    await self?.syncHealthDataIfEnabled()
                }
            }
            healthStore.execute(query)
            healthObserverQueries.append(query)
            try? await enableHealthBackgroundDelivery(for: sampleType)
        }
    }

    private func stopHealthObservers() {
        for query in healthObserverQueries {
            healthStore.stop(query)
        }
        healthObserverQueries.removeAll()

        for sampleType in healthObserverTypes {
            healthStore.disableBackgroundDelivery(for: sampleType) { _, _ in }
        }
    }

    private func startHealthPollingIfNeeded() {
        guard isHealthSyncEnabled, UIApplication.shared.applicationState == .active else { return }
        guard healthPollingTask == nil else { return }

        healthPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                // Foreground fallback for simulator/reliability: keep Health import responsive.
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    guard let self, UIApplication.shared.applicationState == .active else { return }
                    Task { @MainActor [weak self] in
                        await self?.syncHealthDataIfEnabled()
                    }
                }
            }
        }
    }

    private func stopHealthPolling() {
        healthPollingTask?.cancel()
        healthPollingTask = nil
    }

    private func enableHealthBackgroundDelivery(for sampleType: HKSampleType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "KeepFit.HealthKit",
                            code: -3,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to enable background delivery."]
                        )
                    )
                }
            }
        }
    }

    private func requestHealthAuthorization() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: healthWriteTypes, read: healthReadTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard success else {
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: true)
            }
        }
    }

    private func hasAnyHealthAuthorization() -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        return healthToggleEligibleShareTypes.contains { sampleType in
            healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized
        }
    }

    private func waitForAnyHealthAuthorization(
        attempts: Int = 5,
        delayNanoseconds: UInt64 = 250_000_000
    ) async -> Bool {
        for attempt in 0..<attempts {
            if hasAnyHealthAuthorization() {
                return true
            }
            guard attempt < attempts - 1 else { break }
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return hasAnyHealthAuthorization()
    }

    private var healthToggleEligibleShareTypes: [HKSampleType] {
        var types: [HKSampleType] = [HKObjectType.workoutType()]
        if let dietary = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            types.append(dietary)
        }
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.append(activeEnergy)
        }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.append(bodyMass)
        }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) {
            types.append(bodyFat)
        }
        return types
    }

    private func shareAuthorizationStatus(for sampleType: HKSampleType?) -> Bool {
        guard let sampleType, HKHealthStore.isHealthDataAvailable() else { return false }
        return healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized
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
        if let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(activeEnergy) }
        if let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass) { types.insert(bodyMass) }
        if let bodyFat = HKObjectType.quantityType(forIdentifier: .bodyFatPercentage) { types.insert(bodyFat) }
        return types
    }

    private struct HealthFoodImportDescriptor {
        let id: String
        let name: String
    }

    private struct HealthWorkoutImportDescriptor {
        let id: String
        let name: String
        let defaultMET: Double
    }

    private func normalizedLookupKey(_ value: String) -> String {
        let scalars = value.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalars)).lowercased()
    }

    private func stableHashHex(of value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return String(hash, radix: 16)
    }

    private func matchedFoodItem(for healthFoodName: String) -> FoodItem? {
        let key = normalizedLookupKey(healthFoodName)
        guard !key.isEmpty else { return nil }

        if let exactChinese = foodLibrary.first(where: { normalizedLookupKey($0.name) == key }) {
            return exactChinese
        }

        if let exactEnglish = foodLibrary.first(where: { normalizedLookupKey(englishDisplayName(from: $0.id)) == key }) {
            return exactEnglish
        }

        if let fuzzyChinese = foodLibrary.first(where: {
            let itemKey = normalizedLookupKey($0.name)
            return !itemKey.isEmpty && (key.contains(itemKey) || itemKey.contains(key))
        }) {
            return fuzzyChinese
        }

        if let fuzzyEnglish = foodLibrary.first(where: {
            let itemKey = normalizedLookupKey(englishDisplayName(from: $0.id))
            return !itemKey.isEmpty && (key.contains(itemKey) || itemKey.contains(key))
        }) {
            return fuzzyEnglish
        }

        return nil
    }

    private func resolveHealthFoodDescriptor(from sample: HKQuantitySample) -> HealthFoodImportDescriptor {
        let foodType = (sample.metadata?[HKMetadataKeyFoodType] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let foodType, !foodType.isEmpty {
            if let matched = matchedFoodItem(for: foodType) {
                return HealthFoodImportDescriptor(id: matched.id, name: matched.name)
            }
            return HealthFoodImportDescriptor(
                id: "apple_health_food_\(stableHashHex(of: foodType))",
                name: foodType
            )
        }

        let sourceName = sample.sourceRevision.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sourceName.isEmpty {
            return HealthFoodImportDescriptor(
                id: "apple_health_food_source_\(stableHashHex(of: sourceName))",
                name: localized("饮食摄入 · \(sourceName)", "Food Intake · \(sourceName)")
            )
        }

        return HealthFoodImportDescriptor(
            id: "apple_health_food_unknown",
            name: localized("饮食摄入", "Food Intake")
        )
    }

    private func mappedExerciseDescriptor(
        preferredIDs: [String],
        fallbackChinese: String,
        fallbackEnglish: String,
        defaultMET: Double
    ) -> HealthWorkoutImportDescriptor {
        for id in preferredIDs {
            if let item = exerciseLibrary.first(where: { $0.id == id }) {
                return HealthWorkoutImportDescriptor(id: item.id, name: item.name, defaultMET: item.met)
            }
        }

        let fallbackID = preferredIDs.first ?? "apple_health_workout_generic"
        return HealthWorkoutImportDescriptor(
            id: fallbackID,
            name: localized(fallbackChinese, fallbackEnglish),
            defaultMET: defaultMET
        )
    }

    private func resolveHealthWorkoutDescriptor(from workout: HKWorkout) -> HealthWorkoutImportDescriptor {
        switch workout.workoutActivityType {
        case .running:
            return mappedExerciseDescriptor(
                preferredIDs: ["running", "jogging", "trail_running"],
                fallbackChinese: "跑步",
                fallbackEnglish: "Running",
                defaultMET: 9.8
            )
        case .walking:
            return mappedExerciseDescriptor(
                preferredIDs: ["walking_fast", "walking_slow"],
                fallbackChinese: "步行",
                fallbackEnglish: "Walking",
                defaultMET: 4.3
            )
        case .hiking:
            return mappedExerciseDescriptor(
                preferredIDs: ["hiking", "walking_fast"],
                fallbackChinese: "徒步",
                fallbackEnglish: "Hiking",
                defaultMET: 6.0
            )
        case .cycling:
            return mappedExerciseDescriptor(
                preferredIDs: ["cycling_light", "cycling_fast", "mountain_bike"],
                fallbackChinese: "骑行",
                fallbackEnglish: "Cycling",
                defaultMET: 7.0
            )
        case .swimming:
            return mappedExerciseDescriptor(
                preferredIDs: ["swim_light", "swim_fast"],
                fallbackChinese: "游泳",
                fallbackEnglish: "Swimming",
                defaultMET: 8.0
            )
        case .traditionalStrengthTraining, .functionalStrengthTraining:
            return mappedExerciseDescriptor(
                preferredIDs: ["weight_training", "bodyweight"],
                fallbackChinese: "力量训练",
                fallbackEnglish: "Strength Training",
                defaultMET: 6.0
            )
        case .highIntensityIntervalTraining:
            return mappedExerciseDescriptor(
                preferredIDs: ["hiit"],
                fallbackChinese: "高强度间歇训练",
                fallbackEnglish: "HIIT",
                defaultMET: 10.0
            )
        case .yoga:
            return mappedExerciseDescriptor(
                preferredIDs: ["yoga"],
                fallbackChinese: "瑜伽",
                fallbackEnglish: "Yoga",
                defaultMET: 3.0
            )
        case .pilates:
            return mappedExerciseDescriptor(
                preferredIDs: ["pilates"],
                fallbackChinese: "普拉提",
                fallbackEnglish: "Pilates",
                defaultMET: 3.5
            )
        case .dance:
            return mappedExerciseDescriptor(
                preferredIDs: ["dancing", "zumba"],
                fallbackChinese: "舞蹈",
                fallbackEnglish: "Dance",
                defaultMET: 6.0
            )
        case .mixedCardio:
            return mappedExerciseDescriptor(
                preferredIDs: ["aerobics", "step_aerobics"],
                fallbackChinese: "有氧操",
                fallbackEnglish: "Aerobics",
                defaultMET: 7.3
            )
        case .stairClimbing:
            return mappedExerciseDescriptor(
                preferredIDs: ["stair_climber", "stairs_up"],
                fallbackChinese: "爬楼",
                fallbackEnglish: "Stair Climbing",
                defaultMET: 8.8
            )
        case .elliptical:
            return mappedExerciseDescriptor(
                preferredIDs: ["elliptical"],
                fallbackChinese: "椭圆机",
                fallbackEnglish: "Elliptical",
                defaultMET: 5.0
            )
        case .rowing:
            return mappedExerciseDescriptor(
                preferredIDs: ["rowing_machine", "rowing_outdoor"],
                fallbackChinese: "划船",
                fallbackEnglish: "Rowing",
                defaultMET: 7.0
            )
        case .jumpRope:
            return mappedExerciseDescriptor(
                preferredIDs: ["jump_rope"],
                fallbackChinese: "跳绳",
                fallbackEnglish: "Jump Rope",
                defaultMET: 12.3
            )
        case .boxing:
            return mappedExerciseDescriptor(
                preferredIDs: ["boxing", "kickboxing_cardio"],
                fallbackChinese: "拳击",
                fallbackEnglish: "Boxing",
                defaultMET: 8.5
            )
        case .basketball:
            return mappedExerciseDescriptor(
                preferredIDs: ["basketball"],
                fallbackChinese: "篮球",
                fallbackEnglish: "Basketball",
                defaultMET: 8.0
            )
        case .soccer:
            return mappedExerciseDescriptor(
                preferredIDs: ["soccer"],
                fallbackChinese: "足球",
                fallbackEnglish: "Soccer",
                defaultMET: 8.5
            )
        case .tennis:
            return mappedExerciseDescriptor(
                preferredIDs: ["tennis"],
                fallbackChinese: "网球",
                fallbackEnglish: "Tennis",
                defaultMET: 7.3
            )
        case .badminton:
            return mappedExerciseDescriptor(
                preferredIDs: ["badminton"],
                fallbackChinese: "羽毛球",
                fallbackEnglish: "Badminton",
                defaultMET: 5.5
            )
        case .volleyball:
            return mappedExerciseDescriptor(
                preferredIDs: ["volleyball"],
                fallbackChinese: "排球",
                fallbackEnglish: "Volleyball",
                defaultMET: 4.0
            )
        case .baseball:
            return mappedExerciseDescriptor(
                preferredIDs: ["baseball"],
                fallbackChinese: "棒球",
                fallbackEnglish: "Baseball",
                defaultMET: 5.0
            )
        case .golf:
            return mappedExerciseDescriptor(
                preferredIDs: ["golf"],
                fallbackChinese: "高尔夫",
                fallbackEnglish: "Golf",
                defaultMET: 4.8
            )
        case .martialArts:
            return mappedExerciseDescriptor(
                preferredIDs: ["taekwondo", "karate", "judo", "muay_thai"],
                fallbackChinese: "武术",
                fallbackEnglish: "Martial Arts",
                defaultMET: 8.5
            )
        default:
            let sourceName = workout.sourceRevision.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName: String
            if sourceName.isEmpty {
                fallbackName = localized("运动记录", "Workout")
            } else {
                fallbackName = localized("运动记录 · \(sourceName)", "Workout · \(sourceName)")
            }
            return HealthWorkoutImportDescriptor(
                id: "apple_health_workout_\(workout.workoutActivityType.rawValue)",
                name: fallbackName,
                defaultMET: 5.0
            )
        }
    }

    private func isKeepFitHealthObject(metadata: [String: Any]?) -> Bool {
        (metadata?[SyncKeys.healthMetadataSource] as? String) == SyncKeys.healthMetadataSourceValue
    }

    private func indexOfHealthFoodLog(matching sampleUUID: String, in logs: [FoodLog]) -> Int? {
        logs.firstIndex {
            $0.id.uuidString == sampleUUID || $0.healthKitSampleUUID == sampleUUID
        }
    }

    private func indexOfHealthWorkoutLog(matching workoutUUID: String, in logs: [ExerciseLog]) -> Int? {
        logs.firstIndex {
            $0.id.uuidString == workoutUUID || $0.healthKitWorkoutUUID == workoutUUID
        }
    }

    private func backfillLegacyHealthFoodLink(
        sampleUUID: String,
        sample: HKQuantitySample,
        descriptor: HealthFoodImportDescriptor,
        in logs: inout [FoodLog]
    ) -> Bool {
        let kcal = sample.quantity.doubleValue(for: .kilocalorie())
        let candidates = logs.indices.filter { index in
            let log = logs[index]
            guard log.healthKitSampleUUID == nil else { return false }
            guard abs(log.date.timeIntervalSince(sample.startDate)) < 1 else { return false }
            guard log.foodID == descriptor.id, log.foodName == descriptor.name else { return false }
            guard abs(log.weightGrams - 100) < 0.001 else { return false }
            guard abs(log.caloriesPer100g - kcal) < 0.01 else { return false }
            return abs(log.proteinPer100g) < 0.001 && abs(log.carbsPer100g) < 0.001 && abs(log.fatPer100g) < 0.001
        }

        guard candidates.count == 1 else { return false }
        logs[candidates[0]].healthKitSampleUUID = sampleUUID
        return true
    }

    private func backfillLegacyHealthWorkoutLink(
        workoutUUID: String,
        workout: HKWorkout,
        descriptor: HealthWorkoutImportDescriptor,
        in logs: inout [ExerciseLog]
    ) -> Bool {
        let durationMinutes = max(workout.duration / 60, 1)
        let candidates = logs.indices.filter { index in
            let log = logs[index]
            guard log.healthKitWorkoutUUID == nil else { return false }
            guard abs(log.date.timeIntervalSince(workout.startDate)) < 1 else { return false }
            guard log.exerciseID == descriptor.id, log.exerciseName == descriptor.name else { return false }
            return abs(log.durationMinutes - durationMinutes) < 0.01
        }

        guard candidates.count == 1 else { return false }
        logs[candidates[0]].healthKitWorkoutUUID = workoutUUID
        return true
    }

    private func reconcileDeletedHealthFoodLogs(
        liveUUIDs: Set<String>,
        logs: inout [FoodLog],
        exportedFoodIDs: inout Set<String>,
        importedDietaryUUIDs: inout Set<String>
    ) -> Bool {
        let removedLogs = logs
            .filter { log in
                guard let sampleUUID = log.healthKitSampleUUID else { return false }
                return !liveUUIDs.contains(sampleUUID)
            }
        guard !removedLogs.isEmpty else { return false }

        logs.removeAll { log in
            guard let sampleUUID = log.healthKitSampleUUID else { return false }
            return !liveUUIDs.contains(sampleUUID)
        }
        exportedFoodIDs.subtract(removedLogs.map(\.id.uuidString))
        importedDietaryUUIDs.subtract(removedLogs.compactMap(\.healthKitSampleUUID))
        return true
    }

    private func reconcileDeletedHealthWorkoutLogs(
        liveUUIDs: Set<String>,
        logs: inout [ExerciseLog],
        exportedExerciseIDs: inout Set<String>,
        importedWorkoutUUIDs: inout Set<String>
    ) -> Bool {
        let removedLogs = logs.filter { log in
            guard let workoutUUID = log.healthKitWorkoutUUID else { return false }
            return !liveUUIDs.contains(workoutUUID)
        }
        guard !removedLogs.isEmpty else { return false }

        logs.removeAll { log in
            guard let workoutUUID = log.healthKitWorkoutUUID else { return false }
            return !liveUUIDs.contains(workoutUUID)
        }
        exportedExerciseIDs.subtract(removedLogs.map(\.id.uuidString))
        importedWorkoutUUIDs.subtract(removedLogs.compactMap(\.healthKitWorkoutUUID))
        return true
    }

    private func normalizedDeletionRange(startDate: Date, endDate: Date) -> ClosedRange<Date> {
        let lower = min(startDate.startOfDayInCurrentCalendar, endDate.startOfDayInCurrentCalendar)
        let upper = max(startDate.startOfDayInCurrentCalendar, endDate.startOfDayInCurrentCalendar)
        return lower...upper
    }

    private func pruneHealthSyncState(
        deletedFoodLogs: [FoodLog],
        deletedExerciseLogs: [ExerciseLog],
        deletedBodyMetrics: [BodyMetricLog]
    ) {
        var exportedFoodIDs = loadStringSet(forKey: SyncKeys.exportedFoodLogIDs)
        var exportedExerciseIDs = loadStringSet(forKey: SyncKeys.exportedExerciseLogIDs)
        var exportedBodyMetricIDs = loadStringSet(forKey: SyncKeys.exportedBodyMetricIDs)

        exportedFoodIDs.subtract(deletedFoodLogs.map { $0.id.uuidString })
        exportedExerciseIDs.subtract(deletedExerciseLogs.map { $0.id.uuidString })
        exportedBodyMetricIDs.subtract(deletedBodyMetrics.map { $0.id.uuidString })

        saveStringSet(exportedFoodIDs, forKey: SyncKeys.exportedFoodLogIDs)
        saveStringSet(exportedExerciseIDs, forKey: SyncKeys.exportedExerciseLogIDs)
        saveStringSet(exportedBodyMetricIDs, forKey: SyncKeys.exportedBodyMetricIDs)
    }

    private func syncProfileWeightAfterBodyMetricDeletion() {
        guard let latestRemaining = bodyMetricLogs.max(by: { $0.date < $1.date }) else { return }
        if profile.weightKg != latestRemaining.weightKg {
            profile.weightKg = latestRemaining.weightKg
        }
    }

    private func rebuildRecordedDataOverview() {
        let allDates = foodLogs.map(\.date) + exerciseLogs.map(\.date) + bodyMetricLogs.map(\.date)
        recordedDataOverview = RecordedDataOverview(
            earliestDate: allDates.min()?.startOfDayInCurrentCalendar,
            latestDate: allDates.max()?.startOfDayInCurrentCalendar,
            summary: DataDeletionSummary(
                foodLogCount: foodLogs.count,
                exerciseLogCount: exerciseLogs.count,
                bodyMetricCount: bodyMetricLogs.count
            )
        )
    }

    private func rebuildDailyMetricsCache() {
        var foodLogsByDay: [Date: [FoodLog]] = [:]
        var exerciseLogsByDay: [Date: [ExerciseLog]] = [:]

        for log in foodLogs {
            let day = log.date.startOfDayInCurrentCalendar
            foodLogsByDay[day, default: []].append(log)
        }

        for log in exerciseLogs {
            let day = log.date.startOfDayInCurrentCalendar
            exerciseLogsByDay[day, default: []].append(log)
        }

        var nutritionByDay: [Date: DayNutritionSummary] = [:]
        var dailyNutritionRecords: [DailyNutritionRecord] = []
        for (day, logs) in foodLogsByDay {
            let summary = logs.reduce(
                DayNutritionSummary(calories: 0, protein: 0, carbs: 0, fat: 0)
            ) { partial, log in
                DayNutritionSummary(
                    calories: partial.calories + log.calories,
                    protein: partial.protein + log.protein,
                    carbs: partial.carbs + log.carbs,
                    fat: partial.fat + log.fat
                )
            }
            nutritionByDay[day] = summary
            dailyNutritionRecords.append(
                DailyNutritionRecord(
                    date: day,
                    calories: summary.calories,
                    protein: summary.protein,
                    carbs: summary.carbs,
                    fat: summary.fat
                )
            )
        }
        dailyNutritionRecords.sort { $0.date > $1.date }

        var exerciseByDay: [Date: DayFitnessSummary] = [:]
        var dailyExerciseRecords: [DailyExerciseRecord] = []
        for (day, logs) in exerciseLogsByDay {
            let summary = DayFitnessSummary(
                caloriesBurned: logs.reduce(0) { $0 + $1.caloriesBurned(weightKg: profile.weightKg) },
                durationMinutes: logs.reduce(0) { $0 + $1.durationMinutes }
            )
            exerciseByDay[day] = summary
            dailyExerciseRecords.append(
                DailyExerciseRecord(
                    date: day,
                    caloriesBurned: summary.caloriesBurned,
                    minutes: summary.durationMinutes
                )
            )
        }
        dailyExerciseRecords.sort { $0.date > $1.date }

        let daysWithAnyActivity = Set(foodLogsByDay.keys).union(exerciseLogsByDay.keys)
        let calorieTrendsAscending = daysWithAnyActivity
            .sorted()
            .map { day in
                let nutrition = nutritionByDay[day] ?? DayNutritionSummary(calories: 0, protein: 0, carbs: 0, fat: 0)
                let exercise = exerciseByDay[day] ?? DayFitnessSummary(caloriesBurned: 0, durationMinutes: 0)
                let exerciseExpenditure = exercise.caloriesBurned
                let totalExpenditure = profile.dailyMaintenanceCalories + exerciseExpenditure
                return DailyCalorieTrend(
                    date: day,
                    intake: nutrition.calories,
                    expenditure: exerciseExpenditure,
                    deficit: nutrition.calories - totalExpenditure
                )
            }

        var latestBodyMetricByDay: [Date: BodyMetricLog] = [:]
        for metric in bodyMetricLogs {
            let day = metric.date.startOfDayInCurrentCalendar
            if let existing = latestBodyMetricByDay[day], existing.date >= metric.date {
                continue
            }
            latestBodyMetricByDay[day] = metric
        }

        dailyMetricsCache = DailyMetricsCache(
            foodLogsByDay: foodLogsByDay,
            exerciseLogsByDay: exerciseLogsByDay,
            nutritionByDay: nutritionByDay,
            exerciseByDay: exerciseByDay,
            dailyNutritionRecordsDescending: dailyNutritionRecords,
            dailyExerciseRecordsDescending: dailyExerciseRecords,
            calorieTrendsAscending: calorieTrendsAscending,
            latestBodyMetricByDay: latestBodyMetricByDay,
            bodyMetricsAscending: bodyMetricLogs.sorted(by: { $0.date < $1.date }),
            daysWithAnyActivity: daysWithAnyActivity
        )
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
            if log.healthKitSampleUUID != nil { continue }
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
            if log.healthKitWorkoutUUID != nil { continue }
            if exportedExerciseIDs.contains(logID) { continue }
            let calories = max(log.caloriesBurned(weightKg: profile.weightKg), 0)
            let durationSeconds = max(log.durationMinutes * 60, 60)
            let endDate = log.date.addingTimeInterval(durationSeconds)
            let metadata: [String: Any] = [
                HKMetadataKeyExternalUUID: logID,
                SyncKeys.healthMetadataSource: SyncKeys.healthMetadataSourceValue
            ]
            try await saveWorkoutWithBuilder(
                startDate: log.date,
                endDate: endDate,
                calories: calories,
                metadata: metadata
            )
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

        var importedDietaryUUIDs = loadStringSet(forKey: SyncKeys.importedDietarySampleUUIDs)
        var importedWorkoutUUIDs = loadStringSet(forKey: SyncKeys.importedWorkoutUUIDs)
        var importedBodyMassUUIDs = loadStringSet(forKey: SyncKeys.importedBodyMassUUIDs)
        var importedBodyFatUUIDs = loadStringSet(forKey: SyncKeys.importedBodyFatUUIDs)
        var exportedFoodIDs = loadStringSet(forKey: SyncKeys.exportedFoodLogIDs)
        var exportedExerciseIDs = loadStringSet(forKey: SyncKeys.exportedExerciseLogIDs)
        var exportedBodyMetricIDs = loadStringSet(forKey: SyncKeys.exportedBodyMetricIDs)

        let didCompleteInitialImport = defaults.bool(forKey: SyncKeys.healthInitialImportCompleted)
        let hasHistoricalImportState =
            !importedDietaryUUIDs.isEmpty ||
            !importedWorkoutUUIDs.isEmpty ||
            !importedBodyMassUUIDs.isEmpty ||
            !importedBodyFatUUIDs.isEmpty
        let calendar = AppPreferences.calendar
        let since: Date = {
            if didCompleteInitialImport || hasHistoricalImportState {
                return calendar.date(byAdding: .day, value: -90, to: Date()) ?? .distantPast
            }
            // First-time Health sync should import all available historical records.
            return .distantPast
        }()

        let dietarySince = min(
            since,
            foodLogs
                .filter { $0.healthKitSampleUUID != nil }
                .map(\.date)
                .min() ?? since
        )
        let dietarySamples = try await fetchQuantitySamples(type: dietaryType, from: dietarySince)
        let importedDietarySamples = dietarySamples.filter { !isKeepFitHealthObject(metadata: $0.metadata) }
        let liveDietaryUUIDs = Set(importedDietarySamples.map { $0.uuid.uuidString })
        var mergedFoodLogs = foodLogs
        var didMutateFoodLogs = false
        for sample in importedDietarySamples {
            let sampleUUID = sample.uuid.uuidString
            let wasImported = importedDietaryUUIDs.contains(sampleUUID)
            if let linkedIndex = indexOfHealthFoodLog(matching: sampleUUID, in: mergedFoodLogs) {
                if mergedFoodLogs[linkedIndex].healthKitSampleUUID != sampleUUID {
                    mergedFoodLogs[linkedIndex].healthKitSampleUUID = sampleUUID
                    didMutateFoodLogs = true
                }
                importedDietaryUUIDs.insert(sampleUUID)
                continue
            }
            if wasImported {
                let descriptor = resolveHealthFoodDescriptor(from: sample)
                if backfillLegacyHealthFoodLink(sampleUUID: sampleUUID, sample: sample, descriptor: descriptor, in: &mergedFoodLogs) {
                    didMutateFoodLogs = true
                }
                importedDietaryUUIDs.insert(sampleUUID)
                continue
            }

            let kcal = sample.quantity.doubleValue(for: .kilocalorie())
            guard kcal > 0 else { continue }
            let descriptor = resolveHealthFoodDescriptor(from: sample)

            let log = FoodLog(
                id: sample.uuid,
                date: sample.startDate,
                foodID: descriptor.id,
                foodName: descriptor.name,
                foodIcon: foodIcon(forFoodID: descriptor.id),
                healthKitSampleUUID: sampleUUID,
                weightGrams: 100,
                caloriesPer100g: kcal,
                proteinPer100g: 0,
                carbsPer100g: 0,
                fatPer100g: 0
            )
            mergedFoodLogs.append(log)
            exportedFoodIDs.insert(log.id.uuidString)
            importedDietaryUUIDs.insert(sampleUUID)
            didMutateFoodLogs = true
        }
        if reconcileDeletedHealthFoodLogs(
            liveUUIDs: liveDietaryUUIDs,
            logs: &mergedFoodLogs,
            exportedFoodIDs: &exportedFoodIDs,
            importedDietaryUUIDs: &importedDietaryUUIDs
        ) {
            didMutateFoodLogs = true
        }
        if didMutateFoodLogs || mergedFoodLogs.count != foodLogs.count {
            foodLogs = mergedFoodLogs.sorted(by: { $0.date > $1.date })
        }

        let workoutsSince = min(
            since,
            exerciseLogs
                .filter { $0.healthKitWorkoutUUID != nil }
                .map(\.date)
                .min() ?? since
        )
        let workouts = try await fetchWorkouts(from: workoutsSince)
        let importedWorkouts = workouts.filter { !isKeepFitHealthObject(metadata: $0.metadata) }
        let liveWorkoutUUIDs = Set(importedWorkouts.map { $0.uuid.uuidString })
        var mergedExerciseLogs = exerciseLogs
        var didMutateExerciseLogs = false
        for workout in importedWorkouts {
            let workoutUUID = workout.uuid.uuidString
            let descriptor = resolveHealthWorkoutDescriptor(from: workout)
            let wasImported = importedWorkoutUUIDs.contains(workoutUUID)
            if let linkedIndex = indexOfHealthWorkoutLog(matching: workoutUUID, in: mergedExerciseLogs) {
                if mergedExerciseLogs[linkedIndex].healthKitWorkoutUUID != workoutUUID {
                    mergedExerciseLogs[linkedIndex].healthKitWorkoutUUID = workoutUUID
                    didMutateExerciseLogs = true
                }
                importedWorkoutUUIDs.insert(workoutUUID)
                continue
            }
            if wasImported {
                if backfillLegacyHealthWorkoutLink(workoutUUID: workoutUUID, workout: workout, descriptor: descriptor, in: &mergedExerciseLogs) {
                    didMutateExerciseLogs = true
                }
                importedWorkoutUUIDs.insert(workoutUUID)
                continue
            }

            let calories = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
            let durationMinutes = max(workout.duration / 60, 1)
            let met: Double
            if calories > 0 {
                met = max((calories * 200) / (3.5 * max(profile.weightKg, 1) * durationMinutes), 1)
            } else {
                // Keep workout import robust even when Health sample has no active energy field.
                met = descriptor.defaultMET
            }
            let log = ExerciseLog(
                id: workout.uuid,
                date: workout.startDate,
                exerciseID: descriptor.id,
                exerciseName: descriptor.name,
                exerciseIcon: exerciseIcon(forExerciseID: descriptor.id),
                healthKitWorkoutUUID: workoutUUID,
                durationMinutes: durationMinutes,
                met: met
            )
            mergedExerciseLogs.append(log)
            exportedExerciseIDs.insert(log.id.uuidString)
            importedWorkoutUUIDs.insert(workoutUUID)
            didMutateExerciseLogs = true
        }
        if reconcileDeletedHealthWorkoutLogs(
            liveUUIDs: liveWorkoutUUIDs,
            logs: &mergedExerciseLogs,
            exportedExerciseIDs: &exportedExerciseIDs,
            importedWorkoutUUIDs: &importedWorkoutUUIDs
        ) {
            didMutateExerciseLogs = true
        }
        if didMutateExerciseLogs || mergedExerciseLogs.count != exerciseLogs.count {
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
            if (sample.metadata?[SyncKeys.healthMetadataSource] as? String) == SyncKeys.healthMetadataSourceValue {
                continue
            }

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
            if (sample.metadata?[SyncKeys.healthMetadataSource] as? String) == SyncKeys.healthMetadataSourceValue {
                continue
            }

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
        defaults.set(true, forKey: SyncKeys.healthInitialImportCompleted)
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

    private func saveWorkoutWithBuilder(
        startDate: Date,
        endDate: Date,
        calories: Double,
        metadata: [String: Any]
    ) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .unknown

        let builder = HKWorkoutBuilder(
            healthStore: healthStore,
            configuration: configuration,
            device: nil
        )

        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata(metadata)

            if calories > 0,
               let activeEnergyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                let activeEnergySample = HKQuantitySample(
                    type: activeEnergyType,
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                    start: startDate,
                    end: endDate,
                    metadata: metadata
                )
                try await builder.addSamples([activeEnergySample])
            }

            try await builder.endCollection(at: endDate)
            _ = try await finishWorkout(builder)
        } catch {
            builder.discardWorkout()
            throw error
        }
    }

    private func finishWorkout(_ builder: HKWorkoutBuilder) async throws -> HKWorkout {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<HKWorkout, Error>) in
            builder.finishWorkout { workout, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let workout else {
                    continuation.resume(throwing: NSError(domain: "KeepFit.HealthKit", code: -2))
                    return
                }
                continuation.resume(returning: workout)
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
