from pathlib import Path
from PIL import Image,ImageStat
import json,subprocess,hashlib,collections
R=Path(__file__).resolve().parents[1]
rows=json.loads((R/'07_Validation/image-manifest.json').read_text());errors=[];counts=collections.Counter();images=[]
for r in rows:
 p=R/r['file']
 with Image.open(p)as im:
  ok=im.size==(r['width'],r['height'])and im.mode=='RGB'and p.suffix=='.png'
  if not ok:errors.append(str(p.relative_to(R)))
  images.append({'file':r['file'],'pixels':im.size,'mode':im.mode,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()});counts[r.get('kind','screenshot')]+=1
groups=collections.Counter((r['locale'],r['device'],r['key'])for r in rows if'slide'in r)
if len(groups)!=52 or any(n!=(4 if device in ['duo-inner-landscape','ipad']else 7)for (locale,device,key),n in groups.items()):errors.append('Expected 52 sets: iPad and Duo-inner-landscape have four; other sets have seven')
videos=[]
for p in sorted((R/'02_Previews').rglob('*.mp4')):
 info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(p)]));v=next(x for x in info['streams']if x['codec_type']=='video');a=next(x for x in info['streams']if x['codec_type']=='audio');duration=float(info['format']['duration'])
 ok=(v['codec_name']=='h264' and v['profile']=='High' and v['level']<=40 and v['r_frame_rate']=='30/1' and v['pix_fmt']=='yuv420p' and a['codec_name']=='aac' and a['sample_rate']=='48000' and a['channels']==2 and abs(duration-28)<.02 and abs(float(v['duration'])-28)<.02 and int(v.get('nb_frames',0))==840 and p.stat().st_size<500_000_000)
 if not ok:errors.append(str(p.relative_to(R)))
 videos.append({'file':str(p.relative_to(R)),'width':v['width'],'height':v['height'],'duration':duration,'codec':v['codec_name'],'profile':v['profile'],'level':v['level'],'fps':v['r_frame_rate'],'audioCodec':a['codec_name'],'audioSampleRate':a['sample_rate'],'audioChannels':a['channels'],'audioBitRate':a.get('bit_rate'),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'pass':ok})
if len(videos)!=14:errors.append('Expected 14 videos')
result={'status':'PASS'if not errors else'FAIL','errors':errors,'imageCounts':dict(counts),'screenshotSetCount':len(groups),'videos':videos,'images':images}
(R/'07_Validation/delivery-validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps({k:v for k,v in result.items()if k not in ['videos','images']},indent=2))
raise SystemExit(bool(errors))
