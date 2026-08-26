# tools/godot/

Godot **エディタ本体**の置き場（任意）。ゲームプロジェクト本体は `client/`。

## バージョン（必須）

このリポジトリの開発・実装は **Godot 4.7**（stable）に揃える。  
GDScript / ノード API / プロパティは **4.7 系の公式ドキュメントで確認してから**使う（エージェント規則: `.cursor/rules/godot-4.7.mdc`）。

- 手元例: `Godot_v4.7-stable_linux.x86_64` / Windows: `Godot_v4.7.2-stable_win64.exe`
- メンテ版（例: 4.7.1 / 4.7.2）は 4.7 系として可。チームで揃えるのが望ましい。
- Windows 手元例: `C:\Users\user\Documents\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`（Cursor タスクが参照）

## 置き方（Git には上げない）

バイナリは大きいので **コミットしない**（このディレクトリの `.gitignore` で除外）。

例（Linux）:

```bash
# リポジトリルートから
mkdir -p tools/godot
cp /media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64 tools/godot/
chmod +x tools/godot/Godot_v4.7-stable_linux.x86_64
```

例（Windows）:

```powershell
# リポジトリルートから
New-Item -ItemType Directory -Force -Path tools\godot | Out-Null
# 公式 zip から展開した実行ファイルをコピー
Copy-Item $env:USERPROFILE\Downloads\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe tools\godot\
```

またはシンボリックリンク:

```bash
ln -s /media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64 tools/godot/Godot_v4.7-stable_linux.x86_64
```

## エディタ起動例

```bash
./tools/godot/Godot_v4.7-stable_linux.x86_64 --path client
```

```powershell
.\tools\godot\Godot_v4.7-stable_win64.exe --path client
```

Cursor / VS Code ではタスク「サーバーとクライアントを起動」も利用可（`.vscode/tasks.json`）。

公式は `.deb` ではなく、zip／ポータブル実行ファイル配布。
