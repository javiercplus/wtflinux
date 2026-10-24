#!/usr/bin/env bash
# 06-config-grub.sh — Genera el grub.cfg que arranca la ISO live y copia los
# temas/assets necesarios dentro del rootfs y del directorio de trabajo ISO.

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

KERNEL_RELEASE="$(cat "$ROOTFS/etc/wtflinux-kernel-release" 2>/dev/null || true)"
[ -z "$KERNEL_RELEASE" ] && die "No se encontró KERNEL_RELEASE en $ROOTFS/etc/wtflinux-kernel-release"

VMLINUZ="/boot/vmlinuz-${KERNEL_RELEASE}"
INITRAMFS="/boot/initramfs-${KERNEL_RELEASE}.img"

[ -f "$ROOTFS$VMLINUZ" ] || die "Falta vmlinuz: $ROOTFS$VMLINUZ"
[ -f "$ROOTFS$INITRAMFS" ] || die "Falta initramfs: $ROOTFS$INITRAMFS. ¿Corriste 09-mkinitramfs.sh?"

ensure_dir "$ISODIR/boot/grub"

log "Escribiendo grub.cfg en $ISODIR/boot/grub/grub.cfg"

cat > "$ISODIR/boot/grub/grub.cfg" <<EOF
set default=0
set timeout=10
set pager=1

insmod all_video
insmod gfxterm
insmod gettext
insmod part_msdos
insmod part_gpt
insmod fat
insmod ext2
insmod iso9660
insmod loopback
insmod squash4

set gfxmode=auto
set gfxpayload=keep
terminal_input console
terminal_output gfxterm

menuentry "WtfLinux (${PKGMGR} + ${INIT}) — live" {
    set gfxpayload=keep
    echo "Loading WtfLinux kernel ${KERNEL_RELEASE}…"
    linux /boot/vmlinuz-${KERNEL_RELEASE} \
        root=live:CDLABEL=WTFLINUX \
        ro \
        rd.live.image \
        rd.live.overlay.overlayfs=1 \
        rd.live.squashfs=/lib/wtflinux/rootfs.squashfs \
        rd.shell rd.emergency=reboot \
        loglevel=3 \
        vt.global_cursor_default=0 \
        i915.modeset=1 \
        nouveau.modeset=1 \
        radeon.modeset=1 \
        amdgpu.modeset=1 \
        nomodeset
    echo "Loading initramfs…"
    initrd /boot/initramfs-${KERNEL_RELEASE}.img
}

menuentry "WtfLinux (${PKGMGR} + ${INIT}) — live (nomodeset)" {
    set gfxpayload=text
    linux /boot/vmlinuz-${KERNEL_RELEASE} \
        root=live:CDLABEL=WTFLINUX \
        ro \
        rd.live.image \
        rd.live.overlay.overlayfs=1 \
        rd.live.squashfs=/lib/wtflinux/rootfs.squashfs \
        rd.shell rd.emergency=reboot \
        loglevel=3 \
        nomodeset \
        3
    initrd /boot/initramfs-${KERNEL_RELEASE}.img
}

menuentry "WtfLinux — rescue shell (no squashfs mount)" {
    set gfxpayload=text
    linux /boot/vmlinuz-${KERNEL_RELEASE} \
        root=live:CDLABEL=WTFLINUX \
        ro \
        rd.shell \
        loglevel=7
    initrd /boot/initramfs-${KERNEL_RELEASE}.img
}

menuentry "Reboot" {
    reboot
}

menuentry "Power off" {
    halt
}
EOF

# loopback grub config para EFI
mkdir -p "$ISODIR/EFI/BOOT"
cat > "$ISODIR/EFI/BOOT/grub.cfg" <<'EOF'
search --set=root --file /boot/grub/grub.cfg
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EOF

ok "grub.cfg escrito en $ISODIR/boot/grub/grub.cfg"
