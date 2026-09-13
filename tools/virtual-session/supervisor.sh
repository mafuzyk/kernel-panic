#!/usr/bin/env bash
# Roda DENTRO da sessão KWin virtual. Lança SOMENTE o KERNEL PANIC.
# Herda o DISPLAY/WAYLAND_DISPLAY que o próprio KWin virtual criou.
# Nunca restaura o DISPLAY/WAYLAND_DISPLAY/XAUTHORITY/DBus da sessão física.
set -uo pipefail

PROJ="${KP_PROJECT:-/home/mafu/kernel-panic}"

echo "supervisor: WAYLAND_DISPLAY='${WAYLAND_DISPLAY:-}' DISPLAY='${DISPLAY:-}' XAUTHORITY='${XAUTHORITY:-}'"

# espera o Xwayland desta sessão aceitar conexões (se houver)
DRIVER="wayland"
if [ -n "${DISPLAY:-}" ]; then
  for _ in $(seq 1 80); do
    xdpyinfo -display "$DISPLAY" >/dev/null 2>&1 && { DRIVER="x11"; break; }
    sleep 0.25
  done
fi
echo "supervisor: driver=$DRIVER display='${DISPLAY:-}'"

# publica o estado real desta sessão pro lado de fora
{
  echo "runtime=$XDG_RUNTIME_DIR"
  echo "xdisplay=${DISPLAY:-}"
  echo "xauthority=${XAUTHORITY:-}"
  echo "wayland=${WAYLAND_DISPLAY:-}"
  echo "driver=$DRIVER"
} > /tmp/kernel-panic-virtual.env

# save real da usuária (progresso/bestiário populados) a menos que se peça limpo
if [ "${KP_CLEAN_SAVE:-0}" != "1" ]; then
  export XDG_DATA_HOME="${KP_REAL_DATA_HOME:-$HOME/.local/share}"
  export XDG_CONFIG_HOME="${KP_REAL_CONFIG_HOME:-$HOME/.config}"
fi

exec godot --path "$PROJ" \
  --display-driver "$DRIVER" \
  --audio-driver Dummy \
  --rendering-driver opengl3 \
  --resolution "${KP_W:-1920}x${KP_H:-1080}" \
  ${KP_GODOT_ARGS:-} ${KP_SCENE:-}
