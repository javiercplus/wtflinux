#!/usr/bin/env bash
# 08-config-desktop.sh — Configura i3wm + lightdm + xprofile.
# Copia configs de config/i3/ y config/lightdm/ al rootfs.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

CFG="$SCRIPT_DIR/../../config"

log "Configurando i3 + lightdm en el rootfs"

# ─────────── i3 ────────────
I3_DIR="$ROOTFS/etc/skel/.config/i3"
ensure_dir "$I3_DIR"
if [ -f "$CFG/i3/config" ]; then
  cp "$CFG/i3/config" "$I3_DIR/config"
else
  cat > "$I3_DIR/config" <<'EOF'
# i3 config — WtfLinux live
set $mod Mod4
font pango:monospace 10
floating_modifier $mod
exec --no-startup-id xset -b
exec --no-startup-id feh --bg-scale /usr/share/wtflinux/wallpaper.png || true

# Terminal
bindsym $mod+Return exec i3-sensible-terminal
bindsym $mod+Shift+q kill
bindsym $mod+d exec --no-startup-id i3-dmenu-desktop

# Movement
bindsym $mod+h focus left
bindsym $mod+j focus down
bindsym $mod+k focus up
bindsym $mod+l focus right
bindsym $mod+Left  focus left
bindsym $mod+Down  focus down
bindsym $mod+Up    focus up
bindsym $mod+Right focus right

bindsym $mod+Shift+h move left
bindsym $mod+Shift+j move down
bindsym $mod+Shift+k move up
bindsym $mod+Shift+l move right

bindsym $mod+1 workspace 1
bindsym $mod+2 workspace 2
bindsym $mod+3 workspace 3
bindsym $mod+4 workspace 4
bindsym $mod+5 workspace 5

bindsym $mod+r mode "resize"
mode "resize" {
  bindsym h resize shrink width 2 px
  bindsym j resize grow height 2 px
  bindsym k resize shrink height 2 px
  bindsym l resize grow width 2 px
  bindsym Escape mode "default"
}

bar {
  status_command i3status || i3blocks
}
EOF
fi
# skel → usuario anon
if id -R "$ROOTFS" anon >/dev/null 2>&1 || [ -d "$ROOTFS/home/anon" ]; then
  ensure_dir "$ROOTFS/home/anon/.config/i3"
  cp "$I3_DIR/config" "$ROOTFS/home/anon/.config/i3/config"
  chown -R 1000:1000 "$ROOTFS/home/anon/.config" 2>/dev/null || true
fi

# ─────────── lightdm ────────────
LIGHTDM_DIR="$ROOTFS/etc/lightdm"
ensure_dir "$LIGHTDM_DIR"
if [ -f "$CFG/lightdm/lightdm.conf" ]; then
  cp "$CFG/lightdm/lightdm.conf" "$LIGHTDM_DIR/lightdm.conf"
fi
# Autologin anon
mkdir -p "$LIGHTDM_DIR/lightdm.conf.d"
cat > "$LIGHTDM_DIR/lightdm.conf.d/10-autologin.conf" <<'EOF'
[LightDM]
run-directory=/run/lightdm
autologin-user=anon
autologin-user-timeout=0
EOF

# Permitir autologin al usuario anon en PAM (lightdm + lightdm-autologin)
enter_chroot "$ROOTFS" bash -c '
  set -e
  if [ -f /etc/pam.d/lightdm-autologin ]; then
    if ! grep -q "anon" /etc/security/lightdm-autologin.group 2>/dev/null; then
      groupadd -f autologin 2>/dev/null || true
      usermod -aG autologin anon 2>/dev/null || true
    fi
  fi
' || warn "No se pudo configurar autologin PAM"

# Wallpaper placeholder
mkdir -p "$ROOTFS/usr/share/wtflinux"
# Genera un PNG pequeño de 1x1 púrpura (sólo para que feh no explote)
if command -v convert >/dev/null 2>&1; then
  convert -size 1920x1080 xc:'#6c1f9e' "$ROOTFS/usr/share/wtflinux/wallpaper.png"
else
  # Imagen PNG púrpura 1x1 en base64
  printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00\x00\x0cIDATx\x9cc\xf8\x1f\x9e\x00\x00\x01\x00\x01\x00\x05\xfe\xd4\x00\x00\x00\x00IEND\xaeB`\x82' \
    > "$ROOTFS/usr/share/wtflinux/wallpaper.png"
fi

# xprofile: arranque X
mkdir -p "$ROOTFS/etc/skel"
cat > "$ROOTFS/etc/skel/.xprofile" <<'EOF'
# ~/.xprofile — WtfLinux live
setxkbmap us 2>/dev/null || true
xset -b
EOF
if [ -d "$ROOTFS/home/anon" ]; then
  cp "$ROOTFS/etc/skel/.xprofile" "$ROOTFS/home/anon/.xprofile"
fi

ok "Desktop (i3 + lightdm) configurado"
