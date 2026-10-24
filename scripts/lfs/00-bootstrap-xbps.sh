#!/usr/bin/env bash
# 00-bootstrap-xbps.sh — Bootstrap de un rootfs Void Linux con xbps-install.
#
# Estrategia: el contenedor base void-glibc-full ya trae xbps; usamos
# `xbps-install --root=$ROOTFS` para instalar el sistema base dentro del
# rootfs sin necesidad de debootstrap ni nada similar.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Bootstrap xbps rootfs en $ROOTFS"

REPO="${XBPS_REPO:-https://repo-de.voidlinux.org/current}"
ARCH="$(host_arch)"

# 1. Confianza de claves: copiamos las keys de xbps del host al rootfs
ensure_dir "$ROOTFS/var/db/xbps/keys"
cp -a /var/db/xbps/keys/* "$ROOTFS/var/db/xbps/keys/" 2>/dev/null || \
  warn "No había keys xbps en el host; descargaremos confianzas manualmente"

# 2. Configuración repos
ensure_dir "$ROOTFS/etc/xbps.d"
cat > "$ROOTFS/etc/xbps.d/00-repository-main.conf" <<EOF
repository=$REPO
repository=$REPO/multilib
repository=$REPO/nonfree
repository=$REPO/debug
EOF

# 3. Bootstrap: instalación base
log "xbps-install -S -R $REPO -r $ROOTFS base-system + paquetes"
pkgs=(
  base-system base-devel
  linux-firmware intel-ucode amd-ucode
  nano grub grub-x86_64-efi efibootmgr
  NetworkManager dhclient wpa_supplicant iwd
  i3 dmenu xorg xorg-input-drivers lightdm lightdm-gtk-greeter
  htop btop ncdu ripgrep fd fastfetch
  git curl wget rsync tar xz gzip zstd lz4 unzip
  bash bash-completion sudo openssh
  dracut squashfs-tools xorriso mtools dosfstools
  runit-void void-runit
)

# Si las keys siguen vacías, xbps-install las descargará automáticamente
# en el primer `-S`.
xbps-install -S -R "$REPO" -r "$ROOTFS" -y "${pkgs[@]}" 2>&1 | tail -n 80 || {
  err "xbps-install falló. Reintentando con -f (force)…"
  xbps-install -S -R "$REPO" -r "$ROOTFS" -yf "${pkgs[@]}"
}

# 4. fstab mínimo
cat > "$ROOTFS/etc/fstab" <<'EOF'
# WtfLinux live ISO — fstab generado en build-time
tmpfs /tmp  tmpfs  defaults,nosuid,nodev 0 0
EOF

# 5. Hostname y locale
echo "wtflinux" > "$ROOTFS/etc/hostname"
ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"

# Void usa /etc/default/libc-locales
if [ -f "$ROOTFS/etc/default/libc-locales" ]; then
  sed -i 's/^#\s*en_US.UTF-8/en_US.UTF-8/' "$ROOTFS/etc/default/libc-locales"
fi

# DNS y resolv
echo "nameserver 1.1.1.1" > "$ROOTFS/etc/resolv.conf"

enter_chroot "$ROOTFS" bash -c '
  set -e
  # Generar locales
  if command -v xbps-reconfigure >/dev/null 2>&1; then
    xbps-reconfigure -f glibc-locales 2>/dev/null || true
  fi
'

echo "LANG=en_US.UTF-8" > "$ROOTFS/etc/locale.conf"
echo "KEYMAP=us"        > "$ROOTFS/etc/vconsole.conf"

# 6. Usuario live
enter_chroot "$ROOTFS" bash -c '
  set -e
  if ! id anon >/dev/null 2>&1; then
    useradd -m -G wheel,users,audio,input,video,storage,optical,network -s /bin/bash anon
    echo "anon:anon" | chpasswd
    echo "root:root" | chpasswd
  fi
'

# 7. Sudo: wheel sin password
mkdir -p "$ROOTFS/etc/sudoers.d"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > "$ROOTFS/etc/sudoers.d/10-wheel"

ok "Rootfs xbps bootstrap OK en $ROOTFS"
