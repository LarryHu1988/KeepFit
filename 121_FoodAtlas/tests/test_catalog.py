from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog


class CatalogTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name) / 'test.sqlite'
        self.db = catalog.open_db(self.path)
        for sid, authorized in [('usda-test', 1), ('china-cdc', 0)]:
            catalog.add_source(self.db, dict(id=sid, name=sid, version='test', url='https://example.com',
                license='test', commercial_use_authorized=authorized, retrieved_at='test',
                raw_sha256='test', notes='test'))

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def record(self):
        return dict(fdcId=1, description='Egg, cooked', dataType='SR Legacy', foodNutrients=[
            dict(nutrient=dict(id=1008, name='Energy', unitName='kcal'), amount=155),
            dict(nutrient=dict(id=1003, name='Protein', unitName='g'), amount=12.6),
            dict(nutrient=dict(id=1004, name='Fat', unitName='g'), amount=10.6),
            dict(nutrient=dict(id=1005, name='Carbohydrate', unitName='g'), amount=1.12),
        ], foodPortions=[dict(id=10, amount=2, gramWeight=100, modifier='large egg',
                            measureUnit=dict(name='undetermined'))])

    def insert(self):
        catalog.save_food(self.db, *catalog.usda_record(self.record(), 'usda-test'))
        self.db.commit()

    def test_two_eggs_are_not_one_100g_egg(self):
        self.insert()
        portion = self.db.execute("SELECT * FROM portion_nutrition WHERE portion_id='usda:1:portion:10'").fetchone()
        self.assertEqual(portion['grams_per_unit'], 50)
        self.assertEqual(portion['calories_kcal'], 155)
        self.assertEqual(portion['calories_per_unit_kcal'], 77.5)
        self.assertEqual(portion['protein_per_unit_g'], 6.3)

    def test_missing_does_not_become_zero(self):
        record = self.record()
        del record['foodNutrients'][-1]
        catalog.save_food(self.db, *catalog.usda_record(record, 'usda-test'))
        self.assertIsNone(self.db.execute('SELECT carbs_g FROM foods').fetchone()[0])
        self.assertTrue(all(r[0] is None for r in self.db.execute('SELECT carbs_per_unit_g FROM portion_nutrition')))

    def test_kj_conversion_and_atwater_priority(self):
        record = self.record()
        record['foodNutrients'][0] = dict(nutrient=dict(id=1062, name='Energy', unitName='kJ'), amount=418.4)
        food, _, _ = catalog.usda_record(record, 'usda-test')
        self.assertAlmostEqual(food['calories_kcal'], 100)
        record['foodNutrients'].append(dict(nutrient=dict(id=2047, name='General', unitName='kcal'), amount=101))
        record['foodNutrients'].append(dict(nutrient=dict(id=2048, name='Specific', unitName='kcal'), amount=103))
        food, _, _ = catalog.usda_record(record, 'usda-test')
        self.assertEqual(food['calories_kcal'], 103)

    def test_negative_source_value_is_preserved_but_not_used(self):
        record = self.record()
        record['foodNutrients'][-1]['amount'] = -0.475
        food, nutrients, _ = catalog.usda_record(record, 'usda-test')
        self.assertIsNone(food['carbs_g'])
        nutrient = next(n for n in nutrients if n[0] == '1005')
        self.assertEqual(nutrient[4], 'invalid_source_value')
        self.assertEqual(nutrient[5], '-0.475')

    def test_reimport_is_idempotent(self):
        self.insert()
        self.insert()
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM foods').fetchone()[0], 1)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0], 4)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM portions').fetchone()[0], 2)

    def test_unknown_or_zero_portion_is_not_invented(self):
        record = self.record()
        record['foodPortions'] = [dict(amount=0, gramWeight=100), dict(amount=1, gramWeight=0)]
        _, _, portions = catalog.usda_record(record, 'usda-test')
        self.assertEqual(portions, [])

    def test_china_special_values_and_percentage_units(self):
        for value in ['', '—', 'Tr', 'un']:
            self.assertIsNone(catalog.china_value(value, 'g')[0])
        self.assertEqual(catalog.china_value('0g', 'g'), (0, 'g', 'reported'))
        self.assertEqual(catalog.china_value('30.3%', '%'), (30.3, '%', 'reported'))
        self.assertEqual(catalog.china_value('5.40μg', 'ug'), (5.4, 'ug', 'reported'))
        with self.assertRaises(ValueError):
            catalog.china_value('30.3%', 'g')

    def test_header_drift_is_detectable(self):
        parser = catalog.ChinaHeaders()
        parser.feed("<th class='ysq_title ysq_code_danbz' id='foodName6'>Protein</th>")
        self.assertEqual(parser.columns, {6: 'danbz'})
        with self.assertRaises(ValueError):
            catalog.china_record([1, '', 'food'], parser.columns)

    def test_restricted_foods_cannot_leak_through_query_or_export(self):
        self.insert()
        food, nutrients, portions = catalog.usda_record(self.record(), 'china-cdc')
        food['id'], food['source_food_id'], food['name'] = 'china-cdc:2', '2', 'Restricted food'
        # This fixture has no household portion; per-100g basis is added by the writer.
        catalog.save_food(self.db, food, nutrients, [])
        self.db.commit()
        self.assertEqual(catalog.search(self.db, 'Restricted'), [])
        with self.assertRaises(ValueError):
            catalog.detail(self.db, food['id'])
        self.assertEqual(len(catalog.search(self.db, 'Restricted', include_restricted=True)), 1)
        exported = catalog.export_db(self.db, Path(self.temp.name) / 'commercial.sqlite')
        with sqlite3.connect(exported) as snapshot:
            self.assertEqual(snapshot.execute('SELECT COUNT(*) FROM foods').fetchone()[0], 1)
            self.assertEqual(snapshot.execute('SELECT COUNT(*) FROM sources WHERE commercial_use_authorized=0').fetchone()[0], 0)
            self.assertEqual(snapshot.execute('PRAGMA foreign_key_check').fetchall(), [])

    def test_wildcards_and_sql_are_literal_search_text(self):
        self.insert()
        self.assertEqual(catalog.search(self.db, '%'), [])
        self.assertEqual(catalog.search(self.db, "' OR 1=1 --"), [])

    def test_compact_export_preserves_core_and_does_not_change_master(self):
        self.insert()
        self.db.execute('INSERT INTO nutrients VALUES (?,?,?,?,?,?,?,?)',
                        ('usda:1', '1087', 'Calcium', 'mg', 50, 'reported', '50', 'source'))
        self.db.commit()
        exported = catalog.export_db(self.db, Path(self.temp.name) / 'compact.sqlite', compact=True)
        with sqlite3.connect(exported) as compact:
            self.assertEqual(compact.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0], 4)
            self.assertEqual(compact.execute('SELECT calories_per_unit_kcal FROM portion_nutrition WHERE basis=?', ('source',)).fetchone()[0], 77.5)
        self.assertEqual(self.db.execute('SELECT COUNT(*) FROM nutrients').fetchone()[0], 5)


if __name__ == '__main__':
    unittest.main()
