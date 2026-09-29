#!/usr/bin/env bash
# ホスト側から コンテナ内の kicad-cli を呼ぶラッパー。
# Claude Code の Bash ツールからの検証はこれを経由する。
#
#   scripts/kicad-cli.sh version
#   scripts/kicad-cli.sh sch erc --output /work/demo/erc.rpt --exit-code-violations /work/demo/demo.kicad_sch
#   scripts/kicad-cli.sh pcb export gerbers --output /work/demo/fab /work/demo/demo.kicad_pcb
#
# パスは必ずコンテナ側の /work/... で指定すること
# (ホストの ./projects が /work にマウントされる)。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"

IMAGE="${KONNECT_IMAGE:-konnect-kicad:10}"
PROJECTS="${KONNECT_PROJECTS:-${ROOT}/projects}"

mkdir -p "${PROJECTS}"

exec docker run --rm \
  --user "$(id -u):$(id -g)" \
  --network "${KONNECT_NETWORK:-bridge}" \
  --volume "${PROJECTS}:/work" \
  --workdir /work \
  --entrypoint kicad-cli \
  "${IMAGE}" "$@"
