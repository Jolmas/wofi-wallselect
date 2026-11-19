SHELL := /bin/bash
BIN_DIR ?= $(HOME)/.local/bin
DESTDIR ?=
XGETTEXT ?= xgettext
MSGFMT ?= msgfmt

.PHONY: all help check install uninstall install-system thumbs pot mo dist clean

all: help

help:
	@echo "wofi-wallselect"
	@echo
	@echo "  make install     Instala para el usuario actual (sin sudo)"
	@echo "  make install-system  Instala dist/ en el sistema (sudo; admite DESTDIR)"
	@echo "  make uninstall   Desinstala (conserva config.sh y la caché)"
	@echo "  make thumbs      Regenera la caché de miniaturas"
	@echo "  make check       Valida scripts, tema, configuración y traducciones"
	@echo "  make pot         Regenera po/wallselect.pot desde src/wallselect.sh"
	@echo "  make mo          Compila los .po a usr/share/locale/"
	@echo "  make dist        Prepara un árbol FHS en dist/ para empaquetar"
	@echo "  make clean       Elimina dist/"

check:
	bash -n src/wallselect.sh src/config.sh install.sh uninstall.sh
	test -s src/style.css
	test -s src/wofi.conf
	test -s usr/share/applications/wallselect.desktop
	test -s README.md
	test -s LICENSE
	test -s image.png
	grep -qx 'location=center' src/wofi.conf
	! grep -Eq '^[[:space:]]*(xoffset|yoffset)[[:space:]]*=' src/wofi.conf
	@if command -v $(MSGFMT) >/dev/null 2>&1; then \
		for po in po/*.po; do \
			$(MSGFMT) --check -o /dev/null "$$po" || exit 1; \
		done; \
	fi
	@if command -v desktop-file-validate >/dev/null 2>&1; then \
		desktop-file-validate usr/share/applications/wallselect.desktop; \
	fi
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck -S error src/wallselect.sh install.sh uninstall.sh; \
	fi
	@echo "Validación correcta."

install:
	bash ./install.sh

uninstall:
	bash ./uninstall.sh

thumbs:
	$(BIN_DIR)/wallselect.sh --generate-thumbs

pot:
	$(XGETTEXT) --language=Shell \
		--keyword=gettext \
		--from-code=UTF-8 \
		--package-name=wallselect \
		--package-version=1.0 \
		--msgid-bugs-address="kurumin@disroot.org" \
		--output=po/wallselect.pot \
		src/wallselect.sh

# Cuando se invoca con sudo (p. ej. `sudo make install-system`), todo el
# make corre como root y los artefactos generados dentro del repositorio
# quedarían en root. Los devolvemos al usuario original para que pueda
# borrarlos o regenerarlos sin privilegios.
RESTORE_OWNER = if [[ -n "$${SUDO_USER:-}" ]]; then \
	chown -R -- "$$SUDO_USER" "$1" || echo "aviso: no se pudo devolver $1 a $$SUDO_USER" >&2; \
fi

mo:
	@for po in po/*.po; do \
		lang=$$(basename "$$po" .po); \
		mkdir -p "usr/share/locale/$$lang/LC_MESSAGES"; \
		$(MSGFMT) --check -o "usr/share/locale/$$lang/LC_MESSAGES/wallselect.mo" "$$po" || exit 1; \
	done
	@$(call RESTORE_OWNER,usr/share/locale)

dist: mo
	rm -rf dist
	install -Dm755 src/wallselect.sh dist/usr/local/bin/wallselect.sh
	install -Dm644 src/style.css dist/usr/local/share/wofi-wallselect/style.css
	install -Dm644 src/wofi.conf dist/usr/local/share/wofi-wallselect/wofi.conf
	install -Dm644 src/config.sh dist/usr/local/share/wofi-wallselect/config.sh
	install -Dm644 usr/share/applications/wallselect.desktop dist/usr/local/share/applications/wallselect.desktop
	install -Dm644 README.md dist/usr/local/share/doc/wofi-wallselect/README.md
	@sed -i 's#usr/share/doc/wofi-wallselect/##g' dist/usr/local/share/doc/wofi-wallselect/README.md
	install -Dm644 LICENSE dist/usr/local/share/doc/wofi-wallselect/LICENSE
	install -Dm644 image.png dist/usr/local/share/doc/wofi-wallselect/image.png
	@for doc in AUTHORS ChangeLog DESCRIPTION.md REQUIREMENTS.md; do \
		install -Dm644 "usr/share/doc/wofi-wallselect/$$doc" "dist/usr/local/share/doc/wofi-wallselect/$$doc"; \
	done
	@for mo in usr/share/locale/*/LC_MESSAGES/wallselect.mo; do \
		lang=$$(basename "$$(dirname "$$(dirname "$$mo")")"); \
		install -Dm644 "$$mo" "dist/usr/local/share/locale/$$lang/LC_MESSAGES/wallselect.mo"; \
	done
	@$(call RESTORE_OWNER,dist)
	@echo "Árbol preparado en dist/ (todo bajo usr/local)"

# Instala el árbol FHS de dist/ en el sistema. Sin DESTDIR requiere root;
# con DESTDIR=... vuelca los archivos en esa raíz (útil al empaquetar).
# --no-preserve=ownership evita que los archivos instalados hereden el dueño
# de dist/ (el usuario del repo) cuando se copian con sudo.
install-system: dist
	mkdir -p -- "$(DESTDIR)/usr"
	cp -a --no-preserve=ownership -- dist/usr/. "$(DESTDIR)/usr/"
	@echo "Instalado en $(DESTDIR)/usr"

clean:
	rm -rf dist
