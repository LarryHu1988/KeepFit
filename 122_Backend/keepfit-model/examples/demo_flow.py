"""Run against an explicitly started local demo; no external network calls."""
import argparse
import json
from pathlib import Path
from uuid import uuid4

import httpx


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token-file", type=Path, default=Path(".data/local-token"))
    args = parser.parse_args()
    headers = {"Authorization": "Bearer " + args.token_file.read_text().strip()}
    with httpx.Client(base_url=f"http://127.0.0.1:{args.port}", headers=headers, timeout=15, trust_env=False) as client:
        def post(path, payload):
            response = client.post(path, json=payload, headers={"Idempotency-Key": str(uuid4())})
            response.raise_for_status()
            return response.json()

        draft = post("/v1/intakes", {"source": "text", "text": "早餐两个鸡蛋、一杯牛奶", "reference_time": "2026-10-22T09:00:00+08:00", "timezone": "Asia/Shanghai"})
        print("1. 输入后：", draft["status"], draft["understanding"]["questions"][0]["text"])
        ready = post(f'/v1/intakes/{draft["id"]}/answers', {"expected_revision": 1, "answers": {"milk_size": "普通杯（250ml）"}})
        print("2. 补充后：", ready["status"], json.dumps(ready["totals"], ensure_ascii=False))
        record = post(f'/v1/intakes/{draft["id"]}/confirm', {"expected_revision": 2, "accept_estimates": True})
        print("3. 已保存演示记录：", record["id"], "simulated =", record["snapshot"]["model"]["simulated"])


if __name__ == "__main__":
    main()
