PREFIX ?= /usr
ODIN ?= odin
DATADIR ?= $(PREFIX)/share
BINDIR ?= $(PREFIX)/bin
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

	@printf 'Installed anush to %s\n' "$(DESTDIR)$(ANUSH_DIR)"

clean:
	rm -rf build

test: build/anushctl
	./tests/anushctl.sh

.PHONY: all install clean test
