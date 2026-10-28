import base64
import io
import json
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi.testclient import TestClient
from PIL import Image
from keepfit_model.api import create_app
from keepfit_model.engine import calculate
from keepfit_model.nutrition import CATALOG, MATCHES, ground
from keepfit_model.production import AppleAuth, AppleLogin, ServerRuntime
from keepfit_model.providers import ServiceError
from keepfit_model.schemas import Understanding, ImageInput
from keepfit_model.store import Store


def meal(name='水煮鸡蛋',grams=100,portion_estimate=False):
    return Understanding.model_validate({'meal_time':'2026-10-24T08:00:00+08:00','meal_time_note':'用户提供',
        'normalized_text':name,'items':[{'id':'a','name':name,'original_portion':str(grams)+'克','eater':'self',
        'consumption':'eaten','consumed_grams':grams,'portion_is_estimate':portion_estimate,
        'nutrition_basis':'model_estimate','nutrients_per_100g':{'calories_kcal':99,'protein_g':1,'fat_g':1,'carbs_g':1},
        'estimation_notes':['合成模型返回，用于测试覆盖数据库而非实际营养精度']}]})

class NutritionTests(unittest.TestCase):
    def test_source_grounding_overrides_model_numbers(self):
        grounded=ground(meal())
        self.assertEqual(grounded.items[0].nutrition_basis,'food_database')
        self.assertEqual(grounded.items[0].nutrients_per_100g.calories_kcal,155)
        self.assertEqual(grounded.items[0].nutrition_source['id'],'usda:173424')
    def test_arithmetic_from_source_weights(self):
        result=calculate(ground(meal(grams=50)))
        self.assertEqual(result['totals'].calories_kcal,77.5)
        self.assertFalse(result['requires_estimate_acceptance'])
    def test_recipe_is_explicit_not_a_measured_usda_dish(self):
        item=ground(meal('番茄炒蛋')).items[0]
        self.assertEqual(item.nutrition_basis,'recipe_estimate')
        self.assertIn('假设成品400g',item.nutrition_source['note'])
        self.assertEqual(len(item.nutrition_source['ingredients']),4)
        self.assertTrue(calculate(ground(meal('番茄炒蛋')))['requires_estimate_acceptance'])
    def test_no_fuzzy_raw_cooked_or_brand_substitution(self):
        for name in ['生米','煎鸡蛋','某品牌全脂牛奶','少油红烧肉','红烧肉去肥肉']:
            self.assertEqual(ground(meal(name)).items[0].nutrition_basis,'model_estimate')
    def test_unknown_is_not_zero(self):
        u=meal('未知食物');u.items[0].nutrition_basis='unknown';u.items[0].nutrients_per_100g=None
        result=calculate(ground(u));self.assertIsNone(result['totals']);self.assertFalse(result['totals_complete'])
    def test_forbidding_estimates_is_enforced_in_code(self):
        self.assertIsNone(calculate(ground(meal('红烧肉'),False))['totals'])
        self.assertIsNone(calculate(ground(meal(portion_estimate=True),False))['totals'])
    def test_other_people_negation_components_never_count(self):
        for field,value in [('eater','other'),('consumption','not_eaten')]:
            u=meal();setattr(u.items[0],field,value)
            self.assertEqual(calculate(ground(u))['known_subtotal'].calories_kcal,0)
    def test_catalog_provenance_and_physical_ranges(self):
        self.assertEqual(len(CATALOG['archive_sha256']),64)
        for f in CATALOG['foods']:
            self.assertTrue(f['url'].startswith('https://fdc.nal.usda.gov/food-details/'))
            n=f['nutrients_per_100g'];self.assertEqual(len(n),4)
            self.assertLessEqual(sum(n[k] for k in ['protein_g','fat_g','carbs_g']),105)
    def test_image_decode_and_metadata_normalization(self):
        out=io.BytesIO();Image.new('RGB',(2000,1000)).save(out,format='PNG')
        value=ImageInput(mime_type='image/png',base64_data=base64.b64encode(out.getvalue()).decode())
        self.assertEqual(value.mime_type,'image/jpeg')
        with Image.open(io.BytesIO(base64.b64decode(value.base64_data))) as image:
            self.assertEqual(image.size,(1600,800));self.assertFalse(image.getexif())
    def test_forged_image_header_is_rejected(self):
        with self.assertRaises(ValueError): ImageInput(mime_type='image/jpeg',base64_data=base64.b64encode(b'\xff\xd8\xffgarbage').decode())

class ProductionTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.store=Store(Path(self.temp.name));self.auth=AppleAuth(self.store,'com.larry.keepfit')
        self.private=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        key=json.loads(jwt.algorithms.RSAAlgorithm.to_jwk(self.private.public_key()));key['kid']='test-key'
        self.auth.jwks=[key];self.auth.loaded=time.time()
    def tearDown(self): self.temp.cleanup()
    def login(self,subject='owner',nonce=None,audience='com.larry.keepfit'):
        c=self.auth.challenge('ip')
        token=jwt.encode({'sub':subject,'iss':'https://appleid.apple.com','aud':audience,'iat':int(time.time()),
                          'exp':int(time.time())+300,'nonce':nonce or c['nonce']},self.private,algorithm='RS256',headers={'kid':'test-key'})
        return self.auth.login(AppleLogin(identity_token=token,challenge_id=c['id']),'ip')
    def test_apple_signature_audience_and_nonce(self):
        for args in [{'nonce':'wrong'},{'audience':'another-app'}]:
            with self.assertRaises(ServiceError): self.login(**args)
        session=self.login();self.assertTrue(self.auth.owner(session['token']).startswith('apple:'))
        self.assertNotIn(session['token'].encode(),self.store.path.read_bytes())
    def test_tenant_sessions_are_distinct(self):
        a=self.login('a');b=self.login('b');self.assertNotEqual(self.auth.owner(a['token']),self.auth.owner(b['token']))
    def test_daily_limits_survive_process_restart(self):
        runtime=ServerRuntime(self.store,'deepseek','not-real-test-provider-key',per_user=1,global_limit=2)
        runtime.provider('a',{},[]).reserve()
        fresh=ServerRuntime(self.store,'deepseek','not-real-test-provider-key',per_user=1,global_limit=2)
        with self.assertRaises(ServiceError): fresh.provider('a',{},[]).reserve()
        fresh.provider('b',{},[]).reserve()
        with self.assertRaises(ServiceError): fresh.provider('c',{},[]).reserve()
        self.assertEqual(fresh.usage('c'),0)
    def test_production_has_no_workbench_or_cookie_login(self):
        runtime=ServerRuntime(self.store,'deepseek','not-real-test-provider-key')
        with patch.dict(os.environ,{'KEEPFIT_MODE':'production','KEEPFIT_ALLOWED_HOSTS':'testserver'}):
            app=create_app(Path(self.temp.name),{},runtime=runtime)
        with TestClient(app) as c:
            for path in ['/','/docs','/v1/workbench/connect','/v1/workbench/state']:
                self.assertEqual(c.get(path).status_code,404)
            self.assertEqual(c.get('/v1/capabilities').status_code,401)
            self.assertEqual(c.post('/v1/auth/challenge').status_code,200)
