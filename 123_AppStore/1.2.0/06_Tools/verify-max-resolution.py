import json,struct,hashlib,datetime
from pathlib import Path
r=Path(__file__).resolve().parent.parent;o=r/'08_AppStoreConnect';a=json.loads((o/'asset-reference-data.json').read_text())['data'][0]['attributes'];specs={x['specId']:x for x in a['imageSpecs']};mapping={x['placementGroupId']:x['specs']for x in next(x for x in a['placementTypes']if x['placementTypeId']=='APP_SCREENSHOT')['specMappings']};plan=json.loads((o/'upload-plan.json').read_text());report={'at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'source':'Apple live appAssetLibraryRefData API','groups':[],'creatives':[],'allFinalImages':[]}
def png(p):
 b=p.read_bytes();w,h,depth,color=struct.unpack('>IIBB',b[16:26]);return {'width':w,'height':h,'bitDepth':depth,'colorType':color,'bytes':len(b),'md5':hashlib.md5(b).hexdigest()}
for j in plan['jobs']:
 allowed=[specs[s]['dimensions']for s in mapping[j['placementGroup']]];max_area=max(d['maxWidth']*d['maxHeight']for d in allowed);images=[]
 for im in j['screenshots']:
  d=png(r/im['file']);family='standard'
  if j['displayType']=='APP_IPHONE_DUO':
   family='outer'if d['width']*d['height']==1398*2034 else 'inner';max_area=(1398*2034 if family=='outer'else 2007*2853)
  good=any(d['width']==s['maxWidth'] and d['height']==s['maxHeight']for s in allowed)
  images.append({'file':im['file'],'family':family,**d,'highestAcceptedForDisplay':good and d['width']*d['height']==max_area,'sourceChecksumMatchesUploadPlan':d['md5']==im['md5']})
 report['groups'].append({'locale':j['locale'],'displayType':j['displayType'],'images':images})
for p in (r/'03_Creatives').rglob('*.png'):
 d=png(p);kind=p.name.split('-')[0];sid={'header':'1eb43b80-e0b7-4d96-bd32-47a42a8c5fed','search':'d2ffa3b7-6c55-5cdf-8512-229d92791333','universal':'c8f4e2b1-7a3d-5c9e-8b6f-2d1a0e9c8b7a'}[kind];s=specs[sid]['dimensions'];report['creatives'].append({'file':str(p.relative_to(r)),**d,'highestAcceptedForAspect':d['width']==s['maxWidth']and d['height']==s['maxHeight']})
for folder in ['01_Screenshots','03_Creatives']:
 for p in (r/folder).rglob('*.png'):report['allFinalImages'].append({'file':str(p.relative_to(r)),**png(p)})
report['uploadedScreenshotsAtMaximum']=all(im['highestAcceptedForDisplay']and im['sourceChecksumMatchesUploadPlan'] for g in report['groups']for im in g['images']);report['creativesAtMaximum']=all(im['highestAcceptedForAspect']for im in report['creatives']);report['allOpaqueRGB']=all(im['colorType']==2 and im['bitDepth']==8 for im in report['allFinalImages']);(o/'maximum-resolution-audit.json').write_text(json.dumps(report,indent=2,ensure_ascii=False));print(json.dumps({k:v for k,v in report.items()if k not in ['groups','creatives','allFinalImages']},ensure_ascii=False));print('uploaded screenshots',sum(len(g['images'])for g in report['groups']),'creatives',len(report['creatives']),'final PNGs',len(report['allFinalImages']));assert report['uploadedScreenshotsAtMaximum']and report['creativesAtMaximum']and report['allOpaqueRGB']
