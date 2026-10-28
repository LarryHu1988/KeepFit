import tempfile
import unittest
from copy import deepcopy
from datetime import datetime
from pathlib import Path

from fastapi.testclient import TestClient
from pydantic import ValidationError

from keepfit_model.api import create_app
from keepfit_model.engine import calculate
from keepfit_model.providers import DemoProvider, FIXTURES
from keepfit_model.schemas import IntakeInput, Understanding


TOKEN_A = "local-test-a-not-a-real-secret"
TOKEN_B = "local-test-b-not-a-real-secret"


class ServiceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)
        self.app = create_app(self.path, {"a": TOKEN_A, "b": TOKEN_B}, DemoProvider())
        self.client = TestClient(self.app)
        self.headers = {"Authorization": f"Bearer {TOKEN_A}"}

    def tearDown(self):
        self.client.close()
        self.temp.cleanup()

    def payload(self, fixture="breakfast", source="text"):
        result = {"source": source, "demo_fixture": fixture, "reference_time": "2026-10-22T09:00:00+08:00", "timezone": "Asia/Shanghai"}
        if source == "text":
            result["text"] = FIXTURES[fixture]
        if source == "voice":
            result["transcript"] = FIXTURES[fixture]
        return result

    def post(self, path, payload, key="request-0001", token=TOKEN_A):
        return self.client.post(path, json=payload, headers={"Authorization": f"Bearer {token}", "Idempotency-Key": key})

    def draft(self, fixture="breakfast", source="text"):
        response = self.post("/v1/intakes", self.payload(fixture, source))
        self.assertEqual(response.status_code, 201, response.text)
        return response.json()

    def test_full_flow(self):
        draft = self.draft()
        self.assertEqual(draft["status"], "needs_clarification")
        self.assertIsNone(draft["totals"])
        self.assertEqual(draft["known_subtotal"]["calories_kcal"], 150)
        prefix = f'/v1/intakes/{draft["id"]}'
        response = self.post(prefix + "/answers", {"expected_revision": 1, "answers": {"milk_size": "普通杯（250ml）"}})
        self.assertEqual(response.status_code, 200, response.text)
        ready = response.json()
        self.assertEqual(ready["status"], "ready_for_confirmation")
        self.assertEqual(ready["totals"], {"calories_kcal": 300, "protein_g": 19.5, "fat_g": 17.5, "carbs_g": 13.5})
        response = self.post(prefix + "/confirm", {"expected_revision": 2, "accept_estimates": True})
        self.assertEqual(response.status_code, 201, response.text)
        record = response.json()
        self.assertTrue(record["snapshot"]["model"]["simulated"])
        self.assertEqual(record["snapshot"]["revision"], 3)
        self.assertEqual(self.client.get("/v1/records/" + record["id"], headers=self.headers).json(), record)
        again = self.post(prefix + "/confirm", {"expected_revision": 2, "accept_estimates": True})
        self.assertEqual(again.json(), record)
        duplicate = self.post(prefix + "/confirm", {"expected_revision": 3, "accept_estimates": True}, "new-confirm-key")
        self.assertEqual(duplicate.status_code, 409)

    def test_confirmation_is_blocked_for_missing_information(self):
        draft = self.draft()
        result = self.post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 1, "accept_estimates": True})
        self.assertEqual(result.json()["error"]["code"], "clarification_required")

    def test_estimates_require_explicit_acceptance(self):
        draft = self.draft("shared_dish")
        result = self.post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 1})
        self.assertEqual(result.json()["error"]["code"], "estimate_acceptance_required")

    def test_idempotency_replay_and_collision(self):
        first = self.draft()
        self.assertEqual(self.post("/v1/intakes", self.payload()).json(), first)
        response = self.post("/v1/intakes", self.payload("leftovers"))
        self.assertEqual(response.json()["error"]["code"], "idempotency_conflict")

    def test_answer_replay_and_stale_revision(self):
        draft = self.draft()
        url = f'/v1/intakes/{draft["id"]}/answers'
        payload = {"expected_revision": 1, "answers": {"milk_size": "小杯（150ml）"}}
        result = self.post(url, payload)
        self.assertEqual(self.post(url, payload).json(), result.json())
        self.assertEqual(self.post(url, payload, "another-answer-key").json()["error"]["code"], "revision_conflict")
        self.assertEqual(self.post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 1, "accept_estimates": True}).json()["error"]["code"], "revision_conflict")

    def test_tenant_isolation(self):
        draft = self.draft("leftovers")
        other = {"Authorization": f"Bearer {TOKEN_B}"}
        self.assertEqual(self.client.get("/v1/intakes/" + draft["id"], headers=other).status_code, 404)
        self.assertEqual(self.post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 1, "accept_estimates": True}, token=TOKEN_B).status_code, 404)
        own = self.post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 1, "accept_estimates": True}).json()
        self.assertEqual(self.client.get("/v1/records/" + own["id"], headers=other).status_code, 404)

    def test_auth_and_missing_idempotency_key(self):
        self.assertEqual(self.client.get("/v1/capabilities").status_code, 401)
        self.assertEqual(self.client.post("/v1/intakes", json=self.payload(), headers=self.headers).status_code, 422)

    def test_arbitrary_text_is_not_faked(self):
        payload = self.payload()
        payload.pop("demo_fixture")
        payload["text"] = "随便猜一盘菜"
        result = self.post("/v1/intakes", payload)
        self.assertEqual(result.json()["error"]["code"], "demo_fixture_required")

    def test_mismatched_fixture_is_rejected(self):
        payload = self.payload()
        payload["text"] = "什么都没有吃"
        self.assertEqual(self.post("/v1/intakes", payload).json()["error"]["code"], "fixture_text_mismatch")

    def test_unknown_answer_does_not_mutate(self):
        draft = self.draft()
        result = self.post(f'/v1/intakes/{draft["id"]}/answers', {"expected_revision": 1, "answers": {"wrong": "yes"}})
        self.assertEqual(result.status_code, 422)
        self.assertEqual(self.client.get("/v1/intakes/" + draft["id"], headers=self.headers).json()["revision"], 1)

    def test_voice_transcript_uses_same_pipeline(self):
        draft = self.draft("correction", "voice")
        self.assertEqual(draft["source"], "voice")
        self.assertEqual(len(draft["items"]), 1)
        self.assertEqual(draft["items"][0]["consumed_grams"], 120)

    def test_photo_requires_personal_portion(self):
        draft = self.draft("photo_shared", "photo")
        self.assertIsNone(draft["totals"])
        result = self.post(f'/v1/intakes/{draft["id"]}/answers', {"expected_revision": 1, "answers": {"my_portion": "我吃了四分之一盘"}})
        self.assertEqual(result.json()["totals"]["calories_kcal"], 105)

    def test_shared_dish_not_divided_by_party_size(self):
        draft = self.draft("shared_dish")
        self.assertEqual(draft["items"][0]["consumed_grams"], 75)
        self.assertEqual(draft["totals"]["calories_kcal"], 300)

    def test_negation_excluded(self):
        draft = self.draft("negation")
        self.assertFalse(draft["items"][0]["included_in_totals"])
        self.assertEqual(draft["totals"]["calories_kcal"], 320)

    def test_leftovers_only_consumed_portion(self):
        self.assertEqual(self.draft("leftovers")["totals"]["calories_kcal"], 210)

    def test_relative_day_uses_supplied_timezone(self):
        payload = self.payload("yesterday")
        payload["reference_time"] = "2026-10-21T17:00:00+00:00"
        result = self.post("/v1/intakes", payload).json()
        self.assertEqual(result["understanding"]["meal_time"], "2026-10-21T19:00:00+08:00")

    def test_persistence_after_restart(self):
        draft = self.draft()
        with TestClient(create_app(self.path, {"a": TOKEN_A}, DemoProvider())) as fresh:
            self.assertEqual(fresh.get("/v1/intakes/" + draft["id"], headers=self.headers).json(), draft)

    def test_validation_does_not_echo_private_input(self):
        payload = self.payload()
        payload["reference_time"] = "PRIVATE-TEST-CONTENT"
        result = self.post("/v1/intakes", payload)
        self.assertEqual(result.status_code, 422)
        self.assertNotIn("PRIVATE-TEST-CONTENT", result.text)

    def test_image_validation_and_real_image_not_simulated(self):
        payload = self.payload("photo_shared", "photo")
        payload["image"] = {"mime_type": "image/png", "base64_data": "notbase64"}
        self.assertEqual(self.post("/v1/intakes", payload).status_code, 422)
        import base64, io
        from PIL import Image
        image = io.BytesIO()
        Image.new("RGB", (4, 4)).save(image, format="PNG")
        payload["image"]["base64_data"] = base64.b64encode(image.getvalue()).decode()
        self.assertEqual(self.post("/v1/intakes", payload).json()["error"]["code"], "demo_image_unsupported")

    def test_body_size_limit(self):
        result = self.client.post("/v1/intakes", content=b"x" * 6_000_001, headers=self.headers)
        self.assertEqual(result.status_code, 413)

    def test_no_provider_fails_closed(self):
        import os
        from unittest.mock import patch
        with patch.dict(os.environ, {"KEEPFIT_PROVIDER": "disabled"}):
            with TestClient(create_app(self.path, {"a": TOKEN_A})) as client:
                result = client.post("/v1/intakes", json=self.payload(), headers={**self.headers, "Idempotency-Key": "disabled-test"})
                self.assertEqual(result.status_code, 503)


class EngineTests(unittest.TestCase):
    def understanding(self):
        return DemoProvider().understand(IntakeInput(source="text", text=FIXTURES["shared_dish"], reference_time=datetime.fromisoformat("2026-10-22T12:00:00+08:00")), {})

    def test_unknown_nutrition_is_not_zero(self):
        data = self.understanding().model_dump()
        data["items"][0].update(nutrition_basis="unknown", nutrients_per_100g=None)
        result = calculate(Understanding.model_validate(data))
        self.assertIsNone(result["totals"])
        self.assertEqual(result["status"], "needs_clarification")

    def test_components_not_double_counted(self):
        data = self.understanding().model_dump()
        component = deepcopy(data["items"][0])
        component.update(id="ingredient", parent_id="pork")
        data["items"].append(component)
        self.assertEqual(calculate(Understanding.model_validate(data))["totals"].calories_kcal, 300)

    def test_other_person_not_counted(self):
        data = self.understanding().model_dump()
        data["items"][0]["eater"] = "other"
        result = calculate(Understanding.model_validate(data))
        self.assertEqual(result["known_subtotal"].calories_kcal, 0)
        self.assertIsNone(result["totals"])

    def test_invalid_model_values_rejected(self):
        for bad in [float("nan"), float("inf"), -1, 10001]:
            data = self.understanding().model_dump()
            data["items"][0]["consumed_grams"] = bad
            with self.subTest(bad=bad), self.assertRaises(ValidationError):
                Understanding.model_validate(data)

    def test_invalid_relations_rejected(self):
        data = self.understanding().model_dump()
        data["items"][0]["parent_id"] = "pork"
        with self.assertRaises(ValidationError):
            Understanding.model_validate(data)


if __name__ == "__main__":
    unittest.main()
