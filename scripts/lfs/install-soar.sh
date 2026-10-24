#!/usr/bin/env bash
# install-soar.sh — Instala el binario estático de soar (pkgforge/soar) en el rootfs.
# Repo: https://github.com/pkgforge/soar

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

ARCH="$(host_arch)"
case "$ARCH" in
  x86_64)  SOAR_ARCH="linux-amd64"  ;;
  aarch64) SOAR_ARCH="linux-arm64"   ;;
  *)       die "Arquitectura no soportada por soar: $ARCH" ;;
esac

# Buscamos el binario precompilado en el último release
log "Buscando último release de pkgforge/soar ($SOAR_ARCH)"

API="https://api.github.com/repos/pkgforge/soar/releases/latest"
curl -fsSL -H "Accept: application/vnd.github+json" "$API" > /tmp/soar-release.json

# Estrategias (en orden de preferencia):
#   1. Asset llamado soar-$SOAR_ARCH (binario suelto)
#   2. Asset llamado soar-$ARCH (binario suelto)
#   3. Asset con tarball/zip que contenga `soar`
URL="$(jq -r --arg a "$SOAR_ARCH" --arg b "$ARCH" '
  .assets[] |
  select(.name | test("^(soar|Soar).*" + $a + ".*$")) |
  .browser_download_url
' /tmp/soar-release.json | head -n1)"

if [ -z "$URL" ]; then
  URL="$(jq -r --arg a "$ARCH" '
    .assets[] |
    select(.name | test("(^|[_-])" + $a + "([._-]|$)")) |
    select(.name | test("(any|musl|gnu|static|libc)"; "i")) |
    .browser_download_url
  ' /tmp/soar-release.json | head -n1)"
fi

if [ -z "$URL" ]; then
  # Último recurso: cualquier asset linux
  URL="$(jq -r '.assets[] | select(.name | test("linux"; "i")) | .browser_download_url' \
          /tmp/soar-release.json | head -n1)"
fi

[ -z "$URL" ] && die "No se encontró binario de soar para $ARCH en el último release"
log "Descargando: $URL"

TMP="$WORKDIR/soar-tmp"
ensure_dir "$TMP"
cd "$TMP"
curl -fsSL -O "$URL"
ASSET="$(ls -1 | head -n1)"

# Si es un tarball/zip, extraer; si es binario, usar directo
case "$ASSET" in
  *.tar.gz|*.tgz) tar -xzf "$ASSET" ;;
  *.tar.xz)       tar -xJf "$ASSET" ;;
  *.tar.zst)      tar --zstd -xf "$ASSET" ;;
  *.zip)          unzip -o "$ASSET" ;;
  *)              chmod +x "$ASSET" ;;
esac

SOAR_BIN="$(find . -type f -name 'soar' -o -name 'Soar' | head -n1)"
[ -z "$SOAR_BIN" ] && die "Binario soar no encontrado dentro del asset"

log "Instalando $SOAR_BIN → $ROOTFS/usr/local/bin/soar"
install -Dm755 "$SOAR_BIN" "$ROOTFS/usr/local/bin/soar"

# Sanity check dentro del rootfs (no siempre hay dinámicas compatibles)
enter_chroot "$ROOTFS" /usr/local/bin/soar --version 2>&1 | head -n5 || \
  warn "soar no pudo ejecutarse dentro del chroot (puede ser normal en build)"

ok "soar instalado en /usr/local/bin/soar"
