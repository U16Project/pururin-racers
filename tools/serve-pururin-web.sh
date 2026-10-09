#!/usr/bin/env bash
# build/webだけを127.0.0.1で配信。Ctrl+Cで止める。
set -euo pipefail
task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
task_port="${1:-8060}"
if [[ ! "$task_port" =~ ^[0-9]+$ ]] || (( task_port < 1024 || task_port > 65535 )); then
  echo "ポートは1024〜65535の整数を指定してください。" >&2
  exit 1
fi
if [[ ! -s "$task_root/build/web/index.html" ]]; then
  echo "先に bash tools/export-pururin-web.sh を実行してください。" >&2
  exit 1
fi
echo "ぷるりんレーサーズ ローカルWeb確認: http://127.0.0.1:$task_port/"
echo "このターミナルでCtrl+Cを押すと停止します。外部へは公開しません。"
exec python3 -m http.server "$task_port" --bind 127.0.0.1 --directory "$task_root/build/web"
