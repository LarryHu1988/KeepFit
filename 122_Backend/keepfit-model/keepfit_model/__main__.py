import argparse
import json
import os
import secrets
from pathlib import Path

import uvicorn

from .api import create_app


def main():
    parser = argparse.ArgumentParser(description="KeepFit 本地服务，只监听本机回环地址")
    parser.add_argument("--demo", action="store_true", help="启用固定案例演示，不调用任何云 API")
    parser.add_argument("--open", action="store_true", help="启动后自动打开可视化工作台")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--data-dir", type=Path, default=Path(".data"))
    args = parser.parse_args()
    if args.open:
        import webbrowser
        from urllib.request import Request, build_opener, ProxyHandler
        try:
            opener = build_opener(ProxyHandler({}))
            with opener.open(Request(f"http://127.0.0.1:{args.port}/health"), timeout=2) as response:
                health = json.load(response)
            if health.get("app") == "keepfit-workbench" or (health.get("local_prototype") and health.get("version") == "0.2.0"):
                webbrowser.open(f"http://127.0.0.1:{args.port}/")
                return
            raise RuntimeError("端口已被其它服务占用")
        except (OSError, ValueError):
            pass
    if os.environ.get("KEEPFIT_MODE") == "production" and (args.demo or args.open):
        parser.error("Production does not expose the local workbench or demo mode")
    if args.demo:
        os.environ["KEEPFIT_PROVIDER"] = "demo"
    args.data_dir.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.environ.get("KEEPFIT_MODE") != "production" and not os.environ.get("KEEPFIT_CLIENT_KEYS"):
        key_file = args.data_dir / "local-token"
        if not key_file.exists():
            fd = os.open(key_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, "w") as file:
                file.write(secrets.token_urlsafe(32))
        os.chmod(key_file, 0o600)
        os.environ["KEEPFIT_CLIENT_KEYS"] = json.dumps({"local": key_file.read_text().strip()})
        print(f"本地凭证保存在 {key_file.resolve()}，未输出到日志。")
    app = create_app(directory=args.data_dir)
    if args.open:
        import threading
        def open_when_ready():
            from time import sleep
            for _ in range(30):
                try:
                    with opener.open(f"http://127.0.0.1:{args.port}/health", timeout=1):
                        webbrowser.open(f"http://127.0.0.1:{args.port}/")
                        return
                except OSError:
                    sleep(0.2)
        threading.Thread(target=open_when_ready, daemon=True).start()
    uvicorn.run(app, host=args.host, port=args.port, access_log=False, limit_concurrency=16)


if __name__ == "__main__":
    main()
