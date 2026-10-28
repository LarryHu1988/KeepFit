from pathlib import Path
from PIL import Image,ImageStat,ImageChops,ImageDraw
from io import BytesIO
from concurrent.futures import ThreadPoolExecutor
import subprocess,json
R=Path(__file__).resolve().parents[1];OUT=R/'07_Validation/ReviewSheets';OUT.mkdir(exist_ok=True)
def frame(p,t):
 return Image.open(BytesIO(subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-ss',str(t),'-i',str(p),'-frames:v','1','-vf','scale=240:240:force_original_aspect_ratio=decrease','-f','image2pipe','-vcodec','png','-threads','1','-']))).convert('RGB')
def inspect(p):
 times=[0,2,4,8,12,16,21,25,27];ims=[frame(p,t)for t in times];sheet=Image.new('RGB',(9*250,280),'#e9eef1');draw=ImageDraw.Draw(sheet)
 for i,(im,t)in enumerate(zip(ims,times)):sheet.paste(im,(i*250,25));draw.text((i*250+8,5),str(t)+'s',fill='black')
 sheet.save(OUT/(p.parent.name+'-'+p.stem+'-frames.jpg'),quality=92)
 diff=lambda a,b:sum(ImageStat.Stat(ImageChops.difference(a,b)).mean)/3
 measurements={'file':str(p.relative_to(R)),'coverHoldDifference':diff(ims[0],ims[1]),'eatMotion':diff(ims[2],ims[3]),'moveMotion':diff(ims[4],ims[5]),'loseMotion':diff(ims[6],ims[7]),'minFrameBrightness':min(sum(ImageStat.Stat(im).mean)/3 for im in ims)}
 measurements['pass']=measurements['coverHoldDifference']<.1 and measurements['minFrameBrightness']>30 and all(measurements[k]>.1 for k in ['eatMotion','moveMotion','loseMotion'])
 return measurements
with ThreadPoolExecutor(max_workers=2)as pool:rows=list(pool.map(inspect,sorted((R/'02_Previews').rglob('*.mp4'))))
(R/'07_Validation/video-frame-check.json').write_text(json.dumps(rows,indent=2));print(json.dumps(rows,indent=2));raise SystemExit(any(not r['pass']for r in rows))
