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
- a JetBrainsMono Nerd Font for the intended icons and typography;
- for the current skarwm adapter, `skarwm-msg` available in `PATH`.

Optional desktop integrations:

- Picom, Dunst, Feh, and Kitty for the supplied desktop configuration;
- Clipmenu and Xdotool for clipboard history and pasting;
- `setxkbmap` and `xkb-switch` for keyboard layouts;
- renCal for calendar events;
- NetworkManager tools, BlueZ, `pactl`, and Pavucontrol for network and audio;
- brightnessctl, powerprofilesctl, redshift, xset, and xrandr for hardware and
  power controls;
- curl, xdg-open, flameshot, xinput, notify-send, and xterm for individual
  widget actions;
- ImageMagick for wallpaper-derived themes;
- lxqt-policykit-agent, xss-lock, Betterlockscreen, and Udiskie for the supplied
  full desktop startup configuration.

Missing optional tools disable only the related action or widget. renCal is
available from the LazyLinux repository used by skarwm for Odin:

```sh
printf '%s\n' 'repository=https://github.com/lazylinuxos/lazy-repo/releases/latest/download' \
  | sudo tee /etc/xbps.d/99-repository-lazy.conf
```
```sh
sudo xbps-install -S quickshell picom dunst feh kitty xss-lock \
  betterlockscreen udiskie lxqt-policykit NetworkManager bluez pavucontrol \
  curl flameshot brightnessctl xrandr python3 renCal xterm xinput xdotool \
  clipmenu xkb-switch setxkbmap ImageMagick
```

Package availability depends on the enabled Void repositories; the Nerd Font may need separate installation.

## Install and launch

Install into `${XDG_CONFIG_HOME:-$HOME/.config}/anush`:

```sh
make install
```

Launch it directly with:

```sh
qs --no-duplicate -p ~/.config/anush/shell
```

There is deliberately no anush session executable or display-manager entry.
The active WM decides how to start the shell. For skarwm, copy the supplied
configuration or add the autostart command yourself:

```sh
cp ~/.config/anush/config/skarwm/config.rc ~/.config/skarwm/config.rc
```

```text
autostart : "qs --no-duplicate -p ~/.config/anush/shell"
```

Future WM integrations belong under `config/<wm>/` and should point to the
same shell entry point without coupling anush to their session lifecycle.

## Layout

```text
config/                 external application and WM integration examples
shell/common/           shared QML types and state management
shell/components/       QML grouped by feature
shell/scripts/          shell helper programs
shell/states/           default state document
shell/shell.qml         Quickshell entry point
```

## State and configuration

Persistent settings live in
`${XDG_STATE_HOME:-$HOME/.local/state}/anush/shell-state.json`. Set
`ANUSH_STATE_DIR` to override that directory. The sections are `bar`,
`weather`, `launcher`, `keyboard`, `tray`, `tags`, `pomodoro`, `theme`,
`windowManager`, and `desktop`.

Right-click the launcher button to choose an icon-theme icon or an image file.
Image paths inside the anush config directory are stored relative to that
directory for portability. An unavailable or deleted custom icon falls back to
the built-in anush glyph; **Reset** clears the saved customization.

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

The layout/appearance popup switches between the built-in Srcery `dark` and
`light` modes below the accent colors. The selection is stored as `theme.mode`
and updates the running shell immediately:

```json
"theme": {
  "mode": "light"
}
```

`Theme.qml` exposes mode-independent roles including `background`, `surface`,
`surfaceVariant`, `foreground`, `foregroundMuted`, `accent`,
`accentForeground`, `outline`, `hover`, `pressed`, `error`, `warning`,
`success`, `shadow`, and `overlay`. Built-in and wallpaper-derived palettes
both populate this API, allowing future palette generators to remain separate
from component styling.

In light mode, wallpaper-derived palettes lift the wallpaper's dominant
background hue into a light surface and enforce readable contrast for text and
accent roles; the fixed Srcery light theme continues to use its canonical cream.

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

`ShellState.qml` merges section updates and writes the complete document
atomically. On first launch, it imports compatible state from the former
skarwm files when present; afterward `shell-state.json` is the only active
state source.

Application configuration is under `config/`, shell scripts are always
resolved relative to `shell/`, and QML components are grouped by function
under `shell/components/`.

## Inspiration

The desktop setup was inspired by
[drew/dwm-setup](https://justaguy.dev/drew/dwm-setup).
