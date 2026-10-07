# Konnect + KiCad 10 回路設計検証環境

このリポジトリは、Konnect(KiCad用MCPサーバ)と KiCad 10 の CLI を 1 つの Docker
イメージに同梱し、**回路図の生成 → ERC → 製造ファイル出力** までをコンテナ内で
完結させるための検証環境です。実案件ではなく、AI支援でどこまで回路設計ができるかを
評価するのが目的です。

同じ中身を Claude Code / Codex のプラグイン `kicad-konnect`
(`plugins/kicad-konnect/`)として配布しています。

## 回路設計の進め方はスキルにある

KiCad / Konnect を使う作業では、まずスキル `kicad-konnect`
(`plugins/kicad-konnect/skills/kicad-konnect/SKILL.md`。`.claude/skills/` から
シンボリックリンクで読み込まれる)を読むこと。できる/できない の線引き、作業ルール、
標準ワークフロー、Konnect の既知の癖はすべてそちらにある。
**知見を追記するときもスキル側(SKILL.md / references/)に書く。** ここに重複させない。

## このリポジトリで作業するときの差分

| 項目 | このリポジトリ | プラグインとして使うとき |
| --- | --- | --- |
| `/work` にマウントされる場所 | `./projects` | 起動したディレクトリ(`KONNECT_PROJECTS` で上書き) |
| MCP 設定 | ルートの `.mcp.json` | プラグインの manifest |
| IPC ソケット / GUI 設定 | `./.kicad-ipc` / `./.kicad-gui-config` | `~/.local/state/konnect-kicad/` |
| スクリプトの呼び方 | `make` 経由 | `<plugin>/scripts/*.sh` |

外部リポジトリの KiCad プロジェクトは `projects/<repo>/` に `git clone` する。
`projects/*/` は外側の `.gitignore` で除外してあり、クローンしたリポジトリは
それ自身の git で管理する(コミットはクローン側に積む)。

## 作業ルール(このリポジトリ固有)

1. **書き込んでよいのは `./projects` 配下のみ。**
   `Dockerfile` / `plugins/` / `.mcp.json` / `.claude-plugin/` / `.agents/` は
   環境定義なので、明示的に依頼されない限り変更しない。
2. スキルの作業ルール(編集前の commit、編集後の ERC など)に従う。

## コマンド

```bash
make pull         # 公開イメージ (ghcr.io/bols-blue/konnect-kicad:10) を取得
make build        # イメージをローカルでビルド(Rust のフルビルドを含むので初回は長い)
make smoke        # kicad-cli / ライブラリ / MCP ハンドシェイクの確認
make shell        # コンテナ内のシェル
make gui PROJECT=/work/demo/demo.kicad_pro   # KiCad GUI (PCB系ツール用)
make gui-stop
make cli ARGS="sch erc --output /work/demo/erc.rpt --exit-code-violations /work/demo/demo.kicad_sch"
```

`make` は環境変数を設定してから `plugins/kicad-konnect/scripts/` を呼ぶ。
スクリプトを直接呼ぶ場合は、リポジトリ直下で
`KONNECT_PROJECTS=projects KONNECT_IPC_DIR=.kicad-ipc` を付けること
(付けないとリポジトリ直下が `/work` になる)。

| 症状 | 対処 |
| --- | --- |
| `make: ターゲット 'gui' を make するルールがありません` | カレントディレクトリが `projects/...` の下になっている。`make -C <リポジトリ直下> gui ...` で実行する |

## 注意

- Konnect は **beta**。実案件のプロジェクトをこの環境に直接マウントしない。
- ライセンスは **AGPL-3.0**。業務利用・社内共有に広げる前に法務確認が必要。
