import Foundation

enum ChineseDishNutritionEstimator {
    private struct DishSpec {
        let id: String
        let name: String
        let category: FoodCategory
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let portionGrams: Double
        let aliases: [String]
        let icon: String

        init(
            _ id: String,
            _ name: String,
            _ category: FoodCategory,
            _ calories: Double,
            _ protein: Double,
            _ carbs: Double,
            _ fat: Double,
            portionGrams: Double = 250,
            aliases: [String] = [],
            icon: String
        ) {
            self.id = id
            self.name = name
            self.category = category
            self.calories = calories
            self.protein = protein
            self.carbs = carbs
            self.fat = fat
            self.portionGrams = portionGrams
            self.aliases = aliases
            self.icon = icon
        }
    }

    private struct NutritionValues {
        var calories: Double
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    private struct WeightedFood {
        let food: FoodItem
        let weight: Double
    }

    private static let recipeReference = FoodNutritionReference(
        basis: .recipeEstimate,
        sourceName: "USDA FoodData Central",
        sourceURLString: "https://fdc.nal.usda.gov/",
        referenceCode: nil,
        noteZH: "基于内置基础食材营养值、常见配方比例和烹饪方式估算；实际数值会随原料、用油、调味和份量变化，请在确认页核对重量。",
        noteEN: "Estimated from built-in ingredient values, typical recipe ratios, and cooking method. Ingredients, oil, seasoning, and serving size can change the result; verify the weight before saving."
    )

    private static let commonDishSpecs: [DishSpec] = [
        DishSpec("yu_xiang_shredded_pork", "鱼香肉丝", .protein, 156, 10.5, 11, 8, aliases: ["鱼香肉片"], icon: "🍖🌶️"),
        DishSpec("twice_cooked_pork", "回锅肉", .protein, 270, 12, 7, 22, aliases: ["川味回锅肉"], icon: "🥓🌶️"),
        DishSpec("green_pepper_pork", "青椒肉丝", .protein, 135, 11, 5, 7.5, aliases: ["辣椒炒肉丝"], icon: "🫑🍖"),
        DishSpec("beijing_sauce_pork", "京酱肉丝", .protein, 185, 12, 13, 9.5, icon: "🍖🥢"),
        DishSpec("moo_shu_pork", "木须肉", .protein, 145, 10, 5, 9, aliases: ["木樨肉"], icon: "🥚🍖"),
        DishSpec("boiled_pork_slices", "水煮肉片", .protein, 180, 14, 6, 11, icon: "🌶️🍖"),
        DishSpec("sweet_sour_pork", "糖醋里脊", .protein, 235, 12, 24, 10, aliases: ["糖醋肉"], icon: "🍖🍬"),
        DishSpec("farmhouse_pork", "农家小炒肉", .protein, 230, 13, 6, 19, aliases: ["小炒肉"], icon: "🌶️🥓"),
        DishSpec("mei_cai_pork", "梅菜扣肉", .protein, 300, 11, 9, 25, icon: "🥓🥬"),
        DishSpec("braised_ribs", "红烧排骨", .protein, 260, 16, 8, 20, icon: "🍖"),
        DishSpec("sweet_sour_ribs", "糖醋排骨", .protein, 285, 15, 20, 21, icon: "🍖🍬"),
        DishSpec("spicy_chicken", "辣子鸡", .protein, 245, 18, 8, 16, aliases: ["辣子鸡丁"], icon: "🌶️🍗"),
        DishSpec("poached_chicken", "白切鸡", .protein, 180, 19, 1, 11, aliases: ["白斩鸡"], icon: "🍗"),
        DishSpec("braised_chicken", "黄焖鸡", .protein, 170, 14, 7, 10, aliases: ["黄焖鸡块"], icon: "🍗🥘"),
        DishSpec("cola_wings", "可乐鸡翅", .protein, 220, 14, 12, 13, icon: "🍗🥤"),
        DishSpec("potato_chicken", "土豆烧鸡", .protein, 145, 10, 10, 7.5, aliases: ["土豆炖鸡", "土豆鸡块"], icon: "🥔🍗"),
        DishSpec("braised_beef_potato", "土豆烧牛肉", .protein, 155, 11, 11, 8, aliases: ["土豆炖牛肉"], icon: "🥔🥩"),
        DishSpec("tomato_beef_brisket", "番茄炖牛腩", .protein, 130, 10, 7, 7, aliases: ["西红柿炖牛腩"], icon: "🍅🥩"),
        DishSpec("onion_beef", "洋葱炒牛肉", .protein, 155, 13, 6, 9, icon: "🧅🥩"),
        DishSpec("cumin_lamb", "孜然羊肉", .protein, 230, 18, 5, 16, icon: "🥩🌿"),
        DishSpec("sauerkraut_fish", "酸菜鱼", .protein, 120, 13, 4, 6, icon: "🐟🥬"),
        DishSpec("boiled_fish", "水煮鱼", .protein, 170, 15, 5, 10, aliases: ["水煮鱼片"], icon: "🐟🌶️"),
        DishSpec("braised_fish", "红烧鱼", .protein, 150, 15, 7, 7.5, aliases: ["红烧鱼块"], icon: "🐟"),
        DishSpec("sweet_sour_fish", "糖醋鱼", .protein, 185, 13, 18, 7, icon: "🐟🍬"),
        DishSpec("garlic_shrimp", "蒜蓉虾", .protein, 125, 15, 5, 5, aliases: ["蒜蓉大虾"], icon: "🦐🧄"),
        DishSpec("spicy_crayfish", "麻辣小龙虾", .protein, 110, 15, 5, 3.5, aliases: ["香辣小龙虾", "小龙虾"], icon: "🦞🌶️"),
        DishSpec("home_style_tofu", "家常豆腐", .protein, 145, 8, 8, 9, icon: "🫘🥘"),
        DishSpec("braised_tofu", "红烧豆腐", .protein, 125, 7.5, 7, 7.5, icon: "🫘"),
        DishSpec("yu_xiang_eggplant", "鱼香茄子", .vegetable, 150, 3, 14, 9.5, aliases: ["鱼香茄子煲"], icon: "🍆🌶️"),
        DishSpec("di_san_xian", "地三鲜", .vegetable, 170, 3, 19, 9.5, icon: "🥔🍆"),
        DishSpec("dry_fried_green_beans", "干煸四季豆", .vegetable, 145, 5, 12, 9, aliases: ["干煸豆角"], icon: "🫛🌶️"),
        DishSpec("sour_spicy_potato", "酸辣土豆丝", .vegetable, 105, 2, 16, 4, icon: "🥔🌶️"),
        DishSpec("hand_torn_cabbage", "手撕包菜", .vegetable, 100, 2, 8, 7, aliases: ["手撕圆白菜"], icon: "🥬"),
        DishSpec("oyster_sauce_lettuce", "蚝油生菜", .vegetable, 75, 2, 7, 4.5, icon: "🥬"),
        DishSpec("garlic_broccoli", "蒜蓉西兰花", .vegetable, 75, 3.5, 8, 3.5, aliases: ["蒜炒西兰花"], icon: "🥦🧄"),
        DishSpec("chive_scrambled_egg", "韭菜炒鸡蛋", .protein, 145, 9, 4, 10, aliases: ["韭菜炒蛋"], icon: "🥚🥬"),
        DishSpec("eggplant_minced_pork", "肉末茄子", .protein, 155, 7, 10, 10, aliases: ["肉沫茄子"], icon: "🍆🍖"),
        DishSpec("fo_tiao_qiang", "佛跳墙", .protein, 105, 11, 5, 4.5, portionGrams: 350, icon: "🥘"),
        DishSpec("fuqi_feipian", "夫妻肺片", .protein, 220, 17, 6, 15, icon: "🥩🌶️"),
        DishSpec("ants_climbing_tree", "蚂蚁上树", .staple, 170, 6, 24, 6, icon: "🍜🍖"),
        DishSpec("braised_lion_head", "红烧狮子头", .protein, 250, 13, 8, 19, aliases: ["四喜丸子", "狮子头"], icon: "🍖🥘"),
        DishSpec("squirrel_mandarin_fish", "松鼠桂鱼", .protein, 220, 13, 20, 10, aliases: ["松鼠鳜鱼"], icon: "🐟"),
        DishSpec("beggars_chicken", "叫花鸡", .protein, 200, 20, 3, 12, aliases: ["叫化鸡"], icon: "🍗"),
        DishSpec("dongpo_pork", "东坡肉", .protein, 330, 11, 8, 28, icon: "🥓"),
        DishSpec("guobaorou", "锅包肉", .protein, 250, 12, 24, 12, icon: "🍖"),
        DishSpec("saliva_chicken", "口水鸡", .protein, 190, 17, 5, 12, icon: "🍗🌶️"),
        DishSpec("big_plate_chicken", "大盘鸡", .protein, 160, 11, 12, 8, portionGrams: 350, icon: "🍗🥔"),
        DishSpec("chopped_pepper_fish_head", "剁椒鱼头", .protein, 150, 15, 5, 8, icon: "🐟🌶️"),
        DishSpec("steamed_pork_rice_flour", "粉蒸肉", .protein, 240, 11, 16, 15, icon: "🍖🍚"),
        DishSpec("winter_melon_rib_soup", "冬瓜排骨汤", .protein, 55, 5, 2, 3, portionGrams: 400, icon: "🥣🍖"),
        DishSpec("seaweed_egg_soup", "紫菜蛋花汤", .protein, 35, 3, 3, 1.5, portionGrams: 400, aliases: ["紫菜鸡蛋汤"], icon: "🥣🥚"),
        DishSpec("tomato_egg_soup", "番茄鸡蛋汤", .protein, 40, 3, 4, 1.5, portionGrams: 400, aliases: ["西红柿鸡蛋汤", "番茄蛋花汤"], icon: "🥣🍅"),
        DishSpec("mushroom_soup", "菌菇汤", .vegetable, 35, 2.5, 5, 1, portionGrams: 400, aliases: ["蘑菇汤", "杂菌汤"], icon: "🥣🍄"),
        DishSpec("malatang", "麻辣烫", .protein, 105, 6, 11, 4.5, portionGrams: 500, icon: "🍲🌶️"),
        DishSpec("maocai", "冒菜", .protein, 120, 7, 10, 6, portionGrams: 450, icon: "🍲🥬"),
        DishSpec("chinese_hotpot", "火锅", .protein, 130, 8, 8, 7.5, portionGrams: 600, aliases: ["涮火锅"], icon: "🍲"),
        DishSpec("luosifen", "螺蛳粉", .staple, 135, 4.5, 20, 4.5, portionGrams: 500, icon: "🍜"),
        DishSpec("zhajiang_noodles", "炸酱面", .staple, 165, 7, 24, 5.5, portionGrams: 450, icon: "🍜"),
        DishSpec("reganmian", "热干面", .staple, 215, 7, 31, 7.5, portionGrams: 400, icon: "🍜"),
        DishSpec("chongqing_noodles", "重庆小面", .staple, 175, 6, 25, 6, portionGrams: 450, aliases: ["重庆麻辣小面"], icon: "🍜🌶️"),
        DishSpec("sour_spicy_noodles", "酸辣粉", .staple, 125, 3, 22, 3.5, portionGrams: 450, icon: "🍜🌶️"),
        DishSpec("liangpi", "凉皮", .staple, 155, 4, 25, 4.5, portionGrams: 350, aliases: ["陕西凉皮"], icon: "🍜"),
        DishSpec("beef_rice_bowl", "牛肉盖饭", .staple, 165, 7.5, 23, 5, portionGrams: 400, aliases: ["牛肉盖浇饭"], icon: "🍛🥩"),
        DishSpec("braised_pork_rice", "卤肉饭", .staple, 195, 7, 24, 8, portionGrams: 400, aliases: ["台湾卤肉饭"], icon: "🍛🍖")
    ]

    static let commonDishes: [FoodItem] = commonDishSpecs.map { spec in
        FoodItem(
            id: spec.id,
            name: spec.name,
            icon: spec.icon,
            category: spec.category,
            caloriesPer100g: spec.calories,
            proteinPer100g: spec.protein,
            carbsPer100g: spec.carbs,
            fatPer100g: spec.fat,
            aliases: spec.aliases.isEmpty ? nil : spec.aliases,
            portions: [FoodPortion(unit: "份", grams: spec.portionGrams, aliases: ["盘"])],
            nutritionReference: recipeReference
        )
    }

    static func estimatedFood(named rawName: String, foodLibrary: [FoodItem]) -> FoodItem? {
        let name = cleanedDishName(rawName)
        let key = normalized(name)
        guard key.count >= 2 else { return nil }
        guard exactFood(named: key, in: foodLibrary) == nil else { return nil }

        let components = ingredientComponents(for: key, foodLibrary: foodLibrary)
        guard !components.isEmpty || looksLikeDish(key) else { return nil }

        let category = inferredCategory(for: key, components: components)
        var nutrition = components.isEmpty
            ? fallbackNutrition(for: key, category: category)
            : blendedNutrition(from: components)
        applyCookingMethod(in: key, to: &nutrition)

        let id = "estimated_dish_\(stableHash(key))"
        let portionGrams = inferredPortionGrams(for: key)
        return FoodItem(
            id: id,
            name: name,
            icon: IconCatalog.foodIcon(id: id, category: category),
            category: category,
            caloriesPer100g: max(10, nutrition.calories.rounded(toPlaces: 1)),
            proteinPer100g: max(0, nutrition.protein.rounded(toPlaces: 1)),
            carbsPer100g: max(0, nutrition.carbs.rounded(toPlaces: 1)),
            fatPer100g: max(0, nutrition.fat.rounded(toPlaces: 1)),
            aliases: nil,
            portions: [FoodPortion(unit: "份", grams: portionGrams, aliases: ["盘"])],
            nutritionReference: recipeReference
        )
    }

    private static func exactFood(named key: String, in foodLibrary: [FoodItem]) -> FoodItem? {
        foodLibrary.first { food in
            ([food.name] + (food.aliases ?? [])).contains {
                normalized($0) == key
            }
        }
    }

    private static func ingredientComponents(
        for name: String,
        foodLibrary: [FoodItem]
    ) -> [WeightedFood] {
        var components: [WeightedFood] = []
        var usedIDs = Set<String>()

        func add(_ id: String, weight: Double, when condition: Bool) {
            guard
                condition,
                usedIDs.insert(id).inserted,
                let food = foodLibrary.first(where: { $0.id == id })
            else {
                return
            }
            components.append(WeightedFood(food: food, weight: weight))
        }

        let hasSpecificMeat = containsAny(
            ["牛", "羊", "鸡", "鸭", "鹅", "鱼", "虾", "蟹", "排骨", "五花", "猪"],
            in: name
        )
        add("beef_lean", weight: 0.58, when: containsAny(["牛肉", "牛腩", "牛柳", "牛杂", "牛"], in: name))
        add("lean_lamb", weight: 0.58, when: containsAny(["羊肉", "羊排", "羊杂", "羊"], in: name))
        add("chicken_leg", weight: 0.58, when: containsAny(["鸡肉", "鸡丁", "鸡块", "鸡腿", "鸡翅", "鸡"], in: name))
        add("duck_breast", weight: 0.58, when: containsAny(["鸭肉", "鸭"], in: name))
        add("pork_lean", weight: 0.58, when: containsAny(
            ["猪肉", "肉丝", "肉片", "肉丁", "肉末", "肉沫", "里脊", "排骨", "五花肉"],
            in: name
        ) || (name.contains("肉") && !hasSpecificMeat))
        add("egg", weight: 0.45, when: containsAny(["鸡蛋", "炒蛋", "蛋花", "蛋"], in: name))
        add("shrimp", weight: 0.55, when: containsAny(["虾仁", "大虾", "鲜虾", "虾"], in: name))
        add("tilapia", weight: 0.58, when: name.contains("鱼") && !name.contains("鱼香"))
        add("squid", weight: 0.55, when: containsAny(["鱿鱼", "墨鱼"], in: name))
        add("crab", weight: 0.55, when: containsAny(["蟹肉", "螃蟹", "蟹"], in: name))
        add("tofu", weight: 0.5, when: containsAny(["豆腐", "豆干", "香干"], in: name))

        add("rice_white", weight: 0.72, when: containsAny(["米饭", "盖饭", "盖浇饭", "炒饭", "烩饭"], in: name))
        add("noodles", weight: 0.72, when: containsAny(["面条", "拌面", "炒面", "汤面", "小面", "面"], in: name))
        add("rice_noodle", weight: 0.72, when: containsAny(["米粉", "米线", "粉丝", "酸辣粉"], in: name))
        add("potato", weight: 0.35, when: containsAny(["土豆", "马铃薯"], in: name))
        add("sweet_potato", weight: 0.35, when: containsAny(["红薯", "地瓜"], in: name))
        add("tomato", weight: 0.35, when: containsAny(["番茄", "西红柿"], in: name))
        add("bell_pepper", weight: 0.32, when: containsAny(["青椒", "彩椒", "辣椒"], in: name))
        add("eggplant", weight: 0.35, when: containsAny(["茄子", "茄丁"], in: name))
        add("cabbage", weight: 0.35, when: containsAny(["包菜", "圆白菜", "卷心菜", "白菜"], in: name))
        add("bok_choy", weight: 0.35, when: containsAny(["青菜", "小白菜", "油菜", "上海青"], in: name))
        add("broccoli", weight: 0.35, when: containsAny(["西兰花", "花椰菜"], in: name))
        add("spinach", weight: 0.35, when: name.contains("菠菜"))
        add("cucumber", weight: 0.35, when: containsAny(["黄瓜", "青瓜"], in: name))
        add("carrot", weight: 0.3, when: name.contains("胡萝卜"))
        add("mushroom", weight: 0.35, when: containsAny(["蘑菇", "香菇", "菌菇", "金针菇", "杏鲍菇", "木耳"], in: name))
        add("green_beans", weight: 0.35, when: containsAny(["四季豆", "豆角"], in: name))
        add("lotus_root", weight: 0.35, when: containsAny(["莲藕", "藕片"], in: name))
        add("onion", weight: 0.3, when: containsAny(["洋葱", "葱头"], in: name))
        add("pumpkin", weight: 0.35, when: name.contains("南瓜"))

        return components
    }

    private static func blendedNutrition(from components: [WeightedFood]) -> NutritionValues {
        let totalWeight = max(0.01, components.reduce(0) { $0 + $1.weight })
        return components.reduce(
            NutritionValues(calories: 0, protein: 0, carbs: 0, fat: 0)
        ) { result, component in
            let ratio = component.weight / totalWeight
            return NutritionValues(
                calories: result.calories + component.food.caloriesPer100g * ratio,
                protein: result.protein + component.food.proteinPer100g * ratio,
                carbs: result.carbs + component.food.carbsPer100g * ratio,
                fat: result.fat + component.food.fatPer100g * ratio
            )
        }
    }

    private static func applyCookingMethod(in name: String, to nutrition: inout NutritionValues) {
        if containsAny(["汤", "羹"], in: name) {
            nutrition.calories = nutrition.calories * 0.35 + 8
            nutrition.protein *= 0.4
            nutrition.carbs = nutrition.carbs * 0.35 + 1
            nutrition.fat = nutrition.fat * 0.35 + 0.5
            return
        }

        if containsAny(["油炸", "炸", "酥", "脆皮"], in: name) {
            nutrition.calories += 110
            nutrition.carbs += 5
            nutrition.fat += 10
        } else if containsAny(["干锅", "干煸", "香锅"], in: name) {
            nutrition.calories += 75
            nutrition.carbs += 3
            nutrition.fat += 7
        } else if containsAny(["糖醋", "鱼香", "宫保", "京酱", "红烧", "黄焖", "可乐"], in: name) {
            nutrition.calories += 55
            nutrition.carbs += 7
            nutrition.fat += 3
        } else if containsAny(["炒", "爆", "煎", "烧", "烩"], in: name) {
            nutrition.calories += 45
            nutrition.carbs += 2
            nutrition.fat += 4
        } else if containsAny(["凉拌", "拌"], in: name) {
            nutrition.calories += 25
            nutrition.carbs += 2
            nutrition.fat += 2
        } else if containsAny(["蒸", "煮", "炖", "焖", "白灼"], in: name) {
            nutrition.calories += 10
            nutrition.carbs += 1
            nutrition.fat += 0.5
        } else {
            nutrition.calories += 25
            nutrition.carbs += 1.5
            nutrition.fat += 2
        }
    }

    private static func fallbackNutrition(
        for name: String,
        category: FoodCategory
    ) -> NutritionValues {
        if containsAny(["粥"], in: name) {
            return NutritionValues(calories: 65, protein: 2.5, carbs: 11, fat: 1.2)
        }
        if containsAny(["粉", "面", "饭", "饼", "包", "馍"], in: name) {
            return NutritionValues(calories: 150, protein: 5, carbs: 25, fat: 3.5)
        }
        switch category {
        case .protein:
            return NutritionValues(calories: 145, protein: 12, carbs: 5, fat: 8)
        case .vegetable:
            return NutritionValues(calories: 55, protein: 2.5, carbs: 7, fat: 2)
        default:
            return NutritionValues(calories: 110, protein: 5, carbs: 12, fat: 4.5)
        }
    }

    private static func inferredCategory(
        for name: String,
        components: [WeightedFood]
    ) -> FoodCategory {
        if containsAny(["饭", "面", "粉", "粥", "饼", "包", "馍", "饺", "馄饨"], in: name) {
            return .staple
        }
        if components.contains(where: { $0.food.category == .protein }) ||
            containsAny(["肉", "鸡", "鸭", "鱼", "虾", "蟹", "蛋", "豆腐"], in: name) {
            return .protein
        }
        return .vegetable
    }

    private static func inferredPortionGrams(for name: String) -> Double {
        if containsAny(["火锅", "麻辣烫", "冒菜"], in: name) { return 500 }
        if containsAny(["汤", "羹", "粥", "面", "粉"], in: name) { return 400 }
        if containsAny(["饭", "盖浇"], in: name) { return 350 }
        return 250
    }

    private static func looksLikeDish(_ name: String) -> Bool {
        containsAny(
            [
                "炒", "烧", "炖", "焖", "煮", "蒸", "炸", "煎", "烤", "拌", "爆", "烩",
                "汤", "羹", "粥", "饭", "面", "粉", "饼", "包", "锅", "煲", "菜",
                "肉", "鸡", "鸭", "鱼", "虾", "蟹", "蛋", "豆腐", "茄子", "土豆"
            ],
            in: name
        )
    }

    private static func cleanedDishName(_ value: String) -> String {
        value.trimmingCharacters(
            in: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        )
    }

    private static func containsAny(_ values: [String], in text: String) -> Bool {
        values.contains(where: text.contains)
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

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}

enum SeedData {
    private static func food(
        _ id: String,
        _ name: String,
        _ category: FoodCategory,
        _ calories: Double,
        _ protein: Double,
        _ carbs: Double,
        _ fat: Double,
        icon: String? = nil,
        aliases: [String] = [],
        portions: [FoodPortion] = [],
        reference: FoodNutritionReference? = nil
    ) -> FoodItem {
        FoodItem(
            id: id,
            name: name,
            icon: icon ?? IconCatalog.foodIcon(id: id, category: category),
            category: category,
            caloriesPer100g: calories,
            proteinPer100g: protein,
            carbsPer100g: carbs,
            fatPer100g: fat,
            aliases: aliases.isEmpty ? nil : aliases,
            portions: portions.isEmpty ? nil : portions,
            nutritionReference: reference
        )
    }

    private static func exercise(
        _ id: String,
        _ name: String,
        _ category: ExerciseCategory,
        _ met: Double,
        icon: String? = nil
    ) -> ExerciseItem {
        ExerciseItem(id: id, name: name, icon: icon ?? IconCatalog.exerciseIcon(id: id, category: category), category: category, met: met)
    }

    private static let recipeEstimateReference = FoodNutritionReference(
        basis: .recipeEstimate,
        sourceName: "KeepFit Recipe Estimate",
        sourceURLString: nil,
        referenceCode: nil,
        noteZH: "按常见配方和熟制份量估算；实际数值会随原料、用油、大小和品牌变化，请在确认页按实际重量修正。",
        noteEN: "Estimated from a typical recipe and cooked serving. Ingredients, oil, size, and brand can change the result; adjust the weight before saving."
    )

    static let builtInFoodLibrary: [FoodItem] = [
        // Staple (20)
        food(
            "rice_white",
            "米饭(熟)",
            .staple,
            116,
            2.6,
            25.9,
            0.3,
            aliases: ["白米饭", "白饭", "大米饭", "熟米饭", "大米"],
            portions: [
                FoodPortion(unit: "碗", grams: 150, aliases: ["份"]),
                FoodPortion(unit: "盘", grams: 200)
            ]
        ),
        food(
            "rice_brown",
            "糙米饭(熟)",
            .staple,
            111,
            2.6,
            23,
            0.9,
            aliases: ["糙米", "杂粮糙米饭"],
            portions: [FoodPortion(unit: "碗", grams: 150, aliases: ["份"])]
        ),
        food("oatmeal", "燕麦片", .staple, 389, 16.9, 66.3, 6.9),
        food(
            "whole_wheat_bread",
            "全麦面包",
            .staple,
            247,
            13,
            41,
            4.2,
            aliases: ["全麦吐司", "全麦面包片"],
            portions: [FoodPortion(unit: "片", grams: 30, aliases: ["块"])]
        ),
        food(
            "bread_white",
            "白面包",
            .staple,
            266,
            8.7,
            49,
            3.2,
            aliases: ["面包", "面包片", "白吐司"],
            portions: [FoodPortion(unit: "片", grams: 30, aliases: ["块"])]
        ),
        food("sweet_potato", "红薯", .staple, 86, 1.6, 20.1, 0.1),
        food("potato", "土豆", .staple, 77, 2, 17.6, 0.1),
        food("corn", "玉米", .staple, 96, 3.4, 21, 1.5),
        food("noodles", "面条(熟)", .staple, 138, 4.5, 25, 1.1),
        food(
            "dumpling",
            "饺子(熟)",
            .staple,
            218,
            8.2,
            27.5,
            8.3,
            aliases: ["水饺"],
            portions: [
                FoodPortion(unit: "个", grams: 20, aliases: ["只", "枚"]),
                FoodPortion(unit: "份", grams: 200)
            ]
        ),
        food("quinoa", "藜麦(熟)", .staple, 120, 4.4, 21.3, 1.9),
        food("millet", "小米饭(熟)", .staple, 119, 3.5, 23, 1),
        food("barley", "大麦(熟)", .staple, 123, 2.3, 28, 0.4),
        food("pumpkin", "南瓜", .staple, 26, 1, 6.5, 0.1),
        food("rice_noodle", "米线(熟)", .staple, 109, 1.8, 24, 0.2),
        food("udon", "乌冬面(熟)", .staple, 127, 3, 25.8, 0.4),
        food("pasta_wholewheat", "全麦意面(熟)", .staple, 124, 5, 25, 0.8),
        food(
            "bun_steamed",
            "包子",
            .staple,
            214,
            7.5,
            40,
            2.5,
            portions: [FoodPortion(unit: "个", grams: 100, aliases: ["只"])]
        ),
        food(
            "mantou",
            "馒头",
            .staple,
            223,
            7,
            47,
            1.1,
            portions: [FoodPortion(unit: "个", grams: 100, aliases: ["只"])]
        ),
        food("bagel", "贝果", .staple, 250, 10, 49, 1.5),
        food("congee", "白粥", .staple, 46, 1.1, 10.2, 0.2),

        food("fried_rice", "炒饭", .staple, 188, 4.3, 31, 5.4, icon: "🍛"),
        food("fried_noodles", "炒面", .staple, 180, 5.6, 27, 5.2, icon: "🍝"),
        food("sushi_roll", "寿司卷", .staple, 145, 5.5, 28, 1.7, icon: "🍣"),
        food("wonton", "馄饨(熟)", .staple, 132, 6.5, 18, 3.5, icon: "🥟"),
        food("tortilla", "玉米饼", .staple, 218, 5.7, 45.6, 2.9, icon: "🌮"),
        food("pancake", "煎饼", .staple, 227, 6.4, 28.3, 9.7, icon: "🥞"),
        food("cereal", "谷物麦片", .staple, 379, 13.2, 67.7, 6.5, icon: "🥣🥄"),
        food("toast", "吐司", .staple, 266, 8.7, 49, 3.2, icon: "🍞🔥"),
        food("croissant", "可颂", .staple, 406, 8.2, 45.8, 21, icon: "🥐"),
        food("wrap", "卷饼", .staple, 296, 8.7, 49, 6.2, icon: "🌯"),

        // Protein (30)
        food("chicken_breast", "鸡胸肉", .protein, 165, 31, 0, 3.6),
        food("chicken_leg", "鸡腿肉", .protein, 209, 26, 0, 10.9),
        food("beef_lean", "瘦牛肉", .protein, 187, 20.4, 0, 12),
        food("pork_lean", "瘦猪肉", .protein, 143, 21, 0, 6.3),
        food("salmon", "三文鱼", .protein, 208, 20, 0, 13),
        food("tuna", "金枪鱼", .protein, 132, 28, 0, 1.3),
        food("shrimp", "虾仁", .protein, 99, 24, 0.2, 0.3),
        food(
            "egg",
            "鸡蛋",
            .protein,
            155,
            13,
            1.1,
            11,
            aliases: ["蛋"],
            portions: [FoodPortion(unit: "个", grams: 50, aliases: ["只", "枚"])]
        ),
        food("egg_white", "蛋清", .protein, 52, 11, 0.7, 0.2),
        food("tofu", "北豆腐", .protein, 76, 8.1, 1.9, 4.2),
        food("duck_breast", "鸭胸肉", .protein, 201, 19, 0, 14),
        food("cod", "鳕鱼", .protein, 82, 18, 0, 0.7),
        food("tilapia", "罗非鱼", .protein, 96, 20, 0, 1.7),
        food("mackerel", "鲭鱼", .protein, 205, 19, 0, 14),
        food("lean_lamb", "瘦羊肉", .protein, 206, 20, 0, 13),
        food("turkey_breast", "火鸡胸", .protein, 135, 29, 0, 1.6),
        food("prawn", "大虾", .protein, 99, 23, 0.9, 0.3),
        food("crab", "蟹肉", .protein, 97, 21, 0, 1.5),
        food("beef_shank", "牛腱", .protein, 170, 27, 0, 6),
        food("tempeh", "天贝", .protein, 193, 20, 9, 11),
        food("sardine", "沙丁鱼", .protein, 208, 24.6, 0, 11.5, icon: "🐟🥫"),
        food("mussel", "青口贝", .protein, 172, 24, 7, 4.5, icon: "🦪"),
        food("scallop", "扇贝", .protein, 88, 16.8, 3.2, 0.8, icon: "🐚"),
        food("squid", "鱿鱼", .protein, 92, 15.6, 3.1, 1.4, icon: "🦑"),
        food("oyster", "生蚝", .protein, 68, 7, 4, 2.5, icon: "🦪"),
        food("edamame", "毛豆", .protein, 121, 11.9, 8.9, 5.2, icon: "🫛"),
        food("chickpea", "鹰嘴豆", .protein, 164, 8.9, 27.4, 2.6, icon: "🫘🟡"),
        food("chicken_wing", "鸡翅", .protein, 203, 17.7, 0, 14.4, icon: "🍗🪽"),
        food("pork_tenderloin", "猪里脊", .protein, 143, 21, 0, 5.2, icon: "🍖🐖"),
        food("minced_beef", "牛肉末", .protein, 250, 17.2, 0, 20, icon: "🥩🔪"),

        // Vegetable (25)
        food("broccoli", "西兰花", .vegetable, 34, 2.8, 6.6, 0.4),
        food("spinach", "菠菜", .vegetable, 23, 2.9, 3.6, 0.4),
        food("lettuce", "生菜", .vegetable, 15, 1.4, 2.9, 0.2),
        food("tomato", "番茄", .vegetable, 18, 0.9, 3.9, 0.2),
        food("cucumber", "黄瓜", .vegetable, 16, 0.7, 3.6, 0.1),
        food("carrot", "胡萝卜", .vegetable, 41, 0.9, 9.6, 0.2),
        food("mushroom", "蘑菇", .vegetable, 22, 3.1, 3.3, 0.3),
        food("cauliflower", "花菜", .vegetable, 25, 1.9, 5, 0.3),
        food("bok_choy", "上海青", .vegetable, 13, 1.5, 2.2, 0.2),
        food("cabbage", "卷心菜", .vegetable, 25, 1.3, 5.8, 0.1),
        food("asparagus", "芦笋", .vegetable, 20, 2.2, 3.9, 0.1),
        food("bell_pepper", "彩椒", .vegetable, 31, 1, 6, 0.3),
        food("onion", "洋葱", .vegetable, 40, 1.1, 9.3, 0.1),
        food("eggplant", "茄子", .vegetable, 24, 1, 5.7, 0.2),
        food("zucchini", "西葫芦", .vegetable, 17, 1.2, 3.1, 0.3),
        food("kale", "羽衣甘蓝", .vegetable, 49, 4.3, 8.8, 0.9, icon: "🥬💪"),
        food("celery", "芹菜", .vegetable, 16, 0.7, 3, 0.2, icon: "🌿〰️"),
        food("green_beans", "四季豆", .vegetable, 31, 1.8, 7, 0.1, icon: "🫛"),
        food("pea", "豌豆", .vegetable, 81, 5.4, 14.5, 0.4, icon: "🫛🟢"),
        food("bean_sprout", "豆芽", .vegetable, 30, 3, 5.9, 0.2, icon: "🌱💧"),
        food("radish", "白萝卜", .vegetable, 18, 0.6, 4.1, 0.1, icon: "🥗"),
        food("lotus_root", "莲藕", .vegetable, 74, 2.6, 17.2, 0.1, icon: "🪷"),
        food("seaweed", "海带", .vegetable, 43, 1.7, 9.6, 0.6, icon: "🌿🌊"),
        food("okra", "秋葵", .vegetable, 33, 1.9, 7.5, 0.2, icon: "🌿⭐️"),
        food("broccoli_sprout", "西兰花苗", .vegetable, 35, 2.8, 6.6, 0.4, icon: "🌱🥦"),

        // Fruit (25)
        food("apple", "苹果", .fruit, 52, 0.3, 13.8, 0.2),
        food("banana", "香蕉", .fruit, 89, 1.1, 22.8, 0.3),
        food("orange", "橙子", .fruit, 47, 0.9, 11.8, 0.1),
        food("blueberry", "蓝莓", .fruit, 57, 0.7, 14.5, 0.3),
        food("strawberry", "草莓", .fruit, 32, 0.7, 7.7, 0.3),
        food("grape", "葡萄", .fruit, 69, 0.7, 18.1, 0.2),
        food("kiwi", "猕猴桃", .fruit, 61, 1.1, 14.7, 0.5),
        food("mango", "芒果", .fruit, 60, 0.8, 15, 0.4),
        food("watermelon", "西瓜", .fruit, 30, 0.6, 7.6, 0.2),
        food("avocado", "牛油果", .fruit, 160, 2, 8.5, 14.7),
        food("pineapple", "菠萝", .fruit, 50, 0.5, 13.1, 0.1),
        food("pear", "梨", .fruit, 57, 0.4, 15.2, 0.1),
        food("peach", "桃子", .fruit, 39, 0.9, 9.5, 0.3),
        food("cherry", "樱桃", .fruit, 63, 1.1, 16, 0.2),
        food("dragonfruit", "火龙果", .fruit, 60, 1.2, 13, 0.4),
        food("grapefruit", "西柚", .fruit, 42, 0.8, 10.7, 0.1, icon: "🍊🩷"),
        food("lemon", "柠檬", .fruit, 29, 1.1, 9.3, 0.3, icon: "🍋"),
        food("lime", "青柠", .fruit, 30, 0.7, 10.5, 0.2, icon: "🍋🟢"),
        food("papaya", "木瓜", .fruit, 43, 0.5, 10.8, 0.3, icon: "🍈🧡"),
        food("lychee", "荔枝", .fruit, 66, 0.8, 16.5, 0.4, icon: "🍒⚪️"),
        food("plum", "李子", .fruit, 46, 0.7, 11.4, 0.3, icon: "🫐🟣"),
        food("raspberry", "覆盆子", .fruit, 52, 1.2, 11.9, 0.7, icon: "🍓〰️"),
        food("blackberry", "黑莓", .fruit, 43, 1.4, 9.6, 0.5, icon: "🫐⚫️"),
        food("cantaloupe", "哈密瓜", .fruit, 34, 0.8, 8.2, 0.2, icon: "🍈"),
        food("coconut", "椰肉", .fruit, 354, 3.3, 15.2, 33.5, icon: "🥥"),

        // Dairy (12)
        food("greek_yogurt", "希腊酸奶", .dairy, 97, 9, 3.6, 5),
        food(
            "milk",
            "牛奶",
            .dairy,
            62,
            3.4,
            4.8,
            3.3,
            aliases: ["纯牛奶", "鲜牛奶"],
            portions: [FoodPortion(unit: "杯", grams: 240, aliases: ["盒"])]
        ),
        food(
            "soy_milk",
            "无糖豆浆",
            .dairy,
            33,
            2.9,
            1.6,
            1.6,
            aliases: ["豆浆", "豆奶"],
            portions: [FoodPortion(unit: "杯", grams: 240, aliases: ["碗"])]
        ),
        food("lowfat_milk", "低脂牛奶", .dairy, 46, 3.4, 4.9, 1.5),
        food("kefir", "开菲尔", .dairy, 56, 3.5, 4.5, 2.2),
        food("cottage_cheese", "茅屋奶酪", .dairy, 98, 11.1, 3.4, 4.3),
        food("cheddar_cheese", "切达奶酪", .dairy, 403, 24.9, 1.3, 33),
        food("mozzarella", "马苏里拉", .dairy, 280, 28, 3.1, 17),
        food("yogurt_plain", "原味酸奶", .dairy, 61, 3.5, 4.7, 3.3, icon: "🥣"),
        food("skyr", "冰岛酸奶", .dairy, 63, 11, 4, 0.2, icon: "🥣❄️"),
        food("soy_yogurt", "豆乳酸奶", .dairy, 54, 3.8, 6.2, 1.6, icon: "🫘🥣"),
        food("chocolate_milk", "巧克力牛奶", .dairy, 83, 3.2, 10.3, 3.4, icon: "🍫🥛"),

        // Nuts (14)
        food("almond", "杏仁", .nuts, 579, 21.2, 21.6, 49.9),
        food("walnut", "核桃", .nuts, 654, 15.2, 13.7, 65.2),
        food("peanut", "花生", .nuts, 567, 25.8, 16.1, 49.2),
        food("cashew", "腰果", .nuts, 553, 18.2, 30.2, 43.8),
        food("pistachio", "开心果", .nuts, 562, 20.2, 27.2, 45.4),
        food("macadamia", "夏威夷果", .nuts, 718, 7.9, 13.8, 75.8),
        food("sunflower_seed", "葵花籽", .nuts, 584, 20.8, 20, 51.5),
        food("pumpkin_seed", "南瓜籽", .nuts, 559, 30.2, 10.7, 49),
        food("hazelnut", "榛子", .nuts, 628, 15, 17, 61, icon: "🌰🤎"),
        food("pecan", "碧根果", .nuts, 691, 9.2, 13.9, 72, icon: "🌰🍂"),
        food("chestnut", "板栗", .nuts, 213, 2.4, 45.5, 2.3, icon: "🌰🔥"),
        food("chia_seed", "奇亚籽", .nuts, 486, 16.5, 42.1, 30.7, icon: "🫘⚫️"),
        food("flaxseed", "亚麻籽", .nuts, 534, 18.3, 28.9, 42.2, icon: "🌾🫘"),
        food("pine_nut", "松子", .nuts, 673, 13.7, 13.1, 68.4, icon: "🌲🌰"),

        // Drink (16)
        food("black_coffee", "美式咖啡", .drink, 2, 0.3, 0, 0),
        food("latte", "拿铁", .drink, 54, 2.8, 5.1, 2.3),
        food("green_tea", "绿茶", .drink, 1, 0, 0.2, 0),
        food("cola", "可乐", .drink, 42, 0, 10.6, 0),
        food("milk_tea", "奶茶", .drink, 80, 1.5, 13.5, 2.3),
        food("protein_powder", "蛋白粉", .drink, 380, 80, 8, 5),
        food("orange_juice", "橙汁", .drink, 45, 0.7, 10.4, 0.2),
        food("coconut_water", "椰子水", .drink, 19, 0.7, 3.7, 0.2),
        food("cappuccino", "卡布奇诺", .drink, 42, 2.1, 4.8, 1.5, icon: "☕️☁️"),
        food("espresso", "浓缩咖啡", .drink, 9, 0.1, 1.7, 0.2, icon: "☕️⚫️"),
        food("sparkling_water", "气泡水", .drink, 0, 0, 0, 0, icon: "🫧💧"),
        food("sports_drink", "运动饮料", .drink, 25, 0, 6.3, 0, icon: "⚡️🥤"),
        food("smoothie_berry", "莓果奶昔", .drink, 68, 1.6, 13.5, 0.8, icon: "🫐🧋"),
        food("lemonade", "柠檬水", .drink, 27, 0.1, 6.9, 0, icon: "🍋🧃"),
        food("tomato_juice", "番茄汁", .drink, 17, 0.8, 3.9, 0.1, icon: "🍅🧃"),
        food("oat_milk", "燕麦奶", .drink, 46, 1, 6.7, 1.5, icon: "🌾🥛"),

        // Snack (22)
        food("dark_chocolate", "黑巧克力", .snack, 598, 7.8, 45.9, 42.6),
        food("chips", "薯片", .snack, 536, 6.4, 52.9, 34.6),
        food("cookie", "曲奇饼干", .snack, 502, 6.2, 63, 24),
        food("ice_cream", "冰淇淋", .snack, 207, 3.5, 24, 11),
        food("beef_jerky", "牛肉干", .snack, 410, 33, 25, 17),
        food("energy_bar", "能量棒", .snack, 375, 16, 55, 10),
        food("popcorn", "爆米花", .snack, 387, 12.9, 78, 4.5),
        food("cracker", "苏打饼干", .snack, 450, 8, 70, 14),
        food("mooncake", "月饼", .snack, 408, 6.8, 56, 16),
        food("fried_chicken", "炸鸡", .snack, 294, 18, 8.9, 20),
        food("pretzel", "椒盐卷饼", .snack, 380, 9.1, 79.2, 3.5, icon: "🥨"),
        food("muffin", "松饼", .snack, 377, 5.6, 53.4, 16.1, icon: "🧁"),
        food("donut", "甜甜圈", .snack, 452, 4.9, 51.3, 25, icon: "🍩"),
        food("brownie", "布朗尼", .snack, 466, 4.9, 59.1, 22.7, icon: "🍫🟫"),
        food("rice_cracker", "米饼", .snack, 390, 6.8, 82, 1.5, icon: "🍘"),
        food("granola", "格兰诺拉", .snack, 471, 10, 64, 20, icon: "🥣🌾"),
        food("sandwich", "三明治", .snack, 250, 12, 25, 11, icon: "🥪"),
        food("hamburger", "汉堡", .snack, 295, 17, 30, 12, icon: "🍔"),
        food("pizza", "披萨", .snack, 266, 11, 33, 10, icon: "🍕"),
        food("hot_dog", "热狗", .snack, 290, 10, 23, 18, icon: "🌭"),
        food("spring_roll", "春卷", .snack, 220, 4.8, 24, 11, icon: "🌯"),
        food("seaweed_snack", "海苔脆", .snack, 430, 20, 35, 25, icon: "🌿🍘"),

        // Common Chinese dishes. Values are recipe estimates until a commercially licensed dataset is bundled.
        food(
            "grilled_sausage_cn",
            "烤肠",
            .protein,
            250,
            11,
            8,
            19.5,
            icon: "🌭",
            aliases: ["烤香肠", "台湾烤肠", "脆皮肠", "香肠"],
            portions: [FoodPortion(unit: "根", grams: 50, aliases: ["条", "个"])],
            reference: recipeEstimateReference
        ),
        food(
            "pork_cabbage_dumpling",
            "猪肉白菜水饺(熟)",
            .staple,
            218,
            8.2,
            27.5,
            8.3,
            icon: "🥟",
            aliases: ["猪肉白菜饺子", "猪肉白菜馅饺子", "猪肉白菜馅水饺", "白菜猪肉饺子"],
            portions: [
                FoodPortion(unit: "个", grams: 20, aliases: ["只", "枚"]),
                FoodPortion(unit: "份", grams: 200)
            ],
            reference: recipeEstimateReference
        ),
        food(
            "chive_egg_dumpling",
            "韭菜鸡蛋水饺(熟)",
            .staple,
            190,
            8,
            28,
            5.5,
            icon: "🥟",
            aliases: ["韭菜鸡蛋饺子", "韭菜鸡蛋馅饺子", "素三鲜饺子"],
            portions: [
                FoodPortion(unit: "个", grams: 20, aliases: ["只", "枚"]),
                FoodPortion(unit: "份", grams: 200)
            ],
            reference: recipeEstimateReference
        ),
        food(
            "pork_baozi",
            "猪肉包子",
            .staple,
            227,
            8.6,
            34.4,
            6.2,
            icon: "🥟☁️",
            aliases: ["肉包", "鲜肉包", "猪肉馅包子"],
            portions: [FoodPortion(unit: "个", grams: 100, aliases: ["只"]), FoodPortion(unit: "份", grams: 200)],
            reference: recipeEstimateReference
        ),
        food(
            "vegetable_baozi",
            "素菜包子",
            .staple,
            168,
            5.5,
            32,
            2.2,
            icon: "🥟🥬",
            aliases: ["菜包", "素包子", "蔬菜包"],
            portions: [FoodPortion(unit: "个", grams: 100, aliases: ["只"]), FoodPortion(unit: "份", grams: 200)],
            reference: recipeEstimateReference
        ),
        food(
            "jianbing_guozi",
            "煎饼果子",
            .staple,
            230,
            8,
            28,
            10,
            icon: "🥞",
            aliases: ["煎饼馃子", "杂粮煎饼"],
            portions: [FoodPortion(unit: "套", grams: 250, aliases: ["个", "份"])],
            reference: recipeEstimateReference
        ),
        food(
            "youtiao",
            "油条",
            .staple,
            388,
            6.9,
            51,
            18,
            icon: "🥖",
            aliases: ["炸油条"],
            portions: [FoodPortion(unit: "根", grams: 70, aliases: ["条"])],
            reference: recipeEstimateReference
        ),
        food(
            "egg_fried_rice_cn",
            "蛋炒饭",
            .staple,
            188,
            5.1,
            30.7,
            5.2,
            icon: "🍛",
            aliases: ["鸡蛋炒饭", "扬州炒饭"],
            portions: [FoodPortion(unit: "碗", grams: 300, aliases: ["份", "盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "beef_noodle_soup_cn",
            "牛肉汤面",
            .staple,
            105,
            6.2,
            13.8,
            2.8,
            icon: "🍜",
            aliases: ["牛肉面", "兰州牛肉面", "牛肉拉面"],
            portions: [FoodPortion(unit: "碗", grams: 500, aliases: ["份"])],
            reference: recipeEstimateReference
        ),
        food(
            "pork_wonton_soup",
            "鲜肉馄饨",
            .staple,
            90,
            5.4,
            13,
            2,
            icon: "🥟🥣",
            aliases: ["猪肉馄饨", "小馄饨", "云吞"],
            portions: [FoodPortion(unit: "碗", grams: 350, aliases: ["份"]), FoodPortion(unit: "个", grams: 15, aliases: ["只"])],
            reference: recipeEstimateReference
        ),
        food(
            "pork_preserved_egg_congee",
            "皮蛋瘦肉粥",
            .staple,
            68,
            3.2,
            9.2,
            2,
            icon: "🥣",
            aliases: ["瘦肉粥", "皮蛋粥"],
            portions: [FoodPortion(unit: "碗", grams: 400, aliases: ["份"])],
            reference: recipeEstimateReference
        ),
        food(
            "guilin_rice_noodles",
            "桂林米粉",
            .staple,
            92,
            3.5,
            16.8,
            1.2,
            icon: "🍜",
            aliases: ["米粉汤", "汤米粉"],
            portions: [FoodPortion(unit: "碗", grams: 500, aliases: ["份"])],
            reference: recipeEstimateReference
        ),
        food(
            "scallion_pancake_cn",
            "葱油饼",
            .staple,
            265,
            6,
            40,
            9,
            icon: "🥞",
            aliases: ["葱花饼", "香葱饼"],
            portions: [FoodPortion(unit: "张", grams: 100, aliases: ["个", "份"])],
            reference: recipeEstimateReference
        ),
        food(
            "pork_zongzi",
            "鲜肉粽子",
            .staple,
            220,
            7.5,
            32,
            7,
            icon: "🍙",
            aliases: ["肉粽", "猪肉粽"],
            portions: [FoodPortion(unit: "个", grams: 180, aliases: ["只"])],
            reference: recipeEstimateReference
        ),
        food(
            "red_bean_zongzi",
            "红豆粽子",
            .staple,
            185,
            4.5,
            39,
            1.5,
            icon: "🍙",
            aliases: ["豆沙粽", "甜粽"],
            portions: [FoodPortion(unit: "个", grams: 160, aliases: ["只"])],
            reference: recipeEstimateReference
        ),
        food(
            "sesame_tangyuan",
            "黑芝麻汤圆",
            .staple,
            280,
            5,
            43,
            10,
            icon: "⚪️🥣",
            aliases: ["芝麻汤圆", "汤圆"],
            portions: [FoodPortion(unit: "个", grams: 25, aliases: ["只", "枚"]), FoodPortion(unit: "碗", grams: 200, aliases: ["份"])],
            reference: recipeEstimateReference
        ),
        food(
            "shrimp_rice_roll",
            "鲜虾肠粉",
            .staple,
            110,
            4.8,
            20,
            1.2,
            icon: "🍚🦐",
            aliases: ["虾仁肠粉", "肠粉"],
            portions: [FoodPortion(unit: "份", grams: 250, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "roujiamo",
            "肉夹馍",
            .staple,
            250,
            11,
            31,
            9,
            icon: "🥙",
            aliases: ["腊汁肉夹馍"],
            portions: [FoodPortion(unit: "个", grams: 180, aliases: ["只", "份"])],
            reference: recipeEstimateReference
        ),
        food(
            "tomato_scrambled_egg",
            "番茄炒鸡蛋",
            .protein,
            105,
            5.5,
            4.5,
            7,
            icon: "🍅🥚",
            aliases: ["西红柿炒鸡蛋", "番茄炒蛋", "西红柿炒蛋"],
            portions: [FoodPortion(unit: "份", grams: 200, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "mapo_tofu",
            "麻婆豆腐",
            .protein,
            130,
            8,
            6,
            8.5,
            icon: "🌶️🫘",
            aliases: ["麻辣豆腐"],
            portions: [FoodPortion(unit: "份", grams: 250, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "kung_pao_chicken",
            "宫保鸡丁",
            .protein,
            185,
            14,
            10,
            10,
            icon: "🍗🥜",
            aliases: ["宫爆鸡丁"],
            portions: [FoodPortion(unit: "份", grams: 250, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "braised_pork_cn",
            "红烧肉",
            .protein,
            320,
            13,
            6,
            27,
            icon: "🍖",
            aliases: ["毛氏红烧肉"],
            portions: [FoodPortion(unit: "份", grams: 150, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "steamed_fish_cn",
            "清蒸鱼",
            .protein,
            125,
            18,
            2,
            5,
            icon: "🐟",
            aliases: ["清蒸鲈鱼", "蒸鱼"],
            portions: [FoodPortion(unit: "份", grams: 200, aliases: ["盘"])],
            reference: recipeEstimateReference
        ),
        food(
            "stir_fried_bok_choy",
            "清炒小白菜",
            .vegetable,
            55,
            2,
            5,
            3,
            icon: "🥬",
            aliases: ["炒青菜", "清炒青菜", "炒小白菜"],
            portions: [FoodPortion(unit: "份", grams: 200, aliases: ["盘"])],
            reference: recipeEstimateReference
        )
    ]

    static let foodLibrary: [FoodItem] = FoodCompositionDataLoader.mergedFoodLibrary(
        with: builtInFoodLibrary + ChineseDishNutritionEstimator.commonDishes
    )

    static let exerciseLibrary: [ExerciseItem] = [
        // Cardio (38)
        exercise("walking_slow", "散步", .cardio, 2.8),
        exercise("walking_fast", "快走", .cardio, 4.3),
        exercise("jogging", "慢跑", .cardio, 7.0),
        exercise("running", "跑步", .cardio, 9.8),
        exercise("cycling_light", "骑行(轻松)", .cardio, 5.5),
        exercise("cycling_fast", "骑行(高速)", .cardio, 8.5),
        exercise("jump_rope", "跳绳", .cardio, 12.3),
        exercise("hiit", "HIIT", .cardio, 10.0),
        exercise("elliptical", "椭圆机", .cardio, 5.0),
        exercise("stair_climber", "爬楼机", .cardio, 8.8),
        exercise("swim_light", "游泳(轻松)", .cardio, 6.0),
        exercise("swim_fast", "游泳(较快)", .cardio, 9.5),
        exercise("rowing_machine", "划船机", .cardio, 7.0),
        exercise("dancing", "跳舞", .cardio, 6.0),
        exercise("aerobics", "有氧操", .cardio, 7.3),
        exercise("spinning", "动感单车", .cardio, 8.5),
        exercise("zumba", "尊巴", .cardio, 7.8),
        exercise("step_aerobics", "踏板操", .cardio, 8.5),
        exercise("burpees", "波比跳", .cardio, 10.5),
        exercise("jumping_jacks", "开合跳", .cardio, 8.0),
        exercise("shadow_boxing", "空击", .cardio, 7.8),
        exercise("indoor_run", "室内慢跑", .cardio, 8.0),
        exercise("treadmill_walk", "跑步机快走", .cardio, 4.8),
        exercise("treadmill_run", "跑步机跑步", .cardio, 9.0),
        exercise("battle_rope", "战绳", .cardio, 10.3),
        exercise("skierg", "滑雪机", .cardio, 8.8),
        exercise("airbike", "风阻单车", .cardio, 9.0),
        exercise("mountain_bike", "山地骑行", .cardio, 8.5),
        exercise("kickboxing_cardio", "搏击有氧", .cardio, 9.5),
        exercise("rope_climb_machine", "爬绳机", .cardio, 9.2),
        exercise("sprint_interval", "冲刺间歇跑", .cardio, 11.0, icon: "🏃"),
        exercise("incline_walk", "坡度快走", .cardio, 5.3, icon: "🥾"),
        exercise("dance_kpop", "韩舞", .cardio, 6.8, icon: "🕺"),
        exercise("dance_jazz", "爵士舞", .cardio, 6.5, icon: "💃"),
        exercise("boxing_bag", "沙袋拳击", .cardio, 8.8, icon: "🥊"),
        exercise("stair_walk", "台阶走", .cardio, 5.0, icon: "🪜"),
        exercise("skipping_light", "轻跳绳", .cardio, 9.0, icon: "🪢"),
        exercise("water_aerobics", "水中有氧", .cardio, 5.5, icon: "🏊"),

        // Strength (32)
        exercise("bodyweight", "自重训练", .strength, 5.5),
        exercise("weight_training", "力量训练", .strength, 6.0),
        exercise("crossfit", "综合体能", .strength, 8.5),
        exercise("kettlebell", "壶铃训练", .strength, 8.0),
        exercise("squat_training", "下肢训练", .strength, 6.5),
        exercise("core_training", "核心训练", .strength, 5.0),
        exercise("plank", "平板支撑", .strength, 3.8),
        exercise("pushup", "俯卧撑", .strength, 8.0),
        exercise("pullup", "引体向上", .strength, 8.5),
        exercise("deadlift", "硬拉", .strength, 6.0),
        exercise("bench_press", "卧推", .strength, 6.0),
        exercise("shoulder_press", "推举", .strength, 5.5),
        exercise("lunge_training", "弓步训练", .strength, 6.0),
        exercise("resistance_band", "弹力带训练", .strength, 4.8),
        exercise("trx", "TRX 训练", .strength, 5.5),
        exercise("leg_press", "腿举", .strength, 5.5),
        exercise("lat_pulldown", "高位下拉", .strength, 5.0),
        exercise("seated_row", "坐姿划船", .strength, 5.0),
        exercise("bicep_curl", "弯举", .strength, 4.5),
        exercise("tricep_dip", "臂屈伸", .strength, 5.0),
        exercise("hip_thrust", "臀推", .strength, 5.0),
        exercise("glute_bridge", "臀桥", .strength, 4.0),
        exercise("calisthenics", "街头健身", .strength, 7.0),
        exercise("power_clean", "高翻", .strength, 8.0),
        exercise("sandbag_training", "沙袋训练", .strength, 7.5),
        exercise("dumbbell_training", "哑铃训练", .strength, 5.8, icon: "🏋️"),
        exercise("barbell_squat", "杠铃深蹲", .strength, 6.5, icon: "🏋️"),
        exercise("chest_fly", "飞鸟训练", .strength, 5.0, icon: "💪"),
        exercise("cable_row", "绳索划船", .strength, 5.3, icon: "🪢"),
        exercise("leg_curl", "腿弯举", .strength, 4.8, icon: "🦵"),
        exercise("leg_extension", "腿屈伸", .strength, 4.8, icon: "🦵"),
        exercise("farmer_walk", "农夫行走", .strength, 6.0, icon: "🚶"),

        // Flexibility (20)
        exercise("yoga", "瑜伽", .flexibility, 3.0),
        exercise("pilates", "普拉提", .flexibility, 3.5),
        exercise("stretching", "拉伸", .flexibility, 2.8),
        exercise("mobility", "灵活性训练", .flexibility, 3.2),
        exercise("tai_chi", "太极", .flexibility, 3.3),
        exercise("meditation_walk", "冥想散步", .flexibility, 2.5),
        exercise("foam_rolling", "泡沫轴放松", .flexibility, 2.0),
        exercise("dynamic_stretch", "动态拉伸", .flexibility, 3.0),
        exercise("static_stretch", "静态拉伸", .flexibility, 2.3),
        exercise("qigong", "气功", .flexibility, 2.8),
        exercise("breathing_flow", "呼吸流练习", .flexibility, 2.0),
        exercise("surya_namaskar", "拜日式", .flexibility, 3.8),
        exercise("barre", "芭蕾塑形", .flexibility, 4.0),
        exercise("yin_yoga", "阴瑜伽", .flexibility, 2.5),
        exercise("mobility_flow", "关节流动训练", .flexibility, 3.2),
        exercise("chair_yoga", "椅子瑜伽", .flexibility, 2.5, icon: "🪑"),
        exercise("fascia_release", "筋膜放松", .flexibility, 2.2, icon: "🌿"),
        exercise("shoulder_mobility", "肩颈活动", .flexibility, 2.8, icon: "🤸"),
        exercise("hip_opener", "髋部打开", .flexibility, 3.0, icon: "🧘"),
        exercise("recovery_flow", "恢复流", .flexibility, 2.7, icon: "🌿"),

        // Sports (28)
        exercise("boxing", "拳击训练", .sports, 8.5),
        exercise("badminton", "羽毛球", .sports, 5.5),
        exercise("basketball", "篮球", .sports, 8.0),
        exercise("soccer", "足球", .sports, 7.0),
        exercise("tennis", "网球", .sports, 7.3),
        exercise("table_tennis", "乒乓球", .sports, 4.0),
        exercise("volleyball", "排球", .sports, 4.5),
        exercise("baseball", "棒球", .sports, 5.0),
        exercise("golf", "高尔夫", .sports, 4.8),
        exercise("rugby", "橄榄球", .sports, 8.3),
        exercise("handball", "手球", .sports, 8.0),
        exercise("squash", "壁球", .sports, 8.0),
        exercise("pickleball", "匹克球", .sports, 5.0),
        exercise("fencing", "击剑", .sports, 6.0),
        exercise("taekwondo", "跆拳道", .sports, 10.0),
        exercise("judo", "柔道", .sports, 10.3),
        exercise("karate", "空手道", .sports, 9.8),
        exercise("muay_thai", "泰拳", .sports, 10.0),
        exercise("ultimate_frisbee", "飞盘", .sports, 7.0),
        exercise("water_polo", "水球", .sports, 10.0),
        exercise("padel", "板式网球", .sports, 7.0, icon: "🎾"),
        exercise("rock_climbing", "攀岩", .sports, 8.0, icon: "🧗"),
        exercise("bouldering", "抱石", .sports, 7.5, icon: "🧗"),
        exercise("surfing", "冲浪", .sports, 6.0, icon: "🏄"),
        exercise("skating_ice", "滑冰", .sports, 7.0, icon: "⛸️"),
        exercise("cricket", "板球", .sports, 5.0, icon: "🏏"),
        exercise("hockey", "曲棍球", .sports, 8.0, icon: "🏑"),
        exercise("archery", "射箭", .sports, 4.5, icon: "🏹"),

        // Outdoors (17)
        exercise("hiking", "徒步", .outdoors, 6.0),
        exercise("mountain_climb", "登山", .outdoors, 8.0),
        exercise("skating", "轮滑", .outdoors, 7.0),
        exercise("stairs_up", "爬楼", .outdoors, 8.8),
        exercise("housework", "家务", .outdoors, 3.5),
        exercise("rowing_outdoor", "户外划船", .outdoors, 7.0),
        exercise("kayaking", "皮划艇", .outdoors, 5.0),
        exercise("skiing", "滑雪", .outdoors, 7.0),
        exercise("snowboarding", "单板滑雪", .outdoors, 7.5),
        exercise("trail_running", "越野跑", .outdoors, 9.5),
        exercise("rucking", "负重行走", .outdoors, 7.8, icon: "🎒"),
        exercise("dog_walking", "遛狗", .outdoors, 3.5, icon: "🐕"),
        exercise("gardening", "园艺", .outdoors, 4.0, icon: "🪴"),
        exercise("paddle_board", "桨板", .outdoors, 6.0, icon: "🏄"),
        exercise("fishing", "钓鱼", .outdoors, 3.5, icon: "🎣"),
        exercise("snowshoe", "雪地徒步", .outdoors, 7.0, icon: "❄️"),
        exercise("orienteering", "定向越野", .outdoors, 8.0, icon: "🧭")
    ]
}
