#!/usr/bin/env bash
# 10-mksquashfs.sh — Empaqueta el rootfs como squashfs dentro del directorio
# de trabajo del ISO. Compresión zstd -Xcompression-level 19.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# Limpiar caches, logs, etc. antes de empaquetar
log "Limpiando rootfs antes de squashfs"
rm -rf "$ROOTFS/var/cache"/* "$ROOTFS/var/log"/* "$ROOTFS/var/tmp"/* \
       "$ROOTFS/tmp"/* "$ROOTFS/root/.cache"/* "$ROOTFS/home/anon/.cache"/* 2>/dev/null || true

# Asegurar squashfs-tools en el host
if ! command -v mksquashfs >/dev/null 2>&1; then
  case "$PKGMGR" in
    pacman) pacman -Sy --noconfirm squashfs-tools ;;
    xbps)   xbps-install -Sy squashfs-tools ;;
  esac
fi
command -v mksquashfs >/dev/null 2>&1 || die "mksquashfs no disponible"

SQUASHDIR="$ISODIR/lib/wtflinux"
ensure_dir "$SQUASHDIR"
SQUASHFS="$SQUASHDIR/rootfs.squashfs"

rm -f "$SQUASHFS"

log "mksquashfs $ROOTFS → $SQUASHFS (zstd -19)"
mksquashfs "$ROOTFS" "$SQUASHFS" \
  -comp zstd -Xcompression-level 19 \
  -noappend -no-progress \
  -wildcards \
  -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*' \
     'var/cache/*' 'var/log/*'

ok "squashfs creado: $SQUASHFS ($(du -h "$SQUASHFS" | cut -f1))"
