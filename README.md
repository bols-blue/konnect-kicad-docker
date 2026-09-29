# konnect-kicad-docker

Konnect(KiCad 用 MCP サーバ)と KiCad 10 の CLI を 1 イメージに同梱し、
Claude Code から **回路図生成 → ERC → 製造ファイル出力** まで回すための検証環境。

PCB のインタラクティブ編集(部品配置・配線)は KiCad の GUI プロセスを必要とする。
ローカルのデスクトップ環境では `make gui` で同じイメージの KiCad GUI を X11 転送で
起動し、その IPC ソケットを Konnect と共有することで PCB 系ツールも使える。

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
├── Dockerfile              KiCad 公式イメージ + Konnect ビルド + Freerouting/Java
├── docker-compose.yml      バッチ用ワークベンチ(任意)
├── Makefile                build / smoke / shell
├── .mcp.json               Claude Code 用 MCP 設定
├── CLAUDE.md               Claude Code への作業指示(可否の線引き・ルール・手順)
├── scripts/
│   ├── konnect-mcp.sh      MCP stdio 起動ラッパー
│   ├── kicad-cli.sh        ホストから kicad-cli を叩くラッパー
│   ├── kicad-gui.sh        KiCad GUI を X11 転送で起動 (PCB系ツール用)
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

**PCB 系ツールは GUI 起動中のみ。** Konnect の PCB 編集は KiCad 10 の IPC API
(NNG + protobuf)経由で、KiCad が対象基板を PCB エディタで開いた状態で
動いている必要がある。

```bash
make gui PROJECT=/work/demo/demo.kicad_pro   # KiCad が X11 (Wayland なら XWayland) で開く
# → プロジェクトマネージャで PCB エディタを開く
make gui-stop
```

- IPC ソケットはホストの `./.kicad-ipc` を GUI / Konnect 両コンテナの
  `/tmp/kicad` にマウントして共有する。Konnect には `KICAD_API_SOCKET` で固定パスを渡す
  (Konnect のソケット自動検出は起動時に一度だけなので、GUI を後から起動しても繋がるように)
- GUI の設定は `./.kicad-gui-config` に永続化する。初回だけセットアップウィザードが出る
  (完了するまで IPC サーバが起動しない)
- 公式イメージの GUI 利用はサポート外。フォント・IME・OpenGL で問題が出る可能性がある
- 動作確認済み: 基板情報・レイヤ一覧の読み取り、外形追加、保存(KiCad 10.0.6)。
  フットプリント配置・配線は未検証
- 自動配線は Freerouting 2.3.0(SHA-256 検証済み)+ OpenJDK 25 をイメージに同梱。
  Konnect が headless MCP モードで起動し、DSN → SES をローカルで処理する。
  起動時に GitHub へ新版チェックの通信が出る(`KONNECT_NETWORK=none` なら出ないが部品検索も止まる)
- ヘッドレス環境(SSH 先など)ではこの経路は使えない。回路図と ERC まで作って、
  あとはホストの KiCad に引き継ぐ

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
# Freerouting を上げる場合は Dockerfile の FREEROUTING_VERSION / FREEROUTING_SHA256 を両方更新
```

ビルド済みイメージのバージョンは `make versions` で確認できる。

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `make build` がライブラリ検証で落ちる | KiCad イメージのディレクトリ構成が変わっている。エラー出力の `ls` 結果を見て Dockerfile のパスを修正 |
| Claude Code が konnect を認識しない | `claude mcp list` で状態を確認。`.mcp.json` の相対パスはプロジェクトルート基準。ダメなら `scripts/konnect-mcp.sh` を絶対パスに書き換える |
| `image not found` | `make build` 未実行、または `KONNECT_IMAGE` の値が `.mcp.json` と不一致 |
| ERC でシンボルが軒並み見つからない | `make smoke` の項目 2 を確認。`sym-lib-table=NO` なら Dockerfile の `KICAD_CONFIG_VER` を実際の設定ディレクトリ名に合わせる |
| `IPC connect failed` | KiCad GUI 未起動、または PCB エディタで対象基板を開いていない。`make gui` |
| `make gui` で IPC ソケットが現れない | 初回ウィザードやダイアログで止まっていないか確認。`KONNECT_GUI_DEBUG=1 make gui` で前面実行 |
| Rust ビルドが OOM で落ちる | Docker Desktop のメモリ割り当てを 8 GB 以上に |

## 参考

- Konnect: https://github.com/mixelpixx/Konnect
- KiCad 公式 Docker イメージ: https://www.kicad.org/download/docker/
