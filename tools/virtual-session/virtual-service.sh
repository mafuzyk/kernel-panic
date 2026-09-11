#!/usr/bin/env bash
# Sobe uma sessão KWin Wayland COMPLETAMENTE separada da sessão física da
# usuária (DBus privado + XDG privado) e roda o KERNEL PANIC dentro dela.
#
# Não execute este script direto: lance via systemd-run --user
# (kwin_wayland tem cap_sys_nice=ep e execução direta leva SIGKILL aqui).
# Ver tools/virtual-session/README.md.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KP_W="${KP_W:-1920}"
KP_H="${KP_H:-1080}"
KP_XDISPLAY="${KP_XDISPLAY:-:9}"

# 1. corta TODA ligação com a sessão física antes de qualquer coisa.
unset WAYLAND_DISPLAY DISPLAY WAYLAND_SOCKET XAUTHORITY \
      DBUS_SESSION_BUS_ADDRESS DBUS_STARTER_ADDRESS DBUS_STARTER_BUS_TYPE

# 2. runtime/config descartáveis e privados.
RUNTIME="$(mktemp -d /tmp/kernel-panic-kwin.XXXXXX)"
chmod 700 "$RUNTIME"
mkdir -p "$RUNTIME"/{config,data,cache,state}
export XDG_RUNTIME_DIR="$RUNTIME"
export XDG_CONFIG_HOME="$RUNTIME/config"
export XDG_DATA_HOME="$RUNTIME/data"
export XDG_CACHE_HOME="$RUNTIME/cache"
export XDG_STATE_HOME="$RUNTIME/state"
export KP_XDISPLAY

# publica os dados da sessão pro lado de fora conseguir achar
{
  echo "runtime=$RUNTIME"
  echo "xdisplay=$KP_XDISPLAY"
  echo "xauthority=$RUNTIME/xauth"
} > /tmp/kernel-panic-virtual.env

touch "$RUNTIME/xauth"

exec dbus-run-session -- /usr/bin/kwin_wayland \
  --virtual \
  --width "$KP_W" \
  --height "$KP_H" \
  --scale 1 \
  --output-count 1 \
  --socket kernel-panic-test-0 \
  --xwayland \
  --no-lockscreen \
  --no-global-shortcuts \
  --no-kactivities \
  -- "$HERE/supervisor.sh"
