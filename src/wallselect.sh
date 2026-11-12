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
#   wallselect.sh --generate-thumbs
#   wallselect.sh --help
#
# Atajos dentro del menú:
#
#   Enter   aplicar el fondo seleccionado
#   Esc     cerrar
#


set -uo pipefail


# Internationalize the wallselect.sh script
export TEXTDOMAIN="wallselect"
export TEXTDOMAINDIR="/usr/share/locale"


# ---------------------------------------------------------------------------
# Configuración (se puede sobreescribir en config.sh)
# ---------------------------------------------------------------------------

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/wallselect/config.sh"
[[ -r "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Set the wallpaper directory using the user's configured Pictures folder.
# Allows overriding WALL_DIR through an environment variable.
WALL_DIR="${WALL_DIR:-$(xdg-user-dir PICTURES)/Wallpapers}"

THEME="${THEME:-${XDG_CONFIG_HOME:-$HOME/.config}/wofi/wallselect/style.css}"
WOFI_CONF="${WOFI_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/wofi/wallselect/wofi.conf}"
CACHE_DIR="${CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/wofi-wallselect}"
THUMB_DIR="$CACHE_DIR/thumbs"
THUMB_W="${THUMB_W:-480}"
THUMB_H="${THUMB_H:-300}"
SHUFFLE="${SHUFFLE:-0}"
NOTIFY="${NOTIFY:-1}"
THEME_NOTIFY="${THEME_NOTIFY:-1}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
NORMAL_WINDOW="${NORMAL_WINDOW:-0}"
ROWS="${ROWS:-4}"
MAX_HEIGHT_PCT="${MAX_HEIGHT_PCT:-85}"

WALL_DIR="${WALL_DIR/#\~/$HOME}"
THEME="${THEME/#\~/$HOME}"
WOFI_CONF="${WOFI_CONF/#\~/$HOME}"
CACHE_DIR="${CACHE_DIR/#\~/$HOME}"
WALL_DIR="${WALL_DIR%/}"
[[ "$WALL_DIR" == /* ]]  || WALL_DIR="$PWD/$WALL_DIR"
[[ "$CACHE_DIR" == /* ]] || CACHE_DIR="$PWD/$CACHE_DIR"

[[ "$ROWS" =~ ^[0-9]+$ ]] || ROWS=4
((ROWS < 1)) && ROWS=1
[[ "$MAX_HEIGHT_PCT" =~ ^[0-9]+$ ]] || MAX_HEIGHT_PCT=85
((MAX_HEIGHT_PCT < 40)) && MAX_HEIGHT_PCT=40
((MAX_HEIGHT_PCT > 100)) && MAX_HEIGHT_PCT=100

mkdir -p "$CACHE_DIR" "$THUMB_DIR"

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

die() {
    printf 'wallselect: %s\n' "$1" >&2
    exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

if have magick; then
    MAGICK_BIN="magick"
elif have convert; then
    MAGICK_BIN="convert"
else
    MAGICK_BIN=""
fi

notify() {
    local title="$1" body="${2:-}" icon="${3:-}"
    [[ "$NOTIFY" -eq 1 ]] || return 0
    have notify-send || return 0
    local args=(-a "$(gettext "Fondos")" "$title")
    [[ -n "$body" ]] && args+=("$body")
    [[ -n "$icon" && -f "$icon" ]] && args+=(-i "$icon")
    notify-send "${args[@]}" >/dev/null 2>&1 || true
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
    # Wofi usa ':' como separador de escapes de imagen y el menú se pasa por
    # líneas: ninguno de esos caracteres debe aparecer en la ruta.
    rel="${rel//:/_}"
    rel="${rel//$'\n'/_}"
    printf '%s\n' "$rel"
}

thumb_path() {
    printf '%s/%s\n' "$THUMB_DIR" "$(thumb_rel "$1")"
}

# Genera miniaturas en paralelo. Acepta rutas como argumentos.
generate_thumbs_parallel() {
    (($#)) || return 0
    [[ -n "$MAGICK_BIN" ]] || return 0

    printf '%s\0' "$@" | xargs -0 -r -P "$JOBS" -I{} bash -c '
        src=$1; cache=$2; bin=$3; tw=$4; th=$5; wall_dir=$6
        if [[ $src == "$wall_dir"/* ]]; then
            rel=${src#"$wall_dir"/}
        else
            rel=${src##*/}
        fi
        rel=${rel//:/_}
        rel=${rel//$'\n'/_}
        dst="$cache/$rel"
        if [[ -f $dst && $dst -nt $src ]]; then
            exit 0
        fi
        mkdir -p "$(dirname "$dst")"
        tmp="$dst.tmp.$$"
        if "$bin" "$src" \
            -auto-orient \
            -thumbnail "${tw}x${th}^" \
            -gravity center \
            -extent "${tw}x${th}" \
            -strip -quality 88 \
            "$tmp" >/dev/null 2>&1; then
            mv -f "$tmp" "$dst"
        else
            rm -f "$tmp"
        fi
    ' _ {} "$THUMB_DIR" "$MAGICK_BIN" "$THUMB_W" "$THUMB_H" "$WALL_DIR"
}

# Lista de fondos, delimitada por NUL.
load_files() {
    local -a found=()
    [[ -d "$WALL_DIR" ]] || die "$(printf "$(gettext "no existe la carpeta %s")"  "$WALL_DIR")"

    if [[ "$SHUFFLE" -eq 1 ]]; then
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
                   -o -iname '*.webp' -o -iname '*.gif'  -o -iname '*.heic' -o -iname '*.avif' \) -print0 |
            sort -z
        )
    fi

    printf '%s\0' "${found[@]}"
}

# Fondo actual según DMS.
get_current_wallpaper() {
    local out screen
    if have dms; then
        out=$(dms ipc call wallpaper get 2>/dev/null) || out=""
        case "$out" in
            ERROR:*[Pp]er-monitor*)
                screen=$(dms ipc call outputs current 2>/dev/null |
                    jq -r '.[0] // empty' 2>/dev/null)
                if [[ -z "$screen" ]]; then
                    screen=$(dms ipc call outputs current 2>/dev/null |
                        sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)
                fi
                [[ -n "$screen" ]] && out=$(dms ipc call wallpaper getFor "$screen" 2>/dev/null)
                ;;
            ERROR:*|"") out="" ;;
        esac
    fi
    printf '%s\n' "$out"
}

# Nombre legible de la transición configurada en DMS.
get_transition_label() {
    local raw="fade" session="$HOME/.local/state/dms/session.json"
    if [[ -f "$session" ]] && have jq; then
        raw=$(jq -r '.wallpaperTransition // "fade"' "$session" 2>/dev/null || echo fade)
    fi
    case "$raw" in
        random)      echo "$(gettext "Aleatoria")" ;;
        none)        echo "$(gettext "Sin animación")" ;;
        fade)        echo "$(gettext "Fundido")" ;;
        wipe)        echo "$(gettext "Barrido")" ;;
        disc)        echo "$(gettext "Disco")" ;;
        stripes)     echo "$(gettext "Rayas")" ;;
        "iris bloom") echo "$(gettext "Iris Bloom")" ;;
        pixelate)    echo "$(gettext "Pixelado")" ;;
        portal)      echo "$(gettext "Portal")" ;;
        *)           echo "$raw" ;;
    esac
}

# ---------------------------------------------------------------------------
# Aplicar fondo (DMS primero; swww/swaybg como respaldo)
# ---------------------------------------------------------------------------
apply_wallpaper() {
    local img="$1" cur res screen
    [[ -f "$img" ]] || { notify "$(gettext "Fondo no encontrado")" "$img"; return 1; }

    if have dms; then
        cur=$(dms ipc call wallpaper get 2>/dev/null) || cur=""
        case "$cur" in
            ERROR:*[Pp]er-monitor*)
                screen=$(dms ipc call outputs current 2>/dev/null |
                    jq -r '.[0] // empty' 2>/dev/null)
                if [[ -z "$screen" ]]; then
                    screen=$(dms ipc call outputs current 2>/dev/null |
                        sed -n 's/.*"\([^"]*\)".*/\1/p' | head -n 1)
                fi
                if [[ -n "$screen" ]]; then
                    res=$(dms ipc call wallpaper setFor "$screen" "$img" 2>&1)
                else
                    res="$(gettext "ERROR: no se pudo detectar el monitor")"
                fi
                ;;
            *)
                res=$(dms ipc call wallpaper set "$img" 2>&1)
                ;;
        esac

        if [[ "$res" == SUCCESS:* ]]; then
            notify "$(gettext "Fondo cambiado")" "$(basename "$img")" "$img"
            if [[ "$THEME_NOTIFY" -eq 1 ]]; then
                (
                    sleep 1.2
                    notify "$(gettext "Tema aplicado")" "$(printf "$(gettext "Colores generados desde %s")" "$(basename "$img")")"
    
                    
                ) &
            fi
            return 0
        fi
        printf '%s\n' "$res" > "$CACHE_DIR/last-error.log"
    fi

    # Respaldo fuera de DMS -------------------------------------------------
    if have swww && swww query >/dev/null 2>&1; then
        swww img "$img" \
            --transition-type random \
            --transition-duration 1.2 \
            --transition-fps 60 \
            --transition-bezier .43,1.19,1,.4 >/dev/null 2>&1 &
    else
        pkill -x swaybg >/dev/null 2>&1 || true
        setsid swaybg -i "$img" -m fill >/dev/null 2>&1 &
    fi
    notify "$(gettext "Fondo cambiado")" "$(basename "$img")" "$img"
}

# ---------------------------------------------------------------------------
# Geometría / fondo difuminado del menú
# ---------------------------------------------------------------------------
# Devuelve "ANCHO ALTO" del monitor. Es importante conocer también el alto:
# una ventana más alta que la pantalla no se puede centrar.
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

# Crea una versión difuminada y oscurecida del fondo actual.
make_background() {
    local current="$1" width="$2" height="$3" key bg
    [[ -n "$MAGICK_BIN" ]] || return 1
    [[ -n "$current" && -f "$current" ]] || return 1
    [[ "$current" == \#* ]] && return 1

    key=$(printf '%s' "$current" | md5sum | cut -d' ' -f1)
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
    local -a files=() ordered=() missing=() wofi_args=()
    local img th icon current idx=-1 i count bg="" css_file="" est_h
    local screen_w screen_h win_w cell cols rows row_h max_h icon_size label prompt settings_label=""
    local input_file rc selected src

    have wofi || die "$(gettext "Wofi no está instalado o no está en PATH")"
    
    mapfile -d '' -t files < <(load_files)
    ((${#files[@]})) || die "$(printf "$(gettext "no se encontraron fondos en  %s")"  "$WALL_DIR")"

    # Genera las miniaturas que falten (en segundo plano si hay muchas).
    for img in "${files[@]}"; do
        th=$(thumb_path "$img")
        if [[ ! -f "$th" || "$img" -nt "$th" ]]; then
            missing+=("$img")
        fi
    done
    if ((${#missing[@]})) && [[ -n "$MAGICK_BIN" ]]; then
        generate_thumbs_parallel "${missing[@]}" >/dev/null 2>&1 &
    fi

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
        ordered+=("${files[$idx]}")
        for i in "${!files[@]}"; do
            ((i == idx)) && continue
            ordered+=("${files[$i]}")
        done
        files=("${ordered[@]}")
    fi

    # Geometría responsive.
    read -r screen_w screen_h < <(get_screen_res)
    win_w=$((screen_w * 80 / 100))
    ((win_w < 700)) && win_w=$screen_w
    cols=5
    if ((screen_w < 1300)); then
        cols=5
    elif ((screen_w < 1600)); then
        cols=4
    fi
    cell=$(((win_w - 24 - (cols - 1) * 12) / cols))
    # En wofi image_size es el lado mayor de la miniatura.
    icon_size=$((cell - 24))
    ((icon_size > 250)) && icon_size=250
    ((icon_size < 80)) && icon_size=80

    # Altura: filas visibles y tope para que la ventana quepa centrada.
    # La miniatura se escala por su lado mayor: si es apaisada manda el ancho
    # (THUMB_W) y si es vertical manda el alto (icon_size).
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

    label=$(get_transition_label)
    count=${#files[@]}
    prompt="$(gettext "Buscar fondos") · ${count} · ${label}"

    # Fondo difuminado del menú.
    bg=$(make_background "$current" "$win_w" "$est_h")

    # Entrada de wofi con imágenes (formato "img:RUTA"). Wofi se ejecuta
    # dentro de THUMB_DIR y usa rutas relativas, de modo que la búsqueda solo
    # compara con el nombre del fondo y su carpeta, no con toda la caché.
    input_file="$CACHE_DIR/menu-$$.input"
    : > "$input_file"
    declare -A SRC_BY_ICON=()
    for img in "${files[@]}"; do
        th=$(thumb_path "$img")
        icon=$(thumb_rel "$img")
        if [[ ! -f "$th" || "$img" -nt "$th" ]]; then
            # Respaldo mientras se genera la miniatura: un enlace permite a
            # wofi mostrar la imagen original con la misma ruta relativa.
            mkdir -p "${th%/*}"
            ln -sf "$img" "$th"
        fi
        SRC_BY_ICON["$icon"]="$img"
        printf 'img:%s\n' "$icon" >> "$input_file"
    done

    # Entrada extra para abrir los ajustes de transición de DMS; wofi no
    # permite asignar un atajo personalizado de un solo uso.
    if have dms; then
        settings_label="⚙ $(gettext "Ajustes de transición:") ${label}"
        printf '%s\n' "$settings_label" >> "$input_file"
    fi

    # CSS temporal: tema base + fondo difuminado de la sesión.
    if [[ -r "$THEME" || -n "$bg" ]]; then
        css_file="$CACHE_DIR/menu-$$.css"
        : > "$css_file"
        [[ -r "$THEME" ]] && cat "$THEME" >> "$css_file"
        {
            printf '\n/* %s */\n' "$(gettext "Fondo generado por wallselect")"
            
            printf '#window {\n'
            if [[ -n "$bg" && -f "$bg" ]]; then
                printf '  background-image: url("%s");\n' "$bg"
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
    # hereden los xoffset/yoffset del ~/.config/wofi/config global: en wofi,
    # cualquier offset junto a location=center fuerza la esquina superior
    # izquierda y la ventana deja de centrarse.
    if [[ -r "$WOFI_CONF" ]]; then
        wofi_args+=(--conf "$WOFI_CONF")
    else
        wofi_args+=(--conf /dev/null)
    fi

    if ((NORMAL_WINDOW == 1)); then
        # En modo ventana normal wofi empieza con 1 px de alto y crece después
        # de mapearse. Si se usa --lines, el compositor ya no la recentra y
        # queda pegada al borde inferior. Con --lines 0 se abre directamente
        # con la altura final y el compositor la centra correctamente.
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

    rm -f "$input_file"
    [[ -n "$css_file" ]] && rm -f "$css_file"

    if ((rc != 0)); then
        exit 0
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
# Argumentos
# ---------------------------------------------------------------------------

case "${1:-}" in
    --help|-h)
        cat <<EOF
        $(gettext "
wallselect.sh - seletor de papéis de parede para Wofi + DMS

  --random              Aplica um papel de parede aleatório com a animação do DMS
  --set RUTA            Aplica um papel de parede específico
  --generate-thumbs     Gera/atualiza as miniaturas do cache
  --dir RUTA            Utiliza outro diretório de papéis de parede
  --help                Exibe esta ajuda

Atalhos do menu:

  Enter                 Aplicar papel de parede
  Esc                   Fechar
")
EOF
        exit 0
        ;;
    --dir)
        [[ -n "${2:-}" ]] || die "$(gettext "--dir necesita una ruta")"
        WALL_DIR="${2/#\~/$HOME}"
        WALL_DIR="${WALL_DIR%/}"
        [[ "$WALL_DIR" == /* ]] || WALL_DIR="$PWD/$WALL_DIR"
        ;;
    --set)
        [[ -n "${2:-}" ]] || die "$(gettext "--set necesita una ruta")"
        apply_wallpaper "${2/#\~/$HOME}"
        exit $?
        ;;
    --random)
        mapfile -d '' -t all_files < <(load_files)
        ((${#all_files[@]})) || die "$("printf "$(gettext "no se encontraron fondos en %s")"  "$WALL_DIR")"
        pick=$(printf '%s\0' "${all_files[@]}" | shuf -z -n 1 | tr -d '\0')
        apply_wallpaper "$pick"
        exit $?
        ;;
    --generate-thumbs)
        mapfile -d '' -t all_files < <(load_files)
        
        ((${#all_files[@]})) || die "$("printf "$(gettext "no se encontraron fondos en %s")"  "$WALL_DIR")"
        
        printf "$(gettext "Generando miniaturas de %s fondos en %s ...")\n" "${#all_files[@]}" "$THUMB_DIR"

    
        generate_thumbs_parallel "${all_files[@]}"
        echo "$(gettext "Listo.")"
        exit 0
        ;;
esac

show_menu
