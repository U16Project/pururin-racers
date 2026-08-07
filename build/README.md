# build/

Godot からの **エクスポート成果物**（実行ファイル・APK/AAB など）の置き場。

ソースは `client/`。ここには配布用バイナリだけを出す。

## 推奨パス（Export 先）

`client/` から見て:

| プラットフォーム | 例 |
|------------------|-----|
| Linux | `../build/linux/` |
| Windows | `../build/windows/` |
| Android | `../build/android/` |

## Git

このディレクトリ配下の成果物は **コミットしない**（`.gitignore` で除外）。  
README と ignore だけリポジトリに含める。
