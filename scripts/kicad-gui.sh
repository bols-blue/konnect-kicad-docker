#!/usr/bin/env bash
# KiCad 10 の GUI をコンテナ内で起動し、ホストの X (Wayland なら XWayland) に表示する。
# PCB 系ツールは KiCad の IPC API 経由なので、これが起動して対象基板を
# 開いている間だけ Konnect から使える。
#
#   scripts/kicad-gui.sh                          # プロジェクトマネージャを起動
#   scripts/kicad-gui.sh /work/demo/demo.kicad_pro
#   scripts/kicad-gui.sh --stop
#
# IPC ソケットはホストの ${KONNECT_IPC_DIR} (既定 ./.kicad-ipc) を
# 両コンテナの /tmp/kicad にマウントして共有する。
# パスは kicad-cli.sh と同じくコンテナ側の /work/... で指定すること。
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"

IMAGE="${KONNECT_IMAGE:-konnect-kicad:10}"
PROJECTS="${KONNECT_PROJECTS:-${ROOT}/projects}"
IPC_DIR="${KONNECT_IPC_DIR:-${ROOT}/.kicad-ipc}"
CONFIG_DIR="${KONNECT_GUI_CONFIG:-${ROOT}/.kicad-gui-config}"
NAME="${KONNECT_GUI_NAME:-konnect-kicad-gui}"

running() { docker ps --format '{{.Names}}' | grep -qx "${NAME}"; }

if [ "${1:-}" = "--stop" ]; then
  running && docker stop "${NAME}" >/dev/null && echo "stopped ${NAME}"
  exit 0
fi

: "${DISPLAY:?DISPLAY が未設定。X / XWayland のあるデスクトップセッションから実行すること}"

if running; then
  echo "${NAME} は既に起動している (停止: $0 --stop)" >&2
  exit 1
fi

mkdir -p "${PROJECTS}" "${IPC_DIR}"

# GUI の設定は永続化する。コンテナの HOME は毎回まっさらなので、そのままだと
# 起動のたびに初回セットアップウィザードが出て IPC サーバの起動前で止まる。
# 初回だけイメージに焼いた lib-table / kicad_common.json (API 有効) を種にする。
if [ ! -f "${CONFIG_DIR}/10.0/kicad_common.json" ]; then
  mkdir -p "${CONFIG_DIR}"
  docker run --rm --user "$(id -u):$(id -g)" \
    --volume "${CONFIG_DIR}:/seed" \
    --entrypoint sh "${IMAGE}" -c 'cp -r "$XDG_CONFIG_HOME/kicad/." /seed/'
fi
# 前回のクラッシュで残ったソケット。残っていると KiCad は api-<pid>.sock に
# 逃げるので、Konnect 側の固定パスと食い違う。
rm -f "${IPC_DIR}"/api*.sock

args=(
  --rm --name "${NAME}"
  --user "$(id -u):$(id -g)"
  --network "${KONNECT_NETWORK:-bridge}"
  --env DISPLAY="${DISPLAY}"
  --volume /tmp/.X11-unix:/tmp/.X11-unix:ro
  --volume "${PROJECTS}:/work"
  --volume "${IPC_DIR}:/tmp/kicad"
  --volume "${CONFIG_DIR}:/konnect-home/.config/kicad"
  --workdir /work
)

if [ -n "${XAUTHORITY:-}" ] && [ -f "${XAUTHORITY}" ]; then
  args+=(--volume "${XAUTHORITY}:/tmp/.Xauthority:ro" --env XAUTHORITY=/tmp/.Xauthority)
fi

# OpenGL (基板ビュー) 用。デバイスの所有グループを付与しないと開けない。
if [ -d /dev/dri ]; then
  args+=(--device /dev/dri)
  for gid in $(stat -c '%g' /dev/dri/card* /dev/dri/renderD* 2>/dev/null | sort -u); do
    args+=(--group-add "${gid}")
  done
fi

if [ -n "${KONNECT_GUI_DEBUG:-}" ]; then
  exec docker run "${args[@]}" --entrypoint kicad "${IMAGE}" "$@"
fi

docker run --detach "${args[@]}" --entrypoint kicad "${IMAGE}" "$@" >/dev/null

# IPC サーバの起動確認。初回はセットアップウィザードを人が完了するまで待つ。
echo "KiCad GUI 起動待ち (初回はセットアップウィザードを完了すること)..." >&2
for _ in $(seq 1 "${KONNECT_GUI_TIMEOUT:-300}"); do
  if [ -S "${IPC_DIR}/api.sock" ]; then
    echo "KiCad GUI 起動: ${NAME} (IPC: ${IPC_DIR}/api.sock)"
    exit 0
  fi
  running || { echo "KiCad が起動直後に終了した (--rm のためログは残らない。KONNECT_GUI_DEBUG=1 で前面実行して確認)" >&2; exit 1; }
  sleep 1
done
echo "KiCad は起動しているが IPC ソケットが現れない。ダイアログで止まっていないか、設定 > プラグイン で API サーバが有効か確認 (docker logs ${NAME})" >&2
exit 1
