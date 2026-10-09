#!/usr/bin/env bash
# ローカル確認用のWebリリースを書き出す。公開・既存プロセスの停止は行わない。
set -euo pipefail
task_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
task_godot="${PURURIN_GODOT:-$task_root/tools/godot/Godot_v4.7-stable_linux.x86_64}"
task_templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/4.7.stable"
if [[ ! -x "$task_godot" ]]; then
  echo "Godot 4.7 stable が見つかりません: $task_godot" >&2
  exit 1
fi
task_version="$("$task_godot" --version)"
if [[ "$task_version" != 4.7.stable.* ]]; then
  echo "Godot本体のバージョンが違います: $task_version（4.7.stableが必要）" >&2
  exit 1
fi
if [[ ! -f "$task_templates/version.txt" ]] || [[ "$(tr -d '\r\n' < "$task_templates/version.txt")" != "4.7.stable" ]] || [[ ! -s "$task_templates/web_nothreads_release.zip" ]]; then
  echo "4.7 stableのWebテンプレートが必要です: $task_templates" >&2
  echo "公式配布: https://github.com/godotengine/godot-builds/releases/tag/4.7-stable" >&2
  exit 1
fi
task_output="$task_root/build/web"
mkdir -p -- "$task_output"
echo "ぷるりんレーサーズ Web releaseを書き出します（$task_version、single-thread）"
"$task_godot" --headless --path "$task_root/client" --export-release Web "$task_output/index.html" 2>&1 | tee "$task_root/build/web-export.log"
for task_file in index.html index.js index.wasm index.pck; do
  if [[ ! -s "$task_output/$task_file" ]]; then
    echo "生成ファイルが見つかりません: $task_file" >&2
    exit 1
  fi
done
echo "書き出し完了: $task_output/index.html"
echo "ログ: $task_root/build/web-export.log"
du -h -- "$task_output"/*
echo "ローカル確認: bash tools/serve-pururin-web.sh"
