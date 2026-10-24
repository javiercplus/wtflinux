#!/usr/bin/env bash
# 02-install-kernel.sh — Descomprime el tarball del kernel dentro del rootfs.
# Espera que exista $WORKDIR/kernel-pkg/.env con KERNEL_RELEASE y KERNEL_TARBALL.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ENVFILE="$WORKDIR/kernel-pkg/.env"
[ -f "$ENVFILE" ] || die "Falta $ENVFILE. ¿Corriste 01-fetch-kernel.sh?"
# shellcheck disable=SC1090
source "$ENVFILE"

[ -f "$KERNEL_TARBALL" ] || die "Tarball no encontrado: $KERNEL_TARBALL"

log "Instalando kernel $KERNEL_RELEASE en $ROOTFS"

# 1. Extraer tarball directamente sobre el rootfs
tar -xzf "$KERNEL_TARBALL" -C "$ROOTFS"

# 2. Crear symlink /boot/vmlinuz al último kernel
VMLINUZ=$(find "$ROOTFS/boot" -name 'vmlinuz-*' -type f | sort -V | tail -n1)
if [ -n "$VMLINUZ" ]; then
  ln -sf "$(basename "$VMLINUZ")" "$ROOTFS/boot/vmlinuz"
fi

# 3. Para pacman: crear /etc/mkinitcpio.d/linux-cachy.preset
if [ "$PKGMGR" = "pacman" ]; then
  ensure_dir "$ROOTFS/etc/mkinitcpio.d"
  cat > "$ROOTFS/etc/mkinitcpio.d/linux-cachy.preset" <<EOF
# mkinitcpio preset for the WtfLinux Cachy kernel
ALL_kver="/boot/vmlinuz-${KERNEL_RELEASE}"
ALL_config="/etc/mkinitcpio.conf"

PRESETS=('default')

default_image="/boot/initramfs-${KERNEL_RELEASE}.img"
default_options=""
EOF
fi

# 4. Para xbps: dracut config extra
if [ "$PKGMGR" = "xbps" ]; then
  ensure_dir "$ROOTFS/etc/dracut.conf.d"
  cat > "$ROOTFS/etc/dracut.conf.d/wtflinux.conf" <<'EOF'
add_dracutmodules+=" dmsquash-live "
compress="zstd"
hostonly="no"
dracutmodules+=" kernel-modules resume rootfs-block base fs-lib shutdown "
EOF
fi

# 5. Etiqueta para los scripts siguientes
echo "$KERNEL_RELEASE" > "$ROOTFS/etc/wtflinux-kernel-release"

ok "Kernel instalado: $KERNEL_RELEASE"
