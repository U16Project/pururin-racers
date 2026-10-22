# Codex の操作盤試作

Claude側のファイルを編集せず、実際のローカルレースへこの操作盤を付けるGodot 4.7の別入口。
`live_preview.tscn` を開いて F6 で起動する。リポジトリルートから起動する場合:

```bash
./tools/godot/Godot_v4.7-stable_linux.x86_64 --path client res://test/manual/codex_hud/live_preview.tscn
```

アカネを操作役として、現行の個体・能力・走行計算で8プル・2400mを開始する。
F4でこの試作と既存のハート型操作盤を切り替える。F5で元の下書きを半透明に重ねて配置を比べられる。
順位・残り距離・タイム・順位表は既存の実レースの表示を使う。
速度・心拍・体力・空力の内訳・ノッチ・Boost残数と効果時間・Dash効果時間は、実レースの状態から受け取る。
個体選択・距離はこの別プロセス内だけで変更し、場面を抜けると控えから戻す。能力や個体の設定ファイルには保存しない。

`preview.tscn` は別途、見た目の検査用。ボタンで「レース配置」「操作盤を拡大」「旧操作盤と比較」を切り替える。
右のスライダーで速度・心拍・体力・空力・集団・ノッチ・Boost・Dashを変更できる。
「動かす」は試験値の自動変化。実レースの計算ではない。
Dash のバーは現行ゲームと同じく、発動中の残り時間を受け取る。

## 部品

- `dashboard.gd`: 左上の操作盤。名前・属性・脚質、速度、心拍、体力、空力の内訳、ノッチ、Boost、Dash。
- `race_summary.gd`: 右側の順位・残り距離・タイム・8プルの順位表。
- 両方の `update_state(Dictionary)` は `local_race_controller.gd` が作るHUDデータと共通のキーで受け取る。
- `preview.gd`: 見本のデータ、切り替え、スライダー、撮影と確認。
- `live_controller.gd`: 実コントローラーを継承し、この別入口のインスタンス内だけで表示部品を交換する。

配置は `docs/reference/ui/codex_hud_20261019/source_sketch.png`（元の `/home/u16/con2.png` をそのまま保存）の698×555座標を基準にする。
速さの左の弧、体力の右の弧、aeroの曲線、6段のノッチ、斜めのBoost3本、右端のDash、名前と見出しの位置を下書きへ合わせ直している。
文字の個別の背景はBPM帯だけ。明るいコース上で読めるよう、操作盤全体には一枚の半透明の地を置く。
ゲージの端と棒の角は丸め、体力の弧とノッチの塗りが重ならないよう間隔を取る。
操作盤全体の寸法は `dashboard.gd` の `BASE_SIZE`、配置は `preview.gd` の `_layout_stage()`。
起動時は操作盤を拡大して表示する。Compatibility描画でも輪郭を滑らかにするため、試作画面を2倍の解像度で描いて縮小する。

## 確認画像

通常値、警告・体力負債、速度3桁・空力100%超・長い名前、ゼロ・使い切り、960×540配置、旧盤比較をGodotの実描画から撮影する:

```bash
./tools/godot/Godot_v4.7-stable_linux.x86_64 --path client --rendering-method gl_compatibility --audio-driver Dummy res://test/manual/codex_hud/preview.tscn -- --capture=/tmp/pururin-codex-hud-review
```

撮影時には、スライダーから左右の表示へ値が伝わることと、旧盤の比較切り替えも自動確認する。
背景は `docs/reference/key_visuals/game_look_v01/ref_race_view_v01.png` を撮影済み景色として使用する。ライブの3Dレース映像ではない。

実レースの値とF4/F5の切り替えを確認して撮影する場合:

```bash
./tools/godot/Godot_v4.7-stable_linux.x86_64 --path client --rendering-method gl_compatibility --audio-driver Dummy res://test/manual/codex_hud/live_preview.tscn -- --capture-live=/tmp/pururin-codex-live
```

DejaVu Sans Condensed（Regular / Oblique、および初回試作用のBold / Bold Oblique）を同梱。使用許諾は `DejaVu-LICENSE.txt`。
試作は `client/test/` に置いているため、既存の `test/**` 除外がある Web 書き出しには含まれない。
本番の画面、起動設定、レース処理ファイルは変更しない。この別入口の実行時だけUIを交換する。
