import Foundation
import PhosphorSwift

enum FoodMeasureUnit: String {
    case gram
    case milliliter

    var symbol: String {
        switch self {
        case .gram:
            return "g"
        case .milliliter:
            return "ml"
        }
    }

    var defaultAmount: Double {
        switch self {
        case .gram:
            return 120
        case .milliliter:
            return 250
        }
    }
}

enum IconCatalog {
    private static let liquidFoodIDs: Set<String> = [
        "milk", "soy_milk", "black_coffee", "latte", "green_tea", "cola", "milk_tea", "protein_powder"
    ]

    static func foodUnit(id: String, category: FoodCategory?) -> FoodMeasureUnit {
        if liquidFoodIDs.contains(id) { return .milliliter }
        if category == .drink { return .milliliter }
        return .gram
    }

    static func foodIcon(id: String, category: FoodCategory) -> Ph {
        switch id {
        case "whole_wheat_bread":
            return .bread
        case "carrot", "sweet_potato":
            return .carrot
        case "salmon", "tuna":
            return .fish
        case "shrimp":
            return .shrimp
        case "egg", "egg_white":
            return .egg
        case "apple":
            return .cherries
        case "orange":
            return .orange
        case "avocado":
            return .avocado
        case "almond", "walnut", "peanut", "cashew":
            return .nut
        case "black_coffee", "latte":
            return .coffee
        case "green_tea":
            return .teaBag
        case "cookie":
            return .cookie
        case "ice_cream":
            return .iceCream
        case "dark_chocolate":
            return .cake
        default:
            switch category {
            case .staple:
                return .bowlFood
            case .protein:
                return .forkKnife
            case .vegetable:
                return .leaf
            case .fruit:
                return .cherries
            case .dairy:
                return .drop
            case .nuts:
                return .nut
            case .drink:
                return .drop
            case .snack:
                return .hamburger
            }
        }
    }

    static func exerciseIcon(id: String, category: ExerciseCategory) -> Ph {
        switch id {
        case "walking_slow", "walking_fast", "meditation_walk":
            return .personSimpleWalk
        case "jogging", "running", "hiit", "jump_rope":
            return .personSimpleRun
        case "cycling_light", "cycling_fast":
            return .personSimpleBike
        case "swim_light", "swim_fast":
            return .personSimpleSwim
        case "hiking":
            return .personSimpleHike
        case "mountain_climb":
            return .mountains
        case "boxing":
            return .boxingGlove
        case "basketball":
            return .basketball
        case "soccer":
            return .soccerBall
        case "tennis", "badminton", "table_tennis":
            return .tennisBall
        case "volleyball":
            return .volleyball
        case "yoga", "pilates", "stretching", "mobility", "tai_chi":
            return .personSimpleTaiChi
        case "stairs_up", "stair_climber":
            return .stairs
        case "housework":
            return .house
        default:
            switch category {
            case .cardio:
                return .pulse
            case .strength:
                return .barbell
            case .flexibility:
                return .personSimpleTaiChi
            case .sports:
                return .soccerBall
            case .outdoors:
                return .personSimpleHike
            }
        }
    }
}
