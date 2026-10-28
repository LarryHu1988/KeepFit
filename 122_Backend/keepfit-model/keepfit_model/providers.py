"""Provider boundary. The delivered runtime is intentionally local and offline."""
from datetime import timedelta
from typing import Protocol
from zoneinfo import ZoneInfo

from .schemas import IntakeInput, ModelProvenance, Understanding


class ServiceError(Exception):
    def __init__(self, code: str, message: str, status: int = 422):
        self.code, self.message, self.status = code, message, status


class UnderstandingProvider(Protocol):
    provenance: ModelProvenance

    def understand(self, request: IntakeInput, answers: dict[str, str], previous: Understanding | None = None) -> Understanding: ...


FIXTURES = {
    "breakfast": "早餐两个鸡蛋、一杯牛奶",
    "shared_dish": "四个人吃一盘红烧肉，我吃了三块",
    "negation": "没吃米饭，吃了八个水饺",
    "correction": "两个包子，不对，是一个半",
    "leftovers": "吃一碗面，还剩半碗",
    "yesterday": "昨天晚上半碗粥",
    "photo_shared": "照片中有一盘番茄炒蛋，不确定本人吃了多少",
}


def food(id, name, portion, grams, values, **extra):
    # These are synthetic contract-test values, NOT a nutritional reference database.
    return dict(
        id=id, name=name, original_portion=portion, eater="self", consumption="eaten",
        consumed_grams=grams, portion_is_estimate=True, nutrition_basis="demo_fixture",
        nutrients_per_100g=dict(zip(("calories_kcal", "protein_g", "fat_g", "carbs_g"), values)),
        estimation_notes=["仅用于本地流程演示的合成营养和份量值，不作为实际饮食建议。"], **extra,
    )


class DemoProvider:
    provenance = ModelProvenance(provider="demo", base_model="deterministic-fixtures", simulated=True, nutrition_version="synthetic-fixtures-v1")

    def understand(self, request: IntakeInput, answers: dict[str, str], previous: Understanding | None = None) -> Understanding:
        phrase = request.text or request.transcript or ""
        fixture = request.demo_fixture or next((k for k, v in FIXTURES.items() if v == phrase), None)
        if fixture not in FIXTURES:
            raise ServiceError("demo_fixture_required", "本地演示只支持 /v1/demo/fixtures 列出的案例；尚未连接通用文字识别模型。")
        if phrase and phrase != FIXTURES[fixture]:
            raise ServiceError("fixture_text_mismatch", "演示案例与输入文字不一致，不能用演示结果冒充识别结果。")
        if request.image:
            raise ServiceError("demo_image_unsupported", "本地演示不分析真实照片；请选择 photo_shared 演示案例，不上传图片。")
        if fixture == "photo_shared" and request.source != "photo":
            raise ServiceError("fixture_source_mismatch", "photo_shared 是图片流程案例。")
        if request.source == "photo" and fixture != "photo_shared":
            raise ServiceError("fixture_source_mismatch", "图片流程请使用 photo_shared。")
        questions = []
        time = request.reference_time.astimezone(ZoneInfo(request.timezone))
        if fixture == "breakfast":
            size = answers.get("milk_size")
            sizes = {"小杯（150ml）": 150, "普通杯（250ml）": 250, "大杯（300ml）": 300}
            if size and size not in sizes:
                raise ServiceError("demo_answer_unsupported", "演示仅接受给定杯型选项；自由回答留给后续模型适配器。")
            items = [food("eggs", "鸡蛋", "2个", 100, (150, 12, 10, 1)),
                     food("milk", "牛奶", size or "一杯，杯型待确认", sizes.get(size), (60, 3, 3, 5))]
            if not size:
                questions = [dict(id="milk_size", text="这杯牛奶大约多大？", item_ids=["milk"], options=list(sizes))]
            items[1]["estimation_notes"].append("演示为算术测试暂设 1ml=1g；正式服务需使用该食品的密度或每100ml标签。")
        elif fixture == "shared_dish":
            items = [food("pork", "红烧肉", "本人3块，未按4人均分", 75, (400, 15, 35, 6))]
        elif fixture == "negation":
            rice = food("rice", "米饭", "没有吃", None, (120, 3, 0.5, 26))
            rice["consumption"] = "not_eaten"
            items = [rice, food("dumplings", "水饺", "8个", 160, (200, 8, 8, 24))]
        elif fixture == "correction":
            items = [food("bao", "包子", "1.5个，已撤销最初的2个", 120, (230, 8, 7, 34))]
        elif fixture == "leftovers":
            items = [food("noodles", "面", "一碗剩半碗，实际吃半碗", 150, (140, 5, 2, 25))]
        elif fixture == "yesterday":
            time = (time - timedelta(days=1)).replace(hour=19, minute=0, second=0, microsecond=0)
            items = [food("porridge", "粥", "半碗", 125, (45, 1, 0.2, 10))]
        else:
            portion = answers.get("my_portion")
            options = {"我吃了半盘": 150, "我吃了四分之一盘": 75}
            if portion and portion not in options:
                raise ServiceError("demo_answer_unsupported", "演示仅接受给定分食选项。")
            item = food("dish", "番茄炒蛋", portion or "全盘可见，本人食用量未知", options.get(portion), (140, 7, 10, 5))
            if not portion:
                item["eater"], item["consumption"] = "unknown", "unknown"
                questions = [dict(id="my_portion", text="这盘菜你本人吃了多少？", item_ids=["dish"], options=list(options))]
            items = [item]
        return Understanding.model_validate(dict(
            meal_time=time, meal_time_note="演示以 reference_time 为准；昨天案例使用当地前一天19点，确认前可审阅。",
            normalized_text=FIXTURES[fixture], items=items, questions=questions,
            warnings=["这是固定案例演示，没有调用 AI，没有识别真实音频或照片。"],
        ))
