# Descripción

**Nombre:** wofi-wallselect

**Resumen:** Selector de fondos de pantalla para wofi con transiciones
animadas de DMS (DankMaterialShell).

**Descripción larga:**

wofi-wallselect es un menú de selección de fondos para wofi que muestra una
rejilla de miniaturas, permite filtrar por nombre y aplica la imagen elegida a
través de DMS. Al usar DMS como backend, el cambio de fondo reproduce las
transiciones animadas configuradas en el shell (fundido, barrido, disco, iris
bloom, pixelado, portal, etc.) en lugar de un cambio instantáneo.

El menú genera y cachea sus propias miniaturas por carpeta, usa una versión
difuminada del fondo actual como fondo de la ventana y coloca el wallpaper
activo en primer lugar. Si no hay ImageMagick, usa las imágenes originales.
Incluye una entrada para abrir los ajustes de transición de DMS y respaldos
para `swww` y `swaybg` cuando DMS no está disponible.

**Palabras clave:** wofi, wallpaper, fondos, wayland, dms, dankmaterialshell,
swww, labwc, hyprland, matugen, selector, transiciones

**Categorías:** Settings;DesktopSettings;

**Licencia:** MIT

**Lenguaje:** Bash + CSS (tema de wofi)
