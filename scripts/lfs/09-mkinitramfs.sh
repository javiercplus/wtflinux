#!/usr/bin/env bash
# 09-mkinitramfs.sh — Genera initramfs dentro del rootfs con dracut (xbps)
# o mkinitcpio (pacman). Debe incluir módulos live (dmsquash-live / archiso).

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

KERNEL_RELEASE="$(cat "$ROOTFS/etc/wtflinux-kernel-release" 2>/dev/null || true)"
[ -z "$KERNEL_RELEASE" ] && die "No se encontró KERNEL_RELEASE"

VMLINUZ="vmlinuz-${KERNEL_RELEASE}"

log "Generando initramfs para $KERNEL_RELEASE usando $PKGMGR"

case "$PKGMGR" in
  pacman)
    # mkinitcpio con hooks live
    HOOKS_FILE="$ROOTFS/etc/mkinitcpio.conf"
    cat > "$HOOKS_FILE" <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev modconf block filesystems keyboard keymap fsck squashfs)
COMPRESSION="zstd"
COMPRESSION_OPTIONS=(-19 -T0)
EOF

    # Asegurar hooks disponibles
    enter_chroot "$ROOTFS" bash -c '
      set -e
      # Necesitamos el hook `squashfs` y `block`
      if command -v mkinitcpio >/dev/null 2>&1; then
        # Si el preset existe, úsalo; si no, genera directo
        if [ -f /etc/mkinitcpio.d/linux-cachy.preset ]; then
          mkinitcpio -p linux-cachy
        else
          mkinitcpio -k "$1" -g "/boot/initramfs-$1.img"
        fi
      else
        echo "mkinitcpio no disponible; intentando fallback con dracut"
        command -v dracut >/dev/null 2>&1 && \
          dracut --kver "$1" --force "/boot/initramfs-$1.img" || true
      fi
    ' _ "$KERNEL_RELEASE"
    ;;

  xbps)
    # dracut con dmsquash-live ya configurado en 02-install-kernel.sh
    enter_chroot "$ROOTFS" bash -c '
      set -e
      if command -v dracut >/dev/null 2>&1; then
        dracut --kver "$1" --force "/boot/initramfs-$1.img"
      else
        echo "dracut no disponible; instalando…"
        xbps-install -Sy dracut
        dracut --kver "$1" --force "/boot/initramfs-$1.img"
      fi
    ' _ "$KERNEL_RELEASE"
    ;;

  *)
    die "Gestor desconocido: $PKGMGR"
    ;;
esac

# Verificación
INITRAMFS="$ROOTFS/boot/initramfs-${KERNEL_RELEASE}.img"
if [ ! -f "$INITRAMFS" ]; then
  # Algunos sistemas generan como initrd-<KVER>
  ALT="$ROOTFS/boot/initrd-${KERNEL_RELEASE}"
  if [ -f "$ALT" ]; then
    mv "$ALT" "$INITRAMFS"
  else
    die "No se generó initramfs en $INITRAMFS"
  fi
fi

# Tamaño sanity check
SIZE=$(stat -c%s "$INITRAMFS" 2>/dev/null || stat -f%z "$INITRAMFS")
if [ "${SIZE:-0}" -lt 1048576 ]; then
  warn "Initramfs sospechosamente pequeño (${SIZE} bytes)"
fi

ok "initramfs generado: $INITRAMFS ($((SIZE/1024/1024)) MB)"
