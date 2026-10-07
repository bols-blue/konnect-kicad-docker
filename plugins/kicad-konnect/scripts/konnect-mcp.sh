#!/usr/bin/env bash
# Konnect を stdio MCP サーバとして起動する。
# Claude Code / Claude Desktop はこのスクリプトを command に指定する。
#
# 重要: stdout は JSON-RPC 専用。echo などで汚さないこと(全て >&2 へ)。
#
# PCB 系ツールは kicad-gui.sh で起動した KiCad GUI の IPC ソケットに
# 繋ぐ。Konnect 起動時点で GUI が無くても接続先が決まるよう、パスは
# KICAD_API_SOCKET で固定している(自動検出は起動時に一度だけ行われるため)。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${HERE}/_env.sh"
konnect_check_projects

mkdir -p "${PROJECTS}" "${IPC_DIR}" "${BRIDGE_DIR}" >&2
echo "konnect: /work = ${PROJECTS}" >&2

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "konnect: image '${IMAGE}' not found. run 'docker pull ghcr.io/bols-blue/konnect-kicad:10 && docker tag ghcr.io/bols-blue/konnect-kicad:10 ${IMAGE}' first." >&2
  exit 1
fi

# ネットワーク:
# - KiCad GUI コンテナ (kicad-gui.sh) が起動していれば、そのネットワーク
#   名前空間に相乗りする (--network container:<GUI>)。ActionPlugin の native
#   Specctra ブリッジは 127.0.0.1 で待ち受けるので、ループバックの共有が必要。
#   共有するのは この 2 コンテナだけで、ホストには何も公開しない。
#   GUI を後から起動した場合は MCP クライアントで Konnect を再接続すること。
# - GUI が無ければ KONNECT_NETWORK (既定 bridge)。
#   --network none にすると JLCPCB 部品検索など外部アクセスを伴うツールは
#   失敗するが、隔離度は上がる。KONNECT_NETWORK=none で切り替え可能。
GUI_NAME="${KONNECT_GUI_NAME:-konnect-kicad-gui}"
if [ -z "${KONNECT_NETWORK:-}" ] && docker ps --format '{{.Names}}' | grep -qx "${GUI_NAME}"; then
  NETWORK="container:${GUI_NAME}"
else
  NETWORK="${KONNECT_NETWORK:-bridge}"
fi
echo "konnect: network=${NETWORK}" >&2

exec docker run --rm -i \
  --user "$(id -u):$(id -g)" \
  --network "${NETWORK}" \
  --volume "${PROJECTS}:/work" \
  --volume "${IPC_DIR}:/tmp/kicad" \
  --volume "${BRIDGE_DIR}:/konnect-bridge" \
  --env KICAD_API_SOCKET=ipc:///tmp/kicad/api.sock \
  --workdir /work \
  "${IMAGE}" "$@"
