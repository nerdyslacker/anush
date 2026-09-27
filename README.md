# anush

<div align="center">
<a href="https://github.com/nerdyslacker/anush"><img src="assets/anush_logo.png" width="150"/></a>
</div>

**anush** (_[ɑˈnuʃ]_) is a desktop shell named after my wife (_Անուշ_) currently integrated with
[skarwm](https://github.com/nerdyslacker/skarwm) to make it as beautiful as she
makes my life. It owns the bar, launchers,
clipboard, tray, weather, notifications, wallpaper tooling, desktop
configuration, and persistent shell state. It does not own or launch a window
manager; a WM configuration starts the shell by pointing Quickshell at
`anush/shell`.

<div align="center">
<img src="assets/screenshot.png"/>
</div>

## Dependencies

Required:

- Quickshell;
- Python 3 for state migration and shell helpers;
- JetBrainsMono Nerd Font for typography and Symbols Nerd Font Mono for
  consistently sized bar icons;
- for the current skarwm adapter, `skarwm-msg` available in `PATH`.

Optional desktop integrations:

- Any freedesktop icon and XCursor themes; Papirus additionally supports
  matching folder colors to the selected anush accent. The official
  `papirus-folders` helper is preferred, with a built-in fallback for writable
  user-installed Papirus themes;
- Picom, Dunst, Feh, Kitty, and Fastfetch for the supplied desktop configuration;
- Clipmenu and Xdotool for clipboard history and pasting;
- `setxkbmap` and `xkb-switch` for keyboard layouts;
- renCal for calendar events;
- NetworkManager, its command-line/editor tools, BlueZ, Blueman, `pactl`, and
  Pavucontrol for network, Bluetooth, and audio controls;
- for the Wi-Fi hotspot popup: NetworkManager/libnm GIR bindings for PyGObject,
  `iw`, `iproute2`, `iptables`, `dnsmasq`, polkit/`pkexec`, `hostapd`, and
  `create_ap`; NetworkManager owns second-adapter hotspots. Same-radio sharing
  uses `create_ap`, hostapd, dnsmasq, and scoped iptables rules, while the
  installed narrow helper uses `iw` to enforce the selected station limit;
- Easy Effects for optional audio-effect bypass and preset controls;
- tmux for the optional bar session manager;
- brightnessctl, powerprofilesctl, redshift, xset, and xrandr for hardware and
  power controls;
- curl, xcolor, xdg-open, flameshot, xinput, notify-send, and xterm for individual
  widget actions;
- matugen for Material You wallpaper themes; ImageMagick remains the automatic
  fallback when matugen is unavailable or cannot generate a valid palette;
- `adw-gtk-theme` (`adw-gtk3`) for applying generated colors consistently to
  GTK applications, and Qt5ct or Qt6ct for Qt applications;
- lxqt-policykit-agent, xss-lock, Betterlockscreen, and Udiskie for the supplied
  full desktop startup configuration.

Missing optional tools disable only the related action or widget. renCal is
available from the LazyLinux repository used by skarwm for Odin:

```sh
printf '%s\n' 'repository=https://github.com/lazylinuxos/lazy-repo/releases/latest/download' \
  | sudo tee /etc/xbps.d/99-repository-lazy.conf
```
```sh
sudo xbps-install -S quickshell picom dunst feh kitty fastfetch xss-lock \
  betterlockscreen udiskie lxqt-policykit NetworkManager bluez blueman pavucontrol \
  curl flameshot brightnessctl xrandr python3 python3-gobject iw iproute2 dnsmasq polkit \
  hostapd create_ap iptables renCal xterm xinput xdotool xcolor \
  clipmenu xkb-switch setxkbmap ImageMagick matugen adw-gtk-theme
```

Package availability depends on the enabled Void repositories; the Nerd Font may need separate installation.

Every Kitty launch provided by anush passes
`config/kitty/kitty.conf` explicitly, so it does not depend on a separate
system or user Kitty configuration. `anushctl start` also exports that location
to applications launched by the shell. Its selection, URL, active-tab, border,
and primary ANSI colors follow the current anush accent. The focused skarwm
window border is updated in the live skarwm configuration at the same time.

`anushctl start` seeds the Anush Fastfetch configuration when it is missing and
makes Fastfetch's standard
`${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc` path point to
`config/fastfetch/config.jsonc`. An existing regular config is preserved once
as `config.jsonc.pre-anush`. Fastfetch's keys, title, separator, and divider
follow the active anush theme.

## Install and launch

Install the program and data under the configured system prefix:

```sh
sudo make install
```

Hotspot actions can also run directly from a source checkout. anush uses
cached/passwordless `sudo` when available and otherwise opens a PolicyKit
authentication dialog through `pkexec`. Installing anush keeps the preferred
root-owned, narrowly authorized hotspot helpers under `/usr/libexec`, avoiding
authentication prompts for an active desktop session.

The system install is required for hotspot station limits and same-radio
Wi-Fi sharing: it installs the root-owned `create_ap` controller, limit helper,
and matching polkit
policies. Running those helpers directly from a writable source checkout is
intentionally unsupported.

On the first `anushctl start`, the CLI detects the installed data and seeds
`${XDG_CONFIG_HOME:-$HOME/.config}/anush` itself. No separate initialization
script is required. Later starts refresh managed shell code and assets while
leaving the user-owned `config/` directory unchanged.

Launch it directly with:

```sh
anushctl start
```

The install also provides the Odin-based `anushctl` management utility. It
uses anush's typed Quickshell IPC endpoints for runtime control:

```sh
anushctl status
anushctl reload
anushctl lock
anushctl launcher toggle
anushctl notes toggle
anushctl popup network
anushctl popup hotspot
anushctl hotspot status
anushctl wallpaper set ~/Pictures/wallpaper.jpg
anushctl theme mode dark
```

It can add or remove idempotent shell startup and keybinding blocks without
overwriting the rest of an existing compositor configuration:

```sh
anushctl install skarwm
```

See [`docs/anushctl.md`](docs/anushctl.md) for the full command tree, exit
codes, config paths, and protocol notes.
See [`docs/widgets/`](docs/widgets/README.md) for a short guide to every bar
widget and its mouse actions.

There is deliberately no anush session executable or display-manager entry.
The active WM decides how to start the shell. For skarwm, copy the supplied
configuration or add the autostart command yourself:

```sh
cp "${XDG_CONFIG_HOME:-$HOME/.config}/anush/config/skarwm/config.rc" \
   "${XDG_CONFIG_HOME:-$HOME/.config}/skarwm/config.rc"
```

```text
autostart : "anushctl start"
```

Future WM integrations belong under `config/<wm>/` and should point to the
same shell entry point without coupling anush to their session lifecycle.

With a current skarwm build, anush also replaces the WM's native keybinding,
notice, and reminder windows automatically. The keybinding window searches
both shortcuts and action descriptions and highlights every matching row.
Reminder expiry notices remain visible until clicked; ordinary status notices
still close after 2.5 seconds. If anush is not running, skarwm falls back to its
built-in windows.

## Layout

```text
config/                 external application and WM integration examples
shell/common/           shared QML types and state management
shell/components/       QML grouped by feature
shell/scripts/          feature-grouped shell helper programs
shell/states/           default state document
shell/shell.qml         Quickshell entry point
```

## State and configuration

Persistent settings live in
`${XDG_STATE_HOME:-$HOME/.local/state}/anush/shell-state.json`. Set
`ANUSH_STATE_DIR` to override that directory. The sections are `bar`,
`weather`, `launcher`, `wallpaper`, `keyboard`, `tray`, `tags`, `pomodoro`, `theme`,
`windowManager`, `windowList`, and `desktop`.

The optional **Window list** Bar widget uses one shared pill containing one
icon per application. Clicking a group with multiple windows opens a window
picker; a single-window group focuses immediately. Each Bar shows windows from
the workspace currently displayed on that Bar's output and, by default, only
windows on that output. Right-click the pill or any icon to toggle the
persistent cross-monitor view. That mode removes only the output filter; it
keeps the owning Bar's workspace filter:

```json
"windowList": {
  "showWindowsFromAllMonitors": false
}
```

Right-click the launcher button to choose an icon-theme icon, a searchable
distribution logo from `assets/distro-logos.json`, or an image file. Image
paths inside the anush config directory are stored relative to that directory
for portability. An unavailable or deleted custom icon falls back to the
built-in anush glyph; **Reset** clears the saved customization.

The audio widget opens the native mixer with a left click, toggles output mute
with a middle click, and opens Easy Effects controls with a right click. When
Easy Effects is installed, that popup controls global bypass, selects input and
output presets, refreshes their state, or opens the full application. The
normal mixer remains available when Easy Effects is absent.

The Network widget opens the existing Network/VPN popup with a left click and
the Wi-Fi Hotspot popup with a right click; middle click opens the full
NetworkManager editor. Hotspot settings and secrets live in NetworkManager,
rather than anush state. AP/channel capabilities and associated stations come
from `iw`. NetworkManager provides sharing for a separate AP adapter;
same-radio sharing is owned by `create_ap` so NetworkManager cannot fight the
virtual AP.
The optional numeric device limit is enforced by the installed polkit helper for the
life of the hotspot.

The optional tmux bar widget shows the number of running sessions. Its popup
can create and attach sessions in `$TERMINAL`, Kitty, Foot, Alacritty, WezTerm,
or XTerm; it also renames sessions and uses a two-click confirmation before
killing one. Middle-clicking the widget refreshes its session count.

Right-click a tag to configure the workspace count, dynamic workspaces, tag
numbers, and an optional per-page tag limit. When the available tags exceed
that limit, arrow buttons page through them; selecting a workspace by another
method automatically reveals its page.

Rounded corners are controlled by the canonical `theme.cornerRadius` value.
It is watched at runtime along with the rest of the state, so editing the state
file updates open shell surfaces without a restart. `0` keeps every non-circular
surface square; larger values derive coherent small, medium, and large radii:

```json
"theme": {
  "cornerRadius": 10
}
```

Committing the corner-radius slider also updates `corner_radius` in
`config/skarwm/config.rc` atomically and requests a skarwm configuration reload.
Set `ANUSH_CONFIG_DIR` when anush's writable configuration lives somewhere
other than its installed `config/` directory.

The layout/appearance popup includes selectable palette cards for Srcery,
Catppuccin, Gruvbox, Nord, and Everforest in dark and light variants, plus the
Windows 95-inspired Classic palette. Presets are individual JSON files under
`config/themes/presets`; adding a valid file adds a card without changing QML.
The selection and its corresponding mode are stored as `theme.preset` and
`theme.mode` and update the running shell immediately:

```json
"theme": {
  "preset": "everforest-light",
  "mode": "light"
}
```

`Theme.qml` exposes mode-independent roles including `background`, `surface`,
`surfaceVariant`, `foreground`, `foregroundMuted`, `accent`,
`accentForeground`, `activeBackground`, `activeBorder`, `outline`, `hover`,
`pressed`, `error`, `warning`, `success`, `shadow`, and `overlay`. Built-in and
wallpaper-derived palettes both populate this API, allowing future palette
generators to remain separate from component styling.

In light mode, wallpaper-derived palettes lift the wallpaper's dominant
background hue into a light surface and enforce readable contrast for text and
accent roles. Bundled presets use the exact named colors from their upstream
palette documents rather than generated lightening or darkening.

Wallpaper themes combine the wallpaper-faithful anush/ImageMagick palette for
the shell with matugen's fidelity Material roles for application integration.
The anush generator is also used automatically if matugen is missing, exits
unsuccessfully, or returns incomplete data. When
the active wallpaper palette came from matugen, the layout popup exposes
explicit **Apply GTK Themes** and **Apply Qt Themes** actions. Applying the GTK
theme expects `adw-gtk-theme` (the installed theme is normally named
`adw-gtk3`) and updates application CSS in a managed block without discarding
existing user CSS. Qt5ct, Qt6ct, and KDE-compatible color-scheme files are
generated from the same palette. The wallpaper picker can save the current
generated palette under a custom name; saved palettes immediately appear as
cards in the layout popup's theme preset section.

Bars can optionally shrink along their long axis to their natural widget size
while the native panel window remains centered on each screen. This keeps the
surrounding desktop clickable and preserves the bar's workspace reservation:

```json
"bar": {
  "fitContent": true,
  "floating": true,
  "separateSections": false
}
```

These settings are also available as **Fit to content** and **Floating**
in the bar layout popup. Floating mode uses the same 8-pixel gap as bar
popups; a full-width horizontal bar is inset from the left and right edges as
well. The workspace reservation remains intact.

On full-length bars, **Sections** can replace the continuous background with
separate start, center, and end surfaces. Empty sections are not drawn; side
bars arrange the three surfaces vertically.

The power menu's **Display settings** item opens a centered XRandR-backed
configuration surface. Changes are staged until **Apply**; mode, refresh rate,
scale, orientation, enabled state, primary output, mirroring, and snapped
monitor positions are configured together. Potentially disruptive changes
must be confirmed within 15 seconds or the independent rollback watchdog
restores the previous layout. XRandR remains the persistence owner.

`ShellState.qml` merges section updates and writes the complete document
atomically. On first launch, it imports compatible state from the former
skarwm files when present; afterward `shell-state.json` is the only active
state source.

The **Notepad** bar widget opens an animated sidebar from the configurable left
or right screen edge. It supports multiple tabbed UTF-8 Markdown notes under
`${XDG_DATA_HOME:-$HOME/.local/share}/anush/notepad/`; the `+` tab button creates
a new file. The header provides compact/extended width and close controls; the
footer persists whether the drawer opens from the left or right. Writes are
debounced and atomic, and failures or external changes
never discard the in-memory text. Set `ANUSH_NOTEPAD_DIR` to choose another
directory. `ANUSH_NOTES_FILE` remains available for a specific legacy file.
The sidebar can also be controlled through `anushctl`:

```sh
anushctl notes toggle
anushctl notes new
anushctl notes save
```

The supplied skarwm configuration binds `Super+Shift+N` to toggle Notepad.
The shortcut calls the global Notepad IPC handler directly, so it remains
available when the Notepad bar widget is hidden.

Application configuration is under `config/`, shell scripts are always
resolved relative to `shell/`, and QML components are grouped by function
under `shell/components/`.

## Inspiration

The desktop setup was inspired by
[drew/dwm-setup](https://justaguy.dev/drew/dwm-setup).
