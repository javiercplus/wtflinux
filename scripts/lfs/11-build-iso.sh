#!/usr/bin/env bash
# 11-build-iso.sh — Ensambla la ISO final con xorriso + grub-mkrescue.
#
# Estructura del directorio del ISO:
#   /boot/vmlinuz-<KVER>
#   /boot/initramfs-<KVER>.img
#   /boot/grub/grub.cfg
#   /EFI/BOOT/grub.cfg
#   /lib/wtflinux/rootfs.squashfs
#
# Output: $OUTDIR/WtfLinux-<PKGMGR>-<INIT>-<date>.iso

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

KERNEL_RELEASE="$(cat "$ROOTFS/etc/wtflinux-kernel-release" 2>/dev/null || true)"
[ -z "$KERNEL_RELEASE" ] && die "No se encontró KERNEL_RELEASE"

# 1. Copiar kernel + initramfs al dir ISO
log "Copiando kernel + initramfs al directorio ISO"
ensure_dir "$ISODIR/boot"
cp "$ROOTFS/boot/vmlinuz-${KERNEL_RELEASE}"        "$ISODIR/boot/vmlinuz-${KERNEL_RELEASE}"
cp "$ROOTFS/boot/initramfs-${KERNEL_RELEASE}.img" "$ISODIR/boot/initramfs-${KERNEL_RELEASE}.img"

# Microcode (si están disponibles)
for uc in intel-ucode.img amd-ucode.bin; do
  if [ -f "$ROOTFS/boot/$uc" ]; then
    cp "$ROOTFS/boot/$uc" "$ISODIR/boot/$uc"
  fi
done

# 2. Asegurar herramientas en el host
case "$PKGMGR" in
  pacman) pacman -Sy --noconfirm --needed xorriso grub mtools dosfstools 2>/dev/null || true ;;
  xbps)   xbps-install -Sy xorriso grub mtools dosfstools 2>/dev/null || true ;;
esac

# 3. Asegurar grub-mkrescue / grub-bios / efi
GRUB_BIOS=""
GRUB_EFI=""
case "$PKGMGR" in
  pacman)
    pacman -Sy --noconfirm --needed grub grub-bios 2>/dev/null || true
    pacman -Sy --noconfirm --needed grub-efi-x86_64 2>/dev/null || true
    GRUB_BIOS="/usr/lib/grub/i386-pc"
    GRUB_EFI="/usr/lib/grub/x86_64-efi"
    ;;
  xbps)
    xbps-install -Sy grub grub-x86_64-efi 2>/dev/null || true
    GRUB_BIOS="/usr/lib/grub/i386-pc"
    GRUB_EFI="/usr/lib/grub/x86_64-efi"
    ;;
esac

[ -d "$GRUB_BIOS" ] || warn "Falta grub i386-pc: $GRUB_BIOS (la ISO BIOS boot puede fallar)"
[ -d "$GRUB_EFI" ]  || warn "Falta grub x86_64-efi: $GRUB_EFI (la ISO EFI boot puede fallar)"

# 4. Generar imagen EFI (bootx64.efi) con grub-mkstandalone
log "Generando bootx64.efi (grub-mkstandalone)"
EFI_DIR="$ISODIR/EFI/BOOT"
ensure_dir "$EFI_DIR"
MEMDISK_CFG=$(mktemp)
cat > "$MEMDISK_CFG" <<'EOF'
search --set=root --file /boot/grub/grub.cfg
set prefix=($root)/boot/grub
configfile $prefix/grub.cfg
EOF

if command -v grub-mkstandalone >/dev/null 2>&1; then
  grub-mkstandalone \
    --format=x86_64-efi \
    --output="$EFI_DIR/BOOTX64.EFI" \
    --modules="part_gpt part_msdos fat ext2 iso9660 squash4 loopback normal linux" \
    --memdisk=/dev/null \
    --config="$MEMDISK_CFG" 2>&1 || warn "grub-mkstandalone falló (EFI puede no bootear)"
fi

# 5. Imagen eltorito para BIOS
log "Generando core.img BIOS"
if command -v grub-mkimage >/dev/null 2>&1; then
  ensure_dir "$ISODIR/boot/grub/i386-pc"
  cp -a "$GRUB_BIOS"/* "$ISODIR/boot/grub/i386-pc/" 2>/dev/null || true
  grub-mkimage \
    --format=i386-pc-eltorito \
    --output="$ISODIR/boot/grub/i386-pc/eltorito.img" \
    --prefix=/boot/grub \
    --modules="part_gpt part_msdos fat ext2 iso9660 squash4 loopback normal linux boot" 2>&1 \
    || warn "grub-mkimage falló (BIOS boot puede no funcionar)"
fi

# 6. xorriso para ensamblar la ISO
ISO_NAME="WtfLinux-${PKGMGR}-${INIT}-$(date +%Y%m%d-%H%M).iso"
ISO_PATH="$OUTDIR/$ISO_NAME"
ensure_dir "$OUTDIR"

log "xorriso → $ISO_PATH"

xorriso -as mkisofs \
  -iso-level 3 \
  -full-iso9660-filenames \
  -joliet -joliet-long \
  -rational-rock \
  -volid "WTFLINUX" \
  -appid "WtfLinux Live ${PKGMGR}/${INIT}" \
  -publisher "WtfLinux Project" \
  -preparer "GitHub Actions build-iso.yml" \
  -eltorito-boot boot/grub/i386-pc/eltorito.img \
  -eltorito-catalog boot/grub/i386-pc/boot.catalog \
  -no-emul-boot -boot-load-size 4 -boot-info-table \
  --efi-boot EFI/BOOT/BOOTX64.EFI \
  -efi-boot-part --efi-boot-image --protective-msdos-label \
  -output "$ISO_PATH" \
  "$ISODIR" 2>&1 | tail -n 30

if [ ! -f "$ISO_PATH" ]; then
  die "xorriso no generó la ISO"
fi

# Hybrid: hacer la ISO booteable desde USB con isohybrid si está disponible
if command -v isohybrid >/dev/null 2>&1; then
  log "isohybrid $ISO_PATH"
  isohybrid "$ISO_PATH" || warn "isohybrid falló (USB boot puede no funcionar)"
fi

SIZE=$(du -h "$ISO_PATH" | cut -f1)
ok "ISO lista: $ISO_PATH ($SIZE)"
