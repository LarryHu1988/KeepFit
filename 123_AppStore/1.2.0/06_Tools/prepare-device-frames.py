"""Render genuine installed Xcode DeviceKit vector hardware at native scale."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageChops,ImageOps
import fitz,json,shutil,hashlib
R=Path(__file__).resolve().parents[1];OUT=R/'05_Sources/device-frames';OUT.mkdir(exist_ok=True)
CHROME=Path('/Library/Developer/DeviceKit/Chrome');SCALE=3
def raster(p,scale=SCALE):
 doc=fitz.open(p);pix=doc[0].get_pixmap(matrix=fitz.Matrix(scale,scale),alpha=True)
 return Image.frombytes('RGBA',(pix.width,pix.height),pix.samples)
def save_source(p,dst):
 dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(p,dst)
 return {'installedPath':str(p),'retainedSource':str(dst.relative_to(R)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
def nine_slice(root,config,w,h):
 canvas=Image.new('RGBA',(w*SCALE,h*SCALE));ims={k:raster(root/(config[k]+'.pdf'))for k in ['topLeft','top','topRight','right','bottomRight','bottom','bottomLeft','left']}
 tl,tr,bl,br=[ims[k]for k in ['topLeft','topRight','bottomLeft','bottomRight']]
 for k,box in [('top',(tl.width,0,w*SCALE-tr.width,ims['top'].height)),('bottom',(bl.width,h*SCALE-ims['bottom'].height,w*SCALE-br.width,h*SCALE)),('left',(0,tl.height,ims['left'].width,h*SCALE-bl.height)),('right',(w*SCALE-ims['right'].width,tr.height,w*SCALE,h*SCALE-br.height))]:
  im=ims[k].resize((box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS);canvas.alpha_composite(im,(box[0],box[1]))
 for im,xy in [(tl,(0,0)),(tr,(w*SCALE-tr.width,0)),(bl,(0,h*SCALE-bl.height)),(br,(w*SCALE-br.width,h*SCALE-br.height))]:canvas.alpha_composite(im,xy)
 return canvas
definitions=[
 ('iphone','phone12',(474,990),(17,17,440,956),'EB31C0E2-52E0-430E-B4DA-4242D2881AFF',False),
 ('iphone-se','phone',(431,889),(28,111,375,667),None,False),
 ('ipad','tablet5',(1124,1468),(46,46,1032,1376),'75FF89F9-07DA-41E1-B66E-9AC4AF726865',False),
 ('duo-outer','phone15',(514,706),(26,14,466,678),'1C896A2B-F0D7-405C-8D0F-66E4B80AD044',False),
 ('duo-inner-landscape','phone14',(660,924),(17,17,626,890),'BF0DC480-5EE2-4EC1-B02B-C75E94759832',True),
]
manifest={}
for source,chrome,(w,h),(x,y,sw,sh),mask,rotate in definitions:
 root=CHROME/(chrome+'.devicechrome')/'Contents/Resources';config=json.loads((root/'chrome.json').read_text())['images'];retained=OUT/'vectors'/source
 records=[save_source(root/'chrome.json',retained/'chrome.json')]
 composite=root/(config.get('composite','none')+'.pdf')
 if composite.exists():
  frame=raster(composite);records.append(save_source(composite,retained/composite.name))
 else:
  frame=nine_slice(root,config,w,h)
  for key in ['topLeft','top','topRight','right','bottomRight','bottom','bottomLeft','left']:
   p=root/(config[key]+'.pdf');records.append(save_source(p,retained/p.name))
 # Opaque black under the real aperture/camera cutouts. Keep original outer silhouette.
 if not composite.exists():ImageDraw.Draw(frame).rectangle((x*SCALE,y*SCALE,(x+sw)*SCALE-1,(y+sh)*SCALE-1),fill=(0,0,0,255))
 if source=='iphone-se':
  p=root/'Home BTN.pdf';button=raster(p);frame.alpha_composite(button,((w*SCALE-button.width)//2,h*SCALE-90*SCALE));records.append(save_source(p,retained/p.name))
 if mask:
  p=Path('/Library/Developer/DeviceKit/FramebufferMasks')/(mask+'.pdf');m=raster(p).getchannel('A').resize((sw*SCALE,sh*SCALE),Image.Resampling.LANCZOS);records.append(save_source(p,retained/'screen-mask.pdf'))
 else:m=Image.new('L',(sw*SCALE,sh*SCALE),255)
 visible=Image.new('L',frame.size);visible.paste(m,(x*SCALE,y*SCALE))
 if rotate:
  frame=frame.transpose(Image.Transpose.ROTATE_90);visible=visible.transpose(Image.Transpose.ROTATE_90)
  x,y,sw,sh=y,w-x-sw,sh,sw;w,h=h,w
 frame.save(OUT/(source+'-body.png'));visible.save(OUT/(source+'-aperture.png'));hole=Image.new('RGBA',frame.size,'white');hole.putalpha(visible);hole.save(OUT/(source+'-aperture-alpha.png'))
 manifest[source]={'chromeIdentifier':'com.apple.dt.devicekit.chrome.'+chrome,'bodyPixels':frame.size,'aperturePixels':[v*SCALE for v in [x,y,sw,sh]],'sources':records,'rotatedCounterClockwise':rotate}
 # Full hardware plus real UI, used by three-Tab overview/cover designs.
 for lang in ['zh-Hans','en']:
  for p in sorted((R/'05_Sources/screens'/source/lang).glob('*.png')):
   ui=Image.open(p).convert('RGBA');ui=ImageOps.contain(ui,(sw*SCALE,sh*SCALE),Image.Resampling.LANCZOS)
   layer=Image.new('RGBA',frame.size);layer.paste(ui,(x*SCALE+(sw*SCALE-ui.width)//2,y*SCALE+(sh*SCALE-ui.height)//2));layer.putalpha(visible);result=Image.alpha_composite(frame,layer)
   out=R/'05_Sources/framed-screens'/source/lang/p.name;out.parent.mkdir(parents=True,exist_ok=True);result.save(out)
(OUT/'frames.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
(OUT/'SOURCES.md').write_text('''# Hardware frames\n\nThese are the installed Apple Xcode DeviceKit vector chrome assets selected by each CoreSimulator device profile, not generated approximations. Original PDFs, JSON, and SHA-256 are retained.\n\nDuo outer uses phone15; unfolded inner uses phone14, rotated with the physical aperture. iPhone17ProMax uses phone12; iPhoneSE3 uses phone; iPadPro13M5 uses tablet5. Nine-slice composition follows the supplied chrome.json where no composite PDF is present. The screenshot/recording is inserted into the real screen aperture, keeping its source aspect ratio.\n\nThey are simulator hardware renderings, not photographs or physical-device test evidence. Do not interpret legacy export canvas sizes as support for old hardware.\n''')
print('Rendered',len(manifest),'genuine DeviceKit frame templates')
