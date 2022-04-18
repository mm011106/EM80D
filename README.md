# EM-80D/R CPLDコード

## 概要
- 動作開始時にトリガ前のタイミングでch0をドライブする、というバグがあり、それに対処
- 修正の内容については下記URL参照

EM80DのリポジトリISSUE:　[動作開始時に0chに不要なバーストが出る #1](https://github.com/mm011106/EM80D/issues/1)

Notion:　 [リファクタリングメモ](https://www.notion.so/HDL-2f2262ee2c774f51907b1a7b961988f4)

## 仕様
- 5ch, 24波バースト（マーカコイルドライバの標準仕様）
- SYNC = CH0,　第0波で、1波分アサート

## 対応デバイス
- MAX V 5M80ZT100
