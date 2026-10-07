---
name: kicad-konnect
description: Konnect(KiCad 用 MCP サーバ)と Docker 上の KiCad 10 CLI で回路設計を進める手順と注意点。KiCad の回路図(.kicad_sch)の作成・編集、ERC / DRC、Gerber・BOM・PDF などの製造ファイル出力、PCB の部品配置や自動配線(Freerouting)、既存 KiCad プロジェクトの取り込みを頼まれたとき、または konnect の MCP ツールを使うときに必ず読むこと。
---

# Konnect + KiCad 10 で回路設計する

Konnect(KiCad 用 MCP サーバ、MCP サーバ名 `konnect`)と KiCad 10 の CLI を同じ
Docker イメージ `konnect-kicad:10` で動かし、**回路図の生成 → ERC → 製造ファイル出力**
までを進める。

## 場所とパス

- 作業領域(ホスト)がコンテナの `/work` にマウントされる。既定は AI エージェントを
  起動したディレクトリで、環境変数 `KONNECT_PROJECTS` で上書きできる。
  起動時のログ(stderr)に `konnect: /work = <ホストのパス>` と出る
- **Konnect のツールと kicad-cli に渡すパスは常にコンテナ側の `/work/...`。**
  ホストの絶対パスはコンテナから見えない
- 同梱スクリプトはプラグインの `scripts/` にある。この SKILL.md のあるディレクトリから
  見て `../../scripts/`。このスキルのディレクトリ: `${CLAUDE_SKILL_DIR}`
  (Claude Code では絶対パスに置き換わる。置き換わっていなければ SKILL.md を読み込んだ
  パスから求める)。以下、`<scripts>` と書く。探し回らずにこの規則で決めること
  - `<scripts>/kicad-cli.sh` … コンテナ内の kicad-cli を呼ぶ
  - `<scripts>/kicad-gui.sh` … KiCad GUI を X11 転送で起動(PCB 系ツール用)
  - `<scripts>/smoke-test.sh` … 環境の疎通確認
- スクリプトは MCP サーバと同じ規則で作業領域を決めるので、エージェントを起動した
  ディレクトリで実行すれば同じ `/work` になる
- MCP ツール名の前置詞はクライアントで違う(例: Claude Code のプラグインでは
  `mcp__plugin_kicad-konnect_konnect__open_project`)。本文ではツール名だけを書く

初回やエラー時の環境構築は [references/setup.md](references/setup.md)。

## できること / できないこと

この区別を誤ると延々と失敗するので、作業前に必ず確認すること。

| 機能 | 可否 | 根拠 |
| --- | --- | --- |
| 回路図の作成・部品配置・結線 | **可** | Konnect は `.kicad_sch` を S式で直接編集する。KiCad 本体不要 |
| ERC | **可** | `kicad-cli` がイメージに入っている |
| DRC | **可** | 同上。ただし対象の `.kicad_pcb` が既に存在する場合のみ |
| Gerber / ドリル / BOM / PDF / STEP 出力 | **可** | `kicad-cli` 経由 |
| PCB の基板情報・レイヤ・外形の読み書き | **可(GUI 起動時)** | IPC 経由。`get_board_info` / `get_layer_list` / `add_board_outline` / `save_project` で動作確認済み |
| 回路図 → PCB 反映 | **可(GUI 起動時)** | `update_pcb_from_schematic`(dry run → apply)。フットプリント種別の変更は競合になるので、基板側を `delete_component` してから再反映する |
| PCB のフットプリント配置・移動・回転 | **可(GUI 起動時)** | `set_component_placements` で確認済み |
| 自動配線: DSN 出力 | **可(GUI 起動時)** | `export_specctra_dsn_native`(イメージに当てたローカルパッチ `patches/konnect/`)。KiCad 自身の Specctra 出力を ActionPlugin ブリッジ経由で呼ぶので roundrect / oval / NPTH / 円弧外形も可。Konnect 本来の `export_specctra_dsn` は circle / rect パッドのみ |
| 自動配線: Freerouting (DSN → SES) | **可** | `route_specctra_dsn`。KiCad 本体が出力した DSN も可 |
| 自動配線: SES 取り込み | **可(GUI 起動時)** | `import_specctra_ses_native`(同パッチ)。DSN 出力時の基板ハッシュと一致しないと拒否する(GUI で先に取り込んだ場合など)。取り込み後は `refill_zones` → `save_project` → DRC。`plan_specctra_ses_import` / `apply_specctra_ses` は Konnect 本来の DSN 専用 |
| 配線の個別編集(トラック/ビア/ゾーン) | **可(GUI 起動時)・未検証** | 同じ IPC 経路。ビアを削除するツールは無い |
| ライブ回路図ビューア | **不可** | システム WebView 依存でコンテナでは動かない |

PCB 系(「GUI 起動時」の行)を触る前に [references/pcb-ipc.md](references/pcb-ipc.md) を読む。

## 作業ルール

1. **書き込むのは作業領域(`/work`)配下のみ。** プラグインのファイルは変更しない。
2. **回路図を編集する前に git commit する。** Konnect は `.kicad_sch` を直接書き換える。
   beta 版なので破壊に備えて各編集バッチの前にコミットし、差分で何が変わったか
   確認できるようにする。作業領域が git 管理下でなければ、始める前に利用者に確認する。
3. **編集したら必ず ERC を通す。** 目視やツールの戻り値だけで「できた」と判断しない。
   ERC が通って初めて 1 サイクル完了とみなす。
4. **ツールセットは必要なものだけロードする。** Konnect は起動時に小さなスターター
   キットだけを出し、残りはツールセット単位でオンデマンドに読み込むルータ方式。
   作業に関係ないツールセット(製造エクスポート、部品検索など)を先読みしない。
5. **ツール名を記憶や推測で呼ばない。** 未知の操作が必要になったら、まずツール一覧
   またはツールセット一覧(`list_toolboxes` など)を取得してから呼ぶ。存在しないツール名で
   失敗したら、ファイル直接編集にフォールバックせず一覧を取り直す。
6. **部品値・型番は必ず根拠を示す。** 「たぶんこれ」で抵抗値やコンデンサ容量を
   決めない。計算式かデータシートの記載を添える。AI は回路まわりで思い込みの
   回答をしやすいという前提で、利用者がレビューできる形にする。

## 標準ワークフロー

```
1. 要件を docs/<name>-spec.md に書き出して利用者に確認を取る
   (電源電圧、消費電流、インタフェース、外形制約、想定製造先)
2. git commit  ← 編集前スナップショット
3. Konnect で /work/<name>/ にプロジェクトを作成
4. Konnect で回路図を生成(電源 → MCU → 周辺 の順、ブロックごとに小さく)
5. ERC 実行 → 違反を潰す → ERC が通るまで 4-5 を反復
6. 結果を利用者に提示(何を作ったか、ERC の結果、未解決の懸念)
7. 必要なら回路図 PDF / BOM を出力
8. PCB が必要な場合: 利用者に kicad-gui.sh で PCB エディタを開いてもらい、
   IPC 経由で編集 → save_project → DRC。GUI が無ければここで停止して引き継ぐ
```

各サイクルの終わりに、次の 3 点を必ず報告する。

- 変更したファイル
- ERC の結果(違反数と内訳)
- 自信のない設計判断(部品選定、値の根拠が弱い箇所)

既存の KiCad プロジェクトを扱うときは、編集の前に
[references/import-existing.md](references/import-existing.md) の手順で整える。
回路図・シンボルライブラリまわりで想定外の挙動に当たったら
[references/schematic-quirks.md](references/schematic-quirks.md) を見る。

## kicad-cli

```bash
<scripts>/kicad-cli.sh version

# ERC(違反があれば非ゼロ終了)
<scripts>/kicad-cli.sh sch erc \
  --output /work/demo/erc.rpt \
  --exit-code-violations \
  /work/demo/demo.kicad_sch

# 回路図 PDF
<scripts>/kicad-cli.sh sch export pdf \
  --output /work/demo/demo-sch.pdf \
  /work/demo/demo.kicad_sch

# DRC(.kicad_pcb がある場合)。回路図との整合も見るなら --schematic-parity
<scripts>/kicad-cli.sh pcb drc \
  --output /work/demo/drc.rpt \
  --exit-code-violations \
  /work/demo/demo.kicad_pcb

# Gerber + ドリル
<scripts>/kicad-cli.sh pcb export gerbers --output /work/demo/fab /work/demo/demo.kicad_pcb
<scripts>/kicad-cli.sh pcb export drill   --output /work/demo/fab/ /work/demo/demo.kicad_pcb
```

サブコマンドの正確なオプションは `<scripts>/kicad-cli.sh sch erc --help` のように
`--help` で確認する。KiCad のバージョンによって差異がある。

kicad-cli.sh は `docker run` を実行する。シェルのサンドボックスがある環境
(Codex など)で Docker ソケットへのアクセスが拒否されたら、サンドボックス外での
実行の承認を利用者に求める。

症状別の対処は [references/troubleshooting.md](references/troubleshooting.md)。

## 注意

- Konnect は **beta**。実案件のプロジェクトを直接作業領域にしない。git 管理下のコピーで使う。
- Konnect のライセンスは **AGPL-3.0**。業務利用・社内共有に広げる前に法務確認が必要。
