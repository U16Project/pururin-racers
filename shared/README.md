# shared/

ゲーム（Godot）とオンラインのサーバー（画面なしの Godot）のあいだの、通信の決まりの置き場。

| ファイル | 内容 |
|----------|------|
| [`protocol_online.md`](protocol_online.md) | オンライン対戦の通信の決まり |

コースの形（`client/data/course_layout.json`）とドラフト規則（`client/data/config/local_race.json` の `draft_*`）は、ゲームもサーバーも `client/` 側を読む。
