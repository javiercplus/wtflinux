#!/usr/bin/env bash
# 01-fetch-kernel.sh — Descarga el último release del kernel Cachy compilado
# por el workflow build-kernel.yml y lo deja en $WORKDIR/kernel-pkg/.
#
# Variables de entorno:
#   KERNEL_TAG  — tag exacto del release (default: "latest")
#   GH_TOKEN    — token de GitHub (auto-inyectado por GHA)

set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

KERNEL_TAG="${KERNEL_TAG:-latest}"
REPO="$(gh_repo)"
DEST="$WORKDIR/kernel-pkg"

ensure_dir "$DEST"
cd "$DEST"

log "Buscando release '$KERNEL_TAG' en $REPO"

if [ "$KERNEL_TAG" = "latest" ]; then
  API="https://api.github.com/repos/${REPO}/releases/latest"
else
  API="https://api.github.com/repos/${REPO}/releases/tags/${KERNEL_TAG}"
fi

curl -fsSL -H "Authorization: token ${GH_TOKEN:-}" \
     -H "Accept: application/vnd.github+json" \
     "$API" > /tmp/release.json

# Buscar el asset wtflinux-cachy-kernel-*.tar.gz
ASSET_URL=$(jq -r '.assets[] | select(.name | test("wtflinux-cachy-kernel-.*\\.tar\\.gz$")) | .browser_download_url' \
              /tmp/release.json | head -n1)
RELEASE_URL=$(jq -r '.assets[] | select(.name == "kernel-release.txt") | .browser_download_url' \
              /tmp/release.json | head -n1)

if [ -z "$ASSET_URL" ]; then
  err "No se encontró ningún wtflinux-cachy-kernel-*.tar.gz en el release"
  err "Assets disponibles:"
  jq -r '.assets[].name' /tmp/release.json | sed 's/^/   - /' >&2
  die "Compila primero el kernel con build-kernel.yml"
fi

log "Descargando: $ASSET_URL"
curl -fsSL -H "Authorization: token ${GH_TOKEN:-}" -O "$ASSET_URL"

log "Descargando: $RELEASE_URL"
curl -fsSL -H "Authorization: token ${GH_TOKEN:-}" -o kernel-release.txt "$RELEASE_URL"

# Extraer KERNEL_RELEASE del archivo publicado
KERNEL_RELEASE="$(tr -d '[:space:]' < kernel-release.txt | sed 's/^KERNEL_RELEASE=//')"
[ -z "$KERNEL_RELEASE" ] && die "No se pudo leer KERNEL_RELEASE de kernel-release.txt"

echo "KERNEL_RELEASE=${KERNEL_RELEASE}" > "$DEST/.env"
echo "KERNEL_TARBALL=$DEST/$(ls wtflinux-cachy-kernel-*.tar.gz | head -n1)" >> "$DEST/.env"

ok "Kernel Cachy $KERNEL_RELEASE descargado en $DEST"
