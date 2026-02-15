import Foundation

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
        "milk", "soy_milk", "lowfat_milk", "kefir",
        "black_coffee", "latte", "green_tea", "cola", "milk_tea", "protein_powder", "orange_juice", "coconut_water"
    ]

    static func foodUnit(id: String, category: FoodCategory?) -> FoodMeasureUnit {
        if liquidFoodIDs.contains(id) { return .milliliter }
        if category == .drink { return .milliliter }
        return .gram
    }

    static func foodIcon(id: String, category: FoodCategory) -> String {
        switch id {
        case "rice_white", "rice_brown", "congee":
            return "🍚"
        case "oatmeal", "barley", "millet":
            return "🥣"
        case "whole_wheat_bread", "bagel", "bun_steamed", "mantou":
            return "🍞"
        case "sweet_potato", "potato":
            return "🥔"
        case "corn":
            return "🌽"
        case "noodles", "udon", "rice_noodle", "pasta_wholewheat":
            return "🍜"
        case "dumpling":
            return "🥟"
        case "quinoa":
            return "🌾"
        case "pumpkin":
            return "🎃"

        case "chicken_breast", "chicken_leg", "duck_breast", "turkey_breast":
            return "🍗"
        case "beef_lean", "beef_shank", "lean_lamb", "pork_lean":
            return "🥩"
        case "salmon", "tuna", "cod", "tilapia", "mackerel":
            return "🐟"
        case "shrimp", "prawn":
            return "🦐"
        case "crab":
            return "🦀"
        case "egg", "egg_white":
            return "🥚"
        case "tofu", "tempeh":
            return "🫘"

        case "broccoli":
            return "🥦"
        case "spinach", "lettuce", "bok_choy", "cabbage":
            return "🥬"
        case "tomato":
            return "🍅"
        case "cucumber", "zucchini":
            return "🥒"
        case "carrot":
            return "🥕"
        case "mushroom":
            return "🍄"
        case "cauliflower":
            return "🥦"
        case "asparagus":
            return "🌱"
        case "bell_pepper":
            return "🫑"
        case "onion":
            return "🧅"
        case "eggplant":
            return "🍆"

        case "apple", "pear":
            return "🍎"
        case "banana":
            return "🍌"
        case "orange":
            return "🍊"
        case "blueberry":
            return "🫐"
        case "grape":
            return "🍇"
        case "strawberry", "cherry":
            return "🍓"
        case "kiwi":
            return "🥝"
        case "mango", "peach":
            return "🥭"
        case "watermelon":
            return "🍉"
        case "avocado":
            return "🥑"
        case "pineapple", "dragonfruit":
            return "🍍"

        case "greek_yogurt", "cottage_cheese":
            return "🥣"
        case "milk", "soy_milk", "lowfat_milk", "kefir":
            return "🥛"
        case "cheddar_cheese", "mozzarella":
            return "🧀"

        case "almond", "walnut", "peanut", "cashew", "pistachio", "macadamia", "sunflower_seed", "pumpkin_seed":
            return "🥜"

        case "black_coffee":
            return "☕️"
        case "latte":
            return "☕️"
        case "green_tea":
            return "🫖"
        case "cola", "milk_tea", "orange_juice", "coconut_water":
            return "🥤"
        case "protein_powder":
            return "🥤"

        case "dark_chocolate":
            return "🍫"
        case "chips":
            return "🍟"
        case "cookie":
            return "🍪"
        case "ice_cream":
            return "🍨"
        case "beef_jerky":
            return "🥩"
        case "energy_bar":
            return "🍫"
        case "cracker":
            return "🍘"
        case "popcorn":
            return "🍿"
        case "mooncake":
            return "🥮"
        case "fried_chicken":
            return "🍗"

        default:
            switch category {
            case .staple:
                return "🍚"
            case .protein:
                return "🍗"
            case .vegetable:
                return "🥬"
            case .fruit:
                return "🍎"
            case .dairy:
                return "🥛"
            case .nuts:
                return "🥜"
            case .drink:
                return "🥤"
            case .snack:
                return "🍪"
            }
        }
    }

    static func exerciseIcon(id: String, category: ExerciseCategory) -> String {
        switch id {
        case "walking_slow", "walking_fast", "treadmill_walk", "meditation_walk":
            return "🚶"
        case "jogging", "running", "indoor_run", "trail_running", "treadmill_run":
            return "🏃"
        case "cycling_light", "cycling_fast", "mountain_bike", "spinning", "airbike":
            return "🚴"
        case "swim_light", "swim_fast", "water_polo":
            return "🏊"
        case "hiking", "mountain_climb":
            return "🥾"
        case "skating":
            return "🛼"
        case "rowing_machine", "rowing_outdoor":
            return "🚣"
        case "jump_rope", "rope_climb_machine":
            return "🪢"
        case "hiit", "burpees", "jumping_jacks", "battle_rope", "skierg", "step_aerobics", "kickboxing_cardio":
            return "🔥"
        case "elliptical", "stair_climber", "stairs_up":
            return "🏃"
        case "housework":
            return "🧺"

        case "boxing", "shadow_boxing", "muay_thai":
            return "🥊"
        case "basketball":
            return "🏀"
        case "soccer":
            return "⚽️"
        case "tennis":
            return "🎾"
        case "badminton":
            return "🏸"
        case "table_tennis":
            return "🏓"
        case "volleyball":
            return "🏐"
        case "baseball":
            return "⚾️"
        case "golf":
            return "⛳️"
        case "rugby":
            return "🏉"
        case "handball":
            return "🤾"
        case "squash", "pickleball":
            return "🎾"
        case "ultimate_frisbee":
            return "🥏"
        case "fencing":
            return "🤺"
        case "taekwondo", "judo", "karate":
            return "🥋"

        case "yoga", "yin_yoga", "surya_namaskar":
            return "🧘"
        case "pilates", "barre":
            return "🧘"
        case "stretching", "dynamic_stretch", "static_stretch":
            return "🤸"
        case "mobility", "mobility_flow", "foam_rolling":
            return "🧘"
        case "tai_chi", "qigong", "breathing_flow":
            return "☯️"

        case "bodyweight", "crossfit", "calisthenics", "trx", "sandbag_training":
            return "💪"
        case "weight_training", "kettlebell", "deadlift", "bench_press", "shoulder_press", "squat_training", "leg_press", "lat_pulldown", "seated_row", "bicep_curl", "tricep_dip", "hip_thrust", "glute_bridge", "power_clean":
            return "🏋️"
        case "core_training", "plank", "pushup", "pullup", "resistance_band", "lunge_training":
            return "💪"

        case "dancing", "zumba", "aerobics":
            return "💃"
        case "kayaking":
            return "🛶"
        case "skiing":
            return "⛷️"
        case "snowboarding":
            return "🏂"

        default:
            switch category {
            case .cardio:
                return "🏃"
            case .strength:
                return "🏋️"
            case .flexibility:
                return "🧘"
            case .sports:
                return "⚽️"
            case .outdoors:
                return "🥾"
            }
        }
    }
}
