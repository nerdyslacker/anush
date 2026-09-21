#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d /tmp/anush-theme-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/desktop-config"
export XDG_DATA_HOME="$tmp/data"
export XDG_DATA_DIRS="$tmp/share"
export ANUSH_CONFIG_DIR="$tmp/config"
export ANUSH_STATE_DIR="$tmp/state"
export ANUSH_THEME_NO_RELOAD=1
mkdir -p "$tmp/bin" "$ANUSH_CONFIG_DIR/rofi" "$ANUSH_CONFIG_DIR/kitty" \
    "$ANUSH_CONFIG_DIR/skarwm" "$ANUSH_STATE_DIR" \
    "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/skarwm" \
    "$XDG_DATA_DIRS/themes/adw-gtk3/gtk-3.0" "$ANUSH_CONFIG_DIR/matugen"
cp "$repo/config/matugen/config.toml" "$ANUSH_CONFIG_DIR/matugen/config.toml"
cp "$repo/config/skarwm/config.rc" "$ANUSH_CONFIG_DIR/skarwm/config.rc"
cp "$repo/config/skarwm/config.rc" "$XDG_CONFIG_HOME/skarwm/config.rc"
touch "$tmp/wallpaper.png"
printf '%s\n' '{"theme":{"palette":null}}' \
    >"$ANUSH_STATE_DIR/shell-state.json"
printf '%s\n' '/* keep user CSS */' >"$XDG_CONFIG_HOME/gtk-3.0/gtk.css"

cat >"$tmp/bin/matugen" <<'EOF'
#!/bin/sh
if [ "${MATUGEN_FAIL:-0}" -eq 1 ]; then
    printf '%s\n' 'simulated Matugen failure' >&2
    exit 1
fi
cat <<'JSON'
{"colors":{"dark":{"background":"#101114","on_background":"#e4e2e7","surface":"#101114","on_surface":"#e4e2e7","surface_variant":"#303036","surface_container":"#1c1b20","on_surface_variant":"#c8c5ce","primary":"#b8c4ff","on_primary":"#15255c","primary_fixed":"#dce1ff","secondary":"#c3c5dd","tertiary":"#e5bad7","error":"#ffb4ab","error_container":"#93000a","outline":"#92909a","outline_variant":"#47464f"}}}
JSON
EOF

cat >"$tmp/bin/magick" <<'EOF'
#!/usr/bin/env python3
import sys
sys.stdout.buffer.write(bytes((48, 64, 80, 255)) * 96 * 54)
EOF
chmod +x "$tmp/bin/matugen" "$tmp/bin/magick"
export PATH="$tmp/bin:/usr/bin:/bin"

"$repo/shell/scripts/generate-wallpaper-theme" "$tmp/wallpaper.png" dark
python3 - "$ANUSH_STATE_DIR/shell-state.json" <<'PY'
import json, sys
palette = json.load(open(sys.argv[1]))["theme"]["palette"]
assert palette["generator"] == "matugen"
assert palette["semantic"]["primary"] == "#b8c4ff"
assert palette["material"]["surface_container"] == "#1c1b20"
PY
grep -q '^selection_background #b8c4ff$' \
    "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^url_color #b8c4ff$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color4 #b8c4ff$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color12 #b8c4ff$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^sel_outer_border  : #b8c4ff$' \
    "$XDG_CONFIG_HOME/skarwm/config.rc"

ANUSH_ACCENT_NO_RELOAD=1 "$repo/shell/scripts/apply-accent" '#6574a8'
grep -q '^selection_background #6574a8$' \
    "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^url_color #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color4 #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color12 #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^sel_outer_border  : #6574a8$' \
    "$XDG_CONFIG_HOME/skarwm/config.rc"

"$repo/shell/scripts/apply-application-theme" gtk
"$repo/shell/scripts/apply-application-theme" qt
grep -q 'keep user CSS' "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
grep -q 'Anush Matugen (managed)' "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
grep -q '^gtk-theme-name=adw-gtk3$' "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -q 'color_scheme_path=.*/anush-matugen.conf' \
    "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
test -f "$XDG_DATA_HOME/color-schemes/AnushMatugen.colors"

MATUGEN_FAIL=1 "$repo/shell/scripts/generate-wallpaper-theme" \
    "$tmp/wallpaper.png" dark
python3 - "$ANUSH_STATE_DIR/shell-state.json" <<'PY'
import json, sys
palette = json.load(open(sys.argv[1]))["theme"]["palette"]
assert palette["generator"] == "anush"
assert "material" not in palette
PY

printf '%s\n' 'theme generation tests passed'
