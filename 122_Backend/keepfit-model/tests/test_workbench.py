import json
import tempfile
import unittest
from pathlib import Path

import httpx
from fastapi.testclient import TestClient

from keepfit_model.api import create_app
from keepfit_model.cloud import Runtime, VENDORS
from keepfit_model.providers import DemoProvider, FIXTURES
from keepfit_model.schemas import IntakeInput


TOKEN = "local-test-workbench-token-only"
FAKE_KEY = "sk-test-placeholder-not-a-live-key"


def understanding():
    request = IntakeInput(source="text", text=FIXTURES["shared_dish"], reference_time="2026-10-22T12:00:00+08:00")
    result = DemoProvider().understand(request, {}).model_dump(mode="json")
    result["items"][0]["nutrition_basis"] = "model_estimate"
    result["items"][0]["estimation_notes"] = ["测试中的模型估算示例"]
    result["warnings"] = ["仅测试，不代表真实模型评测"]
    return result


class WorkbenchTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.path = Path(self.temp.name)
        self.requests = []
        self.status_code = 200
        self.result = understanding()
        self.finish_reason = "stop"

        def mock(request):
            self.requests.append(request)
            if request.url.path.endswith("/models"):
                return httpx.Response(self.status_code, json={"data": [{"id": s["model"]} for s in VENDORS.values()]})
            return httpx.Response(self.status_code, json={"choices": [{"finish_reason": self.finish_reason,
                "message": {"content": json.dumps(self.result)}}], "usage": {"total_tokens": 100}})

        self.runtime = Runtime(httpx.MockTransport(mock))
        self.client = TestClient(create_app(self.path, {"a": TOKEN}, runtime=self.runtime))
        self.headers = {"Authorization": f"Bearer {TOKEN}", "Idempotency-Key": "test-request-0001"}

    def tearDown(self):
        self.client.close()
        self.temp.cleanup()

    def post(self, path, payload, key="test-request-0001"):
        return self.client.post(path, json=payload, headers={**self.headers, "Idempotency-Key": key})

    def connect(self, vendor="deepseek"):
        result = self.post("/v1/workbench/connect", {"provider": vendor, "api_key": FAKE_KEY})
        self.assertEqual(result.status_code, 200, result.text)
        return result.json()

    def create(self):
        result = self.post("/v1/intakes", {"source": "text", "text": "中午我吃了三小块红烧肉", "reference_time": "2026-10-22T12:00:00+08:00"})
        self.assertEqual(result.status_code, 201, result.text)
        return result.json()

    def test_cookie_session_and_csrf(self):
        page = self.client.get("/")
        self.assertEqual(page.status_code, 200)
        self.assertIn("HttpOnly", page.headers["set-cookie"])
        self.assertIn("SameSite=strict", page.headers["set-cookie"])
        self.assertEqual(self.client.get("/v1/workbench/state").status_code, 200)
        self.assertEqual(self.client.post("/v1/workbench/disconnect", json={}).status_code, 403)
        self.assertEqual(self.client.post("/v1/workbench/disconnect", json={}, headers={"Origin":"https://evil.example"}).status_code, 403)
        self.assertEqual(self.client.post("/v1/workbench/disconnect", json={}, headers={"Origin":"http://testserver"}).status_code, 200)

    def test_untrusted_host_rejected(self):
        self.assertEqual(self.client.get("/", headers={"Host":"evil.example"}).status_code, 400)

    def test_static_pages_and_no_secret_exposure(self):
        self.connect()
        for route in ["/", "/workbench.js", "/workbench.css", "/v1/workbench/state"]:
            response = self.client.get(route, headers=self.headers)
            self.assertEqual(response.status_code, 200)
            self.assertNotIn(FAKE_KEY, response.text)
        self.assertNotIn(FAKE_KEY.encode(), (self.path / "keepfit.sqlite3").read_bytes())

    def test_verify_is_read_only_and_does_not_use_trial(self):
        state = self.connect()
        self.assertEqual(state["calls_used"], 0)
        self.assertEqual([r.method for r in self.requests], ["GET"])

    def test_deepseek_request_and_real_provenance(self):
        self.connect()
        draft = self.create()
        request = self.requests[-1]
        body = json.loads(request.content)
        self.assertEqual(str(request.url), "https://api.deepseek.com/chat/completions")
        self.assertEqual(body["model"], "deepseek-flash")
        self.assertEqual(body["max_tokens"], 4096)
        self.assertEqual(body["thinking"], {"type":"disabled"})
        self.assertFalse(draft["model"]["simulated"])
        self.assertEqual(draft["items"][0]["nutrition_basis"], "recipe_estimate")
        self.assertEqual(draft["items"][0]["nutrition_source"]["id"], "recipe:红烧肉")
        self.assertAlmostEqual(draft["totals"]["calories_kcal"], 447.2, places=1)

    def test_mimo_auth_and_endpoint(self):
        self.connect("mimo")
        self.create()
        request = self.requests[-1]
        self.assertEqual(str(request.url), "https://api.xiaomimimo.com/v1/chat/completions")
        self.assertEqual(request.headers["api-key"], FAKE_KEY)
        self.assertEqual(json.loads(request.content)["max_completion_tokens"], 4096)

    def test_rules_and_corrections_are_actually_in_prompt(self):
        self.connect()
        self.post("/v1/workbench/rules", {"expected_revision":1,"question_style":"careful","allow_estimates":False,"instructions":"我家的小碗很浅"})
        draft = self.create()
        response = self.post("/v1/workbench/feedback", {"intake_id":draft["id"],"expected_revision":1,"correction":"说三块时指小块，不是大块"})
        self.assertEqual(response.status_code, 200)
        result = self.post(f'/v1/intakes/{draft["id"]}/revise', {"expected_revision":1,"correction":"这餐是三小块，去掉肥肉"})
        self.assertEqual(result.status_code, 200, result.text)
        body = json.loads(self.requests[-1].content)
        self.assertIn("我家的小碗很浅", body["messages"][0]["content"])
        self.assertIn("说三块时指小块，不是大块", body["messages"][0]["content"])
        self.assertIn("previous", body["messages"][1]["content"])
        self.assertIn("这餐是三小块，去掉肥肉", body["messages"][1]["content"])

    def test_idempotency_does_not_repeat_paid_call(self):
        self.connect()
        first = self.create()
        count = len(self.requests)
        self.assertEqual(self.create(), first)
        self.assertEqual(len(self.requests), count)

    def test_invalid_model_output_fails_without_writing(self):
        self.connect()
        self.result = {"bad":"schema"}
        response = self.post("/v1/intakes", {"source":"text","text":"吃了一碗面","reference_time":"2026-10-22T12:00:00+08:00"})
        self.assertEqual(response.json()["error"]["code"], "invalid_model_output")
        state = self.client.get("/v1/workbench/state",headers=self.headers).json()
        self.assertEqual(state["history"], [])
        self.assertEqual(state["connection"]["calls_used"], 1)

    def test_truncated_model_output_not_saved(self):
        self.connect();self.finish_reason = "length"
        response = self.post("/v1/intakes", {"source":"text","text":"吃了面","reference_time":"2026-10-22T12:00:00+08:00"})
        self.assertEqual(response.json()["error"]["code"], "model_output_incomplete")

    def test_trial_limit_prevents_network_and_reconnect_does_not_reset(self):
        self.connect()
        self.runtime.state("a")["calls"] = 10
        self.connect()
        count = len(self.requests)
        response = self.post("/v1/intakes", {"source":"text","text":"吃了面","reference_time":"2026-10-22T12:00:00+08:00"})
        self.assertEqual(response.json()["error"]["code"], "trial_limit")
        self.assertEqual(len(self.requests), count)
        self.assertEqual(self.post("/v1/workbench/extend-trial", {}).json()["call_limit"], 20)

    def test_auth_failure_is_sanitized(self):
        self.status_code=401
        response=self.post("/v1/workbench/connect", {"provider":"deepseek","api_key":FAKE_KEY})
        self.assertEqual(response.status_code,502)
        self.assertNotIn(FAKE_KEY,response.text)

    def test_disconnect_clears_key(self):
        self.connect();self.post("/v1/workbench/disconnect",{})
        self.assertIsNone(self.runtime.state("a")["key"])
        self.assertFalse(self.runtime.status("a")["connected"])

    def test_rules_stale_revision_rejected(self):
        payload={"expected_revision":1,"instructions":"先问份量"}
        self.assertEqual(self.post("/v1/workbench/rules",payload).status_code,200)
        self.assertEqual(self.post("/v1/workbench/rules",payload).status_code,409)


if __name__ == "__main__":
    unittest.main()
