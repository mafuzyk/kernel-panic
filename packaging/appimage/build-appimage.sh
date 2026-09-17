#!/bin/sh
# Monta um AppImage a partir de um binário JÁ EXPORTADO.
#
# Um AppImage roda em qualquer distribuição sem instalar nada: é o formato para
# quem não usa Arch nem Void e não quer pacote nenhum.
#
#   ./build-appimage.sh [binario] [versao]
#
# Precisa do `appimagetool`. Ele é distribuído como AppImage e é usado aqui com
# `--appimage-extract-and-run`, que dispensa FUSE — em máquina sem FUSE, e
# dentro de contêiner, montar não funcionaria.
set -eu

HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/../.." && pwd)
BIN=${1:-$ROOT/build/linux-x86_64/kernel-panic}
VERSION=${2:-$(sed -n 's/^config\/version="\(.*\)"$/\1/p' "$ROOT/project.godot")}
OUT=${APPIMAGE_OUT:-$HERE/out}
TOOL=${APPIMAGETOOL:-$HOME/.cache/kp-tools/appimagetool.AppImage}

[ -x "$BIN" ] || { echo "erro: binário não encontrado ou não executável: $BIN" >&2; exit 1; }
[ -x "$TOOL" ] || {
  echo "erro: appimagetool não encontrado em $TOOL" >&2
  echo "      baixe de https://github.com/AppImage/appimagetool/releases" >&2
  echo "      ou aponte APPIMAGETOOL para ele" >&2
  exit 1
}

APPDIR=$(mktemp -d)/KernelPanic.AppDir
trap 'rm -rf "$(dirname "$APPDIR")"' EXIT

install -Dm755 "$BIN" "$APPDIR/usr/bin/kernel-panic"
install -Dm755 "$HERE/AppRun" "$APPDIR/AppRun"
# O .desktop e o ícone vão na RAIZ do AppDir além de usr/share: é ali que o
# runtime os procura para montar o menu e o ícone da janela.
install -Dm644 "$HERE/kernel-panic.desktop" "$APPDIR/kernel-panic.desktop"
install -Dm644 "$HERE/kernel-panic.desktop" "$APPDIR/usr/share/applications/kernel-panic.desktop"
install -Dm644 "$ROOT/assets/icons/launcher.png" "$APPDIR/kernel-panic.png"
install -Dm644 "$ROOT/assets/icons/launcher.png" \
  "$APPDIR/usr/share/icons/hicolor/192x192/apps/kernel-panic.png"

command -v desktop-file-validate >/dev/null && \
  desktop-file-validate "$APPDIR/kernel-panic.desktop"

mkdir -p "$OUT"
ARCH=x86_64 "$TOOL" --appimage-extract-and-run \
  "$APPDIR" "$OUT/KERNEL-PANIC-v${VERSION}-x86_64.AppImage"

echo
echo "pronto: $OUT/KERNEL-PANIC-v${VERSION}-x86_64.AppImage"
