# Requerimientos

## Obligatorios

| Dependencia | Versión / notas | Uso |
|-------------|-----------------|-----|
| `bash` | 4.4 o superior | Ejecutar el script (`mapfile -d`, `wait -n`) |
| `wofi` | 1.4.1 o superior (probado con 1.5.3) | Menú, imágenes y búsqueda |
| `coreutils` | `sort`, `head`, `nproc`, `md5sum`, `mktemp`, `install` | Script e instalador |
| `findutils` | `find` | Listar fondos |
| `sed` y `awk` | Cualquier implementación POSIX | Parseo de DMS y geometría |

## Recomendados

| Dependencia | Uso | Si falta… |
|-------------|-----|-----------|
| `DMS` (DankMaterialShell) | Aplicar el fondo con transiciones animadas | Se intenta `swww` y luego `swaybg` |
| `ImageMagick` (`magick` o `convert`) | Miniaturas y fondo difuminado | Usa las imágenes originales y color sólido |
| `jq` | Modo multi-monitor y etiqueta de transición | Se usa `sed` como respaldo |
| `libnotify` (`notify-send`) | Notificaciones | Sin notificaciones |
| `xdg-user-dirs` (`xdg-user-dir`) | Detectar la carpeta Imágenes | Usa `~/Pictures` |
| `wlr-randr` o `xrandr` | Detectar resolución si DMS no responde | Asume 1920×1080 |
| `gettext` | Traducciones | Los mensajes se muestran en el idioma fuente |
| Fuente `Inter` | Tipografía del tema CSS | wofi usa la fuente por defecto del sistema |

## Opcionales

- `swww`: transiciones alternativas si no usas DMS.
- `swaybg`: último respaldo para mostrar el fondo.
- `util-linux` (`setsid`): evita que `swaybg` quede atado a la terminal.

> **Nota sobre wofi:** el menú usa `wlr-layer-shell`. Si tu compositor no lo
> implementa (por ejemplo, algunos entornos de escritorio Wayland que no son
> wlroots), activa `NORMAL_WINDOW=1` en `config.sh`.

> **Nota sobre swww:** en algunas sesiones Wayland (por ejemplo, ciertas
> versiones de labwc/wlroots) `swww` puede fallar al decodificar imágenes con
> `InvalidEnumDiscriminant(("Format", ...))`. En ese caso usa DMS, que es el
> backend recomendado por este proyecto.

> **Nota sobre `yad`:** ya no es necesario. Los avisos se muestran por consola
> y, si está disponible, mediante `notify-send`.

## Instalación por distribución

### Arch Linux

```bash
sudo pacman -S wofi imagemagick jq libnotify wlr-randr xdg-user-dirs gettext
```

### Debian / Ubuntu

```bash
sudo apt install wofi imagemagick jq libnotify-bin wlr-randr xdg-user-dirs gettext
```

### Fedora

```bash
sudo dnf install wofi ImageMagick jq libnotify wlr-randr xdg-user-dirs gettext
```

### openSUSE

```bash
sudo zypper install wofi ImageMagick jq libnotify-tools wlr-randr xdg-user-dirs gettext
```

## DMS (DankMaterialShell)

DMS no suele estar en los repositorios de las distribuciones. Instálalo desde
su proyecto oficial y asegúrate de que el servicio de usuario está activo:

```bash
systemctl --user status dms
```

Comandos que utiliza este menú:

```bash
dms randr
dms ipc call wallpaper get
dms ipc call wallpaper set RUTA
dms ipc call wallpaper getFor MONITOR
dms ipc call wallpaper setFor MONITOR RUTA
dms ipc call outputs current
dms ipc call settings openWith wallpaper
dms ipc call settings open
```
