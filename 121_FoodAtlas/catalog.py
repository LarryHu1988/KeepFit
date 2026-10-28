"""Local food composition catalog. Python 3.9+, standard library only."""
import argparse
import csv
import hashlib
from html import unescape
from html.parser import HTMLParser
import json
import math
from pathlib import Path
import re
import sqlite3
import time
from datetime import datetime, timezone
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.robotparser import RobotFileParser
import zipfile

ROOT = Path(__file__).resolve().parent
DEFAULT_DB = ROOT / '.data' / 'foods.sqlite'
USER_AGENT = 'KeepFitFoodCatalog/1.0 (+https://larryhu.com)'
CDC_BASE = 'https://nlc.chinanutri.cn/fq/'
CDC_LIST = CDC_BASE + 'foodlist_0_0_0_0_0_1.htm'
CDC_TERMS = CDC_BASE + 'foodinfo/261.html'
USDA_BASE = 'https://fdc.nal.usda.gov/fdc-datasets/'
USDA_RELEASES = {
    'foundation': ('2026-04', 'FoodData_Central_foundation_food_json_2026-04-30.zip',
                   'foundation-2026-04.zip', 'Foundation Foods'),
    'sr-legacy': ('2018-04', 'FoodData_Central_sr_legacy_food_json_2018-04.zip',
                  'sr-legacy-2018-04.zip', 'SR Legacy'),
    'fndds': ('2024-10', 'FoodData_Central_survey_food_json_2024-10-31.zip',
              'fndds-2024-10.zip', 'FNDDS 2021-2023'),
}


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec='seconds')


def file_time(path):
    return datetime.fromtimestamp(Path(path).stat().st_mtime, timezone.utc).isoformat(timespec='seconds')


def digest(path):
    sha = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            sha.update(block)
    return sha.hexdigest()


def positive_number(value):
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) and number > 0 else None


def open_db(path=DEFAULT_DB):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(str(path))
    db.row_factory = sqlite3.Row
    db.executescript((ROOT / 'schema.sql').read_text())
    return db


def request_bytes(url, data=None, attempts=3):
    for attempt in range(attempts):
        try:
            request = Request(url, data=data, headers={'User-Agent': USER_AGENT})
            with urlopen(request, timeout=60) as response:
                return response.read()
        except HTTPError as error:
            if error.code in (401, 403, 404) or attempt == attempts - 1:
                raise
        except (URLError, TimeoutError):
            if attempt == attempts - 1:
                raise
        time.sleep(2 ** (attempt + 1))


def download(url, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and zipfile.is_zipfile(path):
        return path
    temporary = path.with_suffix(path.suffix + '.part')
    print('Downloading', url, flush=True)
    with urlopen(Request(url, headers={'User-Agent': USER_AGENT}), timeout=120) as response:
        with temporary.open('wb') as output:
            for block in iter(lambda: response.read(1024 * 1024), b''):
                output.write(block)
    if not zipfile.is_zipfile(temporary):
        raise ValueError('Download is not a ZIP archive: ' + url)
    temporary.replace(path)
    return path


def add_source(db, source):
    db.execute('''INSERT INTO sources VALUES (:id,:name,:version,:url,:license,
        :commercial_use_authorized,:retrieved_at,:raw_sha256,:notes)
        ON CONFLICT(id) DO UPDATE SET version=excluded.version,url=excluded.url,
        license=excluded.license,commercial_use_authorized=excluded.commercial_use_authorized,
        retrieved_at=excluded.retrieved_at,raw_sha256=excluded.raw_sha256,notes=excluded.notes''', source)


def save_food(db, food, nutrients, portions, aliases=()):
    db.execute('''INSERT INTO foods VALUES (:id,:source_id,:source_food_id,:name,:name_zh,
        :name_en,:category,:data_type,:source_url,:edible_percent,:calories_kcal,
        :protein_g,:fat_g,:carbs_g,:energy_method)
        ON CONFLICT(id) DO UPDATE SET name=excluded.name,name_zh=excluded.name_zh,
        name_en=excluded.name_en,category=excluded.category,data_type=excluded.data_type,
        source_url=excluded.source_url,edible_percent=excluded.edible_percent,
        calories_kcal=excluded.calories_kcal,protein_g=excluded.protein_g,
        fat_g=excluded.fat_g,carbs_g=excluded.carbs_g,energy_method=excluded.energy_method''', food)
    food_id = food['id']
    db.execute('DELETE FROM nutrients WHERE food_id=?', (food_id,))
    db.execute('DELETE FROM portions WHERE food_id=?', (food_id,))
    db.execute('DELETE FROM aliases WHERE food_id=?', (food_id,))
    db.executemany('INSERT INTO nutrients VALUES (?,?,?,?,?,?,?,?)',
                   [(food_id, *row) for row in nutrients])
    baseline = (food_id + ':100g', '100 g / 100克', 100, 'g', 100, 'mass', None)
    db.executemany('INSERT INTO portions VALUES (?,?,?,?,?,?,?,?)',
                   [(p[0], food_id, *p[1:]) for p in [baseline, *portions]])
    db.executemany('INSERT OR IGNORE INTO aliases VALUES (?,?,?,?)',
                   [(food_id, *alias) for alias in aliases if alias[0]])


def normalized_unit(value):
    return {'UG': 'ug', 'µg': 'ug', 'μg': 'ug', 'KCAL': 'kcal', 'kJ': 'kJ',
            'kj': 'kJ', 'G': 'g', 'MG': 'mg'}.get(value, value)


def usda_record(record, source_id):
    identifier = str(record['fdcId'])
    food_id = 'usda:' + identifier
    nutrients = []
    by_id = {}
    for row in record.get('foodNutrients', []):
        nutrient = row.get('nutrient') or {}
        if not nutrient or 'id' not in nutrient:
            continue
        raw_value = row.get('amount')
        value = raw_value
        qualifier = 'reported' if value is not None else 'missing'
        if value is not None:
            value = float(value)
            if not math.isfinite(value) or value < 0:
                # Some difference-calculated source carbohydrates are negative.
                # Preserve the evidence, but exclude it from intake calculations.
                value, qualifier = None, 'invalid_source_value'
        nid = str(nutrient['id'])
        unit = normalized_unit(nutrient.get('unitName', ''))
        # Avoid substituting Atwater-specific/general kcal or kJ for each other.
        by_id[nid] = (value, unit)
        method = (row.get('foodNutrientDerivation') or {}).get('description', 'USDA source')
        nutrients.append((nid, nutrient.get('name', nid), unit, value,
                          qualifier, '' if raw_value is None else str(raw_value), method))
    energy = None
    energy_method = 'missing'
    for nid in ('1008', '2048', '2047'):
        value, unit = by_id.get(nid, (None, ''))
        if value is not None and unit == 'kcal':
            energy = value
            energy_method = 'source_nutrient:' + nid
            break
    if energy is None:
        value, unit = by_id.get('1062', (None, ''))
        if value is not None and unit == 'kJ':
            energy, energy_method = value / 4.184, 'kJ/4.184'
    def grams(nid):
        value, unit = by_id.get(nid, (None, ''))
        return value if unit == 'g' else None
    food = dict(id=food_id, source_id=source_id, source_food_id=identifier,
                name=record['description'], name_en=record['description'], name_zh=None,
                category=(record.get('foodCategory') or {}).get('description'),
                data_type=record.get('dataType', 'USDA'),
                source_url='https://fdc.nal.usda.gov/food-details/' + identifier + '/nutrients',
                edible_percent=None, calories_kcal=energy, protein_g=grams('1003'),
                fat_g=grams('1004'), carbs_g=grams('1005'), energy_method=energy_method)
    portions = []
    for index, portion in enumerate(record.get('foodPortions', [])):
        amount = positive_number(portion.get('amount'))
        weight = positive_number(portion.get('gramWeight'))
        if amount is None or weight is None:
            continue
        measure = (portion.get('measureUnit') or {}).get('name', '')
        modifier = portion.get('modifier', '')
        description = portion.get('portionDescription') or ''
        unit = modifier if measure in ('undetermined', '', 'Quantity not specified') else measure
        if not unit:
            unit = description or 'source portion'
        label = description or ('%g %s' % (amount, unit))
        if modifier and modifier != unit and modifier not in label:
            label += ', ' + modifier
        pid = str(portion.get('id', index))
        portions.append((food_id + ':portion:' + pid, label, amount, unit,
                         weight, 'source', pid))
    return food, nutrients, portions


def import_usda(db, keys):
    for key in keys:
        version, filename, localname, label = USDA_RELEASES[key]
        archive = download(USDA_BASE + filename, ROOT / '.data/raw/usda' / localname)
        source_id = 'usda-' + key
        # One transaction per release: a failed import cannot leave a partial release.
        with db:
            add_source(db, dict(id=source_id, name='USDA FoodData Central - ' + label,
                version=version, url=USDA_BASE + filename, license='CC0-1.0',
                commercial_use_authorized=1, retrieved_at=file_time(archive), raw_sha256=digest(archive),
                notes='Nutrients per 100 g edible food. Raw/cooked states retained; missing is NULL.'))
            with zipfile.ZipFile(archive) as zipped:
                member = next(n for n in zipped.namelist() if n.endswith('.json'))
                with zipped.open(member) as stream:
                    payload = json.load(stream)
            records = next(v for v in payload.values() if isinstance(v, list))
            imported, null_records = 0, 0
            for record in records:
                if record is None:
                    null_records += 1
                    continue
                save_food(db, *usda_record(record, source_id))
                imported += 1
            del payload
            if null_records:
                db.execute('UPDATE sources SET notes=notes || ? WHERE id=?',
                           (' Source contains %d null records; skipped.' % null_records, source_id))
            print('Imported', label, imported, 'foods;', null_records, 'null source records skipped', flush=True)
        del records


class ChinaHeaders(HTMLParser):
    def __init__(self):
        super().__init__()
        self.columns = {}

    def handle_starttag(self, tag, attributes):
        attributes = dict(attributes)
        if tag == 'th' and re.fullmatch(r'foodName\d+', attributes.get('id', '')):
            match = re.search(r'ysq_code_(\w+)', attributes.get('class', ''))
            if match:
                self.columns[int(attributes['id'][8:])] = match.group(1)


# Values are keyed by the website's field identifiers, not positional assumptions.
CHINA_NUTRIENTS = {
    'shibu': ('可食部', '%'), 'shuifen': ('水分', 'g'), 'nliang': ('能量', 'kJ'),
    'danbz': ('蛋白质', 'g'), 'zhifang': ('脂肪', 'g'), 'danguchun': ('胆固醇', 'mg'),
    'huifen': ('灰分', 'g'), 'tshhw': ('碳水化合物', 'g'), 'qianwei': ('总膳食纤维', 'g'),
    'hlbs': ('胡萝卜素', 'ug'), 'shc': ('维生素A（源表口径）', 'ug'),
    'afte': ('维生素E α-TE（源表口径）', 'mg'), 'las': ('硫胺素', 'mg'),
    'hhs': ('核黄素', 'mg'), 'yanSuan': ('烟酸', 'mg'), 'wssC': ('维生素C', 'mg'),
    'gai': ('钙', 'mg'), 'lin': ('磷', 'mg'), 'jia': ('钾', 'mg'), 'na': ('钠', 'mg'),
    'mei': ('镁', 'mg'), 'tie': ('铁', 'mg'), 'xin': ('锌', 'mg'), 'xi': ('硒', 'ug'),
    'tong': ('铜', 'mg'), 'meng': ('锰', 'mg'), 'dian': ('碘', 'ug'),
    'zfsSaturatedPercent': ('饱和脂肪酸比例', '%'),
    'zfsMonounPercent': ('单不饱和脂肪酸比例', '%'),
    'zfsPolyunPercent': ('多不饱和脂肪酸比例', '%'),
    'zfsTotalPercent': ('脂肪酸比例合计', '%'),
}


def china_value(raw, expected_unit):
    text = unescape(str(raw)).strip()
    qualifiers = {'': 'missing', '—': 'not_tested', '-': 'not_tested',
                  'Tr': 'not_detected', 'un': 'not_computable'}
    if text in qualifiers:
        return None, expected_unit, qualifiers[text]
    match = re.fullmatch(r'([0-9]+(?:\.[0-9]+)?)\s*(kJ|kcal|mg|[μµu]g|g|%)?', text)
    if not match:
        raise ValueError('Unrecognized source nutrient: ' + repr(text))
    unit = normalized_unit(match.group(2) or expected_unit)
    if unit != expected_unit:
        raise ValueError('Unexpected source unit: ' + repr(text) + ' expected ' + expected_unit)
    return float(match.group(1)), unit, 'reported'


def china_record(row, columns):
    if sorted(columns) != list(range(len(columns))) or len(row) != len(columns) + 2:
        raise ValueError('China CDC schema drift: expected %d columns, got %d' % (len(columns) + 2, len(row)))
    values = {key: row[index + 2] for index, key in columns.items()}
    identifier = str(row[0])
    food_id = 'china-cdc:' + identifier
    nutrients, parsed = [], {}
    for key, (name, unit) in CHINA_NUTRIENTS.items():
        value, unit, qualifier = china_value(values[key], unit)
        parsed[key] = value
        nutrients.append((key, name, unit, value, qualifier, str(values[key]), 'China CDC source'))
    energy = parsed['nliang']
    food = dict(id=food_id, source_id='china-cdc', source_food_id=identifier,
        name=values['foodName'], name_zh=values['foodName'], name_en=values.get('englishName') or None,
        category=None, data_type='China food composition public query',
        source_url=CDC_BASE + 'foodinfo/' + identifier + '.html',
        edible_percent=parsed['shibu'], calories_kcal=None if energy is None else energy / 4.184,
        protein_g=parsed['danbz'], fat_g=parsed['zhifang'], carbs_g=parsed['tshhw'],
        energy_method='missing' if energy is None else 'kJ/4.184')
    aliases = [(a.strip(), 'zh', 'source') for a in re.split(r'[、,，;；]', values.get('otherName', '')) if a.strip()]
    return food, nutrients, [], aliases


def crawl_china(db, interval=1.0, refresh=False):
    raw_dir = ROOT / '.data/raw/china-cdc'
    if refresh:
        raw_dir = raw_dir / 'snapshots' / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    raw_dir.mkdir(parents=True, exist_ok=True)
    robots_url = 'https://nlc.chinanutri.cn/robots.txt'
    try:
        robots = request_bytes(robots_url)
    except HTTPError as error:
        if error.code != 404:
            raise
        robots = b'# robots.txt returned HTTP 404 at collection time\n'
    (raw_dir / 'robots.txt').write_bytes(robots)
    if not robots.lstrip().startswith(b'<'):
        parser = RobotFileParser()
        parser.parse(robots.decode('utf-8').splitlines())
        if not parser.can_fetch(USER_AGENT, CDC_LIST) or not parser.can_fetch(USER_AGENT, CDC_BASE + 'FoodInfoQueryAction!queryFoodInfoList.do'):
            raise ValueError('robots.txt disallows collection')
        interval = max(interval, parser.crawl_delay(USER_AGENT) or 0)
    header_path = raw_dir / 'list-schema.html'
    if not header_path.exists():
        header_path.write_bytes(request_bytes(CDC_LIST))
    headers = ChinaHeaders()
    headers.feed(header_path.read_text())
    columns = headers.columns
    expected = set(CHINA_NUTRIENTS) | {'foodName', 'otherName', 'englishName'}
    if set(columns.values()) != expected:
        raise ValueError('China CDC header drift: ' + repr(set(columns.values()) ^ expected))
    terms_path = raw_dir / 'license-example.html'
    if not terms_path.exists():
        terms_path.write_bytes(request_bytes(CDC_TERMS))
    if '不得用于商业目的' not in terms_path.read_text():
        raise ValueError('License page changed; review before importing')
    page, total, records, seen, sha = 1, 1, [], set(), hashlib.sha256()
    previous_request = time.monotonic()
    while page <= total:
        cache = raw_dir / ('page-%04d.json' % page)
        if cache.exists():
            raw = cache.read_bytes()
        else:
            time.sleep(max(0, interval - (time.monotonic() - previous_request)))
            data = urlencode(dict(categoryOne=0, categoryTwo=0, foodName=0,
                                  pageNum=page, field=0, flag=0)).encode()
            raw = request_bytes(CDC_BASE + 'FoodInfoQueryAction!queryFoodInfoList.do', data)
            previous_request = time.monotonic()
            json.loads(raw)
            cache.write_bytes(raw)
        payload = json.loads(raw)
        if int(payload['currentPage']) != page:
            raise ValueError('Unexpected CDC page number')
        if page == 1:
            total = int(payload['totalPages'])
            if not 1 <= total <= 5000:
                raise ValueError('Unexpected CDC page count')
        elif int(payload['totalPages']) != total:
            raise ValueError('CDC page count changed during collection')
        if not payload['list']:
            raise ValueError('Empty CDC page: ' + str(page))
        sha.update(raw)
        for row in payload['list']:
            if row[0] in seen:
                raise ValueError('Duplicate CDC food across pages: ' + str(row[0]))
            seen.add(row[0])
            records.append(china_record(row, columns))
        if page == 1 or page % 10 == 0 or page == total:
            print('China CDC', page, '/', total, 'pages;', len(records), 'foods', flush=True)
        page += 1
    retrieved_at = max(file_time(p) for p in raw_dir.glob('page-*.json'))
    with db:
        add_source(db, dict(id='china-cdc', name='中国疾控中心营养与健康所 / 中国食物成分表公开查询',
            version='public-query-' + retrieved_at[:10],
            url=CDC_TERMS, license='Commercial use requires written permission from China CDC NINH',
            commercial_use_authorized=0, retrieved_at=retrieved_at, raw_sha256=sha.hexdigest(),
            notes='Local reference only; excluded from App/commercial exports pending permission. '
                  '100 g source basis; household portion weights not supplied.'))
        for record in records:
            save_food(db, *record)
    print('Imported China CDC', len(records), 'foods (restricted)', flush=True)


def apply_names(db):
    path = ROOT / 'chinese-names.json'
    translations = json.loads(path.read_text())['foods'] if path.exists() else []
    with db:
        for entry in translations:
            food_id = entry['id']
            food = db.execute('SELECT name_en FROM foods WHERE id=?', (food_id,)).fetchone()
            if not food:
                continue
            if entry.get('source_description') and food[0] != entry['source_description']:
                raise ValueError('Translation no longer matches source: ' + food_id)
            db.execute('UPDATE foods SET name_zh=? WHERE id=?', (entry['name'], food_id))
            for alias in [entry['name'], *entry.get('aliases', [])]:
                db.execute('INSERT OR IGNORE INTO aliases VALUES (?,?,?,?)',
                           (food_id, alias, 'zh', 'KeepFit exact-record translation'))


def search(db, query, limit=20, include_restricted=False):
    if not 1 <= limit <= 100:
        raise ValueError('limit must be 1..100')
    query = query.strip()
    if not query:
        return []
    escaped = query.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_')
    pattern = '%' + escaped + '%'
    rows = db.execute('''SELECT f.*, s.name AS source_name,s.license,s.commercial_use_authorized
        FROM foods f JOIN sources s ON s.id=f.source_id
        WHERE (? OR s.commercial_use_authorized=1) AND
        (f.name LIKE ? ESCAPE '\\' OR f.name_zh LIKE ? ESCAPE '\\' OR f.name_en LIKE ? ESCAPE '\\'
         OR EXISTS (SELECT 1 FROM aliases a WHERE a.food_id=f.id AND a.alias LIKE ? ESCAPE '\\'))
        ORDER BY CASE WHEN f.name=? OR f.name_zh=? OR f.name_en=? THEN 0
          WHEN EXISTS (SELECT 1 FROM aliases a WHERE a.food_id=f.id AND a.alias=?) THEN 1 ELSE 2 END,
          CASE f.source_id WHEN 'usda-foundation' THEN 0 WHEN 'usda-sr-legacy' THEN 1 ELSE 2 END,
          f.name LIMIT ?''',
        (int(include_restricted), pattern, pattern, pattern, pattern, query, query, query, query, limit))
    return [dict(row) for row in rows]


def detail(db, food_id, include_restricted=False):
    row = db.execute('''SELECT f.*,s.name AS source_name,s.license,s.commercial_use_authorized
        FROM foods f JOIN sources s ON s.id=f.source_id WHERE f.id=?
        AND (? OR s.commercial_use_authorized=1)''', (food_id, int(include_restricted))).fetchone()
    if row is None:
        raise ValueError('Food not found or source not authorized: ' + food_id)
    result = dict(row)
    result['nutrients_per_100g'] = [dict(r) for r in db.execute('SELECT * FROM nutrients WHERE food_id=?', (food_id,))]
    result['portions'] = [dict(r) for r in db.execute('SELECT * FROM portion_nutrition WHERE food_id=?', (food_id,))]
    result['aliases'] = [dict(r) for r in db.execute('SELECT alias,language,provenance FROM aliases WHERE food_id=?', (food_id,))]
    return result


def export_db(db, target, compact=False):
    target = Path(target).resolve()
    original = Path(db.execute('PRAGMA database_list').fetchone()['file']).resolve()
    if target == original:
        raise ValueError('Export target must differ from master database')
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_suffix('.building.sqlite')
    temporary.unlink(missing_ok=True)
    exported = sqlite3.connect(str(temporary))
    try:
        db.backup(exported)
        exported.execute('PRAGMA foreign_keys=ON')
        with exported:
            exported.execute('DELETE FROM foods WHERE source_id IN (SELECT id FROM sources WHERE commercial_use_authorized=0)')
            exported.execute('DELETE FROM sources WHERE commercial_use_authorized=0')
            if compact:
                exported.execute('''DELETE FROM nutrients WHERE nutrient_id NOT IN
                    ('1003','1004','1005','1008','1062','2047','2048','1079','2000','1258','1093')''')
        exported.execute('VACUUM')
        if exported.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Export integrity check failed')
    finally:
        exported.close()
    temporary.replace(target)
    return target


def export_csv(db, target, include_restricted=False, table='portions', source=None):
    target = Path(target)
    target.parent.mkdir(parents=True, exist_ok=True)
    if table == 'foods':
        sql = '''SELECT f.id AS 食物ID,COALESCE(f.name_zh,f.name) AS 食物名称,f.name_en AS 英文名,
            100 AS "基准重量(g)",f.calories_kcal AS "热量(kcal/100g)",
            f.protein_g AS "蛋白质(g/100g)",f.fat_g AS "脂肪(g/100g)",f.carbs_g AS "碳水(g/100g)",
            f.edible_percent AS "可食部(%)",f.energy_method AS 热量来源方式,s.name AS 数据来源,
            s.version AS 来源版本,s.license AS 许可,s.commercial_use_authorized AS 可商用,
            f.source_url AS 原文链接
            FROM foods f JOIN sources s ON s.id=f.source_id
            WHERE (? OR s.commercial_use_authorized=1) AND (? IS NULL OR f.source_id=?) ORDER BY f.id'''
    elif table == 'nutrients':
        sql = '''SELECT f.id AS food_id,COALESCE(f.name_zh,f.name) AS food_name,n.nutrient_id,
            n.name AS nutrient,n.unit,n.amount,n.qualifier,n.raw_value,n.method,
            f.source_url,s.license,s.commercial_use_authorized
            FROM nutrients n JOIN foods f ON f.id=n.food_id JOIN sources s ON s.id=f.source_id
            WHERE (? OR s.commercial_use_authorized=1) AND (? IS NULL OR f.source_id=?)
            ORDER BY f.id,n.nutrient_id'''
    else:
        sql = '''SELECT * FROM portion_nutrition WHERE (? OR commercial_use_authorized=1)
            AND (? IS NULL OR source_id=?) ORDER BY food_id,portion_id'''
    rows = db.execute(sql, (int(include_restricted), source, source))
    with target.open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow([column[0] for column in rows.description])
        writer.writerows(rows)


def report(db):
    counts = []
    for row in db.execute('''SELECT s.id,s.name,s.version,s.license,s.commercial_use_authorized,
        COUNT(f.id) AS foods,SUM(f.calories_kcal IS NOT NULL AND f.protein_g IS NOT NULL
          AND f.fat_g IS NOT NULL AND f.carbs_g IS NOT NULL) AS complete_macros
        FROM sources s LEFT JOIN foods f ON f.source_id=s.id GROUP BY s.id ORDER BY s.id'''):
        counts.append(dict(row))
    result = dict(generated_at=utc_now(), schema_version=db.execute('PRAGMA user_version').fetchone()[0],
        sources=counts, integrity=db.execute('PRAGMA integrity_check').fetchone()[0],
        foreign_key_errors=[list(r) for r in db.execute('PRAGMA foreign_key_check')],
        foods=db.execute('SELECT COUNT(*) FROM foods').fetchone()[0],
        nutrients=db.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0],
        source_portions=db.execute("SELECT COUNT(*) FROM portions WHERE basis='source'").fetchone()[0],
        chinese_names=db.execute('SELECT COUNT(*) FROM foods WHERE name_zh IS NOT NULL').fetchone()[0],
        missing_macros=db.execute('''SELECT COUNT(*) FROM foods WHERE calories_kcal IS NULL
            OR protein_g IS NULL OR fat_g IS NULL OR carbs_g IS NULL''').fetchone()[0],
        invalid_nutrients=db.execute('SELECT COUNT(*) FROM nutrients WHERE amount<0').fetchone()[0],
        invalid_source_values=db.execute("SELECT COUNT(*) FROM nutrients WHERE qualifier='invalid_source_value'").fetchone()[0])
    # NULL is preserved in tables and in calculated portion views.
    result['qualifiers'] = dict(db.execute('SELECT qualifier,COUNT(*) FROM nutrients GROUP BY qualifier').fetchall())
    result['source_details'] = [dict(r) for r in db.execute('SELECT * FROM sources ORDER BY id')]
    return result


def build_outputs(db):
    apply_names(db)
    output = ROOT / '.data/exports'
    snapshot = export_db(db, output / 'KeepFitFoods.sqlite', compact=True)
    export_csv(db, output / 'foods-per-100g.csv', table='foods')
    export_csv(db, output / 'food-portions.csv')
    export_csv(db, ROOT / '.data/reference-only/china-cdc-per-100g.csv',
               include_restricted=True, table='foods', source='china-cdc')
    result = report(db)
    with sqlite3.connect(str(snapshot)) as exported:
        result['app_export'] = dict(path=str(snapshot.relative_to(ROOT)),
            size_bytes=snapshot.stat().st_size, sha256=digest(snapshot),
            foods=exported.execute('SELECT COUNT(*) FROM foods').fetchone()[0],
            nutrients=exported.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0],
            restricted_sources=exported.execute('SELECT COUNT(*) FROM sources WHERE commercial_use_authorized=0').fetchone()[0],
            integrity=exported.execute('PRAGMA integrity_check').fetchone()[0])
    if result['integrity'] != 'ok' or result['foreign_key_errors'] or result['app_export']['restricted_sources']:
        raise ValueError('Database validation failed')
    path = ROOT / 'reports/latest.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('Built', result['foods'], 'source records;', result['app_export']['foods'],
          'commercial export records;', result['app_export']['size_bytes'], 'bytes', flush=True)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=DEFAULT_DB)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('build', help='Rebuild App SQLite, CSV tables and quality report from the master catalog')
    usda = commands.add_parser('import-usda')
    usda.add_argument('--datasets', nargs='+', choices=list(USDA_RELEASES), default=list(USDA_RELEASES))
    cdc = commands.add_parser('crawl-china')
    cdc.add_argument('--interval', type=float, default=1.0)
    cdc.add_argument('--refresh', action='store_true', help='Fetch a new snapshot; preserve previous raw pages')
    find = commands.add_parser('search')
    find.add_argument('query')
    find.add_argument('--limit', type=int, default=20)
    find.add_argument('--include-restricted', action='store_true')
    get = commands.add_parser('get')
    get.add_argument('food_id')
    get.add_argument('--include-restricted', action='store_true')
    export = commands.add_parser('export')
    export.add_argument('--output', type=Path, default=ROOT / '.data/exports/KeepFitFoods.sqlite')
    export.add_argument('--compact', action='store_true', help='Retain macros, energy, fiber, sugars, saturated fat and sodium nutrient rows')
    flat = commands.add_parser('csv')
    flat.add_argument('--output', type=Path, default=ROOT / '.data/exports/food-portions.csv')
    flat.add_argument('--include-restricted', action='store_true')
    flat.add_argument('--table', choices=['foods','portions','nutrients'], default='portions')
    flat.add_argument('--source', help='Filter to one source ID')
    check = commands.add_parser('report')
    check.add_argument('--output', type=Path)
    args = parser.parse_args()
    db = open_db(args.db)
    try:
        result = None
        if args.command == 'build':
            build_outputs(db)
        elif args.command == 'import-usda':
            import_usda(db, args.datasets)
            apply_names(db)
        elif args.command == 'crawl-china':
            if args.interval < 1:
                raise ValueError('Minimum request interval is 1 second')
            crawl_china(db, args.interval, args.refresh)
        elif args.command == 'search':
            result = search(db, args.query, args.limit, args.include_restricted)
        elif args.command == 'get':
            result = detail(db, args.food_id, args.include_restricted)
        elif args.command == 'export':
            print(export_db(db, args.output, args.compact))
        elif args.command == 'csv':
            export_csv(db, args.output, args.include_restricted, args.table, args.source)
            print(args.output)
        elif args.command == 'report':
            result = report(db)
            if args.output:
                args.output.parent.mkdir(parents=True, exist_ok=True)
                args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
        if result is not None:
            print(json.dumps(result, ensure_ascii=False, indent=2))
    finally:
        db.close()


if __name__ == '__main__':
    main()
