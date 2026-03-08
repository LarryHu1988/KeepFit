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
        "black_coffee", "latte", "green_tea", "cola", "milk_tea", "protein_powder", "orange_juice", "coconut_water",
        "chocolate_milk", "cappuccino", "espresso", "sparkling_water", "sports_drink", "smoothie_berry",
        "lemonade", "tomato_juice", "oat_milk"
    ]

    static func foodUnit(id: String, category: FoodCategory?) -> FoodMeasureUnit {
        if liquidFoodIDs.contains(id) { return .milliliter }
        if category == .drink { return .milliliter }
        return .gram
    }

    static func foodIcon(id: String, category: FoodCategory) -> String {
        switch id {
        case "rice_white":
            return "🍚"
        case "rice_brown":
            return "🍙"
        case "congee":
            return "🥣🍚"
        case "oatmeal":
            return "🥣🌾"
        case "cereal":
            return "🥣🥄"
        case "barley":
            return "🌾"
        case "millet":
            return "🌾🟡"
        case "quinoa":
            return "🌾⚪️"
        case "whole_wheat_bread":
            return "🍞🌾"
        case "toast":
            return "🍞🔥"
        case "bagel":
            return "🥯"
        case "bun_steamed":
            return "🥟☁️"
        case "wonton":
            return "🥟🥣"
        case "mantou":
            return "🥖"
        case "sweet_potato":
            return "🍠"
        case "potato":
            return "🥔"
        case "corn":
            return "🌽"
        case "noodles":
            return "🍜"
        case "rice_noodle":
            return "🍜🍚"
        case "udon":
            return "🍲"
        case "pasta_wholewheat", "fried_noodles":
            return "🍝"
        case "dumpling":
            return "🥟"
        case "pumpkin":
            return "🎃"
        case "fried_rice":
            return "🍛"
        case "sushi_roll":
            return "🍣"
        case "tortilla":
            return "🌮"
        case "pancake":
            return "🥞"
        case "croissant":
            return "🥐"
        case "wrap", "spring_roll":
            return "🌯"

        case "chicken_breast":
            return "🍗⚪️"
        case "chicken_wing":
            return "🍗🪽"
        case "chicken_leg":
            return "🍖"
        case "pork_tenderloin":
            return "🍖🐖"
        case "duck_breast":
            return "🦆"
        case "turkey_breast":
            return "🦃"
        case "beef_lean":
            return "🥩🐄"
        case "beef_shank":
            return "🥩🦵"
        case "lean_lamb":
            return "🥩🐑"
        case "pork_lean":
            return "🥩🐖"
        case "minced_beef":
            return "🥩🔪"
        case "salmon":
            return "🍣"
        case "tuna":
            return "🐟"
        case "sardine":
            return "🐟🥫"
        case "cod":
            return "🐟⚪️"
        case "tilapia":
            return "🐟🌊"
        case "mackerel":
            return "🐟💙"
        case "shrimp":
            return "🦐"
        case "prawn":
            return "🦐👑"
        case "crab":
            return "🦀"
        case "mussel":
            return "🦪"
        case "oyster":
            return "🦪💧"
        case "scallop":
            return "🐚"
        case "squid":
            return "🦑"
        case "egg":
            return "🥚"
        case "egg_white":
            return "🥚⚪️"
        case "tofu":
            return "🫘⬜️"
        case "tempeh":
            return "🫘🔥"
        case "chickpea":
            return "🫘🟡"
        case "edamame":
            return "🫛"

        case "broccoli":
            return "🥦"
        case "spinach":
            return "🥬💚"
        case "lettuce":
            return "🥬"
        case "bok_choy":
            return "🥬🥢"
        case "cabbage":
            return "🥬⚪️"
        case "kale":
            return "🥬💪"
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
        case "bean_sprout":
            return "🌱💧"
        case "broccoli_sprout":
            return "🌱🥦"
        case "bell_pepper":
            return "🫑"
        case "onion":
            return "🧅"
        case "eggplant":
            return "🍆"
        case "celery":
            return "🌿〰️"
        case "seaweed":
            return "🌿🌊"
        case "okra":
            return "🌿⭐️"
        case "green_beans":
            return "🫛"
        case "pea":
            return "🫛🟢"
        case "radish":
            return "🥗"
        case "lotus_root":
            return "🪷"

        case "apple":
            return "🍎"
        case "pear":
            return "🍐"
        case "banana":
            return "🍌"
        case "orange":
            return "🍊"
        case "grapefruit":
            return "🍊🩷"
        case "blueberry":
            return "🫐"
        case "grape":
            return "🍇"
        case "strawberry":
            return "🍓"
        case "raspberry":
            return "🍓〰️"
        case "cherry":
            return "🍒"
        case "lychee":
            return "🍒⚪️"
        case "kiwi":
            return "🥝"
        case "mango":
            return "🥭"
        case "peach":
            return "🍑"
        case "watermelon":
            return "🍉"
        case "avocado":
            return "🥑"
        case "pineapple", "dragonfruit":
            return "🍍"
        case "lemon":
            return "🍋"
        case "lime":
            return "🍋🟢"
        case "papaya":
            return "🍈🧡"
        case "cantaloupe":
            return "🍈"
        case "plum":
            return "🫐🟣"
        case "blackberry":
            return "🫐⚫️"
        case "coconut":
            return "🥥"

        case "greek_yogurt":
            return "🥣💪"
        case "yogurt_plain":
            return "🥣"
        case "skyr":
            return "🥣❄️"
        case "soy_yogurt":
            return "🫘🥣"
        case "milk", "lowfat_milk":
            return id == "lowfat_milk" ? "🥛➖" : "🥛"
        case "soy_milk":
            return "🫘🥛"
        case "kefir":
            return "🫙🥛"
        case "chocolate_milk":
            return "🍫🥛"
        case "oat_milk":
            return "🌾🥛"
        case "cottage_cheese":
            return "🥣🧀"
        case "cheddar_cheese":
            return "🧀"
        case "mozzarella":
            return "🧀⚪️"

        case "almond":
            return "🌰💧"
        case "walnut":
            return "🌰🧠"
        case "cashew":
            return "🌰🌙"
        case "pistachio":
            return "🌰💚"
        case "macadamia":
            return "🌰⚪️"
        case "peanut":
            return "🥜"
        case "sunflower_seed":
            return "🌻"
        case "pumpkin_seed":
            return "🎃"
        case "hazelnut":
            return "🌰🤎"
        case "pecan":
            return "🌰🍂"
        case "chestnut":
            return "🌰🔥"
        case "pine_nut":
            return "🌲🌰"
        case "chia_seed":
            return "🫘⚫️"
        case "flaxseed":
            return "🌾🫘"

        case "black_coffee":
            return "☕️"
        case "latte":
            return "☕️🥛"
        case "espresso":
            return "☕️⚫️"
        case "cappuccino":
            return "☕️☁️"
        case "green_tea":
            return "🍵"
        case "cola":
            return "🥤"
        case "milk_tea":
            return "🧋"
        case "orange_juice":
            return "🍊🧃"
        case "sports_drink":
            return "⚡️🥤"
        case "coconut_water":
            return "🥥🧃"
        case "smoothie_berry":
            return "🫐🧋"
        case "sparkling_water":
            return "🫧💧"
        case "lemonade":
            return "🍋🧃"
        case "tomato_juice":
            return "🍅🧃"
        case "protein_powder":
            return "💪🥤"

        case "dark_chocolate":
            return "🍫🌑"
        case "brownie":
            return "🍫🟫"
        case "chips":
            return "🍟"
        case "cookie":
            return "🍪"
        case "ice_cream":
            return "🍨"
        case "beef_jerky":
            return "🥩"
        case "energy_bar":
            return "⚡️🍫"
        case "cracker", "rice_cracker":
            return "🍘"
        case "popcorn":
            return "🍿"
        case "mooncake":
            return "🥮"
        case "fried_chicken":
            return "🍗"
        case "pretzel":
            return "🥨"
        case "muffin":
            return "🧁"
        case "donut":
            return "🍩"
        case "granola":
            return "🥣🌾"
        case "sandwich":
            return "🥪"
        case "hamburger":
            return "🍔"
        case "pizza":
            return "🍕"
        case "hot_dog":
            return "🌭"
        case "seaweed_snack":
            return "🌿🍘"

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
        case "jogging", "running", "indoor_run", "trail_running", "treadmill_run", "sprint_interval":
            return "🏃"
        case "incline_walk", "hiking", "mountain_climb":
            return "🥾"
        case "cycling_light", "cycling_fast", "mountain_bike", "spinning", "airbike":
            return "🚴"
        case "swim_light", "swim_fast", "water_polo", "water_aerobics":
            return "🏊"
        case "skating":
            return "🛼"
        case "rowing_machine", "rowing_outdoor":
            return "🚣"
        case "jump_rope", "rope_climb_machine", "skipping_light":
            return "🪢"
        case "hiit", "burpees", "jumping_jacks", "battle_rope", "skierg", "step_aerobics", "kickboxing_cardio":
            return "🔥"
        case "elliptical", "stair_climber", "stairs_up":
            return "🏃"
        case "stair_walk":
            return "🪜"
        case "housework":
            return "🧺"

        case "boxing", "shadow_boxing", "muay_thai", "boxing_bag":
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
        case "rock_climbing", "bouldering":
            return "🧗"
        case "surfing", "paddle_board":
            return "🏄"
        case "skating_ice":
            return "⛸️"
        case "cricket":
            return "🏏"
        case "hockey":
            return "🏑"
        case "archery":
            return "🏹"

        case "yoga", "yin_yoga", "surya_namaskar":
            return "🧘"
        case "pilates", "barre", "hip_opener":
            return "🧘"
        case "stretching", "dynamic_stretch", "static_stretch":
            return "🤸"
        case "mobility", "mobility_flow", "foam_rolling", "fascia_release", "recovery_flow":
            return "🧘"
        case "chair_yoga":
            return "🪑"
        case "shoulder_mobility":
            return "🤸"
        case "tai_chi", "qigong", "breathing_flow":
            return "☯️"

        case "bodyweight", "crossfit", "calisthenics", "trx", "sandbag_training":
            return "💪"
        case "weight_training", "kettlebell", "deadlift", "bench_press", "shoulder_press", "squat_training", "leg_press", "lat_pulldown", "seated_row", "bicep_curl", "tricep_dip", "hip_thrust", "glute_bridge", "power_clean", "dumbbell_training", "barbell_squat":
            return "🏋️"
        case "core_training", "plank", "pushup", "pullup", "resistance_band", "lunge_training", "chest_fly":
            return "💪"
        case "cable_row":
            return "🪢"
        case "leg_curl", "leg_extension":
            return "🦵"
        case "farmer_walk":
            return "🚶"

        case "dancing", "zumba", "aerobics", "dance_jazz":
            return "💃"
        case "dance_kpop":
            return "🕺"
        case "kayaking":
            return "🛶"
        case "skiing":
            return "⛷️"
        case "snowboarding":
            return "🏂"
        case "rucking":
            return "🎒"
        case "dog_walking":
            return "🐕"
        case "gardening":
            return "🪴"
        case "fishing":
            return "🎣"
        case "snowshoe":
            return "❄️"
        case "orienteering":
            return "🧭"

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
