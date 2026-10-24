#!/usr/bin/env bash
# 00-bootstrap-pacman.sh — Bootstrap de un rootfs Arch Linux con pacstrap.
#
# Estrategia: usamos el contenedor base archlinux:latest del workflow, que ya
# tiene pacman + archlinux-keyring. pacstrap installa el grupo `base` y los
# paquetes extra que listamos aquí dentro de ROOTFS.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Bootstrap pacman rootfs en $ROOTFS"

# 1. Refrescar keys del host (Arch container)
log "Refrescando archlinux-keyring…"
pacman-key --init
pacman-key --populate archlinux

# 2. Servidores (mirrorlist automático del container)
if ! [ -f /etc/pacman.d/mirrorlist ] || [ ! -s /etc/pacman.d/mirrorlist ]; then
  warn "mirrorlist vacío; usando un mirror de respaldo"
  mkdir -p /etc/pacman.d
  cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
Server = https://mirror.rackspace.com/archlinux/$repo/os/$arch
EOF
fi

# 3. Instalar pacstrap si no está disponible
if ! command -v pacstrap >/dev/null 2>&1; then
  log "Instalando arch-install-scripts…"
  pacman -Sy --noconfirm arch-install-scripts
fi

# 4. Crear rootfs
ensure_dir "$ROOTFS"

log "Ejecutando pacstrap base + paquetes del sistema"
# Lista base que necesita el instalador después
pkgs=(
  base base-devel linux-firmware intel-ucode amd-ucode
  nano grub efibootmgr os-prober
  networkmanager dhclient wpa_supplicant iwd
  i3 dmenu xorg-server xorg-xinit lightdm lightdm-gtk-greeter
  htop btop ncdu ripgrep fd fastfetch
  git curl wget rsync tar xz gzip zstd lz4 unzip
  bash bash-completion sudo openssh
  dracut squashfs-tools xorriso mtools dosfstools
  runit runit-services void-linux-repo void-runit
)

# void-runit no existe en Arch; lo quitamos si está (lo dejamos por seguridad
# de no romper al usuario que quiera usar runit encima)
pkgs=("${pkgs[@]/void-linux-repo/}")
pkgs=("${pkgs[@]/void-runit/}")
pkgs=("${pkgs[@]/runit-services/}")
pkgs=("${pkgs[@]/runit/}")

pacstrap -K -M -c "$ROOTFS" "${pkgs[@]}" 2>&1 | tail -n 80

# 5. Generar fstab mínimo (no es root real, es squashfs; pero algo hay que poner)
cat > "$ROOTFS/etc/fstab" <<'EOF'
# WtfLinux live ISO — fstab generado en build-time
tmpfs /tmp  tmpfs  defaults,nosuid,nodev 0 0
EOF

# 6. Configuración mínima del rootfs
echo "wtflinux" > "$ROOTFS/etc/hostname"
ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"

# Locale
sed -i 's/^#\s*en_US.UTF-8/en_US.UTF-8/' "$ROOTFS/etc/locale.gen" 2>/dev/null || true
echo "en_US.UTF-8 UTF-8" > "$ROOTFS/etc/locale.gen"
enter_chroot "$ROOTFS" locale-gen

echo "LANG=en_US.UTF-8" > "$ROOTFS/etc/locale.conf"
echo "KEYMAP=us"        > "$ROOTFS/etc/vconsole.conf"

# 7. Usuario live
enter_chroot "$ROOTFS" bash -c '
  set -e
  if ! id anon >/dev/null 2>&1; then
    useradd -m -G wheel,sys,audio,input,video,storage,optical,network -s /bin/bash anon
    echo "anon:anon" | chpasswd
    echo "root:root" | chpasswd
  fi
'

# 8. Sudo: grupo wheel sin password (live ISO)
mkdir -p "$ROOTFS/etc/sudoers.d"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > "$ROOTFS/etc/sudoers.d/10-wheel"

ok "Rootfs pacman bootstrap OK en $ROOTFS"
