#!/bin/sh
# Empacota um binário JÁ EXPORTADO como um .xbps instalável.
#
# É o caminho de quem quer o jogo agora, na própria máquina, sem montar a
# árvore do void-packages. Para mandar o pacote para a distribuição, o que vale
# é o `template` ao lado deste arquivo.
#
#   ./build-xbps.sh [binario] [versao]
#
# Sai um `kernel-panic-<versao>_1.x86_64.xbps` e um repositório local ao lado,
# pronto para `xbps-install --repository=.`
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
BIN=${1:-$ROOT/build/linux-x86_64/kernel-panic}
VERSION=${2:-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")}
OUT=${XBPS_OUT:-$HERE/out}

[ -x "$BIN" ] || { echo "erro: binário não encontrado ou não executável: $BIN" >&2; exit 1; }
[ -n "$VERSION" ] || { echo "erro: não consegui ler a versão de project.godot" >&2; exit 1; }
command -v xbps-create >/dev/null || { echo "erro: xbps-create não está no PATH" >&2; exit 1; }

# As dependências são o que o binário do Godot abre em RUNTIME, não o que ele
# linka: `ldd` mostra só a glibc porque todo o resto entra por dlopen.
# Cada dependência precisa de restrição de versão: o `xbps-create` recusa um
# nome puro com "can't guess pkgname for dependency". `>=0` é o idioma para
# "qualquer versão serve".
DEPS="glibc>=2.32_1 libX11>=0 libXcursor>=0 libXext>=0 libXi>=0 libXinerama>=0
libXrandr>=0 libXrender>=0 libglvnd>=0 alsa-lib>=0 libpulseaudio>=0 dbus-libs>=0
fontconfig>=0 libdecor>=0 eudev-libudev>=0 wayland>=0"

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

install -Dm755 "$BIN" "$STAGE/usr/bin/kernel-panic"
install -Dm644 "$HERE/kernel-panic.desktop" "$STAGE/usr/share/applications/kernel-panic.desktop"
install -Dm644 "$ROOT/assets/icons/launcher.png" \
  "$STAGE/usr/share/icons/hicolor/192x192/apps/kernel-panic.png"
install -Dm644 "$ROOT/LICENSE" "$STAGE/usr/share/licenses/kernel-panic/LICENSE"

mkdir -p "$OUT"
( cd "$OUT" && xbps-create \
    -A x86_64 \
    -n "kernel-panic-${VERSION}_1" \
    -s "Neon arena shooter about keeping one stubborn process alive" \
    -m "mafuzyk" \
    -l "MIT" \
    -H "https://github.com/mafuzyk/kernel-panic" \
    -D "$(echo $DEPS)" \
    "$STAGE" )

xbps-rindex -a "$OUT"/*.xbps >/dev/null
echo
echo "pronto: $(ls "$OUT"/kernel-panic-*.xbps)"
echo "instalar:  sudo xbps-install --repository=$OUT kernel-panic"
