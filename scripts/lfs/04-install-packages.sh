#!/usr/bin/env bash
# 04-install-packages.sh — Instala los paquetes restantes dentro del rootfs
# usando el gestor nativo. Lee config/packages-${PKGMGR}.list.
#
# Ya instalamos lo básico en el bootstrap, así que esto completa herramientas
# de build, sistema y red que pudieran faltar, y reconfigura cosas.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

PKG_LIST="$WORKDIR/repo/config/packages-${PKGMGR}.list"
[ -f "$PKG_LIST" ] || PKG_LIST="$SCRIPT_DIR/../../config/packages-${PKGMGR}.list"

if [ ! -f "$PKG_LIST" ]; then
  warn "Lista no encontrada: $PKG_LIST (se omite paso de paquetes extra)"
  exit 0
fi

log "Instalando paquetes extra para $PKGMGR desde $PKG_LIST"

mapfile -t PKGS < <(read_package_list "$PKG_LIST")

case "$PKGMGR" in
  pacman)
    enter_chroot "$ROOTFS" bash -c '
      set -e
      pacman -Sy --noconfirm --needed "$@" || true
    ' _ "${PKGS[@]}"
    ;;
  xbps)
    enter_chroot "$ROOTFS" bash -c '
      set -e
      xbps-install -Sy "$@" || true
    ' _ "${PKGS[@]}"
    ;;
  *)
    die "Gestor desconocido: $PKGMGR"
    ;;
esac

ok "Paquetes extra instalados"
