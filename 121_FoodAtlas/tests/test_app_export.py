import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import catalog
import export_app


class AppExportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.db_path = self.root / 'foods.sqlite'
        self.config = self.root / 'app-foods.json'
        self.output = self.root / 'atlas.json'
        self.db = catalog.open_db(self.db_path)
        for sid, authorized in [('usda-test', 1), ('restricted', 0)]:
            catalog.add_source(self.db, dict(id=sid, name=sid, version='test', url='https://example.com',
                license='test', commercial_use_authorized=authorized, retrieved_at='test', raw_sha256='test', notes=''))
        for food_id, source in [(1, 'usda-test'), (2, 'restricted'), (3, 'usda-test')]:
            self.db.execute('''INSERT INTO foods(id,source_id,source_food_id,name,category,data_type,source_url,
                calories_kcal,protein_g,fat_g,carbs_g) VALUES(?,?,?,?,?,?,?,?,?,?,?)''',
                (f'usda:{food_id}', source, str(food_id), f'Test {food_id}', 'Beverages', 'test',
                 'https://example.com', 60, 3, 2, None if food_id == 3 else 7))
        self.db.commit()
        self.write_config()

    def tearDown(self):
        self.db.close()
        self.temp.cleanup()

    def write_config(self, **changes):
        self.config.write_text(json.dumps(dict(schemaVersion=1, overrides={}, foods=[], **changes)))

    def run_export(self):
        return export_app.export(self.db_path, self.config, self.output, version='test')

    def test_filters_restricted_and_missing_and_does_not_guess_volume(self):
        report = self.run_export()
        self.assertEqual(report['foods'], 1)
        self.assertEqual(report['excluded_incomplete'], 1)
        food = json.loads(self.output.read_text())['foods'][0]
        self.assertEqual(food['category'], 'drink')
        self.assertEqual(food['basis']['unit'], 'g')
        self.assertEqual(food['basis']['calories'], 60)

    def test_same_id_update_and_removal_replace_previous_export(self):
        self.run_export()
        self.db.execute("UPDATE foods SET calories_kcal=99 WHERE id='usda:1'")
        self.db.execute("UPDATE foods SET carbs_g=0 WHERE id='usda:3'")
        self.db.commit()
        self.run_export()
        entries = {f['id']: f for f in json.loads(self.output.read_text())['foods']}
        self.assertEqual(entries['usda:1']['basis']['calories'], 99)
        self.assertEqual(entries['usda:3']['basis']['carbs'], 0)
        self.db.execute("DELETE FROM foods WHERE id='usda:1'")
        self.db.commit()
        self.run_export()
        self.assertEqual([f['id'] for f in json.loads(self.output.read_text())['foods']], ['usda:3'])

    def test_curation_volume_has_independent_nutrients_and_no_density(self):
        config = dict(schemaVersion=1, overrides={'usda:1': {
            'name': '测试牛奶', 'icon': '🥛', 'aliases': ['测试奶'],
            'basis': dict(amount=100, unit='mL', calories=64, protein=3, fat=4, carbs=4)
        }}, foods=[])
        self.config.write_text(json.dumps(config))
        self.run_export()
        basis = json.loads(self.output.read_text())['foods'][0]['basis']
        self.assertEqual(basis['unit'], 'mL')
        self.assertNotIn('gramsPerUnit', basis)

    def test_invalid_update_preserves_last_good_export(self):
        self.run_export()
        before = self.output.read_bytes()
        config = dict(schemaVersion=1, overrides={'usda:1': {'basis': dict(amount=0, unit='个', calories=70, protein=6, fat=5, carbs=1)}}, foods=[])
        self.config.write_text(json.dumps(config))
        with self.assertRaises(ValueError):
            self.run_export()
        self.assertEqual(self.output.read_bytes(), before)

    def test_custom_food_requires_explicit_authorization_and_stable_id(self):
        custom = dict(id='custom:egg', name='测试鸡蛋', icon='🥚', category='protein', aliases=[],
            basis=dict(amount=1, unit='个', gramsPerUnit=50, calories=70, protein=6, fat=5, carbs=1),
            sourceName='用户维护')
        config = dict(schemaVersion=1, overrides={}, foods=[custom])
        self.config.write_text(json.dumps(config))
        with self.assertRaises(ValueError):
            self.run_export()
        custom['commercialUseAuthorized'] = True
        self.config.write_text(json.dumps(config))
        self.assertEqual(self.run_export()['foods'], 2)

    def test_common_food_rank_is_exported_without_dropping_searchable_library(self):
        config = json.loads(self.config.read_text())
        config['commonFoodIDs'] = ['usda:1']
        self.config.write_text(json.dumps(config))
        self.run_export()
        food = json.loads(self.output.read_text())['foods'][0]
        self.assertEqual(food['commonFoodRank'], 0)

    def test_common_food_ids_must_be_unique_complete_and_authorized(self):
        self.run_export()
        before = self.output.read_bytes()
        for ids in [['usda:1', 'usda:1'], ['usda:2'], ['usda:3'], ['missing']]:
            config = json.loads(self.config.read_text())
            config['commonFoodIDs'] = ids
            self.config.write_text(json.dumps(config))
            with self.assertRaises(ValueError):
                self.run_export()
            self.assertEqual(self.output.read_bytes(), before)


if __name__ == '__main__':
    unittest.main()
