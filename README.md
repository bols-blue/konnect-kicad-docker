# konnect-kicad-docker

Konnect(KiCad 用 MCP サーバ)と KiCad 10 の CLI を 1 イメージに同梱し、
Claude Code から **回路図生成 → ERC → 製造ファイル出力** まで回すための検証環境。

PCB のインタラクティブ編集(部品配置・配線)は KiCad の GUI プロセスを必要とする
ため、この環境には含まれない。そこは割り切る構成。

## 前提

- Docker(Compose v2 同梱のもの)
- ディスク空き 10 GB 程度(KiCad 公式イメージ + Rust ビルドキャッシュ)
- Claude Code

## セットアップ

```bash
chmod +x scripts/*.sh
make build     # 初回は Rust のフルビルドを含むため時間がかかる
make smoke     # 疎通確認
```

`make smoke` が全項目 OK になったら、このディレクトリで Claude Code を起動する。
`.mcp.json` がプロジェクトスコープの MCP 設定として読み込まれ、`konnect` サーバが
使えるようになる(初回は MCP サーバの承認プロンプトが出る)。

```bash
claude
```

Claude Code 側の動き方は `CLAUDE.md` に書いてある。これが本体。

## ディレクトリ

```
.
├── Dockerfile              KiCad 公式イメージ + Konnect ビルド
├── docker-compose.yml      バッチ用ワークベンチ(任意)
├── Makefile                build / smoke / shell
├── .mcp.json               Claude Code 用 MCP 設定
├── CLAUDE.md               Claude Code への作業指示(可否の線引き・ルール・手順)
├── scripts/
│   ├── konnect-mcp.sh      MCP stdio 起動ラッパー
│   ├── kicad-cli.sh        ホストから kicad-cli を叩くラッパー
│   └── smoke-test.sh       疎通確認
└── projects/               作業領域。コンテナの /work にマウントされる
```

**ホストの `./projects` がコンテナの `/work`。** Konnect に渡すパスは常に
`/work/...` 形式にする。

## 設計上のポイント

**ランタイムに KiCad 公式イメージを使っている。** 公式イメージは kicad-cli 利用を
想定して配布されており、GUI 用途はサポート対象外と明示されている。この環境は
まさに CLI だけを使うので用途が一致する。

**Konnect はソースからビルドしている。** 配布バイナリは Windows / macOS 向けで、
Linux は公式にはロードマップ段階(コード自体は 3 プラットフォームで CI を通過)。
ビルダーステージをランタイムと同じ Debian bookworm 系に揃えて glibc 不一致を避けている。

**グローバル `sym-lib-table` をイメージに焼いてある。** コンテナは毎回まっさらな
HOME で起動するため、これが無いとシンボル解決に失敗して ERC が通らない。
`make smoke` の項目 2 がここを見ている。

**コンテナは呼び出し元の UID で起動する。** ラッパースクリプトが
`--user $(id -u):$(id -g)` を渡しているので、`./projects` に root 所有の
ファイルが生えない。

## 事前に把握しておくべき制約

**PCB レイアウトはできない。** Konnect の PCB 編集は KiCad 10 の IPC API
(NNG + protobuf)経由で、KiCad が対象基板を開いた状態で動いている必要がある。
GUI を Docker で動かすのはサポート外なので、この環境では配置・配線・ゾーンは
一切触れない。回路図と ERC まで作って、あとはホストの KiCad に引き継ぐ。

**Konnect は beta。** コアのツールチェーンは動作確認済みだが若いリリースで、
実地での検証を求めている段階。回路図ファイルを直接書き換えるので、必ず git 管理下の
コピーに対して使うこと。実案件のディレクトリを `./projects` にマウントしない。

**ライセンスは AGPL-3.0。** ホビイスト・学生・フリーランス・OSS は自由に使える一方、
企業の場合は Konnect の上や周辺に作ったものが、ネットワーク越しに提供する
ソフトウェアも含めて同ライセンスでのオープンソース化を要求される。商用ライセンスも
別途用意されている。個人の評価で閉じるなら問題にならないが、社内共有や業務利用に
広げる前に法務確認を入れること(法的判断は専門家に)。

**HTTP モードは有効にしていない。** Konnect のサーバには認証が無く、ツールは
ファイルを編集し kicad-cli を実行するため、上流でも compose はループバック限定で
公開している。この構成では stdio のみにしている。必要になったら認証付きの
リバースプロキシを前段に置き、`0.0.0.0` に素で公開しないこと。

## バージョン固定

再現性が要るなら以下を固定する。

```bash
make build KICAD_TAG=10.0.5 KONNECT_REF=<タグ or コミットSHA>
```

ビルド済みイメージのバージョンは `make versions` で確認できる。

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `make build` がライブラリ検証で落ちる | KiCad イメージのディレクトリ構成が変わっている。エラー出力の `ls` 結果を見て Dockerfile のパスを修正 |
| Claude Code が konnect を認識しない | `claude mcp list` で状態を確認。`.mcp.json` の相対パスはプロジェクトルート基準。ダメなら `scripts/konnect-mcp.sh` を絶対パスに書き換える |
| `image not found` | `make build` 未実行、または `KONNECT_IMAGE` の値が `.mcp.json` と不一致 |
| ERC でシンボルが軒並み見つからない | `make smoke` の項目 2 を確認。`sym-lib-table=NO` なら Dockerfile の `KICAD_CONFIG_VER` を実際の設定ディレクトリ名に合わせる |
| `IPC connect failed` | PCB 系ツール。この環境では実行不可(仕様) |
| Rust ビルドが OOM で落ちる | Docker Desktop のメモリ割り当てを 8 GB 以上に |

## 参考

- Konnect: https://github.com/mixelpixx/Konnect
- KiCad 公式 Docker イメージ: https://www.kicad.org/download/docker/
