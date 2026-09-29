# Konnect + KiCad 10 回路設計検証環境

このリポジトリは、Konnect(KiCad用MCPサーバ)と KiCad 10 の CLI を 1 つの Docker
イメージに同梱し、**回路図の生成 → ERC → 製造ファイル出力** までをコンテナ内で
完結させるための検証環境です。実案件ではなく、AI支援でどこまで回路設計ができるかを
評価するのが目的です。

## 構成

| 要素 | 実体 |
| --- | --- |
| MCPサーバ | `konnect` (Rust 単一バイナリ / stdio) |
| 実行環境 | Docker イメージ `konnect-kicad:10` (KiCad 公式イメージ + konnect) |
| 作業領域 | ホスト `./projects` ⇔ コンテナ `/work` |
| 検証手段 | コンテナ内の `kicad-cli` (ERC / DRC / 各種エクスポート) |

**パスは常にコンテナ側の `/work/...` で指定すること。** ホストの絶対パスを
Konnect のツールに渡してもコンテナからは見えない。

## できること / できないこと

この区別を誤ると延々と失敗するので、作業前に必ず確認すること。

| 機能 | 可否 | 根拠 |
| --- | --- | --- |
| 回路図の作成・部品配置・結線 | **可** | Konnect は `.kicad_sch` を S式で直接編集する。KiCad 本体不要 |
| ERC | **可** | `kicad-cli` がイメージに入っている |
| DRC | **可** | 同上。ただし対象の `.kicad_pcb` が既に存在する場合のみ |
| Gerber / ドリル / BOM / PDF / STEP 出力 | **可** | `kicad-cli` 経由 |
| PCB のフットプリント配置・移動・回転 | **不可** | KiCad 10 の IPC API 経由で、GUI が起動している必要がある |
| 配線(トラック/ビア/ゾーン)の編集 | **不可** | 同上 |
| Freerouting による自動配線 | **不可** | PCB編集に依存 |
| ライブ回路図ビューア | **不可** | システム WebView 依存でコンテナでは動かない |

### PCB系ツールを呼んだ場合

`IPC connect failed` 等のエラーが返る。**この場合はリトライしないこと。**
別のパラメータを試したり、ファイルを手で書き換えて回避しようとしたりせず、
作業を中断してユーザーに「この操作はコンテナ環境では実行できない」と報告する。
PCB レイアウトが必要なら、生成物をホストの KiCad 10 で開いて人間が行う。

## 作業ルール

1. **書き込んでよいのは `/work` (= `./projects`) 配下のみ。**
   リポジトリ直下の `Dockerfile` / `scripts/` / `.mcp.json` は環境定義なので、
   明示的に依頼されない限り変更しない。

2. **回路図を編集する前に git commit する。**
   Konnect は `.kicad_sch` を直接書き換える。beta 版なので破壊に備えて
   各編集バッチの前にコミットしておき、差分で何が変わったか確認できるようにする。

3. **編集したら必ず ERC を通す。** 目視やツールの戻り値だけで「できた」と判断しない。
   ERC が通って初めて 1 サイクル完了とみなす。

4. **ツールセットは必要なものだけロードする。**
   Konnect は全ツールを一度に露出させるとコンテキストを大量に消費するため、
   起動時は小さなスターターキットのみを読み込み、必要に応じてツールセットを
   オンデマンドで引き込むルータ方式になっている。作業に関係ないツールセット
   (製造エクスポート、部品検索など)を先読みしない。

5. **ツール名を記憶や推測で呼ばない。** 未知の操作が必要になったら、まず
   ツール一覧またはツールセット一覧を取得してから呼ぶ。存在しないツール名で
   失敗した場合は、ファイル直接編集にフォールバックせず一覧を取り直す。

6. **部品値・型番は必ず根拠を示す。** 「たぶんこれ」で抵抗値やコンデンサ容量を
   決めない。計算式かデータシートの記載を添える。AI は回路まわりで思い込みの
   回答をしやすいという前提で、ユーザーがレビューできる形にする。

## 標準ワークフロー

```
1. 要件を docs/<name>-spec.md に書き出してユーザーに確認を取る
   (電源電圧、消費電流、インタフェース、外形制約、想定製造先)
2. git commit  ← 編集前スナップショット
3. Konnect で /work/<name>/ にプロジェクトを作成
4. Konnect で回路図を生成(電源 → MCU → 周辺 の順、ブロックごとに小さく)
5. ERC 実行 → 違反を潰す → ERC が通るまで 4-5 を反復
6. 結果をユーザーに提示(何を作ったか、ERCの結果、未解決の懸念)
7. 必要なら回路図PDF / BOM を出力
8. PCB が必要な場合はここで停止し、ホストの KiCad に引き継ぐ
```

各サイクルの終わりに、次の 3 点を必ず報告する。

- 変更したファイル
- ERC の結果(違反数と内訳)
- 自信のない設計判断(部品選定、値の根拠が弱い箇所)

## コマンド

ビルドと疎通確認:

```bash
make build        # イメージのビルド(Rust のフルビルドを含むので初回は長い)
make smoke        # kicad-cli / ライブラリ / MCP ハンドシェイクの確認
make shell        # コンテナ内のシェル
```

`kicad-cli` をホストから直接叩く(パスはコンテナ側 `/work/...`):

```bash
scripts/kicad-cli.sh version

# ERC(違反があれば非ゼロ終了)
scripts/kicad-cli.sh sch erc \
  --output /work/demo/erc.rpt \
  --exit-code-violations \
  /work/demo/demo.kicad_sch

# 回路図PDF
scripts/kicad-cli.sh sch export pdf \
  --output /work/demo/demo-sch.pdf \
  /work/demo/demo.kicad_sch

# DRC(.kicad_pcb がある場合)
scripts/kicad-cli.sh pcb drc \
  --output /work/demo/drc.rpt \
  --exit-code-violations \
  /work/demo/demo.kicad_pcb

# Gerber + ドリル
scripts/kicad-cli.sh pcb export gerbers --output /work/demo/fab /work/demo/demo.kicad_pcb
scripts/kicad-cli.sh pcb export drill   --output /work/demo/fab/ /work/demo/demo.kicad_pcb
```

サブコマンドの正確なオプションは `scripts/kicad-cli.sh sch erc --help` のように
`--help` で確認すること。KiCad のバージョンによって差異がある。

## トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `IPC connect failed` | PCB系ツール。この環境では実行不可。中断して報告する |
| シンボルが見つからない / ERC が大量に落ちる | グローバル `sym-lib-table` が見えているか `make smoke` で確認 |
| ホストに root 所有のファイルができる | ラッパースクリプト経由で起動しているか確認(`--user` を付けている) |
| ツールが見つからない | 一覧を取り直す。ファイル直接編集で回避しない |
| 応答が返らない | `docker ps` で停止していないか確認。stdio なので 1 セッション 1 コンテナ |

## 注意

- Konnect は **beta**。実案件のプロジェクトをこの環境に直接マウントしない。
- ライセンスは **AGPL-3.0**。業務利用・社内共有に広げる前に法務確認が必要。
