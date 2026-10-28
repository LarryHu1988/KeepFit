#!/bin/zsh
set -e
cd -- "$(dirname -- "$0")"
KF_PYTHON="$HOME/Library/Caches/KeepFitModel/venv/bin/python"
if [[ ! -x "$KF_PYTHON" ]]; then
  python3 -m venv "$HOME/Library/Caches/KeepFitModel/venv"
  "$KF_PYTHON" -m pip install -r requirements.txt
fi
exec "$KF_PYTHON" -m keepfit_model --open
