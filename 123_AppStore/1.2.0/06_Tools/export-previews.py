"""Cover + real native Tab recordings + CC0 music; no recreated app UI."""
from pathlib import Path
import json, subprocess, concurrent.futures, sys
R=Path(__file__).resolve().parents[1]
PROFILES=[('iphone-modern',886,1920,'iphone'),('iphone-home-large',1080,1920,'iphone'),('iphone-home-medium',750,1334,'iphone-se'),('ipad',1200,1600,'ipad'),('ipad-legacy',900,1200,'ipad'),('duo-outer',886,1920,'duo-outer'),('duo-inner',1920,886,'duo-inner-landscape')]
def run(args):
 p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True)
 if p.returncode:raise RuntimeError(p.stderr[-5000:])
 return p.stdout
def export(job):
 lang,(name,w,h,group)=job
 source=R/'05_Sources/recordings'/group/lang
 if not(source/'done').exists():return None
 phases=json.loads((source/'timeline.json').read_text());ack=float((source/'ack').read_text())
 out=R/'02_Previews'/lang/(name+'.mp4');out.parent.mkdir(parents=True,exist_ok=True)
 if out.exists() and '--force' not in sys.argv:return {'file':str(out.relative_to(R)),'profile':name,'locale':lang,'source':group,'width':w,'height':h,'duration':28,'posterTimecode':'00:00:00:00','hardwareFrame':'Apple DeviceKit','overviewTabs':['eat','move','lose'],'chapters':[{'tab':'cover','start':0,'duration':2.5}]+[{'tab':p['tab'],'start':2.5+i*8.5,'duration':8.5}for i,p in enumerate(phases)],'rawPhases':phases}
 geometry=next(x for x in json.loads((R/'07_Validation/stage-geometry.json').read_text())if x['profile']==name and x['locale']==lang)
 sw,sh,sx,sy=[geometry[k]for k in ['screenWidth','screenHeight','screenX','screenY']]
 movie=source/'source.mov';duration=float(json.loads(run(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(movie)]))['format']['duration'])
 filters=[f'[0:v]fps=30,trim=duration=2.5,setpts=PTS-STARTPTS,setsar=1,format=yuv420p[c]', '[1:v]fps=30,tpad=stop_mode=clone:stop_duration=15,split=3[v0][v1][v2]']
 for i,phase in enumerate(phases):
  start=max(0,phase['start']-ack);end=max(start+.1,phase['end']-ack);factor=8.5/max(.1,end-start)
  filters.append(f'[v{i}]trim=start={start:.6f}:end={end:.6f},setpts=(PTS-STARTPTS)*{factor:.8f},scale={sw}:{sh}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad={sw}:{sh}:(ow-iw)/2:(oh-ih)/2:color=black,format=rgba,pad={w}:{h}:{sx}:{sy}:color=black,setsar=1,fps=30,tpad=stop_mode=clone:stop_duration=15,trim=duration=8.5,format=rgba[s{i}]')
 filters+=['[s0][s1][s2]concat=n=3:v=1:a=0[body]','[body][2:v]overlay=0:0:format=auto:shortest=1,format=yuv420p[framed]','[c][framed]concat=n=2:v=1:a=0[v]','[3:a]atrim=start=12:end=40,asetpts=PTS-STARTPTS,loudnorm=I=-22:TP=-3:LRA=7,afade=t=in:d=0.8,afade=t=out:st=26.5:d=1.5,aresample=48000[a]']
 command=['ffmpeg','-hide_banner','-loglevel','error','-y','-threads','2','-loop','1','-framerate','30','-i',str(R/'05_Sources/covers'/lang/(name+'.png')),'-i',str(movie),'-loop','1','-framerate','30','-i',str(R/geometry['file']),'-i',str(R/'05_Sources/music/first-light-particles.wav'),'-filter_complex_threads','2','-filter_complex',';'.join(filters),'-map','[v]','-map','[a]','-t','28','-r','30','-c:v','libx264','-threads','2','-preset','medium','-profile:v','high','-level:v','4.0','-pix_fmt','yuv420p','-b:v','10M','-maxrate','12M','-bufsize','24M','-c:a','aac','-b:a','256k','-ar','48000','-ac','2','-movflags','+faststart',str(out)]
 run(command);print('EXPORTED',lang,name,flush=True)
 return {'file':str(out.relative_to(R)),'profile':name,'locale':lang,'source':group,'width':w,'height':h,'duration':28,'posterTimecode':'00:00:00:00','hardwareFrame':'Apple DeviceKit','overviewTabs':['eat','move','lose'],'chapters':[{'tab':'cover','start':0,'duration':2.5}]+[{'tab':p['tab'],'start':2.5+i*8.5,'duration':8.5}for i,p in enumerate(phases)],'rawPhases':phases}
if __name__=='__main__':
 jobs=[(lang,p)for lang in ['zh-Hans','en']for p in PROFILES]
 with concurrent.futures.ThreadPoolExecutor(max_workers=4)as pool:rows=[r for r in pool.map(export,jobs)if r]
 (R/'07_Validation/preview-manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2))
