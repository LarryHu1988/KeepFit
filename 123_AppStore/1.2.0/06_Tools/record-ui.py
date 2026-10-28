from pathlib import Path
import subprocess,time,signal,os,sys,json
root=Path(__file__).resolve().parents[1];group,udid,display=sys.argv[1:4];env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
for lang in ['zh-Hans','en']:
 d=root/'05_Sources/recordings'/group/lang;d.mkdir(parents=True,exist_ok=True);deadline=time.monotonic()+500
 while not(d/'ready').exists():
  if time.monotonic()>deadline:raise RuntimeError('Timed out waiting for UI')
  time.sleep(.1)
 with(d/'record.log').open('w')as f:
  p=subprocess.Popen(['xcrun','simctl','io',udid,'recordVideo','--codec=h264',*(['--display='+display]if display!='default'else[]),'--mask=ignored','--force',str(d/'source.mov')],env=env,stdout=f,stderr=f)
  while 'Recording started' not in(d/'record.log').read_text():
   if p.poll()is not None:raise RuntimeError((d/'record.log').read_text())
   time.sleep(.1)
  (d/'ack').write_text(str(time.time()))
  while not(d/'done').exists():
   if time.monotonic()>deadline:p.send_signal(signal.SIGINT);raise RuntimeError('UI flow timed out')
   time.sleep(.1)
  p.send_signal(signal.SIGINT);p.wait(timeout=30)
 print('RECORDED',group,lang,flush=True)
