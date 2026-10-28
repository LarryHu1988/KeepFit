from http.server import ThreadingHTTPServer
import json
import threading
import unittest
from urllib.error import HTTPError
from urllib.request import urlopen

import test_catalog as fixtures
import catalog
from serve import make_handler


class APITests(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.CatalogTests()
        self.fixture.setUp()
        self.fixture.insert()
        self.path, self.db = self.fixture.path, self.fixture.db
        food, nutrients, _ = catalog.usda_record(self.fixture.record(), 'china-cdc')
        food['id'], food['source_food_id'], food['name'] = 'china-cdc:2', '2', 'Restricted'
        catalog.save_food(self.db, food, nutrients, [])
        self.db.commit()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), make_handler(self.path))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.base = 'http://127.0.0.1:%d' % self.server.server_address[1]

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.fixture.tearDown()

    def get_json(self, path):
        with urlopen(self.base + path, timeout=5) as response:
            return json.load(response)

    def test_api_health_and_portion_calculation(self):
        self.assertEqual(self.get_json('/health')['foods'], 1)
        self.assertEqual(len(self.get_json('/foods?q=Egg')['foods']), 1)
        detail = self.get_json('/foods/usda:1')
        self.assertEqual(next(p for p in detail['portions'] if p['basis'] == 'source')['calories_per_unit_kcal'], 77.5)

    def test_api_excludes_restricted_data(self):
        self.assertEqual(self.get_json('/foods?q=Restricted')['foods'], [])
        with self.assertRaises(HTTPError) as error:
            self.get_json('/foods/china-cdc:2')
        self.assertEqual(error.exception.code, 404)

    def test_api_rejects_invalid_limit(self):
        with self.assertRaises(HTTPError) as error:
            self.get_json('/foods?q=Egg&limit=100000')
        self.assertEqual(error.exception.code, 400)
