#!/usr/bin/env bash
#
# Configuración opcional de wallselect.
# Se carga automáticamente si existe. Descomenta y ajusta lo que necesites.
#

# Carpeta donde están los fondos.
# WALL_DIR="$HOME/Pictures/Wallpapers"

# Tema de wofi (CSS).
# THEME="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/wallselect/style.css"

# Configuración propia de wofi (posición y comportamiento del menú).
# No la cambies salvo que sepas lo que haces: evita heredar xoffset/yoffset
# de ~/.config/wofi/config, que impiden que la ventana quede centrada.
# WOFI_CONF="${XDG_CONFIG_HOME:-$HOME/.config}/wofi/wallselect/wofi.conf"

# Carpeta de caché (miniaturas y fondos difuminados).
# CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/wofi-wallselect"

# Tamaño de las miniaturas generadas.
# THUMB_W=480
# THUMB_H=300

# Filas visibles del menú y porcentaje máximo de alto de pantalla que puede
# ocupar la ventana. Si las filas no caben, se reducen automáticamente.
# ROWS=4
# MAX_HEIGHT_PCT=85

# 1 = mostrar los fondos en orden aleatorio cada vez que se abre el menú.
# SHUFFLE=0

# 1 = enviar notificaciones al cambiar de fondo.
NOTIFY=0

# 1 = avisar también de que el tema (colores) se ha regenerado.
THEME_NOTIFY=0

# Número de procesos en paralelo al generar miniaturas.
# JOBS=8

# 1 = abrir wofi como ventana normal (útil fuera de compositores wlroots).
# En labwc/wlroots déjalo en 0: usa wlr-layer-shell y centra de forma fiable.
# Si lo pones en 1, wallselect desactiva --lines para que el compositor pueda
# centrar la ventana al abrirse.
# NORMAL_WINDOW=0
