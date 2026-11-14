SHELL := /bin/bash
BIN_DIR ?= $(HOME)/.local/bin
XGETTEXT ?= xgettext
MSGFMT ?= msgfmt

.PHONY: all help check install uninstall thumbs pot mo dist clean

all: help

help:
	@echo "wofi-wallselect"
	@echo
	@echo "  make install     Instala para el usuario actual (sin sudo)"
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

mo:
	@for po in po/*.po; do \
		lang=$$(basename "$$po" .po); \
		mkdir -p "usr/share/locale/$$lang/LC_MESSAGES"; \
		$(MSGFMT) --check -o "usr/share/locale/$$lang/LC_MESSAGES/wallselect.mo" "$$po" || exit 1; \
	done

dist: mo
	rm -rf dist
	install -Dm755 src/wallselect.sh dist/usr/local/bin/wallselect.sh
	install -Dm644 src/style.css dist/usr/share/wofi-wallselect/style.css
	install -Dm644 src/wofi.conf dist/usr/share/wofi-wallselect/wofi.conf
	install -Dm644 src/config.sh dist/usr/share/wofi-wallselect/config.sh
	install -Dm644 usr/share/applications/wallselect.desktop dist/usr/share/applications/wallselect.desktop
	install -Dm644 README.md dist/usr/share/doc/wofi-wallselect/README.md
	@sed -i 's#usr/share/doc/wofi-wallselect/##g' dist/usr/share/doc/wofi-wallselect/README.md
	install -Dm644 LICENSE dist/usr/share/doc/wofi-wallselect/LICENSE
	install -Dm644 image.png dist/usr/share/doc/wofi-wallselect/image.png
	@for doc in AUTHORS ChangeLog DESCRIPTION.md REQUIREMENTS.md; do \
		install -Dm644 "usr/share/doc/wofi-wallselect/$$doc" "dist/usr/share/doc/wofi-wallselect/$$doc"; \
	done
	@for mo in usr/share/locale/*/LC_MESSAGES/wallselect.mo; do \
		lang=$$(basename "$$(dirname "$$(dirname "$$mo")")"); \
		install -Dm644 "$$mo" "dist/usr/share/locale/$$lang/LC_MESSAGES/wallselect.mo"; \
	done
	@echo "Árbol preparado en dist/"

clean:
	rm -rf dist
