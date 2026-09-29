#!/usr/bin/env bash
# Konnect を stdio MCP サーバとして起動する。
# Claude Code / Claude Desktop はこのスクリプトを command に指定する。
#
# 重要: stdout は JSON-RPC 専用。echo などで汚さないこと(全て >&2 へ)。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"

IMAGE="${KONNECT_IMAGE:-konnect-kicad:10}"
PROJECTS="${KONNECT_PROJECTS:-${ROOT}/projects}"

mkdir -p "${PROJECTS}" >&2

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "konnect: image '${IMAGE}' not found. run 'make build' first." >&2
  exit 1
fi

# --network none にすると JLCPCB 部品検索など外部アクセスを伴うツールは
# 失敗するが、隔離度は上がる。KONNECT_NETWORK=none で切り替え可能。
exec docker run --rm -i \
  --user "$(id -u):$(id -g)" \
  --network "${KONNECT_NETWORK:-bridge}" \
  --volume "${PROJECTS}:/work" \
  --workdir /work \
  "${IMAGE}" "$@"
