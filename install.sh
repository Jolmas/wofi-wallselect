#!/usr/bin/env bash
#
# Instalador de wofi-wallselect para el usuario actual.
#
# Instala el ejecutable en ~/.local/bin, la configuración en
# ~/.config/wofi/wallselect, las traducciones en ~/.local/share/locale,
# el lanzador en ~/.local/share/applications y la documentación en
# ~/.local/share/doc/wofi-wallselect.
#
# No necesita sudo. Para empaquetar en el sistema usa las fuentes de src/ y
# el árbol usr/ con tu herramienta de empaquetado.
#
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
CONFIG_DIR="$CONFIG_HOME/wofi/wallselect"
APP_DIR="$DATA_HOME/applications"
LOCALE_DIR="$DATA_HOME/locale"
DOC_DIR="$DATA_HOME/doc/wofi-wallselect"
CACHE_DIR="$CACHE_HOME/wofi-wallselect"
STAMP="$(date +%Y%m%d-%H%M%S)"
GEN_THUMBS=1

usage() {
    cat <<'EOF'
Uso: ./install.sh [opciones]

Opciones:
  --no-thumbs   No generar las miniaturas durante la instalación
  -h, --help    Mostrar esta ayuda

Instala para el usuario actual, sin sudo:
  ejecutable      ~/.local/bin/wallselect.sh
  configuración   ~/.config/wofi/wallselect/
  traducciones    ~/.local/share/locale/
  lanzador        ~/.local/share/applications/wallselect.desktop
  documentación   ~/.local/share/doc/wofi-wallselect/
EOF
}

for arg in "$@"; do
    case "$arg" in
        --no-thumbs) GEN_THUMBS=0 ;;
        -h|--help)   usage; exit 0 ;;
        *)           echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    esac
done

# Valida las fuentes antes de tocar nada.
for required in \
    src/wallselect.sh \
    src/style.css \
    src/wofi.conf \
    src/config.sh \
    usr/share/applications/wallselect.desktop \
    README.md \
    LICENSE \
    image.png
do
    if [[ ! -e "$REPO_ROOT/$required" ]]; then
        echo "Error: falta $required en el repositorio." >&2
        exit 1
    fi
done

backup() {
    local file="$1"
    if [[ -e "$file" ]]; then
        cp -a -- "$file" "$file.bak.$STAMP"
        echo "  respaldo: $file.bak.$STAMP"
    fi
}

install_locales() {
    local po lang
    shopt -s nullglob
    for po in "$REPO_ROOT"/po/*.po; do
        lang="$(basename -- "$po" .po)"
        mkdir -p "$LOCALE_DIR/$lang/LC_MESSAGES"
        if command -v msgfmt >/dev/null 2>&1; then
            msgfmt --check -o "$LOCALE_DIR/$lang/LC_MESSAGES/wallselect.mo" "$po"
            echo "  traducción: $lang"
        elif [[ -f "$REPO_ROOT/usr/share/locale/$lang/LC_MESSAGES/wallselect.mo" ]]; then
            install -m 644 "$REPO_ROOT/usr/share/locale/$lang/LC_MESSAGES/wallselect.mo" \
                "$LOCALE_DIR/$lang/LC_MESSAGES/wallselect.mo"
            echo "  traducción: $lang"
        else
            echo "  aviso: no se pudo instalar la traducción $lang (falta msgfmt)" >&2
        fi
    done
    shopt -u nullglob
}

echo "Instalando wofi-wallselect para ${USER:-$(id -un)}"
mkdir -p "$BIN_DIR" "$CONFIG_DIR" "$APP_DIR" "$LOCALE_DIR" "$DOC_DIR" "$CACHE_DIR"

# Ejecutable.
backup "$BIN_DIR/wallselect.sh"
install -m 755 "$REPO_ROOT/src/wallselect.sh" "$BIN_DIR/wallselect.sh"

# Tema y configuración de wofi.
backup "$CONFIG_DIR/style.css"
backup "$CONFIG_DIR/wofi.conf"
install -m 644 "$REPO_ROOT/src/style.css" "$CONFIG_DIR/style.css"
install -m 644 "$REPO_ROOT/src/wofi.conf" "$CONFIG_DIR/wofi.conf"

# La configuración personal no se pisa.
if [[ -e "$CONFIG_DIR/config.sh" ]]; then
    echo "  conservando configuración existente: $CONFIG_DIR/config.sh"
else
    install -m 644 "$REPO_ROOT/src/config.sh" "$CONFIG_DIR/config.sh"
fi

# Lanzador con ruta absoluta para que funcione aunque ~/.local/bin no esté
# en el PATH del gestor de aplicaciones.
backup "$APP_DIR/wallselect.desktop"
awk -v exec="$BIN_DIR/wallselect.sh" '
    /^Exec=/     { print "Exec=" exec; next }
    /^TryExec=/  { print "TryExec=" exec; next }
    { print }
' "$REPO_ROOT/usr/share/applications/wallselect.desktop" > "$APP_DIR/wallselect.desktop"
chmod 644 "$APP_DIR/wallselect.desktop"

# Traducciones.
install_locales

# Documentación. El README del repositorio enlaza a las fuentes dentro de
# usr/share/doc; en la instalación todos los documentos quedan juntos.
sed 's#usr/share/doc/wofi-wallselect/##g' "$REPO_ROOT/README.md" > "$DOC_DIR/README.md"
install -m 644 "$REPO_ROOT/LICENSE" "$DOC_DIR/LICENSE"
install -m 644 "$REPO_ROOT/image.png" "$DOC_DIR/image.png"
for doc in AUTHORS ChangeLog DESCRIPTION.md REQUIREMENTS.md; do
    install -m 644 "$REPO_ROOT/usr/share/doc/wofi-wallselect/$doc" "$DOC_DIR/$doc"
done

if ((GEN_THUMBS)); then
    if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
        echo "Generando miniaturas..."
        if ! "$BIN_DIR/wallselect.sh" --generate-thumbs; then
            echo "  no se generaron las miniaturas; revisa WALL_DIR y ejecuta" >&2
            echo "  $BIN_DIR/wallselect.sh --generate-thumbs más tarde." >&2
        fi
    else
        echo "  ImageMagick no encontrado: se omite la generación de miniaturas."
        echo "  El menú funcionará igual usando las imágenes originales."
    fi
fi

if ! command -v wofi >/dev/null 2>&1; then
    echo "  aviso: wofi no está instalado; instálalo para poder abrir el menú." >&2
fi

case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *)
        echo
        echo "Aviso: $BIN_DIR no está en PATH."
        echo "Añádelo a tu shell o usa la ruta completa:"
        echo "  $BIN_DIR/wallselect.sh"
        ;;
esac

echo
echo "Instalación completada."
echo "Abre el menú con:"
echo "  $BIN_DIR/wallselect.sh"
echo "Desinstala con:"
echo "  $REPO_ROOT/uninstall.sh"
