#!/bin/bash
# 1枚撮る。使い方: shoot.sh <撮り方の名前>　（名前は kv.gd の _shots() にある）
# 撮った絵（3840x2160 など）は、このフォルダの out/ に入る。
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$HERE/../../../../.." && pwd)"
mkdir -p "$HERE/out"
KV_SHOT="$1" KV_OUT="$HERE/out/$1.png" "$REPO/tools/godot/Godot_v4.7-stable_linux.x86_64" --path "$REPO/client" --resolution 640x360 -s "$HERE/kv.gd"
