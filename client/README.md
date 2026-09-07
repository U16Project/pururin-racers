# client/

Godot クライアント（プレイヤーが遊ぶアプリ）のルート。

## エンジンバージョン

- **Godot 4.7**（stable）で開発する
- エディタ本体はリポジトリに含めない。置き場所の例は [`tools/godot/README.md`](../tools/godot/README.md)
- パス例（このマシン）: `/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64`
- 起動例: `Godot_v4.7-stable_linux.x86_64 --path client`

API・メソッド・ノードは **4.7 の公式ドキュメントで確認したうえで**使う（古い 3.x / 4.0〜4.5 の記憶や記事をそのまま書かない）。エージェントは `.cursor/rules/godot-4.7.mdc` に従う。

## M1 起動確認

（疎通確認用。現行の main_scene は M2。）

先にサーバーを起動してから（`server/README.md`、待ち受け `127.0.0.1:18765`）。

リポジトリルートから:

```bash
/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64 --path client
```

完了の見方:

- 緑の地面の上に灰色の帯（コース／Path）が見える
- オレンジの箱（ランナー）が帯の上を周回する
- 上部ラベル／コンソールに `pong を受け取ったよ` が出る
- コンソールに `ぷるりんレーサーズ — M1 コースを走ります` も出る

M0 の空シーンは `main.tscn` / `main.gd`、M1 は `scenes/m1_run.tscn`、M2 は `scenes/m2_run.tscn` に残してある（main_scene は M3 の `scenes/m3_intro.tscn`）。

## M3 起動確認（導入＋控室接続／ローカルレース）

導入画面はオフラインで表示されます。「レース開始」でローカル簡易レース、「控室へ進む」で M2 控室へ進みます。

- main_scene: `scenes/m3_intro.tscn`
- 導入: `←→` ライン、`↑↓` 目標スピード（レース）、`C` カメラ、`Esc` メニュー（レース中）
- **レース開始**: `scenes/local_race.tscn`（サーバー不要。8 頭・2000 m・東京風 1:1）
- **控室へ進む**: サーバー起動時 `接続しています…` → `接続できました` → 控室入室結果
- サーバー停止時（控室）: `接続できませんでした。サーバーを起動してください`
- 契約: [`shared/protocol_m3.md`](../shared/protocol_m3.md)、ローカルレース [`shared/protocol_local_race.md`](../shared/protocol_local_race.md)

## ローカル簡易レース確認

サーバー不要。導入から「レース開始」。

- 緑ライン＝スタート、白ライン＝ゴール（ホームストレート終端）。HUD に経過タイム、結果画面にゴールタイムを競馬風（`1:23.4`）で表示
- 橙（最内）が操作キャラ。左右＝ライン、上下＝目標スピード（プレイヤー上限 25m/s）
- Esc で一時停止→タイトルへ戻る。全員ゴール後に着順→タイトルへ戻る
- 詳細ルールは検討事項 #23 / `protocol_local_race.md`

## M2 起動確認（内外＋控室）

先にサーバーを起動してから（`server/README.md`、待ち受け `127.0.0.1:18765`）。

- main_scene: `scenes/m2_run.tscn`
- 競馬場形の仮コース（直線＋半円、幅 15m、機体 φ1.5m 想定）
- ←→ / ゲームパッド十字左右で内外（左＝内）
- C でカメラ切替（**後方追従**／**真上＋正射影**）
- 橙＝操作、青＝最内／黄＝中心／紫＝最外のダミー（同対地速）
- カーブでは距離倍率（幾何＋`GEOMETRIC_BLEND`）で内側が中心線を進みやすい。直線は内外同速
- 上部ラベルに控室入室（例: `控室に入りました（waiting_room・いま N 人）`）

通信契約:

- M1 ping／pong: [`shared/protocol_m1.md`](../shared/protocol_m1.md)
- M2 控室: [`shared/protocol_m2.md`](../shared/protocol_m2.md)

Windows 起動例（エディタパスは環境に合わせる）:

```powershell
& "C:\Users\user\Documents\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path client
```

または `tools/windows/start-godot-client.ps1` / VS Code タスク。

## テスト（GUT）

- **GUT 9.7.1**（Godot 4.7 向け）を `addons/gut/` に同梱。プラグインは有効済み
- テスト置き場: `test/unit/`（ファイル名は `test_*.gd`）
- 設定: `.gutconfig.json`
- **Export に `addons/gut` と `test/` を含めない**（開発用。プリセット作成時に除外する）

エディタ: Project → Project Settings → Plugins で Gut が有効であることを確認し、下部の GUT パネルから Run All。

コマンドライン（リポジトリの `client/` で）:

```bash
HOME=/tmp/pururin-godot-home \
/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64 \
  -d -s --path . addons/gut/gut_cmdln.gd -gexit
```

（`HOME` を書き込み可能な場所に向けると、サンドボックスや初回起動で落ちにくい。）

M1 の distance 進行ロジックは `test/unit/test_m1_distance.gd`、M2 のコース／倍率は `test/unit/test_m2_track.gd`、ローカルレースは `test/unit/test_local_race.gd` でカバーする。

## フォント

- 日本語 UI 用に `fonts/NotoSansCJK-Regular.ttc`（Noto Sans CJK / SIL OFL）を同梱。詳細は [`fonts/README.md`](fonts/README.md)

## プロジェクト配置

- `project.godot` は **このディレクトリ直下** に置く
- Windows / Linux（Steam）と Android（Google Play）は、**同一プロジェクトの Export プリセット**で出す（PC用・Android用にフォルダ分割しない）
- Export 先はリポジトリの [`build/`](../build/)（例: `../build/linux/`）。成果物は Git に含めない
- Phase やオンライン同時進行の進め方は `docs/検討事項.md` を参照
