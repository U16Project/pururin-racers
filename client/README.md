# client/

Godot クライアント（プレイヤーが遊ぶアプリ）のルート。

## エンジンバージョン

- **Godot 4.7**（stable）で開発する
- エディタ本体はリポジトリに含めない。置き場所の例は [`tools/godot/README.md`](../tools/godot/README.md)
- パス例（このマシン）: `/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64`
- 起動例: `Godot_v4.7-stable_linux.x86_64 --path client`

API・メソッド・ノードは **4.7 の公式ドキュメントで確認したうえで**使う（古い 3.x / 4.0〜4.5 の記憶や記事をそのまま書かない）。エージェントは `.cursor/rules/godot-4.7.mdc` に従う。

## M0 起動確認

リポジトリルートから:

```bash
/media/u16/Backup/Godot/Godot_v4.7-stable_linux.x86_64 --path client
```

完了の見方: ウィンドウが開き、中央に次の 2 行が出る。

- `ぷるりんレーサーズ`
- `いま起動したよ（M0）`

（コンソールにも同趣旨の 1 行が出る。）

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

## フォント

- 日本語 UI 用に `fonts/NotoSansCJK-Regular.ttc`（Noto Sans CJK / SIL OFL）を同梱。詳細は [`fonts/README.md`](fonts/README.md)

## プロジェクト配置

- `project.godot` は **このディレクトリ直下** に置く
- Windows / Linux（Steam）と Android（Google Play）は、**同一プロジェクトの Export プリセット**で出す（PC用・Android用にフォルダ分割しない）
- Export 先はリポジトリの [`build/`](../build/)（例: `../build/linux/`）。成果物は Git に含めない
- Phase やオンライン同時進行の進め方は `docs/検討事項.md` を参照
