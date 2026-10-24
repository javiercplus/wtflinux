#!/usr/bin/env bash
# scripts/local-test.sh — Verifica la sintaxis bash de todos los scripts LFS
# sin necesidad de correr nada. Útil para detectar errores antes de pushear.
#
# Uso: bash scripts/local-test.sh

set -Eeuo pipefail

cd "$(dirname "$0")/.."

fail=0
echo "── bash -n (sintaxis) ─────────────────────────"
for f in scripts/lfs/*.sh scripts/lfs/lib/*.sh; do
  if ! bash -n "$f" 2> /tmp/bash-err; then
    echo "  ✗ $f"
    sed 's/^/      /' /tmp/bash-err
    fail=1
  else
    echo "  ✓ $f"
  fi
done

echo ""
echo "── shellcheck (si está disponible) ───────────"
if command -v shellcheck >/dev/null 2>&1; then
  for f in scripts/lfs/*.sh scripts/lfs/lib/*.sh; do
    if ! shellcheck -S warning "$f" 2> /tmp/sc-err; then
      echo "  ✗ $f"
      sed 's/^/      /' /tmp/sc-err
      fail=1
    else
      echo "  ✓ $f"
    fi
  done
else
  echo "  (shellcheck no instalado — skipped)"
fi

echo ""
echo "── yamllint workflows ────────────────────────"
if command -v yamllint >/dev/null 2>&1; then
  if ! yamllint -d "{extends: default, rules: {line-length: {max: 200}, document-start: {present: false}, truthy: {check-keys: false}}}" \
        .github/workflows/ > /tmp/yaml-err 2>&1; then
    cat /tmp/yaml-err | sed 's/^/  /'
    fail=1
  else
    echo "  ✓ YAML OK"
  fi
else
  echo "  (yamllint no instalado — skipped)"
fi

echo ""
[ $fail -eq 0 ] && echo "✅ Todo OK" || echo "❌ Hay errores"
exit $fail
