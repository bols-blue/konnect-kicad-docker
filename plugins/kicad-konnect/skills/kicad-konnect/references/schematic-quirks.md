# Konnect の既知の癖(回路図・ライブラリ)

Konnect 0.12.1 / KiCad 10.0.6、2026-10 に確認。

- 既存シンボルのピン型を変えるツールは無い。`create_symbol` で同じ形・同じピン位置の
  シンボルを `.kicad_sym` に作り、`register_symbol_library`(project スコープ)→
  `replace_component` で差し替える。`graphics` で本体を描けばピン座標は指定どおりに書かれる
- **`update_symbols_from_library` は埋め込みシンボルを置き換えず、同じ名前のコピーを
  追加することがある。** KiCad は先にあるコピーを使うので変更が効かず、ファイルも
  不正な状態になる。ライブラリを変えたら ERC で反映を確認する。反映できないときは
  GUI の ツール > ライブラリからシンボルを更新 を人間が使う
- `get_schematic_view` の SVG はコンテナ内の `/tmp` に出るのでホストから見えない。
  見た目を確認するときは `kicad-cli sch export pdf` で `/work` に出し、ホストの
  `pdftoppm` で PNG にする
- PWR_FLAG を電源シンボルと同じ点に置くと絵が重なりやすい。回転させるか、空いている
  場所にある同じネットの電源シンボルに置く
- DC-DC などの出力ピンが `output` 型だと、PWR_FLAG(`power_out`)と
  `pin_to_pin` エラーになる。PWR_FLAG で隠さず、シンボルのピン型を `power_out` に直す
