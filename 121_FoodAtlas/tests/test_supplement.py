import json
import unittest

import test_catalog as fixtures
import catalog
import supplement
from browser import Atlas, progress, valid_gtin


def comparison(products, links=True):
    heads=''.join('<td><a href="food/%s.html">%s</a></td>'%(p['unid'],p['productName']) if links else '<td>'+p['productName']+'</td>' for p in products)
    def row(name,values):
        return '<tr><td>'+name+'</td>'+''.join('<td>'+v+'</td>' for v in values)+'</tr>'
    return ('<table><tr><td>食物</td>'+heads+'</tr>'+
        row('条形码/识别码',[p['barCode'] for p in products])+row('品牌',['Example']*len(products))+
        row('净含量',['200mL']*len(products))+row('能量',['250kJ']*len(products))+
        row('蛋白质',['3.2g']*len(products))+row('脂肪',['0.0g']*len(products))+
        row('碳水化合物',['<0.5g']*len(products))+row('钠',['40mg']*len(products))+'</table>').encode()


class SupplementTests(unittest.TestCase):
    def setUp(self):
        self.fixture=fixtures.CatalogTests()
        self.fixture.setUp()
        self.fixture.insert()
        self.db=self.fixture.db
        catalog.add_source(self.db,dict(id=supplement.PACKAGED_SOURCE,name='NLC',version='test',url=supplement.BASE,
            license='pending',commercial_use_authorized=0,retrieved_at='test',raw_sha256='test',notes='test'))
        self.record=dict(unid='sample',productName='测试牛奶',barCode='1234567890123',url='/sample.html')
        food=supplement.empty_food('nlc:sample',supplement.PACKAGED_SOURCE,'sample','测试牛奶',None,'label',supplement.BASE)
        catalog.save_food(self.db,food,[],[])
        self.db.execute("DELETE FROM portions WHERE food_id='nlc:sample'")
        self.db.execute('''INSERT INTO food_metadata(food_id,kind,barcode,basis_status,detail_status,raw_json)
            VALUES ('nlc:sample','packaged',?,'unverified','index_only',?)''',
            (self.record['barCode'],json.dumps(self.record)))
        self.db.commit()

    def tearDown(self):
        self.fixture.tearDown()

    def test_public_comparison_matches_ids_not_column_order(self):
        other=dict(unid='other',productName='另一商品',barCode='456')
        rows=supplement.parse_comparison(comparison([other,self.record]),[self.record,other])
        self.assertEqual([r['unid'] for r in rows],['other','sample'])
        self.assertEqual(rows[0]['metadata']['net_content'],'200mL')
        fat=next(r for r in rows[0]['nutrients'] if r[0]=='fat')
        carbs=next(r for r in rows[0]['nutrients'] if r[0]=='carbs')
        self.assertEqual(fat[3],0)
        self.assertIsNone(carbs[3])
        self.assertEqual(carbs[5],'<0.5g')

    def test_ambiguous_duplicate_barcodes_require_single_id_request(self):
        other=dict(self.record,unid='other')
        with self.assertRaisesRegex(ValueError,'Ambiguous'):
            supplement.parse_comparison(comparison([self.record,other],links=False),[self.record,other])
        single=supplement.parse_comparison(comparison([self.record],links=False),[self.record])
        self.assertEqual(single[0]['unid'],'sample')

    def test_source_four_column_limit_is_not_silently_exceeded(self):
        rows=[dict(self.record,unid=str(i)) for i in range(5)]
        with self.assertRaisesRegex(ValueError,'four'):
            supplement.parse_comparison(comparison(rows),rows)

    def test_unknown_reference_does_not_create_100g_macros_or_portions(self):
        rows=supplement.parse_comparison(comparison([self.record]),[self.record])
        with self.db:
            supplement.save_comparison(self.db,rows,catalog.ROOT/'.data/raw/test.html')
        food=self.db.execute("SELECT * FROM foods WHERE id='nlc:sample'").fetchone()
        self.assertIsNone(food['calories_kcal'])
        self.assertIsNone(food['protein_g'])
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM portions WHERE food_id='nlc:sample'").fetchone()[0],0)
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM nutrients WHERE food_id='nlc:sample'").fetchone()[0],0)
        self.assertEqual(self.db.execute("SELECT COUNT(*) FROM label_nutrients WHERE food_id='nlc:sample'").fetchone()[0],5)
        self.assertEqual(catalog.search(self.db,'测试牛奶'),[])
        atlas=Atlas(self.fixture.path,{},overrides={},terms={})
        detail=atlas.detail('nlc:sample')
        self.assertEqual(detail['metadata']['detail_status'],'raw_label_complete')
        self.assertEqual(len(detail['label_nutrients']),5)
        self.assertEqual(detail['nutrients_per_100g'],[])
        self.assertEqual(atlas.listing({'q':['1234567890123']})['total'],1)

    def test_detail_basis_does_not_infer_density(self):
        body=b'<table><tr><td>\xe9\xa1\xb9\xe7\x9b\xae</td><td>\xe6\xaf\x8f100\xe6\xaf\xab\xe5\x8d\x87</td></tr><tr><td>\xe8\x83\xbd\xe9\x87\x8f</td><td>250kJ</td></tr></table>'
        parsed=supplement.parse_detail(body)
        self.assertEqual((parsed['quantity'],parsed['unit']),(100,'ml'))
        with self.assertRaisesRegex(ValueError,'cannot be safely parsed'):
            supplement.parse_detail('<table><tr><td>项目</td><td>每份</td></tr></table>'.encode())

    def test_verified_ml_label_keeps_per100g_empty(self):
        body=('<p>1234567890123</p><table><tr><td>项目</td><td>每100毫升</td></tr>'
              '<tr><td>能量</td><td>250kJ</td></tr><tr><td>蛋白质</td><td>3.2g</td></tr></table>').encode()
        class Cache:
            def get(self,*args): return body
        supplement.verify_one(self.db,Cache(),self.record)
        row=self.db.execute("SELECT * FROM foods WHERE id='nlc:sample'").fetchone()
        self.assertIsNone(row['calories_kcal'])
        self.assertEqual(self.db.execute("SELECT basis_unit FROM food_metadata WHERE food_id='nlc:sample'").fetchone()[0],'ml')

    def test_verified_25g_label_normalizes_mass_only(self):
        body=('<p>1234567890123</p><table><tr><td>项目</td><td>每25克</td></tr>'
              '<tr><td>能量</td><td>418.4kJ</td></tr><tr><td>蛋白质</td><td>2g</td></tr></table>').encode()
        class Cache:
            def get(self,*args): return body
        supplement.verify_one(self.db,Cache(),self.record)
        row=self.db.execute("SELECT * FROM foods WHERE id='nlc:sample'").fetchone()
        self.assertAlmostEqual(row['calories_kcal'],400)
        self.assertEqual(row['protein_g'],8)
        self.assertEqual(self.db.execute("SELECT amount FROM label_nutrients WHERE food_id='nlc:sample' AND nutrient_id='protein'").fetchone()[0],2)

    def test_source_bounds_missing_and_zero_are_distinct(self):
        self.assertEqual(supplement.parse_value('0g'),(0,'g','reported'))
        self.assertEqual(supplement.parse_value('', 'g'),(None,'g','missing'))
        self.assertIsNone(supplement.parse_value('≤0.5g')[0])
        self.assertEqual(supplement.parse_value('Tr','g')[2],'not_detected')
        self.assertEqual(supplement.parse_value('-3g')[2],'invalid_source_value')

    def test_product_dedup_requires_size_and_identical_complete_label(self):
        self.record['barCode']='6923503784526'
        parsed=supplement.parse_comparison(comparison([self.record]),[self.record])
        with self.db:
            supplement.save_comparison(self.db,parsed,catalog.ROOT/'.data/raw/test.html')
            food=supplement.empty_food('nlc:other',supplement.PACKAGED_SOURCE,'other','测试牛奶',None,'label',supplement.BASE)
            catalog.save_food(self.db,food,[],[])
            self.db.execute('''INSERT INTO food_metadata(food_id,kind,barcode,brand,net_content,basis_status,detail_status,raw_json)
                SELECT 'nlc:other',kind,barcode,brand,net_content,basis_status,detail_status,raw_json FROM food_metadata WHERE food_id='nlc:sample' ''')
            self.db.execute('''INSERT INTO label_nutrients SELECT 'nlc:other',nutrient_id,name,unit,amount,qualifier,raw_value
                FROM label_nutrients WHERE food_id='nlc:sample' ''')
        self.assertTrue(valid_gtin(self.record['barCode']))
        atlas=Atlas(self.fixture.path,{},overrides={},terms={})
        self.assertEqual(atlas.listing({'source':[supplement.PACKAGED_SOURCE]})['total'],1)
        self.assertEqual(atlas.detail('nlc:sample')['variants'][1]['id'],'nlc:sample')
        with self.db:
            self.db.execute("UPDATE food_metadata SET net_content='300mL' WHERE food_id='nlc:other'")
        atlas=Atlas(self.fixture.path,{},overrides={},terms={})
        self.assertEqual(atlas.listing({'source':[supplement.PACKAGED_SOURCE]})['total'],2)

    def test_login_or_unexpected_source_page_stops_collection(self):
        with self.assertRaises(supplement.SourceAccessError):
            supplement.parse_comparison(b'<html><h1>Please sign in</h1></html>',[self.record])


if __name__=='__main__':
    unittest.main()
