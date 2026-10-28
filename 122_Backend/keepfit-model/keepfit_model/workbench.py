import secrets
from datetime import datetime, timezone
from pathlib import Path
from typing import Literal
from uuid import uuid4

from fastapi import Depends, Request
from fastapi.responses import FileResponse
from pydantic import Field, SecretStr

from .cloud import VENDORS
from .providers import ServiceError
from .schemas import StrictModel


class ConnectionInput(StrictModel):
    provider: Literal["deepseek", "mimo"]
    api_key: SecretStr = Field(min_length=16, max_length=512)


class RulesInput(StrictModel):
    expected_revision: int = Field(ge=1)
    question_style: Literal["balanced", "minimal", "careful"] = "balanced"
    allow_estimates: bool = True
    instructions: str = Field(default="", max_length=1600)


class FeedbackInput(StrictModel):
    intake_id: str
    expected_revision: int = Field(ge=1)
    correction: str = Field(min_length=1, max_length=1200)
    use_for_future: bool = True


def list_objects(store, owner, kind, limit=50):
    import json
    with store.transaction() as db:
        rows = db.execute("SELECT body FROM objects WHERE owner=? AND kind=? ORDER BY rowid DESC LIMIT ?", (owner, kind, limit)).fetchall()
    return [json.loads(row[0]) for row in rows]


def profile(store, owner):
    with store.transaction() as db:
        try:
            return store.get(db, owner, "rules", "active")
        except ServiceError as exc:
            if exc.status != 404:
                raise
    return {"id": "active", "revision": 1, "question_style": "balanced", "allow_estimates": True, "instructions": ""}


def examples(store, owner):
    return [{"meal": item["original_text"], "correction": item["correction"]}
            for item in reversed(list_objects(store, owner, "feedback", 50)) if item["use_for_future"]][-6:]


def install_workbench(app, owner_dependency, store, runtime, session_token, local_owner):
    web = Path(__file__).with_name("web")

    @app.get("/", include_in_schema=False)
    def home():
        response = FileResponse(web / "index.html", headers={"Cache-Control": "no-store"})
        response.set_cookie("keepfit_session", session_token, httponly=True, samesite="strict", max_age=8 * 3600)
        return response

    @app.get("/workbench.css", include_in_schema=False)
    def css():
        return FileResponse(web / "workbench.css", media_type="text/css")

    @app.get("/workbench.js", include_in_schema=False)
    def js():
        return FileResponse(web / "workbench.js", media_type="text/javascript")

    @app.middleware("http")
    async def browser_headers(request: Request, call_next):
        response = await call_next(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["X-Frame-Options"] = "DENY"
        if request.url.path == "/":
            response.headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' blob: data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'self'"
        if request.url.path.startswith("/v1/"):
            response.headers["Cache-Control"] = "no-store"
        return response

    @app.get("/v1/workbench/state")
    def state(client: str = Depends(owner_dependency)):
        return {"connection": runtime.status(client), "rules": profile(store, client),
                "vendors": [{"id": k, "model": v["model"], "console": v["console"]} for k, v in VENDORS.items()],
                "feedback": list_objects(store, client, "feedback"),
                "history": [{"id": i["id"], "text": i["original_text"], "status": i["status"], "simulated": i["model"]["simulated"]}
                            for i in list_objects(store, client, "intake", 15)]}

    @app.post("/v1/workbench/connect")
    def connect(body: ConnectionInput, client: str = Depends(owner_dependency)):
        key = body.api_key.get_secret_value().strip()
        if not key.isascii() or any(c.isspace() for c in key):
            raise ServiceError("invalid_key", "密钥格式不正确，请完整复制平台生成的密钥。")
        return runtime.connect(client, body.provider, key)

    @app.post("/v1/workbench/disconnect")
    def disconnect(client: str = Depends(owner_dependency)):
        runtime.disconnect(client)
        return runtime.status(client)

    @app.post("/v1/workbench/extend-trial")
    def extend(client: str = Depends(owner_dependency)):
        return runtime.extend(client)

    @app.post("/v1/workbench/rules")
    def save_rules(body: RulesInput, client: str = Depends(owner_dependency)):
        with store.transaction() as db:
            try:
                current = store.get(db, client, "rules", "active")
            except ServiceError:
                current = {"revision": 1}
            if body.expected_revision != current["revision"]:
                raise ServiceError("revision_conflict", "规则已在其它页面更新，请刷新后重试。", 409)
            result = {"id": "active", "revision": current["revision"] + 1, **body.model_dump(exclude={"expected_revision"})}
            store.put(db, client, "rules", result)
        return result

    @app.post("/v1/workbench/feedback")
    def feedback(body: FeedbackInput, client: str = Depends(owner_dependency)):
        with store.transaction() as db:
            draft = store.get(db, client, "intake", body.intake_id)
            if draft["revision"] != body.expected_revision:
                raise ServiceError("revision_conflict", "结果已变化，请刷新后再保存纠正。", 409)
            result = {"id": str(uuid4()), "created_at": datetime.now(timezone.utc).isoformat(),
                      **body.model_dump(), "original_text": draft["original_text"], "snapshot": draft["understanding"]}
            store.put(db, client, "feedback", result)
        return result

    @app.post("/v1/workbench/feedback/{feedback_id}/delete")
    def delete_feedback(feedback_id: str, client: str = Depends(owner_dependency)):
        with store.transaction() as db:
            store.get(db, client, "feedback", feedback_id)
            db.execute("DELETE FROM objects WHERE owner=? AND kind='feedback' AND id=?", (client, feedback_id))
        return {"deleted": True}
