# 各スクリプトが source する共通設定。単体では実行しない。
#
# 作業領域 (コンテナの /work) の決め方 (上から優先):
#   1. KONNECT_PROJECTS          利用者が明示した場所
#   2. KONNECT_DEFAULT_PROJECTS  MCP の起動設定が渡す既定 (Claude Code は起動ディレクトリ)
#   3. カレントディレクトリ
# 相対パスはカレントディレクトリ基準で解決する。
#
# 呼び出し側は HERE (このファイルのあるディレクトリ) を設定してから source すること。

PLUGIN_ROOT="$(cd "${HERE}/.." && pwd)"
STATE_DIR="${XDG_STATE_HOME:-${HOME}/.local/state}/konnect-kicad"

IMAGE="${KONNECT_IMAGE:-konnect-kicad:10}"

konnect_abs() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$(pwd)" "$1" ;;
  esac
}

PROJECTS="$(konnect_abs "${KONNECT_PROJECTS:-${KONNECT_DEFAULT_PROJECTS:-$(pwd)}}")"
PROJECTS="${PROJECTS%/}"
IPC_DIR="$(konnect_abs "${KONNECT_IPC_DIR:-${STATE_DIR}/ipc}")"
CONFIG_DIR="$(konnect_abs "${KONNECT_GUI_CONFIG:-${STATE_DIR}/gui-config}")"

# 誤って広すぎる場所や、プラグイン自身 (Codex は MCP をプラグインの場所で起動する)
# を /work にしないよう止める。
konnect_check_projects() {
  local why=""
  case "${PROJECTS}/" in
    "${PLUGIN_ROOT}/"*) why="プラグインのディレクトリ (${PLUGIN_ROOT}) の中になっている" ;;
  esac
  if [ -z "${why}" ]; then
    case "${PROJECTS}" in
      ""|/|"${HOME%/}") why="${PROJECTS:-/} は広すぎる" ;;
    esac
  fi
  if [ -n "${why}" ]; then
    echo "konnect: 作業領域が ${why}。KONNECT_PROJECTS に作業ディレクトリの絶対パスを設定すること。" >&2
    return 1
  fi
}
