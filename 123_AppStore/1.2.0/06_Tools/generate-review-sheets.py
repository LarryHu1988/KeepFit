from pathlib import Path
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1];OUT=R/'07_Validation/ReviewSheets';OUT.mkdir(exist_ok=True)
for lang in ['zh-Hans','en']:
 for group,key in [('iphone','1320x2868'),('ipad','2064x2752'),('duo-inner-landscape','2853x2007')]:
  count=4 if group in ['duo-inner-landscape','ipad']else 7
  if count==4:width,height,cols,cellw,cellh=2000,1450,2,1000,725
  else:width,height,cols,cellw,cellh=2100,770,7,300,770
  sheet=Image.new('RGB',(width,height),'#e9eef1');draw=ImageDraw.Draw(sheet)
  for i in range(count):
   im=Image.open(R/f'01_Screenshots/{lang}/{group}/{key}/{i+1:02}.png').convert('RGB');im.thumbnail((cellw-20,cellh-45));x=i%cols*cellw;y=i//cols*cellh;sheet.paste(im,(x,y+30));draw.text((x+8,y+8),str(i+1),fill='black')
  sheet.save(OUT/f'{lang}-{group}.jpg',quality=94)
 sheet=Image.new('RGB',(1800,430),'#e9eef1')
 for i,(kind,size)in enumerate([('header','3840x1646'),('search','3840x2560'),('universal','5244x2950')]):
  im=Image.open(R/f'03_Creatives/{lang}/{kind}-{size}.png');im.thumbnail((590,410));sheet.paste(im,(i*600,10))
 sheet.save(OUT/f'{lang}-creatives.jpg',quality=94)
