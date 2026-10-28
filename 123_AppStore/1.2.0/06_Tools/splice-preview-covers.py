from pathlib import Path
import json,subprocess,concurrent.futures,sys
R=Path(__file__).resolve().parents[1];O=R/'08_AppStoreConnect/LayoutRevision-20261028';B=Path(json.loads((O/'backup.json').read_text())['backup']);profiles=json.loads((R/'07_Validation/stage-geometry.json').read_text())
def run(a):
 p=subprocess.run(a,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
 if p.returncode:raise RuntimeError(p.stderr.decode()[-2500:])
 return p.stdout

def export(x):
 lang=x['locale'];name=x['profile'];w=x['width'];h=x['height'];work=O/'SpliceWork'/lang/name;work.mkdir(parents=True,exist_ok=True);old=B/'02_Previews'/lang/(name+'.mp4');cover=O/'Rendered/05_Sources/covers'/lang/(name+'.png');new=O/'PreviewCandidates'/lang/(name+'.mp4');new.parent.mkdir(parents=True,exist_ok=True)
 run(['ffmpeg','-v','error','-y','-loop','1','-framerate','30','-i',str(cover),'-vf','setsar=1,format=yuv420p','-frames:v','75','-r','30','-an','-c:v','libx264','-threads','2','-preset','medium','-profile:v','high','-level:v','4.0','-pix_fmt','yuv420p','-color_range','tv','-colorspace','bt709','-b:v','10M','-maxrate','12M','-bufsize','24M',str(work/'cover.mp4')])
 run(['ffmpeg','-v','error','-y','-ss','2.5','-i',str(old),'-map','0:v:0','-an','-c:v','copy',str(work/'tail.mp4')])
 (work/'join.txt').write_text("file 'cover.mp4'\nduration 2.5\nfile 'tail.mp4'\n")
 run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',str(work/'join.txt'),'-map','0:v:0','-c:v','copy','-an',str(work/'video.mp4')])
 run(['ffmpeg','-v','error','-y','-i',str(work/'video.mp4'),'-i',str(old),'-map','0:v:0','-map','1:a:0','-c','copy','-t','28','-movflags','+faststart',str(new)])
 info=json.loads(run(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(new)]));v=next(t for t in info['streams']if t['codec_type']=='video');assert int(v['nb_frames'])==840,v;assert abs(float(v['duration'])-28)<.002,v
 def frames(p):
  data=run(['ffmpeg','-v','error','-i',str(p),'-map','0:v:0','-vf','select=gte(n\\,75)','-fps_mode','passthrough','-f','framemd5','-']).decode();return[line.split(',')[-1].strip()for line in data.splitlines()if line and not line.startswith('#')]
 old_frames=frames(old);new_frames=frames(new);assert len(old_frames)==len(new_frames)==765;assert old_frames==new_frames,'Recorded UI frames must be pixel-identical'
 def audio(p):return run(['ffmpeg','-v','error','-i',str(p),'-map','0:a:0','-f','hash','-hash','sha256','-']).decode().strip()
 old_audio=audio(old);new_audio=audio(new);assert old_audio==new_audio,'Music/audio must be unchanged'
 result={'file':str(new.relative_to(R)),'target':f'02_Previews/{lang}/{name}.mp4','locale':lang,'profile':name,'width':w,'height':h,'frames':840,'duration':28,'recordedFramesIdentical':765,'audioSHA256':new_audio,'audioUnchanged':True};print('COVER_ONLY_REPLACED',lang,name,flush=True);return result
if __name__=='__main__':
 jobs=profiles[:1]if '--sample'in sys.argv else profiles
 with concurrent.futures.ThreadPoolExecutor(max_workers=3)as p:result=list(p.map(export,jobs))
 (O/('preview-splice-sample.json'if '--sample'in sys.argv else'preview-splice-verification.json')).write_text(json.dumps(result,indent=2))
