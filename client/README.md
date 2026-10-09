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

M0 の空シーンは `main.tscn` / `main.gd`、M1 は `scenes/m1_run.tscn`、M2 は `scenes/m2_run.tscn` に残してある（main_scene は `scenes/logo.tscn`）。

## 起動確認（ロゴ → タイトル → レース選択 → ローカルレース）

起動すると、U16-Projectのロゴ（約2秒。どのボタンでも飛ばせる）のあと、タイトルが出ます。「オフラインフリー対戦」でレース選択へ進み、距離と、枠ごとのキャラを選んで「レース開始」（ゲームパッドは START）でローカル簡易レースを始めます。オンラインレース（M5）と控室の場面は残してありますが、タイトルからは入れません。

- main_scene: `scenes/logo.tscn`（→ `scenes/title.tscn` → `scenes/race_select.tscn`）
- メニュー（タイトル・レース選択）: 十字キー／左スティックで移動、A（`Enter`）で決定、B（`Esc`）で戻る、START でレース開始、L1・R1 で距離、SELECT（`L`）で施錠、X で選択解除、Y で強制選択、L2・R2（`PageUp`・`PageDown`）で枠の移動
- レース中: `←→`／左スティックでライン、`C`／`Y` で視点の切り替え、右スティックで見回し（押し込みでリセット）、`Esc`／START で一時停止。M5 は、上下／十字キーが目標スピード
- **ローカルの操作**: `↑↓`／十字キーで出力ノッチ（0〜6）、`Space`／A／左トリガーを押している間ブレーキ（ノッチ設定は保持）、`Z`／B でダッシュ、`X`／X でブースト、`F3` で詳細表示（診断数値と操作ガイド）の切替
- **ローカルのHUD**: 画面の左の列に、上から、自分の順位・残り距離・タイム、順位表（全走者）、操作盤。操作盤には、速度、縦ゲージ3本（ノッチ・心拍・体力）、30段の空気抵抗ゲージ（緑＝空力と後方支援、青＝ドラフト。1段＝2%、満タンは空気抵抗が60%減る状態）、ブーストとダッシュの残り。速度の大きな数字は「実際に進んでいる速さ」（前の走者にふさがれた分を引いた値）で、出力上の速度は F3 の詳細表示に併記する。描画は `scripts/presentation/race_hud.gd`（値を受け取って描くだけ）。診断用の数値は F3 の詳細表示に分けている
- **レース開始**: `scenes/local_race.tscn`（サーバー不要。レース選択画面で選んだ2〜8プル・1200〜3000 m・標準コース。コースの寸法の正本は `shared/course_layout_m5.json` で、場面ファイルの中の数字は、起動時に作り直す）
- **ぷるりんの見た目**: 体は、`data/config/pururin_parts.json`（部品の一覧）と `data/config/pururin_looks.json`（個体ごとの見た目）から、プログラムで形を作って組み立てる（`scripts/presentation/pururin_body_builder.gd`）。部品は、用意したメッシュ（`.glb`）や画像（`.png`）に取り替えられる。項目は [`docs/設定管理.md`](../docs/設定管理.md) の「ぷるりんの見た目」
- **控室へ進む**: サーバー起動時 `接続しています…` → `接続できました` → 控室入室結果
- サーバー停止時（控室）: `接続できませんでした。サーバーを起動してください`
- 契約: [`shared/protocol_m3.md`](../shared/protocol_m3.md)、ローカルレース [`shared/protocol_local_race.md`](../shared/protocol_local_race.md)

## ローカル簡易レース確認

サーバー不要。タイトルの「オフラインフリー対戦」から、レース選択の「レース開始」。

- 緑ライン＝スタート、発光＝ゴール。スタートはホーム直線上（最初のコーナーまで約 197 m）。ゴールは直線の中ほどで、その先にも直線が約 280 m ある
- HUD に経過タイム、結果画面にゴールタイムを `58.4` / `1:23.4` で表示
- レース選択画面で、距離と、枠ごとのキャラを選ぶ。左が枠番号（1〜8）とキャラスロット（ユーザー1つ＋CPU7つ）、右が今見ているキャラの詳細（属性・脚質・属性補正後の出走前8ステータス）。最初は全部未選択。ユーザーと、CPUを1体以上選ぶと、レースを始められる。CPUは、各自のCPUトレーナー設定で走る。操作の一覧は `docs/設定管理.md`
- 開始前は3秒のカウントダウン。選択した操作キャラがカメラ追従・開始ノッチ選択の対象で、初期ノッチ4から上下で開始出力を選ぶ。タイミング判定はなく、`START!` と同時に選択ノッチで走行を始める
- レース開始後は左右／左スティック＝ライン、上下／十字キー＝出力ノッチ。V で目標スピード方式へ切り替え（上限 75 km/h）
- Esc で一時停止→レース選択へ戻る。全員ゴール後に着順→レース選択へ戻る
- コース正本は [`shared/course_layout_m5.json`](../shared/course_layout_m5.json)。詳細は検討事項 #23 / `protocol_local_race.md`

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

M1 の distance 進行ロジックは `test/unit/test_m1_distance.gd`、M2 のコース／倍率は `test/unit/test_m2_track.gd`、ローカルレースは `test/unit/test_local_race.gd`、メニューの流れは `test/unit/test_menu_flow.gd`、ぷるりんの見た目は `test/unit/test_pururin_look.gd`、レース中の表情とアクションは `test/unit/test_race_expression.gd` でカバーする。全部で約4分かかる。1つのファイルだけ回すときは、末尾に `-gselect=test_pururin_look.gd` のように足す。

見た目のテストで使う、取り替えの確認用の素材（仮のメッシュ1つ・仮の画像1枚・設定2つ）は、`test/fixtures/pururin/` にある。ゲーム本体では使わない。

## ローカルレースのヘッドレス統合シミュレーション

比較条件ごとにコードを増やさず、共通CLIへJSONの `cases` 配列を渡せます。

```bash
tools/godot/Godot_v4.7-stable_linux.x86_64 --headless --path client \
  --script scripts/local_race_simulation_cli.gd -- \
  --batch-config /absolute/path/conditions.json --output-dir /absolute/path/new-results
```

各caseは `id`、`mode`（`isolated` / `race`）、`config_overrides` を持ちます。設定差し替えは通常の設定検証を通し、case終了時に復元します。結果はcaseごとのJSONと `summary.json` に保存し、既存結果は上書きしません。実行エラーと数値目標のFAILは分離します。

- `isolated`: `isolated.effective_stats` は1〜15の固定有効値。40点配分・属性・順位・区間補正・CPU・コースは適用しない因果比較です。`body_enabled`、`duration_s`、`distance_m`、`initial_speed_kmh`、`delta_s`、`sample_interval_s`、`draft_received_p`、`drive_schedule`（`start_s` / `drive_level`）を指定できます。速度は実走Math、心拍・スタミナ・超過負荷は実走Runnerの身体更新関数を使用します。`draft_received_p` は受取率そのもので、共有の受取上限では切りません。HUDと実効率の100%は、基準速度で真後ろの1走者が作る wake（現行 `wake_base_p + wake_speed_gain_p` = 0.18）です。身体無効時は健常な力の釣り合いを測ります。
- `race`: `scenario` に `all_cpu:true`、`seed`、`distance_m`、`player_id`、`delta_s`、`max_time_s`、`sample_interval_s`、`gate_overrides` を指定できます。全頭CPUでは元プレイヤーもロスター指定トレーナーで判断し、固定ノッチ予定は適用しません。枠の重複は拒否するため、入れ替え相手も指定してください。
- 旧上限を再現する比較だけ `isolated.legacy_speed_cap:true` / `scenario.legacy_speed_cap:true` を指定できます。通常はfalse。旧加算式と新加速応答式は設定上書きで比較し、上限あり／なしを区別してください。

統合結果には全設定、セッション、乱数seed、条件、実行秒数、全頭の時系列、初めてゴールしたtickの `finish_snapshots` を保存します。最終 `runners` は全頭完走時点なので、先にゴールした個体の心拍等はゴール後の値です。ゴール比較は `finish_snapshots` を使用してください。時間刻み既定値は1/60秒で、半刻み比較も同じ条件データでできます。未評価の相対条件は `NOT_EVALUATED` でありPASSではありません。

従来の40点配分スイープは対象以外も再配分する**合法な配分全体の比較**です。単一ステータスの因果判定には使わず、上記 `isolated` を使用してください。

描画・カメラ・入力を使わず、通常のローカルレースシーンを同じ `Runner`／`LocalRaceMath`／CPU判断／ドラフト処理で進め、結果をJSONで出力できます。

```bash
tools/godot/Godot_v4.7-stable_linux.x86_64 \
  --headless --path client \
  --script scripts/local_race_simulation_cli.gd -- \
  --scenario notch4_cruise
```

シナリオを省略すると `notch4_cruise`、利用可能な例は `data/config/local_race_simulation.json` にあります。

- `notch4_cruise`: ノッチ4巡航
- `notch6_sustain`: ノッチ6持続
- `notch6_to_zero_recovery`: ノッチ6から0へ落として心拍回復を観測
- `cpu_pack_and_draft`: CPU集団・ドラフトの観測

各結果には、経過時間、完走数、各ランナーの距離・速度・順位・心拍・スタミナ・ドラフト情報、時系列サンプルが含まれます。
時系列サンプルには、経路距離／レース進捗、座標・向き、現在／目標速度、自然最高速、ノッチ、心拍・スタミナ、オーバーヒート・推進効率、速度診断、ドラフト状態、完走状態を含みます。`test_local_race_simulator.gd` では4シナリオを実際に進行し、速度・距離・心拍・スタミナ・ノッチ・ドラフト率・順位／完走順などの範囲と整合性を検証します。

各シナリオには、単なる範囲検証に加えて、設定ファイルの `goals` に定義した目標値・許容範囲・相対条件の判定結果を `goal_assessment` として出力します。`passed` と `status`（`PASS` / `FAIL`）、実測値、目標値、判定メッセージ、`summary` を確認できます。例えばノッチ4はゴール時スタミナ0%付近・心拍170〜195・オーバーヒートなし、ノッチ6は高負荷だが心拍230以下・スタミナ負債-100以内を確認します。ノッチ6とノッチ4の負荷比較のような相対条件は、両方の結果を参照して再評価できます。旧キー `goal_checks` も互換のため読み込めます。

## フォント

- 日本語 UI 用に `fonts/NotoSansCJK-Regular.ttc`（Noto Sans CJK / SIL OFL）を同梱。詳細は [`fonts/README.md`](fonts/README.md)

## プロジェクト配置

- `project.godot` は **このディレクトリ直下** に置く
- Windows / Linux（Steam）と Android（Google Play）は、**同一プロジェクトの Export プリセット**で出す（PC用・Android用にフォルダ分割しない）
- Export 先はリポジトリの [`build/`](../build/)（例: `../build/linux/`）。成果物は Git に含めない
- Phase やオンライン同時進行の進め方は `docs/検討事項.md` を参照

## ゲームパッド設定・入力確認

タイトル左上の「ゲームパッド設定・入力確認」で、接続したパッドを選び、「標準配置」または登録された機種別補正を選べます。選択すると保存し、タイトルへ戻ると適用します。次回起動・再接続でも保存した設定を使います。未登録の機種は標準配置を維持します。補正は記録と一致するGUID・OSのみに適用し、ゲーム本体の操作対象は従来どおりID 0です。

今回のWindows版ELECOM JC-U3712Fの記録に対応しています。右4ボタンの下／右／左／上をA／B／X／Yとして扱い、ボタン式L2・R2と右スティック上下も補正します。MODEは記録時と同じにしてください。記録ではSTARTと左スティック上が同じボタン11で識別できないため、STARTは未対応です（STARTを押すと左スティック上になります）。レース開始は画面ボタン、メニューはEscで代用してください。MODEを変えた場合は再記録が必要です。

対応表の正本は `data/config/pad_profiles.json`、利用者の選択は `user://pad_input_options.json`。診断画面では補正を停止し、元の入力を記録します。

タイトル左上の「ゲームパッド設定・入力確認」から開きます。診断画面はマウス／キーボードで操作し、Escで戻ります。対象のパッドを選び、MODEを固定して全操作を離し「記録を始める」。各項目は「この操作を採取」→指定の物理ボタン／方向を操作→表示を確認→「これで確定／次へ」で進めます。次の採取前に操作を離し、スティックを中央に戻してください。存在しない操作は「ない／反応なし」で飛ばせます。

Godotが受け取る変換後の入力（ボタン0〜20、軸0〜9）を表示・記録します。「JSONを保存」で `user://pad_diagnostics/` に診断結果を保存し、画面に実際の保存先を表示します。診断の記録操作では、保存した入力設定は変更しません。対象切断で採取を中断、対象変更で診断記録をリセットします。
