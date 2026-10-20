#!/bin/bash
# Gera Resources/AppIcon.icns a partir da arte em Resources/AppIcon-source.jpg.
#
# Uso: ./scripts/make-icon.sh [arte]   (padrão: Resources/AppIcon-source.jpg)
#
# Passos: aplica a máscara/sombra do macOS (make_icon.swift) → gera todos os tamanhos
# do .iconset com sips → empacota com iconutil.
set -euo pipefail
cd "$(dirname "$0")/.."

ART=${1:-Resources/AppIcon-source.jpg}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

swift scripts/make_icon.swift "$ART" "$TMP/icon_1024.png"

SET="$TMP/AppIcon.iconset"
mkdir -p "$SET"
for size in 16 32 128 256 512; do
    sips -z $size $size "$TMP/icon_1024.png" --out "$SET/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z $double $double "$TMP/icon_1024.png" --out "$SET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
cp "$TMP/icon_1024.png" Resources/AppIcon.png
echo "OK: Resources/AppIcon.icns (+ Resources/AppIcon.png)"
