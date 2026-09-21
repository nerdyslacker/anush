#!/bin/sh

set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
helper="$repo/shell/scripts/apply-icon-theme"
tmp=$(mktemp -d /tmp/anush-icon-theme-test.XXXXXX)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM

export HOME="$tmp/home"
export XDG_CONFIG_HOME="$tmp/config"
export XDG_DATA_HOME="$tmp/data"
export XDG_DATA_DIRS="$tmp/share"
export ICON_HELPER_LOG="$tmp/helper.log"
mkdir -p "$HOME" "$XDG_CONFIG_HOME/gtk-3.0" "$XDG_DATA_HOME/icons" \
    "$XDG_DATA_DIRS/icons/Fairy" "$XDG_DATA_DIRS/icons/Papirus" "$tmp/bin"

for theme in Fairy Papirus; do
    cat >"$XDG_DATA_DIRS/icons/$theme/index.theme" <<EOF
[Icon Theme]
Name=$theme
Directories=48x48/apps
EOF
done
printf '%s\n' 'Inherits=Papirus,hicolor' \
    >>"$XDG_DATA_DIRS/icons/Fairy/index.theme"

cat >"$tmp/bin/desktop-helper" <<'EOF'
#!/bin/sh
printf '%s %s\n' "$(basename "$0")" "$*" >>"$ICON_HELPER_LOG"
EOF
chmod +x "$tmp/bin/desktop-helper"
for command in papirus-folders gsettings xfconf-query dbus-send \
        gtk-update-icon-cache pkill; do
    ln -s desktop-helper "$tmp/bin/$command"
done
export PATH="$tmp/bin:/usr/bin:/bin"

# Selecting a non-Papirus theme that inherits Papirus must keep its own name
# and must not invoke Papirus folder recolouring.
"$helper" --set Fairy '#ff0000'
grep -q '^gtk-icon-theme-name=Fairy$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
! grep -q '^papirus-folders ' "$ICON_HELPER_LOG"

# A direct Papirus selection may use the official helper, but still remains
# configured as Papirus rather than an Anush overlay.
: >"$ICON_HELPER_LOG"
"$helper" --set Papirus '#ff0000'
grep -q '^gtk-icon-theme-name=Papirus$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -q '^papirus-folders .*--theme Papirus$' "$ICON_HELPER_LOG"

# Migrate settings left by the old overlay implementation on the next accent
# update, without treating an inheriting theme as Papirus-capable.
mkdir -p "$XDG_DATA_HOME/icons/Anush-Papirus"
cat >"$XDG_DATA_HOME/icons/Anush-Papirus/index.theme" <<'EOF'
[Icon Theme]
Name=Anush Papirus
Inherits=Fairy
Directories=
EOF
for gtk in gtk-3.0 gtk-4.0; do
    sed -i 's/^gtk-icon-theme-name=.*/gtk-icon-theme-name=Anush-Papirus/' \
        "$XDG_CONFIG_HOME/$gtk/settings.ini"
done
: >"$ICON_HELPER_LOG"
"$helper" --accent Fairy '#00ff00'
grep -q '^gtk-icon-theme-name=Fairy$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
! grep -q '^papirus-folders ' "$ICON_HELPER_LOG"

printf '%s\n' 'icon theme tests passed'
