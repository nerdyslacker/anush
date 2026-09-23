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
    "$XDG_DATA_DIRS/icons/Fairy" "$XDG_DATA_HOME/icons/Papirus" "$tmp/bin"

cat >"$XDG_DATA_DIRS/icons/Fairy/index.theme" <<'EOF'
[Icon Theme]
Name=Fairy
Directories=48x48/apps
EOF
printf '%s\n' 'Inherits=Papirus,hicolor' \
    >>"$XDG_DATA_DIRS/icons/Fairy/index.theme"
cat >"$XDG_DATA_HOME/icons/Papirus/index.theme" <<'EOF'
[Icon Theme]
Name=Papirus
Directories=48x48/apps,48x48/places
EOF
places="$XDG_DATA_HOME/icons/Papirus/48x48/places"
mkdir -p "$places"
for icon in folder-blue folder-blue-documents user-blue-home; do
    printf '%s\n' '<svg fill="#5294e2"><path fill="#4877b1"/></svg>' \
        >"$places/$icon.svg"
done

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

# A direct Papirus selection uses an inheriting user overlay so its folder
# fills can exactly match the muted accent instead of a bright named variant.
: >"$ICON_HELPER_LOG"
"$helper" --set Papirus '#b8817d'
overlay="$XDG_DATA_HOME/icons/Anush-Papirus-Folders"
grep -q '^gtk-icon-theme-name=Anush-Papirus-Folders$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -qi '#b8817d' "$overlay/48x48/places/folder-documents.svg"
grep -qi '#976a66' "$overlay/48x48/places/folder-documents.svg"
grep -qi '#b8817d' "$overlay/48x48/places/inode-directory.svg"
! grep -q '^papirus-folders ' "$ICON_HELPER_LOG"
[ "$("$helper" --current)" = "Papirus" ]

# Every Matugen accent, including arbitrary custom colors, is written exactly
# into the generated SVG rather than quantized to Papirus's stock palette.
for accent in '#b8817d' '#6db869' '#bbb169' '#6d7eb7' '#bb6bb7' \
        '#6db8b7' '#654321'; do
    "$helper" --accent Papirus "$accent"
    grep -qi "$accent" "$overlay/48x48/places/folder-documents.svg"
    grep -qi "$accent" "$overlay/48x48/places/inode-directory.svg"
done

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

# Distro-installed Papirus variants use the same exact-color overlay without
# trying to mutate /usr/share/icons or opening a sudo prompt.
system_theme="$XDG_DATA_DIRS/icons/Papirus-Dark"
system_places="$system_theme/48x48/places"
mkdir -p "$system_places"
cat >"$system_theme/index.theme" <<'EOF'
[Icon Theme]
Name=Papirus Dark
Directories=48x48/places
EOF
for icon in folder-blue folder-blue-documents user-blue-home; do
    printf '%s\n' '<svg fill="#5294e2"><path fill="#4877b1"/></svg>' \
        >"$system_places/$icon.svg"
done
"$helper" --set Papirus-Dark '#b8817d'
overlay="$XDG_DATA_HOME/icons/Anush-Papirus-Dark-Folders"
grep -q '^gtk-icon-theme-name=Anush-Papirus-Dark-Folders$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
grep -q '^Inherits=Papirus-Dark$' "$overlay/index.theme"
grep -qi '#b8817d' "$overlay/48x48/places/folder-documents.svg"
grep -qi '#b8817d' "$overlay/48x48/places/inode-directory.svg"
[ "$("$helper" --current)" = "Papirus-Dark" ]
"$helper" --accent Papirus-Dark '#00ff00'
grep -qi '#00ff00' "$overlay/48x48/places/folder-documents.svg"
grep -qi '#00ff00' "$overlay/48x48/places/inode-directory.svg"

# Moving back to an unrelated theme must remove the managed overlay from the
# desktop configuration and never force Papirus.
"$helper" --set Fairy '#00ff00'
grep -q '^gtk-icon-theme-name=Fairy$' \
    "$XDG_CONFIG_HOME/gtk-3.0/settings.ini"
! "$helper" --list | grep -q '^Anush-Papirus-Dark-Folders$'

printf '%s\n' 'icon theme tests passed'
