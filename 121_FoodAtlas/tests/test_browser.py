from http.server import ThreadingHTTPServer
import json
import sqlite3
import threading
import unittest
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen

import test_catalog as fixtures
import catalog
from browser import Atlas, make_handler


class BrowserTests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CatalogTests()
        self.fixture.setUp()
        self.fixture.insert()
        self.db = self.fixture.db
        self.name = self.db.execute('SELECT name FROM foods').fetchone()[0]
        food, nutrients, portions = catalog.usda_record(self.fixture.record(), 'china-cdc')
        food.update(id='china-cdc:2', source_food_id='2', name='鸡蛋（地方样品）', name_zh='鸡蛋（地方样品）', name_en=None)
        catalog.save_food(self.db, food, nutrients, [])
        food, nutrients, portions = catalog.usda_record(self.fixture.record(), 'usda-test')
        food.update(id='usda:3', source_food_id='3', name=self.name.upper(), name_en=self.name.upper(), calories_kcal=180)
        catalog.save_food(self.db, food, nutrients, [])
        self.db.commit()
        self.atlas = Atlas(self.fixture.path, {'en-zh:' + self.name: {'text':'水煮鸡蛋'},
            'en-zh:' + self.name.upper(): {'text':'水煮鸡蛋'},
            'zh-en:鸡蛋（地方样品）': {'text':'Egg (regional sample)'}}, terms={})

    def tearDown(self):
        self.fixture.tearDown()

    def test_dedup_retains_variants_and_different_values(self):
        self.assertEqual(self.atlas.stats()['records'], 3)
        self.assertEqual(self.atlas.stats()['foods'], 2)
        groups = self.atlas.listing({'q':['水煮鸡蛋']})
        self.assertEqual(groups['total'], 1)
        self.assertEqual(groups['items'][0]['variants'], 2)
        detail = self.atlas.detail('usda:1')
        self.assertEqual({v['calories_kcal'] for v in detail['variants']}, {155,180})
        self.assertEqual(detail['calories_kcal'], 155)
        self.assertEqual(len(detail['nutrients_per_100g']), self.db.execute("SELECT COUNT(*) FROM nutrients WHERE food_id='usda:1'").fetchone()[0])
        self.assertEqual(self.atlas.detail('usda:3')['calories_kcal'], 180)

    def test_all_sources_bilingual_search_and_filter(self):
        self.assertEqual(self.atlas.stats()['bilingual'], 3)
        self.assertEqual(self.atlas.listing({'source':['china-cdc']})['total'], 1)
        self.assertEqual(self.atlas.listing({'q':['regional sample']})['items'][0]['id'], 'china-cdc:2')
        self.assertEqual(self.atlas.listing({'q':['<script>']})['total'], 0)
        for limit in ['0','1000','-1']:
            with self.assertRaises(ValueError):
                self.atlas.listing({'limit':[limit]})

    def test_http_static_detail_security_and_csv(self):
        server = ThreadingHTTPServer(('127.0.0.1',0), make_handler(self.atlas))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = 'http://127.0.0.1:%d' % server.server_address[1]
        try:
            with urlopen(base + '/') as response:
                self.assertIn('食物成分图谱', response.read().decode())
                self.assertIn("default-src 'self'", response.headers['Content-Security-Policy'])
            with urlopen(base + '/api/foods/china-cdc%3A2') as response:
                self.assertEqual(json.load(response)['commercial_use_authorized'], 0)
            with urlopen(base + '/api/export.csv?q=' + quote('水煮鸡蛋')) as response:
                csv_text = response.read().decode('utf-8-sig')
                self.assertIn('中文名称', csv_text)
                self.assertIn('usda:1;usda:3', csv_text)
                self.assertEqual(len(csv_text.strip().splitlines()),2)
            for path in ['/../schema.sql','/api/foods/unknown','/api/foods?limit=1000']:
                with self.assertRaises(HTTPError):
                    urlopen(base + path)
            with self.assertRaises(HTTPError) as error:
                urlopen(Request(base + '/', headers={'Host':'attacker.example'}))
            self.assertEqual(error.exception.code, 403)
        finally:
            server.shutdown()
            server.server_close()
            thread.join(timeout=2)

    def test_glossary_preserves_original_identity_and_untranslated_terms(self):
        atlas = Atlas(self.fixture.path, {}, terms={'foods':{'egg':'蛋'},'descriptors':{'cooked':'熟'}})
        result = atlas.detail('usda:1')
        self.assertEqual(result['name_zh'], '蛋（熟）')
        self.assertEqual(result['name'], self.name)
        self.assertEqual(result['translation_method'], 'glossary')
        self.assertEqual(atlas.glossary_name('Egg, cooked, unusual qualifier'), '蛋（熟；unusual qualifier）')
        self.assertEqual(len(atlas.groups),2)

    def test_name_overrides_do_not_change_original_or_nutrients(self):
        atlas = Atlas(self.fixture.path, {}, overrides={self.name:{'name_zh':'已校对蛋名'}})
        result = atlas.detail('usda:1')
        self.assertEqual(result['name_zh'],'已校对蛋名')
        self.assertEqual(result['name'],self.name)
        self.assertEqual(result['calories_kcal'],155)
        self.assertEqual(result['translation_method'],'curated')


if __name__ == '__main__':
    unittest.main()
