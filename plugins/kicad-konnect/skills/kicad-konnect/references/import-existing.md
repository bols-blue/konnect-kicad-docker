# 既存プロジェクトの取り込み

外部リポジトリの KiCad プロジェクトは作業領域の下に `git clone` する。
クローンしたリポジトリはそれ自身の git で管理する(コミットはクローン側に積む)。

取り込み直後、編集の前に次の順で整える(2026-10 の isorated_powor_boad_v2 で確認)。

1. **ベースラインの ERC / DRC を回して違反数を記録する。** 以降の作業で
   増減を比較する基準になる
2. **ライブラリのパスを直す。** プロジェクトの `sym-lib-table` / `fp-lib-table` が
   ホストの絶対パス(`/home/...`)を指しているとコンテナから見えず、
   `lib_symbol_issues` / `footprint_link_issues` が大量に出る。外部ライブラリは
   プロジェクト内(例: `libs/`)にコピーし、URI を `${KIPRJMOD}/...` にする
3. **KiCad 6 以前の形式なら GUI で開いて保存する。** 回路図の先頭が
   `(version 2021...)` などの古い形式で、トップレベルに `symbol_instances` があると、
   Konnect の編集系ツールはすべて `stale_target`
   (placed-symbol instance metadata disagrees)で拒否する。
   - `kicad-cli sch upgrade` は **使わない**。`symbol_instances` を捨てるだけで
     シンボルごとの `(instances ...)` を書かないため、Konnect は同じエラーを返す
   - `annotate_schematic` でも修復できない
   - `<scripts>/kicad-gui.sh` で回路図エディタを開いて保存してもらうのが正解。
     PCB と `.kicad_pro` も一緒に新形式で保存されることがある
   - 保存後、変換前後のネットリスト(`kicad-cli sch export netlist`)を比較し、
     ERC / DRC の件数が変わっていないことを確認してから、変換だけを単独でコミットする
4. GUI で開いたプロジェクトは `.history/` を作るので、クローン側の `.gitignore` に追加する
