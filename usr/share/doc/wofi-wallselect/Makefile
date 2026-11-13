SHELL := /bin/bash
DEST  ?= $(HOME)/.config/wofi/wallselect

.PHONY: all help install uninstall thumbs check

all: help

help:
	@echo "wofi-wallselect"
	@echo
	@echo "  make install     Instala script, tema, wofi.conf y configuración"
	@echo "  make uninstall   Desinstala (conserva config.sh y la caché)"
	@echo "  make thumbs      Regenera la caché de miniaturas"
	@echo "  make check       Valida el script, el tema y la configuración de wofi"

install:
	bash ./install.sh

uninstall:
	bash ./uninstall.sh

thumbs:
	$(DEST)/wallselect.sh --generate-thumbs

check:
	bash -n src/wallselect.sh
	bash -n src/config.sh
	test -s src/style.css
	test -s src/wofi.conf
	grep -qx 'location=center' src/wofi.conf
	! grep -Eq '^[[:space:]]*(xoffset|yoffset)[[:space:]]*=' src/wofi.conf
	command -v wofi >/dev/null
	@echo "Validación correcta."
