"""Start detached resumable collection and local name translation; never schedules jobs."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parent


def launch(name, command):
    pid_path=ROOT/'.data'/(name+'.pid')
    if pid_path.exists():
        try:
            pid=int(pid_path.read_text())
            os.kill(pid,0)
            identity=subprocess.run(['/bin/ps','-p',str(pid),'-o','command='],capture_output=True,text=True,check=False)
            if ' '.join(command[1:]) in identity.stdout:
                return dict(name=name,pid=pid,status='already_running')
        except (ValueError,ProcessLookupError):
            pass
    log_path=ROOT/'.data'/(name+'.log')
    with log_path.open('ab',buffering=0) as log:
        process=subprocess.Popen(command,cwd=str(ROOT),stdin=subprocess.DEVNULL,stdout=log,
            stderr=subprocess.STDOUT,start_new_session=True)
    pid_path.write_text(str(process.pid))
    return dict(name=name,pid=process.pid,status='started',log=str(log_path))


if __name__=='__main__':
    results=[launch('supplement-collector',[sys.executable,'-u',str(ROOT/'supplement.py'),'collect'])]
    python=ROOT/'.venv/bin/python'
    if python.exists():
        results.append(launch('supplement-translations',[str(python),'-u',str(ROOT/'translate_names.py')]))
    results.append(launch('food-atlas',[sys.executable,'-u',str(ROOT/'browser.py'),'--port','8768']))
    print(json.dumps(results,ensure_ascii=False,indent=2))
