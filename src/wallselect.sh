#!/usr/bin/env bash
#
# wallselect.sh - Selector de fondos de pantalla para wofi + DMS
#
# Usa el shell DMS (Dux Shell) para aplicar el fondo, de modo que se
# reproduzcan sus transiciones animadas (disc, wipe, stripes, iris bloom,
# pixelate, portal, fade o random).
#
# Uso:
#
#   wallselect.sh                 Abre el menú de fondos
#   wallselect.sh --random        Aplica un fondo al azar
#   wallselect.sh --set RUTA      Aplica un fondo concreto
#   wallselect.sh --dir RUTA      Abre el menú en otra carpeta
#   wallselect.sh --generate-thumbs
#   wallselect.sh --help
#
# Atajos dentro del menú:
#
#   Enter   aplicar el fondo seleccionado
#   Esc     cerrar
#
# Traducciones:
#
#   xgettext --language=Shell --keyword=gettext --from-code=UTF-8 \
#       --package-name=wallselect --package-version=1.0 \
#       --output=po/wallselect.pot src/wallselect.sh
#
#   msgmerge --update po/pt_BR.po po/wallselect.pot
#   msgfmt --check -o /dev/null po/pt_BR.po
#

set -uo pipefail

version="20261114"
script_name="$(basename -- "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Internationalization
# ---------------------------------------------------------------------------

TEXTDOMAIN="wallselect"

# gettext es opcional: sin él, los mensajes se muestran en el idioma fuente.
if ! command -v gettext >/dev/null 2>&1; then
    gettext() { printf '%s' "$1"; }
fi

locale_dir() {
    local candidate
    for candidate in \
        "${WALLSELECT_LOCALEDIR:-}" \
        "${XDG_DATA_HOME:-$HOME/.local/share}/locale" \
        "/usr/local/share/locale" \
        "/usr/share/locale"
    do
        [[ -n "$candidate" && -d "$candidate" ]] || continue
        if compgen -G "$candidate/*/LC_MESSAGES/${TEXTDOMAIN}.mo" >/dev/null; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    printf '/usr/share/locale\n'
}

export TEXTDOMAIN
export TEXTDOMAINDIR="${TEXTDOMAINDIR:-$(locale_dir)}"

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

die() {
    printf '%s: %s\n' "$script_name" "$1" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

# Imprime una cadena traducida sustituyendo cada %s por un argumento. Evita
# usar la traducción directamente como formato de printf.
tprintf() {
    local out="$1"
    shift || true
    while [[ "$out" == *%s* ]]; do
        out="${out%%%s*}${1-}${out#*%s}"
        shift || true
    done
    printf '%s' "$out"
}

hash_string() {
    if have md5sum; then
        printf '%s' "$1" | md5sum | cut -d' ' -f1
    elif have cksum; then
        printf '%s' "$1" | cksum | cut -d' ' -f1
    else
        printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'
    fi
}

normalize_path() {
    local path="$1"
    path="${path/#\~/$HOME}"
    [[ "$path" == /* ]] || path="$PWD/$path"
    [[ "$path" == "/" ]] || path="${path%/}"
    printf '%s\n' "$path"
}

bool_value() {
    local value="$1" fallback="$2"
    if [[ "$value" == "0" || "$value" == "1" ]]; then
        printf '%s\n' "$value"
    else
        printf '%s\n' "$fallback"
    fi
}

# ---------------------------------------------------------------------------
# Configuración (se puede sobreescribir en config.sh)
# ---------------------------------------------------------------------------

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

CONFIG_FILE="${WALLSELECT_CONFIG:-$CONFIG_HOME/wofi/wallselect/config.sh}"

# Directorios donde pueden vivir los recursos (style.css, wofi.conf y
# config.sh), tanto en una instalación de usuario como en una del sistema.
asset_dirs=(
    "${WALLSELECT_ASSET_DIR:-}"
    "$SCRIPT_DIR"
    "$SCRIPT_DIR/.."
    "$CONFIG_HOME/wofi/wallselect"
    "$DATA_HOME/wofi-wallselect"
    "/usr/local/share/wofi-wallselect"
    "/usr/share/wofi-wallselect"
)

find_asset() {
    local name="$1" dir
    [[ -n "$name" ]] || return 1
    for dir in "${asset_dirs[@]}"; do
        [[ -n "$dir" && -r "$dir/$name" ]] || continue
        printf '%s\n' "$dir/$name"
        return 0
    done
    return 1
}

if [[ ! -r "$CONFIG_FILE" ]]; then
    CONFIG_FILE=$(find_asset config.sh) || CONFIG_FILE=""
fi
if [[ -n "$CONFIG_FILE" && -r "$CONFIG_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG_FILE"
fi

default_pictures_dir() {
    local dir=""
    if have xdg-user-dir; then
        dir=$(xdg-user-dir PICTURES 2>/dev/null) || dir=""
    fi
    [[ -n "$dir" ]] || dir="$HOME/Pictures"
    printf '%s\n' "$dir"
}

WALL_DIR="${WALL_DIR:-$(default_pictures_dir)/Wallpapers}"
THEME="${THEME:-$CONFIG_HOME/wofi/wallselect/style.css}"
WOFI_CONF="${WOFI_CONF:-$CONFIG_HOME/wofi/wallselect/wofi.conf}"
CACHE_DIR="${CACHE_DIR:-$CACHE_HOME/wofi-wallselect}"
THUMB_W="${THUMB_W:-480}"
THUMB_H="${THUMB_H:-300}"
SHUFFLE="$(bool_value "${SHUFFLE:-0}" 0)"
NOTIFY="$(bool_value "${NOTIFY:-1}" 1)"
THEME_NOTIFY="$(bool_value "${THEME_NOTIFY:-1}" 1)"
NORMAL_WINDOW="$(bool_value "${NORMAL_WINDOW:-0}" 0)"
ROWS="${ROWS:-4}"
MAX_HEIGHT_PCT="${MAX_HEIGHT_PCT:-85}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

[[ "$THUMB_W" =~ ^[0-9]+$ ]] && ((THUMB_W > 0)) || THUMB_W=480
[[ "$THUMB_H" =~ ^[0-9]+$ ]] && ((THUMB_H > 0)) || THUMB_H=300
[[ "$ROWS" =~ ^[0-9]+$ ]] && ((ROWS > 0)) || ROWS=4
[[ "$MAX_HEIGHT_PCT" =~ ^[0-9]+$ ]] || MAX_HEIGHT_PCT=85
((MAX_HEIGHT_PCT < 40)) && MAX_HEIGHT_PCT=40
((MAX_HEIGHT_PCT > 100)) && MAX_HEIGHT_PCT=100
[[ "$JOBS" =~ ^[0-9]+$ ]] && ((JOBS > 0)) || JOBS=$(nproc 2>/dev/null || echo 4)
((JOBS > 0)) || JOBS=4

WALL_DIR="$(normalize_path "$WALL_DIR")"
CACHE_DIR="$(normalize_path "$CACHE_DIR")"

# Si el tema o la configuración de wofi no están en la ruta de usuario,
# búscalos entre los recursos instalados.
[[ -r "$THEME" ]] || THEME=$(find_asset style.css) || THEME=""
[[ -r "$WOFI_CONF" ]] || WOFI_CONF=$(find_asset wofi.conf) || WOFI_CONF=""

if have magick; then
    MAGICK_BIN="magick"
elif have convert; then
    MAGICK_BIN="convert"
else
    MAGICK_BIN=""
fi

update_thumb_dir() {
    local key
    key="$(hash_string "$WALL_DIR")"
    THUMB_DIR="$CACHE_DIR/thumbs/$key"
}
update_thumb_dir

ensure_cache() {
    mkdir -p "$CACHE_DIR" "$THUMB_DIR" || die "$(tprintf "$(gettext "no se pudo crear la caché %s")" "$CACHE_DIR")"
}

set_wall_dir() {
    WALL_DIR="$(normalize_path "$1")"
    update_thumb_dir
}

TMP_INPUT=""
TMP_CSS=""
cleanup_tmp() {
    [[ -n "${TMP_INPUT:-}" ]] && rm -f -- "$TMP_INPUT"
    [[ -n "${TMP_CSS:-}" ]] && rm -f -- "$TMP_CSS"
}
trap cleanup_tmp EXIT INT TERM

notify() {
    local title="$1" body="${2:-}" icon="${3:-}"
    ((NOTIFY == 1)) || return 0
    have notify-send || return 0
    local args=(-a "$(gettext "Fondos")" "$title")
    [[ -n "$body" ]] && args+=("$body")
    [[ -n "$icon" && -f "$icon" ]] && args+=(-i "$icon")
    notify-send "${args[@]}" >/dev/null 2>&1 || true
}

# ---------------------------------------------------------------------------
# Miniaturas
# ---------------------------------------------------------------------------

sanitize_rel() {
    local rel="$1"
    rel="${rel//:/_}"
    rel="${rel//\\/_}"
    rel="${rel//$'\n'/_}"
    rel="${rel//$'\r'/_}"
    printf '%s\n' "$rel"
}

# Ruta relativa de la miniatura dentro de la caché. Se conserva la ruta
# dentro de WALL_DIR para que wofi pueda buscar por nombre de archivo (y por
# carpeta) sin que los hash de la caché ensucien los resultados.
thumb_rel() {
    local src="$1" rel
    if [[ "$src" == "$WALL_DIR"/* ]]; then
        rel="${src#"$WALL_DIR"/}"
    else
        rel="${src##*/}"
    fi
    sanitize_rel "$rel"
}

thumb_path() {
    local src="$1" rel
    [[ -n "$src" ]] || return 1
    rel=$(thumb_rel "$src") || return 1
    [[ -n "$rel" ]] || return 1
    printf '%s/%s\n' "$THUMB_DIR" "$rel"
}

generate_one_thumb() {
    local src="$1" dst tmp
    [[ -n "$MAGICK_BIN" ]] || return 0
    [[ -f "$src" ]] || return 1

    dst=$(thumb_path "$src") || return 1
    [[ -n "$dst" ]] || return 1
    if [[ -f "$dst" && "$dst" -nt "$src" ]]; then
        return 0
    fi

    mkdir -p "$(dirname -- "$dst")" || return 1
    tmp="$dst.tmp.$BASHPID.$RANDOM"
    if "$MAGICK_BIN" "$src" \
        -auto-orient \
        -thumbnail "${THUMB_W}x${THUMB_H}^" \
        -gravity center \
        -extent "${THUMB_W}x${THUMB_H}" \
        -strip -quality 88 \
        "$tmp" >/dev/null 2>&1
    then
        mv -f -- "$tmp" "$dst" && return 0
    fi
    rm -f -- "$tmp"
    return 1
}

# Genera miniaturas en paralelo. Acepta rutas como argumentos.
generate_thumbs_parallel() {
    (($#)) || return 0
    [[ -n "$MAGICK_BIN" ]] || return 1
    ensure_cache

    local src running=0
    for src in "$@"; do
        generate_one_thumb "$src" &
        ((running++))
        if ((running >= JOBS)); then
            wait -n 2>/dev/null || true
            ((running--))
        fi
    done
    wait 2>/dev/null || true
    return 0
}

# Lista de fondos, delimitada por NUL.
load_files() {
    [[ -d "$WALL_DIR" ]] || return 1
    local -a found=()

    if ((SHUFFLE == 1)) && have shuf; then
        mapfile -d '' -t found < <(
            find "$WALL_DIR" -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                   -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.heic' -o -iname '*.avif' \) -print0 |
            shuf -z
        )
    else
        mapfile -d '' -t found < <(
            find "$WALL_DIR" -type f \
                \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
                   -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.heic' -o -iname '*.avif' \) -print0 |
            sort -z
        )
    fi

    ((${#found[@]})) && printf '%s\0' "${found[@]}"
    return 0
}

# ---------------------------------------------------------------------------
# Fondo actual y transición
# ---------------------------------------------------------------------------

normalize_wallpaper() {
    local value="$1"
    value="${value%%$'\n'*}"
    printf '%s' "$value" | sed \
        -e 's/^SUCCESS:[[:space:]]*//' \
        -e 's/^SUCCESS[[:space:]]*$//' \
        -e 's/^"//' \
        -e 's/"$//' \
        -e 's#^file://##'
    printf '\n'
}

get_current_output() {
    local raw="" screen=""
    raw=$(dms ipc call outputs current 2>/dev/null) || return 1
    [[ -n "$raw" ]] || return 1
    if have jq; then
        screen=$(printf '%s' "$raw" | jq -r 'if type == "array" then .[0] // empty else . end' 2>/dev/null) || screen=""
    fi
    [[ -n "$screen" ]] || screen=$(printf '%s\n' "$raw" | sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)
    [[ -n "$screen" ]] || screen=$(printf '%s\n' "$raw" | head -n 1)
    printf '%s\n' "$screen"
}

get_current_wallpaper() {
    local out="" screen=""
    have dms || { printf '\n'; return 0; }

    out=$(dms ipc call wallpaper get 2>/dev/null) || out=""
    case "$out" in
        ERROR:*[Pp]er-monitor*)
            screen=$(get_current_output) || screen=""
            if [[ -n "$screen" ]]; then
                out=$(dms ipc call wallpaper getFor "$screen" 2>/dev/null) || out=""
            else
                out=""
            fi
            ;;
        ERROR:*|"")
            out=""
            ;;
    esac

    normalize_wallpaper "$out"
}

get_transition_label() {
    local raw="fade" session="${XDG_STATE_HOME:-$HOME/.local/state}/dms/session.json"
    if [[ -r "$session" ]]; then
        if have jq; then
            raw=$(jq -r '.wallpaperTransition // "fade"' "$session" 2>/dev/null) || raw=fade
        else
            raw=$(sed -n 's/.*"wallpaperTransition"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$session" | head -n 1)
            [[ -n "$raw" ]] || raw=fade
        fi
    fi

    case "$raw" in
        random)      printf '%s\n' "$(gettext "Aleatoria")" ;;
        none)        printf '%s\n' "$(gettext "Sin animación")" ;;
        fade)        printf '%s\n' "$(gettext "Fundido")" ;;
        wipe)        printf '%s\n' "$(gettext "Barrido")" ;;
        disc)        printf '%s\n' "$(gettext "Disco")" ;;
        stripes)     printf '%s\n' "$(gettext "Rayas")" ;;
        "iris bloom") printf '%s\n' "$(gettext "Iris Bloom")" ;;
        pixelate)    printf '%s\n' "$(gettext "Pixelado")" ;;
        portal)      printf '%s\n' "$(gettext "Portal")" ;;
        *)           echo "$raw" ;;
    esac
}

# ---------------------------------------------------------------------------
# Aplicar fondo (DMS primero; swww/swaybg como respaldo)
# ---------------------------------------------------------------------------

dms_set_wallpaper() {
    local img="$1" cur="" res="" screen=""
    cur=$(dms ipc call wallpaper get 2>/dev/null) || cur=""

    case "$cur" in
        ERROR:*[Pp]er-monitor*)
            screen=$(get_current_output) || screen=""
            if [[ -n "$screen" ]]; then
                res=$(dms ipc call wallpaper setFor "$screen" "$img" 2>&1) || true
            else
                res="ERROR: $(gettext "no se pudo detectar el monitor")"
            fi
            ;;
        *)
            res=$(dms ipc call wallpaper set "$img" 2>&1) || true
            ;;
    esac

    printf '%s\n' "$res"
}

apply_wallpaper() {
    local img="$1" res=""

    [[ -f "$img" ]] || { notify "$(gettext "Fondo no encontrado")" "$img"; return 1; }
    ensure_cache

    if have dms; then
        res=$(dms_set_wallpaper "$img")
        if [[ "$res" == "SUCCESS" || "$res" == SUCCESS:* ]]; then
            notify "$(gettext "Fondo cambiado")" "$(basename -- "$img")" "$img"
            if ((THEME_NOTIFY == 1)); then
                (
                    sleep 1.2
                    notify "$(gettext "Tema aplicado")" \
                        "$(tprintf "$(gettext "Colores generados desde %s")" "$(basename -- "$img")")"
                ) &
            fi
            return 0
        fi
        printf '%s\n' "$res" > "$CACHE_DIR/last-error.log" 2>/dev/null || true
    fi

    if have swww && swww query >/dev/null 2>&1; then
        swww img "$img" \
            --transition-type random \
            --transition-duration 1.2 \
            --transition-fps 60 \
            --transition-bezier .43,1.19,1,.4 >/dev/null 2>&1 &
        notify "$(gettext "Fondo cambiado")" "$(basename -- "$img")" "$img"
        return 0
    fi

    if have swaybg; then
        if have pkill; then
            pkill -x swaybg >/dev/null 2>&1 || true
        fi
        if have setsid; then
            setsid swaybg -i "$img" -m fill >/dev/null 2>&1 &
        else
            swaybg -i "$img" -m fill >/dev/null 2>&1 &
        fi
        notify "$(gettext "Fondo cambiado")" "$(basename -- "$img")" "$img"
        return 0
    fi

    notify "$(gettext "No se pudo aplicar el fondo")" \
        "$(gettext "Instala DMS, swww o swaybg para poder cambiar el fondo.")"
    return 1
}

# ---------------------------------------------------------------------------
# Geometría / fondo difuminado del menú
# ---------------------------------------------------------------------------

# Devuelve "ANCHO ALTO" del monitor.
get_screen_res() {
    local res=""
    if have dms; then
        res=$(dms randr 2>/dev/null | awk '/Resolution:/ {print $2; exit}')
    fi
    if [[ -z "$res" ]] && have wlr-randr; then
        res=$(wlr-randr 2>/dev/null | awk '/current/ {print $1; exit}')
    fi
    if [[ -z "$res" ]] && have xrandr; then
        res=$(xrandr --current 2>/dev/null | awk '/\*/ {print $1; exit}')
    fi

    if [[ "$res" =~ ^([0-9]+)x([0-9]+)$ ]]; then
        printf '%s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    else
        printf '1920 1080\n'
    fi
}

css_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

# Crea una versión difuminada y oscurecida del fondo actual.
make_background() {
    local current="$1" width="$2" height="$3" key bg
    [[ -n "$MAGICK_BIN" ]] || return 1
    [[ -n "$current" && -f "$current" ]] || return 1
    [[ "$current" == \#* ]] && return 1

    key="$(hash_string "$current")"
    bg="$CACHE_DIR/bg-${key}-${width}x${height}.jpg"
    if [[ ! -f "$bg" ]]; then
        "$MAGICK_BIN" "$current" \
            -auto-orient \
            -resize "${width}x${height}^" \
            -gravity center \
            -extent "${width}x${height}" \
            -blur 0x22 \
            -fill '#0a0a10' -colorize 52% \
            -strip -quality 82 \
            "$bg" >/dev/null 2>&1 || return 1
    fi
    printf '%s\n' "$bg"
}

# ---------------------------------------------------------------------------
# Menú principal
# ---------------------------------------------------------------------------

show_menu() {
    have wofi || die "$(gettext "Wofi no está instalado o no está en PATH")"
    [[ -d "$WALL_DIR" ]] || die "$(tprintf "$(gettext "no existe la carpeta %s")" "$WALL_DIR")"

    local -a files=() missing=() wofi_args=()
    local img th icon current idx=-1 i count bg="" css_file="" est_h
    local screen_w screen_h win_w cell cols rows row_h max_h icon_size prompt
    local settings_label="" input_file="" rc=0 selected="" src="" fallback_count=0

    ensure_cache
    mapfile -d '' -t files < <(load_files)
    ((${#files[@]})) || die "$(tprintf "$(gettext "no se encontraron fondos en %s")" "$WALL_DIR")"

    # El fondo actual se coloca primero: wofi no permite preseleccionar una
    # fila, pero al abrir el menú Enter aplica la primera entrada.
    current=$(get_current_wallpaper)
    for i in "${!files[@]}"; do
        if [[ "${files[$i]}" == "$current" ]]; then
            idx=$i
            break
        fi
    done
    if ((idx >= 0)); then
        local -a ordered=("${files[$idx]}")
        for i in "${!files[@]}"; do
            ((i == idx)) && continue
            ordered+=("${files[$i]}")
        done
        files=("${ordered[@]}")
    fi

    # Genera una sola vez, en paralelo, las miniaturas que falten.
    for img in "${files[@]}"; do
        th=$(thumb_path "$img") || continue
        if [[ ! -f "$th" || "$img" -nt "$th" ]]; then
            missing+=("$img")
        fi
    done
    if ((${#missing[@]})) && [[ -n "$MAGICK_BIN" ]]; then
        generate_thumbs_parallel "${missing[@]}"
    fi

    # Geometría responsive.
    read -r screen_w screen_h < <(get_screen_res)
    win_w=$((screen_w * 80 / 100))
    ((win_w < 700)) && win_w=$((screen_w - 40))
    ((win_w < 320)) && win_w=320
    if ((screen_w < 1600)); then
        cols=4
    else
        cols=5
    fi
    cell=$(((win_w - 24 - (cols - 1) * 12) / cols))
    ((cell < 80)) && cell=80
    # En wofi image_size es el lado mayor de la miniatura.
    icon_size=$((cell - 24))
    ((icon_size > 250)) && icon_size=250
    ((icon_size < 80)) && icon_size=80

    # Altura: filas visibles y tope para que la ventana quepa centrada.
    if ((THUMB_W >= THUMB_H)); then
        row_h=$((icon_size * THUMB_H / THUMB_W + 32))
    else
        row_h=$((icon_size + 32))
    fi
    rows=$ROWS
    max_h=$((screen_h * MAX_HEIGHT_PCT / 100))
    while ((rows > 1 && rows * row_h + 90 > max_h)); do
        ((rows--))
    done
    est_h=$((rows * row_h + 90))
    ((est_h > max_h)) && est_h=$max_h

    # Entradas de wofi con imágenes ("img:RUTA"). Wofi se ejecuta dentro de
    # THUMB_DIR y usa rutas relativas para que la búsqueda solo compare con el
    # nombre del fondo y su carpeta, no con toda la caché.
    input_file=$(mktemp "$CACHE_DIR/menu-XXXXXX.input") || die "$(gettext "no se pudo crear el archivo temporal del menú")"
    TMP_INPUT="$input_file"
    : > "$input_file"
    local -A SRC_BY_ICON=()

    for img in "${files[@]}"; do
        th=$(thumb_path "$img") || continue
        if [[ -f "$th" && ! "$img" -nt "$th" ]]; then
            icon=$(thumb_rel "$img")
        else
            # Respaldo: wofi carga la imagen original si no hay miniatura.
            icon="$img"
            ((fallback_count++))
        fi
        [[ -n "$icon" ]] || continue
        [[ "$icon" == *$'\n'* ]] && continue
        SRC_BY_ICON["$icon"]="$img"
        printf 'img:%s\n' "$icon" >> "$input_file"
    done

    count=${#SRC_BY_ICON[@]}
    if ((count == 0)); then
        notify "$(gettext "Wallselect")" "$(gettext "No hay fondos que mostrar.")"
        die "$(tprintf "$(gettext "no hay fondos que mostrar en %s")" "$WALL_DIR")"
    fi
    if ((fallback_count > 0)) && [[ -z "$MAGICK_BIN" ]]; then
        notify "$(gettext "Wallselect")" \
            "$(gettext "ImageMagick no está instalado: se usarán las imágenes originales.")"
    fi

    local transition_label
    transition_label=$(get_transition_label)

    # Entrada extra para abrir los ajustes de transición de DMS; wofi no
    # permite asignar un atajo personalizado de un solo uso.
    if have dms; then
        settings_label="⚙ $(gettext "Ajustes de transición:") ${transition_label}"
        printf '%s\n' "$settings_label" >> "$input_file"
    fi

    prompt="$(gettext "Buscar fondos") · ${count} · ${transition_label}"

    # Fondo difuminado del menú.
    bg=$(make_background "$current" "$win_w" "$est_h")

    # CSS temporal: tema base + fondo difuminado de la sesión.
    if [[ -r "$THEME" || -n "$bg" ]]; then
        css_file=$(mktemp "$CACHE_DIR/menu-XXXXXX.css") || die "$(gettext "no se pudo crear el archivo CSS temporal")"
        TMP_CSS="$css_file"
        : > "$css_file"
        [[ -r "$THEME" ]] && cat "$THEME" >> "$css_file"
        {
            printf '\n/* %s */\n' "$(gettext "Fondo generado por wallselect")"
            printf '#window {\n'
            if [[ -n "$bg" && -f "$bg" ]]; then
                printf '  background-image: url("%s");\n' "$(css_escape "$bg")"
                printf '  background-size: cover;\n'
                printf '  background-position: center;\n'
            fi
            printf '}\n'
        } >> "$css_file"
    fi

    wofi_args=(
        --dmenu
        --allow-images
        --insensitive
        --no-actions
        --cache-file /dev/null
        --location center
        --width "$win_w"
        --height "$est_h"
        --columns "$cols"
        --prompt "$prompt"
        --define "image_size=$icon_size"
    )

    # Configuración propia del selector. Es imprescindible para que no se
    # hereden los xoffset/yoffset del ~/.config/wofi/config global.
    if [[ -r "$WOFI_CONF" ]]; then
        wofi_args+=(--conf "$WOFI_CONF")
    else
        wofi_args+=(--conf /dev/null)
    fi

    if ((NORMAL_WINDOW == 1)); then
        # En modo ventana normal wofi empieza con 1 px de alto y crece después
        # de mapearse. Con --lines 0 se abre con la altura final.
        wofi_args+=(--normal-window --lines 0)
    else
        wofi_args+=(--lines "$rows")
    fi

    [[ -n "$css_file" ]] && wofi_args+=(--style "$css_file")

    selected=$(
        cd "$THUMB_DIR" || exit 1
        wofi "${wofi_args[@]}" < "$input_file" 2>"$CACHE_DIR/wofi.log"
    )
    rc=$?

    rm -f -- "$input_file"
    [[ -n "$css_file" ]] && rm -f -- "$css_file"
    TMP_INPUT=""
    TMP_CSS=""

    if ((rc != 0)); then
        if ((rc > 1)); then
            notify "$(gettext "Error de wofi")" \
                "$(gettext "Consulta el log para más detalles")"
            printf '%s (código %s):\n' "$(gettext "Error de wofi")" "$rc" >&2
            [[ -r "$CACHE_DIR/wofi.log" ]] && cat "$CACHE_DIR/wofi.log" >&2
        fi
        return 0
    fi

    if [[ "$selected" == img:* ]]; then
        icon="${selected#img:}"
        src="${SRC_BY_ICON[$icon]:-}"
        if [[ -n "$src" && -f "$src" ]]; then
            apply_wallpaper "$src"
        else
            notify "$(gettext "Fondo no encontrado")" "$icon"
        fi
    elif [[ -n "$settings_label" && "$selected" == "$settings_label" ]]; then
        # Ajustes de transición de DMS (pestaña Wallpaper).
        sleep 0.15
        dms ipc call settings openWith wallpaper >/dev/null 2>&1 ||
            dms ipc call settings open >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------------------
# Ayuda
# ---------------------------------------------------------------------------

usage() {
    cat <<EOF
$(gettext "
wallselect.sh - Selector de fondos de pantalla para Wofi + DMS

USO: wallselect.sh [OPCIÓN]


DESCRIPCIÓN:

Explora tu colección de fondos de pantalla, visualiza miniaturas y aplica imágenes con transiciones animadas de DMS.


OPCIONES:

--random Selecciona y aplica un fondo de pantalla aleatorio.

--set ARCHIVO Aplica directamente el fondo de pantalla especificado.

--dir DIRECTORIO Establece un directorio personalizado para los fondos de pantalla.

--generate-thumbs Genera o actualiza las miniaturas de las imágenes en caché.

--help, -h Muestra este mensaje de ayuda y finaliza.

--version, -v versión


ATAJOS DEL MENÚ: Enter Aplica el fondo de pantalla seleccionado.

Esc Cierra el selector sin modificar el fondo de pantalla actual.


FORMATOS COMPATIBLES: JPG, JPEG, PNG, WEBP, GIF, HEIC y AVIF.


CARACTERÍSTICAS:

Integración con Wofi y DMS.
Transiciones animadas entre fondos de pantalla.
Generación paralela de miniaturas.
Vista previa con fondo desenfocado.
Notificaciones al cambiar el fondo de pantalla.
Aplicación alternativa mediante swww o swaybg.")
EOF
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------

action="menu"
set_path=""

while (($#)); do
    case "$1" in
        --help|-h)
            usage
            exit 0
            ;;
        --version|-v)
            printf '%s %s\n' "$script_name" "$version"
            exit 0
            ;;
        --random)
            action="random"
            ;;
        --set)
            [[ -n "${2:-}" ]] || die "$(gettext "--set necesita una ruta")"
            set_path="$(normalize_path "$2")"
            action="set"
            shift
            ;;
        --dir)
            [[ -n "${2:-}" ]] || die "$(gettext "--dir necesita una ruta")"
            set_wall_dir "$2"
            shift
            ;;
        --dir=*)
            set_wall_dir "${1#--dir=}"
            ;;
        --generate-thumbs)
            action="thumbs"
            ;;
        *)
            die "$(tprintf "$(gettext "opción desconocida: %s")" "$1")"
            ;;
    esac
    shift
done

case "$action" in
    set)
        ensure_cache
        apply_wallpaper "$set_path"
        exit $?
        ;;
    random)
        [[ -d "$WALL_DIR" ]] || die "$(tprintf "$(gettext "no existe la carpeta %s")" "$WALL_DIR")"
        ensure_cache
        mapfile -d '' -t all_files < <(load_files)
        ((${#all_files[@]})) || die "$(tprintf "$(gettext "no se encontraron fondos en %s")" "$WALL_DIR")"
        pick=$((RANDOM % ${#all_files[@]}))
        apply_wallpaper "${all_files[$pick]}"
        exit $?
        ;;
    thumbs)
        [[ -d "$WALL_DIR" ]] || die "$(tprintf "$(gettext "no existe la carpeta %s")" "$WALL_DIR")"
        [[ -n "$MAGICK_BIN" ]] || die "$(gettext "ImageMagick no está instalado. Instálalo para generar miniaturas.")"
        ensure_cache
        mapfile -d '' -t all_files < <(load_files)
        ((${#all_files[@]})) || die "$(tprintf "$(gettext "no se encontraron fondos en %s")" "$WALL_DIR")"
        printf '%s\n' "$(tprintf "$(gettext "Generando miniaturas de %s fondos en %s ...")" "${#all_files[@]}" "$THUMB_DIR")"
        generate_thumbs_parallel "${all_files[@]}"
        printf '%s\n' "$(gettext "Listo.")"
        exit 0
        ;;
    menu)
        show_menu
        ;;
esac
