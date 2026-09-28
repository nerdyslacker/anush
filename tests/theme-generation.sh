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
    "$ANUSH_CONFIG_DIR/fastfetch" \
    "$ANUSH_CONFIG_DIR/skarwm" "$ANUSH_STATE_DIR" \
    "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_CONFIG_HOME/skarwm" \
    "$XDG_DATA_DIRS/themes/adw-gtk3/gtk-3.0" "$ANUSH_CONFIG_DIR/matugen"
cp "$repo/config/matugen/config.toml" "$ANUSH_CONFIG_DIR/matugen/config.toml"
cp "$repo/config/fastfetch/config.jsonc" \
    "$ANUSH_CONFIG_DIR/fastfetch/config.jsonc"
cp "$repo/config/skarwm/config.rc" "$ANUSH_CONFIG_DIR/skarwm/config.rc"
cp "$repo/config/skarwm/config.rc" "$XDG_CONFIG_HOME/skarwm/config.rc"
touch "$tmp/wallpaper.png"
printf '%s\n' '{"theme":{"palette":null,"wallpaperEnabled":true}}' \
    >"$ANUSH_STATE_DIR/shell-state.json"
printf '%s\n' '/* keep user CSS */' >"$XDG_CONFIG_HOME/gtk-3.0/gtk.css"

cat >"$tmp/bin/matugen" <<'EOF'
#!/bin/sh
if [ "${MATUGEN_FAIL:-0}" -eq 1 ]; then
    printf '%s\n' 'simulated matugen failure' >&2
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

"$repo/shell/scripts/theme/generate-wallpaper-theme" "$tmp/wallpaper.png" dark
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
python3 - "$ANUSH_STATE_DIR/shell-state.json" \
    "$ANUSH_CONFIG_DIR/fastfetch/config.jsonc" <<'PY'
import json, sys
palette = json.load(open(sys.argv[1]))["theme"]["palette"]["semantic"]
config = open(sys.argv[2]).read()
for marker, role in {
    "fastfetch_primary": "primary",
    "fastfetch_foreground": "foreground",
    "fastfetch_secondary": "secondary",
}.items():
    red, green, blue = (int(palette[role][i:i + 2], 16) for i in (1, 3, 5))
    expected = f"38;2;{red};{green};{blue}"
    lines = [line for line in config.splitlines() if f"THEME: {marker}" in line]
    assert lines and all(expected in line for line in lines), (marker, expected, lines)
PY
grep -q '^sel_outer_border  : #507395$' \
    "$XDG_CONFIG_HOME/skarwm/config.rc"
grep -q '^decoration_color_source : explicit$' \
    "$XDG_CONFIG_HOME/skarwm/config.rc"
python3 - "$ANUSH_STATE_DIR/shell-state.json" \
    "$XDG_CONFIG_HOME/skarwm/config.rc" <<'PY'
import json, re, sys
palette = json.load(open(sys.argv[1]))["theme"]["palette"]
config = open(sys.argv[2]).read()
expected = {
    "decoration_accent": palette["semantic"]["primary"],
    "decoration_active_foreground": palette["semantic"]["primary"],
    "decoration_inactive_foreground": palette["semantic"]["primary"],
    "decoration_active_border": palette["semantic"]["primary"],
    "decoration_inactive_border": palette["semantic"]["primary"],
}
def blend(first, second, amount):
    left = tuple(int(first[index:index + 2], 16) for index in (1, 3, 5))
    right = tuple(int(second[index:index + 2], 16) for index in (1, 3, 5))
    mixed = (round(a * (1 - amount) + b * amount)
             for a, b in zip(left, right))
    return "#" + "".join(f"{channel:02x}" for channel in mixed)
expected["decoration_active_background"] = blend(
    palette["semantic"]["background"], palette["semantic"]["foreground"], 0.14)
expected["decoration_inactive_background"] = blend(
    palette["semantic"]["background"], palette["semantic"]["foreground"], 0.07)
for key, value in expected.items():
    assert re.search(rf"(?m)^{key}\s*:\s*{re.escape(value)}$", config), (key, value)
PY

"$repo/shell/scripts/theme/save-wallpaper-preset" \
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
"$repo/shell/scripts/theme/load-theme-presets" \
    "$ANUSH_CONFIG_DIR/themes/presets" | grep -q 'wallpaper-snake-night'
if "$repo/shell/scripts/theme/save-wallpaper-preset" \
        "$ANUSH_STATE_DIR/shell-state.json" \
        "$ANUSH_CONFIG_DIR/themes/presets" "snake night" \
        >"$tmp/duplicate.out" 2>"$tmp/duplicate.err"; then
    printf '%s\n' 'duplicate preset name was unexpectedly accepted' >&2
    exit 1
fi
grep -qi 'already exists' "$tmp/duplicate.err"

# A WM started with `-c` exports this exact path. It must win over the normal
# XDG location for both palette updates and the enable switch.
export SKARWM_CONFIG="$tmp/active-skarwm.rc"
cp "$XDG_CONFIG_HOME/skarwm/config.rc" "$SKARWM_CONFIG"
normal_border_before=$(sed -nE \
    's/^[[:space:]]*norm_outer_border[[:space:]]*:[[:space:]]*(#[0-9A-Fa-f]{6}).*/\1/p' \
    "$SKARWM_CONFIG")

ANUSH_ACCENT_NO_RELOAD=1 "$repo/shell/scripts/theme/apply-accent" \
    '#6574a8' '' '#fce8c3' '#68a8e4' \
    '#333333' '#292929' '#6574a8' '#6574a8' '#6574a8' '#6574a8' true
grep -q '^selection_background #6574a8$' \
    "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^url_color #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color4 #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep -q '^color12 #6574a8$' "$ANUSH_CONFIG_DIR/kitty/current-theme.conf"
grep 'THEME: fastfetch_primary' \
    "$ANUSH_CONFIG_DIR/fastfetch/config.jsonc" | \
    grep -q '38;2;101;116;168'
grep 'THEME: fastfetch_foreground' \
    "$ANUSH_CONFIG_DIR/fastfetch/config.jsonc" | \
    grep -q '38;2;252;232;195'
grep 'THEME: fastfetch_secondary' \
    "$ANUSH_CONFIG_DIR/fastfetch/config.jsonc" | \
    grep -q '38;2;104;168;228'
grep -q '^sel_outer_border  : #6574a8$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_accent : #6574a8$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_active_background : #333333$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_inactive_background : #292929$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_active_foreground : #6574a8$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_inactive_foreground : #6574a8$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_active_border : #6574a8$' \
    "$SKARWM_CONFIG"
grep -q '^decoration_inactive_border : #6574a8$' \
    "$SKARWM_CONFIG"
grep -qi "^[[:space:]]*norm_outer_border[[:space:]]*:[[:space:]]*$normal_border_before$" \
    "$SKARWM_CONFIG"
grep -q '^decorations_enabled : true$' \
    "$SKARWM_CONFIG"

# The persistent switch updates both the Anush template and a pre-existing
# live config, including installations whose file predates the setting.
sed -i '/^[[:space:]]*decorations_enabled[[:space:]]*:/d' \
    "$SKARWM_CONFIG"
ANUSH_DECORATION_NO_RELOAD=1 \
    "$repo/shell/scripts/theme/apply-window-decorations" true ''
grep -q '^decorations_enabled : true$' \
    "$ANUSH_CONFIG_DIR/skarwm/config.rc"
grep -q '^decorations_enabled : true$' \
    "$SKARWM_CONFIG"
ANUSH_DECORATION_NO_RELOAD=1 \
    "$repo/shell/scripts/theme/apply-window-decorations" false ''
grep -q '^decorations_enabled : false$' \
    "$ANUSH_CONFIG_DIR/skarwm/config.rc"
grep -q '^decorations_enabled : false$' \
    "$SKARWM_CONFIG"

# The switch also updates the running WM directly; this must not depend on
# discovering the config path skarwm received through its -c argument.
export SKARWM_MESSAGE_LOG="$tmp/skarwm-message.log"
queried_config="$tmp/queried-skarwm.rc"
cp "$repo/config/skarwm/config.rc" "$queried_config"
cat >"$tmp/bin/skarwm-msg" <<'EOF'
#!/bin/sh
if [ "${1:-}" = get-version ]; then
    printf '{"loaded_config_file_name":"%s"}\n' "$QUERIED_SKARWM_CONFIG"
    exit 0
fi
printf '%s\n' "$*" >>"$SKARWM_MESSAGE_LOG"
EOF
chmod +x "$tmp/bin/skarwm-msg"
export QUERIED_SKARWM_CONFIG="$queried_config"
"$repo/shell/scripts/theme/apply-window-decorations" true skarwm-msg
grep -qx 'decorations true' "$SKARWM_MESSAGE_LOG"
grep -q '^decorations_enabled : true$' "$queried_config"

# Accent refresh uses the same queried active path, so its reload cannot
# restore a stale decoration value from an explicit -c configuration.
ANUSH_ACCENT_NO_RELOAD=1 "$repo/shell/scripts/theme/apply-accent" \
    '#6574a8' skarwm-msg '#fce8c3' '#68a8e4' \
    '#333333' '#292929' '#6574a8' '#6574a8' '#6574a8' '#6574a8' true
grep -q '^decorations_enabled : true$' "$queried_config"
grep -q '^decoration_accent : #6574a8$' "$queried_config"

"$repo/shell/scripts/theme/apply-application-theme" gtk
"$repo/shell/scripts/theme/apply-application-theme" qt
grep -q 'keep user CSS' "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
grep -q 'anush matugen (managed)' "$XDG_CONFIG_HOME/gtk-3.0/gtk.css"
grep -q '^gtk-theme-name=adw-gtk3$' "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -q 'color_scheme_path=.*/anush-matugen.conf' \
    "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
grep -q '^custom_palette=true$' "$XDG_CONFIG_HOME/qt5ct/qt5ct.conf"
grep -q '^custom_palette=true$' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
grep -q '^style=Fusion$' "$XDG_CONFIG_HOME/qt6ct/qt6ct.conf"
grep -q '^\[ColorScheme\]$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^active_colors=#e4e2e7, #101114, #1c1b20, #92909a' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^\[ColorEffects:Disabled\]$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^\[Colors:Header\]\[Inactive\]$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^\[WM\]$' "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^BackgroundNormal=16,17,20$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -q '^DecorationFocus=184,196,255$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf"
grep -A12 '^\[Colors:Selection\]$' \
    "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf" \
    | grep -q '^ForegroundNormal=21,37,92$'
python3 - "$XDG_CONFIG_HOME/qt6ct/colors/anush-matugen.conf" <<'PY'
import sys
lines = open(sys.argv[1]).read().splitlines()
for key in ("active_colors", "disabled_colors", "inactive_colors"):
    value = next(line.split("=", 1)[1] for line in lines
                 if line.startswith(key + "="))
    assert len(value.split(", ")) == 21, (key, value)
PY
test -f "$XDG_DATA_HOME/color-schemes/AnushMatugen.colors"

MATUGEN_FAIL=1 "$repo/shell/scripts/theme/generate-wallpaper-theme" \
    "$tmp/wallpaper.png" dark
python3 - "$ANUSH_STATE_DIR/shell-state.json" <<'PY'
import json, sys
palette = json.load(open(sys.argv[1]))["theme"]["palette"]
assert palette["generator"] == "anush"
assert "material" not in palette
PY

printf '%s\n' 'theme generation tests passed'
