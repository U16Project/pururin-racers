#!/usr/bin/env bash
# オンラインのサーバー（画面なしの Godot）を、外のLinuxサーバーへ送って、起動し直す。
# 使い方： tools/deploy-online-server.sh ubuntu@133.167.117.244
# 前提：そのサーバーに、鍵で（パスワードなしで）ssh で入れること。管理者の権限は使わない。
#       置き場所は、入った人の ~/pururin/ 。自動で起動する設定は、~/.config/systemd/user/pururin-server.service 。
set -euo pipefail

if [ $# -ne 1 ]; then
	echo "使い方: $0 <ユーザー@サーバー>" >&2
	exit 1
fi
TARGET="$1"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="tools/godot/Godot_v4.7-stable_linux.x86_64"
SERVICE="pururin-server.service"

cd "$ROOT"
ssh -o BatchMode=yes "$TARGET" 'mkdir -p ~/pururin/tools/godot ~/pururin/client ~/.config/systemd/user'
# Godot 本体と、ゲームのデータ。
rsync -az "$GODOT" "$TARGET:pururin/tools/godot/"
rsync -az --delete --exclude='.godot/' client/ "$TARGET:pururin/client/"
# 取り込み済みの画像・音・フォント（.godot の中の、要るものだけ）は、このパソコンで作ったものを送る。
# サーバーの上で取り込みを走らせると、終わらずに待ち続けることがあったため。
# 送る前に、このパソコンで1回、Godot のエディタでプロジェクトを開いて（または --import で）、取り込みを済ませておくこと。
ssh -o BatchMode=yes "$TARGET" 'mkdir -p ~/pururin/client/.godot/imported'
rsync -az --delete client/.godot/imported/ "$TARGET:pururin/client/.godot/imported/"
rsync -az client/.godot/uid_cache.bin client/.godot/global_script_class_cache.cfg "$TARGET:pururin/client/.godot/"
rsync -az --delete shared/ "$TARGET:pururin/shared/"

ssh -o BatchMode=yes "$TARGET" "bash -s" <<REMOTE
set -euo pipefail
cd ~/pururin
chmod +x $GODOT
cat > ~/.config/systemd/user/$SERVICE <<UNIT
[Unit]
Description=Pururin Racers online server (headless Godot)
After=network-online.target

[Service]
WorkingDirectory=%h/pururin
ExecStart=%h/pururin/$GODOT --headless --path client res://scenes/online_server.tscn
Restart=always
RestartSec=3

[Install]
WantedBy=default.target
UNIT
# ログアウトしても、再起動しても、動き続けるようにする。
loginctl enable-linger "\$(whoami)" || true
systemctl --user daemon-reload
systemctl --user enable $SERVICE >/dev/null 2>&1
systemctl --user restart $SERVICE
sleep 4
systemctl --user is-active $SERVICE
journalctl --user -u $SERVICE -n 20 --no-pager | grep "待機中" | tail -1
REMOTE
