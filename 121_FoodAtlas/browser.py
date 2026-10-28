"""Local-reference Food Atlas. Includes restricted records; never bind publicly."""
import argparse
from contextlib import closing
import csv
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import re
import sqlite3
import subprocess
import threading
import time
import unicodedata
from urllib.parse import parse_qs, unquote, urlsplit

import catalog

ROOT = Path(__file__).resolve().parent
WEB = ROOT / 'web'
MACROS = ('calories_kcal', 'protein_g', 'fat_g', 'carbs_g')
SOURCE_LABELS = {'china-cdc': '中国疾控 · 食物成分表', 'usda-foundation': 'USDA · Foundation',
                 'usda-sr-legacy': 'USDA · SR Legacy', 'usda-fndds': 'USDA · FNDDS',
                 'china-nlc-packaged': '中国疾控 · 商品标签', 'china-cdc-plate': '中国疾控 · 我的餐盘'}
CATEGORIES = {'Beef Products': '牛肉', 'Vegetables and Vegetable Products': '蔬菜',
    'Baked Products': '烘焙', 'Lamb, Veal, and Game Products': '羊肉与野味',
    'Fruits and Fruit Juices': '水果与果汁', 'Poultry Products': '禽肉', 'Beverages': '饮品',
    'Sweets': '甜食', 'Baby Foods': '婴幼儿食品', 'Pork Products': '猪肉',
    'Dairy and Egg Products': '乳品与蛋类', 'Legumes and Legume Products': '豆类',
    'Fast Foods': '快餐', 'Finfish and Shellfish Products': '鱼虾贝类',
    'Soups, Sauces, and Gravies': '汤与酱汁', 'Fats and Oils': '油脂',
    'Cereal Grains and Pasta': '谷物与意面', 'Breakfast Cereals': '早餐谷物', 'Snacks': '零食',
    'Sausages and Luncheon Meats': '香肠与午餐肉', 'American Indian/Alaska Native Foods': '美洲传统食物',
    'Nut and Seed Products': '坚果与种子', 'Restaurant Foods': '餐厅菜品',
    'Meals, Entrees, and Side Dishes': '菜肴与配餐', 'Spices and Herbs': '香辛料'}


def normalize(text):
    # Identity uses original source names, never an unverified translation.
    text = unicodedata.normalize('NFKC', text or '').casefold()
    return re.sub(r'\s+', ' ', text).strip()


def valid_gtin(value):
    value=value or ''
    if not value.isascii() or not value.isdigit() or len(value) not in (8,12,13,14):
        return False
    checksum=sum(int(d)*(3 if i%2==0 else 1) for i,d in enumerate(value[-2::-1]))
    return (10-checksum%10)%10==int(value[-1])


def connect(path):
    db = sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)
    db.row_factory = sqlite3.Row
    return db


class Atlas:
    def __init__(self, database, translations=None, overrides=None, terms=None):
        self.database = database
        if translations is None:
            path = ROOT / '.data/display-translations.json'
            translations = json.loads(path.read_text()) if path.exists() else {}
        self.translations = translations
        if overrides is None:
            overrides = json.loads((ROOT / 'display-name-overrides.json').read_text())
        if terms is None:
            terms = json.loads((ROOT / 'english-food-terms.json').read_text())
        self.food_terms = terms.get('foods', {})
        self.descriptor_terms = dict(self.food_terms, **terms.get('descriptors', {}))
        self.term_pattern = re.compile(r'(?<![a-zA-Z])(' + '|'.join(re.escape(t) for t in sorted(self.descriptor_terms, key=len, reverse=True)) + r')(?![a-zA-Z])', re.IGNORECASE) if self.descriptor_terms else None
        self.descriptor_terms = {k.casefold():v for k,v in self.descriptor_terms.items()}
        with closing(connect(database)) as db:
            self.sources = [dict(r) for r in db.execute('SELECT * FROM sources')]
            rows = [dict(r) for r in db.execute('SELECT * FROM foods')]
            aliases = {}
            for row in db.execute('SELECT food_id,alias FROM aliases'):
                aliases.setdefault(row['food_id'], []).append(row['alias'])
            self.nutrient_count = db.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0]
            self.portion_count = db.execute("SELECT COUNT(*) FROM portions WHERE basis != 'mass'").fetchone()[0]
            tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            self.metadata = {r['food_id']:dict(r) for r in db.execute('''SELECT food_id,kind,barcode,brand,
                net_content,manufacturer,ingredients,basis_quantity,basis_unit,basis_status,detail_status FROM food_metadata''')} if 'food_metadata' in tables else {}
            self.label_nutrient_count = db.execute('SELECT COUNT(*) FROM label_nutrients').fetchone()[0] if 'label_nutrients' in tables else 0
            profiles={}
            if 'label_nutrients' in tables:
                for r in db.execute('SELECT * FROM label_nutrients ORDER BY food_id,nutrient_id'):
                    profiles.setdefault(r['food_id'],hashlib.sha256()).update(json.dumps(tuple(r)[1:],ensure_ascii=False).encode())
            profiles={k:v.hexdigest() for k,v in profiles.items()}
        self.foods = {}
        self.groups = {}
        self.member_groups = {}
        for row in rows:
            row.update({k: v for k, v in overrides.get(row['name'], {}).items() if k in ('name_zh', 'name_en')})
            glossary = self.glossary_name(row['name']) if not row['name_zh'] else None
            translated = (not row['name_zh'] and self.translation('en-zh', row['name'])) or (not row['name_en'] and self.translation('zh-en', row['name']))
            row['name_zh'] = row['name_zh'] or glossary or self.translation('en-zh', row['name'])
            row['name_en'] = row['name_en'] or self.translation('zh-en', row['name'])
            # The original database explicitly distinguishes existing verified names from machine names.
            row['translation_method'] = 'glossary' if glossary else 'machine' if translated else 'curated'
            if not row['name_zh'] or not row['name_en']:
                row['translation_method'] = 'pending'
            row['metadata'] = self.metadata.get(row['id'])
            row['category_facet'] = (row['category'] or 'none').split('-')[0] if row['metadata'] else row['category'] or 'none'
            row['category_zh'] = CATEGORIES.get(row['category_facet'], row['category_facet'] if row['category_facet'] != 'none' else '来源未分类')
            row['source_label'] = SOURCE_LABELS.get(row['source_id'], row['source_id'])
            row['aliases'] = aliases.get(row['id'], [])
            row['search'] = normalize(' '.join([row['name'], row['name_zh'] or '', row['name_en'] or '',
                (row['metadata'] or {}).get('barcode') or '',(row['metadata'] or {}).get('brand') or ''] + row['aliases']))
            self.foods[row['id']] = row
            key = ('en:' if re.search('[a-zA-Z]', row['name']) and not re.search('[\u3400-\u9fff]', row['name']) else 'zh:') + normalize(row['name'])
            if row['metadata']:
                # Same product name is not sufficient identity: retain each source ID until
                # barcode, brand, size AND the entire label profile can be reconciled.
                key = row['metadata']['kind'] + ':' + row['id']
                m=row['metadata']
                if m['kind']=='packaged' and valid_gtin(m['barcode']) and m['brand'] and m['net_content'] and row['id'] in profiles:
                    identity=[normalize(row['name']),m['barcode'],normalize(m['brand']),normalize(m['net_content']),
                        normalize(m['manufacturer']),normalize(m['ingredients']),m['basis_status'],m['basis_quantity'],
                        m['basis_unit'],profiles[row['id']]]
                    key='product:'+hashlib.sha256(json.dumps(identity,ensure_ascii=False).encode()).hexdigest()
            self.groups.setdefault(key, []).append(row)
        priority = {'china-cdc': 0, 'usda-foundation': 1, 'usda-sr-legacy': 2, 'usda-fndds': 3}
        self.entries = []
        for members in self.groups.values():
            members.sort(key=lambda r: (sum(r[k] is None for k in MACROS), priority.get(r['source_id'], 9), r['id']))
            for member in members:
                self.member_groups[member['id']] = members
            self.entries.append(members)
        self.entries.sort(key=lambda ms: (ms[0]['translation_method'] == 'machine',
            priority.get(ms[0]['source_id'], 9), ms[0]['name_zh'] or ms[0]['name']))

    def translation(self, direction, text):
        return self.translations.get(direction + ':' + text, {}).get('text')

    def glossary_name(self, text):
        parts = text.split(',')
        head = self.food_terms.get(parts[0].strip().casefold())
        if head is None:
            return None
        if parts[0].casefold() == 'rice':
            head = '米饭' if re.search(r'\bcooked\b', text, re.I) else '大米'
        translated = [self.term_pattern.sub(lambda m: self.descriptor_terms[m[0].casefold()], p.strip()) for p in parts[1:]]
        return head + ('（' + '；'.join(translated) + '）' if translated else '')

    def stats(self):
        return dict(records=len(self.foods), foods=len(self.groups), merged=len(self.foods) - len(self.groups),
            nutrients=self.nutrient_count, raw_label_nutrients=self.label_nutrient_count, source_portions=self.portion_count,
            bilingual=sum(bool(f['name_zh'] and f['name_en']) for f in self.foods.values()),
            missing_macros=sum(any(f[k] is None for k in MACROS) for f in self.foods.values()),
            sources=[dict(s, label=SOURCE_LABELS.get(s['id'], s['name']),
                count=sum(f['source_id'] == s['id'] for f in self.foods.values())) for s in self.sources],
            categories=[dict(id=k,label=CATEGORIES.get(k,k)) for k in sorted({r['category_facet'] for r in self.foods.values()}-{'none'})],
            local_reference_only=True)

    def listing(self, query, all_results=False):
        q = normalize(query.get('q', [''])[0])
        if len(q) > 200:
            raise ValueError('搜索关键词不能超过 200 字符')
        source = query.get('source', ['all'])[0]
        category = query.get('category', ['all'])[0]
        quality = query.get('quality', ['all'])[0]
        order = query.get('sort', ['default'])[0]
        page = int(query.get('page', ['1'])[0])
        limit = int(query.get('limit', ['40'])[0])
        if page < 1 or not 1 <= limit <= 100:
            raise ValueError('分页参数无效')
        items = []
        tokens = q.split()
        for members in self.entries:
            matches = [r for r in members if
                (source == 'all' or r['source_id'] == source or source == 'usda' and r['source_id'].startswith('usda-'))
                and (category == 'all' or r['category_facet'] == category)
                and (quality != 'complete' or all(r[k] is not None for k in MACROS))
                and (quality != 'missing' or any(r[k] is None for k in MACROS))
                and all(t in r['search'] for t in tokens)]
            if matches:
                row = dict(matches[0])
                row.pop('search', None)
                row['variants'] = len(members)
                row['matched_variants'] = len(matches)
                row['source_ids'] = list(dict.fromkeys(r['source_id'] for r in members))
                items.append(row)
        if order in MACROS:
            items.sort(key=lambda r: (r[order] is None, -(r[order] or 0)))
        elif order == 'name':
            items.sort(key=lambda r: r['name_zh'] or r['name'])
        if q:
            items.sort(key=lambda r: not any(normalize(n) == q for n in [r['name'], r['name_zh'], r['name_en']] + r['aliases']))
        total = len(items)
        start = (page - 1) * limit
        return dict(total=total, page=page, pages=max(1, (total + limit - 1) // limit),
                    items=items if all_results else items[start:start + limit])

    def detail(self, food_id):
        if food_id not in self.foods:
            raise KeyError(food_id)
        with closing(connect(self.database)) as db:
            result = catalog.detail(db, food_id, include_restricted=True)
            if food_id in self.metadata:
                result['metadata'] = dict(db.execute('SELECT * FROM food_metadata WHERE food_id=?',(food_id,)).fetchone())
                result['metadata']['raw_source'] = json.loads(result['metadata'].pop('raw_json'))
                result['label_nutrients'] = [dict(r) for r in db.execute('SELECT * FROM label_nutrients WHERE food_id=?',(food_id,))]
        result.update({k: v for k, v in self.foods[food_id].items() if k not in ('search', 'aliases', 'metadata')})
        result['variants'] = [{k: row[k] for k in ('id', 'name', 'source_label', 'source_id') + MACROS}
                              for row in self.member_groups[food_id]]
        return result


class AtlasStore:
    """Refresh the browser index as the detached collector makes progress."""
    def __init__(self, database):
        self.database=database
        self.atlas=Atlas(database)
        self.checked=time.monotonic()
        self.lock=threading.Lock()

    def get(self):
        if time.monotonic()-self.checked > 30:
            with self.lock:
                if time.monotonic()-self.checked > 30:
                    self.atlas=Atlas(self.database)
                    self.checked=time.monotonic()
        return self.atlas


def progress(database):
    with closing(connect(database)) as db:
        if not db.execute("SELECT 1 FROM sqlite_master WHERE name='ingestion_jobs'").fetchone():
            return dict(jobs=[])
        jobs=[dict(r) for r in db.execute('SELECT * FROM ingestion_jobs')]
        basis=[dict(r) for r in db.execute('SELECT basis_status,COUNT(*) n FROM food_metadata GROUP BY basis_status')]
    path=ROOT/'.data/raw/china-supplement/quarantined-index.json'
    alive=False
    try:
        pid=int((ROOT/'.data/supplement-collector.pid').read_text())
        os.kill(pid,0)
        identity=subprocess.run(['/bin/ps','-p',str(pid),'-o','command='],capture_output=True,text=True,check=False)
        alive=str(ROOT/'supplement.py')+' collect' in identity.stdout
    except (OSError,ValueError):
        pass
    return dict(jobs=jobs,basis=basis,collector_alive=alive,
                quarantined_index_records=len(json.loads(path.read_text())) if path.exists() else 0)


def make_handler(atlas):
    store=atlas
    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            # Local reference data must not be exposed through a rebound browser hostname.
            if self.headers.get('Host', '').split(':')[0] not in ('127.0.0.1', 'localhost'):
                self.respond(403, b'Local access only', 'text/plain')
                return
            route = urlsplit(self.path)
            try:
                atlas=store.get() if isinstance(store,AtlasStore) else store
                if route.path == '/api/stats':
                    self.send_json(atlas.stats())
                elif route.path == '/api/progress':
                    self.send_json(progress(atlas.database))
                elif route.path == '/api/foods':
                    self.send_json(atlas.listing(parse_qs(route.query)))
                elif route.path.startswith('/api/foods/'):
                    self.send_json(atlas.detail(unquote(route.path[len('/api/foods/'):])) )
                elif route.path == '/api/export.csv':
                    self.export_csv(atlas)
                elif route.path == '/api/export-labels.csv':
                    self.export_labels(atlas)
                else:
                    files = {'/': ('index.html', 'text/html; charset=utf-8'),
                             '/app.js': ('app.js', 'text/javascript; charset=utf-8'),
                             '/style.css': ('style.css', 'text/css; charset=utf-8'),
                             '/favicon.svg': ('favicon.svg', 'image/svg+xml')}
                    if route.path not in files:
                        raise KeyError(route.path)
                    file, mime = files[route.path]
                    self.respond(200, (WEB / file).read_bytes(), mime)
            except KeyError:
                self.respond(404, b'Not found', 'text/plain')
            except (ValueError, TypeError) as error:
                self.respond(400, json.dumps(dict(error=str(error)), ensure_ascii=False).encode(), 'application/json')
            except (sqlite3.Error, OSError):
                self.respond(500, b'{"error":"Local database unavailable"}', 'application/json')

        def export_csv(self, atlas):
            query = parse_qs(urlsplit(self.path).query)
            query['page'], query['limit'] = ['1'], ['100']
            items = atlas.listing(query,all_results=True)['items']
            output = io.StringIO()
            writer = csv.writer(output)
            writer.writerow(['中文名称', '英文名称', '基准单位', '热量(kcal)', '蛋白质(g)', '脂肪(g)', '碳水化合物(g)',
                             '所选来源', '原始名称', '同名来源记录数', '名称说明', '全部记录ID', '条码','品牌','规格','数据状态','用途'])
            for row in items:
                m=row['metadata'] or {}
                unit='100g' if not m or m.get('basis_status')=='verified' and m.get('basis_unit')=='g' else '标签原值见详情；非100g换算'
                values = [row['name_zh'], row['name_en'], unit] + [row[k] for k in MACROS] + \
                    [row['source_label'], row['name'], row['variants'],
                     '辅助译名，待校对' if row['translation_method'] != 'curated' else '原文或已整理译名',
                     ';'.join(m['id'] for m in atlas.member_groups[row['id']]),
                     m.get('barcode'),m.get('brand'),m.get('net_content'),m.get('detail_status','normalized_per100g'),
                     '仅本地参考；中国疾控数据商用需另行授权']
                writer.writerow(["'" + v if isinstance(v, str) and v.lstrip().startswith(('=', '+', '-', '@')) else v for v in values])
            self.respond(200, ('\ufeff' + output.getvalue()).encode(), 'text/csv; charset=utf-8',
                         attachment='food-atlas.csv')

        def send_json(self, data):
            self.respond(200, json.dumps(data, ensure_ascii=False, allow_nan=False).encode(), 'application/json; charset=utf-8')

        def export_labels(self,atlas):
            output=io.StringIO()
            writer=csv.writer(output)
            writer.writerow(['来源记录ID','食物中文','辅助英文名','条码','品牌','规格','基准核验状态','基准量','基准单位',
                             '营养项','原始值','解析数值','营养单位','数值状态','来源链接'])
            with closing(connect(atlas.database)) as db:
                for r in db.execute('''SELECT f.id,f.name_zh,f.name,f.source_url,m.barcode,m.brand,m.net_content,
                    m.basis_status,m.basis_quantity,m.basis_unit,n.name nutrient,n.raw_value,n.amount,n.unit,n.qualifier
                    FROM label_nutrients n JOIN foods f ON f.id=n.food_id JOIN food_metadata m ON m.food_id=f.id
                    ORDER BY f.id,n.nutrient_id'''):
                    english=atlas.foods.get(r['id'],{}).get('name_en')
                    values=[r['id'],r['name_zh'] or r['name'],english,r['barcode'],r['brand'],r['net_content'],
                        r['basis_status'],r['basis_quantity'],r['basis_unit'],r['nutrient'],r['raw_value'],
                        r['amount'],r['unit'],r['qualifier'],r['source_url']]
                    writer.writerow(["'"+v if isinstance(v,str) and v.lstrip().startswith(('=','+','-','@')) else v for v in values])
            self.respond(200,('\ufeff'+output.getvalue()).encode(),'text/csv; charset=utf-8',attachment='food-atlas-original-labels.csv')

        def respond(self, status, body, mime, attachment=None):
            self.send_response(status)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
            if attachment:
                self.send_header('Content-Disposition', 'attachment; filename="%s"' % attachment)
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *args):
            pass
    return Handler


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=Path, default=catalog.DEFAULT_DB)
    parser.add_argument('--port', type=int, default=8768)
    args = parser.parse_args()
    if not args.db.is_file():
        parser.error('Master database does not exist')
    store = AtlasStore(args.db)
    atlas = store.atlas
    server = ThreadingHTTPServer(('127.0.0.1', args.port), make_handler(store))
    print('Food Atlas: http://127.0.0.1:%d (%d records / %d unique names)' %
          (args.port, len(atlas.foods), len(atlas.groups)), flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
