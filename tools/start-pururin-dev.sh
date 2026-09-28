#!/usr/bin/env bash
# サーバーの待受を確認してから、Godot クライアントを起動する。

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SERVER_DIR="$ROOT_DIR/server"
CLIENT_DIR="$ROOT_DIR/client"
PYTHON_BIN="$SERVER_DIR/.venv/bin/python"
HOST="127.0.0.1"
PORT="18765"
SERVER_PID=""

stop_started_server() {
  if [[ -n "$SERVER_PID" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "起動したサーバー (PID $SERVER_PID) を停止します。" >&2
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    for _ in {1..20}; do
      kill -0 "$SERVER_PID" 2>/dev/null || break
      sleep 0.1
    done
    if kill -0 "$SERVER_PID" 2>/dev/null; then
      kill -KILL "$SERVER_PID" 2>/dev/null || true
    fi
  fi
  wait "$SERVER_PID" 2>/dev/null || true
}

if [[ ! -x "$PYTHON_BIN" ]]; then
  echo "server/.venv/bin/python が見つかりません。先に仮想環境を用意してください。" >&2
  exit 1
fi

pushd "$SERVER_DIR" >/dev/null
"$PYTHON_BIN" main.py &
SERVER_PID=$!
popd >/dev/null

server_is_ready() {
  "$PYTHON_BIN" - "$HOST" "$PORT" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
try:
    with socket.create_connection((host, port), timeout=0.2):
        pass
except OSError:
    raise SystemExit(1)
PY
}

ready=0
for _ in {1..100}; do
  if server_is_ready; then
    ready=1
    break
  fi
  if ! kill -0 "$SERVER_PID" 2>/dev/null; then
    wait "$SERVER_PID" 2>/dev/null || true
    echo "Pythonサーバーが待受開始前に終了しました。" >&2
    exit 1
  fi
  sleep 0.1
done

if (( ready == 0 )); then
  echo "サーバーが $HOST:$PORT で待受を開始しませんでした。" >&2
  stop_started_server
  exit 1
fi

echo "サーバー待受確認OK ($HOST:$PORT)。Godotを起動します。"

GODOT="$ROOT_DIR/tools/godot/Godot_v4.7-stable_linux.x86_64"
if [[ ! -x "$GODOT" ]]; then
  GODOT="/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64"
fi
if [[ ! -x "$GODOT" ]]; then
  echo "Godot 4.7 が見つかりません（tools/godot/ を確認）" >&2
  stop_started_server
  exit 1
fi

if "$GODOT" --path "$CLIENT_DIR"; then
  # サーバーは既存の個別起動タスクと同じく、クライアント終了後も残す。
  disown "$SERVER_PID" 2>/dev/null || true
  SERVER_PID=""
  exit 0
else
  status=$?
  echo "Godotの起動に失敗しました（終了コード $status）。" >&2
  stop_started_server
  exit "$status"
fi
