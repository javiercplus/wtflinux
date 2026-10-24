#!/usr/bin/env bash
# 05-config-system.sh — Configuración del sistema:
#   - /etc/os-release con NAME=WtfLinux
#   - hostname, issue, motd
#   - locale.conf, vconsole.conf
#   - Usuario live `anon` con contraseña `anon`
#   - Estado del sistema de paquetes

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

log "Configurando identidad del sistema WtfLinux"

# ─────────────────────────── /etc/os-release ───────────────────────
OSREL="$SCRIPT_DIR/../../config/os-release.${PKGMGR}"
[ -f "$OSREL" ] || OSREL="$SCRIPT_DIR/../../config/os-release"

cat > "$ROOTFS/etc/os-release" <<EOF
NAME="WtfLinux"
ID=wtflinux
ID_LIKE=$( [ "$PKGMGR" = pacman ] && echo arch || echo void )
PRETTY_NAME="WtfLinux ($( [ "$PKGMGR" = pacman ] && echo pacman || echo xbps ))"
VERSION="rolling"
VERSION_ID=rolling
HOME_URL="https://github.com/$(gh_repo)"
DOCUMENTATION_URL="https://github.com/$(gh_repo)#readme"
SUPPORT_URL="https://github.com/$(gh_repo)/issues"
BUG_REPORT_URL="https://github.com/$(gh_repo)/issues"
ANSI_COLOR="0;35"
LOGO="wtflinux"
BUILD_ID="${BUILD_DATE:-manual}"
VARIANT="$( [ "$PKGMGR" = pacman ] && echo pacman-systemd || echo xbps-runit )"
VARIANT_ID=$PKGMGR
EOF

# lsb-release si existe el dir
if [ -d "$ROOTFS/etc" ]; then
  cat > "$ROOTFS/etc/lsb-release" <<EOF
DISTRIB_ID=WtfLinux
DISTRIB_RELEASE=rolling
DISTRIB_DESCRIPTION="WtfLinux ($( [ "$PKGMGR" = pacman ] && echo pacman || echo xbps ))"
EOF
fi

# ───────────────────────── hostname / issue / motd ────────────────
echo "wtflinux" > "$ROOTFS/etc/hostname"

cat > "$ROOTFS/etc/issue" <<'EOF'

  __        __   _      _  __
  \ \      / /__| |__  | |/ /___ _ __
   \ \ /\ / / _ \ '_ \ | ' // _ \ '__|
    \ V  V /  __/ |_) || . \  __/ |
     \_/\_/ \___|_.__/ |_|\_\___|_|

  WtfLinux — pacman(systemd) / xbps(runit) live ISO
  Login: anon / anon   ·   root / root

EOF

cat > "$ROOTFS/etc/motd" <<'EOF'

  Welcome to WtfLinux
  ===================

  This is a live ISO. The root filesystem is a squashfs overlaid with tmpfs,
  so changes are LOST on reboot unless you install WtfLinux to disk.

  Quick start:
    $ sudo soar --help            # pkgforge package manager (AppImages, …)
    $ sudo pacman -Syu            # if pacman variant
    $ sudo xbps-install -Su       # if xbps variant
    $ startx                      # launch i3 from tty1

EOF

# ───────────────────────── locale, vconsole, timezone ─────────────
echo "LANG=en_US.UTF-8" > "$ROOTFS/etc/locale.conf"
echo "KEYMAP=us"        > "$ROOTFS/etc/vconsole.conf"
echo "LC_TIME=en_US.UTF-8" >> "$ROOTFS/etc/locale.conf"

ln -sf /usr/share/zoneinfo/UTC "$ROOTFS/etc/localtime"

# ─────────────────────────── usuarios / sudo ──────────────────────
enter_chroot "$ROOTFS" bash -c '
  set -e
  if ! id anon >/dev/null 2>&1; then
    useradd -m -G wheel,users,audio,input,video,storage,optical,network -s /bin/bash anon
  fi
  echo "anon:anon" | chpasswd
  echo "root:root" | chpasswd
'

mkdir -p "$ROOTFS/etc/sudoers.d"
echo "%wheel ALL=(ALL) NOPASSWD: ALL" > "$ROOTFS/etc/sudoers.d/10-wheel"
chmod 0440 "$ROOTFS/etc/sudoers.d/10-wheel"

# ───────────────────────────── red base ───────────────────────────
# hostname persistente
echo "wtflinux" > "$ROOTFS/etc/hostname"

# /etc/hosts mínimo
cat > "$ROOTFS/etc/hosts" <<'EOF'
127.0.0.1   localhost
::1         localhost ip6-localhost ip6-loopback
127.0.1.1   wtflinux.localdomain wtflinux
EOF

ok "Configuración del sistema aplicada"
