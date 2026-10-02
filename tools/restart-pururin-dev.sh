#!/usr/bin/env bash
# このワークスペースの開発用サーバーと Godot を、仮想環境の準備からまとめて再起動する。

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
SERVER_DIR="$ROOT_DIR/server"
VENV_DIR="$SERVER_DIR/.venv"
PYTHON_BIN="$VENV_DIR/bin/python"

fail() {
  echo "開発環境の再起動に失敗しました: $*" >&2
  exit 1
}

ensure_server_venv() {
  if [[ ! -e "$VENV_DIR" ]]; then
    command -v python3 >/dev/null 2>&1 || fail "python3 が見つかりません。Python 3 を導入してからやり直してください。"

    echo "server/.venv を作成します。"
    python3 -m venv "$VENV_DIR" || fail "server/.venv を作成できませんでした。"
    "$PYTHON_BIN" -m pip install -U pip || fail "pip を更新できませんでした。"
    "$PYTHON_BIN" -m pip install -r "$SERVER_DIR/requirements.txt" || fail "server の依存関係を導入できませんでした。"
    echo "server/.venv の準備が完了しました。"
    return
  fi

  [[ -x "$PYTHON_BIN" ]] || fail "server/.venv はありますが、bin/python を実行できません。仮想環境の状態を確認してください。"
  echo "server/.venv は既に用意されています。"
}

echo "既存の Pururin 開発プロセスを停止します。"
"$ROOT_DIR/tools/stop-pururin-dev.sh" || fail "既存プロセスを停止できませんでした。"

ensure_server_venv

echo "Pythonサーバーと Godot クライアントを起動します。"
exec "$ROOT_DIR/tools/start-pururin-dev.sh"
