#!/usr/bin/env bash
#
# Desinstalador de wofi-wallselect para el usuario actual.
#
# Por defecto elimina el ejecutable, el tema, la configuración de wofi y el
# lanzador, pero conserva config.sh y la caché de miniaturas.
#
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="$CONFIG_HOME/wofi/wallselect"
APP_DIR="$DATA_HOME/applications"
LOCALE_DIR="$DATA_HOME/locale"
DOC_DIR="$DATA_HOME/doc/wofi-wallselect"
CACHE_DIR="$CACHE_HOME/wofi-wallselect"
PURGE=0

usage() {
    cat <<'EOF'
Uso: ./uninstall.sh [opciones]

Opciones:
  --purge       Elimina también config.sh, el directorio de configuración
                y la caché de miniaturas
  -h, --help    Mostrar esta ayuda
EOF
}

for arg in "$@"; do
    case "$arg" in
        --purge)   PURGE=1 ;;
        -h|--help) usage; exit 0 ;;
        *)         echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

echo "Desinstalando wofi-wallselect"

rm -f "$BIN_DIR/wallselect.sh"
rm -f "$CONFIG_DIR/style.css"
rm -f "$CONFIG_DIR/wofi.conf"
rm -f "$APP_DIR/wallselect.desktop"
rm -rf "$DOC_DIR"

# Elimina el dominio en cualquier idioma instalado (incluidas las
# traducciones antiguas en_GB/en_US), sin tocar otras traducciones.
if [[ -d "$LOCALE_DIR" ]]; then
    while IFS= read -r -d '' mo; do
        rm -f "$mo"
        rmdir "$(dirname -- "$mo")" "$(dirname -- "$(dirname -- "$mo")")" 2>/dev/null || true
    done < <(find "$LOCALE_DIR" -path '*/LC_MESSAGES/wallselect.mo' -print0 2>/dev/null)
fi

if ((PURGE)); then
    rm -f "$CONFIG_DIR/config.sh"
    rmdir "$CONFIG_DIR" 2>/dev/null || true
    rm -rf "$CACHE_DIR"
    echo "  eliminados config.sh, $CONFIG_DIR y la caché $CACHE_DIR"
else
    echo "  conservando $CONFIG_DIR/config.sh"
    echo "  conservando la caché $CACHE_DIR (usa --purge para borrarla)"
    rmdir "$CONFIG_DIR" 2>/dev/null || true
fi

echo
echo "Hecho."
