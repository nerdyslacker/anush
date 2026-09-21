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
printf '%s\n' '{"theme":{"palette":null,"wallpaperEnabled":true}}' \
    >"$ANUSH_STATE_DIR/shell-state.json"
printf '%s\n' '/* keep user CSS */' >"$XDG_CONFIG_HOME/gtk-3.0/gtk.css"

cat >"$tmp/bin/matugen" <<'EOF'
#!/bin/sh
if [ "${MATUGEN_FAIL:-0}" -eq 1 ]; then
    printf '%s\n' 'simulated Matugen failure' >&2
    exit 1
fi
cat <<'JSON'
{"colors":{"background":{"dark":{"color":"#101114"}},"on_background":{"dark":{"color":"#e4e2e7"}},"surface":{"dark":{"color":"#101114"}},"on_surface":{"dark":{"color":"#e4e2e7"}},"surface_variant":{"dark":{"color":"#303036"}},"surface_container":{"dark":{"color":"#1c1b20"}},"on_surface_variant":{"dark":{"color":"#c8c5ce"}},"primary":{"dark":{"color":"#b8c4ff"}},"on_primary":{"dark":{"color":"#15255c"}},"primary_fixed":{"dark":{"color":"#dce1ff"}},"secondary":{"dark":{"color":"#c3c5dd"}},"tertiary":{"dark":{"color":"#e5bad7"}},"error":{"dark":{"color":"#ffb4ab"}},"error_container":{"dark":{"color":"#93000a"}},"outline":{"dark":{"color":"#92909a"}},"outline_variant":{"dark":{"color":"#47464f"}}}}
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
assert palette["shellGenerator"] == "anush"
assert palette["semantic"]["primary"] == "#507395"
assert palette["material"]["primary"] == "#b8c4ff"
assert palette["material"]["surface_container"] == "#1c1b20"
PY
grep -q '^selection_background #507395$' \
    "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^url_color #507395$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color4 #507395$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color12 #507395$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^sel_outer_border  : #507395$' \
    "$XDG_CONFIG_HOME/skarwm/config.rc"

"$repo/shell/scripts/save-wallpaper-preset" \
    "$ANUSH_STATE_DIR/shell-state.json" \
    "$ANUSH_CONFIG_DIR/themes/presets" "Snake Night"
python3 - "$ANUSH_CONFIG_DIR/themes/presets/user-snake-night.json" <<'PY'
import json, sys
preset = json.load(open(sys.argv[1]))
assert preset["id"] == "wallpaper-snake-night"
assert preset["name"] == "Snake Night"
assert preset["generator"] == "matugen"
assert preset["accentOverride"] == "#507395"
assert preset["colors"]["background"] == "#263340"
PY
"$repo/shell/scripts/load-theme-presets" \
    "$ANUSH_CONFIG_DIR/themes/presets" | grep -q 'wallpaper-snake-night'
if "$repo/shell/scripts/save-wallpaper-preset" \
        "$ANUSH_STATE_DIR/shell-state.json" \
        "$ANUSH_CONFIG_DIR/themes/presets" "snake night" \
        >"$tmp/duplicate.out" 2>"$tmp/duplicate.err"; then
    printf '%s\n' 'duplicate preset name was unexpectedly accepted' >&2
    exit 1
fi
grep -qi 'already exists' "$tmp/duplicate.err"

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
