"""Reproducibly extract a small CC0 catalog from the official SR Legacy archive."""
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import zipfile

SOURCE = 'https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip'
# Exact USDA cooked/raw descriptions are retained; aliases never strip cooking methods.
SELECTED = {
'168878': ('熟白米饭', ['米饭', '白米饭', '熟米饭']),
'173424': ('水煮鸡蛋', ['煮鸡蛋', '白煮蛋', '水煮蛋']),
'171265': ('全脂牛奶', ['全脂纯牛奶']),
'172475': ('生硬豆腐', []), '172476': ('生普通豆腐', []),
'171411': ('大豆油', ['豆油']), '167812': ('生五花肉', []),
'174277': ('酱油', []), '169655': ('白砂糖', ['白糖']),
'168894': ('普通小麦面粉', ['中筋面粉']),
'169979': ('生大白菜', []), '170390': ('生小白菜', []),
'169967': ('水煮西兰花', ['白灼西兰花']),
'173944': ('香蕉', []), '168409': ('生黄瓜', ['黄瓜']),
'170000': ('生洋葱', []), '170440': ('去皮水煮土豆', []),
'174030': ('生牛肉末（10%脂肪）', []),
}

def main():
    archive=Path(sys.argv[1]); z=zipfile.ZipFile(archive)
    def rows(name):
        member=next(n for n in z.namelist() if n.endswith('/'+name))
        return csv.DictReader(io.TextIOWrapper(z.open(member)))
    foods={r['fdc_id']:r for r in rows('food.csv')}
    extra={'番茄':'Tomatoes, red, ripe, raw, year round average', '生鸡蛋':'Egg, whole, raw, fresh',
           '熟去皮鸡胸肉':'Chicken, broilers or fryers, breast, meat only, cooked, roasted',
           '苹果':"Apples, raw, with skin (Includes foods for USDA's Food Distribution Program)"}
    for zh, en in extra.items():
        matches=[i for i,f in foods.items() if f['description']==en]
        assert len(matches)==1,(zh,matches)
        SELECTED[matches[0]]=(zh, ['西红柿'] if zh=='番茄' else [])
    nutrients={i:{} for i in SELECTED}; keys={'1008':'calories_kcal','1003':'protein_g','1004':'fat_g','1005':'carbs_g'}
    for r in rows('food_nutrient.csv'):
        if r['fdc_id'] in SELECTED and r['nutrient_id'] in keys:
            nutrients[r['fdc_id']][keys[r['nutrient_id']]]=float(r['amount'])
    portions={i:[] for i in SELECTED}
    for r in rows('food_portion.csv'):
        if r['fdc_id'] in SELECTED:
            portions[r['fdc_id']].append({'amount':float(r['amount']), 'description':r['modifier'], 'grams':float(r['gram_weight'])})
    result=[]
    for id,(name,aliases) in SELECTED.items():
        assert len(nutrients[id])==4,id
        result.append({'id':'usda:'+id,'name':name,'aliases':aliases,'source_description':foods[id]['description'],
                       'nutrients_per_100g':nutrients[id],'portions':portions[id],
                       'url':'https://fdc.nal.usda.gov/food-details/'+id+'/nutrients'})
    out={'version':'usda-sr-2018-keepfit-2026-10-24','source':SOURCE,'license':'CC0-1.0',
         'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'foods':result}
    target=Path(__file__).resolve().parents[1]/'keepfit_model/data/usda.json'
    target.write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n')
    print('Imported',len(result),'foods with 4 sourced nutrients each')

if __name__=='__main__': main()
