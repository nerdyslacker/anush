#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="$repo/build/anushctl"
tmp=$(mktemp -d /tmp/anushctl-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/root/shell/scripts" "$tmp/root/config" \
    "$tmp/config/skarwm"
touch "$tmp/root/shell/shell.qml"
mkdir -p "$tmp/root/config/wallpaper"
touch "$tmp/root/config/wallpaper/hadrut_srcery.jpeg"
cat >"$tmp/bin/qs" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" >>"$FAKE_QS_LOG"
printf '%s\n' "${QS_ICON_THEME:-}" >>"$FAKE_QS_THEME_LOG"
printf '%s\n' "${KITTY_CONFIG_DIRECTORY:-}" >>"$FAKE_QS_KITTY_LOG"
if [ "${FAKE_QS_EXIT:-0}" -ne 0 ]; then
    printf '%s\n' 'no matching instance' >&2
    exit "$FAKE_QS_EXIT"
fi
case "$*" in
    *' kill -n') : >"$FAKE_QS_STATE" ;;
    *'-d --no-duplicate -p '*) rm -f "$FAKE_QS_STATE" ;;
    *'call anush ping') [ ! -e "$FAKE_QS_STATE" ] ;;
    *'call anush status') printf '%s\n' '{"name":"anush","protocol":1}' ;;
esac
EOF
chmod +x "$tmp/bin/qs"
cat >"$tmp/bin/betterlockscreen" <<'EOF'
#!/bin/sh
printf 'betterlockscreen %s\n' "$*" >>"$FAKE_HELPER_LOG"
EOF
cat >"$tmp/bin/feh" <<'EOF'
#!/bin/sh
printf 'feh %s\n' "$*" >>"$FAKE_HELPER_LOG"
EOF
cat >"$tmp/root/shell/scripts/clipboard-history" <<'EOF'
#!/bin/sh
printf 'clipboard-history %s\n' "$*" >>"$FAKE_HELPER_LOG"
EOF
chmod +x "$tmp/bin/betterlockscreen" "$tmp/bin/feh" \
    "$tmp/root/shell/scripts/clipboard-history"

export PATH="$tmp/bin:$PATH"
export ANUSH_ROOT="$tmp/root"
export FAKE_QS_LOG="$tmp/qs.log"
export FAKE_QS_STATE="$tmp/qs.stopped"
export FAKE_QS_THEME_LOG="$tmp/qs-theme.log"
export FAKE_QS_KITTY_LOG="$tmp/qs-kitty.log"
export FAKE_HELPER_LOG="$tmp/helper.log"
export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_STATE_HOME="$tmp/state"

mkdir -p "$XDG_STATE_HOME/anush"
cat >"$XDG_STATE_HOME/anush/shell-state.json" <<'EOF'
{"theme":{"iconTheme":"Test-Icons"}}
EOF

assert_contains() {
    haystack=$1
    needle=$2
    case "$haystack" in
        *"$needle"*) ;;
        *) printf 'expected %s to contain %s\n' "$haystack" "$needle" >&2; exit 1 ;;
    esac
}

$binary start
assert_contains "$(tail -n 1 "$FAKE_QS_THEME_LOG")" "Test-Icons"
assert_contains "$(tail -n 1 "$FAKE_QS_KITTY_LOG")" \
    "$ANUSH_ROOT/config/kitty"
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" \
    "--no-duplicate -p $ANUSH_ROOT/shell"

status=$($binary status)
assert_contains "$status" '"protocol":1'
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" \
    "-p $ANUSH_ROOT/shell ipc -n call anush status"
$binary reload
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call anush reload'
$binary restart >/dev/null
assert_contains "$(cat "$FAKE_QS_LOG")" \
    "-p $ANUSH_ROOT/shell kill -n"
assert_contains "$(cat "$FAKE_QS_LOG")" \
    "-d --no-duplicate -p $ANUSH_ROOT/shell"
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call anush ping'

$binary launcher toggle
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call launcher toggleCentered'
$binary notes new
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call notepad newNote'
$binary popup bluetooth
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call bluetooth open'
$binary theme mode light
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call anush themeMode light'
$binary lock
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" 'betterlockscreen -l'
$binary clipboard daemon
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" 'clipboard-history daemon'
$binary wallpaper restore
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" 'feh --bg-fill'

set +e
FAKE_QS_EXIT=1 $binary status >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 3 ] || { printf 'expected not-running exit 3, got %s\n' "$code" >&2; exit 1; }

# A first start discovers the system data tree and atomically seeds the user
# directory without an external initializer.
mkdir -p "$tmp/system/shell/scripts" "$tmp/system/config/themes/presets" \
    "$tmp/system/config/matugen"
touch "$tmp/system/shell/shell.qml"
printf '%s\n' '#!/bin/sh' >"$tmp/system/shell/scripts/new-helper"
printf '%s\n' 'seeded' >"$tmp/system/config/first-run-marker"
printf '%s\n' 'preset v1' >"$tmp/system/config/themes/presets/test.json"
printf '%s\n' 'matugen v1' >"$tmp/system/config/matugen/config.toml"
unset ANUSH_ROOT
export ANUSH_SYSTEM_DIR="$tmp/system"
export XDG_CONFIG_HOME="$tmp/first-config"
$binary start
[ -f "$XDG_CONFIG_HOME/anush/config/first-run-marker" ]
[ -x "$XDG_CONFIG_HOME/anush/shell/scripts/new-helper" ]
[ "$(cat "$XDG_CONFIG_HOME/anush/config/themes/presets/test.json")" = "preset v1" ]
[ "$(cat "$XDG_CONFIG_HOME/anush/config/matugen/config.toml")" = "matugen v1" ]
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" \
    "--no-duplicate -p $XDG_CONFIG_HOME/anush/shell"
assert_contains "$(tail -n 1 "$FAKE_QS_KITTY_LOG")" \
    "$XDG_CONFIG_HOME/anush/config/kitty"

# Later starts refresh managed shell files while preserving user config.
printf '%s\n' 'updated shell' >"$tmp/system/shell/update-marker"
printf '%s\n' '#!/bin/sh' >"$tmp/system/shell/scripts/refreshed-helper"
printf '%s\n' 'preset v2' >"$tmp/system/config/themes/presets/test.json"
printf '%s\n' 'matugen v2' >"$tmp/system/config/matugen/config.toml"
printf '%s\n' 'user setting' >"$XDG_CONFIG_HOME/anush/config/user-setting"
$binary start
[ -f "$XDG_CONFIG_HOME/anush/shell/update-marker" ]
[ -x "$XDG_CONFIG_HOME/anush/shell/scripts/refreshed-helper" ]
[ "$(cat "$XDG_CONFIG_HOME/anush/config/themes/presets/test.json")" = "preset v2" ]
[ "$(cat "$XDG_CONFIG_HOME/anush/config/matugen/config.toml")" = "matugen v2" ]
grep -q 'user setting' "$XDG_CONFIG_HOME/anush/config/user-setting"

export ANUSH_ROOT="$tmp/root"
unset ANUSH_SYSTEM_DIR
export XDG_CONFIG_HOME="$tmp/config"

printf '%s\n' '# user skarwm config' >"$XDG_CONFIG_HOME/skarwm/config.rc"
cat >>"$XDG_CONFIG_HOME/skarwm/config.rc" <<'EOF'
autostart : "if [ -f ~/.fehbg ]; then sh ~/.fehbg; else feh --bg-fill ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/anush/config}/wallpaper/hadrut_srcery.jpeg; fi"
autostart : "${ANUSH_ROOT:-${XDG_CONFIG_HOME:-$HOME/.config}/anush}/shell/scripts/clipboard-history daemon"
autostart : "xss-lock -- betterlockscreen -l"
EOF
$binary install skarwm
$binary install skarwm
[ "$(grep -c '>>> Anush shell' "$XDG_CONFIG_HOME/skarwm/config.rc")" -eq 1 ]
grep -q 'user skarwm config' "$XDG_CONFIG_HOME/skarwm/config.rc"
grep -q 'autostart : "anushctl wallpaper restore"' "$XDG_CONFIG_HOME/skarwm/config.rc"
grep -q 'autostart : "anushctl clipboard daemon"' "$XDG_CONFIG_HOME/skarwm/config.rc"
grep -q 'autostart : "xss-lock -- anushctl lock"' "$XDG_CONFIG_HOME/skarwm/config.rc"
! grep -q 'xss-lock -- betterlockscreen' "$XDG_CONFIG_HOME/skarwm/config.rc"
! grep -q 'shell/scripts/clipboard-history daemon' "$XDG_CONFIG_HOME/skarwm/config.rc"

$binary remove skarwm
grep -q 'user skarwm config' "$XDG_CONFIG_HOME/skarwm/config.rc"
! grep -q 'Anush shell' "$XDG_CONFIG_HOME/skarwm/config.rc"

# The bundled full Skarwm configuration carries the same managed marker, so
# installing after copying it does not duplicate bindings or startup commands.
cp "$repo/config/skarwm/config.rc" "$XDG_CONFIG_HOME/skarwm/config.rc"
$binary install skarwm
[ "$(grep -c '>>> Anush shell' "$XDG_CONFIG_HOME/skarwm/config.rc")" -eq 1 ]

printf '%s\n' 'anushctl tests passed'
