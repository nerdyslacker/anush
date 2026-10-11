#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
editor=$repo/shell/scripts/skarwm/config-editor
config_set=$repo/shell/scripts/skarwm/config-set
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/config.d"
cat >"$tmp/default.conf" <<'EOF'
[import]
appearance = config.d/appearance.conf
objects = config.d/objects.conf

[call]
"mod + r" = reload_config
EOF
cat >"$tmp/config.d/appearance.conf" <<'EOF'
[window]
outer_gap = 8
inner_gap = 6
corner_radius = 4

[window.border]
normal = #303030
selected = #FED06E

[window.decoration]
enabled = true
EOF
cat >"$tmp/config.d/objects.conf" <<'EOF'
[autostart]
shell = anushctl start

[rule.browser]
class = Firefox
workspace = 3
floating = true

[workspace.3]
layout = dwindle
icon = 󰆍
name = Code

[virtual_screen.DP-1]
mode = split
ratio = 75
offset = -30

[bar.block.launcher]
type = button
position = left
label = 󰀻
foreground = #FFFFFF
background = #303030
command = anushctl launcher toggle
EOF
cat >"$tmp/bin/skarwm-msg" <<'EOF'
#!/bin/sh
if [ "${1:-}" = get-version ]; then
    printf '{"loaded_config_file_name":"%s"}\n' "$CONFIG_EDITOR_TEST_PATH"
    exit 0
fi
printf '%s\n' "$*" >>"$CONFIG_EDITOR_TEST_LOG"
EOF
chmod +x "$tmp/bin/skarwm-msg"
export PATH="$tmp/bin:/usr/bin:/bin"
export CONFIG_EDITOR_TEST_PATH=$tmp/default.conf
export CONFIG_EDITOR_TEST_LOG=$tmp/messages.log

"$config_set" "$tmp/default.conf" window.border selected '#ABCDEF'
grep -q '^appearance = config.d/appearance.conf$' "$tmp/default.conf"
grep -q '^objects = config.d/objects.conf$' "$tmp/default.conf"
[ "$(grep -c '^anush = anush.conf$' "$tmp/default.conf")" -eq 1 ]
grep -q '^selected = #ABCDEF$' "$tmp/anush.conf"
"$editor" read >"$tmp/read.json"
python3 - "$tmp/read.json" "$tmp/document.json" <<'PY'
import json, sys
payload = json.load(open(sys.argv[1]))
assert payload["success"] is True
document = payload["document"]
assert document["settings"]["corner_radius"] == 4
assert document["settings"]["sel_outer_border"] == "#ABCDEF"
assert document["autostart"] == ["anushctl start"]
assert document["rules"] == [{
    "id": "browser",
    "field": "class", "pattern": "Firefox",
    "effects": "workspace 3 floating",
}]
assert document["workspaceLayouts"][0]["name"] == "Code"
assert document["virtualScreens"][0]["offset"] == "-30"
assert document["barBlocks"][0]["kind"] == "button"
assert document["barBlocks"][0]["foreground"] == "#FFFFFF"
document["settings"]["corner_radius"] = 14
open(sys.argv[2], "w").write(json.dumps(document, ensure_ascii=False) + "\n")
PY

"$editor" save-reload <"$tmp/document.json" >"$tmp/saved.json"
grep -qx 'reload' "$CONFIG_EDITOR_TEST_LOG"
grep -q '^\[window\]$' "$tmp/anush.conf"
grep -q '^corner_radius = 14$' "$tmp/anush.conf"
grep -q '^\[bar.block.launcher\]$' "$tmp/anush.conf"
grep -q '^type = button$' "$tmp/anush.conf"
grep -q '^foreground = #FFFFFF$' "$tmp/anush.conf"
[ "$(grep -c '^\[window\]$' "$tmp/anush.conf")" -eq 1 ]
[ "$(grep -c '^\[window.decoration\]$' "$tmp/anush.conf")" -eq 1 ]
if grep -Eq '^[[:space:]]*(bind|call|autostart|rule|bar_block)[[:space:]]*:' "$tmp/anush.conf"; then
    echo "legacy skarwm syntax was written" >&2
    exit 1
fi

"$config_set" "$tmp/default.conf" window.border selected '#507395'
"$config_set" "$tmp/default.conf" window.decoration accent '#507395'
"$config_set" "$tmp/default.conf" window.decoration active_border '#507395'
grep -q '^selected = #507395$' "$tmp/anush.conf"
[ "$(grep -c '^\[window.decoration\]$' "$tmp/anush.conf")" -eq 1 ]
grep -q '^accent = #507395$' "$tmp/anush.conf"
grep -q '^active_border = #507395$' "$tmp/anush.conf"
[ "$(grep -c '^anush = anush.conf$' "$tmp/default.conf")" -eq 1 ]
"$editor" read >"$tmp/reread.json"
python3 - "$tmp/reread.json" <<'PY'
import json, sys
document = json.load(open(sys.argv[1]))["document"]
assert document["settings"]["corner_radius"] == 14
assert document["settings"]["sel_outer_border"] == "#507395"
assert document["barBlocks"][0]["command"] == "anushctl launcher toggle"
PY

echo "skarwm configuration tests passed"
