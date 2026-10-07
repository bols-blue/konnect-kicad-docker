# konnect-kicad-docker

[![image](https://github.com/bols-blue/konnect-kicad-docker/actions/workflows/image.yml/badge.svg)](https://github.com/bols-blue/konnect-kicad-docker/actions/workflows/image.yml)

Konnect(KiCad 用 MCP サーバ)と KiCad 10 の CLI を 1 イメージに同梱し、
Claude Code から **回路図生成 → ERC → 製造ファイル出力** まで回すための検証環境。

PCB のインタラクティブ編集(部品配置・配線)は KiCad の GUI プロセスを必要とする。
ローカルのデスクトップ環境では `make gui` で同じイメージの KiCad GUI を X11 転送で
起動し、その IPC ソケットを Konnect と共有することで PCB 系ツールも使える。

## 使い方(Claude Code)

プラグイン `kicad-konnect` として入れると、どのディレクトリでも使える。

```bash
# 1. Docker イメージを取得 (初回のみ)
docker pull ghcr.io/bols-blue/konnect-kicad:10
docker tag ghcr.io/bols-blue/konnect-kicad:10 konnect-kicad:10

# 2. プラグインをインストール (Claude Code 内の /plugin からでも可)
claude plugin marketplace add bols-blue/konnect-kicad-docker
claude plugin install kicad-konnect@konnect-kicad

# 3. 作業ディレクトリで起動 (このディレクトリがコンテナの /work になる)
mkdir -p ~/kicad-work && cd ~/kicad-work && git init
claude
```

1. `/mcp` で `plugin:kicad-konnect:konnect` が connected になっていることを確認する
2. 「/work/demo に KiCad プロジェクトを作って、抵抗を 1 つ置いて ERC して」のように頼む
   - KiCad の話をすればスキルは自動で読み込まれる
   - `/kicad-konnect:kicad-konnect` で明示的に呼ぶこともできる

**作業領域の指定:**
- `/work` にする場所は `KONNECT_PROJECTS=/path/to/dir claude` で変えられる
- ホームディレクトリ直下や `/` で起動すると、安全のため konnect は起動しない

**PCB 編集・自動配線(GUI が必要):** 次の順で操作する。起動コマンドは Claude に聞けば、インストール先のパスで教えてくれる。
1. プラグインの `scripts/kicad-gui.sh /work/<name>/<name>.kicad_pro` で KiCad GUI を起動する
2. PCB エディタで基板を開く
3. `/mcp` で konnect を再接続する
   - native Specctra ブリッジ(自動配線用の DSN 出力・SES 取り込み)を使うときは必須
   - GUI を起動し直したら、再接続もやり直す

**更新:** `claude plugin marketplace update konnect-kicad` のあと、プラグインを入れ直す。

**このリポジトリの中ではプラグインは不要:**
- ルートの `.mcp.json` とスキルへのリンクで動く(`/work` は `./projects`)
- プラグインを入れたままここで起動すると konnect が 2 つ立つので、`/plugin` で無効にする

Codex で使う場合や、構成の詳細は後述の「プラグインとして使う」を参照。

## 前提

- Docker(Compose v2 同梱のもの)、Linux x86_64(KiCad 公式イメージが amd64 のみ)
- ディスク空き 3 GB 程度(公開イメージを使う場合)/ 10 GB 程度(自前ビルドの場合)
- Claude Code

## セットアップ

公開イメージを使う(推奨):

```bash
make pull      # ghcr.io/bols-blue/konnect-kicad:10 を取得し konnect-kicad:10 としてタグ付け
make smoke     # 疎通確認
```

自前でビルドする:

```bash
make build     # 初回は Rust のフルビルドを含むため時間がかかる
make smoke
```

`make smoke` が全項目 OK になったら、このディレクトリで Claude Code を起動する。
`.mcp.json` がプロジェクトスコープの MCP 設定として読み込まれ、`konnect` サーバが
使えるようになる(初回は MCP サーバの承認プロンプトが出る)。

```bash
claude
```

Claude Code 側の動き方はスキル `plugins/kicad-konnect/skills/kicad-konnect/` に
書いてある(このリポジトリでは `.claude/skills/` から読み込まれる)。これが本体。
リポジトリ固有の約束は `CLAUDE.md`。

## プラグインとして使う(Claude Code / Codex)

このリポジトリは Claude Code と Codex のプラグインマーケットプレイスを兼ねている。
プラグイン `kicad-konnect` を入れると、どのディレクトリでもスキルと `konnect`
MCP サーバが使える。Docker イメージは別途必要(上の `make pull`、または
`docker pull ghcr.io/bols-blue/konnect-kicad:10 && docker tag ghcr.io/bols-blue/konnect-kicad:10 konnect-kicad:10`)。

Claude Code:

```bash
claude plugin marketplace add bols-blue/konnect-kicad-docker
claude plugin install kicad-konnect@konnect-kicad
```

Codex:

```bash
codex plugin marketplace add bols-blue/konnect-kicad-docker
# Codex の /plugins から kicad-konnect をインストール
```

**`/work` にマウントされるのはエージェントを起動したディレクトリ。** 環境変数
`KONNECT_PROJECTS` で上書きできる。ホームディレクトリ直下や `/` では安全のため
起動を拒否する。

- Claude Code: 起動ディレクトリ(`CLAUDE_PROJECT_DIR`)が既定
- Codex: MCP サーバがプラグインのディレクトリで起動されるため、起動ディレクトリを
  知る手段が無い。**`KONNECT_PROJECTS` の設定が必須**
  (例: `KONNECT_PROJECTS=$PWD codex`)。
  シェルのサンドボックスが Docker ソケットを塞ぐ
  (`permission denied while trying to connect to the docker API`、codex-cli 0.160.1 で確認)。
  `kicad-cli.sh` の実行時にサンドボックス外での実行を承認する
- Codex: konnect の MCP ツール呼び出しには承認が要る。`codex exec`(非対話)では
  承認できず `MCP tool call requires approval, but approval policy is never` で失敗する。
  `default_tools_approval_mode = "auto"` を設定しても変わらなかった。対話モードで使うこと

| 構成要素 | 場所 |
| --- | --- |
| Claude Code の manifest(MCP 設定込み) | `plugins/kicad-konnect/.claude-plugin/plugin.json` |
| Codex の manifest / MCP 設定 | `plugins/kicad-konnect/.codex-plugin/plugin.json` / `codex-mcp.json` |
| スキル | `plugins/kicad-konnect/skills/kicad-konnect/` |
| マーケットプレイス | `.claude-plugin/marketplace.json`(Claude Code)/ `.agents/plugins/marketplace.json`(Codex) |

IPC ソケットと GUI 設定は `~/.local/state/konnect-kicad/` に置く
(`KONNECT_IPC_DIR` / `KONNECT_GUI_CONFIG` で変更可)。

## ディレクトリ

```
.
├── Dockerfile              KiCad 公式イメージ + Konnect ビルド + Freerouting/Java
├── docker-compose.yml      バッチ用ワークベンチ(任意)
├── Makefile                pull / build / smoke / shell / gui
├── .github/workflows/      イメージのビルド・smoke test・GHCR 公開
├── .mcp.json               このリポジトリで作業するときの MCP 設定
├── CLAUDE.md               このリポジトリ固有の約束
├── .claude-plugin/         Claude Code のマーケットプレイス定義
├── .agents/plugins/        Codex のマーケットプレイス定義
├── .claude/skills/         スキルへのシンボリックリンク
├── plugins/kicad-konnect/  プラグイン本体
│   ├── .claude-plugin/     Claude Code の manifest
│   ├── .codex-plugin/      Codex の manifest (+ codex-mcp.json)
│   ├── skills/kicad-konnect/  スキル(可否の線引き・ルール・手順・既知の癖)
│   └── scripts/
│       ├── _env.sh         作業領域・IPC の場所の決定(共通)
│       ├── konnect-mcp.sh  MCP stdio 起動ラッパー
│       ├── kicad-cli.sh    ホストから kicad-cli を叩くラッパー
│       ├── kicad-gui.sh    KiCad GUI を X11 転送で起動 (PCB系ツール用)
│       └── smoke-test.sh   疎通確認
└── projects/               作業領域。make / .mcp.json 経由ではコンテナの /work にマウントされる
```

**このリポジトリでは、ホストの `./projects` がコンテナの `/work`。** Konnect に渡すパスは常に
`/work/...` 形式にする。

既存の KiCad プロジェクトを試すときは `projects/` の下に `git clone` する。
`projects/*/` はこのリポジトリの `.gitignore` で除外しているので、クローンした
リポジトリはそれ自身の git で管理する。ライブラリの絶対パスや KiCad 6 以前の
ファイル形式など、取り込み時に直すべき点はスキルの `references/import-existing.md` にまとめてある。

```bash
cd projects && git clone <repo-url>
```

## 設計上のポイント

**ランタイムに KiCad 公式イメージを使っている。** 公式イメージは kicad-cli 利用を
想定して配布されており、GUI 用途はサポート対象外と明示されている。この環境は
まさに CLI だけを使うので用途が一致する。

**Konnect はソースからビルドしている。** 配布バイナリは Windows / macOS 向けで、
Linux は公式にはロードマップ段階(コード自体は 3 プラットフォームで CI を通過)。
ビルダーはランタイム (Debian 13 trixie) より古い bookworm にして、新しい glibc 上で
そのまま動くバイナリにしている。

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

- IPC ソケットはホストの `./.kicad-ipc`(プラグインとして使うときは `~/.local/state/konnect-kicad/ipc`)を GUI / Konnect 両コンテナの
  `/tmp/kicad` にマウントして共有する。Konnect には `KICAD_API_SOCKET` で固定パスを渡す
  (Konnect のソケット自動検出は起動時に一度だけなので、GUI を後から起動しても繋がるように)
- GUI の設定は `./.kicad-gui-config`(プラグインでは `~/.local/state/konnect-kicad/gui-config`)に永続化する。初回だけセットアップウィザードが出る
  (完了するまで IPC サーバが起動しない)
- 公式イメージの GUI 利用はサポート外。フォント・IME・OpenGL で問題が出る可能性がある
- 動作確認済み: 回路図 → PCB 反映、フットプリント配置、外形追加、保存、
  DSN 出力 → Freerouting → SES 取り込み → DRC の通し(THT 部品の基板)。
  SMD 受動部品 (roundrect パッド) は Konnect が DSN 出力を拒否するので、
  DSN 出力と SES 取り込みは GUI で人が行う。詳細はスキルの可否表
- 自動配線は Freerouting 2.3.0(SHA-256 検証済み)+ OpenJDK 25 をイメージに同梱。
  Konnect が headless MCP モードで起動し、DSN → SES をローカルで処理する。
  起動時に GitHub へ新版チェックの通信が出る(`KONNECT_NETWORK=none` なら出ないが部品検索も止まる)
- ヘッドレス環境(SSH 先など)ではこの経路は使えない。回路図と ERC まで作って、
  あとはホストの KiCad に引き継ぐ

**Konnect は beta。** コアのツールチェーンは動作確認済みだが若いリリースで、
実地での検証を求めている段階。回路図ファイルを直接書き換えるので、必ず git 管理下の
コピーに対して使うこと。実案件のディレクトリを `./projects` にマウントしない。

**Konnect のライセンスは AGPL-3.0。** ホビイスト・学生・フリーランス・OSS は自由に使える一方、
企業の場合は Konnect の上や周辺に作ったものが、ネットワーク越しに提供する
ソフトウェアも含めて同ライセンスでのオープンソース化を要求される。商用ライセンスも
別途用意されている。個人の評価で閉じるなら問題にならないが、社内共有や業務利用に
広げる前に法務確認を入れること(法的判断は専門家に)。

**HTTP モードは有効にしていない。** Konnect のサーバには認証が無く、ツールは
ファイルを編集し kicad-cli を実行するため、上流でも compose はループバック限定で
公開している。この構成では stdio のみにしている。必要になったら認証付きの
リバースプロキシを前段に置き、`0.0.0.0` に素で公開しないこと。

## バージョン

中身のバージョンは Dockerfile の `ARG` 既定値で固定している(動作検証済みの組み合わせ)。

| 部品 | バージョン | 定義 |
| --- | --- | --- |
| KiCad | 10.0.6 | `KICAD_TAG` |
| Konnect | `9d582b6` (0.12.1) | `KONNECT_REF`(ブランチ・タグ・SHA いずれも可) |
| Freerouting | 2.3.0 | `FREEROUTING_VERSION` / `FREEROUTING_SHA256` |
| OpenJDK | 25 (Debian パッケージ) | Dockerfile |

別の組み合わせを試す場合:

```bash
make build KICAD_TAG=10.0.7 KONNECT_REF=<タグ or コミットSHA>
make smoke
```

検証できたら Dockerfile の既定値を更新して main に push すると、GitHub Actions が
smoke test を通したうえで GHCR に公開する。ビルド済みイメージのバージョンは
`make versions` で確認できる。

## 公開イメージ

`ghcr.io/bols-blue/konnect-kicad` に以下のタグで公開している
(`.github/workflows/image.yml`)。

| タグ | 内容 |
| --- | --- |
| `10` | main の最新 |
| `kicad<ver>-konnect<sha7>` | 中身のバージョンで固定したい場合 |
| `sha-<sha7>` | このリポジトリのコミット |
| `v*` | リリースタグ |

## 同梱ソフトウェアのライセンスとソース

イメージは以下を再配布している。いずれもソースは上流で公開されており、
同梱したバージョンは上の表とイメージのラベル(`docker inspect`)で特定できる。

| 部品 | ライセンス | ソース |
| --- | --- | --- |
| Konnect | AGPL-3.0-only | https://github.com/mixelpixx/Konnect (該当コミットは `/etc/konnect-commit.txt`) |
| KiCad | GPL-3.0-or-later | https://gitlab.com/kicad/code/kicad (ベースイメージ `kicad/kicad`) |
| Freerouting | GPL-3.0 | https://github.com/freerouting/freerouting |
| OpenJDK | GPL-2.0 with Classpath Exception | Debian パッケージ `openjdk-25-jre-headless` |
| Debian ベースの各パッケージ | 各パッケージによる | `apt-get source` で取得可 |

このリポジトリ自体(Dockerfile・スクリプト・ドキュメント)には上記のコードは含まれない。

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `make build` がライブラリ検証で落ちる | KiCad イメージのディレクトリ構成が変わっている。エラー出力の `ls` 結果を見て Dockerfile のパスを修正 |
| Claude Code が konnect を認識しない | `claude mcp list` で状態を確認。`.mcp.json` の相対パスはプロジェクトルート基準。ダメなら `plugins/kicad-konnect/scripts/konnect-mcp.sh` を絶対パスに書き換える |
| `image not found` | `make pull` / `make build` 未実行、または `KONNECT_IMAGE` の値が `.mcp.json` と不一致 |
| ERC でシンボルが軒並み見つからない | `make smoke` の項目 2 を確認。`sym-lib-table=NO` なら Dockerfile の `KICAD_CONFIG_VER` を実際の設定ディレクトリ名に合わせる |
| `IPC connect failed` | KiCad GUI 未起動、または PCB エディタで対象基板を開いていない。`make gui`。プラグインとこのリポジトリの `.mcp.json` では IPC の置き場が違うので、GUI も同じ側から起動する |
| `make gui` で IPC ソケットが現れない | 初回ウィザードやダイアログで止まっていないか確認。`KONNECT_GUI_DEBUG=1 make gui` で前面実行 |
| `make` が「ターゲットを make するルールがありません」 | `projects/` の下で実行している。`make -C <このリポジトリ> gui ...` |
| クローンしたプロジェクトで ERC がライブラリ不足で大量に落ちる | プロジェクトの `sym-lib-table` / `fp-lib-table` がホストの絶対パスを指している。ライブラリをプロジェクト内にコピーし `${KIPRJMOD}` 基準にする |
| Konnect の回路図編集が `stale_target` で拒否される | KiCad 6 以前の回路図。KiCad GUI で開いて保存する(`kicad-cli sch upgrade` では直らない) |
| Rust ビルドが OOM で落ちる | Docker Desktop のメモリ割り当てを 8 GB 以上に |

## 参考

- Konnect: https://github.com/mixelpixx/Konnect
- KiCad 公式 Docker イメージ: https://www.kicad.org/download/docker/
