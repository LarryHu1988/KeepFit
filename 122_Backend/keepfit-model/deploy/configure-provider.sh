#!/bin/bash
# Run in an owner-controlled interactive server terminal, never through a logged cloud command.
set -euo pipefail
set +x
umask 077
export LC_ALL=C
if [ ! -t 0 ]; then echo '请在交互式服务器终端中运行。'; exit 1; fi
IFS= read -r -s -p '请粘贴 MiMo API Key，再按回车（输入不回显）: ' keepfit_provider_key
printf '\n'
if [[ ${#keepfit_provider_key} -lt 20 || "$keepfit_provider_key" =~ [^[:graph:]] ]]; then
 unset keepfit_provider_key; echo '密钥格式不正确，请重新输入。'; exit 1
fi
case "$keepfit_provider_key" in
 tp-*|ttp-*) unset keepfit_provider_key; echo '请使用 MiMo 按量计费 API Key，Token Plan 专用密钥不适用于本服务。'; exit 1 ;;
esac
key_tmp=$(mktemp /opt/keepfit/secrets/.provider-key.XXXXXX)
trap 'rm -f "$key_tmp"; unset keepfit_provider_key' EXIT
printf '%s' "$keepfit_provider_key" > "$key_tmp"
unset keepfit_provider_key
chown keepfit:keepfit "$key_tmp"
chmod 600 "$key_tmp"
cd /opt/keepfit/current
runuser -u keepfit -- /opt/keepfit/venv/bin/python - "$key_tmp" <<'PY'
import sys
from pathlib import Path
from keepfit_model.cloud import CloudProvider
from keepfit_model.providers import ServiceError
key=Path(sys.argv[1]).read_text().strip()
try:
    CloudProvider('mimo',key,{},[],lambda:None,lambda usage:None).verify()
    print('MiMo 模型可用性验证通过。没有执行付费推理。')
except ServiceError as exc:
    print('连接验证未通过，未替换正式密钥：'+exc.message)
    raise SystemExit(1)
PY
mv -f "$key_tmp" /opt/keepfit/secrets/provider-key
echo 'MiMo 密钥已安全保存，服务已连接。'
