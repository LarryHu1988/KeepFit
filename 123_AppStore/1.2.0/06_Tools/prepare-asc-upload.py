from pathlib import Path
import json,hashlib,shutil
R=Path(__file__).resolve().parents[1];OUT=R/'08_AppStoreConnect';OUT.mkdir(exist_ok=True)
definitions=[
 ('APP_IPHONE_61','iphone','1206x2622',['iphone-modern'],'IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE'),
 ('APP_IPHONE_67','iphone','1320x2868',['iphone-modern'],'IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE'),
 ('APP_IPHONE_65','iphone','1284x2778',['iphone-modern'],'IPHONE_FACE_ID_LARGE_PROFILE'),
 ('APP_IPHONE_DUO','duo',None,['duo-outer','duo-inner'],'IPHONE_DUO_PROFILE'),
 ('APP_IPHONE_58','iphone','1170x2532',['iphone-modern'],'IPHONE_FACE_ID_MEDIUM_PROFILE'),
 ('APP_IPHONE_55','iphone','1242x2208',['iphone-home-large'],'IPHONE_HOME_BUTTON_LARGE_PROFILE'),
 ('APP_IPHONE_47','iphone','750x1334',['iphone-home-medium'],'IPHONE_HOME_BUTTON_MEDIUM_PROFILE'),
 ('APP_IPHONE_40','iphone','640x1136',['iphone-home-large'],'IPHONE_HOME_BUTTON_40_PROFILE'),
 ('APP_IPHONE_35','iphone','640x960',[],'IPHONE_HOME_BUTTON_35_PROFILE'),
 ('APP_IPAD_PRO_3GEN_129','ipad','2064x2752',['ipad'],'IPAD_13_PROFILE'),
 ('APP_IPAD_PRO_129','ipad','2048x2732',['ipad'],'IPAD_129_PROFILE'),
 ('APP_IPAD_PRO_3GEN_11','ipad','1668x2420',['ipad'],'IPAD_11_PROFILE'),
 ('APP_IPAD_105','ipad','1668x2224',['ipad'],'IPAD_105_PROFILE'),
 ('APP_IPAD_97','ipad','1536x2048',['ipad-legacy'],'IPAD_97_PROFILE'),
]
localizations=json.loads((OUT/'localizations-current.json').read_text())['data'];jobs=[]
for loc in localizations:
 locale=loc['attributes']['locale'];lang='en'if locale=='en-US'else locale
 for display,device,key,previews,profile in definitions:
  if device=='duo':
   # Ten placements maximum. Shared inner overview + outer six + inner three.
   sources=[R/f'01_Screenshots/{lang}/duo-inner-landscape/2853x2007/01.png']+[R/f'01_Screenshots/{lang}/duo-outer/1398x2034/{i:02}.png'for i in range(2,8)]+[R/f'01_Screenshots/{lang}/duo-inner-landscape/2853x2007/{i:02}.png'for i in range(2,5)]
   directory=OUT/'UploadPayloads'/locale/'DuoScreenshots';directory.mkdir(parents=True,exist_ok=True);files=[]
   for i,source in enumerate(sources,1):
    dest=directory/f'{i:02}-{source.parts[-3]}.png';shutil.copy2(source,dest);files.append(dest)
  else:directory=R/f'01_Screenshots/{lang}/{device}/{key}';files=sorted(directory.glob('*.png'))
  videos=[R/f'02_Previews/{lang}/{name}.mp4'for name in previews]
  def asset(p):return{'file':str(p.relative_to(R)),'bytes':p.stat().st_size,'md5':hashlib.md5(p.read_bytes()).hexdigest()}
  jobs.append({'locale':locale,'localizationId':loc['id'],'displayType':display,'placementGroup':profile,'screenshotDirectory':str(directory.resolve()),'screenshots':[asset(p)for p in files],'previews':[asset(p)for p in videos]})
plan={'appId':'6759662867','versionId':'e19a6cdf-d758-4c0a-8931-d44c583d646d','version':'1.2.0','buildId':'3a327c54-a3af-4177-a0ef-3e06fbc43d39','jobs':jobs,'screenshotCount':sum(len(j['screenshots'])for j in jobs),'previewPlacementCount':sum(len(j['previews'])for j in jobs),'duoSelection':'One shared inner overview; six outer-screen functions; three inner-screen functions, 10 total per localization.'}
assert plan['screenshotCount']==172 and plan['previewPlacementCount']==28
(OUT/'upload-plan.json').write_text(json.dumps(plan,ensure_ascii=False,indent=2));print('Upload plan:',plan['screenshotCount'],'screenshots,',plan['previewPlacementCount'],'preview placements in',len(jobs),'localized device sets')
