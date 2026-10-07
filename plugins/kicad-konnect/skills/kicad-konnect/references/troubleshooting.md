# トラブルシュート

| 症状 | 対処 |
| --- | --- |
| `image 'konnect-kicad:10' not found` | イメージ未取得。[setup.md](setup.md) の「イメージの取得」 |
| `作業領域が ... KONNECT_PROJECTS に ... 設定すること` | 起動ディレクトリがホーム直下・`/`・プラグイン内。`KONNECT_PROJECTS` を設定して MCP を再起動 |
| `IPC connect failed` / `ipc_available: false` | KiCad GUI 未起動か PCB エディタ未オープン。リトライせず利用者に `kicad-gui.sh` での起動を依頼 |
| `kicad-gui.sh` で IPC ソケットが現れない | 初回ウィザードやダイアログで止まっていないか確認。`KONNECT_GUI_DEBUG=1` で前面実行 |
| 編集系ツールが `stale_target` で拒否する | 回路図が KiCad 6 以前の形式。[import-existing.md](import-existing.md) の手順 3 |
| シンボルが見つからない / ERC が大量に落ちる | `smoke-test.sh` の項目 2 でグローバル `sym-lib-table` を確認。プロジェクトの lib-table がホストの絶対パスを指していないかも見る |
| ホストに root 所有のファイルができる | ラッパースクリプト経由で起動しているか確認(`--user` を付けている) |
| `docker` が permission denied | サンドボックスで Docker ソケットが塞がれている。サンドボックス外での実行の承認を求める。サンドボックス外でも出るなら利用者が docker グループに入っていない |
| `MCP tool call requires approval, but approval policy is never` | Codex の非対話実行(`codex exec`)では konnect のツールを承認できない。利用者に対話モードでの実行を依頼する |
| ツールが見つからない | 一覧を取り直す。ファイル直接編集で回避しない |
| 応答が返らない | `docker ps` で停止していないか確認。stdio なので 1 セッション 1 コンテナ |
