"""Resumable public China NLC product-label and My Plate collection, local only."""
import argparse
from contextlib import contextmanager
import hashlib
from html.parser import HTMLParser
from html import unescape
import json
import math
from pathlib import Path
import re
import sqlite3
import time
import tempfile
import unicodedata
from urllib.error import HTTPError
from urllib.robotparser import RobotFileParser

import catalog

BASE = 'https://nlc.chinanutri.cn/'
RAW = catalog.ROOT / '.data/raw/china-supplement'
RUNTIME = Path(tempfile.gettempdir())/'keepfit-food-atlas-runtime'
INDEX = BASE + 'FoodQueryAction!queryFoodList.do'
PLATE = BASE + 'ssbt/plate.htm'
PACKAGED_SOURCE = 'china-nlc-packaged'
PLATE_SOURCE = 'china-cdc-plate'
FIELDS = {'食物类别':'category','生产厂家':'manufacturer','品牌':'brand','配料':'ingredients',
          '净含量':'net_content','条形码/识别码':'barcode','储存方法':'storage','产地':'origin'}
NUTRIENTS = {'能量':('energy','kJ'),'蛋白质':('protein','g'),'脂肪':('fat','g'),
             '碳水化合物':('carbs','g'),'钠':('sodium','mg'),'糖':('sugars','g'),
             '膳食纤维':('fiber','g'),'饱和脂肪':('saturated_fat','g'),
             '饱和脂肪酸':('saturated_fat','g'),'反式脂肪酸':('trans_fat','g')}


def normalized(text):
    return re.sub(r'\s+', '', unicodedata.normalize('NFKC', unescape(str(text or '')))).casefold()


class TableParser(HTMLParser):
    """Extract only the first HTML table, keeping each food column aligned."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.rows, self.row, self.cell, self.links = [], None, None, None
        self.depth = 0
        self.finished = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'table' and not self.finished:
            self.depth += 1
        if self.depth != 1 or self.finished:
            return
        if tag == 'tr':
            self.row = []
        elif tag in ('td','th'):
            self.cell, self.links = [], []
        elif tag == 'a' and self.cell is not None:
            self.links.append(attrs.get('href',''))
        elif tag == 'br' and self.cell is not None:
            self.cell.append('\n')

    def handle_data(self, data):
        if self.depth == 1 and self.cell is not None:
            self.cell.append(data)

    def handle_endtag(self, tag):
        if self.finished:
            return
        if tag in ('td','th') and self.depth == 1 and self.cell is not None:
            self.row.append(dict(text=' '.join(''.join(self.cell).split()), links=self.links))
            self.cell = None
        elif tag == 'tr' and self.depth == 1 and self.row is not None:
            self.rows.append(self.row)
            self.row = None
        elif tag == 'table' and self.depth:
            self.depth -= 1
            if not self.depth:
                self.finished = True


class PublicCache:
    def __init__(self, interval=1.0):
        if interval < 1:
            raise ValueError('Minimum request interval is 1 second')
        self.interval = interval
        self.last = time.monotonic()
        RAW.mkdir(parents=True, exist_ok=True)
        RUNTIME.mkdir(parents=True,exist_ok=True)
        path = RAW / 'robots.txt'
        if not path.exists():
            try:
                path.write_bytes(catalog.request_bytes(BASE + 'robots.txt'))
            except HTTPError as error:
                if error.code != 404:
                    raise
                path.write_text('# HTTP 404: robots.txt not published\n')
        self.robot = RobotFileParser()
        self.robot.parse(path.read_text().splitlines())
        self.interval = max(self.interval, self.robot.crawl_delay(catalog.USER_AGENT) or 0)

    def get(self, relative, url, data=None):
        if not self.robot.can_fetch(catalog.USER_AGENT, url):
            raise ValueError('robots.txt disallows: ' + url)
        path = RAW / relative
        if path.exists():
            return path.read_bytes()
        import fcntl
        # Also share the polite rate limit with manually run verification commands.
        with (RUNTIME/'request.lock').open('a+') as lock:
            fcntl.flock(lock,fcntl.LOCK_EX)
            lock.seek(0)
            previous=float(lock.read() or '0')
            now=time.time()
            time.sleep(max(0,min(self.interval,previous+self.interval-now)))
            lock.seek(0);lock.truncate();lock.write(str(time.time()));lock.flush()
            body = catalog.request_bytes(url, data, attempts=1)
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.part')
        temporary.write_bytes(body)
        temporary.replace(path)
        return body


class SourceAccessError(RuntimeError):
    pass


def parse_value(text, default_unit=''):
    raw = text.strip()
    if raw in ('','—','--','-','NA','N/A','未提供'):
        return None, default_unit, 'missing'
    if raw.lower() in ('tr','trace','微量'):
        return None, default_unit, 'not_detected'
    match = re.fullmatch(r'([<>≤≥]?)\s*([-+]?\d+(?:\.\d+)?)\s*([a-zA-Zμµ%]*)', raw)
    if not match:
        return None, default_unit, 'unparsed_source_value'
    value = float(match[2])
    unit = catalog.normalized_unit(match[3] or default_unit)
    if value < 0 or not math.isfinite(value):
        return None, unit, 'invalid_source_value'
    if match[1]:
        return None, unit, 'source_bound:' + match[1]
    return value, unit, 'reported'


def parse_comparison(body, expected):
    parser = TableParser()
    parser.feed(body.decode('utf-8-sig'))
    if not parser.rows or parser.rows[0][0]['text'] != '食物':
        raise SourceAccessError('Unexpected source page; stopped rather than bypassing a possible access/login page')
    headers = parser.rows[0][1:]
    active = [i for i, h in enumerate(headers) if h['text']]
    if len(active) != len(expected):
        raise ValueError('Product column count changed')
    if len(expected) > 4:
        raise ValueError('Source comparison template exposes at most four nutrient columns')
    columns = []
    for i in active:
        result = dict(name=headers[i]['text'], nutrients=[], metadata={})
        for row in parser.rows[1:]:
            key = row[0]['text']
            if len(row) <= i + 1:
                continue
            text = row[i + 1]['text']
            if key in FIELDS:
                result['metadata'][FIELDS[key]] = text
            elif key in ('食物编码', '营养成分'):
                continue
            elif key in NUTRIENTS or any(c.isdigit() for c in text) and key not in FIELDS:
                nid, unit = NUTRIENTS.get(key, ('label:' + key, ''))
                amount, unit, qualifier = parse_value(text, unit)
                result['nutrients'].append((nid, key, unit, amount, qualifier, text))
        linked = []
        for link in headers[i]['links']:
            match = re.search(r'food/([^/]+)\.html$', link)
            if match:
                linked.append(match[1])
        candidates = [r for r in expected if r['unid'] in linked]
        if not candidates:
            candidates = [r for r in expected if normalized(r['productName']) == normalized(result['name'])
                and normalized(r.get('barCode')) == normalized(result['metadata'].get('barcode'))]
        if not candidates and len(expected)==1:
            r=expected[0]
            if normalized(r['productName'])==normalized(result['name']) or (
                r.get('barCode') and normalized(r['barCode'])==normalized(result['metadata'].get('barcode'))):
                candidates=[r]
        if len(candidates) != 1:
            raise ValueError('Ambiguous product identity; no positional guess: ' + result['name'])
        result['unid'] = candidates[0]['unid']
        columns.append(result)
    if len({r['unid'] for r in columns}) != len(expected):
        raise ValueError('Duplicate/missing comparison identity')
    return columns


def parse_detail(body):
    parser=TableParser()
    parser.feed(body.decode('utf-8-sig'))
    if not parser.rows or len(parser.rows[0]) < 2 or parser.rows[0][0]['text'] != '项目':
        raise ValueError('Unexpected detail nutrient panel schema')
    header=parser.rows[0][1]['text']
    match=re.fullmatch(r'每\s*(\d+(?:\.\d+)?)\s*(毫升|克|mL|ml|g)',header,re.I)
    if not match:
        raise ValueError('Reference basis cannot be safely parsed: '+header)
    quantity=catalog.positive_number(match[1])
    if not quantity:
        raise ValueError('Invalid source reference quantity')
    unit='ml' if match[2].lower() in ('毫升','ml') else 'g'
    nutrients=[]
    for row in parser.rows[1:]:
        if len(row)<2:
            continue
        name,text=row[0]['text'],row[1]['text']
        nid,default=NUTRIENTS.get(name,('label:'+name,''))
        value,nunit,qualifier=parse_value(text,default)
        nutrients.append((nid,name,nunit,value,qualifier,text))
    return dict(quantity=quantity,unit=unit,header=header,nutrients=nutrients)


def empty_food(identifier, source_id, source_food_id, name, category, data_type, url):
    return dict(id=identifier, source_id=source_id, source_food_id=source_food_id, name=name,
        name_zh=name, name_en=None, category=category, data_type=data_type, source_url=url,
        edible_percent=None, calories_kcal=None, protein_g=None, fat_g=None, carbs_g=None,
        energy_method='source_not_normalized')


def source(db, sid, title, path, url, notes):
    catalog.add_source(db, dict(id=sid, name=title, version='snapshot-' + catalog.file_time(path)[:10],
        url=url, license='Copyright retained by source; commercial permission not established',
        commercial_use_authorized=0, retrieved_at=catalog.file_time(path), raw_sha256=catalog.digest(path), notes=notes))


def job(db, sid, status, total, completed, failed, notes):
    db.execute('''INSERT INTO ingestion_jobs VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET
        status=excluded.status,total=excluded.total,completed=excluded.completed,failed=excluded.failed,
        updated_at=excluded.updated_at,notes=excluded.notes''',
        (sid,status,total,completed,failed,catalog.utc_now(),notes))


def initialize(db, cache):
    cache.get('packaged-index.json', INDEX, b'keyword=')
    index_path = RAW / 'packaged-index.json'
    rows = json.loads(index_path.read_bytes())
    if not isinstance(rows, list) or not rows or any(not r.get('unid') for r in rows):
        raise ValueError('Invalid public product index')
    if len({r['unid'] for r in rows}) != len(rows):
        raise ValueError('Duplicate source IDs in product index')
    quarantined = [r for r in rows if not (r.get('productName') or '').strip()]
    (RAW/'quarantined-index.json').write_text(json.dumps(quarantined,ensure_ascii=False,indent=2))
    rows = [r for r in rows if (r.get('productName') or '').strip()]
    with db:
        source(db, PACKAGED_SOURCE, '中国疾控营养所 · 预包装食品营养标签', index_path, BASE,
            'Public autocomplete index snapshot; comparison data retains original labels. '
            'Not every indexed candidate has a working standalone detail page. '
            'No per-100g normalization until label reference basis is verified.')
        for row in rows:
            fid = 'nlc:' + row['unid']
            exists = db.execute('SELECT 1 FROM foods WHERE id=?',(fid,)).fetchone()
            if not exists:
                url = BASE + 'contrastfood_' + row['unid'] + '.htm'
                food = empty_food(fid, PACKAGED_SOURCE, row['unid'], row['productName'], None,
                                  'Packaged food label / original reference', url)
                catalog.save_food(db, food, [], [])
                db.execute('DELETE FROM portions WHERE food_id=?',(fid,))
                db.execute('''INSERT INTO food_metadata(food_id,kind,barcode,basis_status,detail_status,raw_json)
                    VALUES (?,?,?,?,?,?)''', (fid,'packaged',row.get('barCode'),
                        'unverified','index_only',json.dumps(row,ensure_ascii=False)))
        n = db.execute("SELECT COUNT(*) FROM food_metadata WHERE kind='packaged' AND detail_status!='index_only'").fetchone()[0]
        job(db, PACKAGED_SOURCE, 'indexed', len(rows), n, 0,
            'Index imported, raw nutrition collection pending. Unknown reference basis is not per 100g.')
    import_plate(db, cache)
    report(db)
    print('Indexed',len(rows),'products; retained existing completed label records',flush=True)
    return rows


def import_plate(db, cache):
    raw = cache.get('plate.html', PLATE)
    text = raw.decode('utf-8-sig')
    match = re.search(r"var\s+list11\s*=\s*'(.+?)';", text, re.S)
    if not match:
        raise ValueError('Plate JSON source schema changed')
    # The inspected source contains literal JSON in a JS string. Never eval site code.
    groups = json.loads(match[1])
    rows = [r for group in groups for r in group['list']]
    if len({r['id'] for r in rows}) != len(rows):
        raise ValueError('Duplicate plate source IDs')
    with db:
        source(db, PLATE_SOURCE, '中国疾控营养所 · 我的餐盘菜品及份量', RAW/'plate.html', PLATE,
               'Dish names, tool quantities and original foodpb vector only. The vector is not a nutrient panel; '
               'no gram-to-ml assumptions or estimated macros were added.')
        for row in rows:
            fid = 'plate:' + row['id']
            food = empty_food(fid, PLATE_SOURCE, row['id'], row['dishName'], row.get('dishType'),
                              'Plate reference / no reported nutrient panel', PLATE)
            catalog.save_food(db,food,[],[])
            db.execute('DELETE FROM portions WHERE food_id=?',(fid,))
            db.execute('''INSERT INTO food_metadata(food_id,kind,basis_quantity,basis_unit,basis_status,
                detail_status,portion_description,raw_json) VALUES (?,?,?,?,?,?,?,?)
                ON CONFLICT(food_id) DO UPDATE SET basis_quantity=excluded.basis_quantity,
                portion_description=excluded.portion_description,raw_json=excluded.raw_json''',
                (fid,'plate',catalog.positive_number(row.get('quantity')),'g','tool_reference_only',
                 'source_has_no_panel',row.get('content'),json.dumps(row,ensure_ascii=False)))
        job(db, PLATE_SOURCE,'complete',len(rows),len(rows),0,
            'All source plate entries retained. Source has no complete nutrition panels; foodpb not treated as nutrients.')
    print('Plate reference entries imported:',len(rows),flush=True)


def save_comparison(db, parsed, raw_path):
    for product in parsed:
        fid = 'nlc:' + product['unid']
        if db.execute('SELECT basis_status FROM food_metadata WHERE food_id=?',(fid,)).fetchone()[0]=='verified':
            continue
        m = product['metadata']
        previous = json.loads(db.execute('SELECT raw_json FROM food_metadata WHERE food_id=?',(fid,)).fetchone()[0])
        provenance=dict(raw_file=str(raw_path.relative_to(catalog.ROOT)))
        if raw_path.exists():
            provenance.update(collected_at=catalog.file_time(raw_path),sha256=catalog.digest(raw_path))
        previous['comparison'] = dict(product, **provenance)
        db.execute('UPDATE foods SET category=? WHERE id=?',(m.get('category'),fid))
        db.execute('''UPDATE food_metadata SET barcode=?,brand=?,manufacturer=?,ingredients=?,net_content=?,
            storage=?,origin=?,detail_status='raw_label_complete',raw_json=? WHERE food_id=?''',
            (m.get('barcode'),m.get('brand'),m.get('manufacturer'),m.get('ingredients'),m.get('net_content'),
             m.get('storage'),m.get('origin'),json.dumps(previous,ensure_ascii=False),fid))
        db.execute('DELETE FROM label_nutrients WHERE food_id=?',(fid,))
        db.executemany('INSERT INTO label_nutrients VALUES (?,?,?,?,?,?,?)',[(fid,*r) for r in product['nutrients']])
        for value in (m.get('barcode'),m.get('brand')):
            if value:
                db.execute('INSERT OR IGNORE INTO aliases VALUES (?,?,?,?)',(fid,value,'und','NLC original label metadata'))


def fetch_batch(db, cache, batch):
    ids=','.join(r['unid'] for r in batch)
    key=hashlib.sha256(ids.encode()).hexdigest()[:24]
    relative='comparisons/'+key+'.html'
    raw=cache.get(relative,BASE+'contrastfood_'+ids+'.htm')
    try:
        parsed=parse_comparison(raw,batch)
    except ValueError:
        if len(batch)==1:
            raise
        # Identical names/barcodes can still identify different source records.
        # Resolve by a one-ID public request, never assign columns by position.
        for record in batch:
            fetch_batch(db,cache,[record])
        return
    with db:
        save_comparison(db,parsed,RAW/relative)


def verify_one(db, cache, record):
    if not re.fullmatch(r'/[A-Za-z0-9_-]+\.html',record.get('url','')):
        raise ValueError('No explicit standalone detail URL in index')
    fid='nlc:'+record['unid']
    url=BASE+'food'+record['url']
    relative='details/'+record['unid']+'.html'
    raw=cache.get(relative,url)
    if record.get('barCode') and str(record['barCode']).strip() not in raw.decode('utf-8-sig'):
        raise ValueError('Detail barcode does not match public index')
    parsed=parse_detail(raw)
    previous=json.loads(db.execute('SELECT raw_json FROM food_metadata WHERE food_id=?',(fid,)).fetchone()[0])
    previous['verified_detail']=dict(parsed,url=url,raw_file=str((RAW/relative).relative_to(catalog.ROOT)))
    with db:
        db.execute('''UPDATE food_metadata SET basis_quantity=?,basis_unit=?,basis_status='verified',detail_status='raw_label_complete',raw_json=?
            WHERE food_id=?''',(parsed['quantity'],parsed['unit'],json.dumps(previous,ensure_ascii=False),fid))
        db.execute('UPDATE foods SET source_url=? WHERE id=?',(url,fid))
        db.execute('DELETE FROM label_nutrients WHERE food_id=?',(fid,))
        db.executemany('INSERT INTO label_nutrients VALUES (?,?,?,?,?,?,?)',[(fid,*r) for r in parsed['nutrients']])
        if parsed['unit']=='g':
            byid={r[0]:r for r in parsed['nutrients']}
            factor=100/parsed['quantity']
            def amount(key,unit):
                r=byid.get(key)
                return r[3]*factor if r and r[2]==unit and r[3] is not None else None
            kj=amount('energy','kJ')
            kcal=amount('energy','kcal')
            if kcal is None and kj is not None:
                kcal=kj/4.184
            db.execute('''UPDATE foods SET calories_kcal=?,protein_g=?,fat_g=?,carbs_g=?,energy_method=? WHERE id=?''',
                (kcal,amount('protein','g'),amount('fat','g'),amount('carbs','g'),
                 'NLC detail label: per %g g, normalized to 100g; kJ/4.184 where needed'%parsed['quantity'],fid))
            db.execute('DELETE FROM nutrients WHERE food_id=?',(fid,))
            db.executemany('INSERT INTO nutrients VALUES (?,?,?,?,?,?,?,?)',[
                (fid,'nlc:'+nid,name,unit,value*factor if value is not None and unit!='%' else value,
                 qualifier,raw_value,'Normalized from verified label per %g g'%parsed['quantity'])
                for nid,name,unit,value,qualifier,raw_value in parsed['nutrients']])
        # Volume-based labels remain outside the normalized per-100g fields.
    return parsed


def verify_linked_details(db,cache,rows):
    eligible=[r for r in rows if re.fullmatch(r'/[A-Za-z0-9_-]+\.html',r.get('url',''))]
    failed=0
    completed=0
    for offset,record in enumerate(eligible):
        current=db.execute('SELECT basis_status FROM food_metadata WHERE food_id=?',('nlc:'+record['unid'],)).fetchone()[0]
        if current in ('verified','detail_unavailable','source_basis_unparsed'):
            completed+=1
            continue
        try:
            verify_one(db,cache,record)
            completed+=1
        except HTTPError as error:
            if error.code in (401,403,429):
                with db:
                    job(db,'china-nlc-basis','stopped_access_limit',len(eligible),completed,failed,'Source HTTP '+str(error.code))
                raise
            if error.code==404:
                with db:
                    db.execute("UPDATE food_metadata SET basis_status='detail_unavailable' WHERE food_id=?",('nlc:'+record['unid'],))
                completed+=1
            else:
                failed+=1
        except ValueError as error:
            failed+=1
            with (RAW/'basis-failures.jsonl').open('a') as output:
                output.write(json.dumps(dict(id=record['unid'],error=str(error),at=catalog.utc_now()))+'\n')
        if offset%20==0 or offset+1==len(eligible):
            with db:
                job(db,'china-nlc-basis','running',len(eligible),completed,failed,
                    'Checking explicit standalone detail links. Missing links or 404s do not establish a reference unit.')
            report(db)
            print('Reference basis checked',completed,'/',len(eligible),'failed',failed,flush=True)
    with db:
        job(db,'china-nlc-basis','complete' if completed==len(eligible) else 'partial',len(eligible),completed,failed,
            'Checked linked detail pages; source-unavailable records and index candidates without links remain unverified.')
    report(db)


def collect(db, cache, rows, max_batches=None):
    failed = 0
    consecutive_failures=0
    total = len(rows)
    status = 'running'
    completed=db.execute("SELECT COUNT(*) FROM food_metadata WHERE kind='packaged' AND detail_status='raw_label_complete'").fetchone()[0]
    job(db, PACKAGED_SOURCE,status,total,completed,failed,'Public comparison, at most four products/request; minimum 1 second between requests.')
    db.commit()
    for offset in range(0,total,4):
        if max_batches is not None and offset // 4 >= max_batches:
            status = 'partial'
            break
        batch = rows[offset:offset+4]
        done = db.execute("SELECT food_id FROM food_metadata WHERE detail_status='raw_label_complete' AND food_id IN (%s)" %
                          ','.join('?' for _ in batch),tuple('nlc:'+r['unid'] for r in batch)).fetchall()
        if len(done) == len(batch):
            continue
        ids = ','.join(r['unid'] for r in batch)
        try:
            fetch_batch(db,cache,batch)
            consecutive_failures=0
        except SourceAccessError as error:
            with db:
                completed=db.execute("SELECT COUNT(*) FROM food_metadata WHERE kind='packaged' AND detail_status='raw_label_complete'").fetchone()[0]
                job(db,PACKAGED_SOURCE,'stopped_source_page',total,completed,failed,str(error))
            report(db)
            raise
        except HTTPError as error:
            if error.code in (401,403,429):
                status = 'stopped_access_limit'
                with db:
                    job(db,PACKAGED_SOURCE,status,total,offset,failed,'Stopped on source HTTP '+str(error.code)+'; no bypass/retry loop.')
                raise
            failed += len(batch)
            consecutive_failures+=1
            print('HTTP failure',offset,error.code,flush=True)
        except (OSError,ValueError,sqlite3.Error) as error:
            failed += len(batch)
            consecutive_failures+=1
            print('Batch failure',offset,str(error),flush=True)
            with (RAW/'failures.jsonl').open('a') as output:
                output.write(json.dumps(dict(ids=ids,error=str(error),at=catalog.utc_now()))+'\n')
        if consecutive_failures>=3:
            status='stopped_repeated_source_error'
            break
        if offset % 40 == 0 or offset+4 >= total:
            completed=db.execute("SELECT COUNT(*) FROM food_metadata WHERE kind='packaged' AND detail_status='raw_label_complete'").fetchone()[0]
            with db:
                job(db,PACKAGED_SOURCE,'running',total,completed,failed,'Original label values collected; reference basis remains unverified unless detail page checked.')
            print('Labels',completed,'/',total,'failed',failed,flush=True)
            report(db)
    completed=db.execute("SELECT COUNT(*) FROM food_metadata WHERE kind='packaged' AND detail_status='raw_label_complete'").fetchone()[0]
    if completed == total:
        status='raw_labels_complete_basis_pending'
    elif status == 'running':
        status='partial'
    with db:
        job(db,PACKAGED_SOURCE,status,total,completed,failed,'Raw label coverage is separate from verified per-100g/per-100ml basis. Re-run resumes missing batches.')
    report(db)


def report(db):
    result = dict(updated_at=catalog.utc_now(),jobs=[dict(r) for r in db.execute('SELECT * FROM ingestion_jobs')],
        total_food_records=db.execute('SELECT COUNT(*) FROM foods').fetchone()[0],
        raw_label_nutrient_rows=db.execute('SELECT COUNT(*) FROM label_nutrients').fetchone()[0],
        reference_basis=dict(db.execute('SELECT basis_status,COUNT(*) FROM food_metadata GROUP BY basis_status')),
        quarantined_index_records=len(json.loads((RAW/'quarantined-index.json').read_text())) if (RAW/'quarantined-index.json').exists() else 0,
        scope='Public product index snapshot + four-column public comparison pages + all embedded My Plate entries; '
              'not a claim that fq.chinanutri.cn is accessible or that all labels have a verified reference unit.')
    path=catalog.ROOT/'reports/supplement-coverage.json'
    temp=path.with_suffix('.tmp')
    temp.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    temp.replace(path)
    return result


@contextmanager
def worker_lock():
    import fcntl
    RUNTIME.mkdir(parents=True,exist_ok=True)
    lock=(RUNTIME/'collector.lock').open('a')
    try:
        fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        yield
    finally:
        lock.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['initialize','collect','verify-linked','report'])
    parser.add_argument('--max-batches',type=int)
    parser.add_argument('--interval',type=float,default=1)
    args=parser.parse_args()
    db=catalog.open_db()
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('PRAGMA busy_timeout=30000')
    try:
        if args.command=='report':
            print(json.dumps(report(db),ensure_ascii=False,indent=2))
            return
        cache=PublicCache(args.interval)
        with worker_lock():
            if args.command=='initialize':
                initialize(db,cache)
            else:
                rows=[r for r in json.loads((RAW/'packaged-index.json').read_bytes()) if (r.get('productName') or '').strip()]
                if args.command=='collect':
                    collect(db,cache,rows,args.max_batches)
                current=db.execute('SELECT status FROM ingestion_jobs WHERE id=?',(PACKAGED_SOURCE,)).fetchone()
                if args.command=='verify-linked' or args.command=='collect' and args.max_batches is None and current[0] in ('raw_labels_complete_basis_pending','partial'):
                    verify_linked_details(db,cache,rows)
    finally:
        db.close()


if __name__=='__main__':
    main()
