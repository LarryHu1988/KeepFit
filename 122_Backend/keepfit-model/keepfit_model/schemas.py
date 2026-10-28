from __future__ import annotations

import base64
import binascii
from datetime import datetime
from typing import Annotated, Literal
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from pydantic import BaseModel, ConfigDict, Field, model_validator, field_validator


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid", allow_inf_nan=False, str_strip_whitespace=True)


class ImageInput(StrictModel):
    mime_type: Literal["image/jpeg", "image/png"]
    base64_data: str = Field(min_length=8, max_length=5_600_000)

    @model_validator(mode="after")
    def validate_bytes(self):
        try:
            data = base64.b64decode(self.base64_data, validate=True)
        except (ValueError, binascii.Error) as exc:
            raise ValueError("图片必须为有效 base64") from exc
        prefix = b"\xff\xd8\xff" if self.mime_type == "image/jpeg" else b"\x89PNG\r\n\x1a\n"
        if not data.startswith(prefix) or len(data) > 4 * 1024 * 1024:
            raise ValueError("图片类型不匹配，或超过 4 MiB")
        # Decode the actual pixels, bound dimensions, strip metadata and normalize before any model call.
        from io import BytesIO
        from PIL import Image, ImageOps, UnidentifiedImageError
        try:
            with Image.open(BytesIO(data)) as image:
                if image.format != ("JPEG" if self.mime_type == "image/jpeg" else "PNG") or image.width * image.height > 12_000_000:
                    raise ValueError("图片格式无效或像素过大")
                image.load()
                normalized = ImageOps.exif_transpose(image).convert("RGB")
                normalized.thumbnail((1600, 1600))
                output = BytesIO()
                normalized.save(output, format="JPEG", quality=85)
                self.mime_type = "image/jpeg"
                self.base64_data = base64.b64encode(output.getvalue()).decode("ascii")
        except (OSError, UnidentifiedImageError, Image.DecompressionBombError) as exc:
            raise ValueError("图片无法解码") from exc
        return self


class IntakeInput(StrictModel):
    source: Literal["text", "voice", "photo"]
    text: str | None = Field(default=None, min_length=1, max_length=8000)
    transcript: str | None = Field(default=None, min_length=1, max_length=8000)
    image: ImageInput | None = None
    demo_fixture: str | None = Field(default=None, min_length=1, max_length=80)
    reference_time: datetime
    timezone: str = "Asia/Shanghai"

    @field_validator("reference_time")
    @classmethod
    def aware_time(cls, value):
        if value.tzinfo is None:
            raise ValueError("reference_time 必须包含时区偏移")
        return value

    @field_validator("timezone")
    @classmethod
    def valid_zone(cls, value):
        try:
            ZoneInfo(value)
        except (ZoneInfoNotFoundError, ValueError) as exc:
            raise ValueError("需要有效的 IANA 时区") from exc
        return value

    @model_validator(mode="after")
    def validate_source(self):
        if self.source == "text" and (not self.text or self.transcript or self.image):
            raise ValueError("text 入口需要 text，不能携带音频转写或图片")
        if self.source == "voice" and (not self.transcript or self.text or self.image) and not self.demo_fixture:
            raise ValueError("voice 首版需要 transcript；暂未内置音频转写")
        if self.source == "voice" and (self.text or self.image):
            raise ValueError("voice 入口只接受 transcript")
        if self.source == "photo" and (self.transcript or (not self.image and not self.demo_fixture)):
            raise ValueError("photo 入口需要 image，可附加 text 说明")
        return self


Nonnegative = Annotated[float, Field(ge=0)]


class Nutrients(StrictModel):
    calories_kcal: Nonnegative
    protein_g: Nonnegative
    fat_g: Nonnegative
    carbs_g: Nonnegative


class FoodObservation(StrictModel):
    id: str = Field(min_length=1, max_length=80)
    name: str = Field(min_length=1, max_length=200)
    original_portion: str = Field(min_length=1, max_length=500)
    eater: Literal["self", "other", "unknown"]
    consumption: Literal["eaten", "not_eaten", "unknown"]
    # Components describe a dish; only top-level items contribute to totals.
    parent_id: str | None = None
    consumed_grams: float | None = Field(default=None, gt=0, le=10000)
    portion_is_estimate: bool = False
    nutrition_basis: Literal["model_estimate", "demo_fixture", "food_database", "recipe_estimate", "unknown"] = "unknown"
    nutrition_source: dict | None = None
    nutrients_per_100g: Nutrients | None = None
    estimation_notes: list[str] = Field(default_factory=list, max_length=12)

    @model_validator(mode="after")
    def validate_basis(self):
        if (self.nutrition_basis == "unknown") != (self.nutrients_per_100g is None):
            raise ValueError("未知营养必须为 null；已给营养值必须声明来源")
        if self.nutrients_per_100g:
            n = self.nutrients_per_100g
            if n.protein_g + n.fat_g + n.carbs_g > 105 or n.calories_kcal > 1000:
                raise ValueError("每100g营养值超出合理物理范围")
        if (self.portion_is_estimate or self.nutrition_basis != "unknown") and not self.estimation_notes:
            raise ValueError("估算份量和营养来源需要说明")
        return self


class Question(StrictModel):
    id: str = Field(min_length=1, max_length=100)
    text: str = Field(min_length=1, max_length=600)
    item_ids: list[str] = Field(default_factory=list, max_length=30)
    options: list[str] = Field(default_factory=list, max_length=8)


class Understanding(StrictModel):
    meal_time: datetime | None = None
    meal_time_note: str = Field(min_length=1, max_length=500)
    normalized_text: str = Field(min_length=1, max_length=8000)
    items: list[FoodObservation] = Field(min_length=1, max_length=30)
    questions: list[Question] = Field(default_factory=list, max_length=30)
    warnings: list[str] = Field(default_factory=list, max_length=20)

    @model_validator(mode="after")
    def validate_relations(self):
        if self.meal_time and self.meal_time.tzinfo is None:
            raise ValueError("meal_time 必须包含时区")
        ids = [item.id for item in self.items]
        if len(set(ids)) != len(ids):
            raise ValueError("食物 id 不得重复")
        by_id = {item.id: item for item in self.items}
        for item in self.items:
            if item.parent_id:
                parent = by_id.get(item.parent_id)
                if not parent or parent.id == item.id or parent.parent_id:
                    raise ValueError("只允许一级成品菜及其组成部分")
        qids = [q.id for q in self.questions]
        if len(set(qids)) != len(qids) or any(i not in by_id for q in self.questions for i in q.item_ids):
            raise ValueError("问题 id 不得重复，且必须指向存在的食物")
        return self


class FoodResult(FoodObservation):
    included_in_totals: bool
    nutrients: Nutrients | None


class ModelProvenance(StrictModel):
    name: str = "keepfit-v1"
    schema_version: str = "1.0"
    prompt_version: str = "2026-10-22.1"
    provider: Literal["demo", "deepseek", "mimo"]
    base_model: str
    simulated: bool
    nutrition_version: str = "model-estimates-v1"


class Intake(StrictModel):
    id: str
    revision: int
    status: Literal["needs_clarification", "ready_for_confirmation", "confirmed"]
    source: Literal["text", "voice", "photo"]
    reference_time: datetime
    timezone: str
    created_at: datetime
    updated_at: datetime
    original_text: str
    understanding: Understanding
    items: list[FoodResult]
    totals: Nutrients | None
    known_subtotal: Nutrients
    totals_complete: bool
    requires_estimate_acceptance: bool
    model: ModelProvenance
    record_id: str | None = None
    answer_history: list[dict[str, str]] = Field(default_factory=list)
    demo_fixture: str | None = None


class AnswerInput(StrictModel):
    expected_revision: int = Field(ge=1)
    answers: dict[str, str] = Field(min_length=1, max_length=30)

    @field_validator("answers")
    @classmethod
    def nonempty_answers(cls, value):
        if any(not k or not v.strip() or len(k) > 100 or len(v) > 2000 for k, v in value.items()):
            raise ValueError("每个回答应为 1–2000 字")
        return {k: v.strip() for k, v in value.items()}


class ConfirmInput(StrictModel):
    expected_revision: int = Field(ge=1)
    accept_estimates: bool = False


class Record(StrictModel):
    id: str
    intake_id: str
    confirmed_at: datetime
    accepted_estimates: bool
    snapshot: Intake


class ErrorField(StrictModel):
    location: list[str | int]
    type: str


class ErrorDetail(StrictModel):
    code: str
    message: str
    fields: list[ErrorField] | None = None


class ErrorEnvelope(StrictModel):
    error: ErrorDetail
