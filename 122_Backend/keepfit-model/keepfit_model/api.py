import json
import os
import secrets
from datetime import datetime, timezone
from pathlib import Path
from threading import RLock
from typing import Annotated
from uuid import uuid4

from fastapi import Depends, FastAPI, Header, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from starlette.middleware.trustedhost import TrustedHostMiddleware
from pydantic import Field

from .cloud import Runtime
from .workbench import install_workbench, profile, examples

from .engine import calculate
from .providers import DemoProvider, FIXTURES, ServiceError, UnderstandingProvider
from .schemas import AnswerInput, ConfirmInput, ErrorEnvelope, Intake, IntakeInput, Record, StrictModel
from .store import Store


class BodyLimit:
    def __init__(self, app, limit=6_000_000):
        self.app, self.limit = app, limit

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["method"] not in {"POST", "PUT", "PATCH"}:
            return await self.app(scope, receive, send)
        chunks, count = [], 0
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            count += len(chunk)
            if count > self.limit:
                return await JSONResponse(status_code=413, content={"error": {"code": "payload_too_large", "message": "请求超过6MB。"}})(scope, receive, send)
            chunks.append(chunk)
            if not message.get("more_body", False):
                break
        pending = True

        async def replay_receive():
            nonlocal pending
            if pending:
                pending = False
                return {"type": "http.request", "body": b"".join(chunks), "more_body": False}
            return await receive()

        await self.app(scope, replay_receive, send)


def create_app(directory: Path | None = None, client_keys: dict[str, str] | None = None,
               provider: UnderstandingProvider | None = None, runtime: Runtime | None = None):
    directory = directory or Path(os.environ.get("KEEPFIT_DATA_DIR", ".data"))
    if client_keys is None:
        client_keys = json.loads(os.environ.get("KEEPFIT_CLIENT_KEYS", "{}"))
    if not isinstance(client_keys, dict) or any(not isinstance(k, str) or not k or not isinstance(v, str) or len(v) < 20 for k, v in client_keys.items()):
        raise ValueError("KEEPFIT_CLIENT_KEYS 应为 client_id 到至少20字符 token 的 JSON 映射")
    if len(set(client_keys.values())) != len(client_keys):
        raise ValueError("不同调用方必须使用不同 token")
    if provider is None and os.environ.get("KEEPFIT_PROVIDER") == "demo":
        provider = DemoProvider()
    production = os.environ.get("KEEPFIT_MODE") == "production"
    if production and provider is not None:
        raise ValueError("Production cannot use demo fixtures")
    store = Store(directory)
    from .production import AppleAuth, AppleLogin, configure_server
    apple_auth = AppleAuth(store, os.environ.get("KEEPFIT_APPLE_AUDIENCE", "com.larry.keepfit")) if production else None
    runtime = runtime or (configure_server(store) if production else Runtime())
    inference_lock = RLock()
    session_token = secrets.token_urlsafe(32)
    local_owner = "local" if "local" in client_keys else "workbench"
    app = FastAPI(title="KeepFit 饮食服务", version="0.3.0", docs_url=None if production else "/docs", redoc_url=None if production else "/redoc", openapi_url=None if production else "/openapi.json", description="KeepFit 可视化饮食模型工作台：真实模型接入、补问、纠正、规则调教与确认保存。",
                  responses={code: {"model": ErrorEnvelope} for code in (401, 404, 409, 413, 422, 429, 502, 503, 504)})
    app.add_middleware(BodyLimit)
    hosts = os.environ.get("KEEPFIT_ALLOWED_HOSTS", "127.0.0.1,localhost,testserver").split(",")
    if production and ("*" in hosts or hosts == ["127.0.0.1", "localhost", "testserver"]):
        raise ValueError("Production requires an explicit hostname")
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=hosts)
    bearer = HTTPBearer(auto_error=False)

    @app.exception_handler(ServiceError)
    async def service_error(request: Request, exc: ServiceError):
        return JSONResponse(status_code=exc.status, content={"error": {"code": exc.code, "message": exc.message}})

    @app.exception_handler(RequestValidationError)
    async def validation_error(request: Request, exc: RequestValidationError):
        # Do not echo potentially private transcripts, image bytes or other request values.
        return JSONResponse(status_code=422, content={"error": {"code": "invalid_request", "message": "请求格式不符合接口约定。", "fields": [{"location": list(e["loc"]), "type": e["type"]} for e in exc.errors()]}})

    def owner(request: Request, credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        if credentials and credentials.scheme.lower() == "bearer":
            if apple_auth:
                identity = apple_auth.owner(credentials.credentials)
                if identity:
                    return identity
            for client_id, token in client_keys.items():
                if secrets.compare_digest(credentials.credentials.encode(), token.encode()):
                    return client_id
        cookie = request.cookies.get("keepfit_session", "")
        if not production and cookie and secrets.compare_digest(cookie, session_token):
            if request.method not in {"GET", "HEAD"} and request.headers.get("origin") != str(request.base_url).rstrip("/"):
                raise ServiceError("invalid_origin", "请从本机工作台页面操作。", 403)
            return local_owner
        raise ServiceError("unauthorized", "需要有效的调用方 Bearer token。", 401)

    def key(value: Annotated[str, Header(alias="Idempotency-Key", min_length=8, max_length=128)]):
        if not value.isascii() or any(c.isspace() for c in value):
            raise ServiceError("invalid_idempotency_key", "Idempotency-Key 需为不含空格的 ASCII 字符。")
        return value

    def require_provider(client, simulated=False):
        if simulated and provider is not None:
            return provider
        if runtime.status(client)["connected"]:
            return runtime.provider(client, profile(store, client), examples(store, client))
        if provider is not None:
            return provider
        raise ServiceError("provider_not_configured", "饮食识别服务正在准备中，请稍后再试。" if production else "请先在工作台的“连接模型”中填写密钥，再开始真实试用。", 503)

    def load_draft(db, client, id, expected_revision):
        draft = Intake.model_validate(store.get(db, client, "intake", id))
        if draft.status == "confirmed":
            raise ServiceError("already_confirmed", "该草稿已确认，不能再次修改或入账。", 409)
        if draft.revision != expected_revision:
            raise ServiceError("revision_conflict", "草稿已变化，请重新读取后再确认。", 409)
        return draft

    @app.get("/health")
    def health():
        return {"app": "keepfit-workbench", "status": "ok", "version": "0.3.0", "provider_ready": bool(runtime.read_key()) if production else provider is not None, "local_prototype": not production}

    @app.get("/v1/capabilities")
    def capabilities(client: str = Depends(owner)):
        connected = runtime.status(client)["connected"]
        return {"model": "keepfit-v1", "runtime": "cloud" if connected else "offline-demo" if provider else "unconfigured",
                "inputs": ["text", "voice_transcript", "photo"], "audio_transcription": False,
                "real_image_recognition": connected, "general_text_understanding": connected,
                "paid_api_calls": connected, "connection": runtime.status(client)}

    @app.get("/v1/demo/fixtures", include_in_schema=not production)
    def fixtures(client: str = Depends(owner)):
        if production:
            raise ServiceError("not_found", "接口不存在。", 404)
        return {"simulated": True, "fixtures": [{"id": k, "text": v, "source": "photo" if k == "photo_shared" else "text or voice"} for k, v in FIXTURES.items()]}

    @app.post("/v1/intakes", response_model=Intake, status_code=201)
    def create_intake(body: IntakeInput, client: str = Depends(owner), request_key: str = Depends(key)):
        payload = body.model_dump(mode="json")
        with inference_lock:
            with store.transaction() as db:
                replay = store.replay(db, client, "create", request_key, payload)
                if replay is not None:
                    return replay
            model = require_provider(client)
            understood = model.understand(body, {})
            now = datetime.now(timezone.utc)
            result = Intake(id=str(uuid4()), revision=1, source=body.source, reference_time=body.reference_time,
                            timezone=body.timezone, created_at=now, updated_at=now,
                            original_text=body.text or body.transcript or understood.normalized_text,
                            model=model.provenance, demo_fixture=body.demo_fixture, **calculate(understood))
            saved = result.model_dump(mode="json")
            with store.transaction() as db:
                store.put(db, client, "intake", saved)
                store.remember(db, client, "create", request_key, payload, saved)
            return result

    @app.get("/v1/intakes/{intake_id}", response_model=Intake)
    def get_intake(intake_id: str, client: str = Depends(owner)):
        with store.transaction() as db:
            return store.get(db, client, "intake", intake_id)

    def update_intake(intake_id, expected_revision, answers, client, request_key, payload, correction=False):
        scope = ("revise:" if correction else "answer:") + intake_id
        with inference_lock:
            with store.transaction() as db:
                replay = store.replay(db, client, scope, request_key, payload)
                if replay is not None:
                    return replay
                draft = load_draft(db, client, intake_id, expected_revision)
            if draft.revision >= 20:
                raise ServiceError("revision_limit", "这餐已调整20次，请重新开始一餐。", 409)
            if not correction and not set(answers).issubset({q.id for q in draft.understanding.questions}):
                raise ServiceError("unknown_question", "回答必须指向当前草稿中的问题。")
            model = require_provider(client, draft.model.simulated)
            if model.provenance.provider != draft.model.provider or model.provenance.simulated != draft.model.simulated:
                raise ServiceError("provider_changed", "这餐的模型连接已变化，请重新识别，避免混用结果。", 409)
            history = draft.answer_history + [answers]
            merged = {k: v for entry in history for k, v in entry.items()}
            if draft.model.simulated:
                request = IntakeInput(source=draft.source, text=draft.original_text if draft.source == "text" else None,
                                      transcript=draft.original_text if draft.source == "voice" else None,
                                      demo_fixture=draft.demo_fixture, reference_time=draft.reference_time, timezone=draft.timezone)
            else:
                # Follow-ups use saved observations; original images are not retained or re-uploaded.
                request = IntakeInput(source="text", text=draft.original_text, reference_time=draft.reference_time, timezone=draft.timezone)
            updates = calculate(model.understand(request, merged, previous=draft.understanding))
            result = Intake.model_validate({**draft.model_dump(), **updates, "revision": draft.revision + 1,
                                           "updated_at": datetime.now(timezone.utc), "answer_history": history, "model": model.provenance})
            saved = result.model_dump(mode="json")
            with store.transaction() as db:
                load_draft(db, client, intake_id, expected_revision)
                store.put(db, client, "intake", saved)
                store.remember(db, client, scope, request_key, payload, saved)
            return result

    @app.post("/v1/intakes/{intake_id}/answers", response_model=Intake)
    def answer_intake(intake_id: str, body: AnswerInput, client: str = Depends(owner), request_key: str = Depends(key)):
        return update_intake(intake_id, body.expected_revision, body.answers, client, request_key, body.model_dump(mode="json"))

    class ReviseInput(StrictModel):
        expected_revision: int = Field(ge=1)
        correction: str = Field(min_length=1, max_length=1200)

    @app.post("/v1/intakes/{intake_id}/revise", response_model=Intake)
    def revise(intake_id: str, body: ReviseInput, client: str = Depends(owner), request_key: str = Depends(key)):
        return update_intake(intake_id, body.expected_revision, {f"correction_{body.expected_revision}": body.correction},
                             client, request_key, body.model_dump(mode="json"), correction=True)

    @app.post("/v1/intakes/{intake_id}/confirm", response_model=Record, status_code=201)
    def confirm_intake(intake_id: str, body: ConfirmInput, client: str = Depends(owner), request_key: str = Depends(key)):
        payload, scope = body.model_dump(mode="json"), f"confirm:{intake_id}"
        with store.transaction() as db:
            replay = store.replay(db, client, scope, request_key, payload)
            if replay is not None:
                return replay
            draft = load_draft(db, client, intake_id, body.expected_revision)
            if draft.status != "ready_for_confirmation":
                raise ServiceError("clarification_required", "请先补充尚未明确的信息。", 409)
            if draft.requires_estimate_acceptance and not body.accept_estimates:
                raise ServiceError("estimate_acceptance_required", "请明确接受已展示的估算依据后再确认。", 409)
            now, record_id = datetime.now(timezone.utc), str(uuid4())
            draft.status, draft.record_id, draft.updated_at = "confirmed", record_id, now
            draft.revision += 1
            record = Record(id=record_id, intake_id=intake_id, confirmed_at=now, accepted_estimates=body.accept_estimates, snapshot=draft)
            saved = record.model_dump(mode="json")
            store.put(db, client, "intake", draft.model_dump(mode="json"))
            store.put(db, client, "record", saved)
            store.remember(db, client, scope, request_key, payload, saved)
            return record

    @app.get("/v1/records/{record_id}", response_model=Record)
    def get_record(record_id: str, client: str = Depends(owner)):
        with store.transaction() as db:
            return store.get(db, client, "record", record_id)

    if production:
        @app.post("/v1/auth/challenge")
        def auth_challenge(request: Request):
            return apple_auth.challenge(request.client.host)

        @app.post("/v1/auth/apple")
        def auth_apple(body: AppleLogin, request: Request):
            return apple_auth.login(body, request.client.host)

        @app.delete("/v1/account", status_code=204)
        def delete_account(client: str = Depends(owner)):
            with inference_lock, store.transaction() as db:
                db.execute("DELETE FROM objects WHERE owner=? AND kind!='quota'", (client,))
                db.execute("DELETE FROM replays WHERE owner=?", (client,))
                db.execute("DELETE FROM objects WHERE kind='session' AND json_extract(body,'$.owner')=?", (client,))
    else:
        install_workbench(app, owner, store, runtime, session_token, local_owner)
    return app
