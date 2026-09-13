#!/usr/bin/env bash
# このワークスペースで起動した Pururin 開発用プロセスだけを停止する。

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SERVER_DIR="$ROOT_DIR/server"
CLIENT_DIR="$ROOT_DIR/client"
PYTHON_BIN="$SERVER_DIR/.venv/bin/python"

if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN=""
else
  PYTHON_BIN="$(readlink -f "$PYTHON_BIN")"
fi

normalize_path() {
  readlink -f "$1" 2>/dev/null || true
}

is_python_server() {
  local pid="$1"
  local exe cwd arg
  [[ -r "/proc/$pid/exe" && -r "/proc/$pid/cwd" && -r "/proc/$pid/cmdline" ]] || return 1
  [[ -n "$PYTHON_BIN" ]] || return 1
  exe="$(normalize_path "/proc/$pid/exe")"
  cwd="$(normalize_path "/proc/$pid/cwd")"
  [[ "$exe" == "$PYTHON_BIN" && "$cwd" == "$SERVER_DIR" ]] || return 1

  while IFS= read -r -d '' arg; do
    [[ "$arg" == "main.py" ]] && return 0
  done < "/proc/$pid/cmdline"
  return 1
}

is_godot_client() {
  local pid="$1"
  local exe path_arg exe_name
  local -a args
  [[ -r "/proc/$pid/exe" && -r "/proc/$pid/cmdline" ]] || return 1
  exe="$(normalize_path "/proc/$pid/exe")"
  [[ -n "$exe" ]] || return 1
  exe_name="${exe##*/}"
  [[ "${exe_name,,}" == godot* ]] || return 1

  mapfile -d '' -t args < "/proc/$pid/cmdline"
  for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--path" && $((i + 1)) -lt ${#args[@]} ]]; then
      path_arg="$(normalize_path "${args[$((i + 1))]}")"
      [[ "$path_arg" == "$CLIENT_DIR" ]] && return 0
    elif [[ "${args[$i]}" == --path=* ]]; then
      path_arg="$(normalize_path "${args[$i]#--path=}")"
      [[ "$path_arg" == "$CLIENT_DIR" ]] && return 0
    fi
  done
  return 1
}

target_pids=()
target_names=()
for proc_dir in /proc/[0-9]*; do
  pid="${proc_dir##*/}"
  [[ "$pid" != "$$" ]] || continue
  if is_python_server "$pid"; then
    target_pids+=("$pid")
    target_names+=("Pythonサーバー")
  elif is_godot_client "$pid"; then
    target_pids+=("$pid")
    target_names+=("Godotクライアント")
  fi
done

if (( ${#target_pids[@]} == 0 )); then
  echo "Pururin開発プロセス: 停止対象はありませんでした。"
  exit 0
fi

for i in "${!target_pids[@]}"; do
  pid="${target_pids[$i]}"
  echo "${target_names[$i]} (PID $pid) を停止します。"
  kill -TERM "$pid" 2>/dev/null || true
done

for _ in {1..20}; do
  remaining=0
  for pid in "${target_pids[@]}"; do
    kill -0 "$pid" 2>/dev/null && remaining=1
  done
  (( remaining == 0 )) && break
  sleep 0.1
done

for i in "${!target_pids[@]}"; do
  pid="${target_pids[$i]}"
  if kill -0 "$pid" 2>/dev/null; then
    echo "${target_names[$i]} (PID $pid) が残ったため強制終了します。"
    kill -KILL "$pid" 2>/dev/null || true
  fi
done

echo "Pururin開発プロセス: 停止処理が完了しました。"
