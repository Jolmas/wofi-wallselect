#!/usr/bin/env bash
#
# Instalador de wofi-wallselect.
#
# Copia el script, el tema y la configuración de wofi a
# ~/.config/wofi/wallselect, crea la caché de miniaturas y respalda cualquier
# archivo que ya existiera.
#
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DEST="$CONFIG_HOME/wofi/wallselect"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-wallselect"
STAMP="$(date +%Y%m%d-%H%M%S)"
GEN_THUMBS=1

usage() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --no-thumbs   No generar las miniaturas durante la instalación
  -h, --help    Mostrar esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --no-thumbs) GEN_THUMBS=0 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

if ! command -v wofi >/dev/null 2>&1; then
    echo "Error: wofi no está instalado o no está en PATH." >&2
    echo "Instálalo antes de continuar (ver REQUIREMENTS.md)." >&2
    exit 1
fi

backup() {
    local file="$1"
    if [[ -e "$file" ]]; then
        cp -a "$file" "$file.bak.$STAMP"
        echo "  respaldo: $file.bak.$STAMP"
    fi
}

echo "Instalando wofi-wallselect en $DEST"
mkdir -p "$DEST" "$CACHE/thumbs"

backup "$DEST/wallselect.sh"
backup "$DEST/style.css"
backup "$DEST/wofi.conf"
install -m 755 "$REPO_DIR/src/wallselect.sh" "$DEST/wallselect.sh"
install -m 644 "$REPO_DIR/src/style.css"     "$DEST/style.css"
install -m 644 "$REPO_DIR/src/wofi.conf"     "$DEST/wofi.conf"

if [[ -e "$DEST/config.sh" ]]; then
    echo "  conservando configuración existente: $DEST/config.sh"
else
    install -m 644 "$REPO_DIR/src/config.sh" "$DEST/config.sh"
fi

if (( GEN_THUMBS )); then
    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        echo "Generando miniaturas..."
        if ! "$DEST/wallselect.sh" --generate-thumbs; then
            echo "  no se generaron las miniaturas; revisa WALL_DIR y ejecuta"
            echo "  $DEST/wallselect.sh --generate-thumbs más tarde."
        fi
    else
        echo "  ImageMagick no encontrado: se omite la generación de miniaturas."
        echo "  El menú funcionará igual usando las imágenes originales."
    fi
fi

echo
echo "Instalación completada."
echo "Abre el menú con:"
echo "  $DEST/wallselect.sh"
echo
