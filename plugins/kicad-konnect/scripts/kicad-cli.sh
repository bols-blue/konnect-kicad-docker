#!/usr/bin/env bash
# ホスト側から コンテナ内の kicad-cli を呼ぶラッパー。
# Claude Code の Bash ツールからの検証はこれを経由する。
#
#   kicad-cli.sh version
#   kicad-cli.sh sch erc --output /work/demo/erc.rpt --exit-code-violations /work/demo/demo.kicad_sch
#   kicad-cli.sh pcb export gerbers --output /work/demo/fab /work/demo/demo.kicad_pcb
#
# パスは必ずコンテナ側の /work/... で指定すること
# (作業領域が /work にマウントされる。決め方は _env.sh)。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/_env.sh"
konnect_check_projects

mkdir -p "${PROJECTS}"

exec docker run --rm \
  --user "$(id -u):$(id -g)" \
  --network "${KONNECT_NETWORK:-bridge}" \
  --volume "${PROJECTS}:/work" \
  --workdir /work \
  --entrypoint kicad-cli \
  "${IMAGE}" "$@"
