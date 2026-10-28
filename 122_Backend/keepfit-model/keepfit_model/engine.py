"""Deterministic nutrition arithmetic and confirmation prerequisites."""
from decimal import Decimal, ROUND_HALF_UP

from .schemas import FoodResult, Nutrients, Question, Understanding


def calculate(understanding: Understanding):
    data = understanding.model_copy(deep=True)
    questions = list(data.questions)
    covered = {i for q in questions for i in q.item_ids}
    subtotal = {k: Decimal(0) for k in Nutrients.model_fields}
    complete, has_food, estimated = True, False, False
    results = []
    for item in data.items:
        included = not item.parent_id and item.eater == "self" and item.consumption == "eaten"
        nutrients = None
        reason = None
        if not item.parent_id and item.eater != "other" and item.consumption != "not_eaten":
            if item.eater == "unknown" or item.consumption == "unknown":
                reason = f"{item.name}是你本人实际吃下的食物吗？"
            elif item.consumed_grams is None:
                reason = f"{item.name}实际吃了多少？可以用个数、半碗或一份的比例描述。"
            elif item.nutrients_per_100g is None:
                reason = f"{item.name}还缺少营养依据，请补充做法或包装标签；目前不能按零摄入计算。"
        if reason:
            complete = False
            if item.id not in covered:
                questions.append(Question(id=f"missing_{item.id}", text=reason, item_ids=[item.id]))
        if included:
            has_food = True
            if item.consumed_grams is not None and item.nutrients_per_100g is not None:
                values = {
                    k: Decimal(str(v)) * Decimal(str(item.consumed_grams)) / Decimal(100)
                    for k, v in item.nutrients_per_100g.model_dump().items()
                }
                for k, value in values.items():
                    subtotal[k] += value
                nutrients = Nutrients(**{k: float(v.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)) for k, v in values.items()})
            estimated |= item.portion_is_estimate or item.nutrition_basis in {"model_estimate", "demo_fixture", "recipe_estimate"}
        results.append(FoodResult(**item.model_dump(), included_in_totals=included, nutrients=nutrients))
    if not has_food:
        complete = False
        if not questions:
            questions.append(Question(id="meal", text="请补充你本人实际吃下的食物。"))
    if data.meal_time is None and not any(q.id == "meal_time" for q in questions):
        questions.append(Question(id="meal_time", text="这餐是什么时候吃的？"))
    data.questions = questions
    known = Nutrients(**{k: float(v.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)) for k, v in subtotal.items()})
    return dict(
        understanding=data, items=results,
        totals=known if complete else None, known_subtotal=known,
        totals_complete=complete, requires_estimate_acceptance=estimated,
        status="ready_for_confirmation" if complete and not questions else "needs_clarification",
    )
