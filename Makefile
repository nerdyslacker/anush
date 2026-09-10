CONFIG_HOME ?= $(if $(XDG_CONFIG_HOME),$(XDG_CONFIG_HOME),$(HOME)/.config)
ANUSH_DIR ?= $(CONFIG_HOME)/anush

CONFIG_FILES := $(shell find config -type f ! -name .gitkeep)
SHELL_FILES := $(shell find shell -type f ! -path 'shell/scripts/*')
SCRIPT_FILES := $(shell find shell/scripts -type f)
ASSET_FILES := $(shell find assets -type f)

install:
	@set -e; for src in $(CONFIG_FILES) $(SHELL_FILES) $(ASSET_FILES); do \
		install -Dm644 "$$src" "$(ANUSH_DIR)/$$src"; \
	done
	@set -e; for src in $(SCRIPT_FILES); do \
		install -Dm755 "$$src" "$(ANUSH_DIR)/$$src"; \
	done
	@printf 'Installed anush to %s\n' "$(ANUSH_DIR)"

.PHONY: install
