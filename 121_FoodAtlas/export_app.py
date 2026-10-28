"""Export the Food Atlas into KeepFit's versioned, unit-aware offline contract."""
import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parent
CATEGORIES = {'staple', 'protein', 'vegetable', 'fruit', 'dairy', 'nuts', 'drink', 'snack', 'other'}
CATEGORY_MAP = {
    'Beef Products': ('protein', '🥩'), 'Pork Products': ('protein', '🍖'),
    'Poultry Products': ('protein', '🍗'), 'Lamb, Veal, and Game Products': ('protein', '🥩'),
    'Finfish and Shellfish Products': ('protein', '🐟'),
    'Legumes and Legume Products': ('protein', '🫘'),
    'Sausages and Luncheon Meats': ('protein', '🍖'),
    'Vegetables and Vegetable Products': ('vegetable', '🥬'),
    'Fruits and Fruit Juices': ('fruit', '🍎'), 'Dairy and Egg Products': ('dairy', '🥛'),
    'Nut and Seed Products': ('nuts', '🥜'), 'Beverages': ('drink', '🥤'),
    'Baked Products': ('staple', '🍞'), 'Cereal Grains and Pasta': ('staple', '🌾'),
    'Breakfast Cereals': ('staple', '🥣'), 'Sweets': ('snack', '🍬'), 'Snacks': ('snack', '🍪'),
}
NUTRIENTS = ('calories', 'protein', 'fat', 'carbs')


def validate(entry):
    for key in ('id', 'name', 'icon', 'sourceName'):
        if not isinstance(entry.get(key), str) or not entry[key].strip():
            raise ValueError(f'{entry.get("id")}: invalid {key}')
    if entry.get('category') not in CATEGORIES:
        raise ValueError(f'{entry["id"]}: invalid category')
    if not isinstance(entry.get('aliases'), list) or not all(isinstance(a, str) for a in entry['aliases']):
        raise ValueError(f'{entry["id"]}: invalid aliases')
    basis = entry['basis']
    for key in ('amount', *NUTRIENTS):
        number = basis.get(key)
        if isinstance(number, bool) or not isinstance(number, (int, float)) or not math.isfinite(number) or number < 0:
            raise ValueError(f'{entry["id"]}: invalid {key}')
    if basis['amount'] <= 0 or not isinstance(basis.get('unit'), str) or not basis['unit'].strip():
        raise ValueError(f'{entry["id"]}: invalid measurement basis')
    grams = basis.get('gramsPerUnit')
    if grams is not None and (isinstance(grams, bool) or not isinstance(grams, (int, float)) or not math.isfinite(grams) or grams <= 0):
        raise ValueError(f'{entry["id"]}: invalid gramsPerUnit')
    if basis['unit'] == 'g' and grams not in (None, 1):
        raise ValueError(f'{entry["id"]}: g must have gramsPerUnit=1')


def export(database, curation, output, version=None):
    config = json.loads(Path(curation).read_text())
    if config.get('schemaVersion') != 1:
        raise ValueError('Unsupported curation schema')
    entries = {}
    skipped = 0
    # Read the current master directly: newly authorized/updated foods require no intermediate export.
    with sqlite3.connect(f'{Path(database).resolve().as_uri()}?mode=ro', uri=True) as db:
        db.row_factory = sqlite3.Row
        aliases = {}
        for row in db.execute('SELECT food_id,alias FROM aliases ORDER BY alias'):
            aliases.setdefault(row['food_id'], []).append(row['alias'])
        rows = db.execute('''SELECT f.*,s.name AS source_name FROM commercial_foods f
                             JOIN sources s ON s.id=f.source_id ORDER BY f.id''')
        for row in rows:
            values = [row[k] for k in ('calories_kcal', 'protein_g', 'fat_g', 'carbs_g')]
            if any(v is None or not math.isfinite(v) or v < 0 for v in values):
                skipped += 1
                continue
            category, icon = CATEGORY_MAP.get(row['category'], ('other', '🍽️'))
            entries[row['id']] = {
                'id': row['id'], 'name': row['name_zh'] or row['name'],
                'nameEnglish': row['name_en'], 'icon': icon, 'category': category,
                'aliases': aliases.get(row['id'], []),
                'basis': dict(amount=100, unit='g', gramsPerUnit=1, **dict(zip(NUTRIENTS, values))),
                'sourceName': row['source_name'], 'sourceURL': row['source_url'],
            }
    for food_id, changes in config.get('overrides', {}).items():
        if food_id not in entries:
            raise ValueError(f'Override must target a complete authorized food: {food_id}')
        if set(changes) - {'name', 'nameEnglish', 'icon', 'category', 'aliases', 'basis', 'sourceName', 'sourceURL'}:
            raise ValueError(f'Unsupported override fields: {food_id}')
        entries[food_id].update(changes)
    for custom in config.get('foods', []):
        entry = dict(custom)
        if entry.pop('commercialUseAuthorized', False) is not True:
            raise ValueError('Custom foods must explicitly confirm commercialUseAuthorized')
        if not entry['id'].startswith('custom:') or entry['id'] in entries:
            raise ValueError('Custom food IDs must be unique and start with custom:')
        entries[entry['id']] = entry
    common_ids = config.get('commonFoodIDs', [])
    if not isinstance(common_ids, list) or not all(isinstance(i, str) for i in common_ids):
        raise ValueError('commonFoodIDs must be a list of stable food IDs')
    if len(common_ids) > 100 or len(set(common_ids)) != len(common_ids):
        raise ValueError('commonFoodIDs must contain at most 100 unique IDs')
    for rank, food_id in enumerate(common_ids):
        if food_id not in entries:
            raise ValueError(f'Common food must be complete and authorized: {food_id}')
        entries[food_id]['commonFoodRank'] = rank
    for entry in entries.values():
        validate(entry)
    if not entries:
        raise ValueError('Cannot export an empty atlas')
    # Put curated Chinese names first; preserve every source ID without merging by name.
    foods = sorted(entries.values(), key=lambda f: (not any('\u4e00' <= c <= '\u9fff' for c in f['name']), f['name'], f['id']))
    payload = dict(schemaVersion=1, version=version or datetime.now(timezone.utc).isoformat(timespec='seconds'), foods=foods)
    output = Path(output)
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(payload, ensure_ascii=False, separators=(',', ':'), allow_nan=False) + '\n')
    temporary.replace(output)
    return dict(foods=len(foods), excluded_incomplete=skipped, output=str(output))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=ROOT / '.data/foods.sqlite')
    parser.add_argument('--curation', type=Path, default=ROOT / 'app-foods.json')
    parser.add_argument('--output', type=Path, default=ROOT.parent / '120_App/KeepFitApp/Resources/KeepFitFoodAtlas.json')
    args = parser.parse_args()
    print(json.dumps(export(args.db, args.curation, args.output), ensure_ascii=False, indent=2))
