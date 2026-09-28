PREFIX ?= /usr
ODIN ?= odin
DATADIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
LIBEXECDIR ?= $(PREFIX)/libexec
ANUSH_DIR ?= $(DATADIR)/anush

CONFIG_FILES := $(shell find config -type f ! -name .gitkeep)
SHELL_FILES  := $(shell find shell -type f ! -path 'shell/scripts/*')
SCRIPT_FILES := $(shell find shell/scripts -type f)
ASSET_FILES  := $(shell find assets -type f)
ANUSHCTL_SRCS := $(shell find cmd/anushctl -name '*.odin')

all: build/anushctl

build/anushctl: $(ANUSHCTL_SRCS)
	@mkdir -p build
	$(ODIN) build cmd/anushctl -o:speed -out:$@

install: build/anushctl
	@set -e; \
	for src in $(CONFIG_FILES) $(SHELL_FILES) $(ASSET_FILES); do \
		install -Dm644 "$$src" "$(DESTDIR)$(ANUSH_DIR)/$$src"; \
	done

	@set -e; \
	for src in $(SCRIPT_FILES); do \
		install -Dm755 "$$src" "$(DESTDIR)$(ANUSH_DIR)/$$src"; \
	done

	install -Dm755 build/anushctl \
		"$(DESTDIR)$(BINDIR)/anushctl"
	install -Dm755 shell/scripts/hotspot/hotspot-limit-enforcer \
		"$(DESTDIR)$(LIBEXECDIR)/anush-hotspot-limit-enforcer"
	install -Dm755 shell/scripts/hotspot/hotspot-create-ap-helper \
		"$(DESTDIR)$(LIBEXECDIR)/anush-hotspot-create-ap-helper"
	install -Dm644 packaging/org.anush.hotspot-limit.policy \
		"$(DESTDIR)$(DATADIR)/polkit-1/actions/org.anush.hotspot-limit.policy"
	install -Dm644 packaging/org.anush.hotspot-create-ap.policy \
		"$(DESTDIR)$(DATADIR)/polkit-1/actions/org.anush.hotspot-create-ap.policy"

	@printf 'Installed anush to %s\n' "$(DESTDIR)$(ANUSH_DIR)"

clean:
	rm -rf build

test: build/anushctl
	./tests/anushctl.sh
	./tests/config-loading.sh
	./tests/hotspot-control.sh
	./tests/icon-theme.sh
	./tests/launcher-search.sh
	./tests/phone-control.sh
	./tests/picom-control.sh
	./tests/theme-generation.sh

.PHONY: all install clean test
