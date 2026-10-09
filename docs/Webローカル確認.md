# Web版のローカル確認（第1段階）

まだ公開しません。Pythonゲームサーバーやオンライン接続は使わず、現行クライアントの表示・操作・容量をブラウザで確認します。

## 準備

Godot本体と書き出しテンプレートは **4.7 stable** にそろえます。本体の既定位置は `tools/godot/Godot_v4.7-stable_linux.x86_64`。テンプレートはGodotエディターの「エディター → 書き出しテンプレートの管理」で導入できます。テンプレートはGitに入れません。

- [公式4.7 stable配布](https://github.com/godotengine/godot-builds/releases/tag/4.7-stable)
- [Godot 4.7 Web書き出しの説明](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html)

## 書き出しと起動

リポジトリのルートで実行します。

```bash
bash tools/export-pururin-web.sh
bash tools/serve-pururin-web.sh
```

Chromium系ブラウザで `http://127.0.0.1:8060/` を開きます。`file://`でHTMLを直接開かないでください。確認後は配信ターミナルで **Ctrl+C**。ポートを変える例は `bash tools/serve-pururin-web.sh 8061`。

生成物は `build/web/`、ログは `build/web-export.log`。再書き出しは同名生成物を更新しますが、既存ディレクトリを削除しません。Godot本体が別の場所なら `PURURIN_GODOT=/absolute/path/to/godot` を指定できます。

## 確認すること

- ロゴからタイトルが表示され、日本語・ボタンが欠けないこと。
- 「カメラで探検」でコース・景観が表示され、WASD・ホイール・マウスで見回せること。ブラウザのマウス捕捉にはユーザーのクリック等が必要です。Escは捕捉解除に使われる場合もあります。
- オフラインフリー対戦でキャラを選び、カウントダウンから走行まで進めること。キーボード入力はゲーム画面をクリックしてから確認します。
- ゲームパッドはブラウザでボタンを一度押してから確認します。ブラウザ・OSによる割当差は未保証です。
- F12のConsoleでエラー、配信ターミナルで404を確認します。

Webは **single-thread / Compatibility（WebGL 2）** です。デスクトップ版と質感・影・速度に差が出る可能性があります。PWA・マルチスレッド・公開設定は今回追加しません。容量とブラウザ確認結果は実行時の記録で判断します。

## 第1回書き出し記録（2026/10/10）

- Godot本体：`4.7.stable.official.5b4e0cb0f`。
- テンプレートは既に導入済みでした。`~/.local/share/godot/export_templates/4.7.stable` は `/media/u16/Backup/Godot/export_templates/4.7.stable` へのリンク。バージョン一致、既存TPZのSHA512と公式 `SHA512-SUMS.txt` の一致、導入済み `web_nothreads_release.zip` とTPZ内の同ファイルの一致を確認し、再ダウンロードしていません。
- リリース書き出しは終了コード0。生成物9ファイル、ファイル合計 **60,349,583 bytes（約57.55 MiB）**。最大は `index.wasm` **39,509,339 bytes（約37.68 MiB）**、`index.pck` は **20,505,612 bytes（約19.56 MiB）**。
- 生成物：`index.html`、`index.js`、`index.wasm`、`index.pck`、`index.png`、`index.icon.png`、`index.apple-touch-icon.png`、`index.audio.worklet.js`、`index.audio.position.worklet.js`。
- 書き出しログにERRORなし。エディター起動時、既存GUT素材のUID警告13件あり。GUTとtestは書き出し対象から除外しています。
- ローカルHTTPで `index.wasm` の200応答・`application/wasm` を確認。`file://`は使用しません。
- 内蔵ブラウザで、タイトルから「カメラで探検」へ遷移し、3D会場が表示され、Escでタイトルへ戻れることを確認しました。
- 独立したChrome（1360×625）で、タイトルからオフライン対戦を選び、ランダムキャラ選択、レース開始、カウントダウン、STARTを経て、残り1996m・41km/hで走行が始まることを確認しました。
- ConsoleではGodot 4.7、WebGL 2 Compatibility、single-threaded、GDExtensionなしで起動し、JavaScript例外・Godotエラーはありませんでした。
- headless確認はSwiftShaderによるソフトウェア描画で低速だったため、性能評価には使っていません。実物ゲームパッド、完走、スマートフォン表示、通常GPUでのFPS・質感比較は未確認です。
