#!/usr/bin/env bash
# ビルド後の疎通確認。
#   1. kicad-cli が動くか
#   2. シンボルライブラリとグローバル lib-table が見えているか
#   3. Konnect が MCP の initialize / tools/list に応答するか
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
IMAGE="${KONNECT_IMAGE:-konnect-kicad:10}"

fail=0
step() { printf '\n=== %s\n' "$1"; }
ok()   { printf '  [ OK ] %s\n' "$1"; }
ng()   { printf '  [FAIL] %s\n' "$1"; fail=1; }

step "1. kicad-cli"
if out="$("${HERE}/kicad-cli.sh" version 2>&1)"; then
  ok "kicad-cli version: ${out}"
else
  ng "kicad-cli failed: ${out}"
fi

step "2. libraries / global lib-table"
out="$(docker run --rm --user "$(id -u):$(id -g)" --entrypoint sh "${IMAGE}" -c '
  n=$(ls /usr/share/kicad/symbols/*.kicad_sym 2>/dev/null | wc -l)
  echo "symbols=${n}"
  [ -f "$XDG_CONFIG_HOME/kicad/10.0/sym-lib-table" ] && echo "sym-lib-table=yes" || echo "sym-lib-table=NO"
  [ -f "$XDG_CONFIG_HOME/kicad/10.0/fp-lib-table" ]  && echo "fp-lib-table=yes"  || echo "fp-lib-table=NO"
  touch "$XDG_CACHE_HOME/.writetest" && echo "home-writable=yes" || echo "home-writable=NO"
' 2>&1)"
echo "${out}" | sed 's/^/  /'
echo "${out}" | grep -q 'sym-lib-table=yes' && ok "global sym-lib-table present" || ng "sym-lib-table missing (ERC will fail)"
echo "${out}" | grep -q 'home-writable=yes' && ok "HOME writable as current uid"  || ng "HOME not writable"

step "3. MCP stdio handshake"
req_init='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"smoke-test","version":"0"}}}'
req_note='{"jsonrpc":"2.0","method":"notifications/initialized"}'
req_list='{"jsonrpc":"2.0","id":2,"method":"tools/list"}'

resp="$(printf '%s\n%s\n%s\n' "${req_init}" "${req_note}" "${req_list}" \
        | timeout 60 "${HERE}/konnect-mcp.sh" 2>/dev/null)"

if echo "${resp}" | grep -q '"serverInfo"'; then
  ok "initialize responded"
else
  ng "no initialize response"
fi
if echo "${resp}" | grep -q '"tools"'; then
  n="$(echo "${resp}" | grep -o '"name"' | wc -l)"
  ok "tools/list responded (name fields: ${n})"
else
  ng "no tools/list response"
fi

printf '\n'
if [ "${fail}" -eq 0 ]; then
  echo "すべて通過しました。.mcp.json を読ませて Claude Code を起動してください。"
else
  echo "失敗した項目があります。README.md のトラブルシュートを参照してください。"
fi
exit "${fail}"
