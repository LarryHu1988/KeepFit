"""Prepare a metadata-only icon proposal; never downloads or installs icon artwork."""
from pathlib import Path
import argparse
import collections
import csv
import json
import re

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent

# Explicit, reviewed semantic associations. These remain proposals, not asset IDs
# written into user food/exercise records. Visually inspect them after licensing.
GROUPS = {
    "rye-bread": "whole_wheat_bread",
    "corn-on-the-cob": "corn",
    "dumplings": "dumpling wonton pork_cabbage_dumpling chive_egg_dumpling pork_wonton_soup",
    "groat": "millet barley",
    "rice-vermicelli": "rice_noodle guilin_rice_noodles shrimp_rice_roll",
    "pasta": "pasta_wholewheat",
    "baozi": "bun_steamed pork_baozi vegetable_baozi",
    "bread-roll": "mantou",
    "luncheon-meat-fried-rice": "fried_rice egg_fried_rice_cn",
    "noodles": "fried_noodles luosifen zhajiang_noodles reganmian chongqing_noodles sour_spicy_noodles liangpi ants_climbing_tree",
    "sushi-california-roll": "sushi_roll",
    "corn-tortilla": "tortilla",
    "fruit-ring-cereal": "cereal",
    "burrito": "wrap",
    "chicken-roasted": "chicken_breast chicken_leg turkey_breast spicy_chicken poached_chicken braised_chicken potato_chicken beggars_chicken saliva_chicken big_plate_chicken kung_pao_chicken",
    "chicken-wings": "chicken_wing cola_wings",
    "beef-raw": "beef_lean beef_shank minced_beef braised_beef_potato tomato_beef_brisket onion_beef fuqi_feipian",
    "meat": "pork_lean pork_tenderloin lean_lamb cumin_lamb yu_xiang_shredded_pork twice_cooked_pork green_pepper_pork beijing_sauce_pork moo_shu_pork boiled_pork_slices sweet_sour_pork farmhouse_pork guobaorou steamed_pork_rice_flour",
    "crispy-pork-belly": "mei_cai_pork dongpo_pork braised_pork_cn",
    "ribs": "braised_ribs sweet_sour_ribs",
    "canned-tuna": "tuna",
    "egg": "egg_white",
    "smoked-duck-breast": "duck_breast",
    "fish-raw": "cod mackerel",
    "shrimp-925i6g": "prawn",
    "fish-cooked": "sauerkraut_fish boiled_fish braised_fish sweet_sour_fish squirrel_mandarin_fish chopped_pepper_fish_head steamed_fish_cn",
    "garlic-butter-shrimp": "garlic_shrimp",
    "tofu": "home_style_tofu braised_tofu mapo_tofu",
    "eggplant": "yu_xiang_eggplant eggplant_minced_pork di_san_xian",
    "potato": "sour_spicy_potato",
    "cabbage": "hand_torn_cabbage",
    "lettuce": "oyster_sauce_lettuce stir_fried_bok_choy bok_choy kale",
    "broccoli": "garlic_broccoli",
    "scrambled-egg": "chive_scrambled_egg tomato_scrambled_egg",
    "meatball": "braised_lion_head",
    "soup-bowl": "fo_tiao_qiang winter_melon_rib_soup seaweed_egg_soup tomato_egg_soup mushroom_soup",
    "hot-pot": "malatang maocai chinese_hotpot",
    "rice": "rice_white rice_brown congee pork_preserved_egg_congee beef_rice_bowl braised_pork_rice",
    "oyster-mushroom": "mushroom",
    "white-asparagus": "asparagus",
    "green-pepper": "bell_pepper",
    "can-of-peas": "pea",
    "fried-lotus-root": "lotus_root",
    "nori-sheet": "seaweed seaweed_snack",
    "kiwi-fruit": "kiwi",
    "cherries": "cherry",
    "dragon-fruit": "dragonfruit",
    "milk": "lowfat_milk chocolate_milk soy_milk",
    "cheese": "cottage_cheese cheddar_cheese",
    "mozzarella-cheese": "mozzarella",
    "yogurt": "yogurt_plain skyr soy_yogurt kefir",
    "pumpkin-seeds": "pumpkin_seed",
    "roasted-chestnut": "chestnut",
    "chia-seeds": "chia_seed",
    "filter-coffee": "black_coffee",
    "traditional-chinese-green-tea": "green_tea",
    "cola-can": "cola",
    "bubble-tea": "milk_tea",
    "coconut-water-carton": "coconut_water",
    "bottle-of-water": "sparkling_water sports_drink",
    "smoothie-bowl": "smoothie_berry",
    "chocolate-bar": "dark_chocolate",
    "cereal-bar": "energy_bar",
    "saltine-cracker": "cracker rice_cracker",
    "korean-fried-chicken": "fried_chicken",
    "blueberry-muffin": "muffin",
    "nems": "spring_roll",
    "sausage": "grilled_sausage_cn",
    "fried-scallion-pancake": "scallion_pancake_cn jianbing_guozi",
    "taiwan-beef-noodle-soup": "beef_noodle_soup_cn",
    "zongzi": "pork_zongzi red_bean_zongzi",
    "tangyuan": "sesame_tangyuan",
    "gua-bao": "roujiamo",
    "walk": "walking_slow walking_fast meditation_walk farmer_walk",
    "running": "jogging indoor_run sprint_interval trail_running",
    "bicycle": "cycling_light cycling_fast",
    "swimming": "swim_light swim_fast water_aerobics",
    "dance": "dancing dance_kpop dance_jazz zumba",
    "indoor-cycling-bike": "spinning airbike",
    "cross-trainer": "elliptical",
    "step-aerobics-platform": "step_aerobics stair_walk",
    "treadmill": "treadmill_walk treadmill_run incline_walk",
    "workout-5uerrd": "hiit burpees jumping_jacks bodyweight crossfit sandbag_training",
    "boxing": "shadow_boxing kickboxing_cardio muay_thai",
    "punching-bag": "boxing_bag",
    "climbing-rope": "rope_climb_machine battle_rope",
    "ski": "skierg",
    "skipping-rope": "skipping_light",
    "weightlifting": "weight_training power_clean",
    "squat-rack": "squat_training barbell_squat",
    "ab-wheel": "core_training",
    "bicep": "pushup lunge_training hip_thrust glute_bridge",
    "calisthenics-pull-up": "pullup calisthenics",
    "barbell": "deadlift",
    "weights-bench": "bench_press",
    "dumbbell": "shoulder_press dumbbell_training bicep_curl",
    "resistance-band": "trx",
    "high-low-pulley-cable": "lat_pulldown chest_fly",
    "lateral-seated-row-machine": "seated_row cable_row",
    "dip-bar": "tricep_dip",
    "lying-leg-curl-machine": "leg_curl",
    "leg-extension-machine": "leg_extension",
    "flexibility": "stretching mobility dynamic_stretch static_stretch mobility_flow shoulder_mobility recovery_flow",
    "foam-roller": "foam_rolling fascia_release",
    "tai-chi": "qigong breathing_flow",
    "yoga": "surya_namaskar yin_yoga chair_yoga hip_opener",
    "pilates": "barre",
    "soccer-ball": "soccer",
    "tennis-racket": "tennis",
    "table-tennis-paddle": "table_tennis",
    "squash-racket": "squash",
    "ultimate-disc": "ultimate_frisbee",
    "rock-climbing": "bouldering mountain_climb",
    "ice-skating": "skating_ice",
    "cricket-bat": "cricket",
    "hockey-stick": "hockey",
    "hiking-on-trails": "hiking",
    "inline-skate": "skating",
    "stair-climber": "stairs_up",
    "cleaning-the-table": "housework",
    "rowing-boat": "rowing_outdoor",
    "kayak": "kayaking",
    "hiking-backpack": "rucking",
    "gardening-starter-kit": "gardening",
    "paddleboard": "paddle_board",
    "fishing-rod": "fishing",
    "compass": "orienteering",
}

# These depictions are not the food/action itself. Keep them visibly pending.
REVIEW = set("""rice_brown congee pork_preserved_egg_congee whole_wheat_bread millet barley
rice_noodle pasta_wholewheat mantou fried_rice fried_noodles tortilla cereal chicken_breast
turkey_breast beef_lean pork_lean tuna egg_white cod mackerel lean_lamb beef_shank minced_beef
asparagus bok_choy kale pea lotus_root soy_milk lowfat_milk chocolate_milk cottage_cheese
cheddar_cheese skyr soy_yogurt kefir sparkling_water sports_drink smoothie_berry energy_bar
rice_cracker muffin fried_chicken youtiao hiit burpees jumping_jacks airbike battle_rope skierg
bodyweight crossfit core_training pushup lunge_training hip_thrust glute_bridge trx
lat_pulldown chest_fly sandbag_training stretching mobility qigong breathing_flow barre
chair_yoga hip_opener recovery_flow mountain_climb stairs_up housework rucking""".split())
REVIEW.update("kung_pao_chicken mapo_tofu braised_pork_cn steamed_fish_cn tomato_scrambled_egg stir_fried_bok_choy jianbing_guozi roujiamo".split())


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--catalog", type=Path, required=True, help="Public Thiings browsing catalog JSON")
    args = parser.parse_args()
    catalog = json.loads(args.catalog.read_text())
    by_slug = {item[0]: item for item in catalog["items"]}
    source = (ROOT / "120_App/KeepFitApp/SeedData.swift").read_text()
    rows = []
    explicit = {}
    for slug, identifiers in GROUPS.items():
        if slug not in by_slug:
            raise ValueError(f"Unknown catalog slug: {slug}")
        for identifier in identifiers.split():
            if identifier in explicit and explicit[identifier] != slug:
                raise ValueError(f"Conflicting proposal: {identifier}")
            explicit[identifier] = slug
    for kind, pattern in [("食材／菜品", "(?:food|DishSpec)"), ("运动", "exercise")]:
        for identifier, name, category in re.findall(r'\b' + pattern + r'\(\s*"([^"]+)",\s*"([^"]+)",\s*\.(\w+)', source):
            exact = identifier.replace("_", "-")
            slug = exact if exact in by_slug else explicit.get(identifier)
            recipe = source.find('DishSpec("' + identifier + '"') >= 0
            status = "直接候选" if slug == exact else "共享候选"
            note = "英文名称对应；素材外观仍需目视核对。" if status == "直接候选" else "同类食材、运动或器械共用；保留原项目名称与强度。"
            if recipe or identifier in REVIEW:
                status = "近似候选，需确认"
                note = "仅表示主食材、食物类别或训练器械，不表示准确菜式／动作；需目视选型确认。"
            if not slug:
                status = "待选型"
                note = "未找到可靠的同名或近义候选；不自动用另一种食材／动作冒充。"
            item = by_slug.get(slug)
            rows.append(dict(kind=kind, id=identifier, name=name, category=category,
                             status=status, thiings_slug=slug or "", thiings_name=item[2] if item else "",
                             source_url=f"https://www.thiings.co/things/{slug}" if slug else f"https://www.thiings.co/things?q={identifier.replace('_', '%20')}",
                             note=note))
    assert len({(row["kind"], row["id"]) for row in rows}) == len(rows)
    (OUT / "icon-mapping.json").write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n")
    with (OUT / "icon-mapping.csv").open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    counts = collections.Counter(row["status"] for row in rows)
    print(json.dumps({"total": len(rows), "by_kind": dict(collections.Counter(r["kind"] for r in rows)), "status": dict(counts)}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
