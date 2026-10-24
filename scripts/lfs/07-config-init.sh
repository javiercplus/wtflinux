#!/usr/bin/env bash
# 07-config-init.sh — Habilita servicios según el init del rootfs.
#
#   INIT=systemd → systemctl enable lightdm, NetworkManager, …
#   INIT=runit   → ln -s /etc/sv/<svc> /etc/runit/runsvdir/default/

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

case "$INIT" in
  systemd)
    log "Habilitando servicios con systemctl…"
    enter_chroot "$ROOTFS" bash -c '
      set -e
      for svc in lightdm NetworkManager sshd getty@tty1; do
        if [ -f "/usr/lib/systemd/system/${svc}.service" ] || \
           [ -f "/etc/systemd/system/${svc}.service" ]; then
          systemctl enable "$svc" || true
        fi
      done
      # Bypass login en tty1 (usuario anon)
      mkdir -p /etc/systemd/system/getty@tty1.service.d
      cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf <<CONF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin anon --noclear %I \$TERM
CONF
    '
    ;;

  runit)
    log "Habilitando servicios con runit…"
    enter_chroot "$ROOTFS" bash -c '
      set -e
      mkdir -p /etc/runit/runsvdir/default
      for svc in NetworkManager sshd lightdm dbus udevd; do
        if [ -d "/etc/sv/$svc" ]; then
          ln -sf "/etc/sv/$svc" "/etc/runit/runsvdir/default/$svc"
        fi
      done
      # tty1 autologin como anon
      if [ -d /etc/sv/agetty-tty1 ] || [ -d /etc/sv/getty-tty1 ]; then
        ln -sf /etc/sv/agetty-tty1 /etc/runit/runsvdir/default/agetty-tty1 2>/dev/null || \
        ln -sf /etc/sv/getty-tty1  /etc/runit/runsvdir/default/getty-tty1  2>/dev/null || true
      fi
    '
    ;;

  *)
    die "Init no soportado: $INIT"
    ;;
esac

ok "Servicios habilitados para $INIT"
