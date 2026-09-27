# client/

Godot クライアント（プレイヤーが遊ぶアプリ）のルート。

ローカル出力操作の係数は `data/config/local_race.json`、M5 共通ドラフト規則は `data/config/m5_draft_rules.json`（`shared/` の正本の写し）で管理します。編集方法・単位・適用範囲は [設定管理](../docs/設定管理.md) を参照してください。変更の反映にはクライアントの再起動が必要です。

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

導入画面はオフラインで表示されます。「レース開始」でローカル簡易レース、「集団プロトタイプを試す（M4）」と「オンラインレースを試す（M5）」で各レース、「控室へ進む」で M2 控室へ進みます。

- main_scene: `scenes/m3_intro.tscn`
- 導入: `←→`／左スティックでライン、`C`／`Y` でカメラ、`Esc`／Start でメニュー。上下／十字キーはモードによる（ローカルは出力ノッチ、M4 と M5 は目標スピード）。右スティック左右は追随カメラの向き、押し込みはリセット。A は決定、B はメニューを閉じる。X は将来のブースト用に予約
- **レース開始**: `scenes/local_race.tscn`（サーバー不要。8 頭・2000 m・標準コース）
- **控室へ進む**: サーバー起動時 `接続しています…` → `接続できました` → 控室入室結果
- サーバー停止時（控室）: `接続できませんでした。サーバーを起動してください`
- 契約: [`shared/protocol_m3.md`](../shared/protocol_m3.md)、ローカルレース [`shared/protocol_local_race.md`](../shared/protocol_local_race.md)

## ローカル簡易レース確認

サーバー不要。導入から「レース開始」。

- 緑ライン＝スタート、発光＝ゴール。スタートはホーム直線上（最初のコーナーまで約 197 m）。ゴールは直線の中ほどで、その先にも直線が約 280 m ある
- HUD に経過タイム、結果画面にゴールタイムを `58.4` / `1:23.4` で表示
- 開始前は3秒のカウントダウン。橙（最内）が操作キャラで、初期ノッチ4から上下で開始出力を選ぶ。タイミング判定はなく、`START!` と同時に選択ノッチで走行を始める
- レース開始後は左右／左スティック＝ライン、上下／十字キー＝出力ノッチ。V で目標スピード方式へ切り替え（上限 75 km/h）
- Esc で一時停止→タイトルへ戻る。全員ゴール後に着順→タイトルへ戻る
- コース正本は [`shared/course_layout_m5.json`](../shared/course_layout_m5.json)。詳細は検討事項 #23 / `protocol_local_race.md`

## M4 集団プロトタイプ確認

サーバー不要。導入から「集団プロトタイプを試す（M4）」。

- プレイヤー＋CPU内側型＋CPU外側型の3体を走らせる
- ←→／左スティック＝ライン変更、↑↓／十字キー＝目標スピード、C／Y＝カメラ切替、Esc／Start＝メニュー
- コースは標準コースではない。直線 526 m、半径 164 m、スタート path 609、ゴール path 526 の旧寸法
- HUD の「ドラフト中」は、同一ライン付近の前方に入り集団適性による速度補助が発生している状態
- 固定仮能力値は検討事項 #25 に記載。能力配分・保存・育成・属性・通信同期は未実装
- シーン: `scenes/m4_group_race.tscn`（`local_race.tscn` の初期値は旧寸法のまま。ローカル側が起動時に標準コースへ差し替える）

## M5 オンラインレース確認

サーバーを起動してから。導入から「オンラインレースを試す（M5）」。

- 標準コース。判定はサーバー、クライアントは描画と目標スピード・ラインの送信
- ←→／左スティック＝ライン、↑↓／十字キー＝目標スピード、C／Y＝カメラ切替、Esc／Start＝メニュー
- タイム表示は百分の一秒（`0:01.20`）
- 契約: [`shared/protocol_m5.md`](../shared/protocol_m5.md)

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

コマンドライン（リポジトリルートで）:

```bash
tools/godot/Godot_v4.7-stable_linux.x86_64 \
  --headless --path client -s addons/gut/gut_cmdln.gd -gexit
```

M1 の distance 進行ロジックは `test/unit/test_m1_distance.gd`、M2 のコース／倍率は `test/unit/test_m2_track.gd`、ローカルレースは `test/unit/test_local_race.gd` でカバーする。

## フォント

- 日本語 UI 用に `fonts/NotoSansCJK-Regular.ttc`（Noto Sans CJK / SIL OFL）を同梱。詳細は [`fonts/README.md`](fonts/README.md)

## プロジェクト配置

- `project.godot` は **このディレクトリ直下** に置く
- Windows / Linux（Steam）と Android（Google Play）は、**同一プロジェクトの Export プリセット**で出す（PC用・Android用にフォルダ分割しない）
- Export 先はリポジトリの [`build/`](../build/)（例: `../build/linux/`）。成果物は Git に含めない
- Phase やオンライン同時進行の進め方は `docs/検討事項.md` を参照
