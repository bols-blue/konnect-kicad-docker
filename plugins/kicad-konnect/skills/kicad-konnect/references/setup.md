# 環境構築と疎通確認

## 前提

- Docker、Linux x86_64(KiCad 公式イメージが amd64 のみ)
- ディスク空き 3 GB 程度
- PCB 系ツールを使う場合は X11 / XWayland のあるデスクトップセッション

## イメージの取得

MCP サーバが `image 'konnect-kicad:10' not found` で起動しないときは、公開イメージを
取得してタグを付ける(利用者に実行してもらうか、承認を得てから実行する)。

```bash
docker pull ghcr.io/bols-blue/konnect-kicad:10
docker tag ghcr.io/bols-blue/konnect-kicad:10 konnect-kicad:10
```

自前でビルドする場合は https://github.com/bols-blue/konnect-kicad-docker を clone して
`make build`。別名のイメージを使うときは `KONNECT_IMAGE` で指定する。

イメージを入れたあとは MCP サーバの再接続(Claude Code なら `/mcp`、Codex なら再起動)が要る。

## 疎通確認

```bash
<scripts>/smoke-test.sh
```

確認する項目:

1. kicad-cli が動く
2. シンボルライブラリとグローバル lib-table がイメージ内に見えている
3. Konnect が MCP の initialize / tools/list に応答する

## 環境変数

| 変数 | 既定 | 意味 |
| --- | --- | --- |
| `KONNECT_PROJECTS` | エージェントを起動したディレクトリ | コンテナの `/work` にマウントする作業領域 |
| `KONNECT_IMAGE` | `konnect-kicad:10` | 使うイメージ |
| `KONNECT_NETWORK` | `bridge` | `none` にすると隔離度は上がるが、JLCPCB 部品検索や Freerouting の新版チェックなど外部アクセスを伴うツールは失敗する |
| `KONNECT_IPC_DIR` | `~/.local/state/konnect-kicad/ipc` | KiCad GUI と Konnect が共有する IPC ソケットの置き場 |
| `KONNECT_GUI_CONFIG` | `~/.local/state/konnect-kicad/gui-config` | KiCad GUI の設定の永続化先 |

作業領域がホームディレクトリ直下や `/`、プラグイン自身の中になる場合、スクリプトは
起動を拒否する。そのときは `KONNECT_PROJECTS` に作業ディレクトリの絶対パスを設定する。

Codex は MCP サーバをプラグインのディレクトリで起動するため、起動ディレクトリを
既定にできない。Codex では `KONNECT_PROJECTS` を設定してから起動する。

## KiCad GUI(PCB 系ツール用)

```bash
<scripts>/kicad-gui.sh /work/<name>/<name>.kicad_pro   # 起動して PCB エディタを開く
<scripts>/kicad-gui.sh --stop                          # 停止
```

- 初回だけ KiCad のセットアップウィザードが出る。完了するまで IPC サーバが起動しない
- 前面で起動してログを見るときは `KONNECT_GUI_DEBUG=1`
- GUI の起動・操作は人間が行う。エージェントは起動コマンドを案内するだけにする
