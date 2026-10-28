"""Source-backed exact food matching and transparent, versioned recipe assumptions."""
import json
from pathlib import Path
from .schemas import Nutrients, Understanding

CATALOG = json.loads((Path(__file__).with_name('data') / 'usda.json').read_text())
VERSION = CATALOG['version'] + '+recipes-1'
FOODS = {f['name']: f for f in CATALOG['foods']}
# Ingredient weights and final cooked yields are explicit KeepFit assumptions, NOT USDA recipes.
RECIPES = [
    ('番茄炒蛋', ['西红柿炒鸡蛋','西红柿炒蛋','番茄炒鸡蛋'], {'番茄':300,'生鸡蛋':150,'大豆油':15,'白砂糖':5}, 400),
    ('蛋炒饭', ['鸡蛋炒饭'], {'熟白米饭':250,'生鸡蛋':50,'大豆油':10,'酱油':5}, 300),
    ('红烧肉', [], {'生五花肉':500,'酱油':30,'白砂糖':20}, 450),
    ('清炒小白菜', [], {'生小白菜':300,'大豆油':12}, 240),
    ('炒大白菜', ['清炒大白菜'], {'生大白菜':300,'大豆油':12}, 250),
    ('番茄鸡蛋汤', ['西红柿蛋汤','番茄蛋汤'], {'番茄':200,'生鸡蛋':100,'大豆油':5}, 900),
    ('红烧豆腐', [], {'生普通豆腐':300,'大豆油':12,'酱油':15,'白砂糖':5}, 330),
    ('洋葱炒牛肉末', [], {'生牛肉末（10%脂肪）':200,'生洋葱':150,'大豆油':10,'酱油':10}, 310),
]
MATCHES = {}
for f in CATALOG['foods']:
    entry = {**f, 'basis':'food_database', 'note':'USDA SR Legacy 2018 的对应食物参考值；实际品种、含水量可不同。'}
    for name in [f['name'], *f['aliases']]: MATCHES[name] = entry
for name, aliases, ingredients, cooked in RECIPES:
    values = {key: round(sum(FOODS[n]['nutrients_per_100g'][key]*g/100 for n,g in ingredients.items())*100/cooked,4)
              for key in Nutrients.model_fields}
    entry = {'id':'recipe:'+name,'name':name,'basis':'recipe_estimate','nutrients_per_100g':values,
             'url':None,'source_description':'KeepFit 常见配方假设 v1',
             'note':'配方估算：'+ '、'.join(f'{n}{g}g' for n,g in ingredients.items()) + f'；假设成品{cooked}g，食用油全部计入。不是餐馆实测配方。',
             'ingredients':[{'name':n,'grams':g,'source_id':FOODS[n]['id'],'url':FOODS[n]['url']} for n,g in ingredients.items()]}
    for alias in [name,*aliases]: MATCHES[alias]=entry


def catalog_hint():
    # The model may use exact names only when they describe the user's actual dish.
    return '可核验食物/配方名（不要将不同做法、生熟、品牌食品强行改名匹配）：'+ '、'.join(MATCHES)


def ground(understanding: Understanding, allow_estimates=True):
    data=understanding.model_copy(deep=True)
    for item in data.items:
        # Never accept the model claiming it looked up a source or a recipe.
        item.nutrition_source=None
        if item.nutrition_basis not in {'unknown','model_estimate'}:
            item.nutrition_basis='model_estimate' if item.nutrients_per_100g else 'unknown'
        match=MATCHES.get(item.name.strip())
        if match:
            item.nutrients_per_100g=Nutrients(**match['nutrients_per_100g'])
            item.nutrition_basis=match['basis']
            item.nutrition_source={'id':match['id'],'name':match['source_description'], 'url':match['url'],
                                   'version':VERSION,'note':match['note'], 'ingredients':match.get('ingredients',[])}
            item.estimation_notes=[match['note'], *item.estimation_notes[:10]]
        elif item.nutrients_per_100g:
            item.estimation_notes=['未命中核验数据：本项营养由模型估算。',*item.estimation_notes[:10]]
        if not allow_estimates and (item.portion_is_estimate or item.nutrition_basis in {'model_estimate','recipe_estimate'}):
            if item.portion_is_estimate: item.consumed_grams=None
            if item.nutrition_basis in {'model_estimate','recipe_estimate'}:
                item.nutrients_per_100g=None; item.nutrition_basis='unknown'; item.nutrition_source=None
    return Understanding.model_validate(data.model_dump())
