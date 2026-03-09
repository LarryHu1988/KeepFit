import Foundation

enum BiologicalSex: String, CaseIterable, Codable, Identifiable {
    case female
    case male
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female:
            return localized("女", "Female")
        case .male:
            return localized("男", "Male")
        case .other:
            return localized("其他", "Other")
        }
    }
}

enum ActivityLevel: String, CaseIterable, Codable, Identifiable {
    case sedentary
    case lightlyActive
    case moderatelyActive
    case veryActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary:
            return localized("久坐", "Sedentary")
        case .lightlyActive:
            return localized("轻度活动", "Lightly Active")
        case .moderatelyActive:
            return localized("中度活动", "Moderately Active")
        case .veryActive:
            return localized("高强度活动", "Very Active")
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary:
            return 1.2
        case .lightlyActive:
            return 1.375
        case .moderatelyActive:
            return 1.55
        case .veryActive:
            return 1.725
        }
    }
}

struct UserProfile: Codable {
    var name: String
    var heightCm: Double
    var weightKg: Double
    var age: Int
    var sex: BiologicalSex
    var activityLevel: ActivityLevel
    var targetWeightKg: Double
    var targetBodyFat: Double
    var dailyExerciseGoal: Double
    var avatarJPEGData: Data?

    static let `default` = UserProfile(
        name: "KeepFit 用户",
        heightCm: 170,
        weightKg: 70,
        age: 28,
        sex: .male,
        activityLevel: .lightlyActive,
        targetWeightKg: 65,
        targetBodyFat: 18,
        dailyExerciseGoal: 300,
        avatarJPEGData: nil
    )

    var bmr: Double {
        switch sex {
        case .male:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
        case .female:
            return 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
        case .other:
            let male = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) + 5
            let female = 10 * weightKg + 6.25 * heightCm - 5 * Double(age) - 161
            return (male + female) / 2
        }
    }

    var dailyMaintenanceCalories: Double {
        bmr * activityLevel.multiplier
    }

    var recommendedIntakeForFatLoss: Double {
        max(1200, dailyMaintenanceCalories - 450)
    }
}

enum FoodCategory: String, CaseIterable, Codable {
    case staple
    case protein
    case vegetable
    case fruit
    case dairy
    case nuts
    case drink
    case snack

    var title: String {
        switch self {
        case .staple:
            return localized("主食", "Staple")
        case .protein:
            return localized("蛋白质", "Protein")
        case .vegetable:
            return localized("蔬菜", "Vegetable")
        case .fruit:
            return localized("水果", "Fruit")
        case .dairy:
            return localized("乳制品", "Dairy")
        case .nuts:
            return localized("坚果", "Nuts")
        case .drink:
            return localized("饮品", "Drink")
        case .snack:
            return localized("零食", "Snack")
        }
    }
}

struct FoodItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var category: FoodCategory
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
}

struct FoodLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var foodID: String
    var foodName: String
    var foodIcon: String
    var healthKitSampleUUID: String? = nil
    var weightGrams: Double
    var caloriesPer100g: Double
    var proteinPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double

    var calories: Double { caloriesPer100g * weightGrams / 100 }
    var protein: Double { proteinPer100g * weightGrams / 100 }
    var carbs: Double { carbsPer100g * weightGrams / 100 }
    var fat: Double { fatPer100g * weightGrams / 100 }
}

enum ExerciseCategory: String, CaseIterable, Codable {
    case cardio
    case strength
    case flexibility
    case sports
    case outdoors

    var title: String {
        switch self {
        case .cardio:
            return localized("有氧", "Cardio")
        case .strength:
            return localized("力量", "Strength")
        case .flexibility:
            return localized("柔韧", "Flexibility")
        case .sports:
            return localized("球类", "Sports")
        case .outdoors:
            return localized("户外", "Outdoors")
        }
    }
}

struct ExerciseItem: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var category: ExerciseCategory
    var met: Double
}

struct ExerciseLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var exerciseID: String
    var exerciseName: String
    var exerciseIcon: String
    var healthKitWorkoutUUID: String? = nil
    var durationMinutes: Double
    var met: Double

    func caloriesBurned(weightKg: Double) -> Double {
        met * 3.5 * weightKg / 200 * durationMinutes
    }
}

struct BodyMetricLog: Identifiable, Codable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var bodyFatPercent: Double
}

struct DayNutritionSummary {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

struct DayFitnessSummary {
    var caloriesBurned: Double
    var durationMinutes: Double
}
