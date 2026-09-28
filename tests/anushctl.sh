#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
binary="$repo/build/anushctl"
tmp=$(mktemp -d /tmp/anushctl-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin" "$tmp/root/shell/scripts" "$tmp/root/config/fastfetch" \
    "$tmp/config/skarwm" "$tmp/config/fastfetch"
touch "$tmp/root/shell/shell.qml"
printf '%s\n' 'anush fastfetch' >"$tmp/root/config/fastfetch/config.jsonc"
printf '%s\n' 'personal fastfetch' >"$tmp/config/fastfetch/config.jsonc"
mkdir -p "$tmp/root/config/wallpaper"
touch "$tmp/root/config/wallpaper/minimal.png"
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
mkdir -p "$tmp/root/shell/scripts/clipboard"
cat >"$tmp/root/shell/scripts/clipboard/clipboard-history" <<'EOF'
#!/bin/sh
printf 'clipboard-history %s\n' "$*" >>"$FAKE_HELPER_LOG"
EOF
chmod +x "$tmp/bin/betterlockscreen" "$tmp/bin/feh" \
    "$tmp/root/shell/scripts/clipboard/clipboard-history"

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
[ "$(readlink "$XDG_CONFIG_HOME/fastfetch/config.jsonc")" = \
    "$XDG_CONFIG_HOME/skarwm/anush/fastfetch/config.jsonc" ]
[ "$(cat "$XDG_CONFIG_HOME/skarwm/anush/fastfetch/config.jsonc")" = \
    "anush fastfetch" ]
[ "$(cat "$XDG_CONFIG_HOME/fastfetch/config.jsonc.pre-anush")" = \
    "personal fastfetch" ]
assert_contains "$(tail -n 1 "$FAKE_QS_THEME_LOG")" "Test-Icons"
assert_contains "$(tail -n 1 "$FAKE_QS_KITTY_LOG")" \
    "$XDG_CONFIG_HOME/skarwm/anush/kitty"
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
$binary popup phone
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call phone open'
$binary popup hotspot
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot openPopup'
$binary hotspot status
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot status'
$binary hotspot on
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot enable'
$binary hotspot off
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot disable'
$binary hotspot toggle
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot toggle'
$binary hotspot clients
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call hotspot clients'
$binary theme mode light
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call anush themeMode light'
$binary lock
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" 'betterlockscreen -l'
$binary clipboard daemon
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" 'clipboard-history daemon'
$binary wallpaper restore
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" \
    'feh --bg-fill'
assert_contains "$(tail -n 1 "$FAKE_HELPER_LOG")" \
    '/config/wallpaper/minimal.png'

set +e
FAKE_QS_EXIT=1 $binary status >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 3 ] || { printf 'expected not-running exit 3, got %s\n' "$code" >&2; exit 1; }

# A normal start discovers and runs the package tree directly. Only writable
# application configuration is seeded under skarwm/anush.
mkdir -p "$tmp/system/shell/scripts/shell" \
    "$tmp/system/config/kitty" "$tmp/system/config/picom" \
    "$tmp/system/config/rofi"
touch "$tmp/system/shell/shell.qml"
printf '%s\n' '#!/bin/sh' >"$tmp/system/shell/scripts/new-helper"
printf '%s\n' '#!/bin/sh' >"$tmp/system/shell/scripts/shell/bar"
printf '%s\n' 'kitty template' >"$tmp/system/config/kitty/kitty.conf"
printf '%s\n' 'picom template' >"$tmp/system/config/picom/picom.conf"
printf '%s\n' 'rofi template' >"$tmp/system/config/rofi/config.rasi"
unset ANUSH_ROOT
export ANUSH_SYSTEM_DIR="$tmp/system"
export XDG_CONFIG_HOME="$tmp/first-config"
$binary start
[ ! -e "$XDG_CONFIG_HOME/anush" ]
[ "$(cat "$XDG_CONFIG_HOME/skarwm/anush/kitty/kitty.conf")" = \
    "kitty template" ]
[ "$(cat "$XDG_CONFIG_HOME/skarwm/anush/picom/picom.conf")" = \
    "picom template" ]
[ "$(cat "$XDG_CONFIG_HOME/skarwm/anush/rofi/config.rasi")" = \
    "rofi template" ]
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" \
    "--no-duplicate -p $tmp/system/shell"
assert_contains "$(tail -n 1 "$FAKE_QS_KITTY_LOG")" \
    "$XDG_CONFIG_HOME/skarwm/anush/kitty"

# Existing writable config is an override and is not refreshed from package
# updates. Reload addresses the package-backed shell directly.
printf '%s\n' 'personal kitty' >"$XDG_CONFIG_HOME/skarwm/anush/kitty/kitty.conf"
printf '%s\n' 'updated template' >"$tmp/system/config/kitty/kitty.conf"
$binary reload
[ "$(cat "$XDG_CONFIG_HOME/skarwm/anush/kitty/kitty.conf")" = \
    "personal kitty" ]
assert_contains "$(tail -n 1 "$FAKE_QS_LOG")" 'call anush reload'

export ANUSH_ROOT="$tmp/root"
unset ANUSH_SYSTEM_DIR
export XDG_CONFIG_HOME="$tmp/config"

set +e
$binary install skarwm >/dev/null 2>&1
code=$?
set -e
[ "$code" -eq 2 ] || { printf 'expected removed install command to exit 2\n' >&2; exit 1; }

printf '%s\n' 'anushctl tests passed'
