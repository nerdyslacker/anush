#!/bin/sh
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper=$repo/shell/scripts/theme/picom-control
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

mkdir -p "$tmp/bin"
config=$tmp/config.rc
log=$tmp/process.log
cat >"$config" <<'EOF'
autostart : "picom --experimental-backends --config /tmp/custom-picom.conf -b"
EOF
cat >"$tmp/bin/skarwm-msg" <<'EOF'
#!/bin/sh
printf '{"loaded_config_file_name":"%s"}\n' "$PICOM_TEST_CONFIG"
EOF
cat >"$tmp/bin/picom" <<'EOF'
#!/bin/sh
printf 'picom %s\n' "$*" >>"$PICOM_TEST_LOG"
EOF
cat >"$tmp/bin/pkill" <<'EOF'
#!/bin/sh
printf 'pkill %s\n' "$*" >>"$PICOM_TEST_LOG"
EOF
chmod +x "$tmp/bin/skarwm-msg" "$tmp/bin/picom" "$tmp/bin/pkill"
export PATH="$tmp/bin:/usr/bin:/bin"
export PICOM_TEST_CONFIG=$config
export PICOM_TEST_LOG=$log

"$helper" status skarwm-msg | grep -q '"available":true,"enabled":true'
"$helper" disable skarwm-msg | grep -q '"enabled":false'
grep -q '^# autostart : "picom --experimental-backends --config /tmp/custom-picom.conf -b"$' "$config"
grep -q '^pkill -x picom$' "$log"

: >"$log"
"$helper" enable skarwm-msg | grep -q '"enabled":true'
grep -q '^autostart : "picom --experimental-backends --config /tmp/custom-picom.conf -b"$' "$config"
i=0
while ! grep -q '^picom --experimental-backends --config /tmp/custom-picom.conf -b$' "$log"; do
    i=$((i + 1))
    [ "$i" -lt 50 ] || { echo "Picom command was not executed" >&2; exit 1; }
    sleep 0.02
done

# Enabling without an existing line adds the documented command first.
printf '%s\n' 'mod_key : super' >"$config"
export ANUSH_CONFIG_DIR=$tmp/anush
export ANUSH_PICOM_ARGS=--test-flag
: >"$log"
"$helper" enable skarwm-msg >/dev/null
grep -q '^autostart : "picom --config ${ANUSH_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/anush}/picom/picom.conf ${ANUSH_PICOM_ARGS:---no-use-damage} -b"$' "$config"
i=0
while ! grep -q '^picom --config .*/anush/picom/picom.conf --test-flag -b$' "$log"; do
    i=$((i + 1))
    [ "$i" -lt 50 ] || { echo "Default Picom command was not executed" >&2; exit 1; }
    sleep 0.02
done

# Availability is reported separately so the UI can hide the switch. An
# unavailable enable attempt must not modify the user's configuration.
mkdir "$tmp/no-picom"
cp "$tmp/bin/skarwm-msg" "$tmp/no-picom/skarwm-msg"
printf '%s\n' '# autostart : "picom --config /tmp/keep.conf -b"' >"$config"
PATH="$tmp/no-picom" /usr/bin/python3 "$helper" status \
    "$tmp/no-picom/skarwm-msg" | grep -q '"available":false,"enabled":false'
if PATH="$tmp/no-picom" /usr/bin/python3 "$helper" enable \
        "$tmp/no-picom/skarwm-msg" >/dev/null 2>&1; then
    echo "Unavailable Picom was unexpectedly enabled" >&2
    exit 1
fi
grep -q '^# autostart : "picom --config /tmp/keep.conf -b"$' "$config"

echo "picom control tests passed"
