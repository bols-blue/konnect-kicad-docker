# PCB 系ツール(IPC)の前提と既知の癖

PCB 系ツールは、`<scripts>/kicad-gui.sh` で起動した KiCad 10 GUI(同じイメージを
X11 転送でホストに表示)の IPC ソケットに繋がる。**対象基板が GUI の PCB エディタで
開かれているときだけ動く。**

- 作業前に `open_project`(`path` に `.kicad_pcb`)で `ipc_available: true` かつ
  `requested_open: true` を確認する
- `ipc_available: false` / `IPC connect failed` なら **リトライせず**、利用者に
  `<scripts>/kicad-gui.sh /work/<name>/<name>.kicad_pro` で起動して PCB エディタを
  開くよう依頼する。GUI の起動・操作は人間が行う
- IPC での変更や GUI での操作は、保存するまでファイルに反映されない。
  `save_project` で保存してから DRC を `kicad-cli` で回す(DRC はファイルを読む)
- 利用者が GUI で同時に編集していると競合する。PCB 編集の前に一声かける
- ファイルを手で書き換えて IPC の代わりにしない
- native Specctra ブリッジ(`export_specctra_dsn_native` / `import_specctra_ses_native`)は
  127.0.0.1 で待ち受けるので、Konnect は GUI コンテナのネットワークに相乗りする
  (`konnect-mcp.sh` が起動時に自動判定)。順番は
  **kicad-gui.sh → PCB エディタを開く → MCP クライアントで konnect を再接続**
  (Claude Code は `/mcp`、Codex は再起動)。GUI を起動し直したら再接続もやり直す
- ヘッドレス環境(SSH 先など)ではこの経路は使えない。回路図と ERC まで作って、
  あとはホストの KiCad に引き継ぐ

## 既知の癖

Konnect 0.12.1 / KiCad 10.0.6、2026-09 の自動配線通し検証で確認。

- `get_board_extents` は IPC 経由だと図形だけの基板を空(0)と返す。保存後はファイル経由で正しい値になる
- `update_pcb_from_schematic` で追加したフットプリントは `(attr smd)` / descr / tags などが欠ける。
  反映後に必ず `update_footprints_from_library` を当てる。SMD 抵抗はそれでも
  `lib_footprint_mismatch` 警告が残る(パッド寸法 1 nm の丸め)
- `update_pcb_from_schematic` は回路図の Description を基板に反映しない。
  `kicad-cli pcb drc --schematic-parity` で `footprint_symbol_field_mismatch` になる。
  Konnect の DRC はこれを報告しないので、parity 付きの kicad-cli DRC を必ず回す
- Freerouting は未使用ビアを残すことがある(`via_dangling`)。GUI の
  ツール > 配線とビアをクリーンアップ で消す
- KiCad が内層を power 層として DSN に出すと、Freerouting はその層のベタ(plane)へ
  つなぐビアを打たない(4 層の cm-carrier で GND / +5V のビア 0)。signal 層として出すと打つが、
  信号も内層に引かれる。class に `use_layer F.Cu B.Cu` を付けると再びビアが打たれなくなる
