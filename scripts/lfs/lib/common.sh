#!/usr/bin/env bash
# lib/common.sh — Funciones compartidas por todos los scripts LFS de WtfLinux.
# Se carga con: source "$(dirname "$0")/lib/common.sh"

# shellcheck disable=SC2034  # colores se usan en log/ok/warn/err
set -Eeuo pipefail

# ───────────────────────── Colores / log ──────────────────────────
if [ -t 1 ]; then
  C_RED='\033[0;31m'
  C_GRN='\033[0;32m'
  C_YEL='\033[1;33m'
  C_BLU='\033[0;34m'
  C_CYA='\033[0;36m'
  C_RST='\033[0m'
else
  C_RED=''
  C_GRN=''
  C_YEL=''
  C_BLU=''
  C_CYA=''
  C_RST=''
fi
export C_RED C_GRN C_YEL C_BLU C_CYA C_RST

log()  { printf "${C_BLU}[*]${C_RST} %s\n"  "$*"; }
ok()   { printf "${C_GRN}[+]${C_RST} %s\n"  "$*"; }
warn() { printf "${C_YEL}[!]${C_RST} %s\n" "$*"; }
err()  { printf "${C_RED}[x]${C_RST} %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ─────────────────────────── Rutas base ────────────────────────────
: "${ROOTFS:=/rootfs}"
: "${WORKDIR:=$(pwd)}"
: "${ISODIR:=${WORKDIR}/isowork}"
: "${OUTDIR:=${WORKDIR}/out}"
: "${PKGMGR:=pacman}"
: "${INIT:=systemd}"

# ─────────────────────────────── chroot ───────────────────────────
# Prepara un chroot seguro con /proc /sys /dev /run montados
enter_chroot() {
  local root="$1"; shift
  [ -d "$root" ] || die "ROOTFS no existe: $root"

  mount --bind /dev  "$root/dev"  2>/dev/null || true
  mount --bind /dev/pts "$root/dev/pts" 2>/dev/null || true
  mount -t proc  proc  "$root/proc" 2>/dev/null || true
  mount -t sysfs sysfs "$root/sys"  2>/dev/null || true
  mount -t tmpfs tmpfs "$root/run"  2>/dev/null || true
  mount -t tmpfs tmpfs "$root/tmp"  2>/dev/null || true

  # DNS
  cp /etc/resolv.conf "$root/etc/resolv.conf" 2>/dev/null || \
    echo "nameserver 1.1.1.1" > "$root/etc/resolv.conf"

  chroot "$root" /usr/bin/env -i \
    HOME=/root TERM="${TERM:-linux}" \
    PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$@"
  local rc=$?

  umount "$root/tmp"        2>/dev/null || true
  umount "$root/run"        2>/dev/null || true
  umount "$root/sys"        2>/dev/null || true
  umount "$root/proc"       2>/dev/null || true
  umount "$root/dev/pts"    2>/dev/null || true
  umount "$root/dev"        2>/dev/null || true
  return $rc
}

# Ejecuta un comando como si fuera un script dentro del chroot
chroot_run() {
  local script="$1"; shift
  local root="$ROOTFS"
  local tmp
  tmp="/tmp/wtflinux-$$-$(basename "$script")"
  cp "$script" "$root/$tmp"
  chmod +x "$root/$tmp"
  enter_chroot "$root" "$tmp" "$@"
  local rc=$?
  rm -f "$root/$tmp"
  return $rc
}

# ──────────────────────────── utilidades ──────────────────────────
require_env() {
  local v
  for v in "$@"; do
    [ -n "${!v:-}" ] || die "Variable de entorno requerida: $v"
  done
}

ensure_dir() {
  local d
  for d in "$@"; do
    mkdir -p "$d"
  done
}

# Devuelve la arquitectura del host normalizada
host_arch() {
  case "$(uname -m)" in
    x86_64|amd64)  echo x86_64 ;;
    aarch64|arm64) echo aarch64 ;;
    *) uname -m ;;
  esac
}

# Devuelve el nombre canónico del repo GitHub en formato owner/name
gh_repo() {
  echo "${GITHUB_REPOSITORY:-wtflinux/wtflinux}"
}

# Versión de un archivo de paquetes con comentarios (#) y líneas vacías ignoradas
read_package_list() {
  local f="$1"
  [ -f "$f" ] || { warn "Lista no encontrada: $f"; return 0; }
  grep -vE '^\s*(#|$)' "$f" | tr '\n' ' '
}
