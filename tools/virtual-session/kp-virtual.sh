#!/usr/bin/env bash
# Controle da sessão KWin virtual isolada do KERNEL PANIC.
#
#   kp-virtual.sh start [largura] [altura]   sobe a sessão + jogo
#   kp-virtual.sh stop                       derruba (systemctl, nunca pkill)
#   kp-virtual.sh status                     estado da unit + janela
#   kp-virtual.sh shot <arquivo.png>         captura a janela do jogo
#   kp-virtual.sh key <tecla> [repeticoes]   envia tecla (xdotool, display isolado)
#   kp-virtual.sh click <x> <y>              clique na janela
#   kp-virtual.sh logs [n]                   últimas n linhas do journal
#
# Segurança: tudo é escopado ao DISPLAY do Xwayland da sessão virtual,
# lido de /tmp/kernel-panic-virtual.env. Nunca toca :0 nem usa pkill/killall.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIT="kernel-panic-virtual"
ENVF="/tmp/kernel-panic-virtual.env"

die() { echo "erro: $*" >&2; exit 1; }

load_env() {
  [ -f "$ENVF" ] || die "sessão não está no ar (sem $ENVF). rode: $0 start"
  # shellcheck disable=SC1090
  source "$ENVF"
  [ -n "${xdisplay:-}" ] || die "sessão sem display X"
  [ "$xdisplay" != ":0" ] || die "recusando usar :0 (sessão física)"
  export DISPLAY="$xdisplay"
}

win_id() {
  local id
  id="$(xdotool search --onlyvisible --name "KERNEL PANIC" 2>/dev/null | head -1)"
  [ -n "$id" ] || die "janela do jogo não encontrada em $DISPLAY"
  echo "$id"
}

case "${1:-}" in
  start)
    systemctl --user stop "$UNIT.service" 2>/dev/null; sleep 1
    rm -f "$ENVF"
    systemd-run --user --unit="$UNIT" --collect \
      --property=KillMode=control-group \
      --property=TimeoutStopSec=5s \
      --property=MemoryMax=4G \
      --setenv=KP_W="${2:-1920}" --setenv=KP_H="${3:-1080}" \
      --setenv=KP_REAL_DATA_HOME="$HOME/.local/share" \
      --setenv=KP_REAL_CONFIG_HOME="$HOME/.config" \
      --setenv=KP_CLEAN_SAVE="${KP_CLEAN_SAVE:-0}" \
      "$HERE/virtual-service.sh" >/dev/null || die "systemd-run falhou"
    for _ in $(seq 1 80); do
      [ -f "$ENVF" ] && { sleep 3; break; }
      sleep 0.5
    done
    [ -f "$ENVF" ] || die "sessão não publicou $ENVF; veja: $0 logs"
    load_env
    for _ in $(seq 1 40); do
      xdotool search --onlyvisible --name "KERNEL PANIC" >/dev/null 2>&1 && break
      sleep 0.5
    done
    echo "sessão virtual no ar: display=$xdisplay wayland=${wayland:-} driver=${driver:-}"
    ;;
  stop)
    systemctl --user stop "$UNIT.service" && echo "sessão virtual encerrada"
    rm -f "$ENVF"
    ;;
  status)
    echo "unit: $(systemctl --user is-active $UNIT.service 2>/dev/null)"
    [ -f "$ENVF" ] && cat "$ENVF"
    if [ -f "$ENVF" ]; then load_env; echo "janela: $(win_id 2>/dev/null || echo nenhuma)"; fi
    ;;
  shot)
    [ -n "${2:-}" ] || die "uso: $0 shot <arquivo.png>"
    load_env; import -window "$(win_id)" "$2" && echo "salvo: $2"
    ;;
  key)
    [ -n "${2:-}" ] || die "uso: $0 key <tecla> [repeticoes]"
    # XTEST (sem --window): o Godot ignora XSendEvent. Seguro porque o
    # DISPLAY está escopado ao Xwayland da sessão virtual, nunca :0.
    load_env; xdotool windowactivate --sync "$(win_id)" 2>/dev/null
    xdotool key --clearmodifiers --repeat "${3:-1}" "$2" && echo "tecla enviada: $2"
    ;;
  type)
    [ -n "${2:-}" ] || die "uso: $0 type <texto>"
    load_env; xdotool windowactivate --sync "$(win_id)" 2>/dev/null
    xdotool type --clearmodifiers "$2" && echo "texto enviado"
    ;;
  click)
    [ -n "${3:-}" ] || die "uso: $0 click <x> <y>"
    load_env; W="$(win_id)"
    xdotool windowactivate --sync "$W" 2>/dev/null
    eval "$(xdotool getwindowgeometry --shell "$W")"
    xdotool mousemove --sync $((X + $2)) $((Y + $3)) click 1 && echo "clique em $2,$3"
    ;;
  capture)
    # Roda o harness KP_SHOT do jogo DENTRO da sessão virtual: o próprio jogo
    # monta a cena, captura o viewport e sai. Não depende de XTEST.
    # uso: kp-virtual.sh capture <modo> <arquivo.png> [VAR=val ...]
    [ -n "${3:-}" ] || die "uso: $0 capture <modo> <arquivo.png> [VAR=val ...]"
    CAP_MODE="$2"; CAP_OUT="$(realpath -m "$3")"; shift 3
    systemctl --user stop "$UNIT.service" 2>/dev/null; sleep 1
    rm -f "$ENVF" "$CAP_OUT"
    EXTRA=()
    for kv in "$@"; do EXTRA+=(--setenv="$kv"); done
    systemd-run --user --unit="$UNIT" --collect \
      --property=KillMode=control-group --property=TimeoutStopSec=5s \
      --property=MemoryMax=4G \
      --setenv=KP_W="${KP_W:-1920}" --setenv=KP_H="${KP_H:-1080}" \
      --setenv=KP_SHOT="$CAP_MODE" --setenv=KP_SHOT_OUT="$CAP_OUT" \
      --setenv=KP_REAL_DATA_HOME="$HOME/.local/share" \
      --setenv=KP_REAL_CONFIG_HOME="$HOME/.config" \
      --setenv=KP_CLEAN_SAVE="${KP_CLEAN_SAVE:-0}" \
      "${EXTRA[@]}" "$HERE/virtual-service.sh" >/dev/null || die "systemd-run falhou"
    for _ in $(seq 1 160); do
      [ -s "$CAP_OUT" ] && break
      sleep 0.5
    done
    systemctl --user stop "$UNIT.service" 2>/dev/null
    rm -f "$ENVF"
    [ -s "$CAP_OUT" ] && echo "capturado: $CAP_OUT" || die "captura falhou ($CAP_MODE) - veja: $0 logs"
    ;;
  showcase)
    # Renderiza o style guide do design system.
    # uso: kp-virtual.sh showcase <arquivo.png> [largura] [altura]
    [ -n "${2:-}" ] || die "uso: $0 showcase <arquivo.png> [larg] [alt]"
    OUT="$(realpath -m "$2")"; W="${3:-1500}"; H="${4:-1500}"
    D=":$((100 + RANDOM % 50))"
    Xvfb "$D" -screen 0 "${W}x${H}x24" -nolisten tcp >/dev/null 2>&1 &
    XP=$!; trap 'kill $XP 2>/dev/null || true' EXIT
    for _ in $(seq 1 60); do xdpyinfo -display "$D" >/dev/null 2>&1 && break; sleep 0.1; done
    env DISPLAY="$D" WAYLAND_DISPLAY="" KP_SHOT_OUT="$OUT" timeout 180 godot \
      --path "$(dirname "$(dirname "$HERE")")" --display-driver x11 --audio-driver Dummy \
      --rendering-driver opengl3 --resolution "${W}x${H}" \
      res://src/ui/design/showcase.tscn 2>&1 | grep -E "SHOT_SAVED|SCRIPT ERROR" | head -3
    ;;
  mockup)
    # Renderiza uma tela do estudo de direção suíça dark neon.
    # uso: kp-virtual.sh mockup <over|menu|pause> <arquivo.png>
    [ -n "${3:-}" ] || die "uso: $0 mockup <over|menu|pause> <arquivo.png>"
    M="$2"; OUT="$(realpath -m "$3")"; W=1920; H=1080
    D=":$((150 + RANDOM % 40))"
    Xvfb "$D" -screen 0 "${W}x${H}x24" -nolisten tcp >/dev/null 2>&1 &
    XP=$!; trap 'kill $XP 2>/dev/null || true' EXIT
    for _ in $(seq 1 60); do xdpyinfo -display "$D" >/dev/null 2>&1 && break; sleep 0.1; done
    env DISPLAY="$D" WAYLAND_DISPLAY="" KP_MOCKUP="$M" KP_SHOT_OUT="$OUT" timeout 180 godot \
      --path "$(dirname "$(dirname "$HERE")")" --display-driver x11 --audio-driver Dummy \
      --rendering-driver opengl3 --resolution "${W}x${H}" \
      res://src/ui/design/mockup_swiss.tscn 2>&1 | grep -E "SHOT_SAVED|SCRIPT ERROR" | head -3
    ;;
  logs)
    journalctl --user -u "$UNIT.service" --no-pager -n "${2:-40}" 2>&1 | grep -v WorkspaceTracker
    ;;
  *)
    sed -n '2,20p' "$0" | sed 's/^# \?//'
    ;;
esac
